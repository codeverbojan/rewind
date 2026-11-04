#import "../RWDiscoveryMetadata.h"
#import "../RWCast.h"
#import "../RWAtomicWriter.h"
static int Checks,Failures;static NSUInteger Requests,Active,Peak,Mode;static NSData *HTML;static NSMutableArray *URLs;
static void Check(BOOL ok,NSString *label){Checks++;if(!ok){Failures++;fprintf(stderr,"FAIL %s\n",label.UTF8String);}}
static NSDictionary *Claim(id value){return @{@"mainsnak":@{@"datavalue":@{@"value":value}}};}
static NSDictionary *Human(NSString *qid,NSString *property,NSString *pid){return @{@"id":qid,@"labels":@{@"en":@{@"value":@"Jodi Benson"}},@"claims":@{property:@[Claim(pid)],@"P31":@[Claim(@{@"id":@"Q5"})]}};}
static void Spin(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];}
static BOOL Until(BOOL(^predicate)(void),double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(!predicate()&&end.timeIntervalSinceNow>0)Spin(.005);return predicate();}
@interface PersonProtocol:NSURLProtocol
@property(atomic,assign)BOOL active;
@end
@implementation PersonProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)r{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r{return r;}
- (void)releaseCount {@synchronized(PersonProtocol.class){if(self.active){Active--;self.active=NO;}}}
- (void)startLoading {
    NSUInteger mode;NSString *url=self.request.URL.absoluteString;@synchronized(PersonProtocol.class){mode=Mode;Requests++;Active++;Peak=MAX(Peak,Active);self.active=YES;[URLs addObject:url];}
    if(mode==6)return;
    BOOL cast=[self.request.URL.host isEqual:@"www.themoviedb.org"];NSDictionary *json;
    if([url containsString:@"list=search"])json=@{@"query":@{@"search":mode==7?@[]:mode==1?@[@{@"title":@"Q1138602"},@{@"title":@"Q999"}]:@[@{@"title":@"Q1138602"}]}};
    else {NSMutableDictionary *entity=[Human(@"Q1138602",@"P4985",mode==2?@"111":@"63978")mutableCopy];if(mode==3)entity[@"claims"]=@{@"P4985":@[Claim(@"63978")],@"P31":@[Claim(@{@"id":@"Q11424"})]};if(mode==4)entity[@"claims"]=@{@"P4985":@[@{@"rank":@"deprecated",@"mainsnak":Claim(@"63978")[@"mainsnak"]}],@"P31":@[Claim(@{@"id":@"Q5"})]};json=@{@"entities":mode==1?@{@"Q1138602":entity,@"Q999":Human(@"Q999",@"P4985",@"63978")}:@{@"Q1138602":entity}};}
    NSData *data=cast?(mode==8?[@"<html>temporarily unavailable</html>" dataUsingEncoding:NSUTF8StringEncoding]:HTML):[NSJSONSerialization dataWithJSONObject:json options:0 error:nil];NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:mode==5?429:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Retry-After":@"120"}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:data];[self releaseCount];[self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {[self releaseCount];}
@end
@interface PersonService:RWDiscoveryMetadata @end
@implementation PersonService
+ (NSURLSessionConfiguration *)sessionConfiguration {NSURLSessionConfiguration *c=[NSURLSessionConfiguration ephemeralSessionConfiguration];c.protocolClasses=@[PersonProtocol.class];return c;}
@end
@interface CastService:RWCast @end
@implementation CastService
+ (NSURLSessionConfiguration *)sessionConfiguration {return [PersonService sessionConfiguration];}
@end
int main(int argc,char **argv){@autoreleasepool{
    NSString *fixtures=@(argv[1]);HTML=[NSData dataWithContentsOfFile:[fixtures stringByAppendingPathComponent:@"toy-story-3-cast.html"]];URLs=[NSMutableArray new];
    NSDictionary *meta=@{@"id":@"tt0435761",@"name":@"Toy Story 3",@"moviedb_id":@10193,@"type":@"movie",@"releaseInfo":@"2010"};NSArray *people=[RWCast publicMoviePeople:[[NSString alloc]initWithData:HTML encoding:NSUTF8StringEncoding] meta:meta];
    NSDictionary *jodi=[[people filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *p,NSDictionary *b){return [p[@"name"]isEqual:@"Jodi Benson"];}]]firstObject];Check(jodi!=nil,@"Real cast fixture contains target actor");Check([jodi[@"providerPersonID"]isEqual:@"63978"],@"Parser keeps provider ID");
    NSDictionary *ref=[RWCast personReference:jodi];Check([ref isEqual:@{@"property":@"P4985",@"value":@"63978"}],@"Validated provider URL and ID map to documented property");
    NSDictionary *real=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[fixtures stringByAppendingPathComponent:@"jodi-entities.json"]] options:0 error:nil];Check([[RWCast canonicalPerson:real[@"entities"][@"Q1138602"] reference:ref][@"id"]isEqual:@"Q1138602"],@"Real exact human record accepted");
    for(NSDictionary *change in @[@{@"providerPersonID":@"2"},@{@"personURL":@"https://www.themoviedb.org.evil.invalid/person/63978"},@{@"personURL":@"https://www.themoviedb.org/movie/63978"},@{@"personURL":@"http://www.themoviedb.org/person/63978"},@{@"personURL":@"https://user@www.themoviedb.org/person/63978"},@{@"personURL":@"https://www.themoviedb.org/person/63978?other=1"},@{@"provider":@"Unknown"}]){NSMutableDictionary *bad=[jodi mutableCopy];[bad addEntriesFromDictionary:change];Check(![RWCast personReference:bad],@"Malformed or mismatched reference rejected");}
    Check([[RWCast personReference:@{@"provider":@"TVmaze",@"sourceURL":@"https://www.tvmaze.com/people/3388/jeffrey-dean-morgan"}][@"property"]isEqual:@"P11449"],@"Legacy TVmaze URL supplies exact ID without refetch");
    Check([RWCast canonicalPerson:Human(@"Q20",@"P11449",@"3388") reference:@{@"property":@"P11449",@"value":@"3388"}]!=nil,@"TVmaze human verified");
    NSArray *known=@[@{@"id":@"Q1138602",@"name":@"Jodi Benson"}];
    Check([[RWCast knownPersonID:jodi titleCredits:known]isEqual:@"Q1138602"],@"Existing exact-title credit wins even when provider reference exists");
    Check(![RWCast knownPersonID:jodi titleCredits:@[@{@"id":@"Q2",@"name":@"Different person"}]].length,@"Different name within title does not match");
    Check(![RWCast knownPersonID:jodi titleCredits:[known arrayByAddingObject:@{@"id":@"Q3",@"name":@"Jodi Benson"}]].length,@"Ambiguous same-title names rejected");
    Check(![RWCast knownPersonID:jodi titleCredits:@[@{@"id":@"not-canonical",@"name":@"Jodi Benson"}]].length,@"Invalid canonical credit rejected");
    Check([[RWCast knownPersonID:@{@"name":@"Jodi Benson",@"personID":@"Q1138602"} titleCredits:@[@{@"id":@"Q2",@"name":@"Jodi Benson"}]]isEqual:@"Q1138602"],@"Previously verified person ID cannot be replaced by name matching");
    Check(![RWCast knownPersonID:@{@"name":@""} titleCredits:@[@{@"id":@"Q2",@"name":@""}]].length,@"Empty names cannot establish identity");
    NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];NSMutableArray *services=[NSMutableArray new];
    PersonService *(^service)(NSString *,NSDictionary *)=^PersonService *(NSString *name,NSDictionary *cache){PersonService *s=[[PersonService alloc]initWithPath:[folder stringByAppendingPathComponent:name] cached:cache?:@{} seed:@{}];[services addObject:s];return s;};
    PersonService *normal=service(@"normal.json",nil);__block NSUInteger replies=0;__block NSDictionary *result=nil;
    for(int i=0;i<2;i++)[normal resolvePerson:jodi done:^(NSDictionary *record,NSString *error){Check(NSThread.isMainThread&&!error,@"Main-thread success");result=record;replies++;}];Check(Requests==0,@"Paused service does not request");normal.paused=NO;Check(Until(^BOOL{return replies==2;},2),@"Coalesced result delivered");Check(Requests==2&&Peak==1,@"Only search and claims requests, serial budget");Check([result[@"id"]isEqual:@"Q1138602"],@"Exact canonical identity delivered");Check([URLs[0]containsString:@"haswbstatement%3AP4985%3D63978"],@"Request searches provider ID, not name");
    NSUInteger before=Requests;[normal resolvePerson:jodi done:^(NSDictionary *record,NSString *error){Check([record[@"id"]isEqual:@"Q1138602"]&&!error,@"Cached identity returned");}];Check(Requests==before,@"Repeat visit has no identity network requests");
    for(NSUInteger mode=1;mode<=5;mode++){Mode=mode;PersonService *s=service([NSString stringWithFormat:@"bad%lu.json",(unsigned long)mode],nil);__block BOOL done=NO;[s resolvePerson:jodi done:^(NSDictionary *record,NSString *error){Check(!record&&error.length,@"Ambiguous, mismatch, nonhuman, deprecated, rate-limit rejected");done=YES;}];s.paused=NO;Check(Until(^BOOL{return done;},2),@"Failure completes");before=Requests;[s resolvePerson:jodi done:^(NSDictionary *record,NSString *error){Check(!record&&error.length,@"Retry cooldown preserves honest failure");}];Check(Requests==before,@"Failed lookup does not hammer provider");}
    Mode=6;PersonService *cancel=service(@"cancel.json",nil);__block BOOL called=NO;[cancel resolvePerson:jodi done:^(NSDictionary *record,NSString *error){called=YES;}];cancel.paused=NO;Check(Until(^BOOL{return Active==1;},1),@"Cancellable request active");[cancel cancelPending];Check(Until(^BOOL{return Active==0;},1)&&!called,@"Cancelled lookup cannot deliver stale identity");
    PersonService *paused=service(@"pause.json",nil);__block BOOL resumed=NO;[paused resolvePerson:jodi done:^(NSDictionary *record,NSString *error){resumed=record!=nil;}];paused.paused=NO;Check(Until(^BOOL{return Active==1;},1),@"Pause test started");paused.paused=YES;Check(Until(^BOOL{return Active==0;},1),@"Pausing releases network budget");Mode=0;paused.paused=NO;Check(Until(^BOOL{return resumed;},2),@"Resume revalidates exact identity");
    // Legacy public cast refresh retains visible headshots until new IDs arrive.
    NSMutableDictionary *legacy=[jodi mutableCopy];[legacy removeObjectForKey:@"providerPersonID"];[legacy removeObjectForKey:@"personURL"];NSString *castPath=[folder stringByAppendingPathComponent:@"cast.json"];
    [[NSJSONSerialization dataWithJSONObject:@{meta[@"id"]:@{@"people":@[legacy],@"expires":@(NSDate.date.timeIntervalSince1970+86400)}} options:0 error:nil]writeToFile:castPath atomically:YES];CastService *cast=[[CastService alloc]initWithCache:castPath];Check([cast cached:meta].count==1,@"Legacy portraits remain visible before refresh");__block NSArray *fresh=nil;[cast resolve:meta done:^(NSArray *p){fresh=p;}];Check(Until(^BOOL{return fresh!=nil;},2),@"Legacy cache refresh completes");Check(fresh.count==12&&[RWCast personReference:fresh.lastObject]!=nil,@"Migration refresh preserves actors and adds IDs");before=Requests;[cast resolve:meta done:^(NSArray *p){Check(p.count==12,@"New cast cache reused");}];Check(Requests==before,@"Migration only once after successful refresh");
    NSString *retryPath=[folder stringByAppendingPathComponent:@"cast-retry.json"];[[NSJSONSerialization dataWithJSONObject:@{meta[@"id"]:@{@"people":@[legacy],@"expires":@(NSDate.date.timeIntervalSince1970+86400)}} options:0 error:nil]writeToFile:retryPath atomically:YES];CastService *retry=[[CastService alloc]initWithCache:retryPath];Mode=8;__block NSArray *fallback=nil;before=Requests;
    [retry resolve:meta done:^(NSArray *p){fallback=p;}];Check(Until(^BOOL{return fallback!=nil;},2),@"Failed migration completes");Check([fallback isEqual:@[legacy]]&&[[retry cached:meta]isEqual:@[legacy]],@"Failed migration preserves original headshots and names");Check(Requests==before+1,@"Failed migration does not replace known cast with a partial fallback");before=Requests;[retry resolve:meta done:^(NSArray *p){}];Check(Requests==before,@"Legacy refresh retry is throttled");[retry cancel];Mode=0;
    Spin(1.1);__block BOOL idle=NO;[[RWAtomicWriter shared]whenIdle:^{idle=YES;}];Check(Until(^BOOL{return idle;},2),@"Writes settled");NSDictionary *disk=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"normal.json"]] options:0 error:nil];Check([disk[@"personLinks"]count]==1,@"Exact identity cache persisted");PersonService *reopened=service(@"reopen.json",disk);before=Requests;[reopened resolvePerson:jodi done:^(NSDictionary *record,NSString *error){Check([record[@"id"]isEqual:@"Q1138602"],@"Exact identity survives process restart");}];Check(Requests==before,@"Persisted identity avoids repeat request");
    for(PersonService *s in services)[s cancelPending];[cast cancel];Check(Active==0,@"All owned requests cleaned up");[NSFileManager.defaultManager removeItemAtPath:folder error:nil];printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
