#import <Foundation/Foundation.h>
#import "../RWCast.h"
#import "../RWAtomicWriter.h"
static NSString *FixtureRoot;static NSUInteger Requests;static BOOL RateLimit;
@interface CastProtocol : NSURLProtocol @end
@implementation CastProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request{return [request.URL.host isEqual:@"api.tvmaze.com"];}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request{return request;}
- (void)startLoading {
    if(RateLimit){Requests++;[self.client URLProtocol:self didReceiveResponse:[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:429 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Retry-After":@"600"}] cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocolDidFinishLoading:self];return;}
    if(++Requests==1){[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]];return;}
    NSString *file=[self.request.URL.path hasPrefix:@"/lookup/"]?@"tvmaze-show.json":@"tvmaze-cast.json";
    NSData *data=[NSData dataWithContentsOfFile:[FixtureRoot stringByAppendingPathComponent:file]];
    [self.client URLProtocol:self didReceiveResponse:[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}] cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data];[self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end
@interface TestCast : RWCast @end
@implementation TestCast
+ (NSURLSessionConfiguration *)sessionConfiguration {NSURLSessionConfiguration *c=[super sessionConfiguration];c.protocolClasses=@[CastProtocol.class];return c;}
@end
static BOOL Wait(BOOL(^done)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:3];while(!done()&&[end timeIntervalSinceNow]>0)[NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.01]];return done();}
int main(int argc,char **argv){@autoreleasepool{
    FixtureRoot=@(argv[1]);__block int checks=0,failures=0;void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *label){checks++;if(!ok){failures++;fprintf(stderr,"FAIL %s\n",label.UTF8String);}};
    NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[[NSFileManager defaultManager]createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];NSString *path=[folder stringByAppendingPathComponent:@"cast.json"];
    NSDictionary *meta=@{@"id":@"tt0369179",@"type":@"series"};NSDictionary *legacy=@{@"tt0369179":@{@"people":@[],@"expires":@(NSDate.date.timeIntervalSince1970+900)}};
    [[NSJSONSerialization dataWithJSONObject:legacy options:0 error:nil]writeToFile:path atomically:YES];TestCast *service=[[TestCast alloc]initWithCache:path];
    check([service cached:meta]==nil,@"Old empty entries are invalidated on upgrade");
    __block BOOL done=NO;__block NSArray *people=nil;[service resolve:meta done:^(NSArray *p){people=p;done=YES;}];check(Wait(^BOOL{return done;}),@"Offline request completes");
    check(!people.count&&[service.lastFailure[@"code"]integerValue]==NSURLErrorNotConnectedToInternet,@"Actual network error remains available");
    check([service cached:meta]==nil,@"Offline response does not poison the cast cache");
    done=NO;[service resolve:meta done:^(NSArray *p){people=p;done=YES;}];check(Wait(^BOOL{return done;})&&people.count>3&&Requests==3,@"Same title retries immediately and recovers its real cast");
    done=NO;[service resolve:meta done:^(NSArray *p){people=p;done=YES;}];check(done&&people.count>3&&Requests==3,@"Successful result is reused without another HTTP request");
    RateLimit=YES;TestCast *limited=[[TestCast alloc]initWithCache:[folder stringByAppendingPathComponent:@"limited.json"]];done=NO;[limited resolve:@{@"id":@"tt1234567",@"type":@"series"} done:^(NSArray *p){done=YES;}];check(Wait(^BOOL{return done;})&&[limited.lastFailure[@"http"]integerValue]==429,@"Rate-limited response is captured without caching empty cast");
    NSUInteger before=Requests;TestCast *next=[[TestCast alloc]initWithCache:[folder stringByAppendingPathComponent:@"next.json"]];done=NO;[next resolve:@{@"id":@"tt7654321",@"type":@"series"} done:^(NSArray *p){done=YES;}];check(done&&Requests==before,@"Provider cooldown is shared across title screens and resolver instances");check([next.lastFailure[@"retry_after_seconds"]doubleValue]>590,@"Provider Retry-After is respected");
    __block BOOL idle=NO;[[RWAtomicWriter shared]whenIdle:^{idle=YES;}];check(Wait(^BOOL{return idle;}),@"Cache writes finish before temporary files are removed");
    [service cancel];[[NSFileManager defaultManager]removeItemAtPath:folder error:nil];
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
