#import "../RWDiscoveryMetadata.h"
#import "../RWDiscoveryMetadataPolicy.h"
#import "../RWHomeRailPolicy.h"
#import "../RWWorldCatalog.h"
static int Checks,Failures,Mode;static NSMutableArray *Requests;static NSDictionary *Entities;static NSArray *IDs;
#define C(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
@interface WorldProtocol:NSURLProtocol
@property BOOL stopped;
@end
@implementation WorldProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)r{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r{return r;}
- (void)startLoading {
 NSURLComponents *u=[NSURLComponents componentsWithURL:self.request.URL resolvingAgainstBaseURL:NO];NSMutableDictionary *q=[NSMutableDictionary new];for(NSURLQueryItem *item in u.queryItems)q[item.name]=item.value?:@"";[Requests addObject:q];
 if(Mode==4)return;
 NSDictionary *payload;
 if([q[@"action"]isEqual:@"query"]){
  C([q[@"srsearch"]isEqual:RWWorldCatalogQuery()]);C([q[@"srlimit"]integerValue]==8);
  NSMutableArray *rows=[NSMutableArray new];for(NSString *key in (Mode==2?@[@"Q23780734"]:IDs))[rows addObject:@{@"title":key}];
  payload=@{@"query":@{@"search":rows},@"continue":@{@"sroffset":Mode==1?@8.5:@8,@"continue":@"-||"}};
 }else{
  NSMutableDictionary *entities=[NSMutableDictionary new];for(NSString *key in [q[@"ids"]componentsSeparatedByString:@"|"]){entities[key]=Entities[key]?:@{@"id":key,@"labels":@{@"en":@{@"value":key}}};}
  // Never accept an extra title that was not in the search's exact identity set.
  entities[@"Q61448040"]=Entities[@"Q61448040"];
  payload=@{@"entities":entities};
 }
 NSData *data=[NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
 void(^send)(void)=^{if(self.stopped)return;NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}];[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:data];[self.client URLProtocolDidFinishLoading:self];};
 if(Mode==3)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/5),dispatch_get_main_queue(),send);else send();
}
- (void)stopLoading{self.stopped=YES;}
@end
@interface WorldMetadata:RWDiscoveryMetadata @end
@implementation WorldMetadata
+ (NSURLSessionConfiguration *)sessionConfiguration{NSURLSessionConfiguration *c=[NSURLSessionConfiguration ephemeralSessionConfiguration];c.protocolClasses=@[WorldProtocol.class];return c;}
@end
static void Wait(BOOL(^ready)(void),double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];C(ready());}
static NSDictionary *Read(NSString *path){return [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] options:0 error:nil];}
static NSDictionary *Reload(NSDictionary *d){return [NSJSONSerialization JSONObjectWithData:[NSJSONSerialization dataWithJSONObject:d options:0 error:nil] options:0 error:nil];}
int main(int argc,char **argv){@autoreleasepool{
 if(argc!=2)return 2;NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
 Entities=Read([@(argv[1])stringByAppendingPathComponent:@"world-entities.json"])[@"entities"];
 IDs=[[Read([@(argv[1])stringByAppendingPathComponent:@"world-search.json"])[@"query"][@"search"]valueForKey:@"title"]subarrayWithRange:NSMakeRange(0,8)];
 C([[RWDiscoveryMetadataPolicy worldFilmIDs:Entities[@"Q189540"]]isEqual:@[@"tt0047478"]]);C(![RWDiscoveryMetadataPolicy worldFilmIDs:Entities[@"Q23780734"]].count);
 C(![RWDiscoveryMetadataPolicy worldFilmIDs:@{@"claims":@{}}].count);
 NSDictionary *row=@{@"id":@"world",@"recipe":@"world",@"mediaType":@"movie"};double now=2000000000;
 NSDictionary *old=@{@"page":@7,@"skip":@199,@"catalogPolicy":@1,@"catalogs":@{@"movie|Top rated|":@{@"skip":@199}}};
 NSDictionary *p=[RWHomeRailPolicy catalogPage:row cursor:old restricted:NO now:now];C([p[@"request"][@"sort"]isEqual:@"World Cinema"]);C([p[@"request"][@"skip"]integerValue]==0);C([p[@"cursor"][@"page"]integerValue]==7);
 NSDictionary *legacy=[RWHomeRailPolicy catalogPage:row cursor:@{@"skip":@100} restricted:NO now:now];C([legacy[@"request"][@"skip"]integerValue]==0);
 C(![[RWHomeRailPolicy catalogPage:row cursor:@{} restricted:YES now:now][@"request"][@"sort"]isEqual:@"World Cinema"]);
 NSDictionary *next=@{@"sroffset":@8,@"continue":@"-||"};NSDictionary *cursor=[RWHomeRailPolicy advanceWorldPage:p continuation:next now:now];
 p=[RWHomeRailPolicy catalogPage:row cursor:Reload(cursor) restricted:NO now:now];C([p[@"request"][@"skip"]integerValue]==8);C([p[@"request"][@"continuation"]isEqual:next]);
 for(NSDictionary *bad in @[@{@"sroffset":@8,@"continue":@"-||"},@{@"sroffset":@17,@"continue":@"-||"},@{@"sroffset":@8.5,@"continue":@"-||"},@{@"sroffset":@16}])C(![RWHomeRailPolicy advanceWorldPage:p continuation:bad now:now]);
 NSDictionary *deferred=[RWHomeRailPolicy deferCatalogPage:p now:now];NSDictionary *retry=[RWHomeRailPolicy catalogPage:row cursor:Reload(deferred) restricted:NO now:now+61];C([retry[@"request"][@"continuation"]isEqual:next]);
 NSDictionary *end=[RWHomeRailPolicy advanceWorldPage:p continuation:@{} now:now];C(![RWHomeRailPolicy catalogPage:row cursor:Reload(end) restricted:NO now:now+1][@"request"]);C([[RWHomeRailPolicy catalogPage:row cursor:Reload(end) restricted:NO now:now+21601][@"request"][@"skip"]integerValue]==0);
 for(int mode=0;mode<5;mode++){
  Mode=mode;Requests=[NSMutableArray new];WorldMetadata *s=[[WorldMetadata alloc]initWithPath:[folder stringByAppendingFormat:@"/%d",mode] bundled:@""];s.paused=NO;
  __block BOOL finished=NO;__block NSUInteger callbacks=0;__block NSArray *items;__block NSDictionary *continuation;__block NSString *error;
  [s worldPage:@{} owner:@"home-world:main" done:^(NSArray *values,NSDictionary *n,NSString *failure){callbacks++;items=values;continuation=n;error=failure;finished=YES;}];
  if(mode==3){Wait(^BOOL{return Requests.count>0;},2);[s cancelCreditRequestsForOwner:@"home-world:main"];NSDate *until=[NSDate dateWithTimeIntervalSinceNow:.3];while(until.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];C(callbacks==0);}
  else {Wait(^BOOL{return finished;},mode==4?14:5);C(callbacks==1);
   if(mode==0){C(!error.length);C(items.count>0&&items.count<=8);C([[items valueForKey:@"id"]containsObject:@"tt0047478"]);C(![[items valueForKey:@"id"]containsObject:@"tt1825683"]);C(![[items valueForKey:@"id"]containsObject:@"tt6751668"]);C([continuation isEqual:next]);for(NSDictionary *m in items){C([m[@"type"]isEqual:@"movie"]);C([[RWDiscoveryMetadataPolicy languageGroup:m[@"discovery"]]isEqual:@"world"]);C(!m[@"availability"]&&!m[@"ageAllowed"]);for(NSDictionary *language in m[@"discovery"][@"originalLanguages"])C([language[@"name"]length]>0);}}
   if(mode==1){C(error.length&&!items.count);C(!continuation.count);}
   if(mode==2){C(!error.length&&!items.count);C([continuation isEqual:next]);}
   if(mode==4)C(error.length&&!items.count);
  }
  [s invalidate];
 }
 [NSFileManager.defaultManager removeItemAtPath:folder error:nil];printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
