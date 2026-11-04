#import "../RWRatings.h"
#import "../RWAtomicWriter.h"
static int Checks,Failures;static NSString *Folder,*DisneyFolder,*KingFolder;static NSMutableArray *URLs;static BOOL Lag,Limited,Disney,King,PublisherUnavailable,PublisherMalformed;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static void Wait(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:8];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];CHECK(ready());}
@interface ClassifyProtocol:NSURLProtocol @end
@implementation ClassifyProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request{return request;}
- (void)startLoading {
 NSString *url=self.request.URL.absoluteString;@synchronized(URLs){[URLs addObject:url];}NSData *body=nil;NSInteger status=Limited?429:200;
 if(King&&[self.request.URL.host isEqual:@"www.disneyplus.com"])body=[NSData dataWithContentsOfFile:[KingFolder stringByAppendingPathComponent:@"king-disney.html"]];
 else if([self.request.URL.host isEqual:@"www.disneyplus.com"])body=[NSData dataWithContentsOfFile:[DisneyFolder stringByAppendingPathComponent:@"gravity-disney-page.html"]];
 else if([self.request.URL.host isEqual:@"tv.apple.com"])body=[NSData dataWithContentsOfFile:[Folder stringByAppendingPathComponent:@"arthur-apple-page.html"]];
 else if(Lag&&[url containsString:@"maxlag=5"])body=[@"{\"error\":{\"code\":\"maxlag\"}}" dataUsingEncoding:NSUTF8StringEncoding];
 else if(King&&[url containsString:@"action=query"])body=[@"{\"query\":{\"search\":[{\"title\":\"Q1135966\"}]}}" dataUsingEncoding:NSUTF8StringEncoding];
 else if(King)body=[NSData dataWithContentsOfFile:[KingFolder stringByAppendingPathComponent:@"king-wikidata.json"]];
 else if([url containsString:@"action=query"])body=[(Disney?@"{\"query\":{\"search\":[{\"title\":\"Q550555\"}]}}":@"{\"query\":{\"search\":[{\"title\":\"Q1056342\"}]}}") dataUsingEncoding:NSUTF8StringEncoding];
 else body=[NSData dataWithContentsOfFile:[(Disney?DisneyFolder:Folder) stringByAppendingPathComponent:Disney?@"gravity-wikidata-claims.json":@"arthur-wikidata-claims.json"]];
 if([@[@"tv.apple.com",@"www.disneyplus.com"]containsObject:self.request.URL.host]){if(PublisherUnavailable)status=503;if(PublisherMalformed)body=[@"<html>No classification</html>" dataUsingEncoding:NSUTF8StringEncoding];}
 NSURL *responseURL=[self.request.URL.host isEqual:@"www.disneyplus.com"]?[NSURL URLWithString:King?@"https://www.disneyplus.com/browse/entity-52b8dd8a-eff2-4ed2-9b8d-7c0039df1c53":@"https://www.disneyplus.com/browse/entity-9995dda1-d70a-4d15-98ba-72f1d10fa406"]:self.request.URL;
 NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc]initWithURL:responseURL statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:@{@"Retry-After":@"120"}];[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:body];[self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end
int main(int argc,const char **argv){@autoreleasepool{
 Folder=@(argv[1]);DisneyFolder=@(argv[2]);KingFolder=@(argv[3]);URLs=[NSMutableArray new];NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];NSURLSessionConfiguration *config=[NSURLSessionConfiguration ephemeralSessionConfiguration];config.protocolClasses=@[ClassifyProtocol.class];
 NSDictionary *meta=@{@"id":@"tt0169414",@"name":@"Arthur",@"type":@"series",@"releaseInfo":@"1996"};RWRatings *client=nil;
 @try{
 client=[[RWRatings alloc]initWithCache:[folder stringByAppendingPathComponent:@"one.json"] bundled:@"" configuration:config];Lag=YES;CHECK(![client isResolvingItems:@[meta]]);[client resolve:@[meta]];CHECK([client isResolvingItems:@[meta]]);CHECK(![client isResolvingItems:@[@{@"id":@"tt9999999"}]]);Wait(^BOOL{return !client.busy;});CHECK(URLs.count==1&&[URLs[0]containsString:@"maxlag=5"]);CHECK(![client rating:meta[@"id"]]);CHECK(![client isResolvingItems:@[meta]]);
 [client resolve:@[meta]];CHECK(URLs.count==1); // Background backs off.
 [client resolve:@[meta] interactive:YES];Wait(^BOOL{return !client.busy;});NSDictionary *record=[client rating:meta[@"id"]];CHECK([record[@"label"]isEqual:@"TV-G"]);CHECK([record[@"minimumAge"]integerValue]==0);CHECK(URLs.count==4);CHECK(![URLs[1]containsString:@"maxlag="]);CHECK(![URLs[2]containsString:@"maxlag="]);CHECK([URLs[3]hasPrefix:@"https://tv.apple.com/us/show/"]);
 NSUInteger before=URLs.count;[client resolve:@[meta] interactive:YES];CHECK(URLs.count==before&&!client.busy);client=nil;
 client=[[RWRatings alloc]initWithCache:[folder stringByAppendingPathComponent:@"many.json"] bundled:@"" configuration:config];NSMutableArray *many=[NSMutableArray arrayWithObject:meta];for(NSUInteger i=1;i<10;i++)[many addObject:@{@"id":[NSString stringWithFormat:@"tt%07lu",(unsigned long)(900000+i)],@"name":@"Other show",@"type":@"series",@"releaseInfo":@"1996"}];[client resolve:many interactive:YES];Wait(^BOOL{return !client.busy;});NSString *search=[URLs[before]stringByRemovingPercentEncoding];CHECK([search containsString:@"tt0900003"]&&! [search containsString:@"tt0900004"]);CHECK([client rating:@"tt0900001"]&&[[client rating:@"tt0900001"][@"minimumAge"]integerValue]==-1);CHECK(![client rating:@"tt0900004"]);client=nil;
 Limited=YES;client=[[RWRatings alloc]initWithCache:[folder stringByAppendingPathComponent:@"limited.json"] bundled:@"" configuration:config];[client resolve:@[meta] interactive:YES];Wait(^BOOL{return !client.busy;});before=URLs.count;[client resolve:@[meta] interactive:YES];CHECK(URLs.count==before&&!client.busy);CHECK(![client rating:meta[@"id"]]);
 client=nil;Limited=NO;Lag=NO;Disney=YES;
 // Live Gravity Falls has no P9751 Apple mapping, but its exact IMDb entity
 // links to Disney via P7596. A real formal rating must not become unknown.
 NSDictionary *gravity=@{@"id":@"tt1865718",@"name":@"Gravity Falls",@"type":@"series",@"releaseInfo":@"2012–2016"};
 client=[[RWRatings alloc]initWithCache:[folder stringByAppendingPathComponent:@"disney.json"] bundled:@"" configuration:config];before=URLs.count;[client resolve:@[gravity] interactive:YES];Wait(^BOOL{return !client.busy;});record=[client rating:gravity[@"id"]];CHECK([record[@"label"]isEqual:@"TV-Y7"]);CHECK(record&&[record[@"minimumAge"]integerValue]==7);CHECK(URLs.count==before+3);client=nil;
 // Temporary failures from either directly mapped publisher need the same
 // retry admission as the store path; they are not absent classifications.
 for(NSNumber *disney in @[@NO,@YES]){Disney=disney.boolValue;NSDictionary *title=Disney?gravity:meta;
  NSString *failPath=[folder stringByAppendingPathComponent:[NSString stringWithFormat:@"publisher-failure-%@.json",disney]];
  client=nil;client=[[RWRatings alloc]initWithCache:failPath bundled:@"" configuration:config];PublisherUnavailable=YES;double start=NSDate.date.timeIntervalSince1970;
  [client resolve:@[title] interactive:YES];Wait(^BOOL{return !client.busy;});NSDictionary *failure=[client rating:title[@"id"]];CHECK([failure[@"minimumAge"]intValue]==-1);CHECK([failure[@"retryAfter"]doubleValue]>=start+120);
  before=URLs.count;[client resolve:@[title] interactive:YES];CHECK(URLs.count==before&&!client.busy);
  client=nil;PublisherUnavailable=NO;PublisherMalformed=YES;
  client=[[RWRatings alloc]initWithCache:[failPath stringByAppendingString:@"-absent"] bundled:@"" configuration:config];[client resolve:@[title] interactive:YES];Wait(^BOOL{return !client.busy;});CHECK(![client rating:title[@"id"]][@"retryAfter"]);PublisherMalformed=NO;client=nil;
 }
 Disney=YES;
 // Negative cache entries produced before the additional publisher existed
 // must get one bounded new-policy attempt, not wait a full day.
 NSString *oldPath=[folder stringByAppendingPathComponent:@"old-negative.json"];
 [[NSJSONSerialization dataWithJSONObject:@{gravity[@"id"]:@{@"minimumAge":@(-1),@"publisherAttempted":@YES,@"checked":@(NSDate.date.timeIntervalSince1970)}} options:0 error:nil]writeToFile:oldPath atomically:YES];
 client=[[RWRatings alloc]initWithCache:oldPath bundled:@"" configuration:config];before=URLs.count;[client resolve:@[gravity] interactive:YES];Wait(^BOOL{return !client.busy;});CHECK([[client rating:gravity[@"id"]][@"label"]isEqual:@"TV-Y7"]);CHECK(URLs.count==before+3);

 client=nil;King=YES;NSDictionary *king=@{@"id":@"tt0118375",@"type":@"series",@"name":@"King of the Hill",@"releaseInfo":@"1997"};
 // The actual cached Apple TV-PG record conflicts with the linked publisher's
 // TV-14 classification. A normal expired refresh must review it, not stop at
 // the old positive rating. A stronger existing record must never be lowered.
 for(NSNumber *age in @[@10,@18]){
  NSString *path=[folder stringByAppendingPathComponent:[NSString stringWithFormat:@"conflict-%@.json",age]];
  NSDictionary *old=@{@"minimumAge":age,@"label":age.intValue==10?@"TV-PG":@"TV-MA",@"source":@"https://tv.apple.com/us/show/king-of-the-hill/umc.cmc.56wibku4o8ebq6vzfg6j41hgn",@"publisherPolicy":@2,@"checked":@(NSDate.date.timeIntervalSince1970-31*86400)};
  [[NSJSONSerialization dataWithJSONObject:@{king[@"id"]:old} options:0 error:nil]writeToFile:path atomically:YES];
  client=[[RWRatings alloc]initWithCache:path bundled:@"" configuration:config];before=URLs.count;[client resolve:@[king] interactive:YES];Wait(^BOOL{return !client.busy;});record=[client rating:king[@"id"]];
  CHECK([record[@"minimumAge"]intValue]==MAX(age.intValue,14));CHECK(URLs.count==before+3);CHECK([URLs.lastObject hasPrefix:@"https://www.disneyplus.com/series/wp/"]);client=nil;
 }
 client=[[RWRatings alloc]initWithCache:[folder stringByAppendingPathComponent:@"king-new.json"] bundled:@"" configuration:config];before=URLs.count;[client resolve:@[king] interactive:YES];Wait(^BOOL{return !client.busy;});record=[client rating:king[@"id"]];CHECK([record[@"minimumAge"]intValue]==14);CHECK(URLs.count==before+3);CHECK([URLs.lastObject hasPrefix:@"https://www.disneyplus.com/series/wp/"]);client=nil;
 // The reviewed publisher seed corrects the real fresh Apple cache immediately,
 // without a forced refresh or extra opening-network work. Stronger cache wins.
 NSString *bundled=[KingFolder stringByAppendingPathComponent:@"../../Resources/Rewind/age-ratings.json"];
 for(NSNumber *age in @[@10,@18]){
  NSString *path=[folder stringByAppendingPathComponent:[NSString stringWithFormat:@"fresh-%@.json",age]];
  [[NSJSONSerialization dataWithJSONObject:@{king[@"id"]:@{@"minimumAge":age,@"checked":@(NSDate.date.timeIntervalSince1970),@"publisherPolicy":@2}} options:0 error:nil]writeToFile:path atomically:YES];
  client=[[RWRatings alloc]initWithCache:path bundled:bundled configuration:config];before=URLs.count;record=[client rating:king[@"id"]];CHECK([record[@"minimumAge"]intValue]==MAX(14,age.intValue));
  CHECK([client.snapshot[@"publishers"][king[@"id"]][@"minimumAge"]intValue]==14);[client resolve:@[king] interactive:YES];CHECK(URLs.count==before&&!client.busy);client=nil;
 }
 }@finally{client=nil;__block BOOL flushed=NO;[[RWAtomicWriter shared]whenIdle:^{flushed=YES;}];Wait(^BOOL{return flushed;});[NSFileManager.defaultManager removeItemAtPath:folder error:nil];}
 printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
