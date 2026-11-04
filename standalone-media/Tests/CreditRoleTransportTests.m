#import "../RWDiscoveryMetadata.h"
#import "../RWMetadataBudget.h"
static NSMutableArray *Queries;static NSUInteger Active,Requests,Peak;static BOOL HoldProduction,FailSearch;static double DelayAll;static int Checks,Failures;
static NSDictionary *C(id value){return @{@"mainsnak":@{@"datavalue":@{@"value":value}}};}
static NSDictionary *Params(NSURL *url){NSMutableDictionary *p=[NSMutableDictionary new];for(NSURLQueryItem *item in [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO].queryItems)p[item.name]=item.value?:@"";return p;}
static NSDictionary *Title(NSString *qid,NSString *property,NSString *imdb){return @{@"id":qid,@"labels":@{@"en":@{@"value":[@"Title " stringByAppendingString:qid]}},@"claims":@{property:@[C(@{@"id":@"Q10"})],@"P345":@[C(imdb)],@"P31":@[C(@{@"id":[property isEqual:@"P449"]?@"Q5398426":@"Q11424"})]}};}
@interface CreditProtocol:NSURLProtocol
@property(atomic,assign) BOOL counted;
@end
@implementation CreditProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)r{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r{return r;}
- (void)releaseCount {@synchronized(CreditProtocol.class){if(self.counted){Active--;self.counted=NO;}}}
- (void)startLoading {
    NSDictionary *p=Params(self.request.URL);NSString *query=p[@"srsearch"]?:@"";BOOL hold;
    @synchronized(CreditProtocol.class){Requests++;Active++;Peak=MAX(Peak,Active);self.counted=YES;[Queries addObject:query];hold=HoldProduction&&[query containsString:@"haswbstatement:P272="];}
    if(hold)return;
    if(FailSearch&&[p[@"list"]isEqual:@"search"]){[self releaseCount];[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:nil]];return;}
    NSDictionary *json;NSDictionary *entities=@{@"Q101":Title(@"Q101",@"P272",@"tt101"),@"Q102":Title(@"Q102",@"P750",@"tt102"),@"Q103":Title(@"Q103",@"P449",@"tt103"),@"Q104":Title(@"Q104",@"P161",@"tt104")};
    NSMutableDictionary *withEpisode=[entities mutableCopy];NSMutableDictionary *episode=[Title(@"Q105",@"P272",@"tt105")mutableCopy];NSMutableDictionary *claims=[episode[@"claims"]mutableCopy];claims[@"P31"]=@[C(@{@"id":@"Q21191270"})];episode[@"claims"]=claims;withEpisode[@"Q105"]=episode;withEpisode[@"Q21191270"]=@{@"id":@"Q21191270",@"labels":@{@"en":@{@"value":@"television series episode"}}};entities=withEpisode;
    if([p[@"list"]isEqual:@"search"]){NSString *qid=[query containsString:@"P272="]?@"Q101":[query containsString:@"P750="]?@"Q102":[query containsString:@"P449="]?@"Q103":@"";json=@{@"query":@{@"search":qid.length?@[@{@"title":qid},@{@"title":@"Q104"},@{@"title":@"Q105"}]:@[]}};}
    else{NSMutableDictionary *found=[NSMutableDictionary new];for(NSString *qid in [p[@"ids"]componentsSeparatedByString:@"|"])if(entities[qid])found[qid]=entities[qid];json=@{@"entities":found};}
    void(^deliver)(void)=^{if(!self.counted)return;
    NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:[NSJSONSerialization dataWithJSONObject:json options:0 error:nil]];[self releaseCount];[self.client URLProtocolDidFinishLoading:self];
    };if(DelayAll>0)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(DelayAll*NSEC_PER_SEC)),dispatch_get_main_queue(),deliver);else deliver();
}
- (void)stopLoading {[self releaseCount];}
@end
@interface CreditService:RWDiscoveryMetadata @end
@implementation CreditService
+ (NSURLSessionConfiguration *)sessionConfiguration {NSURLSessionConfiguration *c=[NSURLSessionConfiguration ephemeralSessionConfiguration];c.protocolClasses=@[CreditProtocol.class];return c;}
@end
static void CheckAt(BOOL ok,int line){Checks++;if(!ok){Failures++;fprintf(stderr,"FAIL check %d line %d\n",Checks,line);}}
#define Check(...) CheckAt((__VA_ARGS__),__LINE__)
static void Spin(double seconds){NSDate *limit=[NSDate dateWithTimeIntervalSinceNow:seconds];while(limit.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];}
static BOOL Until(BOOL(^test)(void),double seconds){NSDate *limit=[NSDate dateWithTimeIntervalSinceNow:seconds];while(!test()&&limit.timeIntervalSinceNow>0)Spin(.005);return test();}
int main(){@autoreleasepool{Queries=[NSMutableArray new];NSMutableArray *services=[NSMutableArray new];CreditService *(^service)(void)=^CreditService *{CreditService *s=[[CreditService alloc]initWithPath:@"" cached:@{} seed:@{}];[services addObject:s];return s;};
    @try{
        for(NSArray *pair in @[@[@"studio",@"tt101",@"P272",@"movie"],@[@"distributor",@"tt102",@"P750",@"movie"],@[@"network",@"tt103",@"P449",@"series"]]){CreditService *s=service();__block BOOL done=NO;NSUInteger before=Requests;[s creditPage:@"Q10" role:pair[0] continuation:nil done:^(NSArray *items,NSDictionary *next,NSString *error){Check(NSThread.isMainThread&&!error&&!next.count);Check(items.count==1);Check([items.firstObject[@"id"]isEqual:pair[1]]&&[items.firstObject[@"type"]isEqual:pair[3]]);Check([items.firstObject[@"creditEntityID"]isEqual:@"Q10"]&&[items.firstObject[@"creditRole"]isEqual:pair[0]]);done=YES;}];s.paused=NO;Check(Until(^BOOL{return done;},2));Check(Requests-before==3);Check([Queries[before]containsString:[NSString stringWithFormat:@"haswbstatement:%@=Q10",pair[2]]]);Check([Queries[before]containsString:@"-haswbstatement:P31=Q21191270"]);Check(![s record:@"tt104"].count&&![s record:@"tt105"].count);[s cancelPending];}
        Check(Peak==1);CreditService *s=service();__block BOOL stale=NO,done=NO;HoldProduction=YES;NSUInteger before=Requests;
        [s creditPage:@"Q10" role:@"studio" continuation:nil done:^(NSArray *items,NSDictionary *next,NSString *error){stale=YES;}];s.paused=NO;Check(Until(^BOOL{return Requests>before;},1));
        [s cancelCredits:@"Q11" role:@"studio"];Spin(.02);Check(Active==1);[s cancelCredits:@"Q10" role:@"network"];Spin(.02);Check(Active==1);
        [s creditPage:@"Q10" role:@"studio" continuation:@{@"sroffset":@8} done:^(NSArray *items,NSDictionary *next,NSString *error){stale=YES;}];
        [s creditPage:@"Q10" role:@"distributor" continuation:nil done:^(NSArray *items,NSDictionary *next,NSString *error){Check(!error&&[items.firstObject[@"id"]isEqual:@"tt102"]);done=YES;}];HoldProduction=NO;[s cancelCredits:@"Q10" role:@"studio"];Check(Until(^BOOL{return done;},2));Check(Until(^BOOL{return Active==0;},.5));Check(!stale&&Requests-before==4);Check(![s record:@"tt101"].count&&[s record:@"tt102"].count);
        // Cancelling a queued relationship must preserve another queued role.
        CreditService *queued=service();before=Requests;done=NO;[queued creditPage:@"Q10" role:@"network" continuation:nil done:^(NSArray *items,NSDictionary *next,NSString *error){Check(!error&&[items.firstObject[@"id"]isEqual:@"tt103"]);done=YES;}];[queued creditPage:@"Q10" role:@"studio" continuation:nil done:^(NSArray *items,NSDictionary *next,NSString *error){stale=YES;}];[queued cancelCredits:@"Q10" role:@"studio"];queued.paused=NO;Check(Until(^BOOL{return done;},2));Check(!stale&&Requests-before==3);
        // Unrelated title metadata can continue after a credit request is cancelled.
        CreditService *background=service();HoldProduction=YES;before=Requests;[background creditPage:@"Q10" role:@"studio" continuation:nil done:^(NSArray *items,NSDictionary *next,NSString *error){stale=YES;}];background.paused=NO;Check(Until(^BOOL{return Requests>before;},1));done=NO;[background resolve:@{@"id":@"tt999",@"type":@"movie"} done:^(NSDictionary *record,NSString *error){Check(!record&&error.length);done=YES;}];[background cancelCredits:@"Q10" role:@"studio"];HoldProduction=NO;Check(Until(^BOOL{return done;},1));Check(!stale&&Requests-before==2);
        before=Requests;done=NO;[queued creditPage:@"Q10" role:@"unknown" continuation:nil done:^(NSArray *items,NSDictionary *next,NSString *error){Check(error.length&&!items.count);done=YES;}];Check(done&&Requests==before);
        // A departed entity page cannot cancel the same profile's discovery lookup.
        CreditService *owned=service();__block NSUInteger backgroundDone=0,pageDone=0;before=Requests;
        [owned creditPage:@"Q10" role:@"studio" continuation:nil owner:@"discovery:main" foreground:NO done:^(NSArray *items,NSDictionary *next,NSString *error){Check(!error&&items.count==1);backgroundDone++;}];
        [owned creditPage:@"Q10" role:@"studio" continuation:nil done:^(NSArray *items,NSDictionary *next,NSString *error){pageDone++;}];[owned cancelCredits:@"Q10" role:@"studio"];owned.paused=NO;
        Check(Until(^BOOL{return backgroundDone==1;},2));Check(pageDone==0&&Requests-before==3);
        // Foreground can complete while the global budget holds background requests.
        CreditService *priority=service();[RWMetadataBudget shared].backgroundPaused=YES;before=Requests;backgroundDone=0;pageDone=0;
        [priority creditPage:@"Q10" role:@"studio" continuation:nil owner:@"discovery:main" foreground:NO done:^(NSArray *items,NSDictionary *next,NSString *error){Check(!error);backgroundDone++;}];priority.paused=NO;Spin(.03);Check(Requests==before);
        [priority creditPage:@"Q10" role:@"distributor" continuation:nil done:^(NSArray *items,NSDictionary *next,NSString *error){Check(!error);pageDone++;}];Check(Until(^BOOL{return pageDone==1;},2));Check(backgroundDone==0&&Requests-before==3);[RWMetadataBudget shared].backgroundPaused=NO;Check(Until(^BOOL{return backgroundDone==1;},2));Check(Requests-before==6);
        // A live blocked background request yields immediately and later resumes once.
        CreditService *yielding=service();HoldProduction=YES;backgroundDone=0;pageDone=0;before=Requests;
        [yielding creditPage:@"Q10" role:@"studio" continuation:nil owner:@"discovery:main" foreground:NO done:^(NSArray *items,NSDictionary *next,NSString *error){Check(!error);backgroundDone++;}];yielding.paused=NO;Check(Until(^BOOL{return Requests>before;},1));
        [yielding creditPage:@"Q10" role:@"network" continuation:nil done:^(NSArray *items,NSDictionary *next,NSString *error){Check(!error);pageDone++;HoldProduction=NO;}];Check(Until(^BOOL{return pageDone==1&&backgroundDone==1;},2));Check(Requests-before==7&&Peak==1);
        // Pause/restart retains ownership; owner cancellation never removes page work.
        CreditService *paused=service();HoldProduction=YES;backgroundDone=0;pageDone=0;before=Requests;
        [paused creditPage:@"Q10" role:@"studio" continuation:nil owner:@"discovery:main" foreground:NO done:^(NSArray *items,NSDictionary *next,NSString *error){backgroundDone++;}];paused.paused=NO;Check(Until(^BOOL{return Requests>before;},1));paused.paused=YES;
        [paused creditPage:@"Q10" role:@"studio" continuation:nil done:^(NSArray *items,NSDictionary *next,NSString *error){Check(!error);pageDone++;}];[paused cancelCreditRequestsForOwner:@"discovery:other"];[paused cancelCreditRequestsForOwner:@"discovery:main"];HoldProduction=NO;paused.paused=NO;Check(Until(^BOOL{return pageDone==1;},2));Check(!backgroundDone&&Requests-before==4);
        CreditService *failed=service();FailSearch=YES;backgroundDone=0;[failed creditPage:@"Q10" role:@"studio" continuation:@{@"sroffset":@8} owner:@"discovery:main" foreground:NO done:^(NSArray *items,NSDictionary *next,NSString *error){Check(error.length&&!items.count&&[next[@"sroffset"]intValue]==8);backgroundDone++;}];failed.paused=NO;Check(Until(^BOOL{return backgroundDone==1;},2));FailSearch=NO;
        // Three individually timely five-second responses still hit the 12-second whole-job deadline.
        CreditService *deadline=service();HoldProduction=NO;DelayAll=5;backgroundDone=0;[deadline creditPage:@"Q10" role:@"studio" continuation:@{@"sroffset":@8} owner:@"discovery:main" foreground:NO done:^(NSArray *items,NSDictionary *next,NSString *error){Check(error.length&&!items.count&&[next[@"sroffset"]intValue]==8);backgroundDone++;}];deadline.paused=NO;Check(Until(^BOOL{return backgroundDone==1;},13));DelayAll=0;
        // A paused foreground request also expires, instead of keeping the page
        // busy indefinitely. It must not start after the service resumes.
        CreditService *waiting=service();__block NSUInteger waitingDone=0;NSUInteger waitingBefore=Requests;
        [waiting creditPage:@"Q10" role:@"studio" continuation:@{@"sroffset":@16} done:^(NSArray *items,NSDictionary *next,NSString *error){Check(error.length&&!items.count&&[next[@"sroffset"]intValue]==16);waitingDone++;}];
        // Foreground pages have the same whole-chain bound, preserve their cursor,
        // reject the late third response, and permit an explicit retry.
        CreditService *frontDeadline=service();DelayAll=5;pageDone=0;
        [frontDeadline creditPage:@"Q10" role:@"studio" continuation:@{@"sroffset":@8} done:^(NSArray *items,NSDictionary *next,NSString *error){Check(error.length&&!items.count&&[next[@"sroffset"]intValue]==8);pageDone++;}];frontDeadline.paused=NO;
        Check(Until(^BOOL{return pageDone==1;},13));DelayAll=0;Spin(3);
        Check(pageDone==1&&!Active&&![frontDeadline record:@"tt101"].count);
        done=NO;[frontDeadline creditPage:@"Q10" role:@"studio" continuation:@{@"sroffset":@8} done:^(NSArray *items,NSDictionary *next,NSString *error){Check(!error&&items.count==1);done=YES;}];Check(Until(^BOOL{return done;},2));
        Check(Until(^BOOL{return waitingDone==1;},5));before=Requests;waiting.paused=NO;Spin(.05);Check(waitingDone==1&&Requests==before&&waitingBefore<Requests);
    }@finally{[RWMetadataBudget shared].backgroundPaused=NO;for(CreditService *s in services)[s cancelPending];Spin(.03);Check(Active==0);}
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
