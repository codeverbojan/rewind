#import "../RWHomeFeedCoordinator.h"
#import "../RWFeedStore.h"
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static BOOL Wait(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:2];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];CHECK(ready());return ready();}
static NSDictionary *Title(int i){return @{@"id":[NSString stringWithFormat:@"tt%07d",i],@"type":@"movie",@"name":[NSString stringWithFormat:@"Film %d",i]};}
static NSDictionary *Row(NSString *key,NSArray *items){return @{@"id":key,@"title":key,@"mediaType":@"movie",@"recipe":@"for-you",@"items":items};}
static NSDictionary *Descriptor(RWHomeFeedCoordinator *s,NSString *key){for(NSDictionary *r in s.rows)if([r[@"id"]isEqual:key])return r;return @{};}
static NSUInteger Count(RWHomeFeedCoordinator *s,NSString *key){return [Descriptor(s,key)[@"feed"]count];}
static void Reply(NSDictionary *call,NSArray *items,NSDictionary *cursor,BOOL more,NSString *error){void(^done)(NSArray *,NSDictionary *,BOOL,NSString *)=call[@"done"];done(items,cursor,more,error);}
// Complete both bounded empty batches; the second has no further cursor
// movement. Local enrichment assertions below must not cause remote work.
static void Empty(NSMutableArray *network,NSDictionary *cursor){NSUInteger n=network.count;Reply(network.lastObject,@[],cursor,YES,nil);if(Wait(^BOOL{return network.count==n+1;}))Reply(network.lastObject,@[],cursor,YES,nil);}
static void Local(NSDictionary *call,NSArray *items){void(^done)(NSArray *,NSString *)=call[@"done"];done(items,nil);}
int main(){@autoreleasepool{
    NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];RWHomeFeedCoordinator *s=[[RWHomeFeedCoordinator alloc]initWithFolder:folder];NSMutableArray *network=[NSMutableArray new],*local=[NSMutableArray new];__block BOOL active=YES;__block NSUInteger changes=0;
    @try{
        s.isActive=^BOOL{return active;};s.onChange=^{changes++;};s.prepareRecords=^(NSArray *items,NSDictionary *row,void(^done)(NSArray *,NSString *)){done(items,nil);};
        s.fetchPage=^(NSDictionary *row,NSDictionary *cursor,NSSet *excluded,BOOL(^current)(void),void(^done)(NSArray *,NSDictionary *,BOOL,NSString *)){[network addObject:@{@"row":row,@"cursor":cursor,@"excluded":excluded,@"current":[current copy],@"done":[done copy]}];};
        s.recheckLocal=^(NSDictionary *row,NSSet *excluded,BOOL(^current)(void),void(^done)(NSArray *,NSString *)){[local addObject:@{@"row":row,@"excluded":excluded,@"current":[current copy],@"done":[done copy]}];};
        NSArray *seeds=@[Row(@"films",@[Title(1),Title(2)]),Row(@"world",@[Title(3),Title(4)])];
        [s activate:@"regular" profile:@"regular" rows:seeds excluding:[NSSet setWithObject:Title(99)[@"id"]]];Wait(^BOOL{return s.rows.count==2&&![s.diagnostics[@"activating"]boolValue];});
        [s catalogChanged];CHECK(!network.count&&!local.count); // Untouched shelves remain lazy.
        [s rememberAnchor:@{@"id":Title(2)[@"id"],@"delta":@17} identifier:@"films"];
        [s loadMore:@"films" manual:NO];Wait(^BOOL{return network.count==1;});Empty(network,@{@"page":@1,@"skip":@32});Wait(^BOOL{return [Descriptor(s,@"films")[@"paused"]boolValue]&&! [s.diagnostics[@"active"]length];});CHECK(!local.count);
        for(int i=0;i<30;i++)[s catalogChanged];
        if(Wait(^BOOL{return local.count==1;})){
            CHECK(network.count==2);CHECK([local[0][@"excluded"]count]==5);CHECK([local[0][@"excluded"]containsObject:Title(99)[@"id"]]);
            // The completed page and its watchdog cannot own a later local
            // request for the same row just because the scope still matches.
            BOOL(^oldRequest)(void)=network[0][@"current"];CHECK(!oldRequest());Reply(network[0],@[Title(300)],@{@"page":@99},YES,nil);CHECK(Count(s,@"films")==2);
            // Real SQLite insertion retains exclusions across shelves and the exact cursor/anchor.
            Local(local[0],@[Title(2),Title(3),Title(5),Title(99)]);Wait(^BOOL{return Count(s,@"films")==3&&![s.diagnostics[@"active"]length];});
            CHECK(Count(s,@"world")==2);CHECK([Descriptor(s,@"films")[@"error"]length]==0);CHECK([Descriptor(s,@"films")[@"cursor"]integerValue]==1);
            NSDictionary *saved=s.diagnostics[@"rows"][0];CHECK([saved[@"cursor"]isEqual:@{@"page":@1,@"skip":@32}]);CHECK([saved[@"anchor"][@"id"]isEqual:Title(2)[@"id"]]);CHECK([saved[@"anchor"][@"delta"]integerValue]==17);
            for(int i=0;i<30;i++)[s catalogChanged];CHECK(local.count==1&&network.count==2);
            [s loadMore:@"films" manual:NO];Wait(^BOOL{return network.count==3;});Empty(network,@{@"page":@2,@"skip":@64});Wait(^BOOL{return [Descriptor(s,@"films")[@"paused"]boolValue]&&! [s.diagnostics[@"active"]length];});
            [s catalogChanged];CHECK(local.count==1); // A burst cannot defeat the thirty-second bound.
            [[s valueForKey:@"localAfter"]setObject:@0 forKey:@"films"];[s catalogChanged];Wait(^BOOL{return local.count==2;});Local(local.lastObject,@[]);Wait(^BOOL{return ![s.diagnostics[@"active"]length];});
            CHECK(Count(s,@"films")==3);CHECK([Descriptor(s,@"films")[@"paused"]boolValue]);CHECK([Descriptor(s,@"films")[@"cursor"]integerValue]==2);
            for(int i=0;i<30;i++)[s catalogChanged];CHECK(local.count==2&&network.count==4);
            [[s valueForKey:@"localAfter"]setObject:@0 forKey:@"films"];[s catalogChanged];Wait(^BOOL{return local.count==3;});NSDictionary *stale=local.lastObject;BOOL(^current)(void)=stale[@"current"];
            NSArray *kids=@[Row(@"films",@[Title(100)])];[s activate:@"kids" profile:@"kids" rows:kids excluding:[NSSet set]];CHECK(!current());Local(stale,@[Title(200)]);Wait(^BOOL{return [s.scope isEqual:@"kids"]&&! [s.diagnostics[@"activating"]boolValue];});CHECK(Count(s,@"films")==1);
            // Inactive app has no new worker; returning to the same context can consume queued metadata.
            [s loadMore:@"films" manual:NO];Wait(^BOOL{return network.count==5;});Empty(network,@{@"page":@1,@"skip":@12});Wait(^BOOL{return [Descriptor(s,@"films")[@"paused"]boolValue]&&! [s.diagnostics[@"active"]length];});
            active=NO;[s catalogChanged];CHECK(local.count==3&&network.count==6);active=YES;[s activate:@"kids" profile:@"kids" rows:kids excluding:[NSSet set]];Wait(^BOOL{return local.count==4;});Local(local.lastObject,@[]);Wait(^BOOL{return ![s.diagnostics[@"active"]length];});
            // Actual transport errors still require user retry. Enrichment must not restart them.
            [s loadMore:@"films" manual:YES];Wait(^BOOL{return network.count==7;});Reply(network.lastObject,nil,nil,YES,@"Offline");[s catalogChanged];CHECK(local.count==4&&network.count==7);CHECK([Descriptor(s,@"films")[@"error"]isEqual:@"Offline"]);
            // A rating can arrive while the remote page is finishing. Preserve that event.
            [s loadMore:@"films" manual:YES];Wait(^BOOL{return network.count==8;});[[s valueForKey:@"localAfter"]setObject:@0 forKey:@"films"];[s catalogChanged];Empty(network,@{@"page":@2,@"skip":@24});Wait(^BOOL{return local.count==5;});Local(local.lastObject,@[Title(101)]);Wait(^BOOL{return Count(s,@"films")==2&&! [s.diagnostics[@"active"]length];});CHECK(network.count==9);
            CHECK([s.diagnostics[@"local_checks"]integerValue]==5);CHECK([s.diagnostics[@"local_added"]integerValue]==2);
            // Deactivation while a local result is pending must preserve its
            // quiet retry state. No result may append while the app is inactive.
            [s loadMore:@"films" manual:NO];Wait(^BOOL{return network.count==10;});Empty(network,@{@"page":@3,@"skip":@36});Wait(^BOOL{return [Descriptor(s,@"films")[@"paused"]boolValue]&&! [s.diagnostics[@"active"]length];});
            [[s valueForKey:@"localAfter"]setObject:@0 forKey:@"films"];[s catalogChanged];Wait(^BOOL{return local.count==6;});active=NO;Local(local.lastObject,@[Title(102)]);CHECK(Count(s,@"films")==2);CHECK([Descriptor(s,@"films")[@"paused"]boolValue]);
            active=YES;[[s valueForKey:@"localAfter"]setObject:@0 forKey:@"films"];[s activate:@"kids" profile:@"kids" rows:kids excluding:[NSSet set]];
            if(Wait(^BOOL{return local.count==7;})){Local(local.lastObject,@[Title(102)]);Wait(^BOOL{return Count(s,@"films")==3&&! [s.diagnostics[@"active"]length];});CHECK([s.diagnostics[@"local_checks"]integerValue]==7);CHECK([s.diagnostics[@"local_added"]integerValue]==3);CHECK(network.count==11);}
            CHECK(changes>0);
        }
    }@catch(NSException *e){Failures++;fprintf(stderr,"EXCEPTION %s\n",e.reason.UTF8String);}@finally{[s cancel];[network removeAllObjects];[local removeAllObjects];s=nil;__block BOOL flushed=NO;dispatch_async([RWFeedStore storageQueue],^{dispatch_async(dispatch_get_main_queue(),^{flushed=YES;});});Wait(^BOOL{return flushed;});[NSFileManager.defaultManager removeItemAtPath:folder error:nil];}
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
