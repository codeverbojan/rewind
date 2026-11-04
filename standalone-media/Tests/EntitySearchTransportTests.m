#import "../RWDiscoveryMetadata.h"
static NSUInteger Requests,Active,Peak,Mode;static NSMutableArray *URLs;static int Checks,Failures;
static NSDictionary *C(NSString *qid){return @{@"mainsnak":@{@"datavalue":@{@"value":@{@"id":qid}}}};}
@interface SearchProtocol:NSURLProtocol
@property(atomic,assign) BOOL counted;
@end
@implementation SearchProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)r{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r{return r;}
- (void)releaseCount {@synchronized(SearchProtocol.class){if(self.counted){Active--;self.counted=NO;}}}
- (void)startLoading {
    NSString *url=self.request.URL.absoluteString;NSUInteger mode;@synchronized(SearchProtocol.class){Requests++;Active++;Peak=MAX(Peak,Active);self.counted=YES;[URLs addObject:url];mode=Mode;}
    if((mode==3&&[url containsString:@"ids=Q102"])||mode==5)return;
    BOOL search=[url containsString:@"action=wbsearchentities"],background=[url containsString:@"list=search"];NSDictionary *json;
    if(search){NSMutableDictionary *r=[@{@"search":@[@{@"id":@"Q1",@"label":@"Ada Actor"},@{@"id":@"Q2",@"label":@"Ada Road"}]}mutableCopy];if(![url containsString:@"continue=8&"])r[@"search-continue"]=mode==2?(id)@"eight":@8;json=r;}
    else if(background)json=@{@"query":@{@"search":@[]}};
    else if([url containsString:@"descriptions"]){json=@{@"entities":@{@"Q1":@{@"id":@"Q1",@"labels":@{@"en":@{@"value":@"Ada Actor"}},@"claims":@{@"P31":@[C(@"Q5")],@"P106":@[C(@"Q101")]}},@"Q2":@{@"id":@"Q2",@"labels":@{@"en":@{@"value":@"Ada Road"}},@"claims":@{@"P31":@[C(@"Q9")]}}}};}
    else if([url containsString:@"ids=Q102"])json=@{@"entities":@{@"Q102":@{@"id":@"Q102",@"claims":@{@"P279":@[C(@"Q33999")]}}}};
    else json=@{@"entities":@{@"Q101":@{@"id":@"Q101",@"claims":@{@"P279":@[C(@"Q102")]}},@"Q9":@{@"id":@"Q9",@"claims":@{}}}};
    NSInteger status=mode==1?429:200;NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:mode==1?@{@"Retry-After":@"120"}:@{@"Content-Type":@"application/json"}];
    void(^deliver)(void)=^{if(!self.counted)return;[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:[NSJSONSerialization dataWithJSONObject:json options:0 error:nil]];[self releaseCount];[self.client URLProtocolDidFinishLoading:self];};
    double delay=mode==3?2.5:mode==4&&background?.5:0;if(delay)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,delay*NSEC_PER_SEC),dispatch_get_main_queue(),deliver);else deliver();
}
- (void)stopLoading {[self releaseCount];}
@end
@interface SearchService:RWDiscoveryMetadata @end
@implementation SearchService
+ (NSURLSessionConfiguration *)sessionConfiguration {NSURLSessionConfiguration *c=[NSURLSessionConfiguration ephemeralSessionConfiguration];c.protocolClasses=@[SearchProtocol.class];return c;}
@end
static void Check(BOOL ok){Checks++;if(!ok){Failures++;fprintf(stderr,"FAIL check %d\n",Checks);}}
static void Spin(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];}
static BOOL Until(BOOL(^predicate)(void),double timeout){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:timeout];while(!predicate()&&end.timeIntervalSinceNow>0)Spin(.005);return predicate();}
static void Reset(NSUInteger mode){@synchronized(SearchProtocol.class){Requests=0;Peak=Active;Mode=mode;URLs=[NSMutableArray new];}}
int main(){@autoreleasepool{NSMutableArray *services=[NSMutableArray new];SearchService *(^service)(void)=^SearchService *{SearchService *s=[[SearchService alloc]initWithPath:@"" cached:@{} seed:@{}];[services addObject:s];return s;};
    Reset(0);SearchService *s=service();__block BOOL done=NO;__block NSArray *items=nil;__block NSDictionary *next=nil;
    [s searchEntities:@"Ada" kind:@"People" continuation:nil done:^(NSArray *r,NSDictionary *n,NSString *e){Check(NSThread.isMainThread&&!e);items=r;next=n;done=YES;}];Check(Requests==0);s.paused=NO;Check(Until(^BOOL{return done;},2));Check(Requests==4&&Peak==1);Check(items.count==1&&[items[0][@"id"]isEqual:@"Q1"]);Check([next[@"offset"]integerValue]==8);Check([items[0][@"verifiedEntity"]boolValue]);
    NSUInteger before=Requests;__block BOOL photoDone=NO;[s entity:@"Q1" role:@"person" done:^(NSDictionary *record,NSString *error){Check([record[@"id"]isEqual:@"Q1"]&&!error);photoDone=YES;}];Check(photoDone&&Requests==before);[s searchEntities:@"Ada" kind:@"People" continuation:nil done:^(NSArray *r,NSDictionary *n,NSString *e){Check([r isEqual:items]&&[n isEqual:next]&&!e);}];Check(Requests==before);
    done=NO;[s searchEntities:@"Ada" kind:@"People" continuation:next done:^(NSArray *r,NSDictionary *n,NSString *e){Check(r.count==1&&!n.count&&!e);done=YES;}];Check(Until(^BOOL{return done;},2));Check(Requests==before+2);
    before=Requests;for(NSDictionary *input in @[@{@"q":@"A",@"kind":@"People"},@{@"q":@"Ada",@"kind":@"Unknown"},@{@"q":@"Ada",@"kind":@"People",@"offset":@(-1)}]){[s searchEntities:input[@"q"] kind:input[@"kind"] continuation:input[@"offset"]?@{@"offset":input[@"offset"]}:nil done:^(NSArray *r,NSDictionary *n,NSString *e){Check(!r.count&&e.length);}];}Check(Requests==before);
    Reset(2);SearchService *invalid=service();done=NO;[invalid searchEntities:@"Ada" kind:@"People" continuation:nil done:^(NSArray *r,NSDictionary *n,NSString *e){Check(!r.count&&!n.count&&e.length);done=YES;}];invalid.paused=NO;Check(Until(^BOOL{return done;},1));Check(Requests==1);
    Reset(1);SearchService *resting=service();done=NO;[resting searchEntities:@"Ada" kind:@"People" continuation:nil done:^(NSArray *r,NSDictionary *n,NSString *e){Check(e.length);done=YES;}];resting.paused=NO;Check(Until(^BOOL{return done;},1));done=NO;[resting searchEntities:@"Actor" kind:@"People" continuation:nil done:^(NSArray *r,NSDictionary *n,NSString *e){Check(e.length);done=YES;}];Check(done&&Requests==1);
    Reset(5);SearchService *cancel=service();__block BOOL stale=NO;[cancel searchEntities:@"Ada" kind:@"People" continuation:nil done:^(NSArray *r,NSDictionary *n,NSString *e){stale=YES;}];cancel.paused=NO;Check(Until(^BOOL{return Requests==1;},1));Mode=0;done=NO;[cancel searchEntities:@"Actor Ada" kind:@"People" continuation:nil done:^(NSArray *r,NSDictionary *n,NSString *e){Check(r.count==1&&!e);done=YES;}];Check(Until(^BOOL{return done;},1));Check(!stale);[cancel cancelEntitySearch];Check(Until(^BOOL{return Active==0;},.2));
    Reset(4);SearchService *priority=service();[priority enqueue:@[@{@"id":@"tt1",@"type":@"movie"}]];priority.paused=NO;Check(Until(^BOOL{return Requests==1;},1));double began=NSDate.date.timeIntervalSince1970;done=NO;[priority searchEntities:@"Ada" kind:@"People" continuation:nil done:^(NSArray *r,NSDictionary *n,NSString *e){Check(r.count==1&&!e);done=YES;}];Check(Until(^BOOL{return done;},.4));Check(NSDate.date.timeIntervalSince1970-began<.4);Check(Until(^BOOL{return Active==0;},1));Check(Requests==6);[priority cancelPending];
    Reset(3);SearchService *deadline=service();began=NSDate.date.timeIntervalSince1970;done=NO;[deadline searchEntities:@"Ada" kind:@"People" continuation:nil done:^(NSArray *r,NSDictionary *n,NSString *e){Check(!r.count&&[e containsString:@"too long"]);done=YES;}];deadline.paused=NO;Check(Until(^BOOL{return done;},11));Check(NSDate.date.timeIntervalSince1970-began>=9.9);Check(Requests==4);Check(Until(^BOOL{return Active==0;},.3));
    for(SearchService *service in services)[service cancelPending];Spin(.03);Check(Active==0);printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
