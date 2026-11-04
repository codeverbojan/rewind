#import "../RWApplePreviewLookup.h"
#import "../RWApplePreviewPolicy.h"
#import "../RWTrailers.h"
#import "../RWAtomicWriter.h"
#import "../RWMetadataBudget.h"
static NSString *Folder;static NSUInteger Requests;static BOOL Hold,WrongYear,TimingMismatch;
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
static BOOL Wait(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:3];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];return ready();}
@interface MovieProtocol:NSURLProtocol
@property(atomic) BOOL stopped;
@end
@implementation MovieProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)r{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r{return r;}
- (void)startLoading {
 Requests++;if(Hold)return;NSString *host=self.request.URL.host,*path=self.request.URL.path;
 NSString *file=[host isEqual:@"tv.apple.com"]?@"../previews-130/oak.html":[host isEqual:@"play-edge.itunes.apple.com"]?@"../previews-130/oak-master.m3u8":[path containsString:@"audio"]?@"oak-audio.m3u8":@"oak-video.m3u8";
 NSData *data=[NSData dataWithContentsOfFile:[Folder stringByAppendingPathComponent:file]];
 if(WrongYear&&[host isEqual:@"tv.apple.com"]){NSString *s=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];data=[[s stringByReplacingOccurrencesOfString:@"\"2026\"" withString:@"\"2025\""]dataUsingEncoding:NSUTF8StringEncoding];}
 if(TimingMismatch&&[file isEqual:@"oak-audio.m3u8"]){NSString *s=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];data=[[s stringByReplacingOccurrencesOfString:@"#EXTINF:" withString:@"#EXTINF:1"]dataUsingEncoding:NSUTF8StringEncoding];}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(self.stopped)return;NSHTTPURLResponse *r=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}];[self.client URLProtocol:self didReceiveResponse:r cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:data];[self.client URLProtocolDidFinishLoading:self];});
}
- (void)stopLoading{self.stopped=YES;}
@end
int main(int argc,const char **argv){@autoreleasepool{
 Folder=@(argv[1]);RWMetadataBudget.shared.paused=NO;RWMetadataBudget.shared.backgroundPaused=NO;
 NSDictionary *meta=@{@"id":@"tt27165187",@"name":@"The End of Oak Street",@"type":@"movie",@"releaseInfo":@"2026"};NSString *identifier=@"umc.cmc.zgc43vpna42wfgfi645em0sm";
 NSDictionary *mapping=@{@"imdb":meta[@"id"],@"type":@"movie",@"name":meta[@"name"],@"year":@"2026",@"url":[@"https://tv.apple.com/us/movie/the-end-of-oak-street/" stringByAppendingString:identifier]};
 CHECK([[RWApplePreviewPolicy reviewedMovieIDs:mapping meta:meta]isEqual:@[identifier]]);
 for(NSDictionary *change in @[@{@"imdb":@"tt9999999"},@{@"type":@"series"},@{@"name":@"Other Film"},@{@"year":@"2025"},@{@"url":@"https://tv.apple.com.evil.test/us/movie/umc.cmc.abcdefghijk"},@{@"url":@"https://tv.apple.com/us/show/umc.cmc.abcdefghijk"}]){NSMutableDictionary *bad=[mapping mutableCopy];[bad addEntriesFromDictionary:change];CHECK(![RWApplePreviewPolicy reviewedMovieIDs:bad meta:meta].count);}
 NSDictionary *claims=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[Folder stringByAppendingPathComponent:@"../previews-130/interstellar-entity.json"]] options:0 error:nil];
 CHECK([[RWApplePreviewPolicy movieIDs:claims[@"entities"][@"Q13417189"] imdb:@"tt0816692"]containsObject:@"umc.cmc.1vrwat5k1ucm5k42q97ioqyq3"]);CHECK(![RWApplePreviewPolicy movieIDs:claims[@"entities"][@"Q13417189"] imdb:meta[@"id"]].count);
 NSURLSessionConfiguration *configuration=[NSURLSessionConfiguration ephemeralSessionConfiguration];configuration.protocolClasses=@[MovieProtocol.class];NSMutableArray *services=[NSMutableArray new];
 RWApplePreviewLookup *(^service)(void)=^RWApplePreviewLookup *{RWApplePreviewLookup *s=[[RWApplePreviewLookup alloc]initWithConfiguration:configuration];[services addObject:s];return s;};
 __block NSUInteger completed=0;__block NSDictionary *result;__block NSString *error;void(^done)(NSDictionary *,NSString *)=^(NSDictionary *s,NSString *e){CHECK(NSThread.isMainThread);completed++;result=s;error=e;};
 NSString *temp=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[[NSFileManager defaultManager]createDirectoryAtPath:temp withIntermediateDirectories:YES attributes:nil error:nil];
 @try{
 RWApplePreviewLookup *s=service();[s resolve:meta knownIDs:@[identifier] done:done];CHECK(Wait(^BOOL{return completed==1;}));CHECK(result&&!error&&[result[@"kind"]isEqual:@"apple-hls"]);CHECK(Requests==4);CHECK([result[@"movieID"]isEqual:identifier]&&[result[@"imdb"]isEqual:meta[@"id"]]);CHECK([result[@"duration"]intValue]==140);CHECK([result[@"hlsMaster"]containsString:@"mp4a.40.2"]);CHECK([s.diagnostics[@"steps"][0][@"stage"]isEqual:@"movie_page"]);
 NSUInteger before=Requests;[s resolve:meta knownIDs:@[identifier] done:done];CHECK(completed==2&&result&&Requests==before);
 WrongYear=YES;RWApplePreviewLookup *wrong=service();[wrong resolve:meta knownIDs:@[identifier] done:done];CHECK(Wait(^BOOL{return completed==3;}));CHECK(!result&&Requests-before==1);WrongYear=NO;
 TimingMismatch=YES;RWApplePreviewLookup *timing=service();[timing resolve:meta knownIDs:@[identifier] done:done];CHECK(Wait(^BOOL{return completed==4;}));CHECK(!result);TimingMismatch=NO;
 Hold=YES;RWApplePreviewLookup *cancelled=service();before=Requests;[cancelled resolve:meta knownIDs:@[identifier] done:done];CHECK(Wait(^BOOL{return Requests>before;}));[cancelled cancel];CHECK(completed==5&&!result&&[error isEqual:@"Cancelled"]);Hold=NO;
 NSString *seed=[temp stringByAppendingPathComponent:@"seed.json"],*cache=[temp stringByAppendingPathComponent:@"cache.json"];
 [[NSJSONSerialization dataWithJSONObject:@{meta[@"id"]:@{@"appleMovie":mapping}} options:0 error:nil]writeToFile:seed atomically:YES];
 [[NSJSONSerialization dataWithJSONObject:@{meta[@"id"]:@{@"source":@{},@"expires":@(NSDate.date.timeIntervalSince1970+900),@"nativeUnavailableUntil":@(NSDate.date.timeIntervalSince1970+900),@"nativeLookupRevision":@3,@"nativeFailureKind":@"unavailable"}} options:0 error:nil]writeToFile:cache atomically:YES];
 RWTrailers *facade=[[RWTrailers alloc]initWithCache:cache bundled:seed configuration:configuration];before=Requests;[facade resolveNative:meta done:done];CHECK(Wait(^BOOL{return completed==6;}));CHECK(result&&Requests-before==4);CHECK([facade.diagnostics[@"native"][@"resolved"]boolValue]);before=Requests;[facade resolveNative:meta done:done];CHECK(completed==7&&result&&Requests==before);
 [facade failed:meta[@"id"] embedded:NO];[facade resolveNative:meta done:done];CHECK(completed==8&&!result&&Requests==before);facade=nil;
 }@finally{for(RWApplePreviewLookup *s in services)[s invalidate];__block BOOL saved=NO;[[RWAtomicWriter shared]whenIdle:^{saved=YES;}];CHECK(Wait(^BOOL{return saved;}));CHECK([RWMetadataBudget.shared.diagnostics[@"active"]integerValue]==0);[[NSFileManager defaultManager]removeItemAtPath:temp error:nil];}
 printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
