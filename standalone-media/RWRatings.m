#import "RWMetadataBudget.h"
#import "RWRatings.h"
#import "RWRatingPolicy.h"
#import "RWAtomicWriter.h"
#import "RWApplePreviewLookup.h"
#import "RWApplePreviewPolicy.h"
#import "RWPublisherRatingPolicy.h"
static NSString *EscapeRating(NSString *s){return [s stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];}
@implementation RWRatings {
    NSMutableDictionary *_cache;NSDictionary *_publisherRatings;NSString *_path;NSURLSession *_session;NSMutableOrderedSet *_pending;NSMutableSet *_inFlight;BOOL _busy;double _retryAfter;NSMutableDictionary *_titles;RWApplePreviewLookup *_publisherLookup;NSMutableArray *_events;NSMutableSet *_interactiveKeys;BOOL _interactiveBatch,_lastFailureLag;double _backgroundRetryAfter;
}
- (BOOL)busy{return _busy;}
- (BOOL)isResolvingItems:(NSArray *)items {
    for(NSDictionary *m in items){NSString *key=m[@"id"]?:m[@"imdb_id"];if(key&&([_pending containsObject:key]||[_inFlight containsObject:key]))return YES;}return NO;
}
- (NSDictionary *)diagnostics{return @{@"busy":@(_busy),@"queued":@(_pending.count),@"events":[_events copy]?:@[],@"publisher":_publisherLookup.diagnostics};}
- (NSDictionary *)snapshot{return @{@"cache":[_cache copy],@"publishers":_publisherRatings?:@{}};}
- (instancetype)initWithCache:(NSString *)cache bundled:(NSString *)bundled {return [self initWithCache:cache bundled:bundled configuration:nil];}
- (instancetype)initWithCache:(NSString *)cache bundled:(NSString *)bundled configuration:(NSURLSessionConfiguration *)configuration {
    if((self=[super init])){_path=cache;_interactiveKeys=[NSMutableSet new];_events=[NSMutableArray new];_titles=[NSMutableDictionary new];_publisherLookup=[[RWApplePreviewLookup alloc]initWithConfiguration:configuration];_pending=[NSMutableOrderedSet new];_inFlight=[NSMutableSet new];NSData *data=[NSData dataWithContentsOfFile:cache];id raw=data?[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil]:nil;_cache=[raw isKindOfClass:NSDictionary.class]?[raw mutableCopy]:[NSMutableDictionary new];
        NSData *seed=[NSData dataWithContentsOfFile:bundled];NSDictionary *entries=seed?[NSJSONSerialization JSONObjectWithData:seed options:0 error:nil]:nil;
        for(NSString *imdb in entries){NSDictionary *rating=[RWRatingPolicy recordForEntity:entries[imdb] imdb:imdb];if(rating&&!_cache[imdb])_cache[imdb]=rating;}
        NSData *publisherData=[NSData dataWithContentsOfFile:[[bundled stringByDeletingLastPathComponent]stringByAppendingPathComponent:@"publisher-ratings.json"]];NSDictionary *rawPublishers=publisherData?[NSJSONSerialization JSONObjectWithData:publisherData options:0 error:nil]:@{};NSMutableDictionary *publishers=[NSMutableDictionary new];for(NSString *imdb in rawPublishers){NSDictionary *record=[RWRatingPolicy recordForPublisher:rawPublishers[imdb] imdb:imdb];if(record)publishers[imdb]=record;}_publisherRatings=publishers;
        NSURLSessionConfiguration *c=[configuration copy]?:[NSURLSessionConfiguration ephemeralSessionConfiguration];c.timeoutIntervalForRequest=12;c.timeoutIntervalForResource=20;c.HTTPMaximumConnectionsPerHost=1;c.HTTPAdditionalHeaders=@{@"User-Agent":@"Rewind/0.11 (standalone iPad experiment; org.local.ministreamlab)",@"Accept":@"application/json"};_session=[NSURLSession sessionWithConfiguration:c];
    }return self;
}
- (NSDictionary *)rating:(NSString *)imdb{NSDictionary *cached=_cache[imdb],*publisher=_publisherRatings[imdb];return publisher&&(!cached||[cached[@"minimumAge"]integerValue]<[publisher[@"minimumAge"]integerValue])?publisher:cached;}
- (void)resolve:(NSArray *)items {[self resolve:items interactive:NO];}
- (void)resolve:(NSArray *)items interactive:(BOOL)interactive {
    double now=NSDate.date.timeIntervalSince1970;if(now<_retryAfter||(!interactive&&now<_backgroundRetryAfter))return;NSUInteger admitted=0;NSRegularExpression *valid=[NSRegularExpression regularExpressionWithPattern:@"^tt[0-9]+$" options:0 error:nil];
    for(NSDictionary *m in items){NSString *key=m[@"id"];if(![key isKindOfClass:NSString.class]||![valid firstMatchInString:key options:0 range:NSMakeRange(0,key.length)])continue;
        if(![RWRatingPolicy needsLookup:[self rating:key] type:m[@"type"] now:now])continue;
        if(_pending.count<60&&![_inFlight containsObject:key]){if(interactive&&admitted++>=4)break;[_pending addObject:key];if(interactive)[_interactiveKeys addObject:key];NSMutableDictionary *brief=[NSMutableDictionary new];for(NSString *field in @[@"id",@"name",@"type",@"releaseInfo"])if(m[field])brief[field]=m[field];_titles[key]=brief;}}
    [self next];
}
- (void)fetch:(NSString *)url done:(void(^)(NSDictionary *))done {
    __block NSURLSessionDataTask *task=nil;task=[_session dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){NSInteger code=[(NSHTTPURLResponse *)response statusCode];id result=(!error&&code==200&&data.length<=5*1024*1024)?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
        dispatch_async(dispatch_get_main_queue(),^{[[RWMetadataBudget shared]complete:task];task=nil;if(code==429||code==503){NSString *retry=[(NSHTTPURLResponse *)response allHeaderFields][@"Retry-After"];self->_retryAfter=[NSDate date].timeIntervalSince1970+MAX(120,retry.doubleValue);}
            if(self->_events.count>=8)[self->_events removeObjectAtIndex:0];[self->_events addObject:@{@"interactive":@(self->_interactiveBatch),@"http":@(code),@"error":error.domain?:@"",@"error_code":@(error.code),@"api_error":([result isKindOfClass:NSDictionary.class]&&[result[@"error"]isKindOfClass:NSDictionary.class])?(result[@"error"][@"code"]?:@""):@"",@"bytes":@(data.length)}];
            self->_lastFailureLag=[result isKindOfClass:NSDictionary.class]&&[result[@"error"]isKindOfClass:NSDictionary.class]&&[result[@"error"][@"code"]isEqual:@"maxlag"];
            done([result isKindOfClass:NSDictionary.class]&&!result[@"error"]?result:nil);});}];[[RWMetadataBudget shared]enqueue:task foreground:_interactiveBatch];
}
- (void)publishRatings {
    if(_cache.count>1500){NSArray *keys=[_cache keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"checked"]compare:b[@"checked"]];}];for(NSUInteger i=0;i<keys.count-1200;i++)[_cache removeObjectForKey:keys[i]];}
    [[RWAtomicWriter shared]write:[NSJSONSerialization dataWithJSONObject:_cache options:0 error:nil] path:_path];
    [[NSNotificationCenter defaultCenter]postNotificationName:@"RWRatingsUpdated" object:self];
}
- (void)publisherJobs:(NSArray *)jobs index:(NSUInteger)index batch:(NSArray *)batch {
    if(index>=jobs.count){[_inFlight minusSet:[NSSet setWithArray:batch]];[_titles removeObjectsForKeys:batch];_busy=NO;[self next];return;}
    NSDictionary *job=jobs[index];NSString *imdb=job[@"meta"][@"id"];
    void(^complete)(NSDictionary *,NSString *)=^(NSDictionary *record,NSString *error){
        if(record&&[record[@"minimumAge"]integerValue]>=[self->_cache[imdb][@"minimumAge"]integerValue]){NSMutableDictionary *merged=[record mutableCopy];merged[@"publisherAttempted"]=@YES;merged[@"publisherPolicy"]=@3;self->_cache[imdb]=merged;[self publishRatings];}
        else if([self->_cache[imdb][@"minimumAge"]integerValue]<0&&[self->_publisherLookup.diagnostics[@"failure_kind"]isEqual:@"transient"]){NSMutableDictionary *retry=[self->_cache[imdb]mutableCopy];retry[@"retryAfter"]=@(NSDate.date.timeIntervalSince1970+120);self->_cache[imdb]=retry;[self publishRatings];}
        [self publisherJobs:jobs index:index+1 batch:batch];
    };
    if([job[@"provider"]isEqual:@"disney"])[_publisherLookup resolveDisneyRating:job[@"meta"] identifier:job[@"identifier"] done:complete];
    else if([job[@"provider"]isEqual:@"store"])[_publisherLookup resolveStoreRating:job[@"meta"] done:complete];
    else [_publisherLookup resolveRating:job[@"meta"] identifier:job[@"identifier"] done:complete];
}
- (void)finish:(NSArray *)batch entities:(NSDictionary *)entities success:(BOOL)success {
    double now=NSDate.date.timeIntervalSince1970;NSMutableArray *jobs=[NSMutableArray new];
    if(!success){if(_lastFailureLag)_backgroundRetryAfter=MAX(_backgroundRetryAfter,now+120);else _retryAfter=MAX(_retryAfter,now+120);
        for(NSString *key in [_pending.array copy])if(!_lastFailureLag||![_interactiveKeys containsObject:key]){[_titles removeObjectForKey:key];[_pending removeObject:key];[_interactiveKeys removeObject:key];}}
    if(success)for(NSString *imdb in batch){NSDictionary *record=nil;NSMutableOrderedSet *ids=[NSMutableOrderedSet new],*disneyIDs=[NSMutableOrderedSet new];
        for(id entity in entities.allValues){NSDictionary *r=[RWRatingPolicy recordForEntity:entity imdb:imdb];if(r&&(!record||[r[@"minimumAge"]integerValue]>[record[@"minimumAge"]integerValue]))record=r;[ids addObjectsFromArray:[RWApplePreviewPolicy showIDs:entity imdb:imdb]];[disneyIDs addObjectsFromArray:[RWPublisherRatingPolicy disneyIDs:entity imdb:imdb]];}
        // Missing or weaker enrichment must never lower an already known age.
        if([_cache[imdb][@"minimumAge"]integerValue]>=0&&(!record||[_cache[imdb][@"minimumAge"]integerValue]>[record[@"minimumAge"]integerValue]))record=_cache[imdb];
        NSMutableDictionary *saved=[(record?:@{@"minimumAge":@(-1),@"label":@"Rating unavailable",@"checked":@(now)})mutableCopy];
        NSDictionary *meta=_titles[imdb];BOOL series=[meta[@"type"]isEqual:@"series"];
        if(series){
            // Review positive ratings too when their normal refresh is due.
            // Prefer the exact publisher over an aggregator; never lower the
            // stricter cached classification. No new refresh queue or budget.
            // At most four publisher jobs per batch, on the existing lane.
            // Missing mappings may use exact store identity + premiere checks.
            BOOL disney=disneyIDs.count==1,apple=!disney&&ids.count==1;
            if((apple||disney)&&jobs.count<4){[jobs addObject:@{@"meta":meta,@"identifier":apple?ids.firstObject:disneyIDs.firstObject,@"provider":apple?@"apple":@"disney"}];saved[@"publisherAttempted"]=@YES;saved[@"publisherPolicy"]=@3;}
            else if(!ids.count&&!disneyIDs.count&&jobs.count<4){[jobs addObject:@{@"meta":meta,@"provider":@"store"}];saved[@"publisherAttempted"]=@YES;saved[@"publisherPolicy"]=@3;}
            else if((ids.count||disneyIDs.count)&&!apple&&!disney){saved[@"publisherAttempted"]=@YES;saved[@"publisherPolicy"]=@3;}
        }
        _cache[imdb]=saved;
    }
    [self publishRatings];[self publisherJobs:jobs index:0 batch:batch];
}
- (void)next {
    if(_busy||!_pending.count||NSDate.date.timeIntervalSince1970<_retryAfter)return;_interactiveBatch=_interactiveKeys.count>0;if(!_interactiveBatch&&NSDate.date.timeIntervalSince1970<_backgroundRetryAfter)return;_busy=YES;_lastFailureLag=NO;
    NSMutableArray *batch=[NSMutableArray new],*queries=[NSMutableArray new];for(NSString *key in [_pending.array copy]){if(_interactiveBatch&&![_interactiveKeys containsObject:key])continue;[_pending removeObject:key];[_interactiveKeys removeObject:key];[batch addObject:key];[_inFlight addObject:key];[queries addObject:[@"P345=" stringByAppendingString:key]];if(batch.count>=(_interactiveBatch?4:12))break;}
    // Wikimedia explicitly distinguishes user-waiting reads from background
    // work. Only a visible rail request may omit maxlag; automatic enrichment
    // still yields at maxlag=5. Both share one request lane and HTTP backoff.
    NSString *lag=_interactiveBatch?@"":@"&maxlag=5";
    NSString *url=[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=query&list=search&format=json%@&srlimit=50&srnamespace=0&srprop=&srsearch=%@",lag,EscapeRating([@"haswbstatement:" stringByAppendingString:[queries componentsJoinedByString:@"|"]])];
    [self fetch:url done:^(NSDictionary *result){if(!result){[self finish:batch entities:@{} success:NO];return;}
        NSMutableArray *ids=[NSMutableArray new];for(NSDictionary *item in result[@"query"][@"search"]){NSString *key=item[@"title"];if([key isKindOfClass:NSString.class]&&[key hasPrefix:@"Q"])[ids addObject:key];}
        if(!ids.count){[self finish:batch entities:@{} success:YES];return;}
        NSString *details=[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json%@&props=claims&ids=%@",lag,[ids componentsJoinedByString:@"%7C"]];
        [self fetch:details done:^(NSDictionary *r){[self finish:batch entities:[r[@"entities"]isKindOfClass:NSDictionary.class]?r[@"entities"]:@{} success:r!=nil];}];
    }];
}
- (void)dealloc {[_publisherLookup invalidate];[_session invalidateAndCancel];}
@end
