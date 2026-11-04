#import "RWEntityCreditPolicy.h"
#import "RWMetadataBudget.h"
#import "RWDiscoveryMetadata.h"
#import "RWWorldCatalog.h"
#import "RWDiscoveryMetadataPolicy.h"
#import "RWAtomicWriter.h"
#import "RWCast.h"
#import "RWEntityDetailsPolicy.h"
#import "RWEntitySearchPolicy.h"
static NSString *MT(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static NSDictionary *MD(id x){return [x isKindOfClass:NSDictionary.class]?x:@{};}
static NSArray *MA(id x){return [x isKindOfClass:NSArray.class]?x:@[];}
static NSString *ME(NSString *s){return [s stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"]];}
static id MV(id raw){NSDictionary *s=MD(raw);return [s[@"rank"]isEqual:@"deprecated"]?nil:MD(MD(s[@"mainsnak"])[@"datavalue"])[@"value"];}
static NSString *MID(NSDictionary *m){return MT(m[@"id"]?:m[@"imdb_id"]);}
static NSDictionary *MRead(NSString *path){NSData *d=[NSData dataWithContentsOfFile:path];return d.length<=8*1024*1024?MD(d?[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]:nil):@{};}
#include "RWEntityPhotoCache.h"
@interface RWDiscoveryMetadata () <NSURLSessionDataDelegate>
@end
@implementation RWDiscoveryMetadata {
    NSDictionary *_collectionSeed;NSUInteger _searchStarted,_searchCancelled,_searchCacheHits;NSMutableArray *_searchEvents;BOOL _invalidated;
    NSString *_path;NSMutableDictionary *_cache,*_cooldowns,*_failures,*_entities,*_entityWaiters,*_detailWaiters,*_searchPages,*_searchTypes,*_personLinks,*_personWaiters,*_photoRecoveries;NSMutableArray *_jobs,*_searchPageOrder,*_searchTypeOrder;NSDictionary *_active,*_diagnostics;NSURLSession *_session;NSURLSessionDataTask *_task;NSUInteger _generation,_requestGeneration;BOOL _paused,_writeScheduled;dispatch_queue_t _persistenceQueue;NSMutableData *_responseData;NSHTTPURLResponse *_response;void(^_responseDone)(NSDictionary *,NSString *);
}
- (instancetype)initWithPath:(NSString *)path bundled:(NSString *)bundled {
    return [self initWithPath:path cached:MRead(path) seed:MRead(bundled)];
}
- (instancetype)initWithPath:(NSString *)path cached:(NSDictionary *)cached seed:(NSDictionary *)seed {
    if((self=[super init])){_path=path;_searchEvents=[NSMutableArray new];_persistenceQueue=dispatch_queue_create("org.local.rewind.metadata-persistence",DISPATCH_QUEUE_SERIAL);_cache=[MD(seed[@"titles"])mutableCopy];[_cache addEntriesFromDictionary:MD(cached[@"titles"])];_collectionSeed=MD(seed[@"collectionEntities"]);for(NSString *key in _cache.allKeys)_cache[key]=[RWDiscoveryMetadataPolicy normalizeCollections:MD(_cache[key]) entities:_collectionSeed];_entities=[MD(cached[@"entities"])mutableCopy];_personLinks=[MD(cached[@"personLinks"])mutableCopy];_personWaiters=[NSMutableDictionary new];_photoRecoveries=[NSMutableDictionary new];_entityWaiters=[NSMutableDictionary new];_detailWaiters=[NSMutableDictionary new];_searchPages=[NSMutableDictionary new];_searchPageOrder=[NSMutableArray new];_searchTypes=[NSMutableDictionary new];_searchTypeOrder=[NSMutableArray new];_jobs=[NSMutableArray new];_cooldowns=[NSMutableDictionary new];_failures=[NSMutableDictionary new];_paused=YES;_diagnostics=@{};
        // Reviewed raw exact-ID entities can add missing year evidence to an
        // existing cache without replacing its other fields or refreshing its TTL.
        for(NSString *key in MD(seed[@"releaseYearEntities"])){
            NSDictionary *entity=MD(seed[@"releaseYearEntities"][key]),*current=MD(_cache[key]);
            NSDictionary *review=[RWDiscoveryMetadataPolicy recordForEntity:entity imdb:key labels:@{}];
            if([current[@"imdb"]isEqual:key]&&[current[@"entityID"]isEqual:review[@"entityID"]]&&!current[@"releaseYearEvidence"]&&review[@"releaseYearEvidence"]){NSMutableDictionary *copy=[current mutableCopy];copy[@"releaseYearEvidence"]=review[@"releaseYearEvidence"];_cache[key]=copy;}
        }
        NSURLSessionConfiguration *c=[[self class]sessionConfiguration];c.timeoutIntervalForRequest=6;c.timeoutIntervalForResource=8;c.HTTPMaximumConnectionsPerHost=1;c.HTTPAdditionalHeaders=@{@"User-Agent":@"Rewind/0.53 (standalone personal iPad experiment; org.local.ministreamlab)",@"Accept":@"application/json"};_session=[NSURLSession sessionWithConfiguration:c delegate:self delegateQueue:NSOperationQueue.mainQueue];
    }return self;
}
+ (NSURLSessionConfiguration *)sessionConfiguration {return [NSURLSessionConfiguration ephemeralSessionConfiguration];}
+ (NSURL *)URLForRequest:(NSString *)url {
    if(![url isKindOfClass:NSString.class])return nil;
    // iOS 9 rejects raw Wikidata property separators. Modern NSURL silently
    // escapes them, which concealed this failure in host-only transport tests.
    NSURL *value=[NSURL URLWithString:[url stringByReplacingOccurrencesOfString:@"|" withString:@"%7C"]];
    return [value.scheme.lowercaseString isEqual:@"https"]&&value.host.length&&!value.user&&!value.password?value:nil;
}
- (NSDictionary *)diagnostics{NSMutableDictionary *d=[_diagnostics mutableCopy];d[@"active_kind"]=_active[@"kind"]?:@"";d[@"active_entity"]=_active[@"entity"]?:@"";d[@"active_role"]=_active[@"role"]?:@"";d[@"queued"]=@(_jobs.count);d[@"paused"]=@(_paused);return d;}
- (void)recordEntitySearch:(NSDictionary *)job outcome:(NSString *)outcome {
    [_searchEvents addObject:@{@"query":job[@"query"]?:@"",@"kind":job[@"scope"]?:@"",@"outcome":outcome,@"response_received":@(_response!=nil),@"bytes":@(_responseData.length)}];while(_searchEvents.count>16)[_searchEvents removeObjectAtIndex:0];
}
- (NSDictionary *)entitySearchDiagnostics {
    BOOL active=[_active[@"kind"]isEqual:@"entitySearch"];
    return @{@"started":@(_searchStarted),@"cancelled":@(_searchCancelled),@"cache_hits":@(_searchCacheHits),@"events":[_searchEvents copy],@"active":@(active),@"query":active?_active[@"query"]:@"",@"response_received":@(active&&_task&&_response),@"bytes":@(_responseData.length),@"paused":@(_paused)};
}
- (void)invalidate {_invalidated=YES;[self cancelPending];[_session invalidateAndCancel];}
- (NSDictionary *)record:(NSString *)imdb {return MD(_cache[imdb]);}
- (NSDictionary *)entitySnapshot {return [_entities copy];}
- (NSDictionary *)cachedEntity:(NSString *)key {
    NSDictionary *record=_entities[key];double now=NSDate.date.timeIntervalSince1970;if(record&&now-[record[@"accessedAt"]doubleValue]>60){NSMutableDictionary *touched=[record mutableCopy];touched[@"accessedAt"]=@(now);record=[touched copy];_entities[key]=record;[self persist];}return record;
}
- (NSDictionary *)titleSnapshot {return [_cache copy];} // Records are replaced, never mutated after publication.
- (NSDictionary *)enrich:(NSDictionary *)meta {return [RWDiscoveryMetadataPolicy enrich:meta record:[self record:MID(meta)]];}
- (BOOL)paused{return _paused;}
- (void)setPaused:(BOOL)paused {if(_paused==paused)return;_paused=paused;if(paused){_generation++;[[RWMetadataBudget shared]cancel:_task];_task=nil;_responseData=nil;_responseDone=nil;if(_active){[_jobs insertObject:_active atIndex:0];_active=nil;}}else [self next];}
- (void)cancelPending {_generation++;[[RWMetadataBudget shared]cancel:_task];_task=nil;_responseData=nil;_responseDone=nil;[_jobs removeAllObjects];[_entityWaiters removeAllObjects];[_detailWaiters removeAllObjects];[_personWaiters removeAllObjects];_active=nil;}
- (void)persist {
    if(_writeScheduled)return;_writeScheduled=YES;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{self->_writeScheduled=NO;
        if(self->_cache.count>500){NSArray *keys=[self->_cache keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"fetchedAt"]?:@0 compare:b[@"fetchedAt"]?:@0];}];for(NSUInteger i=0;i<keys.count-500;i++)[self->_cache removeObjectForKey:keys[i]];}
        if(self->_entities.count>64){NSArray *keys=[self->_entities keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"accessedAt"]?:a[@"at"]?:@0 compare:b[@"accessedAt"]?:b[@"at"]?:@0];}];for(NSUInteger i=0;i<keys.count-64;i++)[self->_entities removeObjectForKey:keys[i]];}if(self->_personLinks.count>64){NSArray *keys=[self->_personLinks keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"at"]?:@0 compare:b[@"at"]?:@0];}];for(NSUInteger i=0;i<keys.count-64;i++)[self->_personLinks removeObjectForKey:keys[i]];}NSDictionary *snapshot=@{@"personLinks":[self->_personLinks copy],@"titles":[self->_cache copy],@"entities":[self->_entities copy],@"version":@1};NSString *path=self->_path;dispatch_async(self->_persistenceQueue,^{NSData *data=[NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil];if(data.length<=8*1024*1024)[[RWAtomicWriter shared]write:data path:path];});
    });
}
- (void)accept:(NSDictionary *)record imdb:(NSString *)imdb {
    if(!record.count||![record[@"imdb"]isEqual:imdb])return;NSMutableDictionary *saved=[record mutableCopy];saved[@"fetchedAt"]=@(NSDate.date.timeIntervalSince1970);if(!saved[@"artwork"]&&[_cache[imdb][@"artwork"]isKindOfClass:NSDictionary.class])saved[@"artwork"]=_cache[imdb][@"artwork"];_cache[imdb]=saved;[self persist];[[NSNotificationCenter defaultCenter]postNotificationName:@"RWDiscoveryMetadataUpdated" object:self userInfo:@{@"id":imdb}];
}
- (void)fetch:(NSString *)url generation:(NSUInteger)g done:(void(^)(NSDictionary *,NSString *))done {
    if(g!=_generation||_paused)return;NSURL *address=[[self class]URLForRequest:url];if(!address){done(nil,@"Invalid metadata address.");return;}
    NSString *host=address.host;double cooldown=[_cooldowns[host]doubleValue];if(cooldown>NSDate.date.timeIntervalSince1970){done(nil,@"Metadata provider is resting; cached details remain available.");return;}
    _requestGeneration=g;_responseDone=[done copy];_responseData=[NSMutableData new];_response=nil;_task=[_session dataTaskWithURL:address];BOOL foreground=_active[@"foreground"]?[_active[@"foreground"]boolValue]:_active[@"done"]!=nil;_task.priority=foreground?NSURLSessionTaskPriorityDefault:NSURLSessionTaskPriorityLow;[[RWMetadataBudget shared]enqueue:_task foreground:foreground];
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void(^)(NSURLSessionResponseDisposition))completion {
    if(task!=_task||_requestGeneration!=_generation||_paused){completion(NSURLSessionResponseCancel);return;}
    _response=[response isKindOfClass:NSHTTPURLResponse.class]?(NSHTTPURLResponse *)response:nil;
    completion(response.expectedContentLength>4*1024*1024?NSURLSessionResponseCancel:NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if(task!=_task||_requestGeneration!=_generation||_paused)return;
    if(_responseData.length+data.length>4*1024*1024){[[RWMetadataBudget shared]cancel:task];return;}[_responseData appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [[RWMetadataBudget shared]complete:task];
    if(task!=_task||_requestGeneration!=_generation||_paused)return;_task=nil;NSUInteger generation=_generation;NSData *data=[_responseData copy];_responseData=nil;NSHTTPURLResponse *response=_response;_response=nil;void(^done)(NSDictionary *,NSString *)=_responseDone;_responseDone=nil;NSString *host=task.originalRequest.URL.host;NSInteger status=response.statusCode;
    if(status==429||status==503){NSString *retry=MT(response.allHeaderFields[@"Retry-After"]?:response.allHeaderFields[@"retry-after"]);double delay=retry.doubleValue;if(delay<=0&&retry.length){NSDateFormatter *f=[NSDateFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];f.dateFormat=@"EEE, dd MMM yyyy HH:mm:ss z";delay=[[f dateFromString:retry]timeIntervalSinceNow];}_cooldowns[host]=@(NSDate.date.timeIntervalSince1970+MAX(120,delay));}
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0),^{@autoreleasepool{id parsed=!error&&status==200?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;NSString *path=task.originalRequest.URL.path;NSRange imagePath=[path rangeOfString:@"^/shows/[1-9][0-9]*/images$" options:NSRegularExpressionSearch];if([task.originalRequest.URL.host isEqual:@"api.tvmaze.com"]&&imagePath.location==0&&imagePath.length==path.length&&[parsed isKindOfClass:NSArray.class])parsed=@{@"images":parsed};dispatch_async(dispatch_get_main_queue(),^{if(generation!=self->_generation||self->_paused)return;NSString *failure=error.localizedDescription;if(!failure&&(![parsed isKindOfClass:NSDictionary.class]||parsed[@"error"]))failure=[NSString stringWithFormat:@"Metadata unavailable (%ld)",(long)status];self->_diagnostics=@{@"host":host?:@"",@"http":@(status),@"bytes":@(data.length),@"queued":@(self->_jobs.count),@"error":failure?:@""};if(done)done(failure?nil:parsed,failure);});}});
}
- (void)finish { if(_failures.count>500)[_failures removeAllObjects];_active=nil;_task=nil;[self next]; }
- (void)enqueue:(NSArray *)items {
    NSUInteger added=0;for(NSDictionary *meta in items){if(_jobs.count>=24)break;NSString *imdb=MID(meta);if(![imdb hasPrefix:@"tt"]||[_failures[imdb]doubleValue]>NSDate.date.timeIntervalSince1970)continue;NSDictionary *record=[self record:imdb];if([record[@"entityID"]length]&&NSDate.date.timeIntervalSince1970-[record[@"fetchedAt"]doubleValue]<30*86400)continue;
        BOOL exists=[_active[@"key"]isEqual:imdb];for(NSDictionary *job in _jobs)if([job[@"key"]isEqual:imdb])exists=YES;if(exists)continue;
        [_jobs addObject:@{@"kind":@"title",@"key":imdb,@"meta":meta}];if(++added>=12||_jobs.count>=24)break;
    }[self next];
}
- (BOOL)isResolvingItems:(NSArray *)items {
    for(NSDictionary *meta in items){NSString *key=MID(meta);if(!key.length)continue;
        if([_active[@"kind"]isEqual:@"title"]&&[_active[@"key"]isEqual:key])return YES;
        for(NSDictionary *job in _jobs)if([job[@"kind"]isEqual:@"title"]&&[job[@"key"]isEqual:key])return YES;
    }return NO;
}
- (void)prioritizeTitles:(NSArray *)items {
    if(_invalidated)return;NSMutableArray *promoted=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];double now=NSDate.date.timeIntervalSince1970;
    for(NSDictionary *meta in items){NSString *key=MID(meta);if(promoted.count==4)break;
        if([key rangeOfString:@"^tt[0-9]+$" options:NSRegularExpressionSearch].location!=0||[seen containsObject:key])continue;[seen addObject:key];
        if([_active[@"kind"]isEqual:@"title"]&&[_active[@"key"]isEqual:key])continue;
        NSUInteger existing=[_jobs indexOfObjectPassingTest:^BOOL(NSDictionary *job,NSUInteger idx,BOOL *stop){return [job[@"kind"]isEqual:@"title"]&&[job[@"key"]isEqual:key];}];
        if(existing!=NSNotFound){NSDictionary *job=_jobs[existing];if(job[@"done"]||[job[@"foreground"]boolValue])continue;[_jobs removeObjectAtIndex:existing];[promoted addObject:job];continue;}
        NSDictionary *record=[self record:key];if([_failures[key]doubleValue]>now||([record[@"entityID"]length]&&now-[record[@"fetchedAt"]doubleValue]<30*86400))continue;
        if(_jobs.count+promoted.count>=24){NSUInteger drop=[_jobs indexOfObjectWithOptions:NSEnumerationReverse passingTest:^BOOL(NSDictionary *job,NSUInteger idx,BOOL *stop){return [job[@"kind"]isEqual:@"title"]&&!job[@"done"]&&![job[@"foreground"]boolValue];}];if(drop==NSNotFound)continue;[_jobs removeObjectAtIndex:drop];}
        [promoted addObject:@{@"kind":@"title",@"key":key,@"meta":meta}];
    }
    // Explicit detail/credits requests retain priority. Never cancel an active
    // request or duplicate its work just because a shelf reached its end.
    NSUInteger position=0;while(position<_jobs.count&&(_jobs[position][@"done"]||[_jobs[position][@"foreground"]boolValue]))position++;
    if(promoted.count)[_jobs insertObjects:promoted atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(position,promoted.count)]];
    [self next];
}
- (void)resolve:(NSDictionary *)meta done:(void(^)(NSDictionary *,NSString *))done {
    NSDictionary *record=[self record:MID(meta)];if([record[@"entityID"]length]){done(record,nil);return;}
    if(![MID(meta)hasPrefix:@"tt"]){done(nil,@"No verified metadata identity for this title.");return;}
    if(_jobs.count>=24||[_failures[MID(meta)]doubleValue]>NSDate.date.timeIntervalSince1970){done(nil,@"Metadata is temporarily unavailable. Try again later.");return;}
    [_jobs insertObject:@{@"kind":@"title",@"key":MID(meta),@"meta":meta,@"done":[done copy]} atIndex:0];[self yieldBackgroundCredits];[self next];
}
- (void)credits:(NSString *)entityID role:(NSString *)role offset:(NSUInteger)offset done:(void(^)(NSArray *,BOOL,NSString *))done {
    [self creditPage:entityID role:role continuation:@{@"sroffset":@(offset)} done:^(NSArray *items,NSDictionary *next,NSString *error){done(items,next.count>0,error);}];
}
- (void)creditPage:(NSString *)entityID role:(NSString *)role continuation:(NSDictionary *)continuation done:(void(^)(NSArray *,NSDictionary *,NSString *))done {
    [self creditPage:entityID role:role continuation:continuation owner:@"page" foreground:YES done:done];
}
- (void)yieldBackgroundCredits {
    if(![_active[@"kind"]isEqual:@"credits"]||!_active[@"foreground"]||[_active[@"foreground"]boolValue])return;
    _generation++;[[RWMetadataBudget shared]cancel:_task];_task=nil;_responseData=nil;_responseDone=nil;[_jobs addObject:_active];_active=nil;
}
- (void)creditPage:(NSString *)entityID role:(NSString *)role continuation:(NSDictionary *)continuation owner:(NSString *)owner foreground:(BOOL)foreground done:(void(^)(NSArray *,NSDictionary *,NSString *))done {
    if([MT(entityID) rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location!=0||![RWEntityCreditPolicy property:role]||!MT(owner).length||owner.length>100){done(@[],@{},@"No verified credits identity.");return;}
    if(_jobs.count>=24){done(@[],continuation?:@{},@"Please finish the current lookup first.");return;}
    NSDictionary *job=@{@"kind":@"credits",@"entity":entityID,@"role":role,@"owner":owner,@"foreground":@(foreground),@"offset":MD(continuation)[@"sroffset"]?:@0,@"continuation":MD(continuation),@"done":[done copy]};
    if(foreground){
        [_jobs insertObject:job atIndex:0];[self yieldBackgroundCredits];
        // Also bound queueing/pauses: a foreground page must reach a usable
        // success or retry state even if other metadata or a modal delays it.
        __weak RWDiscoveryMetadata *weak=self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,20*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            RWDiscoveryMetadata *service=weak;if(!service)return;BOOL active=service->_active==job;
            NSUInteger queued=[service->_jobs indexOfObjectIdenticalTo:job];if(!active&&queued==NSNotFound)return;
            if(active){service->_generation++;[[RWMetadataBudget shared]cancel:service->_task];service->_task=nil;service->_responseData=nil;service->_responseDone=nil;}
            else [service->_jobs removeObjectAtIndex:queued];
            void(^complete)(NSArray *,NSDictionary *,NSString *)=job[@"done"];complete(@[],job[@"continuation"],@"Credits are taking too long to load. Please try again.");
            if(active)[service finish];else [service next];
        });
    }else [_jobs addObject:job];[self next];
}
- (void)worldPage:(NSDictionary *)continuation owner:(NSString *)owner done:(void(^)(NSArray *,NSDictionary *,NSString *))done {
    NSDictionary *cursor=RWWorldCursor(continuation?:@{});
    if(!cursor||!MT(owner).length||owner.length>100){done(@[],continuation?:@{},@"Invalid World Cinema continuation.");return;}
    if(_jobs.count>=24){done(@[],cursor,@"Please finish the current lookup first.");return;}
    [_jobs addObject:@{@"kind":@"credits",@"world":@YES,@"entity":@"world",@"role":@"world",@"owner":owner,@"foreground":@NO,@"offset":cursor[@"sroffset"]?:@0,@"continuation":cursor,@"done":[done copy]}];[self next];
}
- (void)cancelCreditJobs:(BOOL(^)(NSDictionary *))matches {
    NSIndexSet *indices=[_jobs indexesOfObjectsPassingTest:^BOOL(NSDictionary *job,NSUInteger idx,BOOL *stop){return matches(job);}];[_jobs removeObjectsAtIndexes:indices];
    if(matches(_active)){_generation++;[[RWMetadataBudget shared]cancel:_task];_task=nil;_responseData=nil;_responseDone=nil;_active=nil;}
    __weak RWDiscoveryMetadata *weak=self;dispatch_async(dispatch_get_main_queue(),^{[weak next];});
}
- (void)cancelCredits:(NSString *)entityID role:(NSString *)role {
    [self cancelCreditJobs:^BOOL(NSDictionary *job){return [job[@"kind"]isEqual:@"credits"]&&[job[@"owner"]isEqual:@"page"]&&[job[@"entity"]isEqual:entityID]&&[job[@"role"]isEqual:role];}];
}
- (void)cancelCreditRequestsForOwner:(NSString *)owner {
    if(!MT(owner).length)return;[self cancelCreditJobs:^BOOL(NSDictionary *job){return [job[@"kind"]isEqual:@"credits"]&&[job[@"owner"]isEqual:owner];}];
}
#include "RWTitleArtwork.inc"
- (void)next {
    if(_invalidated||_paused||_active||!_jobs.count)return;_active=_jobs.firstObject;[_jobs removeObjectAtIndex:0];NSUInteger g=++_generation;NSDictionary *job=_active;
    if([job[@"kind"]isEqual:@"titleArtwork"]){[self startTitleArtwork:job generation:g];return;}
    if([job[@"kind"]isEqual:@"personIdentity"]){[self startPersonIdentity:job generation:g];return;}
    if([job[@"kind"]isEqual:@"entitySearch"]){[self startEntitySearch:job generation:g];return;}
    if([job[@"kind"]isEqual:@"entityDetails"]){[self startEntityDetails:job generation:g];return;}
    if([job[@"kind"]isEqual:@"entity"]){[self startEntity:job generation:g];return;}
    if([job[@"kind"]isEqual:@"credits"]){[self startCredits:job generation:g];return;}
    NSDictionary *meta=job[@"meta"];NSString *imdb=MID(meta);void(^done)(NSDictionary *,NSString *)=job[@"done"];
    [self wikiTitle:imdb generation:g done:^(NSDictionary *record,NSString *error){
        if([meta[@"type"]isEqual:@"series"]){[self fetch:[NSString stringWithFormat:@"https://api.tvmaze.com/lookup/shows?imdb=%@",ME(imdb)] generation:g done:^(NSDictionary *show,NSString *tvError){
            NSMutableDictionary *merged=[record mutableCopy]?:[NSMutableDictionary new];BOOL exact=[MD(show[@"externals"])[@"imdb"]isEqual:imdb];NSString *language=MT(show[@"language"]);
            if(exact&&language.length){merged[@"imdb"]=imdb;merged[@"primaryLanguage"]=[language isEqual:@"English"]?@"en":language;merged[@"languageSource"]=MT(show[@"url"]);if(!merged[@"industry"])merged[@"industry"]=@"unknown";}
            if(merged.count)[self accept:merged imdb:imdb];else self->_failures[imdb]=@(NSDate.date.timeIntervalSince1970+900);if(done)done(merged.count?merged:nil,merged.count?nil:error?:tvError);[self finish];
        }];}else{if(record)[self accept:record imdb:imdb];else self->_failures[imdb]=@(NSDate.date.timeIntervalSince1970+900);if(done)done(record,error);[self finish];}
    }];
}
#include "RWPersonIdentity.inc"
- (void)labelsFor:(NSArray *)entities generation:(NSUInteger)g done:(void(^)(NSDictionary *))done {
    NSArray *batch=[RWDiscoveryMetadataPolicy labelIDsForEntities:entities];if(!batch.count){done(@{});return;}
    [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=labels&languages=en%%7Cmul&ids=%@",ME([batch componentsJoinedByString:@"|"])] generation:g done:^(NSDictionary *json,NSString *error){NSMutableDictionary *labels=[MD(json[@"entities"])mutableCopy];NSMutableOrderedSet *unknown=[NSMutableOrderedSet new];
        for(NSDictionary *entity in entities)for(NSString *qid in [RWDiscoveryMetadataPolicy collectionIDs:entity]){NSDictionary *known=MD(self->_collectionSeed[qid]);if(known.count)labels[qid]=known;else if(unknown.count<12)[unknown addObject:qid];}
        if(!unknown.count){done(labels);return;}
        // Only collection identities need claims, never every actor/language.
        // One bounded request shares this job's existing cancellation/budget.
        [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=labels%%7Cclaims&languages=en%%7Cmul&ids=%@",ME([unknown.array componentsJoinedByString:@"|"])] generation:g done:^(NSDictionary *types,NSString *typeError){
            for(NSString *qid in unknown){NSDictionary *value=MD(MD(types[@"entities"])[qid]);if([value[@"id"]isEqual:qid])labels[qid]=value;}
            done(labels);
        }];
    }];
}
- (void)wikiTitle:(NSString *)imdb generation:(NSUInteger)g done:(void(^)(NSDictionary *,NSString *))done {
    NSString *query=[@"haswbstatement:P345=" stringByAppendingString:imdb];
    [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=query&list=search&format=json&srnamespace=0&srprop=&srlimit=3&srsearch=%@",ME(query)] generation:g done:^(NSDictionary *search,NSString *error){
        NSMutableArray *ids=[NSMutableArray new];for(NSDictionary *row in MA(MD(search[@"query"])[@"search"]))if([MT(row[@"title"])hasPrefix:@"Q"])[ids addObject:row[@"title"]];if(!ids.count){done(nil,error?:@"No verified title metadata yet.");return;}
        [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=claims|labels&languages=en%%7Cmul&ids=%@",ME([ids componentsJoinedByString:@"|"])] generation:g done:^(NSDictionary *json,NSString *error){
            NSMutableArray *matches=[NSMutableArray new];for(NSDictionary *entity in MD(json[@"entities"]).allValues)if([RWDiscoveryMetadataPolicy recordForEntity:entity imdb:imdb labels:@{}])[matches addObject:entity];
            if(matches.count!=1){done(nil,error?:@"Title identity is missing or ambiguous.");return;}
            [self labelsFor:matches generation:g done:^(NSDictionary *labels){done([RWDiscoveryMetadataPolicy recordForEntity:matches[0] imdb:imdb labels:labels],nil);}];
        }];
    }];
}
- (void)startCredits:(NSDictionary *)job generation:(NSUInteger)g {
    BOOL world=[job[@"world"]boolValue];
    {__weak RWDiscoveryMetadata *weak=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,12*NSEC_PER_SEC),dispatch_get_main_queue(),^{RWDiscoveryMetadata *service=weak;if(!service||g!=service->_generation||service->_active!=job||service->_paused)return;service->_generation++;[[RWMetadataBudget shared]cancel:service->_task];service->_task=nil;service->_responseData=nil;service->_responseDone=nil;void(^done)(NSArray *,NSDictionary *,NSString *)=job[@"done"];done(@[],job[@"continuation"],world?@"World Cinema lookup deadline.":[job[@"foreground"]boolValue]?@"Credits are taking too long to load. Please try again.":@"Background credits refresh deadline.");[service finish];});}
    NSString *property=[RWEntityCreditPolicy property:job[@"role"]];NSString *query=world?RWWorldCatalogQuery():[NSString stringWithFormat:@"haswbstatement:%@=%@ haswbstatement:P345 -haswbstatement:P31=Q21191270",property,job[@"entity"]];void(^done)(NSArray *,NSDictionary *,NSString *)=job[@"done"];
    NSString *token=MT(MD(job[@"continuation"])[@"continue"]);NSString *url=[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=query&list=search&format=json&srnamespace=0&srprop=&srlimit=8&sroffset=%@&srsearch=%@&continue=%@",job[@"offset"],ME(query),ME(token)];
    [self fetch:url generation:g done:^(NSDictionary *search,NSString *error){
        if(error){done(@[],job[@"continuation"],error);[self finish];return;}
        NSDictionary *next=MD(search[@"continue"]);if(world&&(!RWWorldCursor(next)||(next.count&&([next[@"sroffset"]longLongValue]<=[job[@"offset"]longLongValue]||[next[@"sroffset"]longLongValue]>[job[@"offset"]longLongValue]+8)))){done(@[],job[@"continuation"],@"Invalid World Cinema continuation.");[self finish];return;}if(next.count&&(![next[@"sroffset"]isKindOfClass:NSNumber.class]||[next[@"sroffset"]longLongValue]<=[job[@"offset"]longLongValue]||MT(next[@"continue"]).length>128)){done(@[],job[@"continuation"],@"The credits provider returned an invalid continuation. Try again later.");[self finish];return;}
        NSMutableArray *ids=[NSMutableArray new];for(NSDictionary *row in MA(MD(search[@"query"])[@"search"]))if([MT(row[@"title"])hasPrefix:@"Q"])[ids addObject:row[@"title"]];
        if(world&&ids.count>8){done(@[],job[@"continuation"],@"World Cinema page exceeds its limit.");[self finish];return;}
        if(!ids.count){done(@[],next,error);[self finish];return;}
        [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=claims|labels&languages=en%%7Cmul&ids=%@",ME([ids componentsJoinedByString:@"|"])] generation:g done:^(NSDictionary *json,NSString *error){
            NSMutableArray *entities=[NSMutableArray new];for(NSString *key in ids){NSDictionary *entity=MD(MD(json[@"entities"])[key]);if([entity[@"id"]isEqual:key])[entities addObject:entity];}if(!entities.count){done(@[],job[@"continuation"],error?:@"Credits could not be verified. Try again.");[self finish];return;}
            [self labelsFor:entities generation:g done:^(NSDictionary *labels){NSMutableArray *titles=[NSMutableArray new];
                for(NSDictionary *entity in entities){NSArray *imdbs=world?[RWDiscoveryMetadataPolicy worldFilmIDs:entity]:[RWDiscoveryMetadataPolicy creditIDs:entity role:job[@"role"] entityID:job[@"entity"]];if(imdbs.count!=1)continue;
                    NSString *name=[RWDiscoveryMetadataPolicy displayName:entity];if(!name.length)continue;NSString *type=[RWDiscoveryMetadataPolicy creditTypeForEntity:entity labels:labels];
                    if(![@[@"movie",@"series"]containsObject:type])continue;NSString *imdb=imdbs[0];NSDictionary *record=[RWDiscoveryMetadataPolicy recordForEntity:entity imdb:imdb labels:labels];if(world&&(![type isEqual:@"movie"]||![[RWDiscoveryMetadataPolicy languageGroup:record]isEqual:@"world"]))continue;[self accept:record imdb:imdb];
                    NSString *year=[RWDiscoveryMetadataPolicy creditReleaseYearForEntity:entity type:type];
                    [titles addObject:@{@"id":imdb,@"type":type,@"name":name,@"releaseInfo":year,@"discovery":record?:@{},@"creditEntityID":job[@"entity"],@"creditRole":job[@"role"]}];
                }done(titles,next,nil);[self finish];
            }];
        }];
    }];
}
- (void)entity:(NSString *)entityID done:(void(^)(NSDictionary *,NSString *))done {[self entity:entityID role:@"person" done:done];}
- (void)entity:(NSString *)entityID role:(NSString *)role done:(void(^)(NSDictionary *,NSString *))done {
    if([entityID rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location!=0){done(nil,@"No verified identity.");return;}
    role=[role isEqual:@"studio"]?@"studio":@"person";NSString *key=[NSString stringWithFormat:@"%@:%@",entityID,role];NSDictionary *cached=[self cachedEntity:key];
    if(cached&&NSDate.date.timeIntervalSince1970<MEntityExpiry(cached,@"expires")){done(cached,nil);return;}
    NSMutableArray *waiters=_entityWaiters[key];if(waiters){if(waiters.count<8)[waiters addObject:[done copy]];else done(nil,@"Metadata is busy.");return;}
    if(_jobs.count>=24||[_failures[key]doubleValue]>NSDate.date.timeIntervalSince1970){done(nil,@"Metadata is busy. Cached details remain available.");return;}
    _entityWaiters[key]=[NSMutableArray arrayWithObject:[done copy]];__weak RWDiscoveryMetadata *weak=self;
    void(^deliver)(NSDictionary *,NSString *)=^(NSDictionary *record,NSString *error){RWDiscoveryMetadata *service=weak;if(!service)return;NSArray *callbacks=[service->_entityWaiters[key]copy];[service->_entityWaiters removeObjectForKey:key];if(error)service->_failures[key]=@(NSDate.date.timeIntervalSince1970+60);for(void(^callback)(NSDictionary *,NSString *) in callbacks)callback(record,error);};
    [_jobs insertObject:@{@"kind":@"entity",@"entity":entityID,@"role":role,@"key":key,@"done":[deliver copy]} atIndex:0];[self yieldBackgroundCredits];[self next];
}
- (void)entity:(NSString *)entityID role:(NSString *)role failedImage:(NSString *)url done:(void(^)(NSDictionary *,NSString *))done {
    if([MT(entityID)rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location!=0||!MT(url).length){done(nil,@"No verified image identity.");return;}
    role=[role isEqual:@"studio"]?@"studio":@"person";NSString *key=[NSString stringWithFormat:@"%@:%@",entityID,role];NSDictionary *cached=[self cachedEntity:key];NSString *current=MT(cached[@"image"]);
    // An old view must not invalidate a newer replacement chosen for this ID.
    if(current.length&&![current isEqual:url]){done(cached,nil);return;}
    // Join the existing refresh before applying its cooldown to a new request.
    if(_entityWaiters[key]){[self entity:entityID role:role done:done];return;}
    double now=NSDate.date.timeIntervalSince1970,last=MAX([_photoRecoveries[key]doubleValue],[cached[@"photoRecoveryAt"]doubleValue]);
    if(last>0&&now-last<900){done(cached,@"Image refresh is cooling down.");return;}
    if(_photoRecoveries.count>=64&&!_photoRecoveries[key]){NSString *old=[_photoRecoveries keysSortedByValueUsingSelector:@selector(compare:)].firstObject;[_photoRecoveries removeObjectForKey:old];}_photoRecoveries[key]=@(now);
    if(cached){NSMutableDictionary *record=[cached mutableCopy];[record removeObjectForKey:@"image"];[record removeObjectForKey:@"sourceURL"];[record removeObjectForKey:@"credit"];record[@"expires"]=@0;record[@"detailsExpires"]=@0;record[@"photoRecoveryAt"]=@(now);_entities[key]=record;[self persist];}
    [self entity:entityID role:role done:done];
}
- (void)refreshEntityPhoto:(NSMutableDictionary *)profile job:(NSDictionary *)job generation:(NSUInteger)g {
    NSString *file=MT(profile[@"imageFile"]);void(^done)(NSDictionary *,NSString *)=job[@"done"];
    void(^finish)(void)=^{profile[@"photoCheckedAt"]=@(NSDate.date.timeIntervalSince1970);profile[@"expires"]=@([profile[@"photoCheckedAt"]doubleValue]+(file.length&&!MT(profile[@"image"]).length?900:7*86400));self->_entities[job[@"key"]]=[profile copy];[self persist];done([profile copy],nil);[self finish];};
    if(!file.length){finish();return;}
    [self fetch:[NSString stringWithFormat:@"https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=imageinfo&iiprop=url%%7Cextmetadata&iiurlwidth=400&titles=%@",ME([@"File:" stringByAppendingString:file])] generation:g done:^(NSDictionary *photos,NSString *photoError){NSDictionary *photo=[RWCast photos:photos people:@[@{@"imageFile":file,@"name":profile[@"name"]?:@""}]].firstObject;if(photo){[profile addEntriesFromDictionary:photo];if([job[@"role"]isEqual:@"studio"])profile[@"credit"]=[MT(profile[@"credit"])stringByReplacingOccurrencesOfString:@" · Cropped portrait" withString:@" · Logo"];}finish();}];
}
- (void)startEntity:(NSDictionary *)job generation:(NSUInteger)g {
    NSDictionary *cached=MD(_entities[job[@"key"]]);if([cached[@"id"]isEqual:job[@"entity"]]&&NSDate.date.timeIntervalSince1970-[cached[@"searchVerifiedAt"]doubleValue]<600){[self refreshEntityPhoto:[cached mutableCopy] job:job generation:g];return;}
    NSString *qid=job[@"entity"];void(^done)(NSDictionary *,NSString *)=job[@"done"];
    [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=claims%%7Clabels%%7Cdescriptions&languages=en%%7Cmul&ids=%@",qid] generation:g done:^(NSDictionary *json,NSString *error){NSDictionary *entity=MD(MD(json[@"entities"])[qid]);if(![entity[@"id"]isEqual:qid]){done(nil,error?:@"Person details are unavailable.");[self finish];return;}
        NSMutableDictionary *profile=[MD(self->_entities[job[@"key"]])mutableCopy];NSDictionary *basic=[RWDiscoveryMetadataPolicy entityProfile:entity role:job[@"role"]];NSString *oldFile=MT(profile[@"imageFile"]);for(NSString *key in basic){id value=basic[key];if([value isKindOfClass:NSString.class]&&![value length])continue;if([key isEqual:@"biography"]&&MT(profile[@"biographySourceURL"]).length)continue;profile[key]=value;}if(oldFile.length&&![oldFile isEqual:profile[@"imageFile"]]){[profile removeObjectForKey:@"image"];[profile removeObjectForKey:@"sourceURL"];[profile removeObjectForKey:@"credit"];}profile[@"at"]=@(NSDate.date.timeIntervalSince1970);profile[@"accessedAt"]=profile[@"at"];
        [self refreshEntityPhoto:profile job:job generation:g];
    }];
}
- (void)entityDetails:(NSString *)entityID role:(NSString *)role progress:(void(^)(NSDictionary *))progress done:(void(^)(NSDictionary *,NSString *))done {
    if([MT(entityID)rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location!=0){done(nil,@"No verified identity.");return;}
    role=[role isEqual:@"studio"]?@"studio":@"person";NSString *key=[NSString stringWithFormat:@"%@:%@",entityID,role];NSDictionary *cached=[self cachedEntity:key];double now=NSDate.date.timeIntervalSince1970;
    if([cached[@"detailsVersion"]intValue]==1&&MEntityExpiry(cached,@"detailsExpires")>now){done(cached,nil);return;}if(cached&&progress)progress(cached);
    NSDictionary *waiter=@{@"progress":progress?[progress copy]:[^(NSDictionary *m){} copy],@"done":[done copy]};NSMutableArray *waiters=_detailWaiters[key];if(waiters){if(waiters.count<8)[waiters addObject:waiter];else done(cached,@"Metadata is busy.");return;}
    if(_jobs.count>=24||[_failures[[@"details:" stringByAppendingString:key]]doubleValue]>now){done(cached,@"Cached details remain available.");return;}
    _detailWaiters[key]=[NSMutableArray arrayWithObject:waiter];[_jobs insertObject:@{@"kind":@"entityDetails",@"entity":entityID,@"role":role,@"key":key,@"done":@YES} atIndex:0];[self yieldBackgroundCredits];[self next];
}
- (void)publishEntityDetails:(NSDictionary *)record job:(NSDictionary *)job {
    if(![record[@"id"]isEqual:job[@"entity"]])return;NSDictionary *snapshot=[record copy];_entities[job[@"key"]]=snapshot;[self persist];
    for(NSDictionary *waiter in [_detailWaiters[job[@"key"]]copy]){void(^progress)(NSDictionary *)=waiter[@"progress"];progress(snapshot);}
}
- (void)finishEntityDetails:(NSMutableDictionary *)record job:(NSDictionary *)job warnings:(NSArray *)warnings error:(NSString *)error {
    NSString *key=job[@"key"];BOOL valid=[record[@"id"]isEqual:job[@"entity"]];double now=NSDate.date.timeIntervalSince1970;
    if(valid){BOOL missingPhoto=MT(record[@"imageFile"]).length&&!MT(record[@"image"]).length;record[@"detailsVersion"]=@1;record[@"detailsExpires"]=@(now+(warnings.count||missingPhoto?900:7*86400));record[@"detailWarnings"]=warnings?:@[];record[@"expires"]=@(now+(missingPhoto?900:7*86400));_entities[key]=[record copy];[self persist];}
    else _failures[[@"details:" stringByAppendingString:key]]=@(now+60);
    NSArray *callbacks=[_detailWaiters[key]copy];[_detailWaiters removeObjectForKey:key];for(NSDictionary *waiter in callbacks){void(^done)(NSDictionary *,NSString *)=waiter[@"done"];done(valid?[record copy]:_entities[key],error?:valid?nil:@"Entity details are unavailable. Try again later.");}[self finish];
}
- (void)startEntityDetails:(NSDictionary *)job generation:(NSUInteger)g {
    NSString *qid=job[@"entity"];NSMutableDictionary *profile=[MD(_entities[job[@"key"]])mutableCopy];NSMutableArray *warnings=[NSMutableArray new];
    // Bound the entire enrichment chain, not just each individual connection.
    __weak RWDiscoveryMetadata *weak=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,8*NSEC_PER_SEC),dispatch_get_main_queue(),^{RWDiscoveryMetadata *service=weak;if(!service||g!=service->_generation||service->_active!=job||service->_paused)return;service->_generation++;[[RWMetadataBudget shared]cancel:service->_task];service->_task=nil;service->_responseData=nil;service->_responseDone=nil;[warnings addObject:@"Details refresh deadline"];[service finishEntityDetails:profile job:job warnings:warnings error:nil];});
    NSString *url=[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=claims%%7Clabels%%7Cdescriptions%%7Csitelinks&sitefilter=enwiki&languages=en%%7Cmul&ids=%@",qid];
    [self fetch:url generation:g done:^(NSDictionary *json,NSString *error){NSDictionary *entity=MD(MD(json[@"entities"])[qid]);if(![entity[@"id"]isEqual:qid]){[warnings addObject:error?:@"Entity identity unavailable"];[self finishEntityDetails:profile job:job warnings:warnings error:error];return;}
        NSDictionary *basic=[RWEntityDetailsPolicy details:entity role:job[@"role"] labels:@{}];NSString *oldFile=MT(profile[@"imageFile"]);for(NSString *key in basic){id value=basic[key];if([value respondsToSelector:@selector(length)]&&[value length]==0)continue;if([value isKindOfClass:NSArray.class]&&![value count])continue;if([key isEqual:@"biography"]&&MT(profile[@"biographySourceURL"]).length)continue;profile[key]=value;}
        profile[@"at"]=@(NSDate.date.timeIntervalSince1970);profile[@"accessedAt"]=profile[@"at"];NSString *file=MT(profile[@"imageFile"]);if(oldFile.length&&![oldFile isEqual:file]){[profile removeObjectForKey:@"image"];[profile removeObjectForKey:@"sourceURL"];[profile removeObjectForKey:@"credit"];}[self publishEntityDetails:profile job:job];
        void(^biography)(void)=^{NSString *article=MT(basic[@"wikipediaTitle"]);if(!article.length){[self finishEntityDetails:profile job:job warnings:warnings error:nil];return;}
            NSString *address=[NSString stringWithFormat:@"https://en.wikipedia.org/w/api.php?action=query&format=json&prop=extracts%%7Cpageprops&ppprop=wikibase_item%%7Cdisambiguation&explaintext=1&exintro=1&exchars=1200&redirects=1&titles=%@",ME(article)];
            [self fetch:address generation:g done:^(NSDictionary *response,NSString *failure){NSDictionary *bio=[RWEntityDetailsPolicy biography:response entityID:qid];if(bio.count)[profile addEntriesFromDictionary:bio];else [warnings addObject:failure?:@"Linked biography unavailable or identity mismatch"];[self finishEntityDetails:profile job:job warnings:warnings error:nil];}];
        };
        void(^photo)(void)=^{if(!file.length||MT(profile[@"image"]).length){biography();return;}
            [self fetch:[NSString stringWithFormat:@"https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=imageinfo&iiprop=url%%7Cextmetadata&iiurlwidth=400&titles=%@",ME([@"File:" stringByAppendingString:file])] generation:g done:^(NSDictionary *photos,NSString *failure){NSDictionary *image=[RWCast photos:photos people:@[@{@"imageFile":file,@"name":profile[@"name"]?:@""}]].firstObject;
                profile[@"photoCheckedAt"]=@(NSDate.date.timeIntervalSince1970);if(image){[profile addEntriesFromDictionary:image];if([job[@"role"]isEqual:@"studio"])profile[@"credit"]=[MT(profile[@"credit"])stringByReplacingOccurrencesOfString:@" · Cropped portrait" withString:@" · Logo"];[self publishEntityDetails:profile job:job];}else [warnings addObject:failure?:@"Image unavailable"];biography();}];
        };
        NSArray *ids=[RWEntityDetailsPolicy labelIDs:entity studio:[job[@"role"]isEqual:@"studio"]];if(!ids.count){photo();return;}
        [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=labels&languages=en%%7Cmul&ids=%@",ME([ids componentsJoinedByString:@"|"])] generation:g done:^(NSDictionary *labels,NSString *failure){NSDictionary *details=[RWEntityDetailsPolicy details:entity role:job[@"role"] labels:MD(labels[@"entities"])];if(failure)[warnings addObject:failure];else{profile[@"facts"]=details[@"facts"]?:@[];if(MT(details[@"kindLabel"]).length)profile[@"kindLabel"]=details[@"kindLabel"];[self publishEntityDetails:profile job:job];}photo();}];
    }];
}
#include "RWEntitySearchTransport.inc"
- (void)dealloc {[[RWMetadataBudget shared]cancel:_task];[_session invalidateAndCancel];}
@end
