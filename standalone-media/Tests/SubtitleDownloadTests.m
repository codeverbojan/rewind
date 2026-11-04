#import "../RWSubtitleDownload.h"
static NSMutableSet *Live;
@interface SubtitleProtocol : NSURLProtocol
@end
@implementation SubtitleProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request{return [request.URL.host isEqual:@"subtitle.test"];}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r{return r;}
- (void)startLoading {
    @synchronized(Live){[Live addObject:self];}
    NSString *path=self.request.URL.path;
    if([path isEqual:@"/hold"])return;
    NSDictionary *headers=[path isEqual:@"/headers"]?@{@"Content-Length":@"4194304"}:@{@"Content-Type":[path isEqual:@"/html"]?@"text/html":@"text/plain"};
    NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:[path isEqual:@"/404"]?404:200 HTTPVersion:@"HTTP/1.1" headerFields:headers];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    if([path isEqual:@"/big"]){NSData *chunk=[NSMutableData dataWithLength:65536];for(int i=0;i<33;i++)[self.client URLProtocol:self didLoadData:chunk];}
    else if(![path isEqual:@"/headers"]){[self.client URLProtocol:self didLoadData:[@"1\n00:00:00,000 --> 00:01:00,000\nEnglish\n" dataUsingEncoding:NSUTF8StringEncoding]];}
    [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {@synchronized(Live){[Live removeObject:self];}}
@end
static void Spin(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];}
int main(){@autoreleasepool{
    __block NSUInteger checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line%d\n",__LINE__);}}while(0)
    Live=[NSMutableSet new];NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;config.protocolClasses=@[SubtitleProtocol.class];
    for(NSString *path in @[@"/good",@"/headers",@"/big",@"/404",@"/html"]){
        __block NSUInteger calls=0;__block NSData *body=nil;__block NSString *failure=nil;__block NSDictionary *metrics=nil;
        RWSubtitleDownload *download=[[RWSubtitleDownload alloc]initWithURL:[NSURL URLWithString:[@"https://subtitle.test" stringByAppendingString:path]] configuration:config completion:^(NSData *data,NSString *error,NSDictionary *m){CHECK(NSThread.isMainThread);calls++;body=data;failure=error;metrics=m;}];
        for(int i=0;i<200&&!calls;i++)Spin(.01);CHECK(calls==1);CHECK([metrics[@"peak_buffer_bytes"]unsignedIntegerValue]<=2*1024*1024);
        if([path isEqual:@"/good"]){CHECK(body.length>0&&!failure);CHECK([metrics[@"bytes"]unsignedIntegerValue]==body.length);}
        else {CHECK(!body&&failure.length);if([path isEqual:@"/headers"])CHECK([metrics[@"peak_buffer_bytes"]unsignedIntegerValue]==0);}
        [download cancel];Spin(.03);CHECK(calls==1);
    }
    __block NSUInteger cancelledCalls=0;
    RWSubtitleDownload *held=[[RWSubtitleDownload alloc]initWithURL:[NSURL URLWithString:@"https://subtitle.test/hold"] configuration:config completion:^(NSData *d,NSString *e,NSDictionary *m){cancelledCalls++;}];
    Spin(.03);[held cancel];Spin(.05);CHECK(cancelledCalls==0);
    __block NSUInteger invalidCalls=0;
    RWSubtitleDownload *invalid=[[RWSubtitleDownload alloc]initWithURL:[NSURL URLWithString:@"file:///tmp/captions.srt"] configuration:config completion:^(NSData *d,NSString *e,NSDictionary *m){invalidCalls++;CHECK(!d&&e.length);CHECK([m[@"bytes"]integerValue]==0);}];
    for(int i=0;i<100&&!invalidCalls;i++)Spin(.01);CHECK(invalidCalls==1);[invalid cancel];
    Spin(.05);@synchronized(Live){CHECK(Live.count==0);}
    printf("{\"checks\":%lu,\"failures\":%lu}\n",(unsigned long)checks,(unsigned long)failures);return failures?1:0;
}}
