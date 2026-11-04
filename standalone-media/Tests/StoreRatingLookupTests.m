#import "../RWRatings.h"
#import "../RWAtomicWriter.h"
#import "../RWPublisherRatingPolicy.h"
#import "../RWApplePreviewLookup.h"
#import "../RWRatingPolicy.h"
static int Checks,Failures;static NSString *Folder;static NSMutableArray *URLs;static BOOL Hold,LargeSearch,LargePage,Unavailable;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static void Wait(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:8];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];CHECK(ready());}
@interface StoreProtocol:NSURLProtocol @end
@implementation StoreProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request{return request;}
- (void)startLoading {
 NSString *url=self.request.URL.absoluteString;[URLs addObject:url];if(Hold)return;NSData *body=nil;NSURL *responseURL=self.request.URL;
 if([self.request.URL.host isEqual:@"itunes.apple.com"]&&[self.request.URL.path isEqual:@"/search"])body=[NSData dataWithContentsOfFile:[Folder stringByAppendingPathComponent:@"kenan-search.json"]];
 else if([self.request.URL.host isEqual:@"itunes.apple.com"]){body=[NSData dataWithContentsOfFile:[Folder stringByAppendingPathComponent:@"kenan-show.html"]];responseURL=[NSURL URLWithString:@"https://tv.apple.com/us/show/kenan--kel/umc.cmc.6wtltbrut449hzqsgnb77r89a"];} 
 else if([url containsString:@"action=query"])body=[@"{\"query\":{\"search\":[{\"title\":\"Q1065187\"}]}}" dataUsingEncoding:NSUTF8StringEncoding];
 else body=[NSData dataWithContentsOfFile:[Folder stringByAppendingPathComponent:@"rating-entities.json"]];
 if(LargeSearch&&[self.request.URL.path isEqual:@"/search"])body=[NSMutableData dataWithLength:128*1024+1];if(LargePage&&![self.request.URL.path isEqual:@"/search"])body=[NSMutableData dataWithLength:2*1024*1024+1];
 NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc]initWithURL:responseURL statusCode:(Unavailable&&[self.request.URL.host isEqual:@"itunes.apple.com"]?503:200) HTTPVersion:@"HTTP/1.1" headerFields:@{}];[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:body];[self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end
int main(int argc,const char **argv){@autoreleasepool{
 Folder=@(argv[1]);URLs=[NSMutableArray new];NSString *cache=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];NSURLSessionConfiguration *config=[NSURLSessionConfiguration ephemeralSessionConfiguration];config.protocolClasses=@[StoreProtocol.class];RWRatings *client=nil;
 @try{
  client=[[RWRatings alloc]initWithCache:cache bundled:@"" configuration:config];NSDictionary *meta=@{@"id":@"tt0115231",@"name":@"Kenan & Kel",@"type":@"series",@"releaseInfo":@"1996–2001"};
  [client resolve:@[meta] interactive:YES];Wait(^BOOL{return !client.busy;});NSDictionary *r=[client rating:meta[@"id"]];CHECK([r[@"label"]isEqual:@"TV-G"]);CHECK(r&&[r[@"minimumAge"]intValue]==0);CHECK(URLs.count==4);
  // Both captured official identities resolve, independently of season advisories.
  NSDictionary *dinosaur=@{@"id":@"tt1460205",@"name":@"Dinosaur Train",@"type":@"series",@"releaseInfo":@"2009"};
  for(NSArray *entry in @[@[@"kenan",meta,@"TV-G"],@[@"dinosaur",dinosaur,@"TV-Y"]]){
   NSData *search=[NSData dataWithContentsOfFile:[Folder stringByAppendingPathComponent:[entry[0]stringByAppendingString:@"-search.json"]]];
   NSString *show=[RWPublisherRatingPolicy storeShowURL:search meta:entry[1]];CHECK(show.length);CHECK(![show containsString:@"?"]);
   NSData *html=[NSData dataWithContentsOfFile:[Folder stringByAppendingPathComponent:[entry[0]stringByAppendingString:@"-show.html"]]];
   NSString *page=[entry[0]isEqual:@"kenan"]?@"https://tv.apple.com/us/show/kenan--kel/umc.cmc.6wtltbrut449hzqsgnb77r89a":@"https://tv.apple.com/us/show/dinosaur-train/umc.cmc.53ryo62osm2egvd6napvwkw69";
   NSDictionary *record=[RWPublisherRatingPolicy storeRecord:html URL:[NSURL URLWithString:page] meta:entry[1]];CHECK([record[@"label"]isEqual:entry[2]]);
   for(NSDictionary *change in @[@{@"name":@"Other show"},@{@"releaseInfo":@"2025"},@{@"releaseInfo":@""},@{@"id":@"invalid"},@{@"type":@"movie"}]){NSMutableDictionary *m=[entry[1]mutableCopy];[m addEntriesFromDictionary:change];CHECK(![RWPublisherRatingPolicy storeRecord:html URL:[NSURL URLWithString:page] meta:m]);}
   CHECK(![RWPublisherRatingPolicy storeRecord:html URL:[NSURL URLWithString:[page stringByReplacingOccurrencesOfString:@"/us/" withString:@"/gb/"]] meta:entry[1]]);
   CHECK(![RWPublisherRatingPolicy storeRecord:html URL:[NSURL URLWithString:[page stringByReplacingOccurrencesOfString:@"/show/" withString:@"/movie/"]] meta:entry[1]]);
   CHECK(![RWPublisherRatingPolicy storeRecord:html URL:[NSURL URLWithString:[page stringByReplacingOccurrencesOfString:@"/show/" withString:@"/show/other/"]] meta:entry[1]]);
   NSMutableDictionary *root=[NSJSONSerialization JSONObjectWithData:search options:NSJSONReadingMutableContainers error:nil];
   for(NSMutableDictionary *row in root[@"results"])row[@"contentAdvisoryRating"]=@"TV-MA";
   CHECK([[RWPublisherRatingPolicy storeShowURL:[NSJSONSerialization dataWithJSONObject:root options:0 error:nil] meta:entry[1]]isEqual:show]);
   NSDictionary *first=root[@"results"][0];
   for(NSDictionary *change in @[@{@"artistName":@"Other"},@{@"artistId":@YES},@{@"artistId":@12.5},@{@"artistId":@"123"},@{@"artistViewUrl":@"https://itunes.apple.com/us/tv-show/other/id999999"},@{@"country":@"GBR"},@{@"collectionType":@"TV Episode"},@{@"wrapperType":@"track"}]){
    NSMutableDictionary *row=[first mutableCopy];[row addEntriesFromDictionary:change];CHECK(![RWPublisherRatingPolicy storeShowURL:[NSJSONSerialization dataWithJSONObject:@{@"resultCount":@1,@"results":@[row]} options:0 error:nil] meta:entry[1]]);
   }
   NSMutableDictionary *other=[first mutableCopy];other[@"artistId"]=@999999;other[@"artistViewUrl"]=@"https://itunes.apple.com/us/tv-show/other/id999999";
   CHECK(![RWPublisherRatingPolicy storeShowURL:[NSJSONSerialization dataWithJSONObject:@{@"resultCount":@2,@"results":@[first,other]} options:0 error:nil] meta:entry[1]]);
   for(NSString *bad in @[[show stringByReplacingOccurrencesOfString:@"https:" withString:@"http:"],[show stringByAppendingString:@"?x=1"],[show stringByAppendingString:@"#fragment"],[show stringByReplacingOccurrencesOfString:@"itunes.apple.com" withString:@"user@itunes.apple.com"],[show stringByReplacingOccurrencesOfString:@"itunes.apple.com" withString:@"itunes.apple.com.evil.test"],[show stringByReplacingOccurrencesOfString:@"itunes.apple.com" withString:@"itunes.apple.com:8443"],[show stringByReplacingOccurrencesOfString:@"/us/" withString:@"/gb/"]]){
    CHECK(![RWPublisherRatingPolicy allowsStoreURL:[NSURL URLWithString:bad] showURL:show]);NSMutableDictionary *row=[first mutableCopy];row[@"artistViewUrl"]=bad;CHECK(![RWPublisherRatingPolicy storeShowURL:[NSJSONSerialization dataWithJSONObject:@{@"resultCount":@1,@"results":@[row]} options:0 error:nil] meta:entry[1]]);
   }
  }
  CHECK(![RWPublisherRatingPolicy storeShowURL:[NSMutableData dataWithLength:128*1024+1] meta:meta]);
  CHECK([RWRatingPolicy needsLookup:@{@"minimumAge":@(-1),@"checked":@(NSDate.date.timeIntervalSince1970),@"publisherPolicy":@2} type:@"series" now:NSDate.date.timeIntervalSince1970]);
  CHECK(![RWRatingPolicy needsLookup:@{@"minimumAge":@7,@"checked":@(NSDate.date.timeIntervalSince1970),@"publisherPolicy":@2} type:@"series" now:NSDate.date.timeIntervalSince1970]);
  NSString *searchURL=[RWPublisherRatingPolicy storeSearchURL:meta];CHECK([searchURL containsString:@"Kenan%20%26%20Kel"]);CHECK(![searchURL containsString:@"term=Kenan &"]);
  double now=NSDate.date.timeIntervalSince1970;
  NSDictionary *retry=@{@"minimumAge":@(-1),@"publisherPolicy":@3,@"checked":@(now),@"retryAfter":@(now+120)};
  CHECK(![RWRatingPolicy needsLookup:retry type:@"series" now:now+119]);CHECK([RWRatingPolicy needsLookup:retry type:@"series" now:now+120]);
  NSString *failureCache=[cache stringByAppendingString:@"-failure"];RWRatings *failed=[[RWRatings alloc]initWithCache:failureCache bundled:@"" configuration:config];
  Unavailable=YES;[failed resolve:@[meta] interactive:YES];Wait(^BOOL{return !failed.busy;});NSDictionary *negative=[failed rating:meta[@"id"]];CHECK([negative[@"minimumAge"]intValue]<0);CHECK([negative[@"retryAfter"]doubleValue]>=now+120);CHECK(![RWRatingPolicy needsLookup:negative type:@"series" now:NSDate.date.timeIntervalSince1970]);Unavailable=NO;failed=nil;
  __block BOOL failureFlushed=NO;[[RWAtomicWriter shared]whenIdle:^{failureFlushed=YES;}];Wait(^BOOL{return failureFlushed;});[NSFileManager.defaultManager removeItemAtPath:failureCache error:nil];
  RWApplePreviewLookup *lookup=[[RWApplePreviewLookup alloc]initWithConfiguration:config];__block BOOL done=NO;
  @try{
   LargeSearch=YES;[lookup resolveStoreRating:meta done:^(NSDictionary *record,NSString *error){CHECK(!record&&error.length);done=YES;}];Wait(^BOOL{return done;});CHECK([lookup.diagnostics[@"requests"]intValue]==1);CHECK([lookup.diagnostics[@"steps"][0][@"bytes"]unsignedIntegerValue]<=128*1024);LargeSearch=NO;
   done=NO;LargePage=YES;[lookup resolveStoreRating:meta done:^(NSDictionary *record,NSString *error){CHECK(!record&&error.length);done=YES;}];Wait(^BOOL{return done;});CHECK([lookup.diagnostics[@"requests"]intValue]==2);CHECK([lookup.diagnostics[@"steps"][1][@"bytes"]unsignedIntegerValue]<=2*1024*1024);LargePage=NO;
   done=NO;Hold=YES;NSUInteger before=URLs.count;[lookup resolveStoreRating:meta done:^(NSDictionary *record,NSString *error){CHECK(!record&&[error isEqual:@"Cancelled"]);done=YES;}];Wait(^BOOL{return URLs.count==before+1;});[lookup cancel];CHECK(done);Hold=NO;
   done=NO;[lookup resolveStoreRating:meta done:^(NSDictionary *record,NSString *error){CHECK(record&&!error&&[record[@"label"]isEqual:@"TV-G"]);done=YES;}];Wait(^BOOL{return done;});CHECK([lookup.diagnostics[@"requests"]intValue]==2);
  }@finally{[lookup invalidate];}

 }@finally{client=nil;__block BOOL flushed=NO;[[RWAtomicWriter shared]whenIdle:^{flushed=YES;}];Wait(^BOOL{return flushed;});[NSFileManager.defaultManager removeItemAtPath:cache error:nil];}
 printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
