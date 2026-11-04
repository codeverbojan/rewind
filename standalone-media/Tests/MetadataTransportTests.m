#import "../RWMetadataBudget.h"
// Real NSURLSession tasks from independent clients, with in-process transport.
// No network listener or external service is needed. NSURLProtocol retains
// its object while a task is suspended; that is not a live socket measurement.
// Count real running task states, verify suspended work does not deliver, and
// report retained protocol objects separately. Physical iPad acceptance is separate.
static NSMutableSet *Live;static NSMutableDictionary *Starts,*Tasks;static NSUInteger Peak,HostPeak,LivePeak;
@interface BudgetProtocol:NSURLProtocol
@property(nonatomic,assign) BOOL stopped;
@end
@implementation BudgetProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request{return request;}
- (void)startLoading {
    @synchronized(BudgetProtocol.class){self.stopped=NO;[Live addObject:self];NSString *key=self.request.URL.absoluteString;Starts[key]=@([Starts[key]integerValue]+1);LivePeak=MAX(LivePeak,Live.count);NSUInteger running=0,same=0;for(NSURLSessionTask *task in Tasks.allValues)if(task.state==NSURLSessionTaskStateRunning){running++;if([task.originalRequest.URL.host isEqual:self.request.URL.host])same++;}Peak=MAX(Peak,running);HostPeak=MAX(HostPeak,same);}
}
- (void)stopLoading {@synchronized(BudgetProtocol.class){self.stopped=YES;[Live removeObject:self];}}
- (void)finish {
    @synchronized(BudgetProtocol.class){if(self.stopped)return;self.stopped=YES;[Live removeObject:self];}
    NSHTTPURLResponse *r=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
    [self.client URLProtocol:self didReceiveResponse:r cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:[@"{}" dataUsingEncoding:NSUTF8StringEncoding]];[self.client URLProtocolDidFinishLoading:self];
}
@end
static void Spin(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];}
static NSUInteger Count(void){@synchronized(BudgetProtocol.class){NSUInteger n=0;for(BudgetProtocol *p in Live)if([Tasks[p.request.URL.absoluteString]state]==NSURLSessionTaskStateRunning)n++;return n;}}
static NSUInteger Started(NSString *url){@synchronized(BudgetProtocol.class){return [Starts[url]integerValue];}}
static void FinishAll(void){NSArray *copy;@synchronized(BudgetProtocol.class){copy=Live.allObjects;}for(BudgetProtocol *p in copy)if([Tasks[p.request.URL.absoluteString]state]==NSURLSessionTaskStateRunning)[p finish];Spin(.04);}
static NSURLSessionTask *Request(NSURLSession *session,RWMetadataBudget *gate,NSString *url,BOOL foreground,void(^done)(void)){
    __block NSURLSessionDataTask *task=nil;
    task=[session dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        dispatch_async(dispatch_get_main_queue(),^{[gate complete:task];task=nil;if(done)done();});
    }];@synchronized(BudgetProtocol.class){Tasks[url]=task;}[gate enqueue:task foreground:foreground];return task;
}
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    Live=[NSMutableSet new];Starts=[NSMutableDictionary new];Tasks=[NSMutableDictionary new];RWMetadataBudget *gate=[RWMetadataBudget new];NSMutableArray *sessions=[NSMutableArray new];
    for(int i=0;i<3;i++){NSURLSessionConfiguration *c=[NSURLSessionConfiguration ephemeralSessionConfiguration];c.protocolClasses=@[BudgetProtocol.class];c.timeoutIntervalForResource=10;[sessions addObject:[NSURLSession sessionWithConfiguration:c]];}
    __block NSUInteger callbacks=0;void(^done)(void)=^{callbacks++;};
    NSURLSessionTask *a=Request(sessions[0],gate,@"https://a.test/a",NO,done);
    Request(sessions[1],gate,@"https://a.test/second",NO,done);Request(sessions[2],gate,@"https://b.test/b",NO,done);Spin(.06);
    CHECK(Count()==2&&Started(@"https://a.test/second")==0);CHECK([gate.diagnostics[@"active"]integerValue]==2);
    [gate cancel:a];Spin(.08);CHECK(callbacks==1&&Started(@"https://a.test/second")==1);CHECK(Count()==2);
    NSURLSessionTask *foreground=Request(sessions[0],gate,@"https://a.test/visible",YES,done);Spin(.06);
    CHECK(foreground.state==NSURLSessionTaskStateRunning);CHECK([gate.diagnostics[@"preemptions"]integerValue]==1);CHECK(Count()<=2);
    gate.backgroundPaused=YES;Spin(.04);CHECK(foreground.state==NSURLSessionTaskStateRunning);CHECK([gate.diagnostics[@"active"]integerValue]==1);CHECK(Count()<=1);
    FinishAll();CHECK(callbacks==2);gate.backgroundPaused=NO;Spin(.04);CHECK([gate.diagnostics[@"active"]integerValue]==2);FinishAll();Spin(.04);CHECK(callbacks==4&&Count()==0);CHECK([gate.diagnostics[@"active"]integerValue]==0&&[gate.diagnostics[@"pending"]integerValue]==0);
    gate.paused=YES;NSURLSessionTask *cancelled=Request(sessions[0],gate,@"https://c.test/cancelled",YES,done);[gate cancel:cancelled];Spin(.05);CHECK(callbacks==5&&Started(@"https://c.test/cancelled")==0);gate.paused=NO;
    Request(sessions[0],gate,@"https://c.test/final",NO,done);Spin(.03);gate.paused=YES;gate.paused=YES;Spin(.03);CHECK(Count()==0);gate.paused=NO;Spin(.03);CHECK(Count()==1);FinishAll();CHECK(callbacks==6);
    for(NSURLSession *s in sessions)[s invalidateAndCancel];Spin(.05);CHECK(Count()==0);CHECK(Peak<=2&&HostPeak<=1);
    printf("{\"checks\":%d,\"failures\":%d,\"running_task_peak\":%lu,\"running_host_peak\":%lu,\"callbacks\":%lu,\"retained_protocol_peak\":%lu}\n",checks,failures,(unsigned long)Peak,(unsigned long)HostPeak,(unsigned long)callbacks,(unsigned long)LivePeak);return failures?1:0;
}}
