#import "../RWHomeFeedStore.h"
#import "../RWFeedStore.h"
#import <sqlite3.h>
static int checks,failures;
#define C(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL %d %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static void Wait(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:3];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];C(ready());}
static NSDictionary *Title(int i){return @{@"id":[NSString stringWithFormat:@"tt%d",i],@"name":@"Film",@"type":@"movie"};}
static NSDictionary *Row(NSString *key,NSArray *items){return @{@"id":key,@"title":key,@"recipe":@"for-you",@"mediaType":@"movie",@"items":items};}
static void Activate(RWHomeFeedStore *s,NSArray *rows){__block BOOL done=NO;[s activate:@"scope" profile:@"profile" seedRows:rows excluding:[NSSet set] done:^(NSString *error){C(!error);done=YES;}];Wait(^BOOL{return done;});}
static NSArray *IDs(RWHomeRowFeed *r){__block BOOL done=NO;[r loadRange:NSMakeRange(0,r.count) done:^(NSString *e){C(!e);done=YES;}];Wait(^BOOL{return done;});NSMutableArray *ids=[NSMutableArray new];for(NSUInteger i=0;i<r.count;i++){NSDictionary *m=[r cachedItem:i];if(m)[ids addObject:m[@"id"]];}return ids;}
static void Remove(RWHomeFeedStore *s,RWHomeRowFeed *r,NSArray *ids){__block BOOL done=NO;[s removeIdentifiers:ids row:r done:^(NSString *e){C(!e);done=YES;}];Wait(^BOOL{return done;});}
static long long SQL(NSString *folder,NSString *sql){sqlite3 *db=NULL;sqlite3_stmt *q=NULL;C(sqlite3_open([[folder stringByAppendingPathComponent:@"rewind-home.sqlite"]UTF8String],&db)==SQLITE_OK);C(sqlite3_prepare_v2(db,sql.UTF8String,-1,&q,NULL)==SQLITE_OK);int step=sqlite3_step(q);C(step==SQLITE_ROW||step==SQLITE_DONE);long long n=step==SQLITE_ROW?sqlite3_column_int64(q,0):0;sqlite3_finalize(q);sqlite3_close(db);return n;}
static void Close(RWHomeFeedStore *s){__block BOOL done=NO;[s close:^{done=YES;}];Wait(^BOOL{return done;});}
int main(){@autoreleasepool{
 NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];RWHomeFeedStore *s=[[RWHomeFeedStore alloc]initWithFolder:folder];
 @try{
  NSArray *initial=@[Title(1),Title(2),Title(3),Title(4),Title(5),Title(6)];Activate(s,@[Row(@"films",initial),Row(@"other",@[Title(20)])]);RWHomeRowFeed *r=s.rows[0];
  __block BOOL saved=NO;[s saveAnchor:@{@"id":@"tt1",@"delta":@17} row:r done:^(NSString *e){C(!e);saved=YES;}];Wait(^BOOL{return saved;});
  // Real schema-1 migration retains existing rows, titles and anchors.
  Close(s);SQL(folder,@"DROP TABLE positions");SQL(folder,@"PRAGMA user_version=1");s=[[RWHomeFeedStore alloc]initWithFolder:folder];Activate(s,@[Row(@"films",@[]),Row(@"other",@[])]);r=s.rows[0];C(SQL(folder,@"PRAGMA user_version")==2);C([r.anchor[@"id"]isEqual:@"tt1"]&&r.count==6);
  Remove(s,r,@[@"tt1"]);C(r.count==5);C(![IDs(r)containsObject:@"tt1"]);
  // A genuinely new title arriving while the first one is unavailable must
  // not occupy its old slot. The recovered title returns before the survivors.
  __block BOOL appended=NO;[s append:@[Title(7)] row:r expectedCursor:@{} nextCursor:@{@"page":@1} more:YES done:^(NSUInteger n,NSString *e){C(!e&&n==1);appended=YES;}];Wait(^BOOL{return appended;});
  appended=NO;[s append:@[Title(1)] row:r expectedCursor:@{@"page":@1} nextCursor:@{@"page":@2} more:YES done:^(NSUInteger n,NSString *e){C(!e&&n==1);appended=YES;}];Wait(^BOOL{return appended;});
  C([IDs(r)isEqual:@[@"tt1",@"tt2",@"tt3",@"tt4",@"tt5",@"tt6",@"tt7"]]);
  __block BOOL located=NO;[s anchorIndex:r done:^(NSUInteger n){C(n==0);located=YES;}];Wait(^BOOL{return located;});C([r.anchor[@"delta"]integerValue]==17);
  // Preserve the reserved position across a real close/reopen of SQLite.
  Remove(s,r,@[@"tt3"]);Close(s);s=[[RWHomeFeedStore alloc]initWithFolder:folder];Activate(s,@[Row(@"films",@[]),Row(@"other",@[Title(3),Title(20)])]);r=s.rows[0];C(s.rows[1].count==1);
  __block BOOL assigned=NO;[s assignedIDsExceptRemovedInRow:@"films" done:^(NSSet *ids,NSString *e){C(!e&&![ids containsObject:@"tt3"]&&[ids containsObject:@"tt20"]);assigned=YES;}];Wait(^BOOL{return assigned;});
  assigned=NO;[s assignedIDsExceptRemovedInRow:@"other" done:^(NSSet *ids,NSString *e){C(!e&&[ids containsObject:@"tt3"]);assigned=YES;}];Wait(^BOOL{return assigned;});
  appended=NO;[s append:@[Title(3)] row:r expectedCursor:@{@"page":@2} nextCursor:@{@"page":@3} more:YES done:^(NSUInteger n,NSString *e){C(!e&&n==1);appended=YES;}];Wait(^BOOL{return appended;});C([IDs(r)isEqual:@[@"tt1",@"tt2",@"tt3",@"tt4",@"tt5",@"tt6",@"tt7"]]);
  // Repeated catalog changes cannot grow removed-position history forever.
  for(int batch=0;batch<10;batch++){NSMutableArray *items=[NSMutableArray new],*ids=[NSMutableArray new];for(int i=0;i<30;i++){NSDictionary *m=Title(100+batch*30+i);[items addObject:m];[ids addObject:m[@"id"]];}__block BOOL added=NO;[s append:items row:r expectedCursor:r.cursor nextCursor:@{@"page":@(4+batch)} more:YES done:^(NSUInteger n,NSString *e){C(!e&&n==30);added=YES;}];Wait(^BOOL{return added;});Remove(s,r,ids);}
  C(SQL(folder,@"SELECT COUNT(*) FROM positions")==256);C(SQL(folder,@"SELECT COUNT(*) FROM positions WHERE identity='tt100'")==0);C(SQL(folder,@"SELECT COUNT(*) FROM positions WHERE identity='tt399'")==1);C(r.count==7);
  __block BOOL excluded=NO;[s activate:@"scope" profile:@"profile" seedRows:@[Row(@"films",@[Title(399)])] excluding:[NSSet setWithObject:@"tt399"] done:^(NSString *e){C(!e);excluded=YES;}];Wait(^BOOL{return excluded;});C(SQL(folder,@"SELECT COUNT(*) FROM positions WHERE identity='tt399'")==0);C(SQL(folder,@"SELECT COUNT(*) FROM cards WHERE identity='tt399'")==0);
  // Empty retired recipes release their former ownership; obsolete profile
  // contexts release all their history without affecting another profile.
  Remove(s,r,@[@"tt1",@"tt2",@"tt3",@"tt4",@"tt5",@"tt6",@"tt7"]);Activate(s,@[Row(@"other",@[Title(1),Title(20)])]);C(SQL(folder,@"SELECT COUNT(*) FROM positions")==0);C(s.rows.count==1&&s.rows[0].count==2);
  Remove(s,s.rows[0],@[@"tt1"]);excluded=NO;[s activate:@"new-scope" profile:@"profile" seedRows:@[Row(@"films",@[Title(1)])] excluding:[NSSet set] done:^(NSString *e){C(!e);excluded=YES;}];Wait(^BOOL{return excluded;});C(SQL(folder,@"SELECT COUNT(*) FROM positions")==0);C(s.rows[0].count==1);
 }@catch(NSException *e){failures++;fprintf(stderr,"EXCEPTION %s\n",e.reason.UTF8String);}@finally{Close(s);s=nil;[NSFileManager.defaultManager removeItemAtPath:folder error:nil];}
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
