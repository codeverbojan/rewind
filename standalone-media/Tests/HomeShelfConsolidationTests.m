#import "../RWHomeFeedStore.h"
#import "../RWFeedStore.h"
#import <sqlite3.h>
static int checks,failures;
#define C(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL%d %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static void Wait(BOOL(^ready)(void)){NSDate *until=[NSDate dateWithTimeIntervalSinceNow:3];while(!ready()&&until.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];C(ready());}
static NSDictionary *Title(int n,NSString *type){return @{@"id":[NSString stringWithFormat:@"tt%d",n],@"name":@"Title",@"type":type};}
static NSArray *Items(int start,int count,NSString *type){NSMutableArray *a=[NSMutableArray new];for(int i=0;i<count;i++)[a addObject:Title(start+i,type)];return a;}
static NSDictionary *Row(NSString *key,NSString *recipe,NSArray *items,NSString *type){return @{@"id":key,@"title":key,@"recipe":recipe,@"mediaType":type,@"items":items};}
static void Activate(RWHomeFeedStore *s,NSArray *rows){__block BOOL done=NO;[s activate:@"scope" profile:@"profile" seedRows:rows excluding:[NSSet set] done:^(NSString *e){C(!e);done=YES;}];Wait(^BOOL{return done;});}
static RWHomeRowFeed *Feed(RWHomeFeedStore *s,NSString *key){for(RWHomeRowFeed *r in s.rows)if([r.identifier isEqual:key])return r;return nil;}
static void Close(RWHomeFeedStore *s){__block BOOL done=NO;[s close:^{done=YES;}];Wait(^BOOL{return done;});}
static NSArray *IDs(RWHomeRowFeed *r){if(!r)return @[];__block BOOL done=NO;[r loadRange:NSMakeRange(0,r.count) done:^(NSString *e){C(!e);done=YES;}];Wait(^BOOL{return done;});NSMutableArray *a=[NSMutableArray new];for(NSUInteger i=0;i<r.count;i++)if([r cachedItem:i])[a addObject:[r cachedItem:i][@"id"]];return a;}
static void Remove(RWHomeFeedStore *s,RWHomeRowFeed *r,NSArray *ids){__block BOOL done=NO;[s removeIdentifiers:ids row:r done:^(NSString *e){C(!e);done=YES;}];Wait(^BOOL{return done;});}
int main(){@autoreleasepool{
 NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];RWHomeFeedStore *s=[[RWHomeFeedStore alloc]initWithFolder:folder];
 @try{
  NSArray *rows=@[Row(@"new-movie",@"new",Items(10,4,@"movie"),@"movie"),Row(@"world",@"world",Items(30,2,@"movie"),@"movie"),Row(@"for-you-series",@"for-you",Items(40,2,@"series"),@"series"),Row(@"for-you-movie",@"for-you",Items(1,4,@"movie"),@"movie"),Row(@"new-series",@"new",Items(50,1,@"series"),@"series")];
  Activate(s,rows);C([s.rows[0].identifier isEqual:@"for-you-movie"]&&[s.rows[1].identifier isEqual:@"for-you-series"]);C(Feed(s,@"new-movie").count==4);C(!Feed(s,@"new-series"));C([IDs(Feed(s,@"for-you-series"))isEqual:@[@"tt40",@"tt41",@"tt50"]]);C(Feed(s,@"world").count==2);
  RWHomeRowFeed *broad=Feed(s,@"for-you-movie"),*recent=Feed(s,@"new-movie");__block BOOL done=NO;
  [s saveAnchor:@{@"id":@"tt2",@"delta":@17} row:broad done:^(NSString *e){C(!e);done=YES;}];Wait(^BOOL{return done;});done=NO;
  [s append:@[] row:broad expectedCursor:@{} nextCursor:@{@"page":@5} more:YES done:^(NSUInteger n,NSString *e){C(!e);done=YES;}];Wait(^BOOL{return done;});
  Remove(s,recent,@[@"tt10",@"tt11",@"tt12"]);C(recent.count==1);Activate(s,@[Row(@"for-you-movie",@"for-you",@[],@"movie"),Row(@"new-movie",@"new",@[],@"movie")]);C(Feed(s,@"new-movie").count==1);C(broad.count==4); // No rearrangement during a visit.
  Close(s);s=[[RWHomeFeedStore alloc]initWithFolder:folder];Activate(s,@[Row(@"for-you-movie",@"for-you",@[],@"movie"),Row(@"for-you-series",@"for-you",@[],@"series")]);broad=Feed(s,@"for-you-movie");C(!Feed(s,@"new-movie"));C([IDs(broad)isEqual:@[@"tt1",@"tt2",@"tt3",@"tt4",@"tt13"]]);C([broad.cursor isEqual:@{@"page":@5}]);C([broad.anchor isEqual:@{@"id":@"tt2",@"delta":@17}]);C(Feed(s,@"world").count==2);
  // Removed donor positions migrate with ownership, so recovered cards can
  // return in their prior relative order inside the consolidated shelf.
  done=NO;[s append:@[Title(10,@"movie")] row:broad expectedCursor:@{@"page":@5} nextCursor:@{@"page":@6} more:YES done:^(NSUInteger n,NSString *e){C(!e&&n==1);done=YES;}];Wait(^BOOL{return done;});C([IDs(broad)isEqual:@[@"tt1",@"tt2",@"tt3",@"tt4",@"tt10",@"tt13"]]);
  NSArray *folds=s.diagnostics[@"folded_rows"];C(folds.count==1);C([folds[0][@"from"]isEqual:@"new-movie"]&&[folds[0][@"to"]isEqual:@"for-you-movie"]&&[folds[0][@"count"]integerValue]==1&&[folds[0][@"reserved"]integerValue]==3);
  Close(s);s=[[RWHomeFeedStore alloc]initWithFolder:folder];Activate(s,@[Row(@"for-you-movie",@"for-you",@[],@"movie"),Row(@"for-you-series",@"for-you",@[],@"series")]);C([s.diagnostics[@"folded_rows"]count]==0);C([IDs(Feed(s,@"for-you-movie"))isEqual:@[@"tt1",@"tt2",@"tt3",@"tt4",@"tt10",@"tt13"]]);
  // Late recommendation callbacks must not publish new one-card headings.
  // Their cards append to the matching broad shelf without moving old cards.
  broad=Feed(s,@"for-you-movie");NSArray *oldIDs=IDs(broad);NSDictionary *oldCursor=broad.cursor,*oldAnchor=broad.anchor;
  Activate(s,@[Row(@"for-you-movie",@"for-you",@[],@"movie"),Row(@"for-you-series",@"for-you",@[],@"series"),Row(@"late-older",@"older",Items(70,1,@"movie"),@"movie"),Row(@"late-more",@"more",Items(80,3,@"series"),@"series")]);
  C(!Feed(s,@"late-older")&&!Feed(s,@"late-more"));C([IDs(broad)isEqual:[oldIDs arrayByAddingObject:@"tt70"]]);C([broad.cursor isEqual:oldCursor]&&[broad.anchor isEqual:oldAnchor]);
  NSArray *seriesIDs=IDs(Feed(s,@"for-you-series"));C(seriesIDs.count==6);if(seriesIDs.count==6)C([[seriesIDs subarrayWithRange:NSMakeRange(3,3)]isEqual:@[@"tt80",@"tt81",@"tt82"]]);C(Feed(s,@"world").count==2);
  // A genuinely populated new shelf can appear; an existing shelf that later
  // becomes sparse retains its place for the rest of this visit.
  Activate(s,@[Row(@"for-you-movie",@"for-you",@[],@"movie"),Row(@"late-full",@"older",Items(90,4,@"movie"),@"movie")]);C(Feed(s,@"late-full").count==4);
  Remove(s,Feed(s,@"late-full"),@[@"tt90",@"tt91",@"tt92"]);Activate(s,@[Row(@"for-you-movie",@"for-you",@[],@"movie"),Row(@"late-full",@"older",@[],@"movie")]);C(Feed(s,@"late-full").count==1);

 }@catch(NSException *e){failures++;fprintf(stderr,"EXCEPTION %s\n",e.reason.UTF8String);}@finally{Close(s);s=nil;[NSFileManager.defaultManager removeItemAtPath:folder error:nil];}
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
