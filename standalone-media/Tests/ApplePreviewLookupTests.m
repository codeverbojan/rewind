#import "../RWApplePreviewLookup.h"
#import "../RWMetadataBudget.h"
#import "../RWTrailers.h"
#import "../RWAtomicWriter.h"
static NSString *Folder;static NSUInteger Requests,Active,Peak;static int Checks,Failures;static BOOL Hold,Mismatch,Oversize,Unavailable,NetworkFailure;static double PreviewDelay;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
static BOOL Until(BOOL(^done)(void),double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(!done()&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];return done();}
@interface AppleProtocol:NSURLProtocol
@property(atomic) BOOL stopped,counted;
@end
@implementation AppleProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)r{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r{return r;}
- (void)releaseCount {@synchronized(AppleProtocol.class){if(self.counted){self.counted=NO;Active--;}}}
- (void)startLoading {
    @synchronized(AppleProtocol.class){Requests++;Active++;Peak=MAX(Peak,Active);self.counted=YES;}if(Hold)return;if(NetworkFailure){[self releaseCount];[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorServerCertificateUntrusted userInfo:nil]];return;}
    NSString *host=self.request.URL.host,*path=self.request.URL.path,*name=nil;NSDictionary *params;NSMutableDictionary *p=[NSMutableDictionary new];for(NSURLQueryItem *item in [NSURLComponents componentsWithURL:self.request.URL resolvingAgainstBaseURL:NO].queryItems)if(item.value)p[item.name]=item.value;params=p;
    BOOL half=[params[@"srsearch"]containsString:@"tt0369179"]||[params[@"ids"]containsString:@"Q189267"]||[path containsString:@"4syd3ylis0va9bpj1y923v20g"];
    if([host isEqual:@"www.wikidata.org"])name=[params[@"action"]isEqual:@"query"]?(half?@"halfmen-search.json":@"severance-search.json"):@"series-identities.json";
    else if([host isEqual:@"tv.apple.com"])name=half?@"halfmen-page.html":@"severance-page.html";
    else if([host isEqual:@"play-edge.itunes.apple.com"])name=@"severance-trailer-playlist.m3u8";
    else name=[path containsString:@"audio"]?@"severance-audio-variant.m3u8":@"severance-video-variant.m3u8";
    NSData *body=[NSData dataWithContentsOfFile:[Folder stringByAppendingPathComponent:name]];
    if(Mismatch&&[name isEqual:@"series-identities.json"]){NSString *s=[[NSString alloc]initWithData:body encoding:NSUTF8StringEncoding];body=[[s stringByReplacingOccurrencesOfString:@"tt11280740" withString:@"tt99999999"]dataUsingEncoding:NSUTF8StringEncoding];}
    if(Oversize)body=[NSMutableData dataWithLength:2*1024*1024+1];NSInteger status=Unavailable?429:200;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((PreviewDelay?:.01)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(self.stopped)return;NSHTTPURLResponse *r=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/octet-stream",@"Retry-After":@"120"}];[self.client URLProtocol:self didReceiveResponse:r cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:body];[self releaseCount];[self.client URLProtocolDidFinishLoading:self];});
}
- (void)stopLoading {self.stopped=YES;[self releaseCount];}
@end
int main(int argc,const char **argv){@autoreleasepool{
    Folder=@(argv[1]);NSURLSessionConfiguration *configuration=[NSURLSessionConfiguration ephemeralSessionConfiguration];configuration.protocolClasses=@[AppleProtocol.class];NSMutableArray *services=[NSMutableArray new];RWApplePreviewLookup *(^service)(void)=^RWApplePreviewLookup *{RWApplePreviewLookup *s=[[RWApplePreviewLookup alloc]initWithConfiguration:configuration];[services addObject:s];return s;};
    NSDictionary *meta=@{@"id":@"tt11280740",@"type":@"series",@"name":@"Severance"};NSArray *ids=@[@"umc.cmc.1srk2goyh2q2zdxcx605w8vtx"];__block NSUInteger completions=0;__block NSDictionary *result=nil;__block NSString *failure=nil;
    void(^done)(NSDictionary *,NSString *)=^(NSDictionary *s,NSString *e){CHECK(NSThread.isMainThread);completions++;result=s;failure=e;};
    NSString *temporary=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[[NSFileManager defaultManager]createDirectoryAtPath:temporary withIntermediateDirectories:YES attributes:nil error:nil];
    @try{
        RWApplePreviewLookup *s=service();NSUInteger before=Requests;[s resolve:meta knownIDs:@[] done:done];CHECK(Until(^BOOL{return completions==1;},3));CHECK(result&&!failure&&[result[@"kind"]isEqual:@"apple-hls"]);CHECK(Requests-before==6);CHECK([result[@"hlsMaster"]containsString:@"video.m3u8"]&&[result[@"hlsAudio"]containsString:@"https://"]);CHECK(!result[@"url"]);CHECK([result[@"width"]intValue]<=1280&&[result[@"height"]intValue]<=720);CHECK(Peak==1);CHECK([s.diagnostics[@"steps"]count]==6);CHECK([s.diagnostics[@"stage"]isEqual:@"audio_playlist"]&&[s.diagnostics[@"resolved"]boolValue]);CHECK(![[s.diagnostics description]containsString:@"m3u8"]);
        before=Requests;[s resolve:meta knownIDs:@[] done:done];CHECK(completions==2&&result&&Requests==before);
        RWApplePreviewLookup *known=service();[known resolve:meta knownIDs:ids done:done];CHECK(Until(^BOOL{return completions==3;},3));CHECK(result&&Requests-before==4);
        RWApplePreviewLookup *missing=service();before=Requests;[missing resolve:@{@"id":@"tt0369179",@"type":@"series",@"name":@"Two and a Half Men"} knownIDs:@[] done:done];CHECK(Until(^BOOL{return completions==4;},3));CHECK(!result&&failure.length&&Requests-before==3);
        Mismatch=YES;RWApplePreviewLookup *wrong=service();before=Requests;[wrong resolve:meta knownIDs:@[] done:done];CHECK(Until(^BOOL{return completions==5;},3));CHECK(!result&&failure.length&&Requests-before==2);Mismatch=NO;
        Hold=YES;RWApplePreviewLookup *cancelled=service();before=Requests;[cancelled resolve:meta knownIDs:ids done:done];CHECK(Until(^BOOL{return Requests>before;},1));[cancelled cancel];CHECK(completions==6&&!result&&[failure isEqual:@"Cancelled"]);Hold=NO;[cancelled resolve:meta knownIDs:ids done:done];CHECK(Until(^BOOL{return completions==7;},3));CHECK(result&&!failure);
        Oversize=YES;RWApplePreviewLookup *large=service();[large resolve:meta knownIDs:ids done:done];CHECK(Until(^BOOL{return completions==8;},3));CHECK(!result&&failure.length);Oversize=NO;
        Unavailable=YES;RWApplePreviewLookup *limited=service();[limited resolve:meta knownIDs:ids done:done];CHECK(Until(^BOOL{return completions==9;},3));CHECK(!result&&failure.length);before=Requests;Unavailable=NO;[limited resolve:meta knownIDs:ids done:done];CHECK(completions==10&&!result&&failure.length&&Requests==before);
        // Each response would fit its own timeout, but the entire chain must end.
        PreviewDelay=2;RWApplePreviewLookup *slow=service();double began=NSProcessInfo.processInfo.systemUptime;[slow resolve:meta knownIDs:@[] done:done];CHECK(Until(^BOOL{return completions==11;},7));CHECK(!result&&failure.length&&NSProcessInfo.processInfo.systemUptime-began<6.5);PreviewDelay=0;
        // Exercise the actual shared trailer facade, its cache and fallback chain.
        RWTrailers *facade=[[RWTrailers alloc]initWithCache:[temporary stringByAppendingPathComponent:@"cache.json"] bundled:@"" configuration:configuration];before=Requests;NSUInteger start=completions;[facade resolve:meta done:done];[facade resolve:meta done:done];CHECK(Until(^BOOL{return completions==start+2;},3));CHECK(result&&[result[@"kind"]isEqual:@"apple-hls"]&&Requests-before==6);before=Requests;[facade resolve:meta done:done];CHECK(completions==start+3&&result&&Requests==before);
        [facade failed:meta[@"id"] embedded:NO];[facade resolve:meta done:done];CHECK(completions==start+4&&!result&&failure.length&&Requests==before);
        NSDictionary *half=@{@"id":@"tt0369179",@"type":@"series",@"name":@"Two and a Half Men",@"trailers":@[@{@"type":@"trailer",@"source":@"abcdefghijk"}]};[facade resolve:half done:done];CHECK(Until(^BOOL{return completions==start+5;},3));CHECK([result[@"youtubeID"]isEqual:@"abcdefghijk"]&&Requests-before==3);[facade embeddedUnsupported];before=Requests;[facade resolveNative:half done:done];CHECK(completions==start+6&&!result&&Requests==before);
        RWTrailers *aborted=[[RWTrailers alloc]initWithCache:[temporary stringByAppendingPathComponent:@"cancel.json"] bundled:@"" configuration:configuration];Hold=YES;before=Requests;[aborted resolve:meta done:done];CHECK(Until(^BOOL{return Requests>before;},1));[aborted cancel:meta[@"id"]];CHECK(completions==start+7&&!result&&[failure isEqual:@"Cancelled"]);Hold=NO;[aborted resolve:meta done:done];CHECK(Until(^BOOL{return completions==start+8;},3));CHECK(result&&[result[@"kind"]isEqual:@"apple-hls"]);
        [aborted failed:meta[@"id"]];before=Requests;[aborted resolveNative:meta done:done];CHECK(completions==start+9&&result&&Requests==before);[aborted resolve:meta done:done];CHECK(completions==start+10&&result&&Requests==before);
        __block BOOL flushed=NO;[[RWAtomicWriter shared]whenIdle:^{flushed=YES;}];CHECK(Until(^BOOL{return flushed;},1));NSDictionary *persisted=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[temporary stringByAppendingPathComponent:@"cache.json"]] options:0 error:nil];CHECK(!persisted[meta[@"id"]][@"source"][@"hlsVideo"]);facade=nil;aborted=nil;
        // A TLS failure is temporary, preserves its exact stage/code, and cannot
        // become a thirty-minute claim that the title has no native preview.
        NetworkFailure=YES;RWTrailers *failed=[[RWTrailers alloc]initWithCache:[temporary stringByAppendingPathComponent:@"network.json"] bundled:@"" configuration:configuration];start=completions;
        [failed resolve:meta done:done];CHECK(Until(^BOOL{return completions==start+1;},2));CHECK(!result&&failure.length);NSDictionary *trace=failed.diagnostics[@"native"];
        CHECK([trace[@"failure_kind"]isEqual:@"transient"]&&[trace[@"stage"]isEqual:@"identity_search"]);
        CHECK([trace[@"steps"][0][@"error_code"]integerValue]==NSURLErrorServerCertificateUntrusted);CHECK([failed.diagnostics[@"cache_seconds"]intValue]==60);
        flushed=NO;[[RWAtomicWriter shared]whenIdle:^{flushed=YES;}];CHECK(Until(^BOOL{return flushed;},1));NSDictionary *network=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[temporary stringByAppendingPathComponent:@"network.json"]] options:0 error:nil];
        double remaining=[network[meta[@"id"]][@"nativeUnavailableUntil"]doubleValue]-NSDate.date.timeIntervalSince1970;CHECK(remaining>0&&remaining<=60);NetworkFailure=NO;
        before=Requests;[failed resolve:meta done:done];CHECK(completions==start+2&&Requests==before&&!result);CHECK([failed.diagnostics[@"native"][@"stage"]isEqual:@"identity_search"]);
        failed=nil;
        // An old untyped miss must not block the upgraded resolver. Preserve
        // independently observed failures and existing working native sources.
        double future=NSDate.date.timeIntervalSince1970+1700;NSString *legacyPath=[temporary stringByAppendingPathComponent:@"legacy.json"];
        NSDictionary *legacy=@{meta[@"id"]:@{@"source":@{},@"expires":@(future),@"nativeUnavailableUntil":@(future)},@"tt22222222":@{@"source":@{@"url":@"https://example.test/preview.mp4"},@"expires":@(future),@"nativeUnavailableUntil":@(future)},@"tt33333333":@{@"source":@{},@"expires":@(future),@"nativeUnavailableUntil":@(future),@"nativeFailedUntil":@(future)},@"tt44444444":@{@"source":@{},@"expires":@(future),@"nativeUnavailableUntil":@(future),@"nativeFailureKind":@"unavailable"},@"__embeddedRuntime":@{@"unsupportedUntil":@(future),@"expires":@(future)}};
        [[NSJSONSerialization dataWithJSONObject:legacy options:0 error:nil]writeToFile:legacyPath atomically:YES];RWTrailers *upgraded=[[RWTrailers alloc]initWithCache:legacyPath bundled:@"" configuration:configuration];before=Requests;start=completions;
        [upgraded resolve:meta done:done];CHECK(Until(^BOOL{return completions==start+1;},3));CHECK(result&&[result[@"kind"]isEqual:@"apple-hls"]&&Requests-before==6);
        before=Requests;[upgraded resolve:@{@"id":@"tt22222222",@"type":@"movie"} done:done];CHECK([result[@"url"]isEqual:@"https://example.test/preview.mp4"]&&Requests==before);
        [upgraded resolve:@{@"id":@"tt33333333",@"type":@"series"} done:done];CHECK(!result&&Requests==before);[upgraded resolve:@{@"id":@"tt44444444",@"type":@"series"} done:done];CHECK(!result&&Requests==before);
        flushed=NO;[[RWAtomicWriter shared]whenIdle:^{flushed=YES;}];CHECK(Until(^BOOL{return flushed;},1));NSDictionary *migrated=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:legacyPath] options:0 error:nil];CHECK(!migrated[@"tt22222222"][@"nativeUnavailableUntil"]);CHECK([migrated[@"__embeddedRuntime"]isEqual:legacy[@"__embeddedRuntime"]]);upgraded=nil;
    }@finally{for(RWApplePreviewLookup *s in services)[s invalidate];CHECK(Until(^BOOL{return Active==0;},1));CHECK([RWMetadataBudget.shared.diagnostics[@"active"]intValue]==0);[[NSFileManager defaultManager]removeItemAtPath:temporary error:nil];}
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
