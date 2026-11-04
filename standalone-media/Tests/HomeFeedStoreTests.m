#import "../RWHomeFeedStore.h"
#import "../RWFeedStore.h"
#import "../RWFeedStorageBudget.h"
#import <sqlite3.h>
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static void Wait(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:5];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];CHECK(ready());}
static NSDictionary *Title(int i){return @{@"id":[NSString stringWithFormat:@"tt%d",i],@"type":@"movie",@"name":[NSString stringWithFormat:@"Film %d",i],@"imdbRating":@"8.1",@"genres":@[@"Family"]};}
static NSArray *Page(int start,int count){NSMutableArray *out=[NSMutableArray new];for(int i=start;i<start+count;i++)[out addObject:Title(i)];return out;}
static NSDictionary *Row(NSString *key,NSArray *items){return @{@"id":key,@"title":key,@"recipe":key,@"mediaType":@"movie",@"items":items};}
static void Activate(RWHomeFeedStore *s,NSString *scope,NSString *profile,NSArray *rows,NSSet *excluded){__block BOOL done=NO;[s activate:scope profile:profile seedRows:rows excluding:excluded done:^(NSString *error){CHECK(NSThread.isMainThread);if(error)fprintf(stderr,"ACTIVATE: %s\n",error.UTF8String);CHECK(!error);done=YES;}];Wait(^BOOL{return done;});}
static NSString *Append(RWHomeFeedStore *s,RWHomeRowFeed *r,NSArray *records,NSDictionary *expected,NSDictionary *next,NSUInteger wanted){__block BOOL done=NO;__block NSString *failure;[s append:records row:r expectedCursor:expected nextCursor:next more:YES done:^(NSUInteger count,NSString *error){CHECK(NSThread.isMainThread);CHECK(count==wanted);failure=error;done=YES;}];Wait(^BOOL{return done;});return failure;}
static NSArray *Read(RWHomeRowFeed *r,NSRange range){__block BOOL done=NO;[r loadRange:range done:^(NSString *error){CHECK(!error);done=YES;}];Wait(^BOOL{return done;});NSMutableArray *out=[NSMutableArray new];for(NSUInteger i=range.location;i<NSMaxRange(range);i++){NSDictionary *m=[r cachedItem:i];CHECK(m);if(m)[out addObject:m];}return out;}
static void Close(RWHomeFeedStore *s){__block BOOL done=NO;[s close:^{done=YES;}];Wait(^BOOL{return done;});}
int main(){@autoreleasepool{
    NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];RWHomeFeedStore *s=[[RWHomeFeedStore alloc]initWithFolder:folder];unsigned long long size=0;
    @try {
    NSArray *seeds=@[Row(@"for-you",Page(1,8)),Row(@"world",Page(5,8))];Activate(s,@"regular:auto",@"regular",seeds,[NSSet setWithObject:@"tt1"]);
    CHECK(s.rows.count==2);RWHomeRowFeed *first=s.rows[0],*world=s.rows[1];CHECK(first.count==7&&world.count==4);CHECK([[Read(first,NSMakeRange(0,7))valueForKey:@"id"]isEqual:@[@"tt2",@"tt3",@"tt4",@"tt5",@"tt6",@"tt7",@"tt8"]]);
    // Pages share one global unique key. Concurrent row writes cannot duplicate
    // overlap; both cursor transitions commit with their accepted assignments.
    CHECK(!Append(s,first,Page(10,12),@{},@{@"skip":@12},9));CHECK(first.count==16);CHECK(!Append(s,world,Page(15,12),@{},@{@"skip":@12},5));CHECK(world.count==9);
    NSMutableSet *all=[NSMutableSet new];for(RWHomeRowFeed *r in s.rows)for(NSDictionary *m in Read(r,NSMakeRange(0,r.count))){CHECK(![all containsObject:m[@"id"]]);[all addObject:m[@"id"]];}CHECK(all.count==25&&![all containsObject:@"tt1"]);
    CHECK(Append(s,first,Page(100,2),@{},@{@"skip":@24},0)!=nil);CHECK(first.count==16&&[first.cursor isEqual:@{@"skip":@12}]);
    // Invalid page must roll back an earlier valid insert AND its cursor.
    CHECK(Append(s,first,@[Title(100),@{@"id":@"bad",@"type":@"series",@"name":@"Wrong section"}],first.cursor,@{@"skip":@24},0)!=nil);CHECK(first.count==16&&[first.cursor isEqual:@{@"skip":@12}]);
    __block BOOL saved=NO;[s saveAnchor:@{@"id":@"tt15",@"delta":@27.5} row:first done:^(NSString *error){CHECK(!error);saved=YES;}];Wait(^BOOL{return saved;});
    // A different row may publish while the saved anchor query is queued.
    // Its revision change must not silently discard a still-valid position.
    __block BOOL republished=NO,anchorRestored=NO;
    [s append:@[] row:world expectedCursor:world.cursor nextCursor:world.cursor more:YES done:^(NSUInteger added,NSString *error){CHECK(!error&&added==0);republished=YES;}];
    [s anchorIndex:first done:^(NSUInteger index){CHECK(index==9);anchorRestored=YES;}];
    Wait(^BOOL{return republished&&anchorRestored;});
    NSDictionary *savedCursor=first.cursor,*savedAnchor=first.anchor;NSArray *savedIDs=[Read(first,NSMakeRange(0,first.count))valueForKey:@"id"];
    // Reshuffled new ranking seeds do not replace/reorder a user's loaded feed. New qualified identities append at the end.
    Activate(s,@"regular:auto",@"regular",@[Row(@"world",Page(200,8)),Row(@"for-you",Page(300,8))],[NSSet setWithObject:@"tt1"]);CHECK([s.rows[0].identifier isEqual:@"for-you"]);CHECK(s.rows[0].count==24);CHECK([[Read(s.rows[0],NSMakeRange(0,16))valueForKey:@"id"]isEqual:savedIDs]);
    CHECK(first==s.rows[0]&&world==s.rows[1]);CHECK([first.anchor isEqual:savedAnchor]);
    CHECK(Append(s,first,Page(500,1),@{},@{@"skip":@24},0)!=nil); // Same row identity survives; stale cursor still cannot append.
    Close(s);s=nil;s=[[RWHomeFeedStore alloc]initWithFolder:folder];Activate(s,@"regular:auto",@"regular",seeds,[NSSet setWithObject:@"tt1"]);first=s.rows[0];world=s.rows[1];CHECK(first.count==24&&[first.cursor isEqual:savedCursor]&&[first.anchor isEqual:savedAnchor]);CHECK([[Read(first,NSMakeRange(0,16))valueForKey:@"id"]isEqual:savedIDs]);
    RWHomeRowFeed *old=first;Activate(s,@"kids:7:auto",@"kids",@[Row(@"for-you",Page(1,3))],[NSSet set]);CHECK(s.rows.count==1&&s.rows[0].count==3);CHECK(Append(s,old,Page(600,1),old.cursor,@{},0)!=nil);CHECK(![old cachedItem:0]);
    Activate(s,@"regular:auto",@"regular",seeds,[NSSet setWithObjects:@"tt1",@"tt15",nil]);first=s.rows[0];CHECK(first.count==23);CHECK(![[Read(first,NSMakeRange(0,23))valueForKey:@"id"]containsObject:@"tt15"]);
    Activate(s,@"kids:12:720",@"kids",@[Row(@"for-you",Page(20,3))],[NSSet set]);CHECK([[Read(s.rows[0],NSMakeRange(0,3))valueForKey:@"id"]isEqual:@[@"tt20",@"tt21",@"tt22"]]);
    // A context collision cannot import another profile's assignments.
    __block BOOL rejected=NO;[s activate:@"regular:auto" profile:@"kids" seedRows:seeds excluding:[NSSet set] done:^(NSString *error){CHECK(error!=nil);rejected=YES;}];Wait(^BOOL{return rejected;});CHECK(s.rows.count==0);
    Activate(s,@"regular:auto",@"regular",seeds,[NSSet setWithObjects:@"tt1",@"tt15",nil]);first=s.rows[0];CHECK(first.count==23);
    // Large traversal keeps only a single bounded metadata window, while the
    // persistent feed can grow well past twelve cards and retain every ID.
    for(int page=0;page<12;page++)CHECK(!Append(s,first,Page(1000+page*32,32),first.cursor,@{@"skip":@(100+page)},32));CHECK(first.count==407);
    for(NSUInteger i=0;i<first.count;i+=64)Read(first,NSMakeRange(i,MIN((NSUInteger)64,first.count-i)));CHECK([s.diagnostics[@"memory_records"]unsignedIntegerValue]<=128);CHECK(![first cachedItem:0]);CHECK([first cachedItem:first.count-1]);
    [s discardMemory];CHECK([s.diagnostics[@"memory_records"]integerValue]==0);CHECK(first.count==407);
    // A queued old-context read cannot populate the new profile's memory.
    __block BOOL readDone=NO,activated=NO;[first loadRange:NSMakeRange(0,4) done:^(NSString *error){CHECK(error!=nil);readDone=YES;}];[s activate:@"kids:12:720" profile:@"kids" seedRows:@[Row(@"for-you",Page(20,3))] excluding:[NSSet set] done:^(NSString *error){CHECK(!error);activated=YES;}];Wait(^BOOL{return readDone&&activated;});CHECK([s.diagnostics[@"memory_records"]integerValue]==0);
    // Rendering gates run before metadata reaches the visible cache. A newly
    // rejected title is removed transactionally, not shown using saved flags.
    __block NSUInteger changed=0;s.onChange=^{changed++;};s.prepareRecords=^(NSArray *items,NSDictionary *row,void(^done)(NSArray *,NSString *)){NSMutableArray *allowed=[items mutableCopy];if(allowed.count)[allowed removeObjectAtIndex:0];done(allowed,nil);};
    RWHomeRowFeed *kid=s.rows[0];NSUInteger beforeCount=kid.count;__block BOOL filtered=NO;[kid loadRange:NSMakeRange(0,MIN((NSUInteger)3,kid.count)) done:^(NSString *error){CHECK(!error);filtered=YES;}];Wait(^BOOL{return filtered;});CHECK(kid.count==beforeCount-1&&changed==1);CHECK([s.diagnostics[@"memory_records"]integerValue]==0);s.prepareRecords=nil;s.onChange=nil;
    // Retain language evidence, but never persisted episode readiness hints.
    Activate(s,@"evidence",@"test",@[Row(@"films",@[])],[NSSet set]);NSMutableDictionary *evidence=[Title(900)mutableCopy];evidence[@"discovery"]=@{@"primaryLanguage":@"en",@"languageSource":@"https://example.com/evidence"};evidence[@"episodeVideoID"]=@"stale:1:1";CHECK(!Append(s,s.rows[0],@[evidence],@{},@{@"page":@1},1));NSDictionary *loaded=Read(s.rows[0],NSMakeRange(0,1)).firstObject;CHECK([loaded[@"discovery"][@"languageSource"]isEqual:evidence[@"discovery"][@"languageSource"]]);CHECK(!loaded[@"episodeVideoID"]);
    // Featured ownership is part of the same transaction. A new rank must
    // neither steal a previously displayed card nor replace a valid hero.
    NSDictionary *lead=@{@"id":@"__hero",@"title":@"Featured",@"recipe":@"hero",@"mediaType":@"hero",@"items":@[Title(10)]};
    Activate(s,@"featured",@"featured",@[lead,Row(@"films",Page(10,8))],[NSSet set]);CHECK(s.rows[0].count==1&&s.rows[1].count==7);NSMutableDictionary *newLead=[lead mutableCopy];newLead[@"items"]=@[Title(14)];Activate(s,@"featured",@"featured",@[newLead,Row(@"films",Page(30,8))],[NSSet set]);CHECK(s.rows[0].count==1&&s.rows[1].count==15);CHECK([Read(s.rows[0],NSMakeRange(0,1)).firstObject[@"id"]isEqual:Title(10)[@"id"]]);CHECK([[Read(s.rows[1],NSMakeRange(0,7))valueForKey:@"id"]containsObject:Title(14)[@"id"]]);
    // Other profile rows survived; no user preference/history database exists.
    Activate(s,@"regular:auto",@"regular",seeds,[NSSet setWithObjects:@"tt1",@"tt15",nil]);CHECK(s.rows[0].count==407);Close(s);
    size=[[NSFileManager.defaultManager attributesOfItemAtPath:[folder stringByAppendingPathComponent:@"rewind-home.sqlite"] error:nil][NSFileSize]unsignedLongLongValue];CHECK(size>0&&size<=RWFeedDiskBudgetBytes);
    } @catch(NSException *e){Failures++;fprintf(stderr,"EXCEPTION: %s\n",e.reason.UTF8String);} @finally{Close(s);[NSFileManager.defaultManager removeItemAtPath:folder error:nil];}
    printf("{\"checks\":%d,\"failures\":%d,\"persisted_titles\":407,\"bytes\":%llu}\n",Checks,Failures,size);return Failures?1:0;
}}
