#import "../RWHomeFeedStore.h"
#import "../RWFeedStore.h"
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL %d %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static void Wait(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:3];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];CHECK(ready());}
static NSDictionary *Title(int n){return @{@"id":[NSString stringWithFormat:@"tt%d",n],@"name":@"Title",@"type":@"series"};}
static NSArray *Rows(void){NSMutableArray *items=[NSMutableArray new];for(int i=1;i<=12;i++)[items addObject:Title(i)];return @[@{@"id":@"for-you-series",@"title":@"Shows",@"recipe":@"for-you",@"mediaType":@"series",@"items":items}];}
static void Activate(RWHomeFeedStore *s,NSString *scope,NSSet *excluded){__block BOOL done=NO;[s activate:scope profile:scope seedRows:Rows() excluding:excluded done:^(NSString *e){CHECK(!e);done=YES;}];Wait(^BOOL{return done;});}
static void Anchor(RWHomeFeedStore *s,RWHomeRowFeed *row,NSString *key){__block BOOL done=NO;[s saveAnchor:@{@"id":key,@"delta":@170} row:row done:^(NSString *e){CHECK(!e);done=YES;}];Wait(^BOOL{return done;});}
int main(){@autoreleasepool{
 NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];RWHomeFeedStore *s=[[RWHomeFeedStore alloc]initWithFolder:folder];
 @try{
  Activate(s,@"kids",[NSSet set]);RWHomeRowFeed *row=s.rows[0];Anchor(s,row,@"tt10");
  // Native reproduction: renderer asks for a saved position, then a new
  // recommendation activation invalidates the asynchronous read generation.
  // The profile, row object and saved title are all unchanged.
  __block BOOL looked=NO,refreshed=NO;__block NSUInteger index=NSNotFound;
  [s anchorIndex:row done:^(NSUInteger n){index=n;looked=YES;}];
  [s activate:@"kids" profile:@"kids" seedRows:Rows() excluding:[NSSet set] done:^(NSString *e){CHECK(!e);refreshed=YES;}];
  Wait(^BOOL{return looked&&refreshed;});CHECK(row==s.rows[0]);CHECK(row.count==12);CHECK([row.anchor[@"id"]isEqual:@"tt10"]);CHECK(index==9);
  // The retried lookup must use current order when a preceding title leaves.
  looked=NO;refreshed=NO;index=NSNotFound;
  [s anchorIndex:row done:^(NSUInteger n){index=n;looked=YES;}];
  [s activate:@"kids" profile:@"kids" seedRows:Rows() excluding:[NSSet setWithObject:@"tt1"] done:^(NSString *e){CHECK(!e);refreshed=YES;}];
  Wait(^BOOL{return looked&&refreshed;});CHECK(index==8&&row.count==11);CHECK([row.anchor[@"delta"]integerValue]==170);
  // Profile changes remain a hard boundary, even if the new row has the same
  // identity and includes the same title. A late callback cannot jump that UI.
  looked=NO;refreshed=NO;index=0;
  [s anchorIndex:row done:^(NSUInteger n){index=n;looked=YES;}];
  [s activate:@"regular" profile:@"regular" seedRows:Rows() excluding:[NSSet set] done:^(NSString *e){CHECK(!e);refreshed=YES;}];
  Wait(^BOOL{return looked&&refreshed;});CHECK(index==NSNotFound);CHECK(s.rows[0]!=row);
  // An explicitly excluded anchor is genuinely absent; never invent an index
  // or reinsert the removed card simply to pass restoration.
  Activate(s,@"kids",[NSSet setWithObject:@"tt1"]);row=s.rows[0];looked=NO;refreshed=NO;index=0;
  [s anchorIndex:row done:^(NSUInteger n){index=n;looked=YES;}];
  [s activate:@"kids" profile:@"kids" seedRows:Rows() excluding:[NSSet setWithArray:@[@"tt1",@"tt10"]] done:^(NSString *e){CHECK(!e);refreshed=YES;}];
  Wait(^BOOL{return looked&&refreshed;});CHECK(index==NSNotFound);CHECK(row.count==10);
  // A newly saved position wins over an in-flight old lookup.
  Anchor(s,row,@"tt9");looked=NO;refreshed=NO;index=0;
  [s saveAnchor:@{@"id":@"tt8",@"delta":@19} row:row done:^(NSString *e){CHECK(!e);refreshed=YES;}];
  [s anchorIndex:row done:^(NSUInteger n){index=n;looked=YES;}];
  Wait(^BOOL{return looked&&refreshed;});CHECK(index==NSNotFound);CHECK([row.anchor[@"id"]isEqual:@"tt8"]&&[row.anchor[@"delta"]integerValue]==19);
  // The diagnostic is bounded and distinguishes valid refresh retries from
  // ownership rejection and actual missing titles; it is not a polling worker.
  NSArray *events=s.diagnostics[@"anchor_queries"];NSSet *reasons=[NSSet setWithArray:[events valueForKey:@"reason"]];
  CHECK([reasons containsObject:@"retry_generation"]);CHECK([reasons containsObject:@"found"]);CHECK([reasons containsObject:@"missing"]);CHECK([reasons containsObject:@"owner_or_anchor_changed"]);
  for(int i=0;i<20;i++){looked=NO;[s anchorIndex:row done:^(NSUInteger n){CHECK(n==6);looked=YES;}];Wait(^BOOL{return looked;});}
  CHECK([s.diagnostics[@"anchor_queries"]count]==16);
 }@catch(NSException *e){Failures++;fprintf(stderr,"EXCEPTION %s\n",e.reason.UTF8String);}@finally{__block BOOL closed=NO;[s close:^{closed=YES;}];Wait(^BOOL{return closed;});[NSFileManager.defaultManager removeItemAtPath:folder error:nil];}
 printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
