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
static NSDictionary *Series(int n,BOOL cartoon){NSMutableDictionary *m=[Title(n,@"series")mutableCopy];m[@"genres"]=cartoon?@[@"Animation",@"Family"]:@[@"Drama",@"Family"];return m;}
static NSDictionary *Category(NSArray *items){return @{@"id":@"category-cartoon-time",@"title":@"Cartoon Time",@"recipe":@"category",@"mediaType":@"series",@"anyGenres":@[@"Animation"],@"items":items};}
int main(){@autoreleasepool{
 NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];RWHomeFeedStore *s=[[RWHomeFeedStore alloc]initWithFolder:folder];
 @try{
  NSMutableArray *broad=[NSMutableArray new];for(int i=1;i<=10;i++)[broad addObject:Series(i,i<=5)];
  Activate(s,@[Row(@"for-you-series",@"for-you",broad,@"series"),Row(@"world",@"world",Items(100,2,@"movie"),@"movie")]);
  RWHomeRowFeed *general=Feed(s,@"for-you-series");__block BOOL done=NO;[s saveAnchor:@{@"id":@"tt2",@"delta":@17} row:general done:^(NSString *e){C(!e);done=YES;}];Wait(^BOOL{return done;});done=NO;[s append:@[] row:general expectedCursor:@{} nextCursor:@{@"page":@8} more:YES done:^(NSUInteger n,NSString *e){C(!e);done=YES;}];Wait(^BOOL{return done;});
  NSMutableArray *cartoons=[[broad subarrayWithRange:NSMakeRange(0,5)]mutableCopy];[cartoons addObject:Series(11,YES)];
  // New seeds during a visit must not publish a one-card category or steal
  // existing card ownership. Its unique title joins the general shelf.
  Activate(s,@[Row(@"for-you-series",@"for-you",@[],@"series"),Category(cartoons)]);
  C(!Feed(s,@"category-cartoon-time"));C(Feed(s,@"for-you-series").count==11);C([[IDs(general)lastObject]isEqual:@"tt11"]);C([general.anchor isEqual:@{@"id":@"tt2",@"delta":@17}]);
  Close(s);s=[[RWHomeFeedStore alloc]initWithFolder:folder];
  // A new browsing session can now form the full coherent category, leaving
  // five distinct general titles; source and target cursors stay independent.
  Activate(s,@[Row(@"for-you-series",@"for-you",@[],@"series"),Category(cartoons)]);
  C(Feed(s,@"category-cartoon-time").count==6);C([IDs(Feed(s,@"category-cartoon-time"))isEqual:@[@"tt1",@"tt2",@"tt3",@"tt4",@"tt5",@"tt11"]]);
  general=Feed(s,@"for-you-series");C([IDs(general)isEqual:@[@"tt6",@"tt7",@"tt8",@"tt9",@"tt10"]]);C([general.cursor isEqual:@{@"page":@8}]);C([general.anchor isEqual:@{@"id":@"tt6",@"delta":@17}]);C([s.diagnostics[@"allocation_moves"]count]==6);C(Feed(s,@"world").count==2);
  // Returning to a profile cannot reassign existing shelves mid-session.
  Activate(s,@[Row(@"for-you-series",@"for-you",@[],@"series"),Category(cartoons)]);C(general.count==5);C(Feed(s,@"category-cartoon-time").count==6);
  Remove(s,Feed(s,@"category-cartoon-time"),@[@"tt3"]);done=NO;[s append:@[Series(3,YES)] row:Feed(s,@"category-cartoon-time") expectedCursor:@{} nextCursor:@{@"page":@1} more:YES done:^(NSUInteger n,NSString *e){C(!e&&n==1);done=YES;}];Wait(^BOOL{return done;});C([IDs(Feed(s,@"category-cartoon-time"))isEqual:@[@"tt1",@"tt2",@"tt3",@"tt4",@"tt5",@"tt11"]]);
  Close(s);s=[[RWHomeFeedStore alloc]initWithFolder:folder];Activate(s,@[Row(@"for-you-series",@"for-you",@[],@"series"),Category(cartoons)]);C(![s.diagnostics[@"allocation_moves"]count]);C(Feed(s,@"for-you-series").count==5);C(Feed(s,@"category-cartoon-time").count==6);
  // A five-card new category remains in the general row. Titles are never
  // hidden merely because a theme cannot form, and existing shelves stay put.
  Close(s);s=[[RWHomeFeedStore alloc]initWithFolder:[folder stringByAppendingPathComponent:@"short"]];
  NSMutableArray *few=[NSMutableArray new];for(int i=20;i<25;i++)[few addObject:Series(i,YES)];
  Activate(s,@[Row(@"for-you-series",@"for-you",Items(30,5,@"series"),@"series")]);Activate(s,@[Row(@"for-you-series",@"for-you",@[],@"series"),Category(few)]);C(!Feed(s,@"category-cartoon-time"));C(Feed(s,@"for-you-series").count==10);
  // Insufficient remaining broad support cannot be padded or stolen from World.
  Close(s);s=[[RWHomeFeedStore alloc]initWithFolder:[folder stringByAppendingPathComponent:@"budget"]];NSMutableArray *seven=[NSMutableArray new];for(int i=40;i<47;i++)[seven addObject:Series(i,YES)];
  NSArray *six=[seven subarrayWithRange:NSMakeRange(0,6)];Activate(s,@[Row(@"for-you-series",@"for-you",seven,@"series"),Category(six)]);C(!Feed(s,@"category-cartoon-time"));C(Feed(s,@"for-you-series").count==7);C(![s.diagnostics[@"allocation_moves"]count]);
  // New complete categories can appear during the visit without reassigning
  // existing titles. A later profile return must not reshuffle a thinned row.
  NSMutableArray *fresh=[NSMutableArray new];for(int i=60;i<66;i++)[fresh addObject:Series(i,YES)];Activate(s,@[Row(@"for-you-series",@"for-you",@[],@"series"),Category(fresh)]);C(Feed(s,@"category-cartoon-time").count==6);Remove(s,Feed(s,@"category-cartoon-time"),@[@"tt60",@"tt61",@"tt62"]);
  __block BOOL other=NO;[s activate:@"other" profile:@"other" seedRows:@[Row(@"for-you-series",@"for-you",Items(80,4,@"series"),@"series")] excluding:[NSSet set] done:^(NSString *e){C(!e);other=YES;}];Wait(^BOOL{return other;});Activate(s,@[Row(@"for-you-series",@"for-you",@[],@"series"),Category(@[])]);C(Feed(s,@"category-cartoon-time").count==3);C(Feed(s,@"for-you-series").count==7);
  // Reproduce the real startup ordering: the viewport submits a partial seed
  // before the offscreen category is prepared. Same process must still group.
  Close(s);s=[[RWHomeFeedStore alloc]initWithFolder:[folder stringByAppendingPathComponent:@"opening"]];
  NSMutableArray *opening=[NSMutableArray new];for(int i=200;i<210;i++)[opening addObject:Series(i,i<206)];NSArray *theme=[opening subarrayWithRange:NSMakeRange(0,6)];
  done=NO;[s activate:@"scope" profile:@"profile" seedRows:@[Row(@"for-you-series",@"for-you",opening,@"series")] excluding:[NSSet set] settled:NO done:^(NSString *e){C(!e);done=YES;}];Wait(^BOOL{return done;});
  C(![s.diagnostics[@"opening"][@"settled"]boolValue]);C(![s.diagnostics[@"allocation_moves"]count]);
  Activate(s,@[Row(@"for-you-series",@"for-you",@[],@"series"),Category(theme)]);
  C(Feed(s,@"category-cartoon-time").count==6);C(Feed(s,@"for-you-series").count==4);C([s.diagnostics[@"allocation_moves"]count]==6);C([s.diagnostics[@"opening"][@"organized"]boolValue]);
  // A real touch between the partial and complete callback seals ownership.
  Close(s);s=[[RWHomeFeedStore alloc]initWithFolder:[folder stringByAppendingPathComponent:@"touched"]];
  done=NO;[s activate:@"scope" profile:@"profile" seedRows:@[Row(@"for-you-series",@"for-you",opening,@"series")] excluding:[NSSet set] settled:NO done:^(NSString *e){C(!e);done=YES;}];Wait(^BOOL{return done;});
  [s sealOrganization:@"scope" profile:@"profile"];Activate(s,@[Row(@"for-you-series",@"for-you",@[],@"series"),Category(theme)]);
  C(!Feed(s,@"category-cartoon-time"));C(Feed(s,@"for-you-series").count==10);C(![s.diagnostics[@"allocation_moves"]count]);C(![s.diagnostics[@"opening"][@"organized"]boolValue]);
  // Real182 failure: eligible category titles have broad-row reservations,
  // but the full general row's six-card refill cap never restores them.
  Close(s);NSString *reservedFolder=[folder stringByAppendingPathComponent:@"reserved"];s=[[RWHomeFeedStore alloc]initWithFolder:reservedFolder];NSMutableArray *twelve=[NSMutableArray new];for(int i=300;i<312;i++)[twelve addObject:Series(i,i<308)];NSArray *reservedTheme=[twelve subarrayWithRange:NSMakeRange(0,6)];
  Activate(s,@[Row(@"for-you-series",@"for-you",twelve,@"series")]);Remove(s,Feed(s,@"for-you-series"),@[@"tt301",@"tt302",@"tt303"]);C(Feed(s,@"for-you-series").count==9);Close(s);s=[[RWHomeFeedStore alloc]initWithFolder:reservedFolder];
  Activate(s,@[Row(@"for-you-series",@"for-you",@[],@"series"),Category(reservedTheme)]);C(Feed(s,@"category-cartoon-time").count==6);C(Feed(s,@"for-you-series").count==6);C([s.diagnostics[@"allocation_recovered"]count]==3);C([s.diagnostics[@"allocation_moves"]count]==6);
  C([IDs(Feed(s,@"category-cartoon-time"))isEqual:@[@"tt300",@"tt301",@"tt302",@"tt303",@"tt304",@"tt305"]]);
  // Even after interaction, currently eligible reserved titles recover to
  // their old general positions; only cross-row reorganization is sealed.
  Close(s);s=[[RWHomeFeedStore alloc]initWithFolder:[folder stringByAppendingPathComponent:@"reserved-touch"]];Activate(s,@[Row(@"for-you-series",@"for-you",twelve,@"series")]);Remove(s,Feed(s,@"for-you-series"),@[@"tt301",@"tt302",@"tt303"]);[s sealOrganization:@"scope" profile:@"profile"];
  Activate(s,@[Row(@"for-you-series",@"for-you",@[],@"series"),Category(reservedTheme)]);C(Feed(s,@"for-you-series").count==12);C(!Feed(s,@"category-cartoon-time"));C([s.diagnostics[@"allocation_recovered"]count]==3);C([IDs(Feed(s,@"for-you-series"))isEqual:[twelve valueForKey:@"id"]]);
  // A persisted category has older eligible cards absent from today's top
  // seeds. Keep its order and anchor, but let cold-session allocation extend
  // it from broad ownership. No current-session or profile-return reshuffle.
  Close(s);NSString *depthFolder=[folder stringByAppendingPathComponent:@"depth"];s=[[RWHomeFeedStore alloc]initWithFolder:depthFolder];
  NSMutableArray *depthBroad=[NSMutableArray new],*depthOld=[NSMutableArray new];for(int i=400;i<412;i++)[depthBroad addObject:Series(i,YES)];for(int i=420;i<427;i++)[depthOld addObject:Series(i,YES)];
  Activate(s,@[Row(@"for-you-series",@"for-you",depthBroad,@"series"),Category(depthOld)]);
  RWHomeRowFeed *depthRow=Feed(s,@"category-cartoon-time");done=NO;[s saveAnchor:@{@"id":@"tt423",@"delta":@12} row:depthRow done:^(NSString *e){C(!e);done=YES;}];Wait(^BOOL{return done;});
  Close(s);s=[[RWHomeFeedStore alloc]initWithFolder:depthFolder];NSArray *newSeeds=[depthBroad subarrayWithRange:NSMakeRange(0,6)];
  Activate(s,@[Row(@"for-you-series",@"for-you",@[],@"series"),Category(newSeeds)]);
  depthRow=Feed(s,@"category-cartoon-time");C(depthRow.count==12);C(Feed(s,@"for-you-series").count==7);
  C([IDs(depthRow)isEqual:@[@"tt420",@"tt421",@"tt422",@"tt423",@"tt424",@"tt425",@"tt426",@"tt400",@"tt401",@"tt402",@"tt403",@"tt404"]]);
  C([depthRow.anchor isEqual:@{@"id":@"tt423",@"delta":@12}]);C([s.diagnostics[@"allocation_moves"]count]==5);
  Remove(s,depthRow,@[@"tt420",@"tt421",@"tt422",@"tt423",@"tt424",@"tt425",@"tt426"]);
  Activate(s,@[Row(@"for-you-series",@"for-you",@[],@"series"),Category(newSeeds)]);C(Feed(s,@"for-you-series").count==7);C(Feed(s,@"category-cartoon-time").count==5);
  // Actual Kids failure: one new theme spans broad and broad-animation ownership.
  // Move only at a cold opening, leave six cartoons and four general titles,
  // and repair each moved donor anchor to its next surviving title.
  Close(s);NSString *splitFolder=[folder stringByAppendingPathComponent:@"split-donors"];s=[[RWHomeFeedStore alloc]initWithFolder:splitFolder];
  NSMutableArray *splitBroad=[NSMutableArray new],*splitCartoons=[NSMutableArray new],*adventures=[NSMutableArray new];
  for(int i=800;i<808;i++){NSMutableDictionary *m=[Series(i,NO)mutableCopy];m[@"genres"]=i<802?@[@"Family",@"Adventure"]:@[@"Family",@"Comedy"];[splitBroad addObject:m];if(i<802)[adventures addObject:m];}
  for(int i=810;i<820;i++){NSMutableDictionary *m=[Series(i,YES)mutableCopy];m[@"genres"]=i<814?@[@"Animation",@"Adventure"]:@[@"Animation"];[splitCartoons addObject:m];if(i<814)[adventures addObject:m];}
  NSMutableDictionary *adventure=[Category(adventures)mutableCopy];adventure[@"id"]=@"category-kids-adventure";adventure[@"title"]=@"Big Adventures";adventure[@"anyGenres"]=@[@"Adventure"];
  Activate(s,@[Row(@"for-you-series",@"for-you",splitBroad,@"series"),Category(splitCartoons)]);
  done=NO;[s saveAnchor:@{@"id":@"tt811",@"delta":@11} row:Feed(s,@"category-cartoon-time") done:^(NSString *e){C(!e);done=YES;}];Wait(^BOOL{return done;});
  done=NO;[s saveAnchor:@{@"id":@"tt800",@"delta":@5} row:Feed(s,@"for-you-series") done:^(NSString *e){C(!e);done=YES;}];Wait(^BOOL{return done;});
  Close(s);s=[[RWHomeFeedStore alloc]initWithFolder:splitFolder];Activate(s,@[Row(@"for-you-series",@"for-you",@[],@"series"),Category(@[]),adventure]);
  C(Feed(s,@"category-kids-adventure").count==6);C(Feed(s,@"category-cartoon-time").count==6);C(Feed(s,@"for-you-series").count==6);
  C([Feed(s,@"category-cartoon-time").anchor isEqual:@{@"id":@"tt814",@"delta":@11}]);C([Feed(s,@"for-you-series").anchor isEqual:@{@"id":@"tt802",@"delta":@5}]);
  C([IDs(Feed(s,@"category-kids-adventure"))isEqual:[adventures valueForKey:@"id"]]);
  Activate(s,@[Row(@"for-you-series",@"for-you",@[],@"series"),Category(splitCartoons),adventure]);C(Feed(s,@"category-kids-adventure").count==6);C(Feed(s,@"category-cartoon-time").count==6);
  // A documentary's Animation tag does not make it a cartoon donor.
  Close(s);s=[[RWHomeFeedStore alloc]initWithFolder:[folder stringByAppendingPathComponent:@"genres"]];NSMutableArray *mixed=[NSMutableArray new];for(int i=100;i<110;i++)[mixed addObject:Series(i,YES)];NSMutableDictionary *doc=[mixed[0]mutableCopy];doc[@"genres"]=@[@"Animation",@"Documentary",@"Family"];mixed[0]=doc;
  Activate(s,@[Row(@"for-you-series",@"for-you",mixed,@"series"),Category([mixed subarrayWithRange:NSMakeRange(0,6)])]);C(!Feed(s,@"category-cartoon-time"));C(Feed(s,@"for-you-series").count==10);C(![s.diagnostics[@"allocation_moves"]count]);
 }@catch(NSException *e){failures++;fprintf(stderr,"EXCEPTION %s\n",e.reason.UTF8String);}@finally{Close(s);s=nil;[NSFileManager.defaultManager removeItemAtPath:folder error:nil];}
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
