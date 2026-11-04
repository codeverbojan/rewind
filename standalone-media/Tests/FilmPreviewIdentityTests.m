#import <Foundation/Foundation.h>
#import "../RWTrailers.h"
#import "../RWAtomicWriter.h"
#import "../RWMetadataBudget.h"
static NSString *Folder;static NSUInteger Requests;static NSMutableArray *Paths;static BOOL WrongClaim,Hold;
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
static BOOL Wait(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:3];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];return ready();}
@interface FilmIdentityProtocol:NSURLProtocol
@property(atomic) BOOL stopped;
@end
@implementation FilmIdentityProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)r{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r{return r;}
- (void)startLoading {
 Requests++;[Paths addObject:self.request.URL.path];if(Hold)return;
 BOOL entity=[self.request.URL.path containsString:@"Special:EntityData"];
 NSData *data=[self.request.URL.host isEqual:@"itunes.apple.com"]?[NSData dataWithContentsOfFile:[Folder stringByAppendingPathComponent:@"interstellar-itunes.json"]]:entity?[NSData dataWithContentsOfFile:[Folder stringByAppendingPathComponent:@"interstellar-entity.json"]]:[@"{\"query\":{\"search\":[]}}" dataUsingEncoding:NSUTF8StringEncoding];
 if(WrongClaim&&entity){NSString *s=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];data=[[s stringByReplacingOccurrencesOfString:@"tt0816692" withString:@"tt9999999"]dataUsingEncoding:NSUTF8StringEncoding];}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,50*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(self.stopped)return;NSHTTPURLResponse *r=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}];[self.client URLProtocol:self didReceiveResponse:r cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:data];[self.client URLProtocolDidFinishLoading:self];});
}
- (void)stopLoading{self.stopped=YES;}
@end
int main(int argc,const char **argv){@autoreleasepool{
 Folder=@(argv[1]);Paths=[NSMutableArray new];RWMetadataBudget.shared.paused=NO;RWMetadataBudget.shared.backgroundPaused=NO;
 NSString *temp=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[[NSFileManager defaultManager]createDirectoryAtPath:temp withIntermediateDirectories:YES attributes:nil error:nil];
 NSURLSessionConfiguration *config=[NSURLSessionConfiguration ephemeralSessionConfiguration];config.protocolClasses=@[FilmIdentityProtocol.class];
 __block NSUInteger serial=0;NSMutableArray *services=[NSMutableArray new];
 RWTrailers *(^service)(NSDictionary *)=^RWTrailers *(NSDictionary *cache){NSString *path=[temp stringByAppendingPathComponent:[NSString stringWithFormat:@"%lu.json",(unsigned long)++serial]];if(cache)[[NSJSONSerialization dataWithJSONObject:cache options:0 error:nil]writeToFile:path atomically:YES];RWTrailers *s=[[RWTrailers alloc]initWithCache:path bundled:@"/nonexistent" configuration:config];[services addObject:s];return s;};
 NSDictionary *discovery=@{@"imdb":@"tt0816692",@"entityID":@"Q13417189",@"source":@"https://www.wikidata.org/wiki/Q13417189"};
 NSDictionary *movie=@{@"id":@"tt0816692",@"name":@"Interstellar",@"type":@"movie",@"releaseInfo":@"2014",@"discovery":discovery};
 __block NSUInteger completed=0;__block NSDictionary *source=nil;__block NSString *error=nil;
 void(^done)(NSDictionary *,NSString *)=^(NSDictionary *s,NSString *e){CHECK(NSThread.isMainThread);source=s;error=e;completed++;};
 @try{
  RWTrailers *s=service(nil);NSUInteger before=Requests;
  [s resolveNative:movie done:done];[s resolveNative:movie done:done];CHECK(Wait(^BOOL{return completed==2;}));CHECK(source[@"url"]&&[source[@"appleID"]isEqual:@"960891136"]&&!error);CHECK(Requests-before==2);CHECK([Paths containsObject:@"/wiki/Special:EntityData/Q13417189.json"]);CHECK([s.diagnostics[@"native"][@"route"]isEqual:@"cached_verified_entity"]);CHECK([s.diagnostics[@"native"][@"steps"]count]==2);
  before=Requests;[s resolveNative:movie done:done];CHECK(completed==3&&source&&Requests==before);
  [s failed:movie[@"id"] embedded:NO];[s resolveNative:movie done:done];CHECK(completed==4&&!source&&Requests==before);
  WrongClaim=YES;RWTrailers *wrong=service(nil);before=Requests;[wrong resolveNative:movie done:done];CHECK(Wait(^BOOL{return completed==5;}));CHECK(!source&&Requests-before==1);WrongClaim=NO;
  for(NSDictionary *bad in @[@{},@{@"imdb":@"tt9999999",@"entityID":@"Q13417189",@"source":@"https://www.wikidata.org/wiki/Q13417189"},@{@"imdb":@"tt0816692",@"entityID":@"Q13417189/../../x",@"source":@"https://www.wikidata.org/wiki/Q13417189/../../x"},@{@"imdb":@"tt0816692",@"entityID":@"Q13417189",@"source":@"https://evil.test/Q13417189"}]){
   NSMutableDictionary *m=[movie mutableCopy];m[@"discovery"]=bad;RWTrailers *invalid=service(nil);NSUInteger target=completed+1;[invalid resolveNative:m done:done];CHECK(Wait(^BOOL{return completed==target;}));CHECK(!source&&[Paths.lastObject isEqual:@"/w/api.php"]);
  }
  NSDictionary *old=@{movie[@"id"]:@{@"source":@{},@"expires":@(NSDate.date.timeIntervalSince1970+900),@"nativeUnavailableUntil":@(NSDate.date.timeIntervalSince1970+900),@"nativeFailureKind":@"unavailable",@"nativeDiagnostics":@{}}};
  RWTrailers *upgrade=service(old);NSUInteger target=completed+1;before=Requests;[upgrade resolveNative:movie done:done];CHECK(Wait(^BOOL{return completed==target;}));CHECK(source&&Requests-before==2);
  NSMutableDictionary *newEntry=[old[movie[@"id"]]mutableCopy];newEntry[@"nativeLookupRevision"]=@3;RWTrailers *newCache=service(@{movie[@"id"]:newEntry});before=Requests;target=completed+1;[newCache resolveNative:movie done:done];CHECK(completed==target&&!source&&Requests==before);
  newEntry[@"nativeLookupRevision"]=@1;newEntry[@"nativeFailedUntil"]=@(NSDate.date.timeIntervalSince1970+60);RWTrailers *failed=service(@{movie[@"id"]:newEntry});target=completed+1;[failed resolveNative:movie done:done];CHECK(completed==target&&!source&&Requests==before);
  // A sparse detail shell can arrive before Cinemeta's year. It must not
  // perform/cache a failed lookup that blocks the later complete title.
  RWTrailers *sparse=service(nil);NSMutableDictionary *partial=[movie mutableCopy];[partial removeObjectForKey:@"releaseInfo"];
  before=Requests;target=completed+1;[sparse resolveNative:partial done:done];CHECK(Wait(^BOOL{return completed==target;}));CHECK(!source&&Requests==before);
  target=completed+1;[sparse resolveNative:movie done:done];CHECK(Wait(^BOOL{return completed==target;}));CHECK(source&&[source[@"appleID"]isEqual:@"960891136"]&&Requests-before==2);
  Hold=YES;RWTrailers *cancelled=service(nil);before=Requests;target=completed+1;[cancelled resolveNative:movie done:done];CHECK(Wait(^BOOL{return Requests>before;}));[cancelled cancel:movie[@"id"]];CHECK(completed==target&&!source&&[error isEqual:@"Cancelled"]);Hold=NO;
 }@finally{for(RWTrailers *s in services)[s cancel:movie[@"id"]];__block BOOL saved=NO;[[RWAtomicWriter shared]whenIdle:^{saved=YES;}];CHECK(Wait(^BOOL{return saved;}));[[NSFileManager defaultManager]removeItemAtPath:temp error:nil];}
 printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
