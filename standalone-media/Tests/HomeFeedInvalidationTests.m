#import "../RWHomeFeedStore.h"
#import <sqlite3.h>
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static void Wait(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:5];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];CHECK(ready());}
static NSDictionary *Title(int n){return @{@"id":[NSString stringWithFormat:@"tt%d",n],@"name":[NSString stringWithFormat:@"Film %d",n],@"type":@"movie"};}
static NSDictionary *Row(NSString *key,int start){NSMutableArray *items=[NSMutableArray new];for(int i=start;i<start+6;i++)[items addObject:Title(i)];return @{@"id":key,@"title":key,@"recipe":@"for-you",@"mediaType":@"movie",@"items":items};}
static void Activate(RWHomeFeedStore *s,NSArray *rows,NSSet *excluded){__block BOOL done=NO;[s activate:@"main" profile:@"main" seedRows:rows excluding:excluded done:^(NSString *e){CHECK(!e);done=YES;}];Wait(^BOOL{return done;});}
static void Load(RWHomeRowFeed *r){__block BOOL done=NO;[r loadRange:NSMakeRange(0,r.count) done:^(NSString *e){CHECK(!e);done=YES;}];Wait(^BOOL{return done;});}
static void Append(RWHomeFeedStore *s,RWHomeRowFeed *r,NSArray *items){__block BOOL done=NO;[s append:items row:r expectedCursor:r.cursor nextCursor:@{@"page":@([r.cursor[@"page"]intValue]+1)} more:YES done:^(NSUInteger n,NSString *e){CHECK(!e);done=YES;}];Wait(^BOOL{return done;});}
static void Remove(RWHomeFeedStore *s,RWHomeRowFeed *r,NSString *key){__block BOOL done=NO;[s removeIdentifiers:@[key] row:r done:^(NSString *e){CHECK(!e);done=YES;}];Wait(^BOOL{return done;});}
static void Close(RWHomeFeedStore *s){__block BOOL done=NO;[s close:^{done=YES;}];Wait(^BOOL{return done;});}
int main(){@autoreleasepool{
 NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];RWHomeFeedStore *s=[[RWHomeFeedStore alloc]initWithFolder:folder];NSArray *rows=@[Row(@"films",1),Row(@"world",100)];
 @try{
  Activate(s,rows,[NSSet set]);RWHomeRowFeed *a=s.rows[0],*b=s.rows[1];Load(a);Load(b);NSDictionary *world=[b cachedItem:0];CHECK([world[@"id"]isEqual:@"tt100"]);
  // Real append/removal transactions in another shelf must not turn a warm
  // visible shelf into a skeleton. Tail appends preserve the existing prefix.
  Append(s,a,@[Title(7)]);CHECK([[b cachedItem:0]isEqual:world]);CHECK([[a cachedItem:0][@"id"]isEqual:@"tt1"]);CHECK(![a cachedItem:6]);Load(a);
  Remove(s,a,@"tt2");CHECK([[b cachedItem:0]isEqual:world]);CHECK([[a cachedItem:1][@"id"]isEqual:@"tt3"]);Load(a);CHECK([[a cachedItem:1][@"id"]isEqual:@"tt3"]);
  // Restoring an earlier reserved slot shifts indexes: retain nothing in that
  // row only for the inserted title; surviving identities move to their new indexes.
  Append(s,a,@[Title(2)]);CHECK([[a cachedItem:0][@"id"]isEqual:@"tt1"]);CHECK(![a cachedItem:1]);CHECK([[a cachedItem:2][@"id"]isEqual:@"tt3"]);CHECK([[b cachedItem:0]isEqual:world]);Load(a);CHECK([[a cachedItem:1][@"id"]isEqual:@"tt2"]);
  Remove(s,a,@"tt2");Load(a);
  // Overlapping cursor-equivalent appends are serialized by the real store.
  // The duplicate cursor loses, without invalidating the successful prefix.
  __block BOOL page1=NO,page2=NO;NSDictionary *prefix=[a cachedItem:0];NSDictionary *cursor=a.cursor;
  [s append:@[Title(8)] row:a expectedCursor:cursor nextCursor:@{@"page":@50} more:YES done:^(NSUInteger n,NSString *e){CHECK(!e&&n==1);page1=YES;}];
  [s append:@[Title(9)] row:a expectedCursor:cursor nextCursor:@{@"page":@51} more:YES done:^(NSUInteger n,NSString *e){CHECK(e&&n==0);page2=YES;}];Wait(^BOOL{return page1&&page2;});CHECK([[a cachedItem:0]isEqual:prefix]);
  Remove(s,a,@"tt8");Load(a);
  // An ordinary same-context seed refresh keeps validated windows available
  // while its transaction is pending and after an unchanged commit.
  NSDictionary *first=[a cachedItem:0];__block BOOL activated=NO;
  [s activate:@"main" profile:@"main" seedRows:rows excluding:[NSSet set] done:^(NSString *e){CHECK(!e);activated=YES;}];
  CHECK([[b cachedItem:0]isEqual:world]);CHECK([[a cachedItem:0]isEqual:first]);Wait(^BOOL{return activated;});CHECK([[b cachedItem:0]isEqual:world]);
  Load(a);CHECK([[a cachedItem:0][@"id"]isEqual:@"tt1"]);
  // Excluded identities are denied immediately; a shifted row cannot reuse an
  // old index. Unaffected rows stay warm throughout.
  activated=NO;[s activate:@"main" profile:@"main" seedRows:rows excluding:[NSSet setWithObject:@"tt1"] done:^(NSString *e){CHECK(!e);activated=YES;}];
  CHECK(![a cachedItem:0]);CHECK([[b cachedItem:0]isEqual:world]);Wait(^BOOL{return activated;});CHECK([[a cachedItem:0][@"id"]isEqual:@"tt2"]);CHECK([[a cachedItem:1][@"id"]isEqual:@"tt3"]);CHECK([[b cachedItem:0]isEqual:world]);Load(a);CHECK(![[a cachedItem:0][@"id"]isEqual:@"tt1"]);
  // Current policy is evaluated on every retained cache read, not just when it
  // was first admitted. A preference/rating change cannot leak a cached title.
  __block BOOL allow=NO;s.permitsRecord=^BOOL(NSDictionary *m,NSDictionary *r){return allow;};CHECK(![b cachedItem:0]);allow=YES;CHECK([[b cachedItem:0]isEqual:world]);s.permitsRecord=nil;
  // Two queued refreshes: mutations in the superseded transaction must still
  // invalidate the final window. A per-last-transaction dirty bit is insufficient.
  __block BOOL one=NO,two=NO;
  NSUInteger oldCount=a.count;
  [s activate:@"main" profile:@"main" seedRows:rows excluding:[NSSet setWithObject:@"tt2"] done:^(NSString *e){CHECK(e!=nil);one=YES;}];
  [s activate:@"main" profile:@"main" seedRows:rows excluding:[NSSet setWithObject:@"tt2"] done:^(NSString *e){CHECK(!e);two=YES;}];Wait(^BOOL{return one&&two;});CHECK(a.count==oldCount);CHECK([[a cachedItem:0][@"id"]isEqual:@"tt3"]);CHECK([[b cachedItem:0]isEqual:world]);
  // Lifting that exclusion admits tt2 at the tail, never its old cached
  // index. The preceding transaction replaced tt2 with the newly allowed tt1.
  Activate(s,rows,[NSSet set]);CHECK([[a cachedItem:0][@"id"]isEqual:@"tt3"]);Load(a);
  // Explicit exclusions discard the old position, so re-admitted tt1 appends;
  // the surviving titles keep their order. It must not reuse cached tt2.
  NSMutableArray *identities=[NSMutableArray new];for(NSUInteger i=0;i<a.count;i++)[identities addObject:[a cachedItem:i][@"id"]?:@""];
  CHECK([identities isEqual:@[@"tt3",@"tt4",@"tt5",@"tt6",@"tt7",@"tt1",@"tt2"]]);
  // Failed writes roll back both titles and revision bookkeeping.
  NSDictionary *cached=[a cachedItem:0];NSUInteger count=a.count;__block BOOL failed=NO;
  [s append:@[Title(900),@{@"id":@"tt901",@"name":@"Wrong type",@"type":@"series"}] row:a expectedCursor:a.cursor nextCursor:@{@"page":@99} more:YES done:^(NSUInteger n,NSString *e){CHECK(e&&n==0);failed=YES;}];Wait(^BOOL{return failed;});CHECK(a.count==count&&[[a cachedItem:0]isEqual:cached]);CHECK([[b cachedItem:0]isEqual:world]);
  // A subsequent successful append must keep the rollback's original prefix.
  Append(s,a,@[Title(900)]);CHECK([[a cachedItem:0]isEqual:cached]);
  // Existing populated shelves deliberately keep their descriptor when seeds
  // rename them; an unchanged saved recipe must retain its visible cards.
  NSMutableDictionary *renamed=[rows[1]mutableCopy];renamed[@"title"]=@"New World label";
  Activate(s,@[rows[0],renamed],[NSSet set]);CHECK([b.descriptor[@"title"]isEqual:@"world"]&&[[b cachedItem:0]isEqual:world]);Load(b);world=[b cachedItem:0];
  // A queued remove/reinsert with changed stored content must never resurrect
  // the old prepared card. Unchanged neighbours reconcile across both commits.
  Load(a);NSString *changedID=[a cachedItem:0][@"id"],*neighbour=[a cachedItem:1][@"id"];NSMutableDictionary *changed=[[a cachedItem:0]mutableCopy];changed[@"name"]=@"New title body";
  __block BOOL removedBody=NO,insertedBody=NO;
  [s removeIdentifiers:@[changedID] row:a done:^(NSString *e){CHECK(!e);removedBody=YES;}];
  [s append:@[changed] row:a expectedCursor:a.cursor nextCursor:@{@"page":@75} more:YES done:^(NSUInteger n,NSString *e){CHECK(!e&&n==1);insertedBody=YES;}];
  Wait(^BOOL{return removedBody&&insertedBody;});CHECK(![a cachedItem:0]);CHECK([[a cachedItem:1][@"id"]isEqual:neighbour]);Load(a);CHECK([[a cachedItem:0][@"name"]isEqual:@"New title body"]);
  CHECK([s.diagnostics[@"reconciled_window_records"]unsignedIntegerValue]>0);CHECK([s.diagnostics[@"fingerprint_bytes"]unsignedIntegerValue]<=128*32);
  // Explicit memory pressure and profile changes still clear resident content.
  [s discardMemory];CHECK(![a cachedItem:0]&&![b cachedItem:0]);Load(b);activated=NO;
  [s activate:@"kids" profile:@"kids" seedRows:@[Row(@"films",200)] excluding:[NSSet set] done:^(NSString *e){CHECK(!e);activated=YES;}];CHECK(![b cachedItem:0]);Wait(^BOOL{return activated;});CHECK([s.diagnostics[@"memory_records"]intValue]==0);
  Close(s);sqlite3 *db=NULL;CHECK(sqlite3_open_v2([[folder stringByAppendingPathComponent:@"rewind-home.sqlite"]UTF8String],&db,SQLITE_OPEN_READONLY,NULL)==SQLITE_OK);sqlite3_stmt *q=NULL;
  CHECK(sqlite3_prepare_v2(db,"SELECT COUNT(*) FROM sqlite_master WHERE name LIKE 'rw_home_%'",-1,&q,NULL)==SQLITE_OK);CHECK(sqlite3_step(q)==SQLITE_ROW&&sqlite3_column_int(q,0)==0);sqlite3_finalize(q);sqlite3_close(db);
 }@catch(NSException *e){Failures++;fprintf(stderr,"EXCEPTION: %s\n",e.reason.UTF8String);}@finally{Close(s);[NSFileManager.defaultManager removeItemAtPath:folder error:nil];}
 printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
