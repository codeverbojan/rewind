#import <Foundation/Foundation.h>
#import "../RWRemoteMKVProbe.h"
static NSData *fixture;static NSString *mode;static BOOL requestedRange;
@interface FixtureProtocol:NSURLProtocol @end
@implementation FixtureProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request{return [request.URL.host isEqual:@"fixture.invalid"];}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request{return request;}
- (void)startLoading {
    requestedRange=[[self.request valueForHTTPHeaderField:@"Range"]isEqual:@"bytes=0-2097151"];
    NSInteger status=[mode isEqual:@"expired"]?403:[mode isEqual:@"no-range"]?200:206;
    NSString *range=[mode isEqual:@"wrong-range"]?@"bytes 100-999/1000":[NSString stringWithFormat:@"bytes 0-%lu/%lu",(unsigned long)fixture.length-1,(unsigned long)fixture.length];
    NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":[mode isEqual:@"html"]?@"text/html":@"video/x-matroska",@"Content-Range":range}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:[mode isEqual:@"oversized"]?[NSMutableData dataWithLength:3*1024*1024]:fixture];
    [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end
int main(int argc,const char **argv){@autoreleasepool{
    if(argc!=2)return 2;fixture=[NSData dataWithContentsOfFile:@(argv[1])];if(!fixture.length)return 2;int checks=0,failures=0;
#define CHECK(x) do{checks++;if(!(x)){failures++;fprintf(stderr,"FAIL line %d mode %s\n",__LINE__,mode.UTF8String);}}while(0)
    for(NSString *scenario in @[@"range",@"no-range",@"expired",@"wrong-range",@"html",@"oversized",@"cancel"]){
        mode=scenario;requestedRange=NO;__block BOOL finished=NO;__block NSDictionary *media=nil;__block NSString *error=nil;__block BOOL onMain=NO;
        NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;config.protocolClasses=@[FixtureProtocol.class];
        RWRemoteMKVProbe *probe=[[RWRemoteMKVProbe alloc]initWithURL:[NSURL URLWithString:@"https://fixture.invalid/movie.mkv?access=preserved"] configuration:config completion:^(NSDictionary *m,NSURL *url,NSString *e){finished=YES;media=m;error=e;onMain=NSThread.isMainThread&&[url.query isEqual:@"access=preserved"];}];
        BOOL cancelled=[mode isEqual:@"cancel"];if(cancelled)[probe cancel];
        NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:cancelled?.15:3];
        while(!finished&&[deadline timeIntervalSinceNow]>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
        if(cancelled){CHECK(!finished);continue;}
        CHECK(finished&&onMain&&requestedRange);
        if([mode isEqual:@"range"]||[mode isEqual:@"no-range"])CHECK(!error&&[media[@"width"]intValue]>0);
        else CHECK(error.length>0&&!media);
        [probe cancel];
    }
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
