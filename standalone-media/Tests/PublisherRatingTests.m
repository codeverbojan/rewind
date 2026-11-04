#import "../RWPublisherRatingPolicy.h"
#import "../RWApplePreviewPolicy.h"
#import "../RWApplePreviewLookup.h"
#import "../RWMetadataBudget.h"
#import "../RWRatingPolicy.h"
static int Checks,Failures;static NSData *Body;static NSUInteger Requests;static BOOL Large,Hold;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static void Wait(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:8];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];CHECK(ready());}
static NSMutableDictionary *DisneyDocument(NSString *text){NSRange start=[text rangeOfString:@"{\"props\":"],end=[text rangeOfString:@"</script>"];return [NSJSONSerialization JSONObjectWithData:[[text substringWithRange:NSMakeRange(start.location,end.location-start.location)]dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];}
static NSData *DisneyHTML(NSDictionary *root){NSString *json=[[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:root options:0 error:nil] encoding:NSUTF8StringEncoding];return [[NSString stringWithFormat:@"<script id=\"__NEXT_DATA__\">%@</script>",json]dataUsingEncoding:NSUTF8StringEncoding];}
@interface RatingProtocol:NSURLProtocol @end
@implementation RatingProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request{return request;}
- (void)startLoading {Requests++;if(Hold)return;NSURL *url=[self.request.URL.host isEqual:@"www.disneyplus.com"]?[NSURL URLWithString:@"https://www.disneyplus.com/browse/entity-9995dda1-d70a-4d15-98ba-72f1d10fa406"]:self.request.URL;NSHTTPURLResponse *r=[[NSHTTPURLResponse alloc]initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}];[self.client URLProtocol:self didReceiveResponse:r cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:Large?[NSMutableData dataWithLength:2*1024*1024+1]:Body];[self.client URLProtocolDidFinishLoading:self];}
- (void)stopLoading {}
@end
int main(int argc,const char **argv){@autoreleasepool{
 NSString *folder=@(argv[1]);Body=[NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"arthur-apple-page.html"]];NSDictionary *claims=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"arthur-wikidata-claims.json"]] options:0 error:nil];NSDictionary *entity=[claims[@"entities"]allValues].firstObject;
 NSString *identifier=@"umc.cmc.32hpmpaty5eem41zg40onjnxw";NSDictionary *meta=@{@"id":@"tt0169414",@"type":@"series",@"name":@"Arthur",@"releaseInfo":@"1996–2022"};
 CHECK([[RWApplePreviewPolicy showIDs:entity imdb:meta[@"id"]]isEqual:@[identifier]]);CHECK([RWApplePreviewPolicy showIDs:entity imdb:@"tt9999999"].count==0);
 NSDictionary *r=[RWPublisherRatingPolicy record:Body identifier:identifier meta:meta];CHECK([r[@"label"]isEqual:@"TV-G"]);CHECK(r&&[r[@"minimumAge"]integerValue]==0);CHECK([r[@"source"]hasPrefix:@"https://tv.apple.com/us/show/arthur/"]);
 for(NSDictionary *change in @[@{@"name":@"Arthur 2"},@{@"releaseInfo":@"2011"},@{@"type":@"movie"},@{@"id":@"invalid"},@{@"releaseInfo":@""}]){NSMutableDictionary *m=[meta mutableCopy];[m addEntriesFromDictionary:change];CHECK(![RWPublisherRatingPolicy record:Body identifier:identifier meta:m]);}
 CHECK(![RWPublisherRatingPolicy record:Body identifier:@"umc.cmc.otheridentityxxxx" meta:meta]);
 NSString *text=[[NSString alloc]initWithData:Body encoding:NSUTF8StringEncoding];
 for(NSArray *change in @[@[@"/us/show/",@"/gb/show/"],@[@"canonical-header-",@"unrelated-header-"],@[@"TV-G",@"Unrated"],@[@"ratingBadges",@"playbackBadges"]]){NSData *bad=[[text stringByReplacingOccurrencesOfString:change[0] withString:change[1]]dataUsingEncoding:NSUTF8StringEncoding];CHECK(![RWPublisherRatingPolicy record:bad identifier:identifier meta:meta]);}
 CHECK(![RWPublisherRatingPolicy record:[NSMutableData dataWithLength:2*1024*1024+1] identifier:identifier meta:meta]);
 // An adult rating remains adult; neither recommended-age badges nor genres
 // replace the title's formal classification.
 NSData *adult=[[text stringByReplacingOccurrencesOfString:@"TV-G" withString:@"TV-MA"]dataUsingEncoding:NSUTF8StringEncoding];CHECK([[RWPublisherRatingPolicy record:adult identifier:identifier meta:meta][@"minimumAge"]integerValue]==18);
 NSString *disneyFolder=@(argv[2]),*disneyID=@"HZxayxzMJqed";NSURL *disneyURL=[NSURL URLWithString:@"https://www.disneyplus.com/browse/entity-9995dda1-d70a-4d15-98ba-72f1d10fa406"];
 NSDictionary *gravity=@{@"id":@"tt1865718",@"type":@"series",@"name":@"Gravity Falls",@"releaseInfo":@"2012–2016"};
 NSData *disney=[NSData dataWithContentsOfFile:[disneyFolder stringByAppendingPathComponent:@"gravity-disney-page.html"]];NSString *disneyText=[[NSString alloc]initWithData:disney encoding:NSUTF8StringEncoding];
 NSDictionary *disneyClaims=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[disneyFolder stringByAppendingPathComponent:@"gravity-wikidata-claims.json"]] options:NSJSONReadingMutableContainers error:nil];NSMutableDictionary *disneyEntity=disneyClaims[@"entities"][@"Q550555"];
 CHECK([[RWPublisherRatingPolicy disneyIDs:disneyEntity imdb:gravity[@"id"]]isEqual:@[disneyID]]);CHECK([RWPublisherRatingPolicy disneyIDs:disneyEntity imdb:@"tt9999999"].count==0);
 disneyEntity[@"claims"][@"P345"][0][@"rank"]=@"deprecated";CHECK([RWPublisherRatingPolicy disneyIDs:disneyEntity imdb:gravity[@"id"]].count==0);disneyEntity[@"claims"][@"P345"][0][@"rank"]=@"normal";
 disneyEntity[@"claims"][@"P7596"][0][@"rank"]=@"deprecated";CHECK([RWPublisherRatingPolicy disneyIDs:disneyEntity imdb:gravity[@"id"]].count==0);disneyEntity[@"claims"][@"P7596"][0][@"rank"]=@"normal";
 for(id bad in @[NSNull.null,@{},@[],@"short",@"HZxayxzMJqe/",@"HZxayxzMJqed\n"]){disneyEntity[@"claims"][@"P7596"][0][@"mainsnak"][@"datavalue"][@"value"]=bad;CHECK([RWPublisherRatingPolicy disneyIDs:disneyEntity imdb:gravity[@"id"]].count==0);}
 disneyEntity[@"claims"][@"P7596"][0][@"mainsnak"][@"datavalue"][@"value"]=disneyID;
 r=[RWPublisherRatingPolicy disneyRecord:disney URL:disneyURL identifier:disneyID meta:gravity];CHECK([r[@"label"]isEqual:@"TV-Y7"]);CHECK(r&&[r[@"minimumAge"]integerValue]==7);CHECK([r[@"source"]isEqual:disneyURL.absoluteString]);CHECK(![RWRatingPolicy allows:r age:6]);CHECK([RWRatingPolicy allows:r age:7]);
 for(NSDictionary *change in @[@{@"name":@"Gravity Falls 2"},@{@"releaseInfo":@"2020"},@{@"releaseInfo":@""},@{@"type":@"movie"},@{@"id":@"invalid"}]){NSMutableDictionary *m=[gravity mutableCopy];[m addEntriesFromDictionary:change];CHECK(![RWPublisherRatingPolicy disneyRecord:disney URL:disneyURL identifier:disneyID meta:m]);}
 for(NSArray *change in @[@[@"\"us\"",@"\"gb\""],@[@"\"en\"",@"\"fr\""],@[@"TV-Y7",@"8+"],@[@"TVSeries",@"TVEpisode"],@[@"WebPage",@"Movie"],@[@"\"hasContent\":true",@"\"hasContent\":false"],@[@"contentRating",@"recommendationRating"],@[@"2012",@"2012invalid"],@[@"__NEXT_DATA__",@"unrelated-data"]]){NSData *bad=[[disneyText stringByReplacingOccurrencesOfString:change[0] withString:change[1]]dataUsingEncoding:NSUTF8StringEncoding];CHECK(![RWPublisherRatingPolicy disneyRecord:bad URL:disneyURL identifier:disneyID meta:gravity]);}
 NSData *disneyAdult=[[disneyText stringByReplacingOccurrencesOfString:@"TV-Y7" withString:@"TV-MA"]dataUsingEncoding:NSUTF8StringEncoding];r=[RWPublisherRatingPolicy disneyRecord:disneyAdult URL:disneyURL identifier:disneyID meta:gravity];CHECK(r&&[r[@"minimumAge"]integerValue]==18);CHECK(![RWRatingPolicy allows:r age:12]);
 // Individually mismatched page identity and ambiguous top-level records must
 // fail even when another part of the document still matches this title.
 for(NSString *field in @[@"pageId",@"pathname"]){NSMutableDictionary *doc=DisneyDocument(disneyText);doc[@"props"][@"pageProps"][field]=@"other";CHECK(![RWPublisherRatingPolicy disneyRecord:DisneyHTML(doc) URL:disneyURL identifier:disneyID meta:gravity]);}
 for(NSString *field in @[@"url",@"@id",@"name"]){NSMutableDictionary *doc=DisneyDocument(disneyText);doc[@"props"][@"pageProps"][@"stitchDocument"][@"mainContent"][0][@"ldJSON"][@"@graph"][1][@"itemListElement"][0][@"item"][field]=@"other";CHECK(![RWPublisherRatingPolicy disneyRecord:DisneyHTML(doc) URL:disneyURL identifier:disneyID meta:gravity]);}
 for(NSUInteger index=0;index<2;index++){NSMutableDictionary *doc=DisneyDocument(disneyText);NSMutableArray *graph=doc[@"props"][@"pageProps"][@"stitchDocument"][@"mainContent"][0][@"ldJSON"][@"@graph"];[graph addObject:[graph[index]copy]];CHECK(![RWPublisherRatingPolicy disneyRecord:DisneyHTML(doc) URL:disneyURL identifier:disneyID meta:gravity]);}
 CHECK(![RWPublisherRatingPolicy disneyRecord:[[disneyText stringByAppendingString:disneyText]dataUsingEncoding:NSUTF8StringEncoding] URL:disneyURL identifier:disneyID meta:gravity]);
 CHECK(![RWPublisherRatingPolicy disneyRecord:disney URL:[NSURL URLWithString:@"https://www.disneyplus.com/browse/entity-00000000-0000-0000-0000-000000000000"] identifier:disneyID meta:gravity]);
 CHECK(![RWApplePreviewPolicy allowedURL:disneyURL.absoluteString base:nil]);
 for(NSString *field in @[@"title",@"release",@"locale"]){NSMutableDictionary *doc=DisneyDocument(disneyText);doc[@"props"][@"pageProps"][@"stitchDocument"][@"mainContent"][1][field]=@"other";CHECK(![RWPublisherRatingPolicy disneyRecord:DisneyHTML(doc) URL:disneyURL identifier:disneyID meta:gravity]);}
 NSData *percy=[NSData dataWithContentsOfFile:[disneyFolder stringByAppendingPathComponent:@"percy-disney-page.html"]];NSString *percyText=[[NSString alloc]initWithData:percy encoding:NSUTF8StringEncoding];NSURL *percyURL=[NSURL URLWithString:@"https://www.disneyplus.com/browse/entity-f1c31566-ec05-4d30-b23f-3177442233f4"];NSDictionary *percyMeta=@{@"id":@"tt12324366",@"name":@"Percy Jackson and the Olympians",@"type":@"series",@"releaseInfo":@"2023"};
 r=[RWPublisherRatingPolicy disneyRecord:percy URL:percyURL identifier:@"ql33aq42HBdr" meta:percyMeta];CHECK(r&&[r[@"label"]isEqual:@"TV-PG"]&&[r[@"minimumAge"]integerValue]==10);
 for(NSString *field in @[@"promotion",@"_type"]){NSMutableDictionary *doc=DisneyDocument(percyText);for(NSMutableDictionary *component in doc[@"props"][@"pageProps"][@"stitchDocument"][@"mainContent"])if([component[@"_type"]isEqual:@"DetailEntityHero"])component[field]=@"other";CHECK(![RWPublisherRatingPolicy disneyRecord:DisneyHTML(doc) URL:percyURL identifier:@"ql33aq42HBdr" meta:percyMeta]);}
 CHECK(![RWPublisherRatingPolicy disneyRecord:[NSMutableData dataWithLength:2*1024*1024+1] URL:disneyURL identifier:disneyID meta:gravity]);
 CHECK([RWPublisherRatingPolicy allowsDisneyURL:disneyURL identifier:disneyID]);CHECK([RWPublisherRatingPolicy allowsDisneyURL:[NSURL URLWithString:[@"https://www.disneyplus.com/series/wp/" stringByAppendingString:disneyID]] identifier:disneyID]);
 for(NSString *bad in @[@"http://www.disneyplus.com/browse/entity-9995dda1-d70a-4d15-98ba-72f1d10fa406",@"https://www.disneyplus.com.evil.example/series/wp/HZxayxzMJqed",@"https://www.disneyplus.com/series/wp/OtherID12345",@"https://www.disneyplus.com/login",@"https://www.disneyplus.com/series/wp/HZxayxzMJqed?x=1",@"https://name@www.disneyplus.com/series/wp/HZxayxzMJqed",@"https://www.disneyplus.com:8443/series/wp/HZxayxzMJqed"]){CHECK(![RWPublisherRatingPolicy allowsDisneyURL:[NSURL URLWithString:bad] identifier:disneyID]);}
 // Captured official page for the real Kids mismatch: exact mapped identity,
 // current formal US rating, and rejection of the unrelated homepage redirect.
 NSString *kingFolder=@(argv[3]),*kingID=@"2azoZwYZu3Pk";NSURL *kingURL=[NSURL URLWithString:@"https://www.disneyplus.com/browse/entity-52b8dd8a-eff2-4ed2-9b8d-7c0039df1c53"];
 NSDictionary *king=@{@"id":@"tt0118375",@"name":@"King of the Hill",@"type":@"series",@"releaseInfo":@"1997"};
 NSDictionary *kingClaims=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[kingFolder stringByAppendingPathComponent:@"king-wikidata.json"]] options:0 error:nil];
 CHECK([[RWPublisherRatingPolicy disneyIDs:kingClaims[@"entities"][@"Q1135966"] imdb:king[@"id"]]isEqual:@[kingID]]);
 NSData *kingPage=[NSData dataWithContentsOfFile:[kingFolder stringByAppendingPathComponent:@"king-disney.html"]];
 r=[RWPublisherRatingPolicy disneyRecord:kingPage URL:kingURL identifier:kingID meta:king];
 CHECK(r&&[r[@"label"]isEqual:@"TV-14"]&&[r[@"minimumAge"]integerValue]==14);CHECK([r[@"source"]isEqual:kingURL.absoluteString]);CHECK(![RWRatingPolicy allows:r age:12]);CHECK([RWRatingPolicy allows:r age:-1]);
 CHECK(![RWPublisherRatingPolicy disneyRecord:[NSData dataWithContentsOfFile:[kingFolder stringByAppendingPathComponent:@"king-hulu.html"]] URL:[NSURL URLWithString:@"https://www.disneyplus.com/"] identifier:kingID meta:king]);
 NSURLSessionConfiguration *c=[NSURLSessionConfiguration ephemeralSessionConfiguration];c.protocolClasses=@[RatingProtocol.class];RWApplePreviewLookup *client=[[RWApplePreviewLookup alloc]initWithConfiguration:c];__block BOOL done=NO;__block NSDictionary *result=nil;
 @try{
  [client resolveRating:meta identifier:identifier done:^(NSDictionary *record,NSString *error){result=record;done=YES;}];Wait(^BOOL{return done;});CHECK(result&&Requests==1);CHECK([client.diagnostics[@"stage"]isEqual:@"show_classification"]);
  done=NO;Large=YES;[client resolveRating:meta identifier:identifier done:^(NSDictionary *record,NSString *error){CHECK(!record&&error.length);done=YES;}];Wait(^BOOL{return done;});CHECK([client.diagnostics[@"steps"][0][@"bytes"]unsignedIntegerValue]<=2*1024*1024);Large=NO;
  done=NO;Hold=YES;[client resolveRating:meta identifier:identifier done:^(NSDictionary *record,NSString *error){CHECK(!record&&error.length);done=YES;}];Wait(^BOOL{return Requests==3;});[client cancel];CHECK(done);
  Hold=NO;Body=disney;done=NO;result=nil;[client resolveDisneyRating:gravity identifier:disneyID done:^(NSDictionary *record,NSString *error){CHECK(!error);result=record;done=YES;}];Wait(^BOOL{return done;});CHECK(result&&[result[@"label"]isEqual:@"TV-Y7"]);CHECK([client.diagnostics[@"stage"]isEqual:@"disney_classification"]);
  done=NO;Large=YES;[client resolveDisneyRating:gravity identifier:disneyID done:^(NSDictionary *record,NSString *error){CHECK(!record&&error.length);done=YES;}];Wait(^BOOL{return done;});CHECK([client.diagnostics[@"steps"][0][@"bytes"]unsignedIntegerValue]<=2*1024*1024);Large=NO;
  done=NO;Hold=YES;[client resolveDisneyRating:gravity identifier:disneyID done:^(NSDictionary *record,NSString *error){CHECK(!record&&error.length);done=YES;}];Wait(^BOOL{return Requests==6;});NSURLSessionTask *task=[client valueForKey:@"task"];CHECK(task!=nil);
  for(NSUInteger i=0;i<4;i++){__block BOOL answered=NO;__block NSURLRequest *accepted=nil;[(id<NSURLSessionTaskDelegate>)client URLSession:nil task:task willPerformHTTPRedirection:nil newRequest:[NSURLRequest requestWithURL:disneyURL] completionHandler:^(NSURLRequest *request){answered=YES;accepted=request;}];CHECK(answered);CHECK((accepted!=nil)==(i<3));}[client cancel];CHECK(done);
  // Changing lookup modes cannot return a classification as a cached trailer,
  // and the Disney-only redirect policy must not leak into Apple's mode.
  Hold=NO;done=NO;Body=[NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"arthur-apple-page.html"]];
  [client resolveRating:meta identifier:identifier done:^(NSDictionary *record,NSString *error){CHECK(record&&[record[@"label"]isEqual:@"TV-G"]&&!error);done=YES;}];Wait(^BOOL{return done;});
  Hold=YES;done=NO;NSUInteger before=Requests;[client resolve:meta knownIDs:@[identifier] done:^(NSDictionary *record,NSString *error){CHECK(!record&&[error isEqual:@"Cancelled"]);done=YES;}];CHECK(!done);Wait(^BOOL{return Requests==before+1;});CHECK([client.diagnostics[@"stage"]isEqual:@"show_page"]);[client cancel];CHECK(done);
 }@finally{[client invalidate];Hold=NO;}
 printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
