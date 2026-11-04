#import "RWApplePreviewLookup.h"
#import "RWApplePreviewPolicy.h"
#import "RWMetadataBudget.h"
#import "RWTrailerPolicy.h"
#import "RWPublisherRatingPolicy.h"
static NSDictionary *LD(id x){return [x isKindOfClass:NSDictionary.class]?x:@{};}
static NSArray *LA(id x){return [x isKindOfClass:NSArray.class]?x:@[];}
static NSString *LT(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static NSDictionary *LJSON(NSData *data,NSURL *url){return LD([NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);}
@interface RWApplePreviewLookup () <NSURLSessionDataDelegate>
@end
@implementation RWApplePreviewLookup {
    NSURLSession *_session;NSURLSessionDataTask *_task;NSMutableData *_body;NSHTTPURLResponse *_response;NSUInteger _generation,_requestGeneration,_requests,_limit;dispatch_queue_t _parseQueue;
    NSDictionary *(^_parse)(NSData *,NSURL *);void(^_received)(NSDictionary *,NSString *);void(^_done)(NSDictionary *,NSString *);NSDictionary *_meta;NSMutableDictionary *_ids,*_cache;NSMutableArray *_idOrder,*_cacheOrder;double _backoff;BOOL _tooLarge;
    NSMutableArray *_trace;NSString *_stage,*_imdb,*_failureKind,*_lastError;double _requestBegan;BOOL _resolved,_background;
    BOOL _disneyRating,_storeRating;NSString *_disneyIdentifier,*_storeSearch,*_storeShow;NSUInteger _redirects;
}
- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration {
    if((self=[super init])){NSURLSessionConfiguration *c=[configuration copy]?:[NSURLSessionConfiguration ephemeralSessionConfiguration];c.timeoutIntervalForRequest=3;c.timeoutIntervalForResource=4;c.HTTPMaximumConnectionsPerHost=1;c.URLCache=nil;c.HTTPAdditionalHeaders=@{@"User-Agent":@"Rewind/0.54 (personal standalone iPad experiment; org.local.ministreamlab)",@"Accept":@"application/json,text/html,application/vnd.apple.mpegurl"};_session=[NSURLSession sessionWithConfiguration:c delegate:self delegateQueue:NSOperationQueue.mainQueue];_parseQueue=dispatch_queue_create("org.local.rewind.preview-metadata",DISPATCH_QUEUE_SERIAL);_ids=[NSMutableDictionary new];_idOrder=[NSMutableArray new];_cache=[NSMutableDictionary new];_cacheOrder=[NSMutableArray new];}return self;
}
- (void)finish:(NSDictionary *)source error:(NSString *)error {
    if(!_done)return;_lastError=error;_resolved=source!=nil;if(error&&!_failureKind.length)_failureKind=[error isEqual:@"Cancelled"]?@"cancelled":@"unavailable";
    if(_task)[self recordResponse:_response error:nil outcome:[error isEqual:@"Cancelled"]?@"cancelled":@"deadline"];
    void(^done)(NSDictionary *,NSString *)=_done;_done=nil;_generation++;[[RWMetadataBudget shared]cancel:_task];_task=nil;_received=nil;_parse=nil;_body=nil;_response=nil;
    if(source&&!_background){NSString *key=LT(_meta[@"id"]);_cache[key]=@{@"at":@(NSProcessInfo.processInfo.systemUptime),@"source":source};[_cacheOrder removeObject:key];[_cacheOrder addObject:key];while(_cacheOrder.count>2){[_cache removeObjectForKey:_cacheOrder.firstObject];[_cacheOrder removeObjectAtIndex:0];}}
    _meta=nil;done(source,error);
}
- (void)cancel {[self finish:nil error:@"Cancelled"];}
- (void)invalidate {[self cancel];[_session invalidateAndCancel];_session=nil;}
- (NSDictionary *)diagnostics {return @{@"imdb":_imdb?:@"",@"stage":_stage?:@"idle",@"requests":@(_requests),@"resolved":@(_resolved),@"failure_kind":_failureKind?:@"",@"error":_lastError?:@"",@"steps":[_trace copy]?:@[]};}
- (void)recordResponse:(NSHTTPURLResponse *)response error:(NSError *)error outcome:(NSString *)outcome {
    if(!_trace)_trace=[NSMutableArray new];if(_trace.count>=6)return;
    [_trace addObject:@{@"stage":_stage?:@"",@"host":response.URL.host?:_task.currentRequest.URL.host?:@"",@"http":@(response.statusCode),@"bytes":@(_body.length),@"seconds":@(MAX(0,NSProcessInfo.processInfo.systemUptime-_requestBegan)),@"error_domain":error.domain?:@"",@"error_code":@(error.code),@"outcome":outcome?:@""}];
}
- (BOOL)permitted:(NSURL *)url {if(_storeRating)return [url.absoluteString isEqual:_storeSearch]||[RWPublisherRatingPolicy allowsStoreURL:url showURL:_storeShow];if(_disneyRating)return [RWPublisherRatingPolicy allowsDisneyURL:url identifier:_disneyIdentifier];return [RWApplePreviewPolicy allowedURL:url.absoluteString base:nil]||([url.scheme isEqual:@"https"]&&[url.host isEqual:@"www.wikidata.org"]&&!url.user&&!url.password&&(!url.port||url.port.integerValue==443));}
- (void)fetch:(NSString *)url stage:(NSString *)stage limit:(NSUInteger)limit parse:(NSDictionary *(^)(NSData *,NSURL *))parse done:(void(^)(NSDictionary *,NSString *))done {
    _stage=stage;_requestBegan=NSProcessInfo.processInfo.systemUptime;NSURL *address=[NSURL URLWithString:url];if(!_done)return;if(![self permitted:address]||++_requests>6){[self finish:nil error:@"Preview metadata is unavailable."];return;}
    _tooLarge=NO;_limit=limit;_body=[NSMutableData new];_response=nil;_parse=[parse copy];_received=[done copy];_requestGeneration=_generation;_task=[_session dataTaskWithURL:address];[[RWMetadataBudget shared]enqueue:_task foreground:!_background];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void(^)(NSURLRequest *))completion {BOOL allowed=task==_task&&[self permitted:request.URL];if((_disneyRating||_storeRating)&&++_redirects>3)allowed=NO;completion(allowed?request:nil);}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void(^)(NSURLSessionResponseDisposition))completion {
    if(task!=_task||_requestGeneration!=_generation||![self permitted:response.URL]){completion(NSURLSessionResponseCancel);return;}_response=[response isKindOfClass:NSHTTPURLResponse.class]?(NSHTTPURLResponse *)response:nil;_tooLarge=response.expectedContentLength>(int64_t)_limit;completion(_tooLarge?NSURLSessionResponseCancel:NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {if(task!=_task||_requestGeneration!=_generation)return;if(_body.length+data.length>_limit){_tooLarge=YES;[[RWMetadataBudget shared]cancel:task];return;}[_body appendData:data];}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [[RWMetadataBudget shared]complete:task];if(task!=_task||_requestGeneration!=_generation)return;[self recordResponse:_response error:error outcome:_tooLarge?@"too_large":error?@"network_error":_response.statusCode==200?@"received":@"http_error"];_task=nil;NSUInteger g=_generation;NSHTTPURLResponse *response=_response;NSData *data=[_body copy];_body=nil;_response=nil;
    NSDictionary *(^parse)(NSData *,NSURL *)=_parse;void(^done)(NSDictionary *,NSString *)=_received;_parse=nil;_received=nil;
    if(response.statusCode==429||response.statusCode==503)_backoff=NSDate.date.timeIntervalSince1970+MAX(120,[response.allHeaderFields[@"Retry-After"]doubleValue]);
    if(_tooLarge||error||response.statusCode!=200){_failureKind=_tooLarge?@"unsupported":@"transient";[self finish:nil error:@"Preview service is unavailable right now."];return;}
    dispatch_async(_parseQueue,^{@autoreleasepool{NSDictionary *result=parse(data,response.URL);dispatch_async(dispatch_get_main_queue(),^{if(g!=self->_generation||!self->_done)return;if(!result.count||result[@"error"]){self->_failureKind=result[@"error"]?@"transient":@"unavailable";[self finish:nil error:@"No compatible preview is listed for this title."];return;}done(result,nil);});}});
}
- (void)loadShow:(NSString *)showID {
    BOOL movie=[_meta[@"type"]isEqual:@"movie"];NSString *page=[NSString stringWithFormat:@"https://tv.apple.com/us/%@/%@",movie?@"movie":@"show",showID];NSDictionary *meta=_meta;
    [self fetch:page stage:movie?@"movie_page":@"show_page" limit:2*1024*1024 parse:^NSDictionary *(NSData *d,NSURL *url){return [RWApplePreviewPolicy preview:d showID:showID meta:meta];} done:^(NSDictionary *preview,NSString *error){
        [self fetch:preview[@"url"] stage:@"master_playlist" limit:1024*1024 parse:^NSDictionary *(NSData *d,NSURL *url){return [RWApplePreviewPolicy variant:[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding] base:url];} done:^(NSDictionary *variant,NSString *error){
            NSDictionary *(^parseMedia)(NSData *,NSURL *)=^NSDictionary *(NSData *d,NSURL *url){return [RWApplePreviewPolicy media:[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding] base:url];};
            [self fetch:variant[@"videoURL"] stage:@"video_playlist" limit:128*1024 parse:parseMedia done:^(NSDictionary *video,NSString *error){
                [self fetch:variant[@"audioURL"] stage:@"audio_playlist" limit:128*1024 parse:parseMedia done:^(NSDictionary *audio,NSString *error){
                    if(fabs([video[@"duration"]doubleValue]-[audio[@"duration"]doubleValue])>2||fabs([preview[@"duration"]doubleValue]-[video[@"duration"]doubleValue])>5){[self finish:nil error:@"Preview timing could not be verified."];return;}
                    NSMutableDictionary *source=[preview mutableCopy];[source removeObjectForKey:@"url"];source[@"kind"]=@"apple-hls";source[@"hlsMaster"]=[RWApplePreviewPolicy localMaster:variant];source[@"hlsVideo"]=video[@"text"];source[@"hlsAudio"]=audio[@"text"];source[@"width"]=variant[@"width"];source[@"height"]=variant[@"height"];source[@"codecs"]=variant[@"codecs"];source[@"fps"]=variant[@"fps"];source[@"imdb"]=meta[@"id"];
                    if([NSJSONSerialization dataWithJSONObject:source options:0 error:nil].length>128*1024){[self finish:nil error:@"Preview description exceeds its cache budget."];return;}[self finish:source error:nil];
                }];
            }];
        }];
    }];
}
- (void)resolve:(NSDictionary *)meta knownIDs:(NSArray *)ids done:(void(^)(NSDictionary *,NSString *))done {
    _background=NO;_storeRating=NO;_storeSearch=nil;_storeShow=nil;_disneyRating=NO;_disneyIdentifier=nil;_redirects=0;
    [self cancel];NSString *imdb=LT(meta[@"id"]);_imdb=imdb;_trace=[NSMutableArray new];_stage=@"identity";_failureKind=nil;_lastError=nil;_requests=0;_resolved=NO;if(!LT(meta[@"name"]).length||(![meta[@"type"]isEqual:@"series"]&&![RWTrailerPolicy movieIdentityReady:meta])||[imdb rangeOfString:@"^tt[0-9]+$" options:NSRegularExpressionSearch].location!=0){done(nil,@"No verified show identity.");return;}
    NSDictionary *cached=_cache[imdb];if(cached&&NSProcessInfo.processInfo.systemUptime-[cached[@"at"]doubleValue]<60){_stage=@"memory_cache";_resolved=YES;done(cached[@"source"],nil);return;}if(_backoff>NSDate.date.timeIntervalSince1970){_failureKind=@"transient";_lastError=@"Preview service is resting.";done(nil,_lastError);return;}
    _meta=[meta copy];_done=[done copy];_requests=0;NSUInteger g=++_generation;__weak RWApplePreviewLookup *weak=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,6*NSEC_PER_SEC),dispatch_get_main_queue(),^{RWApplePreviewLookup *s=weak;if(s&&s->_generation==g){s->_failureKind=@"transient";[s finish:nil error:@"Preview lookup deadline."];}});
    NSString *known=LA(ids).count==1?ids[0]:_ids[imdb];if([LT(known)rangeOfString:@"^umc\\.cmc\\.[a-z0-9]{10,40}$" options:NSRegularExpressionSearch].location==0){[self loadShow:known];return;}
    NSString *query=[[@"haswbstatement:P345=" stringByAppendingString:imdb]stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=query&list=search&format=json&srnamespace=0&srprop=&srlimit=3&srsearch=%@",query] stage:@"identity_search" limit:128*1024 parse:^NSDictionary *(NSData *d,NSURL *u){return LJSON(d,u);} done:^(NSDictionary *search,NSString *error){NSMutableArray *qids=[NSMutableArray new];for(id raw in LA(LD(search[@"query"])[@"search"])){NSString *qid=LT(LD(raw)[@"title"]);if([qid rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location==0&&![qids containsObject:qid])[qids addObject:qid];if(qids.count==3)break;}
        if(!qids.count){[self finish:nil error:@"No verified show preview mapping."];return;}
        [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=claims&ids=%@",[qids componentsJoinedByString:@"%7C"]] stage:@"identity_claims" limit:1024*1024 parse:^NSDictionary *(NSData *d,NSURL *u){return LJSON(d,u);} done:^(NSDictionary *claims,NSString *error){NSMutableOrderedSet *ids=[NSMutableOrderedSet new];for(NSString *qid in qids)[ids addObjectsFromArray:([meta[@"type"]isEqual:@"movie"]?[RWApplePreviewPolicy movieIDs:LD(LD(claims[@"entities"])[qid]) imdb:imdb]:[RWApplePreviewPolicy showIDs:LD(LD(claims[@"entities"])[qid]) imdb:imdb])];if(ids.count!=1){[self finish:nil error:@"Show preview identity is missing or ambiguous."];return;}self->_ids[imdb]=ids.firstObject;[self->_idOrder removeObject:imdb];[self->_idOrder addObject:imdb];while(self->_idOrder.count>64){[self->_ids removeObjectForKey:self->_idOrder.firstObject];[self->_idOrder removeObjectAtIndex:0];}[self loadShow:ids.firstObject];}];
    }];
}
- (void)dealloc {[[RWMetadataBudget shared]cancel:_task];[_session invalidateAndCancel];}
- (void)resolveRating:(NSDictionary *)meta identifier:(NSString *)identifier done:(void(^)(NSDictionary *,NSString *))done {
    [self cancel];_background=YES;_storeRating=NO;_storeSearch=nil;_storeShow=nil;_disneyRating=NO;_disneyIdentifier=nil;_redirects=0;_trace=[NSMutableArray new];_failureKind=nil;_lastError=nil;_resolved=NO;_requests=0;_imdb=LT(meta[@"id"]);
    if(![meta[@"type"]isEqual:@"series"]||[LT(identifier)rangeOfString:@"^umc\\.cmc\\.[a-z0-9]{10,40}$" options:NSRegularExpressionSearch].location!=0||_backoff>NSDate.date.timeIntervalSince1970){if(_backoff>NSDate.date.timeIntervalSince1970)_failureKind=@"transient";done(nil,@"Classification unavailable.");return;}
    _meta=[meta copy];_done=[done copy];NSUInteger g=++_generation;__weak RWApplePreviewLookup *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,6*NSEC_PER_SEC),dispatch_get_main_queue(),^{RWApplePreviewLookup *s=weak;if(s&&s->_generation==g){s->_failureKind=@"transient";[s finish:nil error:@"Classification lookup deadline."];}});
    [self fetch:[@"https://tv.apple.com/us/show/" stringByAppendingString:identifier] stage:@"show_classification" limit:2*1024*1024 parse:^NSDictionary *(NSData *data,NSURL *url){return [RWPublisherRatingPolicy record:data identifier:identifier meta:meta];} done:^(NSDictionary *record,NSString *error){[self finish:record error:error];}];
}
- (void)resolveDisneyRating:(NSDictionary *)meta identifier:(NSString *)identifier done:(void(^)(NSDictionary *,NSString *))done {
    [self cancel];_background=YES;_storeRating=NO;_storeSearch=nil;_storeShow=nil;_disneyRating=YES;_disneyIdentifier=[identifier copy];_redirects=0;_trace=[NSMutableArray new];_failureKind=nil;_lastError=nil;_resolved=NO;_requests=0;_imdb=LT(meta[@"id"]);
    NSString *address=[@"https://www.disneyplus.com/series/wp/" stringByAppendingString:LT(identifier)];
    if(![meta[@"type"]isEqual:@"series"]||![RWPublisherRatingPolicy allowsDisneyURL:[NSURL URLWithString:address] identifier:identifier]||_backoff>NSDate.date.timeIntervalSince1970){if(_backoff>NSDate.date.timeIntervalSince1970)_failureKind=@"transient";done(nil,@"Classification unavailable.");return;}
    _meta=[meta copy];_done=[done copy];NSUInteger g=++_generation;__weak RWApplePreviewLookup *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,6*NSEC_PER_SEC),dispatch_get_main_queue(),^{RWApplePreviewLookup *s=weak;if(s&&s->_generation==g){s->_failureKind=@"transient";[s finish:nil error:@"Classification lookup deadline."];}});
    [self fetch:address stage:@"disney_classification" limit:2*1024*1024 parse:^NSDictionary *(NSData *data,NSURL *url){return [RWPublisherRatingPolicy disneyRecord:data URL:url identifier:identifier meta:meta];} done:^(NSDictionary *record,NSString *error){[self finish:record error:error];}];
}
- (void)resolveStoreRating:(NSDictionary *)meta done:(void(^)(NSDictionary *,NSString *))done {
    [self cancel];_background=YES;_disneyRating=NO;_disneyIdentifier=nil;_storeRating=YES;_storeShow=nil;_storeSearch=[RWPublisherRatingPolicy storeSearchURL:meta];_redirects=0;_trace=[NSMutableArray new];_failureKind=nil;_lastError=nil;_resolved=NO;_requests=0;_imdb=LT(meta[@"id"]);
    if(!_storeSearch||_backoff>NSDate.date.timeIntervalSince1970){if(_backoff>NSDate.date.timeIntervalSince1970)_failureKind=@"transient";done(nil,@"Classification unavailable.");return;}
    _meta=[meta copy];_done=[done copy];NSUInteger g=++_generation;__weak RWApplePreviewLookup *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,6*NSEC_PER_SEC),dispatch_get_main_queue(),^{RWApplePreviewLookup *s=weak;if(s&&s->_generation==g){s->_failureKind=@"transient";[s finish:nil error:@"Classification lookup deadline."];}});
    [self fetch:_storeSearch stage:@"store_identity" limit:128*1024 parse:^NSDictionary *(NSData *data,NSURL *url){NSString *show=[RWPublisherRatingPolicy storeShowURL:data meta:meta];return show?@{@"show":show}:nil;} done:^(NSDictionary *identity,NSString *error){
        self->_storeSearch=nil;self->_storeShow=identity[@"show"];
        [self fetch:self->_storeShow stage:@"store_classification" limit:2*1024*1024 parse:^NSDictionary *(NSData *data,NSURL *url){return [RWPublisherRatingPolicy storeRecord:data URL:url meta:meta];} done:^(NSDictionary *record,NSString *error){[self finish:record error:error];}];
    }];
}
@end
