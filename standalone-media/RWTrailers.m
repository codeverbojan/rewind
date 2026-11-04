#import "RWMetadataBudget.h"
#import "RWApplePreviewLookup.h"
#import "RWApplePreviewPolicy.h"
#import "RWTrailers.h"
#import "RWTrailerPolicy.h"
#import "RWAtomicWriter.h"
static NSDictionary *JSONFile(NSString *path){NSData *d=[NSData dataWithContentsOfFile:path];id j=d?[NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil]:nil;return [j isKindOfClass:NSDictionary.class]?j:@{};}
@implementation RWTrailers {
    RWApplePreviewLookup *_apple;NSURLSession *_session;NSURLSessionDataTask *_task;NSMutableDictionary *_cache;NSDictionary *_seed,*_fallback,*_diagnostics,*_lookupIdentity;NSArray *_movieIDs;BOOL _appleLookup;NSString *_path,*_key;NSMutableArray *_waiters,*_trace;NSString *_route;NSUInteger _generation;double _began,_backoff;
}
- (instancetype)initWithCache:(NSString *)path bundled:(NSString *)bundled {return [self initWithCache:path bundled:bundled configuration:nil];}
- (instancetype)initWithCache:(NSString *)path bundled:(NSString *)bundled configuration:(NSURLSessionConfiguration *)configuration {
    if((self=[super init])){_path=path;_cache=[JSONFile(path)mutableCopy];_seed=JSONFile(bundled);
        // Before 0.55 an unspecified failure could suppress native lookup for
        // thirty minutes, including temporary TLS/timeouts. Forget only that
        // legacy negative evidence; preserve playable sources and cooldowns.
        BOOL migrated=NO;for(NSString *key in _cache.allKeys){NSDictionary *old=_cache[key];if(![old isKindOfClass:NSDictionary.class]||!old[@"nativeUnavailableUntil"]||old[@"nativeFailureKind"])continue;NSMutableDictionary *entry=[old mutableCopy];[entry removeObjectForKey:@"nativeUnavailableUntil"];_cache[key]=entry;migrated=YES;}if(migrated)[self save];
        NSURLSessionConfiguration *c=[configuration copy]?:[NSURLSessionConfiguration ephemeralSessionConfiguration];c.timeoutIntervalForRequest=4;c.timeoutIntervalForResource=4;c.HTTPMaximumConnectionsPerHost=1;c.HTTPAdditionalHeaders=@{@"User-Agent":@"Rewind/0.12 (standalone iPad experiment; org.local.ministreamlab)",@"Accept":@"application/json"};_session=[NSURLSession sessionWithConfiguration:c];_apple=[[RWApplePreviewLookup alloc]initWithConfiguration:configuration];}return self;
}
- (NSDictionary *)diagnostics {return _diagnostics?:@{};}
- (void)save {if(_cache.count>160){NSArray *keys=[_cache keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"expires"]compare:b[@"expires"]];}];for(NSUInteger i=0;i<keys.count-120;i++)[_cache removeObjectForKey:keys[i]];}[[RWAtomicWriter shared]write:[NSJSONSerialization dataWithJSONObject:_cache options:0 error:nil] path:_path];}
- (void)finish:(NSDictionary *)source error:(NSString *)error ttl:(double)ttl {
    BOOL nativeMiss=!source&&![error isEqual:@"Cancelled"];double nativeTTL=ttl;
    NSDictionary *native=_appleLookup?_apple.diagnostics:@{@"route":_route?:@"",@"steps":[_trace copy]?:@[]};NSString *nativeError=error?:@"";
    if(!source&&_fallback&&![error isEqual:@"Cancelled"]){source=_fallback;error=nil;ttl=900;}_fallback=nil;
    if(!_key)return;_diagnostics=@{@"imdb":_key,@"input":_lookupIdentity?:@{},@"result":source?source[@"kind"]?:([source[@"youtubeID"]length]?@"embedded":@"native_file"):@"unavailable",@"native_error":nativeError,@"native":native,@"cache_seconds":@(nativeTTL),@"elapsed_seconds":@(NSProcessInfo.processInfo.systemUptime-_began)};[[RWMetadataBudget shared]cancel:_task];_task=nil;NSString *key=_key;_key=nil;_generation++;[_apple cancel];NSArray *callbacks=[_waiters copy];_waiters=nil;
    if([source[@"kind"]isEqual:@"apple-hls"]){ttl=0;NSNumber *embeddedUntil=_cache[key][@"embeddedFailedUntil"];if([embeddedUntil doubleValue]>NSDate.date.timeIntervalSince1970)_cache[key]=@{@"embeddedFailedUntil":embeddedUntil,@"expires":embeddedUntil};else [_cache removeObjectForKey:key];[self save];} // Keep playlists only in the two-entry memory cache; success clears obsolete failure state.
    if(ttl>0){NSMutableDictionary *entry=[_cache[key]mutableCopy]?:[NSMutableDictionary new];entry[@"source"]=source?:@{};entry[@"expires"]=@(NSDate.date.timeIntervalSince1970+ttl);[entry removeObjectForKey:@"playbackFailed"];if(nativeMiss){entry[@"nativeLookupRevision"]=@4;entry[@"nativeUnavailableUntil"]=@(NSDate.date.timeIntervalSince1970+MIN(nativeTTL,1800));entry[@"nativeFailureKind"]=native[@"failure_kind"]?:@"unavailable";entry[@"nativeError"]=nativeError;entry[@"nativeDiagnostics"]=native;}else{[entry removeObjectForKey:@"nativeUnavailableUntil"];[entry removeObjectForKey:@"nativeFailureKind"];[entry removeObjectForKey:@"nativeError"];[entry removeObjectForKey:@"nativeDiagnostics"];}_cache[key]=entry;[self save];}
    NSMutableDictionary *out=source?[source mutableCopy]:nil;out[@"lookupSeconds"]=@(NSProcessInfo.processInfo.systemUptime-_began);out[@"imdb"]=key;
    for(void(^cb)(NSDictionary *,NSString *) in callbacks)cb(out,error);
}
- (void)failed:(NSString *)imdb {if(!imdb.length)return;_cache[imdb]=@{@"source":@{},@"playbackFailed":@YES,@"expires":@([NSDate date].timeIntervalSince1970+60)};[self save];}
- (void)failed:(NSString *)imdb embedded:(BOOL)embedded {
    if(!imdb.length)return;NSMutableDictionary *entry=[_cache[imdb]mutableCopy]?:[NSMutableDictionary new];entry[embedded?@"embeddedFailedUntil":@"nativeFailedUntil"]=@(NSDate.date.timeIntervalSince1970+60);entry[@"expires"]=@(MAX([entry[@"expires"]doubleValue],NSDate.date.timeIntervalSince1970+60));_cache[imdb]=entry;[self save];
}
- (void)embeddedUnsupported {_cache[@"__embeddedRuntime"]=@{@"unsupportedUntil":@(NSDate.date.timeIntervalSince1970+86400),@"expires":@(NSDate.date.timeIntervalSince1970+86400),@"reason":@"provider_script_syntax"};[self save];}
- (void)fetch:(NSString *)url generation:(NSUInteger)g done:(void(^)(NSDictionary *))done {
    __block NSURLSessionDataTask *requestTask=nil;
    requestTask=[_session dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){NSInteger code=[response isKindOfClass:NSHTTPURLResponse.class]?[(NSHTTPURLResponse *)response statusCode]:0;id j=!error&&code==200&&data.length<3*1024*1024?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
        dispatch_async(dispatch_get_main_queue(),^{[[RWMetadataBudget shared]complete:requestTask];requestTask=nil;if(self->_generation!=g)return;
            if(self->_trace.count<4)[self->_trace addObject:@{@"host":response.URL.host?:@"",@"path":response.URL.path?:@"",@"http":@(code),@"bytes":@(data.length),@"error_domain":error.domain?:@"",@"error_code":@(error.code)}];
            if(code==429||code==503){self->_backoff=[NSDate date].timeIntervalSince1970+MAX(120,[[(NSHTTPURLResponse *)response allHeaderFields][@"Retry-After"]doubleValue]);}
            if(![j isKindOfClass:NSDictionary.class]||j[@"error"]){[self finish:nil error:@"Preview unavailable right now" ttl:60];return;}done(j);});}];_task=requestTask;[[RWMetadataBudget shared]enqueue:_task foreground:YES];
}
- (void)lookupAppleMovie:(NSDictionary *)meta generation:(NSUInteger)g {
    if(_movieIDs.count!=1){[self finish:nil error:@"No unambiguous movie preview mapping" ttl:1800];return;}
    _appleLookup=YES;_route=@"apple_movie";
    [_apple resolve:meta knownIDs:_movieIDs done:^(NSDictionary *source,NSString *error){if(self->_generation==g)[self finish:source error:error ttl:source?0:([self->_apple.diagnostics[@"failure_kind"]isEqual:@"transient"]?60:1800)];}];
}
- (void)lookup:(NSArray *)ids meta:(NSDictionary *)meta generation:(NSUInteger)g {
    if(!ids.count){if(_movieIDs.count)[self lookupAppleMovie:meta generation:g];else [self finish:nil error:@"No compatible preview for this title" ttl:1800];return;}
    NSArray *limited=ids.count>12?[ids subarrayWithRange:NSMakeRange(0,12)]:ids;
    [self fetch:[NSString stringWithFormat:@"https://itunes.apple.com/lookup?id=%@&country=us",[limited componentsJoinedByString:@","]] generation:g done:^(NSDictionary *r){NSDictionary *s=[RWTrailerPolicy source:r ids:limited meta:meta];if(!s&&self->_movieIDs.count)[self lookupAppleMovie:meta generation:g];else [self finish:s error:s?nil:@"No compatible preview for this title" ttl:s?86400:1800];}];
}
- (void)resolve:(NSDictionary *)meta done:(void(^)(NSDictionary *,NSString *))done {[self resolve:meta native:NO done:done];}
- (void)resolveNative:(NSDictionary *)meta done:(void(^)(NSDictionary *,NSString *))done {[self resolve:meta native:YES done:done];}
- (void)resolve:(NSDictionary *)meta native:(BOOL)nativeOnly done:(void(^)(NSDictionary *,NSString *))done {
    NSString *imdb=[meta[@"id"]isKindOfClass:NSString.class]?meta[@"id"]:@"";double now=NSDate.date.timeIntervalSince1970;NSDictionary *cached=_cache[imdb];
    _diagnostics=@{@"imdb":imdb,@"result":@"cache_or_validation",@"native":cached[@"nativeDiagnostics"]?:@{},@"native_error":cached[@"nativeError"]?:@""};
    BOOL runtimeUnavailable=[_cache[@"__embeddedRuntime"][@"unsupportedUntil"]doubleValue]>now;
    NSDictionary *embedded=(!nativeOnly&&!runtimeUnavailable&&[cached[@"embeddedFailedUntil"]doubleValue]<=now)?[RWTrailerPolicy embeddedSource:meta]:nil;
    BOOL movie=[meta[@"type"]isEqual:@"movie"]&&[imdb hasPrefix:@"tt"],series=[meta[@"type"]isEqual:@"series"]&&[imdb hasPrefix:@"tt"];BOOL identityReady=!movie||[RWTrailerPolicy movieIdentityReady:meta];NSString *entityHint=[RWTrailerPolicy cachedEntityID:meta];NSArray *reviewedMovieIDs=[RWApplePreviewPolicy reviewedMovieIDs:_seed[imdb][@"appleMovie"] meta:meta];NSArray *bundledMovieIDs=reviewedMovieIDs.count?reviewedMovieIDs:[RWApplePreviewPolicy movieIDs:_seed[imdb] imdb:imdb];BOOL retryNewIdentity=(entityHint.length&&[cached[@"nativeLookupRevision"]integerValue]<3)||(bundledMovieIDs.count&&[cached[@"nativeLookupRevision"]integerValue]<4);
    if([cached[@"expires"]doubleValue]>now){
        if([cached[@"playbackFailed"]boolValue]&&!nativeOnly){done(nil,@"Preview is temporarily unavailable");return;}
        NSDictionary *prior=cached[@"source"];BOOL youtube=[prior[@"youtubeID"]length]>0;
        if([prior count]&&((youtube&&embedded)||( !youtube&&[cached[@"nativeFailedUntil"]doubleValue]<=now))){NSMutableDictionary *source=[prior mutableCopy];source[@"lookupSeconds"]=@0;source[@"imdb"]=imdb;done(source,nil);return;}
        if(identityReady&&(([cached[@"nativeUnavailableUntil"]doubleValue]>now&&!retryNewIdentity)||[cached[@"nativeFailedUntil"]doubleValue]>now)){done(embedded,embedded?nil:cached[@"nativeError"]?:@"No native preview is available right now");return;}
    }
    if(movie&&![RWTrailerPolicy movieIdentityReady:meta]){_diagnostics=@{@"imdb":imdb,@"result":@"waiting_for_identity",@"native":@{},@"native_error":@"Movie title/year metadata is incomplete"};done(nil,@"Movie title/year metadata is incomplete");return;}
    if(!movie&&!series){done(embedded,embedded?nil:@"No compatible preview is listed for this title");return;}
    NSArray *knownIDs=[RWTrailerPolicy appleIDs:_seed[imdb] imdb:imdb];
    if(movie&&embedded&&!knownIDs.count&&!entityHint.length&&!bundledMovieIDs.count){done(embedded,nil);return;}
    if([_key isEqual:imdb]){if(nativeOnly||runtimeUnavailable)_fallback=nil;[_waiters addObject:[done copy]];return;}if(_key)[self finish:nil error:@"Cancelled" ttl:0];
    if(_backoff>[NSDate date].timeIntervalSince1970){done(embedded,embedded?nil:@"Preview service is busy");return;}
    _key=imdb;_lookupIdentity=@{@"id":imdb,@"name":meta[@"name"]?:@"",@"type":meta[@"type"]?:@"",@"releaseInfo":meta[@"releaseInfo"]?:@""};_appleLookup=series;_movieIDs=bundledMovieIDs;_trace=[NSMutableArray new];_route=series?@"apple_show":knownIDs.count?@"bundled_apple_id":entityHint.length?@"cached_verified_entity":@"identity_search";_fallback=embedded;_waiters=[NSMutableArray arrayWithObject:[done copy]];_began=NSProcessInfo.processInfo.systemUptime;NSUInteger g=++_generation;
    if(!series)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,4*NSEC_PER_SEC),dispatch_get_main_queue(),^{if(self->_generation==g&&!self->_appleLookup)[self finish:nil error:@"Preview unavailable right now" ttl:60];});
    if(series){[_apple resolve:meta knownIDs:[RWApplePreviewPolicy showIDs:_seed[imdb] imdb:imdb] done:^(NSDictionary *source,NSString *error){if(self->_generation==g)[self finish:source error:error ttl:source?0:([self->_apple.diagnostics[@"failure_kind"]isEqual:@"transient"]?60:1800)];}];return;}
    if(_movieIDs.count&&!knownIDs.count){[self lookupAppleMovie:meta generation:g];return;}
    NSArray *ids=[RWTrailerPolicy appleIDs:_seed[imdb] imdb:imdb];if(ids.count){[self lookup:ids meta:meta generation:g];return;}
    if(entityHint.length){
        [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/wiki/Special:EntityData/%@.json",entityHint] generation:g done:^(NSDictionary *r){
            NSDictionary *entities=[r[@"entities"]isKindOfClass:NSDictionary.class]?r[@"entities"]:@{};
            // Revalidate the exact IMDb claim; cached labels or a stale Q-ID
            // alone never authorize a preview for another movie.
            self->_movieIDs=[RWApplePreviewPolicy movieIDs:entities[entityHint] imdb:imdb];[self lookup:[RWTrailerPolicy appleIDs:entities[entityHint] imdb:imdb] meta:meta generation:g];
        }];return;
    }
    NSString *query=[[@"haswbstatement:P345=" stringByAppendingString:imdb]stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=query&list=search&format=json&maxlag=5&srlimit=3&srnamespace=0&srprop=&srsearch=%@",query] generation:g done:^(NSDictionary *r){NSMutableArray *qids=[NSMutableArray new];for(NSDictionary *row in r[@"query"][@"search"]){NSString *qid=row[@"title"];if([qid isKindOfClass:NSString.class]&&[qid hasPrefix:@"Q"])[qids addObject:qid];}
        if(!qids.count){[self finish:nil error:@"No compatible preview for this title" ttl:1800];return;}
        [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&maxlag=5&props=claims&ids=%@",[qids componentsJoinedByString:@"%7C"]] generation:g done:^(NSDictionary *r){NSMutableOrderedSet *all=[NSMutableOrderedSet new];NSMutableOrderedSet *movies=[NSMutableOrderedSet new];for(NSDictionary *e in [r[@"entities"]allValues]){[all addObjectsFromArray:[RWTrailerPolicy appleIDs:e imdb:imdb]];[movies addObjectsFromArray:[RWApplePreviewPolicy movieIDs:e imdb:imdb]];}self->_movieIDs=movies.array;[self lookup:all.array meta:meta generation:g];}];
    }];
}
- (void)cancel:(NSString *)identifier {if(identifier.length&&[_key isEqual:identifier])[self finish:nil error:@"Cancelled" ttl:0];}
- (void)dealloc {[_apple invalidate];[[RWMetadataBudget shared]cancel:_task];[_session invalidateAndCancel];}
@end
