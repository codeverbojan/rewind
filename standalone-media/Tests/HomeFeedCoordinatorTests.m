#import "../RWHomeFeedCoordinator.h"
#import "../RWFeedStore.h"
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static void Wait(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:4];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];CHECK(ready());}
static NSDictionary *Title(int i){return @{@"id":[NSString stringWithFormat:@"tt%07d",i],@"type":@"movie",@"name":[NSString stringWithFormat:@"Film %d",i]};}
static NSArray *Page(int start,int count){NSMutableArray *out=[NSMutableArray new];for(int i=start;i<start+count;i++)[out addObject:Title(i)];return out;}
static NSDictionary *Row(NSString *key,NSArray *items){return @{@"id":key,@"title":key,@"mediaType":@"movie",@"recipe":@"for-you",@"items":items};}
static NSUInteger Count(RWHomeFeedCoordinator *s,NSUInteger i){NSArray *rows=s.rows;return i<rows.count?[rows[i][@"feed"]count]:0;}
int main(){@autoreleasepool{
    NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];__block RWHomeFeedCoordinator *s=[[RWHomeFeedCoordinator alloc]initWithFolder:folder];NSMutableArray *calls=[NSMutableArray new];__block BOOL active=YES;__block NSUInteger changes=0;__block NSArray *seeds;
    @try{
    s.isActive=^BOOL{return active;};s.onChange=^{changes++;if([s.scope isEqual:@"regular"]&&seeds)[s activate:@"regular" profile:@"regular" rows:seeds excluding:[NSSet setWithObject:Title(1)[@"id"]]];};s.prepareRecords=^(NSArray *items,NSDictionary *row,void(^done)(NSArray *,NSString *)){done(items,nil);};
    s.fetchPage=^(NSDictionary *row,NSDictionary *cursor,NSSet *excluded,BOOL(^current)(void),void(^done)(NSArray *,NSDictionary *,BOOL,NSString *)){[calls addObject:@{@"row":row,@"cursor":cursor,@"excluded":excluded,@"current":[current copy],@"done":[done copy]}];};
    seeds=@[Row(@"films",Page(1,8)),Row(@"world",Page(5,8))];[s activate:@"regular" profile:@"regular" rows:seeds excluding:[NSSet setWithObject:Title(1)[@"id"]]];Wait(^BOOL{return s.rows.count==2&&![s.diagnostics[@"activating"]boolValue];});CHECK(Count(s,0)==7&&Count(s,1)==4);
    [s loadMore:@"films" manual:NO];[s loadMore:@"world" manual:NO];[s loadMore:@"world" manual:NO];Wait(^BOOL{return calls.count==1;});CHECK([s.diagnostics[@"pending"]integerValue]==1);CHECK([calls[0][@"excluded"]count]==12);
    // A late recommendation pass may change row order while a source page is
    // in flight. Same-policy layout maintenance must not cancel that page or
    // the user's queued second shelf. SQLite retains the established order.
    seeds=@[seeds[1],seeds[0]];[s activate:@"regular" profile:@"regular" rows:seeds excluding:[NSSet setWithObject:Title(1)[@"id"]]];
    BOOL(^stillCurrent)(void)=calls[0][@"current"];CHECK(stillCurrent());CHECK([s.diagnostics[@"pending"]integerValue]==1);
    void(^first)(NSArray *,NSDictionary *,BOOL,NSString *)=calls[0][@"done"];first(Page(10,12),@{@"page":@1,@"skip":@32},YES,nil);Wait(^BOOL{return calls.count==2;});CHECK(Count(s,0)==16);CHECK([calls[1][@"excluded"]containsObject:Title(21)[@"id"]]);
    void(^second)(NSArray *,NSDictionary *,BOOL,NSString *)=calls[1][@"done"];second(Page(15,12),@{@"page":@1,@"skip":@32},YES,nil);Wait(^BOOL{return Count(s,1)==9&&![s.diagnostics[@"active"]length];});CHECK([s.diagnostics[@"added"]integerValue]==14);
    // A provider failure preserves the exact retry cursor and every card.
    [s loadMore:@"films" manual:NO];Wait(^BOOL{return calls.count==3;});void(^failure)(NSArray *,NSDictionary *,BOOL,NSString *)=calls[2][@"done"];failure(nil,nil,YES,@"Offline");CHECK([s.rows[0][@"error"]isEqual:@"Offline"]);CHECK(Count(s,0)==16);[s loadMore:@"films" manual:NO];CHECK(calls.count==3);[s loadMore:@"films" manual:YES];Wait(^BOOL{return calls.count==4;});CHECK([calls[3][@"cursor"]isEqual:calls[2][@"cursor"]]);
    // A filtered empty page advances once without another gesture. A second
    // empty page pauses quietly, preserving its exact next cursor and cards.
    void(^empty)(NSArray *,NSDictionary *,BOOL,NSString *)=calls[3][@"done"];empty(@[],@{@"page":@2,@"skip":@64},YES,nil);
    Wait(^BOOL{return calls.count==5;});CHECK([calls[4][@"cursor"][@"skip"]integerValue]==64);
    CHECK([s.rows[0][@"loading"]boolValue]&&![s.rows[0][@"error"]length]);
    void(^emptyAgain)(NSArray *,NSDictionary *,BOOL,NSString *)=calls[4][@"done"];emptyAgain(@[],@{@"page":@3,@"skip":@96},YES,nil);
    Wait(^BOOL{return [s.rows[0][@"paused"]boolValue]&&![s.diagnostics[@"active"]length];});CHECK(![s.rows[0][@"error"]length]);CHECK([s.rows[0][@"more"]boolValue]);
    [s loadMore:@"films" manual:NO];CHECK(calls.count==5);[s loadMore:@"films" manual:YES];Wait(^BOOL{return calls.count==6;});CHECK([calls[5][@"cursor"][@"skip"]integerValue]==96);
    // Profile change invalidates old network work even if it replies later.
    BOOL(^oldCurrent)(void)=calls[5][@"current"];void(^oldReply)(NSArray *,NSDictionary *,BOOL,NSString *)=calls[5][@"done"];
    [s activate:@"regular" profile:@"regular" rows:seeds excluding:[NSSet setWithArray:@[Title(1)[@"id"],Title(999)[@"id"]]]];CHECK(!oldCurrent());Wait(^BOOL{return ![s.diagnostics[@"activating"]boolValue];});CHECK(Count(s,0)==16);
    [s activate:@"kids" profile:@"kids" rows:@[Row(@"films",Page(100,3))] excluding:[NSSet set]];CHECK(!oldCurrent());oldReply(Page(200,8),@{@"page":@3},YES,nil);Wait(^BOOL{return s.rows.count==1&&! [s.diagnostics[@"activating"]boolValue];});CHECK(Count(s,0)==3);CHECK([s.scope isEqual:@"kids"]);
    [s activate:@"regular" profile:@"regular" rows:seeds excluding:[NSSet setWithObject:Title(1)[@"id"]]];Wait(^BOOL{return s.rows.count==2&&![s.diagnostics[@"activating"]boolValue];});CHECK(Count(s,0)==16&&Count(s,1)==9);
    // Explicit end stops requests, while leaving already loaded cards intact.
    [s loadMore:@"world" manual:YES];Wait(^BOOL{return calls.count==7;});void(^end)(NSArray *,NSDictionary *,BOOL,NSString *)=calls[6][@"done"];end(@[],@{@"page":@2,@"skip":@32},NO,nil);Wait(^BOOL{return ![s.rows[1][@"more"]boolValue];});[s loadMore:@"world" manual:YES];CHECK(calls.count==7);
    [s catalogChanged];[s catalogChanged];[s loadMore:@"world" manual:YES];CHECK(calls.count==7); // no hot loop
    // Advance only the bounded local-revisit clock; no database or feed state
    // is fabricated. The real coordinator/store append must retain the cursor.
    [[s valueForKey:@"revisitAfter"]setObject:@0 forKey:@"world"];[s catalogChanged];CHECK([s.rows[1][@"more"]boolValue]);[s loadMore:@"world" manual:NO];Wait(^BOOL{return calls.count==8;});CHECK([calls.lastObject[@"cursor"][@"skip"]integerValue]==32);
    void(^revisit)(NSArray *,NSDictionary *,BOOL,NSString *)=calls.lastObject[@"done"];revisit(Page(27,2),@{@"page":@3,@"skip":@32},NO,nil);Wait(^BOOL{return Count(s,1)==11&&![s.diagnostics[@"active"]length];});CHECK(![s.rows[1][@"more"]boolValue]);[s catalogChanged];[s loadMore:@"world" manual:YES];CHECK(calls.count==8);
    [s rememberAnchor:@{@"id":Title(15)[@"id"],@"delta":@12.5} identifier:@"films"];Wait(^BOOL{return [s.diagnostics[@"rows"][0][@"anchor"]count]>0;});__block BOOL anchorDone=NO;[s anchorIndex:@"films" done:^(NSUInteger index,NSDictionary *anchor){CHECK(index==9);CHECK([anchor[@"delta"]doubleValue]==12.5);anchorDone=YES;}];Wait(^BOOL{return anchorDone;});
    // Leaving Home cancels subsequent work; a later explicit retry can resume.
    [s loadMore:@"films" manual:YES];Wait(^BOOL{return calls.count==9;});active=NO;BOOL(^inactive)(void)=calls[8][@"current"];CHECK(!inactive());[s cancel];void(^late)(NSArray *,NSDictionary *,BOOL,NSString *)=calls[8][@"done"];late(Page(300,4),@{@"page":@99},YES,nil);CHECK(Count(s,0)==16);active=YES;
    // Dealloc closes SQLite on the shared queue. Reopen restores real layout,
    // cursors and anchors; new rank seeds append after the retained prefix.
    [calls removeAllObjects];s=nil;s=[[RWHomeFeedCoordinator alloc]initWithFolder:folder];s.isActive=^BOOL{return YES;};s.prepareRecords=^(NSArray *items,NSDictionary *row,void(^done)(NSArray *,NSString *)){done(items,nil);};[s activate:@"regular" profile:@"regular" rows:@[Row(@"world",Page(400,8)),Row(@"films",Page(500,8))] excluding:[NSSet setWithObject:Title(1)[@"id"]]];Wait(^BOOL{return s.rows.count==2&&![s.diagnostics[@"activating"]boolValue];});CHECK([s.rows[0][@"id"]isEqual:@"films"]);CHECK(Count(s,0)==24&&Count(s,1)==19);CHECK([s.rows[0][@"cursor"]integerValue]==3);CHECK(changes>0);
    // A new catalog policy can reopen an ended row without resetting its
    // cards/anchor or launching work before a deliberate end-scroll.
    __block NSUInteger extraPages=0;__block NSDictionary *resumedCursor=nil;
    s.hasMoreCatalogPages=^BOOL(NSDictionary *row,NSDictionary *cursor){return [row[@"id"]isEqual:@"world"]&&!cursor[@"catalogPolicy"];};
    s.fetchPage=^(NSDictionary *row,NSDictionary *cursor,NSSet *excluded,BOOL(^current)(void),void(^done)(NSArray *,NSDictionary *,BOOL,NSString *)){
        extraPages++;resumedCursor=cursor;CHECK([row[@"id"]isEqual:@"world"]&&current());CHECK([excluded containsObject:Title(27)[@"id"]]);
        done(Page(600,2),@{@"page":@4,@"catalogPolicy":@1},NO,nil);
    };
    CHECK([s.rows[1][@"more"]boolValue]&&extraPages==0);CHECK(Count(s,1)==19);
    [s loadMore:@"world" manual:NO];Wait(^BOOL{return extraPages==1&&Count(s,1)==21&&![s.diagnostics[@"active"]length];});CHECK([resumedCursor[@"page"]integerValue]==3);CHECK(![s.rows[1][@"more"]boolValue]);
    // A saved catalog offset survives cancellation of later work and a real
    // coordinator reopen. It inserts no card and preserves the visible anchor.
    s.fetchPage=nil;[calls removeAllObjects];
    s.fetchPageWithProgress=^(NSDictionary *row,NSDictionary *cursor,NSSet *excluded,BOOL(^current)(void),void(^checkpoint)(NSDictionary *,BOOL,void(^)(NSString *)),void(^done)(NSArray *,NSDictionary *,BOOL,NSString *)){
        [calls addObject:@{@"cursor":cursor,@"checkpoint":[checkpoint copy],@"current":[current copy],@"done":[done copy]}];
    };
    [s loadMore:@"films" manual:YES];Wait(^BOOL{return calls.count==1;});
    void(^checkpoint)(NSDictionary *,BOOL,void(^)(NSString *))=calls[0][@"checkpoint"];
    NSDictionary *savedProgress=@{@"page":@3,@"skip":@100,@"catalogPolicy":@1};__block BOOL saved=NO;
    checkpoint(savedProgress,YES,^(NSString *error){CHECK(!error);saved=YES;});Wait(^BOOL{return saved;});CHECK(Count(s,0)==24);CHECK([s.diagnostics[@"catalog_checkpoints"]integerValue]==1);
    CHECK([s.diagnostics[@"rows"][0][@"cursor"]isEqual:savedProgress]);CHECK([s.diagnostics[@"rows"][0][@"anchor"][@"delta"]doubleValue]==12.5);
    [s cancel];__block BOOL rejected=NO;checkpoint(@{@"page":@999},YES,^(NSString *error){CHECK(error.length>0);rejected=YES;});CHECK(rejected);CHECK([s.diagnostics[@"rows"][0][@"cursor"]isEqual:savedProgress]);
    [calls removeAllObjects];s=nil;s=[[RWHomeFeedCoordinator alloc]initWithFolder:folder];s.isActive=^BOOL{return YES;};s.prepareRecords=^(NSArray *items,NSDictionary *row,void(^done)(NSArray *,NSString *)){done(items,nil);};
    [s activate:@"regular" profile:@"regular" rows:@[Row(@"films",@[]),Row(@"world",@[])] excluding:[NSSet setWithObject:Title(1)[@"id"]]];Wait(^BOOL{return s.rows.count==2&&![s.diagnostics[@"activating"]boolValue];});
    CHECK([s.diagnostics[@"rows"][0][@"cursor"]isEqual:savedProgress]);CHECK(Count(s,0)==24&&Count(s,1)==21);
    // The final append compares against the acknowledged cursor, not the
    // request's original cursor; stale requests never roll it backwards.
    s.fetchPageWithProgress=^(NSDictionary *row,NSDictionary *cursor,NSSet *excluded,BOOL(^current)(void),void(^checkpoint)(NSDictionary *,BOOL,void(^)(NSString *)),void(^done)(NSArray *,NSDictionary *,BOOL,NSString *)){
        CHECK([cursor isEqual:savedProgress]);NSDictionary *next=@{@"page":@4,@"skip":@150,@"catalogPolicy":@1};
        checkpoint(next,YES,^(NSString *error){CHECK(!error);done(Page(9900,2),next,YES,nil);});
    };
    [s loadMore:@"films" manual:NO];Wait(^BOOL{return Count(s,0)==26&&![s.diagnostics[@"active"]length];});CHECK([s.diagnostics[@"rows"][0][@"cursor"][@"skip"]integerValue]==150);
    // No cursor movement must stop after one response; a genuine empty
    // advance may use one extra batch, sharing the exact original deadline.
    [calls removeAllObjects];s.fetchPageWithProgress=nil;
    s.fetchPage=^(NSDictionary *row,NSDictionary *cursor,NSSet *excluded,BOOL(^current)(void),void(^done)(NSArray *,NSDictionary *,BOOL,NSString *)){
        [calls addObject:@{@"cursor":cursor,@"current":[current copy],@"done":[done copy]}];
    };
    [s loadMore:@"films" manual:YES];Wait(^BOOL{return calls.count==1;});
    void(^sameCursor)(NSArray *,NSDictionary *,BOOL,NSString *)=calls[0][@"done"];sameCursor(@[],calls[0][@"cursor"],YES,nil);
    Wait(^BOOL{return ![s.diagnostics[@"active"]length];});CHECK(calls.count==1&&[s.rows[0][@"paused"]boolValue]&&![s.rows[0][@"error"]length]);
    [s loadMore:@"films" manual:YES];Wait(^BOOL{return calls.count==2;});NSNumber *deadline=[s valueForKey:@"attemptEnds"][@"films"];
    void(^advance)(NSArray *,NSDictionary *,BOOL,NSString *)=calls[1][@"done"];advance(@[],@{@"page":@5,@"skip":@200},YES,nil);
    Wait(^BOOL{return calls.count==3;});CHECK([[s valueForKey:@"attemptEnds"][@"films"]isEqual:deadline]);CHECK([calls[2][@"cursor"][@"skip"]integerValue]==200);
    BOOL(^obsolete)(void)=calls[1][@"current"];CHECK(!obsolete());advance(Page(9800,2),@{@"page":@99},YES,nil);CHECK(Count(s,0)==26);
    void(^found)(NSArray *,NSDictionary *,BOOL,NSString *)=calls[2][@"done"];found(Page(9700,2),@{@"page":@6,@"skip":@250},YES,nil);
    Wait(^BOOL{return Count(s,0)==28&&![s.diagnostics[@"active"]length];});CHECK(![s.rows[0][@"paused"]boolValue]&&![s.rows[0][@"error"]length]);
    // A spent wall-clock allowance cannot restart with a new deadline.
    [s loadMore:@"films" manual:YES];Wait(^BOOL{return calls.count==4;});[[s valueForKey:@"attemptEnds"]setObject:@0 forKey:@"films"];
    void(^expired)(NSArray *,NSDictionary *,BOOL,NSString *)=calls[3][@"done"];expired(@[],@{@"page":@7,@"skip":@300},YES,nil);
    Wait(^BOOL{return ![s.diagnostics[@"active"]length];});CHECK(calls.count==4&&[s.rows[0][@"paused"]boolValue]&&![s.rows[0][@"error"]length]);
    }@catch(NSException *e){Failures++;fprintf(stderr,"EXCEPTION %s\n",e.reason.UTF8String);}@finally{[s cancel];[calls removeAllObjects];s=nil;__block BOOL flushed=NO;dispatch_async([RWFeedStore storageQueue],^{dispatch_async(dispatch_get_main_queue(),^{flushed=YES;});});Wait(^BOOL{return flushed;});[NSFileManager.defaultManager removeItemAtPath:folder error:nil];}
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
