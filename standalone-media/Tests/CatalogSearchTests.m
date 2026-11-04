#import "../RWCatalogSearch.h"
static NSUInteger Starts,Stops;static int Checks,Failures;
@interface CatalogProtocol:NSURLProtocol
@property(atomic) BOOL stopped;
@end
@implementation CatalogProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)r{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r{return r;}
- (void)startLoading {
    Starts++;NSString *path=self.request.URL.path;BOOL header=[path containsString:@"header"],chunk=[path containsString:@"chunk"],slow=[path containsString:@"slow"],bad=[path containsString:@"bad"];
    NSData *body=bad?[@"invalid JSON" dataUsingEncoding:NSUTF8StringEncoding]:[NSJSONSerialization dataWithJSONObject:@{@"metas":@[@{@"id":@"tt1727587",@"name":@"Sintel",@"type":@"movie"}]} options:0 error:nil];
    NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:[path containsString:@"offline"]?503:200 HTTPVersion:@"HTTP/1.1" headerFields:header?@{@"Content-Length":@"6291456"}:@{@"Content-Type":@"application/json"}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    void(^deliver)(void)=^{if(self.stopped)return;if(header||chunk){NSData *block=[NSMutableData dataWithLength:65536];for(int i=0;i<96&&!self.stopped;i++)[self.client URLProtocol:self didLoadData:block];}else [self.client URLProtocol:self didLoadData:body];if(!self.stopped)[self.client URLProtocolDidFinishLoading:self];};
    if(slow)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),deliver);else deliver();
}
- (void)stopLoading {self.stopped=YES;Stops++;}
@end
@interface TestSearch:RWCatalogSearch @end
@implementation TestSearch
+ (NSURLSessionConfiguration *)sessionConfiguration {NSURLSessionConfiguration *c=[super sessionConfiguration];c.protocolClasses=@[CatalogProtocol.class];return c;}
+ (NSURL *)URLForType:(NSString *)type query:(NSString *)q {return [NSURL URLWithString:[@"https://catalog.test/" stringByAppendingString:q]];}
@end
static void C(BOOL value){Checks++;if(!value){Failures++;fprintf(stderr,"FAIL%d\n",Checks);}}
static void Spin(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];}
static BOOL Until(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:3];while(!ready()&&end.timeIntervalSinceNow>0)Spin(.01);return ready();}
int main(){@autoreleasepool{
 TestSearch *s=[[TestSearch alloc]initWithURLCache:[[NSURLCache alloc]initWithMemoryCapacity:128 diskCapacity:0 diskPath:nil]];__block BOOL done=NO;__block NSArray *items;__block NSString *error;
 void(^result)(NSArray *,NSString *)=^(NSArray *r,NSString *e){C(NSThread.isMainThread);items=r;error=e;done=YES;};
 [s searchType:@"movie" query:@"valid" done:result];C(Until(^BOOL{return done;}));C(items.count==1&&!error);NSUInteger requests=Starts;done=NO;
 C(![s searchType:@"movie" query:@"valid" done:result]);C(Until(^BOOL{return done;}));C(Starts==requests);C([s.diagnostics[@"cache_hits"]intValue]==1);
 for(NSString *q in @[@"header",@"chunk",@"bad",@"offline"]){done=NO;[s searchType:@"movie" query:q done:result];C(Until(^BOOL{return done;}));C(!items&&error.length);NSDictionary *event=[s.diagnostics[@"events"]lastObject];C([event[@"outcome"]isEqual:@"unavailable"]);C([event[@"peak_buffer_bytes"]unsignedIntegerValue]<=5*1024*1024);if([q isEqual:@"header"])C([event[@"peak_buffer_bytes"]unsignedIntegerValue]==0);}
 __block BOOL stale=NO;NSURLSessionDataTask *old=[s searchType:@"movie" query:@"slow" done:^(NSArray *r,NSString *e){stale=YES;}];C(Until(^BOOL{return [[s.diagnostics[@"active"]firstObject][@"response_received"]boolValue];}));[s cancel:old];done=NO;
 [s searchType:@"movie" query:@"fresh" done:result];C(Until(^BOOL{return done;}));Spin(1.1);C(!stale&&items.count==1&&!error);C([s.diagnostics[@"cancelled"]intValue]==1);C(![s.diagnostics[@"active"]count]);
 [s clearCache];done=NO;[s searchType:@"movie" query:@"valid" done:result];C(Until(^BOOL{return done;}));C(Starts>requests);[s invalidate];Spin(.05);C(![s.diagnostics[@"active"]count]);C(Stops>0);
 printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
