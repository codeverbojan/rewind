#import "../RWHomeFeedCoordinator.h"
#import "../RWFeedStore.h"
#import <sqlite3.h>
static int checks,failures;
#define C(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"line%d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static void Wait(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:3];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];C(ready());}
static NSDictionary *Title(int n){return @{@"id":[NSString stringWithFormat:@"tt%d",n],@"type":@"movie",@"name":[NSString stringWithFormat:@"Film%d",n]};}
static NSArray *Page(int first,int count){NSMutableArray *a=[NSMutableArray new];for(int i=first;i<first+count;i++)[a addObject:Title(i)];return a;}
static NSDictionary *Row(NSString *key,NSArray *items){return @{@"id":key,@"title":key,@"recipe":@"for-you",@"mediaType":@"movie",@"items":items};}
static RWHomeRowFeed *Feed(RWHomeFeedCoordinator *c,NSString *key){for(NSDictionary *r in c.rows)if([r[@"id"]isEqual:key])return r[@"feed"];return nil;}
static void Activate(RWHomeFeedStore *s,NSArray *rows){__block BOOL done=NO;[s activate:@"cap" profile:@"cap" seedRows:rows excluding:[NSSet set] done:^(NSString *error){C(!error);done=YES;}];Wait(^BOOL{return done;});}
static NSArray *IDs(RWHomeRowFeed *r){__block BOOL done=NO;[r loadRange:NSMakeRange(0,r.count) done:^(NSString *error){C(!error);done=YES;}];Wait(^BOOL{return done;});NSMutableArray *ids=[NSMutableArray new];for(NSUInteger i=0;i<r.count;i++)if([r cachedItem:i]){[ids addObject:[r cachedItem:i][@"id"]];}return ids;}
static void Close(RWHomeFeedStore *s){__block BOOL done=NO;[s close:^{done=YES;}];Wait(^BOOL{return done;});}
int main(){@autoreleasepool{
 NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];RWHomeFeedCoordinator *c=[[RWHomeFeedCoordinator alloc]initWithFolder:folder];RWHomeFeedStore *s=nil;__block NSUInteger network=0,changes=0;
 @try{
  c.isActive=^BOOL{return YES;};c.onChange=^{changes++;};c.prepareRecords=^(NSArray *items,NSDictionary *row,void(^done)(NSArray *,NSString *)){done(items,nil);};
  c.fetchPage=^(NSDictionary *row,NSDictionary *cursor,NSSet *excluded,BOOL(^current)(void),void(^done)(NSArray *,NSDictionary *,BOOL,NSString *)){network++;done(@[],cursor,NO,nil);};
  NSArray *first=@[Row(@"films",Page(1,2)),Row(@"other",Page(10,2))];[c activate:@"warm" profile:@"warm" rows:first excluding:[NSSet setWithObject:@"tt99"]];Wait(^BOOL{return c.rows.count==2&&![c.diagnostics[@"activating"]boolValue];});
  [c rememberAnchor:@{@"id":@"tt2",@"delta":@17} identifier:@"films"];Wait(^BOOL{return Feed(c,@"films").anchor.count>0;});
  __block BOOL paged=NO;[(RWHomeFeedStore *)[c valueForKey:@"store"] append:@[] row:Feed(c,@"films") expectedCursor:@{} nextCursor:@{@"page":@7,@"skip":@64} more:YES done:^(NSUInteger added,NSString *error){C(!error&&added==0);paged=YES;}];Wait(^BOOL{return paged;});
  // New qualified seed data reaches a NONEMPTY shelf without a swipe/request.
  // Sibling ownership, hidden titles and original card order must survive.
  NSArray *fresh=@[Row(@"films",@[Title(2),Title(10),Title(99),Title(3),Title(4),Title(5),Title(6),Title(7)]),first[1]];
  NSUInteger before=changes;[c activate:@"warm" profile:@"warm" rows:fresh excluding:[NSSet setWithObject:@"tt99"]];Wait(^BOOL{return ![c.diagnostics[@"activating"]boolValue];});
  C(Feed(c,@"films").count==7);C([IDs(Feed(c,@"films"))isEqual:@[@"tt1",@"tt2",@"tt3",@"tt4",@"tt5",@"tt6",@"tt7"]]);C([Feed(c,@"films").anchor isEqual:@{@"id":@"tt2",@"delta":@17}]);C([Feed(c,@"films").cursor isEqual:@{@"page":@7,@"skip":@64}]);C(Feed(c,@"other").count==2);C(network==0);C(changes>before);C([c.diagnostics[@"storage"][@"seed_refills"][@"films"]integerValue]==5);
  [c activate:@"warm" profile:@"warm" rows:@[Row(@"films",Page(100,12)),first[1]] excluding:[NSSet setWithObject:@"tt99"]];Wait(^BOOL{return ![c.diagnostics[@"activating"]boolValue];});C(Feed(c,@"films").count==19);C(network==0);
  NSArray *appendedIDs=IDs(Feed(c,@"films"));C(appendedIDs.count>=7&&[[appendedIDs subarrayWithRange:NSMakeRange(0,7)]isEqual:@[@"tt1",@"tt2",@"tt3",@"tt4",@"tt5",@"tt6",@"tt7"]]);C([Feed(c,@"films").anchor isEqual:@{@"id":@"tt2",@"delta":@17}]);C([Feed(c,@"films").cursor isEqual:@{@"page":@7,@"skip":@64}]);
  [c activate:@"warm" profile:@"warm" rows:@[Row(@"films",Page(100,12)),first[1]] excluding:[NSSet setWithObject:@"tt99"]];Wait(^BOOL{return ![c.diagnostics[@"activating"]boolValue];});C(Feed(c,@"films").count==19&&network==0);
  // A stale seed must not undo a current-policy rejection. When evidence
  // changes again, the same ID can return to its reserved original position.
  __block BOOL permitLast=YES;c.permitsRecord=^BOOL(NSDictionary *m,NSDictionary *row){return permitLast||![m[@"id"]isEqual:@"tt1006"];};
  NSArray *guard=@[Row(@"guard",Page(1001,6))];[c activate:@"guard" profile:@"guard" rows:guard excluding:[NSSet set]];Wait(^BOOL{return ![c.diagnostics[@"activating"]boolValue];});C(Feed(c,@"guard").count==6);
  [c activate:@"guard" profile:@"guard" rows:guard excluding:[NSSet set]];Wait(^BOOL{return ![c.diagnostics[@"activating"]boolValue];});
  permitLast=NO;__block BOOL removed=NO;[(RWHomeFeedStore *)[c valueForKey:@"store"]removeIdentifiers:@[@"tt1006"] row:Feed(c,@"guard") done:^(NSString *e){C(!e);removed=YES;}];Wait(^BOOL{return removed;});
  [c activate:@"guard" profile:@"guard" rows:guard excluding:[NSSet set]];Wait(^BOOL{return ![c.diagnostics[@"activating"]boolValue];});C(Feed(c,@"guard").count==5);
  for(int repeat=0;repeat<3;repeat++){[c activate:@"guard" profile:@"guard" rows:guard excluding:[NSSet set]];Wait(^BOOL{return ![c.diagnostics[@"activating"]boolValue];});}C(Feed(c,@"guard").count==5);
  permitLast=YES;[c activate:@"guard" profile:@"guard" rows:guard excluding:[NSSet set]];Wait(^BOOL{return ![c.diagnostics[@"activating"]boolValue];});C(Feed(c,@"guard").count==6&&[[IDs(Feed(c,@"guard"))lastObject]isEqual:@"tt1006"]);c.permitsRecord=nil;
  // A changed recipe with the same ID must not put unrelated cards under the
  // old heading. Populated shelves remain owned by their original recipe.
  NSDictionary *mood=@{@"id":@"mood",@"title":@"Adventure",@"recipe":@"mood",@"mood":@"Epic adventures",@"mediaType":@"movie",@"items":Page(200,2)};
  [c activate:@"moods" profile:@"moods" rows:@[mood] excluding:[NSSet set]];Wait(^BOOL{return [c.scope isEqual:@"moods"]&&![c.diagnostics[@"activating"]boolValue];});
  NSMutableDictionary *changed=[mood mutableCopy];changed[@"mood"]=@"Suspense";changed[@"title"]=@"Suspense";changed[@"items"]=Page(300,8);[c activate:@"moods" profile:@"moods" rows:@[changed] excluding:[NSSet set]];Wait(^BOOL{return ![c.diagnostics[@"activating"]boolValue];});C(Feed(c,@"mood").count==2);C([Feed(c,@"mood").descriptor[@"mood"]isEqual:@"Epic adventures"]);C(network==0);
  // Identical identities changing from viewport-only to complete must bypass
  // the coordinator signature cache and reach the storage initialization gate.
  NSMutableArray *ten=[NSMutableArray new];for(int n=2000;n<2010;n++){NSMutableDictionary *m=[Title(n)mutableCopy];m[@"genres"]=@[@"Animation"];[ten addObject:m];}
  NSDictionary *theme=@{@"id":@"category-animation",@"title":@"Animated Worlds",@"recipe":@"category",@"mediaType":@"movie",@"anyGenres":@[@"Animation"],@"items":[ten subarrayWithRange:NSMakeRange(0,6)]};NSArray *opening=@[Row(@"for-you-movie",ten),theme];
  [c activate:@"opening" profile:@"opening" rows:opening excluding:[NSSet set] settled:NO];Wait(^BOOL{return ![c.diagnostics[@"activating"]boolValue];});C(!Feed(c,@"category-animation"));C(Feed(c,@"for-you-movie").count==10);
  [c activate:@"opening" profile:@"opening" rows:opening excluding:[NSSet set] settled:YES];Wait(^BOOL{return ![c.diagnostics[@"activating"]boolValue];});C(Feed(c,@"category-animation").count==6);C(Feed(c,@"for-you-movie").count==4);C([c.diagnostics[@"storage"][@"allocation_moves"]count]==6);C(network==0);
  // A rich provider record may contain a large cast/episode payload. The
  // shelf only needs its bounded card fields; rejecting the raw payload can
  // synchronously re-enter a renderer that retries the unchanged activation.
  NSMutableDictionary *rich=[Title(1000)mutableCopy];rich[@"cast"]=[@"x" stringByPaddingToLength:300*1024 withString:@"x" startingAtIndex:0];
  NSArray *richRows=@[Row(@"rich",@[rich])];__block NSUInteger repeated=0;
  c.onChange=^{repeated++;if(repeated<12)[c activate:@"rich" profile:@"rich" rows:richRows excluding:[NSSet set]];};
  [c activate:@"rich" profile:@"rich" rows:richRows excluding:[NSSet set]];Wait(^BOOL{return ![c.diagnostics[@"activating"]boolValue];});
  C(Feed(c,@"rich").count==1);C(repeated<=3);C(![c.diagnostics[@"error"]length]);
  if(Feed(c,@"rich").count){NSArray *saved=IDs(Feed(c,@"rich"));C([saved isEqual:@[@"tt1000"]]);C(![Feed(c,@"rich")cachedItem:0][@"cast"]);}
  // Even genuinely invalid input cannot recursively hammer the same failure.
  NSMutableArray *invalid=[NSMutableArray new];for(int n=0;n<15;n++)[invalid addObject:Row([NSString stringWithFormat:@"bad%d",n],@[])];repeated=0;
  c.onChange=^{repeated++;if(repeated<12)[c activate:@"invalid" profile:@"invalid" rows:invalid excluding:[NSSet set]];};
  [c activate:@"invalid" profile:@"invalid" rows:invalid excluding:[NSSet set]];C(repeated==1);C([c.diagnostics[@"error"]length]>0);[c setValue:@0 forKey:@"activationRetryAfter"];[c activate:@"invalid" profile:@"invalid" rows:invalid excluding:[NSSet set]];C(repeated==2);
  [c activate:@"invalid" profile:@"invalid" rows:@[Row(@"recovered",Page(1200,2))] excluding:[NSSet set]];c.onChange=nil;Wait(^BOOL{return ![c.diagnostics[@"activating"]boolValue];});C(Feed(c,@"recovered").count==2);C(![c.diagnostics[@"error"]length]);
  [c cancel];c=nil;__block BOOL idle=NO;dispatch_async([RWFeedStore storageQueue],^{dispatch_async(dispatch_get_main_queue(),^{idle=YES;});});Wait(^BOOL{return idle;});
  NSString *cap=[folder stringByAppendingPathComponent:@"cap"];s=[[RWHomeFeedStore alloc]initWithFolder:cap];NSMutableArray *rows=[NSMutableArray new];for(int i=0;i<14;i++)[rows addObject:Row([NSString stringWithFormat:@"row%d",i],i?@[]:Page(400,2))];Activate(s,rows);C(s.rows.count==14);
  // Retired EMPTY rows cannot occupy every slot forever. Keep the populated
  // shelf, reclaim absent empty recipes and admit the current category.
  Activate(s,@[rows[0],Row(@"new",Page(500,3))]);C(s.rows.count==2);C([s.rows[0].identifier isEqual:@"row0"]&&s.rows[0].count==2);C([s.rows.lastObject.identifier isEqual:@"new"]&&s.rows.lastObject.count==3);Close(s);s=nil;
  cap=[folder stringByAppendingPathComponent:@"full"];s=[[RWHomeFeedStore alloc]initWithFolder:cap];[rows removeAllObjects];for(int i=0;i<14;i++)[rows addObject:Row([NSString stringWithFormat:@"row%d",i],Page(600+i,1))];Activate(s,rows);Activate(s,@[Row(@"overflow",Page(900,2))]);C(s.rows.count==14);
  // When every slot is populated, do not write invisible orphan cards that
  // steal global title assignments. The existing shelves stay untouched.
  sqlite3 *db=NULL;C(sqlite3_open_v2([[cap stringByAppendingPathComponent:@"rewind-home.sqlite"]UTF8String],&db,SQLITE_OPEN_READONLY,NULL)==SQLITE_OK);sqlite3_stmt *q=NULL;C(sqlite3_prepare_v2(db,"SELECT COUNT(*) FROM cards c LEFT JOIN rows r ON c.scope=r.scope AND c.rowid=r.identity WHERE r.identity IS NULL",-1,&q,NULL)==SQLITE_OK);C(sqlite3_step(q)==SQLITE_ROW);C(sqlite3_column_int(q,0)==0);sqlite3_finalize(q);sqlite3_close(db);
 }@catch(NSException *e){failures++;fprintf(stderr,"EXCEPTION%s\n",e.reason.UTF8String);}@finally{[c cancel];c=nil;if(s)Close(s);s=nil;__block BOOL idle=NO;dispatch_async([RWFeedStore storageQueue],^{dispatch_async(dispatch_get_main_queue(),^{idle=YES;});});Wait(^BOOL{return idle;});[NSFileManager.defaultManager removeItemAtPath:folder error:nil];}
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
