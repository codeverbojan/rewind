#import "../RWDiscoveryMetadata.h"
#import "../RWArtworkPolicy.h"
#import "../RWAtomicWriter.h"
static NSUInteger Requests,Mode;static int Checks,Failures;
static NSString *const ImageRoot=@"https://static.tvmaze.com/uploads/images/original_untouched/";
#define C(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
@interface ArtProtocol:NSURLProtocol @end
@implementation ArtProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)r{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r{return r;}
- (void)startLoading {
 Requests++;NSString *path=self.request.URL.path;id value=@{};NSInteger status=200;
 if([path hasPrefix:@"/lookup/"])value=@{@"id":@11115,@"externals":@{@"imdb":Mode==2?@"tt9999999":@"tt1380596"},@"image":@{@"original":[ImageRoot stringByAppendingString:@"poster.jpg"]}};
 else if([path hasSuffix:@"/images"]){
  if(Mode==5)return;
  if(Mode==4)status=503;
  value=Mode==1?@[
   @{@"type":@"banner",@"resolutions":@{@"original":@{@"url":[ImageRoot stringByAppendingString:@"banner.jpg"],@"width":@1280,@"height":@720}}},
   @{@"type":@"background",@"resolutions":@{@"original":@{@"url":[ImageRoot stringByAppendingString:@"bad.jpg"],@"width":NSNull.null,@"height":@720}}},
   @{@"type":@"background",@"resolutions":@{@"original":@{@"url":@"https://unrelated.example/backdrop.jpg",@"width":@1280,@"height":@720}}},
   @{@"type":@"background",@"main":@YES,@"resolutions":@{@"original":@{@"url":[ImageRoot stringByAppendingString:@"background.jpg"],@"width":@1280,@"height":@720}}}
  ]:@[];
 }else if([path hasSuffix:@"/episodebynumber"])value=@{@"season":@1,@"number":@1,@"_links":@{@"show":@{@"href":Mode==3?@"https://api.tvmaze.com/shows/169":@"https://api.tvmaze.com/shows/11115"}},@"image":@{@"original":[ImageRoot stringByAppendingString:@"still.jpg"]}};
 NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:@{}];
 [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:[NSJSONSerialization dataWithJSONObject:value options:0 error:nil]];[self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading{}
@end
@interface ArtMetadata:RWDiscoveryMetadata
- (void)accept:(NSDictionary *)record imdb:(NSString *)imdb;
@end
@implementation ArtMetadata
+ (NSURLSessionConfiguration *)sessionConfiguration{NSURLSessionConfiguration *c=[NSURLSessionConfiguration ephemeralSessionConfiguration];c.protocolClasses=@[ArtProtocol.class];return c;}
@end
static void Spin(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];}
static void Wait(BOOL(^ready)(void),double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(!ready()&&end.timeIntervalSinceNow>0)Spin(.01);C(ready());}
int main(){@autoreleasepool{
 NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
 NSDictionary *meta=@{@"id":@"tt1380596",@"type":@"series",@"background":@"https://images.metahub.space/background/medium/tt1380596/img"};
 for(NSUInteger mode=0;mode<=5;mode++){
  Mode=mode;Requests=0;ArtMetadata *s=[[ArtMetadata alloc]initWithPath:[folder stringByAppendingPathComponent:[@(mode)stringValue]] cached:@{@"titles":@{@"tt1380596":@{@"imdb":@"tt1380596",@"entityID":@"Q42",@"fetchedAt":@123}}} seed:@{}];
  [s refreshArtwork:meta];[s refreshArtwork:meta];C(Requests==0);s.paused=NO;
  Wait(^BOOL{return [s.diagnostics[@"kind"]isEqual:@"titleArtwork"];},mode==5?9:2);
  NSDictionary *record=[s record:@"tt1380596"],*art=record[@"artwork"];C([record[@"entityID"]isEqual:@"Q42"]&&[record[@"fetchedAt"]isEqual:@123]);
  NSArray *urls=[RWArtworkPolicy URLsForMeta:[s enrich:meta] landscape:YES];
  if(mode==0){C(Requests==3);C([art[@"backgroundKind"]isEqual:@"episode"]);C([urls.firstObject hasSuffix:@"still.jpg"]);}
  if(mode==1){C(Requests==2);C([art[@"backgroundKind"]isEqual:@"background"]);C([urls.firstObject hasSuffix:@"background.jpg"]);C([art[@"background"]count]==1);}
  if(mode==2){C(Requests==1);C(!art);C([urls.firstObject containsString:@"metahub"]);}
  if(mode==3){C(Requests==3);C(![art[@"background"]count]);C([art[@"poster"]count]==1);C([art[@"checkedAt"]doubleValue]==0);}
  if(mode==4||mode==5){C(Requests==2);C([art[@"poster"]count]==1);C([s.diagnostics[@"error"]length]>0);C([art[@"checkedAt"]doubleValue]==0);}
  NSUInteger before=Requests;[s refreshArtwork:meta];Spin(.02);C(Requests==before);
  if(mode==0){[s accept:@{@"imdb":@"tt1380596",@"entityID":@"Q99"} imdb:@"tt1380596"];C([[s record:@"tt1380596"][@"artwork"]isEqual:art]);
   NSMutableDictionary *wrong=[meta mutableCopy];wrong[@"id"]=@"tt9999999";wrong[@"discovery"]=record;C(![[RWArtworkPolicy URLsForMeta:wrong landscape:YES].firstObject hasSuffix:@"still.jpg"]);
   wrong=[meta mutableCopy];wrong[@"type"]=@"movie";wrong[@"discovery"]=record;C(![[RWArtworkPolicy URLsForMeta:wrong landscape:YES].firstObject hasSuffix:@"still.jpg"]);
  }
  [s invalidate];
 }
 Mode=0;Requests=0;ArtMetadata *cancel=[[ArtMetadata alloc]initWithPath:[folder stringByAppendingPathComponent:@"cancel"] bundled:@""];
 [cancel refreshArtwork:meta];[cancel cancelPending];cancel.paused=NO;Spin(.05);C(Requests==0&&![[cancel record:@"tt1380596"]count]);
 [cancel refreshArtwork:@{@"id":@"tt1380596\n",@"type":@"series"}];[cancel refreshArtwork:@{@"id":@"tt1380596",@"type":@"movie"}];C(Requests==0);[cancel invalidate];[cancel refreshArtwork:meta];C(Requests==0);
 Spin(1.1);__block BOOL idle=NO;[[RWAtomicWriter shared]whenIdle:^{idle=YES;}];Wait(^BOOL{return idle;},3);[NSFileManager.defaultManager removeItemAtPath:folder error:nil];C(![NSFileManager.defaultManager fileExistsAtPath:folder]);
 printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
