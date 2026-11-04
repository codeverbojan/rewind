#import "RWCatalogSearch.h"
#import "RWMetadataBudget.h"
static const NSUInteger SearchLimit=5*1024*1024;
static NSString *const SearchUnavailable=@"Online search is unavailable. Try again.";
static BOOL SearchHTTP(NSURL *url){return [@[@"http",@"https"]containsObject:url.scheme.lowercaseString]&&url.host.length;}
@interface RWCatalogSearch () <NSURLSessionDataDelegate>
@end
@implementation RWCatalogSearch {
    NSURLSession *_session;NSMutableDictionary *_jobs;NSCache *_cache;NSMutableArray *_events;
    NSUInteger _started,_cancelled,_cacheHits;BOOL _invalidated;
}
+ (NSURLSessionConfiguration *)sessionConfiguration {return NSURLSessionConfiguration.ephemeralSessionConfiguration;}
+ (NSURL *)URLForType:(NSString *)type query:(NSString *)query {
    NSCharacterSet *safe=[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://v3-cinemeta.strem.io/catalog/%@/top/search=%@.json",type,[query stringByAddingPercentEncodingWithAllowedCharacters:safe]]];
}
- (instancetype)init {return [self initWithURLCache:nil];}
- (instancetype)initWithURLCache:(NSURLCache *)cache {if((self=[super init])){
    _jobs=[NSMutableDictionary new];_events=[NSMutableArray new];_cache=[NSCache new];_cache.totalCostLimit=2*1024*1024;_cache.countLimit=24;
    NSURLSessionConfiguration *c=[[self class]sessionConfiguration];c.timeoutIntervalForRequest=8;c.timeoutIntervalForResource=10;c.HTTPMaximumConnectionsPerHost=2;c.URLCache=cache;c.HTTPCookieStorage=nil;c.URLCredentialStorage=nil;c.HTTPAdditionalHeaders=@{@"Accept":@"application/json",@"User-Agent":@"Rewind/0.139 (iPad; iOS 9)"};
    _session=[NSURLSession sessionWithConfiguration:c delegate:self delegateQueue:NSOperationQueue.mainQueue];
}return self;}
- (void)record:(NSDictionary *)job outcome:(NSString *)outcome {
    [_events addObject:@{@"query":job[@"query"],@"type":job[@"type"],@"outcome":outcome,@"http":job[@"http"]?:@0,@"peak_buffer_bytes":job[@"peak"]?:@0,@"redirects":job[@"redirects"]?:@0,@"response_received":job[@"received"]?:@NO}];while(_events.count>16)[_events removeObjectAtIndex:0];
}
- (NSDictionary *)diagnostics {
    NSMutableArray *active=[NSMutableArray new];for(NSDictionary *job in _jobs.allValues){NSURLSessionTask *task=job[@"task"];[active addObject:@{@"query":job[@"query"],@"type":job[@"type"],@"state":@(task.state),@"response_received":job[@"received"]?:@NO,@"buffer_bytes":@([job[@"data"]length])}];}
    return @{@"started":@(_started),@"cancelled":@(_cancelled),@"cache_hits":@(_cacheHits),@"active":active,@"events":[_events copy],@"limit_bytes":@(SearchLimit)};
}
- (NSURLSessionDataTask *)searchType:(NSString *)type query:(NSString *)query done:(void(^)(NSArray *,NSString *))done {
    if(_invalidated||![@[@"movie",@"series"]containsObject:type]||!query.length||query.length>256){dispatch_async(dispatch_get_main_queue(),^{done(nil,SearchUnavailable);});return nil;}
    NSString *key=[NSString stringWithFormat:@"%@:%@",type,query.lowercaseString];NSDictionary *cached=[_cache objectForKey:key];
    if(cached&&NSProcessInfo.processInfo.systemUptime-[cached[@"time"]doubleValue]<600){_cacheHits++;dispatch_async(dispatch_get_main_queue(),^{if(!self->_invalidated)done(cached[@"items"],nil);});return nil;}
    NSURL *url=[[self class]URLForType:type query:query];if(!SearchHTTP(url)){dispatch_async(dispatch_get_main_queue(),^{done(nil,SearchUnavailable);});return nil;}
    NSURLSessionDataTask *task=[_session dataTaskWithURL:url];task.priority=NSURLSessionTaskPriorityHigh;
    _jobs[@(task.taskIdentifier)]=[@{@"task":task,@"query":query,@"type":type,@"key":key,@"data":[NSMutableData new],@"done":[done copy]}mutableCopy];_started++;[[RWMetadataBudget shared]enqueue:task foreground:YES];return task;
}
- (void)cancel:(NSURLSessionTask *)task {
    if(!task)return;NSDictionary *job=_jobs[@(task.taskIdentifier)];if(job&&job[@"task"]==task){_cancelled++;[self record:job outcome:@"cancelled"];[_jobs removeObjectForKey:@(task.taskIdentifier)];}[[RWMetadataBudget shared]cancel:task];
}
- (void)clearCache {[_cache removeAllObjects];}
- (void)invalidate {if(_invalidated)return;_invalidated=YES;for(NSDictionary *job in [_jobs.allValues copy])[self cancel:job[@"task"]];[_session invalidateAndCancel];[self clearCache];}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void(^)(NSURLRequest *))done {
    NSMutableDictionary *job=_jobs[@(task.taskIdentifier)];NSUInteger count=[job[@"redirects"]unsignedIntegerValue]+1;job[@"redirects"]=@(count);
    if(!job||count>3||!SearchHTTP(request.URL)||([task.originalRequest.URL.scheme isEqual:@"https"]&&![request.URL.scheme isEqual:@"https"])){job[@"rejected"]=@YES;done(nil);[[RWMetadataBudget shared]cancel:task];return;}done(request);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void(^)(NSURLSessionResponseDisposition))done {
    NSMutableDictionary *job=_jobs[@(task.taskIdentifier)];if(!job){done(NSURLSessionResponseCancel);return;}
    NSInteger code=[response isKindOfClass:NSHTTPURLResponse.class]?[(NSHTTPURLResponse *)response statusCode]:0;job[@"http"]=@(code);job[@"received"]=@YES;
    BOOL reject=code!=200||response.expectedContentLength>(long long)SearchLimit||!SearchHTTP(response.URL);if(reject)job[@"rejected"]=@YES;done(reject?NSURLSessionResponseCancel:NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    NSMutableDictionary *job=_jobs[@(task.taskIdentifier)];if(!job||[job[@"rejected"]boolValue])return;NSMutableData *bytes=job[@"data"];
    if(data.length>SearchLimit-bytes.length){job[@"rejected"]=@YES;[[RWMetadataBudget shared]cancel:task];return;}[bytes appendData:data];job[@"peak"]=@(bytes.length);
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [[RWMetadataBudget shared]complete:task];NSMutableDictionary *job=_jobs[@(task.taskIdentifier)];if(!job||job[@"task"]!=task)return;
    if(error.code==NSURLErrorCancelled&&![job[@"rejected"]boolValue]){[self cancel:task];return;}
    BOOL valid=!error&&![job[@"rejected"]boolValue]&&[job[@"http"]integerValue]==200;NSData *data=valid?[job[@"data"]copy]:nil;[job removeObjectForKey:@"data"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{@autoreleasepool{
        id raw=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;id metas=[raw isKindOfClass:NSDictionary.class]?raw[@"metas"]:nil;NSMutableArray *items=[metas isKindOfClass:NSArray.class]?[NSMutableArray new]:nil;
        for(id meta in items?metas:@[]){if(![meta isKindOfClass:NSDictionary.class])continue;id key=meta[@"id"]?:meta[@"imdb_id"],name=meta[@"name"];if([key isKindOfClass:NSString.class]&&[key length]&&[name isKindOfClass:NSString.class]&&[name length]){[items addObject:meta];if(items.count==200)break;}}
        dispatch_async(dispatch_get_main_queue(),^{if(self->_jobs[@(task.taskIdentifier)]!=job||self->_invalidated)return;[self->_jobs removeObjectForKey:@(task.taskIdentifier)];[self record:job outcome:items?@"success":@"unavailable"];
            if(items&&data.length<=2*1024*1024)[self->_cache setObject:@{@"items":items,@"time":@(NSProcessInfo.processInfo.systemUptime)} forKey:job[@"key"] cost:data.length];void(^done)(NSArray *,NSString *)=job[@"done"];done(items,items?nil:SearchUnavailable);
        });
    }});
}
@end
