#import "../RWDiscoveryMetadata.h"
#import "../RWAtomicWriter.h"
static NSUInteger Requests,Active,Peak,Mode;static BOOL EncodedProperties;static NSString *LastSearchURL;static int Checks,Failures;
@interface MetadataProtocol:NSURLProtocol @end
@implementation MetadataProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)r{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r{return r;}
- (void)startLoading {if([self.request.URL.absoluteString containsString:@"list=search"])LastSearchURL=self.request.URL.absoluteString;Requests++;Active++;Peak=MAX(Peak,Active);NSInteger status=Mode==1?429:200;NSDictionary *headers=Mode==1?@{@"Retry-After":@"120"}:@{@"Content-Type":@"application/json"};NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:headers];[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
 if(Mode==2){NSData *chunk=[NSMutableData dataWithLength:512*1024];for(int i=0;i<10;i++)[self.client URLProtocol:self didLoadData:chunk];}
 else if(Mode==7){NSDictionary *json=nil;NSString *url=self.request.URL.absoluteString;
 if([url containsString:@"commons.wikimedia.org"]){NSString *file=[url containsString:@"Studio.svg"]?@"Studio.svg":@"Portrait.jpg";json=@{@"query":@{@"pages":@{@"1":@{@"title":[@"File:" stringByAppendingString:file],@"imageinfo":@[@{@"thumburl":[@"https://upload.wikimedia.org/" stringByAppendingString:file],@"descriptionurl":@"https://commons.wikimedia.org/wiki/File:Test",@"extmetadata":@{@"LicenseShortName":@{@"value":@"CC BY 4.0"},@"Artist":@{@"value":@"Test artist"}}}]}}}};}
 else json=@{@"entities":@{@"Q20":@{@"id":@"Q20",@"labels":@{@"mul":@{@"value":@"Multilingual name"}},@"claims":@{@"P18":@[@{@"mainsnak":@{@"datavalue":@{@"value":@"Portrait.jpg"}}}],@"P154":@[@{@"mainsnak":@{@"datavalue":@{@"value":@"Studio.svg"}}}]}}}};
 [self.client URLProtocol:self didLoadData:[NSJSONSerialization dataWithJSONObject:json options:0 error:nil]];}
 else if(Mode==5||Mode==6){NSDictionary *json=@{@"query":@{@"search":@[]},@"continue":@{@"sroffset":Mode==5?@1537:@0,@"continue":@"-||"}};[self.client URLProtocol:self didLoadData:[NSJSONSerialization dataWithJSONObject:json options:0 error:nil]];}
 else if(Mode==3||Mode==4){NSString *url=self.request.URL.absoluteString;NSDictionary *json=nil;
 if([url containsString:@"list=search"])json=@{@"query":@{@"search":@[@{@"title":@"Q1"}]}};
 else if([url containsString:@"props=labels%7Cclaims"]){json=@{@"entities":@{@"Q21":@{@"id":@"Q21",@"claims":@{@"P31":@[@{@"mainsnak":@{@"datavalue":@{@"value":@{@"id":@"Q196600"}}}}]}}}};}
 else if([url containsString:@"props=claims%7Clabels"]){EncodedProperties=YES;json=@{@"entities":@{@"Q1":@{@"id":@"Q1",@"labels":@{@"en":@{@"value":@"A verified film"}},@"claims":@{@"P345":@[@{@"mainsnak":@{@"datavalue":@{@"value":@"tt0000100"}}}],@"P179":@[@{@"mainsnak":@{@"datavalue":@{@"value":@{@"id":@"Q21"}}}}],@"P364":@[@{@"mainsnak":@{@"datavalue":@{@"value":@{@"id":@"Q1860"}}}}],@"P31":@[@{@"mainsnak":@{@"datavalue":@{@"value":@{@"id":@"Q24862"}}}}],@"P57":@[@{@"mainsnak":@{@"datavalue":@{@"value":@{@"id":@"Q2"}}}}]}}}};}
 else {NSMutableDictionary *entities=[@{@"Q1860":@{@"labels":@{@"en":@{@"value":@"English"}}}}mutableCopy];if([url containsString:@"Q24862"])entities[@"Q24862"]=@{@"labels":@{@"en":@{@"value":@"feature film"}}};json=@{@"entities":entities};}
 [self.client URLProtocol:self didLoadData:[NSJSONSerialization dataWithJSONObject:json options:0 error:nil]];}
 else [self.client URLProtocol:self didLoadData:[@"{\"query\":{\"search\":[]}}" dataUsingEncoding:NSUTF8StringEncoding]];
 Active--;[self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end
@interface TestMetadata:RWDiscoveryMetadata @end
@implementation TestMetadata
+ (NSURLSessionConfiguration *)sessionConfiguration {NSURLSessionConfiguration *c=[NSURLSessionConfiguration ephemeralSessionConfiguration];c.protocolClasses=@[MetadataProtocol.class];return c;}
@end
static void Check(BOOL ok){Checks++;if(!ok){Failures++;fprintf(stderr,"FAIL check %d\n",Checks);}}
static void Spin(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];}
int main(){@autoreleasepool{NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
 NSDictionary *old=@{@"imdb":@"tt1",@"franchises":@[@{@"id":@"Q2732470"},@{@"id":@"Q2316015"}],@"fetchedAt":@1};
 NSDictionary *seeds=@{@"collectionEntities":@{@"Q2732470":@{@"id":@"Q2732470",@"claims":@{@"P31":@[@{@"mainsnak":@{@"datavalue":@{@"value":@{@"id":@"Q13406463"}}}}]}}}};
 TestMetadata *migrated=[[TestMetadata alloc]initWithPath:[folder stringByAppendingPathComponent:@"migration.json"] cached:@{@"titles":@{@"tt1":old}} seed:seeds];
 Check(![[migrated record:@"tt1"][@"franchises"]count]);Check([[migrated record:@"tt1"][@"collections"]count]==2);Check([[[migrated record:@"tt1"]objectForKey:@"fetchedAt"]isEqual:@1]);Check(Requests==0);[migrated invalidate];
 TestMetadata *service=[[TestMetadata alloc]initWithPath:[folder stringByAppendingPathComponent:@"cache.json"] bundled:@""];NSMutableArray *items=[NSMutableArray new];for(int i=0;i<50;i++)[items addObject:@{@"id":[NSString stringWithFormat:@"tt%07d",100+i],@"type":@"movie"}];[service enqueue:items];[service enqueue:items];Spin(.03);Check(Requests==0);service.paused=NO;Spin(.6);Check(Requests==24);Check(Peak==1);NSUInteger before=Requests;[service enqueue:[items subarrayWithRange:NSMakeRange(0,24)]];Spin(.05);Check(Requests==before);
 service.paused=YES;[service enqueue:[items subarrayWithRange:NSMakeRange(24,20)]];[service cancelPending];service.paused=NO;Spin(.05);Check(Requests==before);
 Mode=1;Requests=0;TestMetadata *cooldown=[[TestMetadata alloc]initWithPath:[folder stringByAppendingPathComponent:@"cooldown.json"] bundled:@""];[cooldown enqueue:items];cooldown.paused=NO;Spin(.3);Check(Requests==1);Check([cooldown.diagnostics[@"bytes"]integerValue]<1024);
 Mode=2;Requests=0;TestMetadata *oversize=[[TestMetadata alloc]initWithPath:[folder stringByAppendingPathComponent:@"oversize.json"] bundled:@""];__block BOOL returned=NO;[oversize resolve:items[0] done:^(NSDictionary *record,NSString *error){returned=YES;Check(!record&&error.length);}];oversize.paused=NO;Spin(.3);Check(returned);Check([oversize.diagnostics[@"bytes"]integerValue]<=4*1024*1024);[oversize cancelPending];
 Check([TestMetadata URLForRequest:@"https://www.wikidata.org/w/api.php?props=claims|labels"].host.length>0);Check([[TestMetadata URLForRequest:@"https://www.wikidata.org/w/api.php?props=claims|labels"].absoluteString containsString:@"claims%7Clabels"]);Check(![TestMetadata URLForRequest:@"file:///private/test"]);Check(![TestMetadata URLForRequest:@"https://user:password@example.test"]);
 Mode=3;Requests=0;TestMetadata *valid=[[TestMetadata alloc]initWithPath:[folder stringByAppendingPathComponent:@"valid.json"] bundled:@""];__block NSDictionary *resolved=nil;[valid resolve:items[0] done:^(NSDictionary *record,NSString *error){resolved=record;Check(!error);}];valid.paused=NO;Spin(.4);Check(EncodedProperties);Check([resolved[@"entityID"]isEqual:@"Q1"]);Check(Requests==4);Check([resolved[@"franchises"][0][@"instanceOf"]containsObject:@"Q196600"]);Check([resolved[@"originalLanguages"][0][@"name"]isEqual:@"English"]);[valid cancelPending];
 Mode=4;__block NSArray *credits=nil;[valid credits:@"Q2" role:@"director" offset:0 done:^(NSArray *items,BOOL more,NSString *error){credits=items;Check(!error);}];Spin(.4);Check(credits.count==1);Check([credits.firstObject[@"type"]isEqual:@"movie"]&&[credits.firstObject[@"id"]isEqual:@"tt0000100"]);
 Mode=5;__block NSDictionary *continuation=nil;[valid creditPage:@"Q2" role:@"director" continuation:@{@"sroffset":@1500,@"continue":@"-||"} done:^(NSArray *items,NSDictionary *next,NSString *error){Check(!error&&!items.count);continuation=next;}];Spin(.2);Check([continuation[@"sroffset"]integerValue]==1537);Check([LastSearchURL containsString:@"sroffset=1500"]&&[LastSearchURL containsString:@"continue=-%7C%7C"]);
 Mode=0;[valid creditPage:@"Q2" role:@"director" continuation:continuation done:^(NSArray *items,NSDictionary *next,NSString *error){Check(!error&&!next.count);}];Spin(.2);Check([LastSearchURL containsString:@"sroffset=1537"]);
 Mode=6;__block BOOL invalid=NO;[valid creditPage:@"Q2" role:@"director" continuation:@{@"sroffset":@0} done:^(NSArray *items,NSDictionary *next,NSString *error){invalid=error.length>0;}];Spin(.2);Check(invalid);
 Mode=7;Requests=0;valid.paused=YES;__block NSUInteger callbacks=0;__block NSDictionary *person=nil,*studio=nil;
 for(int i=0;i<2;i++){[valid entity:@"Q20" role:@"person" done:^(NSDictionary *record,NSString *error){Check(!error);person=record;callbacks++;}];[valid entity:@"Q20" role:@"studio" done:^(NSDictionary *record,NSString *error){Check(!error);studio=record;callbacks++;}];}
 valid.paused=NO;Spin(.4);Check(callbacks==4&&Requests==4);Check([person[@"name"]isEqual:@"Multilingual name"]);Check([person[@"imageRole"]isEqual:@"portrait"]&&[person[@"image"]hasSuffix:@"Portrait.jpg"]);Check([studio[@"imageRole"]isEqual:@"logo"]&&[studio[@"image"]hasSuffix:@"Studio.svg"]);Check([studio[@"credit"]hasSuffix:@"Logo"]);Check(![studio[@"credit"]containsString:@"portrait"]);Check([[valid entitySnapshot][@"Q20:studio"][@"id"]isEqual:@"Q20"]);
 NSUInteger photoRequests=Requests;[valid entity:@"Q20" role:@"studio" done:^(NSDictionary *record,NSString *error){Check([record[@"imageRole"]isEqual:@"logo"]&&!error);}];Spin(.02);Check(Requests==photoRequests);
 // Wait through the actual one-second deferred persist and utility-queue JSON
 // serialization. The earlier test exited before the device's crashing path.
 NSString *savedPath=[folder stringByAppendingPathComponent:@"valid.json"];NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:4];
 while(![NSFileManager.defaultManager fileExistsAtPath:savedPath]&&deadline.timeIntervalSinceNow>0)Spin(.02);
 NSData *savedData=[NSData dataWithContentsOfFile:savedPath];NSDictionary *saved=savedData?[NSJSONSerialization JSONObjectWithData:savedData options:0 error:nil]:nil;
 Check([saved[@"titles"][@"tt0000100"][@"entityID"]isEqual:@"Q1"]);
 TestMetadata *reopened=[[TestMetadata alloc]initWithPath:savedPath bundled:@""];Check([[reopened record:@"tt0000100"][@"originalLanguages"][0][@"name"]isEqual:@"English"]);
 [service cancelPending];[cooldown cancelPending];[valid cancelPending];[reopened cancelPending];Spin(1.1);__block BOOL flushed=NO;[[RWAtomicWriter shared]whenIdle:^{flushed=YES;}];deadline=[NSDate dateWithTimeIntervalSinceNow:4];while(!flushed&&deadline.timeIntervalSinceNow>0)Spin(.01);Check(flushed);
 [NSFileManager.defaultManager removeItemAtPath:folder error:nil];printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
