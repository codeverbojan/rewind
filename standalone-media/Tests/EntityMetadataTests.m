#import "../RWDiscoveryMetadata.h"
#import "../RWAtomicWriter.h"
static NSUInteger Requests,Active,Peak,Mode;static NSMutableArray *URLs;static int Checks,Failures;
static NSDictionary *Claim(id value){return @{@"mainsnak":@{@"datavalue":@{@"value":value}}};}
static NSDictionary *Entity(void){return @{@"id":@"Q20",@"labels":@{@"en":@{@"value":@"Exact Person"}},@"descriptions":@{@"en":@{@"value":@"A brief description"}},@"claims":@{@"P18":@[Claim(@"Portrait.jpg")],@"P154":@[Claim(@"Logo.svg")],@"P106":@[Claim(@{@"id":@"Q101"})],@"P569":@[Claim(@{@"time":@"+1982-11-12T00:00:00Z",@"precision":@11,@"calendarmodel":@"http://www.wikidata.org/entity/Q1985727"})]},@"sitelinks":@{@"enwiki":@{@"title":@"Exact Person"}}};}
@interface EntityProtocol:NSURLProtocol
@property(atomic,assign) BOOL counted;
@end
@implementation EntityProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request{return request;}
- (void)releaseCount {@synchronized(EntityProtocol.class){if(self.counted){Active--;self.counted=NO;}}}
- (void)startLoading {
    NSString *url=self.request.URL.absoluteString;NSUInteger mode;
    @synchronized(EntityProtocol.class){Requests++;Active++;Peak=MAX(Peak,Active);self.counted=YES;[URLs addObject:url];mode=Mode;}
    if(mode==3&&[self.request.URL.host isEqual:@"en.wikipedia.org"])return; // deliberately hangs until the whole-job watchdog cancels it
    NSDictionary *json;
    if(mode==2)json=@{@"entities":@{}};
    else if([self.request.URL.host isEqual:@"en.wikipedia.org"])json=@{@"query":@{@"pages":@{@"1":@{@"ns":@0,@"title":@"Exact Person",@"extract":@"A verified longer biography for this person.",@"pageprops":@{@"wikibase_item":mode==1?@"Q999":@"Q20"}}}}};
    else if([self.request.URL.host isEqual:@"commons.wikimedia.org"]){NSString *file=[url containsString:@"Logo.svg"]?@"Logo.svg":@"Portrait.jpg";json=@{@"query":@{@"pages":@{@"1":@{@"title":[@"File:"stringByAppendingString:file],@"imageinfo":@[@{@"thumburl":[@"https://upload.wikimedia.org/"stringByAppendingString:file],@"descriptionurl":@"https://commons.wikimedia.org/wiki/File:Exact",@"extmetadata":@{@"Artist":@{@"value":@"Test artist"},@"LicenseShortName":@{@"value":@"CC BY 4.0"}}}]}}}};}
    else if([url containsString:@"props=labels&"])json=@{@"entities":@{@"Q101":@{@"labels":@{@"en":@{@"value":@"film actor"}}}}};
    else json=@{@"entities":@{@"Q20":Entity()}};
    NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
    void(^deliver)(void)=^{if(!self.counted)return;[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:[NSJSONSerialization dataWithJSONObject:json options:0 error:nil]];[self releaseCount];[self.client URLProtocolDidFinishLoading:self];};if(mode==3)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),deliver);else deliver();
}
- (void)stopLoading {[self releaseCount];}
@end
@interface EntityService:RWDiscoveryMetadata @end
@implementation EntityService
+ (NSURLSessionConfiguration *)sessionConfiguration {NSURLSessionConfiguration *config=[NSURLSessionConfiguration ephemeralSessionConfiguration];config.protocolClasses=@[EntityProtocol.class];return config;}
@end
static void Check(BOOL value){Checks++;if(!value){Failures++;fprintf(stderr,"FAIL check %d\n",Checks);}}
static void Spin(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];}
static BOOL Until(BOOL(^predicate)(void),double timeout){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:timeout];while(!predicate()&&end.timeIntervalSinceNow>0)Spin(.005);return predicate();}
static void Reset(NSUInteger mode){@synchronized(EntityProtocol.class){Requests=0;Peak=Active;URLs=[NSMutableArray new];Mode=mode;}}
int main(){@autoreleasepool{NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];NSMutableArray *services=[NSMutableArray new];
    EntityService *(^service)(NSString *,NSDictionary *)=^EntityService *(NSString *name,NSDictionary *seed){EntityService *s=[[EntityService alloc]initWithPath:[folder stringByAppendingPathComponent:name] cached:seed?:@{} seed:@{}];[services addObject:s];return s;};
    Reset(0);EntityService *normal=service(@"normal.json",nil);__block NSUInteger count=0,progress=0;__block NSDictionary *result=nil,*first=nil;
    for(int i=0;i<2;i++)[normal entityDetails:@"Q20" role:@"person" progress:^(NSDictionary *m){Check(NSThread.isMainThread);progress++;if(!first)first=m;} done:^(NSDictionary *m,NSString *error){Check(NSThread.isMainThread&&!error);result=m;count++;}];
    Check(Requests==0);normal.paused=NO;Check(Until(^BOOL{return count==2;},2));Check(Requests==4&&Peak==1);Check(progress>=6);Check([result[@"biography"]hasPrefix:@"A verified longer"]);Check([result[@"image"]hasSuffix:@"Portrait.jpg"]);Check([result[@"kindLabel"]isEqual:@"film actor"]);Check(!first[@"detailsVersion"]&&!first[@"image"]);Check([result[@"detailsVersion"]integerValue]==1);Check(![result[@"detailWarnings"]count]);
    NSArray *requests=[URLs copy];BOOL biographyURL=NO;for(NSString *url in requests)if([url containsString:@"en.wikipedia.org"]){biographyURL=[url containsString:@"exchars=1200"]&&[url containsString:@"wikibase_item%7Cdisambiguation"];}Check(biographyURL);
    NSUInteger previous=Requests;[normal entityDetails:@"Q20" role:@"cast" progress:^(NSDictionary *m){Check(NO);} done:^(NSDictionary *m,NSString *error){Check([m isEqual:result]&&!error);}];Check(Requests==previous);
    __block NSDictionary *logo=nil;[normal entity:@"Q20" role:@"studio" done:^(NSDictionary *m,NSString *error){logo=m;}];Check(Until(^BOOL{return logo!=nil;},1));Check(Requests==previous+2);Check([logo[@"imageRole"]isEqual:@"logo"]&&[logo[@"image"]hasSuffix:@"Logo.svg"]);Check(!logo[@"biographySourceURL"]);
    NSMutableDictionary *old=[result mutableCopy];old[@"expires"]=@0;old[@"detailsExpires"]=@0;NSDictionary *seed=@{@"entities":@{@"Q20:person":old}};
    Reset(1);EntityService *stale=service(@"stale.json",seed);__block NSDictionary *staleFirst=nil,*staleFinal=nil;[stale entityDetails:@"Q20" role:@"person" progress:^(NSDictionary *m){if(!staleFirst)staleFirst=m;} done:^(NSDictionary *m,NSString *error){staleFinal=m;}];Check([staleFirst[@"biography"]isEqual:result[@"biography"]]);stale.paused=NO;Check(Until(^BOOL{return staleFinal!=nil;},1));Check(Requests==3);Check([staleFinal[@"biography"]isEqual:result[@"biography"]]);Check([staleFinal[@"detailWarnings"]count]==1);Check([staleFinal[@"detailsExpires"]doubleValue]-NSDate.date.timeIntervalSince1970<901);
    Reset(0);EntityService *card=service(@"card.json",seed);__block NSDictionary *cardFinal=nil;[card entity:@"Q20" role:@"person" done:^(NSDictionary *m,NSString *error){cardFinal=m;}];card.paused=NO;Check(Until(^BOOL{return cardFinal!=nil;},1));Check(Requests==2);Check([cardFinal[@"biography"]isEqual:result[@"biography"]]);Check([cardFinal[@"biographySourceURL"]isEqual:result[@"biographySourceURL"]]);Check([cardFinal[@"facts"]isEqual:result[@"facts"]]);
    Reset(2);EntityService *missing=service(@"missing.json",nil);__block BOOL missingDone=NO;[missing entityDetails:@"Q20" role:@"person" progress:nil done:^(NSDictionary *m,NSString *error){Check(!m&&error.length);missingDone=YES;}];missing.paused=NO;Check(Until(^BOOL{return missingDone;},1));Check(Requests==1);[missing entityDetails:@"Q20" role:@"person" progress:nil done:^(NSDictionary *m,NSString *error){Check(!m&&error.length);}];Check(Requests==1);
    Reset(0);EntityService *cancel=service(@"cancel.json",nil);__block BOOL cancelled=NO,oldDone=NO;[cancel entityDetails:@"Q20" role:@"person" progress:^(NSDictionary *m){cancelled=YES;[cancel cancelPending];} done:^(NSDictionary *m,NSString *error){oldDone=YES;}];cancel.paused=NO;Check(Until(^BOOL{return cancelled;},1));Spin(.05);Check(Requests==1&&!oldDone);
    Reset(0);EntityService *pause=service(@"pause.json",nil);__block BOOL didPause=NO,pauseDone=NO;[pause entityDetails:@"Q20" role:@"person" progress:^(NSDictionary *m){if(!didPause){didPause=YES;pause.paused=YES;}} done:^(NSDictionary *m,NSString *error){pauseDone=YES;}];pause.paused=NO;Check(Until(^BOOL{return didPause;},1));Spin(.03);Check(Requests==1&&!pauseDone);pause.paused=NO;Check(Until(^BOOL{return pauseDone;},1));Check(Requests==5);
    Reset(0);EntityService *coalesce=service(@"coalesce.json",nil);__block NSUInteger good=0,busy=0;for(int i=0;i<9;i++)[coalesce entityDetails:@"Q20" role:@"cast" progress:nil done:^(NSDictionary *m,NSString *error){if(error)busy++;else good++;}];Check(busy==1);coalesce.paused=NO;Check(Until(^BOOL{return good==8;},1));Check(Requests==4);
    Reset(3);EntityService *deadline=service(@"deadline.json",nil);__block BOOL deadlineDone=NO;__block NSDictionary *partial=nil;double started=NSDate.date.timeIntervalSince1970;
    [deadline entityDetails:@"Q20" role:@"person" progress:nil done:^(NSDictionary *m,NSString *error){partial=m;deadlineDone=YES;}];deadline.paused=NO;Check(Until(^BOOL{return deadlineDone;},9));double elapsed=NSDate.date.timeIntervalSince1970-started;Check(elapsed>=7.9&&elapsed<9);Check(Requests==4);Check([partial[@"name"]isEqual:@"Exact Person"]&&[partial[@"image"]length]);Check([partial[@"biography"]isEqual:@"A brief description"]);Check([partial[@"detailWarnings"]containsObject:@"Details refresh deadline"]);Check(Until(^BOOL{return Active==0;},.5));
    NSMutableDictionary *cache=[NSMutableDictionary new];for(int i=1;i<=70;i++){NSString *qid=[NSString stringWithFormat:@"Q%d",i];cache[[qid stringByAppendingString:@":person"]]=@{@"id":qid,@"name":qid,@"at":@(i),@"expires":@(NSDate.date.timeIntervalSince1970+86400)};}EntityService *lru=service(@"lru.json",@{@"entities":cache});NSUInteger lruBefore=Requests;[lru entity:@"Q1" role:@"person" done:^(NSDictionary *m,NSString *error){Check([m[@"id"]isEqual:@"Q1"]&&!error);}];Check(Requests==lruBefore);
    // Exercise real deferred serialization, not only in-memory callbacks.
    Spin(1.1);__block BOOL idle=NO;[[RWAtomicWriter shared]whenIdle:^{idle=YES;}];Check(Until(^BOOL{return idle;},2));NSDictionary *disk=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"normal.json"]] options:0 error:nil];Check([disk[@"entities"][@"Q20:person"][@"biography"]isEqual:result[@"biography"]]);EntityService *reopened=service(@"reopened.json",disk);NSUInteger before=Requests;[reopened entityDetails:@"Q20" role:@"person" progress:nil done:^(NSDictionary *m,NSString *error){Check([m[@"biography"]isEqual:result[@"biography"]]);}];Check(Requests==before);
    Check(lru.entitySnapshot.count==64);Check(lru.entitySnapshot[@"Q1:person"]!=nil);Check(lru.entitySnapshot[@"Q2:person"]==nil);for(EntityService *s in services)[s cancelPending];Check(Active==0);[NSFileManager.defaultManager removeItemAtPath:folder error:nil];printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
