#import "../RWDiscoveryEpisodes.h"
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    RWDiscoveryEpisodes *cache=[RWDiscoveryEpisodes new];NSMutableArray *episodes=[NSMutableArray new];for(int i=1;i<=1000;i++)[episodes addObject:@{@"id":[NSString stringWithFormat:@"tt1:1:%d",i],@"season":@1,@"episode":@(i),@"released":@"2000-01-01"}];NSDictionary *show=@{@"id":@"tt1",@"videos":episodes};NSDate *now=[NSDate dateWithTimeIntervalSince1970:1792607000];NSMutableDictionary *history=[NSMutableDictionary new];
    CHECK([[cache episode:nil show:show history:history now:now][@"id"]isEqual:@"tt1:1:1"]);
    double start=NSProcessInfo.processInfo.systemUptime;for(int i=0;i<100;i++){[cache episode:nil show:show history:history now:now];[cache episode:@"tt1:1:900" show:show history:history now:now];}double warm=NSProcessInfo.processInfo.systemUptime-start;
    CHECK([cache.diagnostics[@"builds"]integerValue]==1);CHECK([cache.diagnostics[@"hits"]integerValue]==200);CHECK([[cache episode:@"tt1:1:900" show:show history:history now:now][@"episode"]integerValue]==900);CHECK(![cache episode:@"tt2:1:1" show:show history:history now:now]);
    history[@"tt1:1:1"]=@{@"position":@1200,@"completed":@YES,@"updated":@1};[cache invalidate:@"tt1"];CHECK([[cache episode:nil show:show history:history now:now][@"id"]isEqual:@"tt1:1:2"]);
    history[@"tt1:1:900"]=@{@"position":@50,@"completed":@NO,@"updated":@2};[cache invalidate:@"tt1"];CHECK([[cache episode:nil show:show history:history now:now][@"id"]isEqual:@"tt1:1:900"]);
    [cache removeAll];CHECK([[cache episode:nil show:show history:@{} now:now][@"id"]isEqual:@"tt1:1:1"]);
    NSDictionary *replacement=@{@"id":@"tt1",@"videos":@[episodes[49]]};CHECK([[cache episode:nil show:replacement history:@{} now:now][@"id"]isEqual:@"tt1:1:50"]);CHECK(![cache episode:@"tt1:1:1" show:replacement history:@{} now:now]);
    NSUInteger builds=[cache.diagnostics[@"builds"]integerValue];[cache episode:nil show:replacement history:@{} now:[now dateByAddingTimeInterval:61]];CHECK([cache.diagnostics[@"builds"]integerValue]==builds+1);
    CHECK(![cache episode:nil show:@{@"id":@"tt3"} history:@{} now:now]);CHECK(![cache episode:nil show:@{@"id":@"tt2",@"videos":@[episodes[0]]} history:@{} now:now]);
    for(int i=0;i<20;i++){NSString *title=[NSString stringWithFormat:@"tt%d",100+i];NSDictionary *s=@{@"id":title,@"videos":@[@{@"id":[title stringByAppendingString:@":1:1"],@"season":@1,@"episode":@1,@"released":@"2000-01-01"}]};[cache episode:nil show:s history:@{} now:now];}CHECK([cache.diagnostics[@"cached_shows"]integerValue]<=16);[cache removeAll];CHECK([cache.diagnostics[@"cached_shows"]integerValue]==0);
    // A complete pass over the twelve retained shows must not evict the
    // beginning of the same working set and rebuild it on every Home render.
    [cache removeAll];NSMutableArray *working=[NSMutableArray new];
    for(int i=0;i<12;i++){NSString *key=[NSString stringWithFormat:@"tt%d",1000+i];[working addObject:@{@"id":key,@"videos":@[@{@"id":[key stringByAppendingString:@":1:1"],@"season":@1,@"episode":@1,@"released":@"2000-01-01"}]}];}
    NSUInteger before=[cache.diagnostics[@"builds"]unsignedIntegerValue];
    for(int pass=0;pass<5;pass++)for(NSDictionary *s in working)[cache episode:nil show:s history:@{} now:now];
    CHECK([cache.diagnostics[@"builds"]unsignedIntegerValue]-before==12);
    // A later worker pass can reuse immutable indexes, but never the first
    // profile's viewing target. Date eligibility must also be evaluated anew.
    [RWDiscoveryEpisodes purgeReusableIndexes];NSDictionary *immutable=[RWDiscoveryEpisodes immutableShow:@{@"id":@"tt1",@"videos":[episodes copy]}];
    RWDiscoveryEpisodes *first=[RWDiscoveryEpisodes new];CHECK([[first episode:nil show:immutable history:@{} now:now][@"id"]isEqual:@"tt1:1:1"]);CHECK([first.diagnostics[@"index_builds"]intValue]==1);
    RWDiscoveryEpisodes *second=[RWDiscoveryEpisodes new];CHECK([[second episode:nil show:immutable history:history now:now][@"id"]isEqual:@"tt1:1:900"]);CHECK([second.diagnostics[@"index_hits"]intValue]==1&&[second.diagnostics[@"index_builds"]intValue]==0);
    RWDiscoveryEpisodes *third=[RWDiscoveryEpisodes new];CHECK([[third episode:nil show:immutable history:@{} now:now][@"id"]isEqual:@"tt1:1:1"]);CHECK([third.diagnostics[@"index_hits"]intValue]==1);
    NSDictionary *future=[RWDiscoveryEpisodes immutableShow:@{@"id":@"ttfuture",@"videos":@[@{@"id":@"ttfuture:1:1",@"season":@1,@"episode":@1,@"released":@"2200-01-01"}]}];CHECK(![[RWDiscoveryEpisodes new]episode:nil show:future history:@{} now:now]);RWDiscoveryEpisodes *later=[RWDiscoveryEpisodes new];CHECK([[later episode:nil show:future history:@{} now:[NSDate dateWithTimeIntervalSince1970:7300000000]][@"id"]isEqual:@"ttfuture:1:1"]);CHECK([later.diagnostics[@"index_hits"]intValue]==1);
    // Replacing a same-count metadata array must invalidate the index too.
    NSDictionary *changed=@{@"id":@"tt1",@"videos":@[@{@"id":@"tt1:2:1",@"season":@2,@"episode":@1,@"released":@"2000-01-01"}]};RWDiscoveryEpisodes *replacementCache=[RWDiscoveryEpisodes new];CHECK([[replacementCache episode:nil show:changed history:history now:now][@"id"]isEqual:@"tt1:2:1"]);CHECK([replacementCache.diagnostics[@"index_builds"]intValue]==1);
    NSDictionary *sameCount=@{@"id":@"tt1",@"videos":@[@{@"id":@"tt1:3:1",@"season":@3,@"episode":@1,@"released":@"2000-01-01"}]};RWDiscoveryEpisodes *sameCountCache=[RWDiscoveryEpisodes new];CHECK([[sameCountCache episode:nil show:sameCount history:history now:now][@"id"]isEqual:@"tt1:3:1"]);CHECK(![sameCountCache episode:@"tt1:2:1" show:sameCount history:history now:now]);CHECK([sameCountCache.diagnostics[@"index_builds"]intValue]==1);
    // Shared retention is hard-bounded even under concurrent preparation.
    dispatch_apply(40,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^(size_t i){@autoreleasepool{NSString *key=[NSString stringWithFormat:@"ttbounded%lu",(unsigned long)i];NSMutableArray *rows=[NSMutableArray new];for(int e=1;e<=1000;e++)[rows addObject:@{@"id":[key stringByAppendingFormat:@":1:%d",e],@"season":@1,@"episode":@(e),@"released":@"2000-01-01"}];NSDictionary *title=[RWDiscoveryEpisodes immutableShow:@{@"id":key,@"videos":[rows copy]}];[[RWDiscoveryEpisodes new]episode:nil show:title history:@{} now:now];}});
    CHECK([cache.diagnostics[@"shared_indexes"]intValue]<=16&&[cache.diagnostics[@"shared_episodes"]intValue]<=4096);[RWDiscoveryEpisodes purgeReusableIndexes];CHECK([cache.diagnostics[@"shared_indexes"]intValue]==0&&[cache.diagnostics[@"shared_episodes"]intValue]==0);
    // Nested mutations in caller-owned metadata cannot change a shared index.
    NSMutableDictionary *rawEpisode=[@{@"id":@"ttowned:1:1",@"season":@1,@"episode":@1,@"released":@"2000-01-01"}mutableCopy];NSMutableArray *rawVideos=[NSMutableArray arrayWithObject:rawEpisode];NSMutableDictionary *rawShow=[@{@"id":@"ttowned",@"videos":rawVideos}mutableCopy];
    NSDictionary *owned=[RWDiscoveryEpisodes immutableShow:rawShow];CHECK([RWDiscoveryEpisodes immutableShow:owned]==owned);
    rawEpisode[@"id"]=@"ttowned:1:2";rawEpisode[@"episode"]=@2;[rawVideos removeAllObjects];rawShow[@"id"]=@"changed";
    RWDiscoveryEpisodes *ownerA=[RWDiscoveryEpisodes new],*ownerB=[RWDiscoveryEpisodes new];CHECK([[ownerA episode:nil show:owned history:@{} now:now][@"id"]isEqual:@"ttowned:1:1"]);
    CHECK([[ownerB episode:nil show:owned history:@{} now:now][@"id"]isEqual:@"ttowned:1:1"]);CHECK([ownerB.diagnostics[@"index_hits"]intValue]==1);
    NSDictionary *unowned=@{@"id":@"ttunowned",@"videos":@[@{@"id":@"ttunowned:1:1",@"season":@1,@"episode":@1,@"released":@"2000-01-01"}]};
    RWDiscoveryEpisodes *uA=[RWDiscoveryEpisodes new],*uB=[RWDiscoveryEpisodes new];[uA episode:nil show:unowned history:@{} now:now];[uB episode:nil show:unowned history:@{} now:now];CHECK([uB.diagnostics[@"index_hits"]intValue]==0&&[uB.diagnostics[@"unowned_inputs"]intValue]==1);
    CHECK(![RWDiscoveryEpisodes immutableShow:@{@"id":@"ttbad",@"videos":NSNull.null}]);
    printf("{\"checks\":%d,\"failures\":%d,\"host_200_warm_lookups_seconds\":%.6f}\n",checks,failures,warm);return failures?1:0;
}}
