#import "../RWHomeDelivery.h"
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    double now=1792620400;NSDictionary *profile=@{@"maxAge":@(-1)};
    NSDictionary *title=@{@"id":@"tt1",@"name":@"Film",@"imdbRating":@8.1,@"poster":@"https://example.test/1.jpg"};
    NSDictionary *page=@{@"hero":@{},@"rows":@[@{@"id":@"for-you",@"title":@"For you",@"items":@[title]}],@"computedAt":@(now)};
    NSDictionary *snapshot=[RWHomeDelivery snapshot:page profile:profile quality:0 now:now];
    CHECK(snapshot.count);CHECK([[RWHomeDelivery restore:snapshot profile:profile quality:0 now:now+3600]isEqual:page]);
    NSMutableDictionary *changedTitle=[title mutableCopy];changedTitle[@"availability"]=@{@"checked":@(now)};
    NSDictionary *(^pageFor)(NSDictionary *)=^NSDictionary *(NSDictionary *m){return @{@"hero":@{},@"rows":@[@{@"id":@"for-you",@"title":@"For you",@"items":@[m]}]};};
    CHECK([[RWHomeDelivery displaySignature:page]isEqual:[RWHomeDelivery displaySignature:pageFor(changedTitle)]]);
    changedTitle[@"imdbRating"]=@8.3;CHECK(![[RWHomeDelivery displaySignature:page]isEqual:[RWHomeDelivery displaySignature:pageFor(changedTitle)]]);
    CHECK(![RWHomeDelivery needsRefresh:@{@"availability":@{@"retry_after":@(now+3600)}} now:now]);
    CHECK(![RWHomeDelivery restore:snapshot profile:@{@"maxAge":@7} quality:0 now:now].count);
    CHECK(![RWHomeDelivery restore:snapshot profile:profile quality:720 now:now].count);
    CHECK(![RWHomeDelivery restore:snapshot profile:@{@"maxAge":@(-1),@"discoveryPreferences":@{@"languageMode":@"all"}} quality:0 now:now].count);
    CHECK(![RWHomeDelivery restore:snapshot profile:profile quality:0 now:now+86400].count);
    CHECK(![RWHomeDelivery restore:snapshot profile:profile quality:0 now:now-1].count);
    CHECK(![RWHomeDelivery restore:nil profile:profile quality:0 now:now].count);
    CHECK(![RWHomeDelivery snapshot:@{} profile:profile quality:0 now:now].count);
    NSDictionary *oldEpisode=@{@"id":@"tt2",@"type":@"series",@"episodeVideoID":@"tt2:1:1",@"season":@1,@"episode":@1,@"seriesName":@"Series",@"name":@"Episode one"};
    NSDictionary *clean=[RWHomeDelivery titleMetadata:oldEpisode];CHECK(!clean[@"episodeVideoID"]&&!clean[@"season"]&&!clean[@"episode"]);CHECK([clean[@"name"]isEqual:@"Series"]);CHECK(oldEpisode[@"episodeVideoID"]!=nil);
    NSMutableDictionary *corrupt=[snapshot mutableCopy];corrupt[@"page"]=@{@"rows":@[NSNull.null]};CHECK(![RWHomeDelivery restore:corrupt profile:profile quality:0 now:now].count);
    NSMutableArray *large=[NSMutableArray new];for(int i=0;i<80;i++)[large addObject:@{@"id":[NSString stringWithFormat:@"tt%d",i+100],@"name":@"Film"}];
    NSMutableArray *rows=[NSMutableArray new];for(int i=0;i<20;i++)[rows addObject:@{@"id":[NSString stringWithFormat:@"row%d",i],@"items":large}];
    NSDictionary *bounded=[RWHomeDelivery snapshot:@{@"rows":rows} profile:profile quality:0 now:now];
    CHECK([bounded[@"page"][@"rows"]count]==12);CHECK([bounded[@"page"][@"rows"][0][@"items"]count]==12);
    CHECK(![RWHomeDelivery snapshot:@{@"rows":@[@{@"id":@"x",@"items":@[@{@"id":@"tt2",@"description":[@"x" stringByPaddingToLength:2*1024*1024 withString:@"x" startingAtIndex:0]}]}]} profile:profile quality:0 now:now].count);
    {NSDictionary *movie=@{@"id":@"tt900",@"name":@"Retained",@"type":@"movie",@"videos":@[@1],@"availability":@{@"discovery_eligible":@YES},@"ageAllowed":@YES};
    NSDictionary *show=@{@"id":@"tt901",@"name":@"Retained show",@"type":@"series",@"videos":@[@1],@"episodeVideoID":@"tt901:1:1"};
    NSDictionary *observations=@{@"tt900":@{@"state":@"candidates",@"meta":movie,@"checked":@100},@"tt901:1:1":@{@"state":@"ready",@"meta":show,@"checked":@200},@"tt901:1:2":@{@"state":@"ready",@"meta":show,@"checked":@201},@"wrong":@{@"state":@"ready",@"meta":movie,@"checked":@300},@"tt902":@{@"state":@"waiting",@"meta":@{@"id":@"tt902",@"type":@"movie"}},@"tt903":NSNull.null};
    NSArray *retained=[RWHomeDelivery retainedTitles:observations];CHECK(retained.count==2);CHECK([[retained valueForKey:@"id"]isEqual:@[@"tt901",@"tt900"]]);
    for(NSDictionary *m in retained)CHECK(!m[@"availability"]&&!m[@"ageAllowed"]&&!m[@"videos"]&&!m[@"episodeVideoID"]);
    CHECK([RWHomeDelivery retainedTitles:nil].count==0&&[RWHomeDelivery retainedTitles:(id)NSNull.null].count==0);CHECK([movie[@"availability"][@"discovery_eligible"]boolValue]);
    NSMutableDictionary *many=[NSMutableDictionary new];for(int i=0;i<300;i++){NSString *key=[NSString stringWithFormat:@"tt%04d",i];many[key]=@{@"state":@"candidates",@"meta":@{@"id":key,@"type":@"movie"},@"checked":@(i)};}retained=[RWHomeDelivery retainedTitles:many];CHECK(retained.count==256);CHECK([retained.firstObject[@"id"]isEqual:@"tt0299"]&&[retained.lastObject[@"id"]isEqual:@"tt0044"]);
    }
    NSArray *ranked=@[@{@"id":@"fresh",@"availability":@{@"discovery_eligible":@YES,@"checked":@(now-60)}},@{@"id":@"negative",@"availability":@{@"watch_instead_of_play":@YES}},@{@"id":@"error",@"availability":@{@"checked":@(now-1)}},@{@"id":@"unknown"},@{@"id":@"stale",@"availability":@{@"discovery_eligible":@YES,@"checked":@(now-7*3600)}}];
    NSArray *world=@[@{@"id":@"world1"},@{@"id":@"unknown"}],*older=@[@{@"id":@"older1"}],*shows=@[@{@"id":@"show1"}];
    NSArray *targets=[RWHomeDelivery targets:ranked world:world older:older shows:shows now:now limit:24];
    CHECK(targets.count==4);CHECK([targets[0][@"id"]isEqual:@"older1"]);CHECK([targets[1][@"id"]isEqual:@"world1"]);CHECK([targets[2][@"id"]isEqual:@"show1"]);
    CHECK([targets[3][@"id"]isEqual:@"unknown"]);
    CHECK([RWHomeDelivery targets:large world:large older:large shows:large now:now limit:100].count==4);
    CHECK(![RWHomeDelivery targets:large world:@[] older:@[] shows:@[] now:now limit:0].count);
    NSArray *combined=[RWHomeDelivery targets:large includingWatches:@[large[0],large[1],large[2]]];CHECK(combined.count==4);CHECK([combined[0][@"id"]isEqual:large[0][@"id"]]&&[combined[1][@"id"]isEqual:large[1][@"id"]]);CHECK([[NSSet setWithArray:[combined valueForKey:@"id"]]count]==4);
    CHECK([RWHomeDelivery targets:@[] includingWatches:large].count==2);CHECK([RWHomeDelivery targets:large includingWatches:@[]].count==4);
    CHECK(![RWHomeDelivery publishCompleted:0 total:0]);CHECK(![RWHomeDelivery publishCompleted:1 total:24]);CHECK([RWHomeDelivery publishCompleted:8 total:24]);CHECK([RWHomeDelivery publishCompleted:16 total:24]);CHECK([RWHomeDelivery publishCompleted:24 total:24]);CHECK([RWHomeDelivery publishCompleted:3 total:3]);
    // Once selected titles get observations, the next pass must advance into
    // the remaining pool rather than repeatedly checking the same four titles.
    NSArray *first=[RWHomeDelivery targets:large world:@[] older:@[] shows:@[] now:now limit:24];NSMutableSet *selected=[NSMutableSet new];for(NSDictionary *m in first)[selected addObject:m[@"id"]];
    NSMutableArray *observed=[NSMutableArray new];for(NSDictionary *m in large){NSMutableDictionary *copy=[m mutableCopy];if([selected containsObject:m[@"id"]])copy[@"availability"]=@{@"discovery_eligible":@YES,@"checked":@(now)};[observed addObject:copy];}
    NSArray *next=[RWHomeDelivery targets:observed world:@[] older:@[] shows:@[] now:now+900 limit:24];CHECK(next.count==4);for(NSDictionary *m in next)CHECK(![selected containsObject:m[@"id"]]);
    NSDictionary *staleMovie=@{@"id":@"tt123",@"type":@"movie",@"availability":@{@"checked":@0}};
    NSDictionary *fresh=@{@"state":@"candidates",@"checked":@(now),@"quality":@0,@"policy":@34};
    NSArray *(^eligible)(NSArray *,NSDictionary *,NSDictionary *,NSDictionary *,NSDictionary *,NSInteger,double)=^NSArray *(NSArray *items,NSDictionary *obs,NSDictionary *shows,NSDictionary *history,NSDictionary *attempts,NSInteger quality,double time){return [RWHomeDelivery refreshable:items observations:obs shows:shows history:history metadataAttempts:attempts quality:quality now:time];};
    CHECK(!eligible(@[staleMovie],@{@"tt123":fresh},@{},@{},@{},0,now).count);
    CHECK(eligible(@[staleMovie],@{},@{},@{},@{},0,now).count==1);
    CHECK(eligible(@[staleMovie],@{@"tt123":fresh},@{},@{},@{},720,now).count==1);
    CHECK(eligible(@[staleMovie],@{@"tt123":fresh},@{},@{},@{},0,now+21601).count==1);
    NSMutableDictionary *negative=[fresh mutableCopy];negative[@"state"]=@"unknown";
    CHECK(!eligible(@[staleMovie],@{@"tt123":negative},@{},@{},@{},0,now+299).count);
    CHECK(eligible(@[staleMovie],@{@"tt123":negative},@{},@{},@{},0,now+301).count==1);
    negative[@"state"]=@"waiting";CHECK(!eligible(@[staleMovie],@{@"tt123":negative},@{},@{},@{},0,now+301).count);
    CHECK(eligible(@[staleMovie],@{@"tt123":negative},@{},@{},@{},0,now+3601).count==1);
    NSDictionary *series=@{@"id":@"tt456",@"type":@"series"};
    NSDictionary *ep1=@{@"id":@"tt456:1:1",@"season":@1,@"episode":@1,@"released":@"2020-01-01T00:00:00Z"},*ep2=@{@"id":@"tt456:1:2",@"season":@1,@"episode":@2,@"released":@"2020-01-02T00:00:00Z"};
    NSDictionary *show=@{@"id":@"tt456",@"type":@"series",@"videos":@[ep1,ep2]};
    // Newly cached episode metadata must be used even if ranking never finished.
    CHECK(!eligible(@[series],@{@"tt456:1:1":fresh},@{@"tt456":show},@{},@{},0,now).count);
    NSArray *advance=eligible(@[series],@{@"tt456:1:1":fresh},@{@"tt456":show},@{@"tt456:1:1":@{@"completed":@YES}},@{},0,now);
    CHECK(advance.count==1&&[advance[0][@"episodeVideoID"]isEqual:@"tt456:1:2"]);
    NSMutableDictionary *oldTarget=[series mutableCopy];oldTarget[@"episodeVideoID"]=@"tt456:1:1";oldTarget[@"availability"]=@{@"hero_eligible":@YES};
    advance=eligible(@[oldTarget],@{@"tt456:1:1":fresh},@{@"tt456":show},@{@"tt456:1:1":@{@"completed":@YES}},@{},0,now);
    CHECK(advance.count==1&&[advance[0][@"episodeVideoID"]isEqual:@"tt456:1:2"]);
    NSDictionary *explicitEpisode=@{@"id":@"tt456",@"type":@"series",@"episodeVideoID":@"tt456:2:1"};
    CHECK(eligible(@[explicitEpisode],@{@"tt456:1:1":fresh},@{},@{},@{},0,now).count==1);
    CHECK(!eligible(@[explicitEpisode],@{@"tt456:2:1":fresh},@{},@{},@{},0,now).count);
    // Metadata failure cooldown is separate from playback evidence and expires.
    CHECK(!eligible(@[series],@{},@{},@{},@{@"tt456":@(now)},0,now+299).count);
    CHECK(eligible(@[series],@{},@{},@{},@{@"tt456":@(now)},0,now+301).count==1);
    CHECK(eligible(@[series],@{},@{},@{},@{@"tt456":@(now)},0,now-1).count==1);
    // A partial historical index with no safe next episode must request new
    // metadata, not disappear permanently from the refresh candidate set.
    NSDictionary *past=@{@"id":@"tt456",@"type":@"series",@"videos":@[ep1],@"episodeIndexAt":@(now-86401),@"episodeIndexHistorical":@YES};
    NSDictionary *finished=@{@"tt456:1:1":@{@"completed":@YES}};
    NSArray *refresh=eligible(@[oldTarget],@{@"tt456:1:1":fresh},@{@"tt456":past},finished,@{},0,now);
    CHECK(refresh.count==1);if(refresh.count){CHECK(![refresh[0][@"episodeVideoID"]length]);CHECK(![refresh[0][@"availability"][@"discovery_eligible"]boolValue]);CHECK(![refresh[0][@"availability"][@"hero_eligible"]boolValue]);}
    CHECK(!eligible(@[series],@{},@{@"tt456":past},finished,@{@"tt456":@(now-299)},0,now).count);
    CHECK(eligible(@[series],@{},@{@"tt456":past},finished,@{@"tt456":@(now-301)},0,now).count==1);
    NSDictionary *unknownHistory=@{@"tt456:3:1":@{@"position":@90}};
    CHECK(eligible(@[series],@{},@{@"tt456":past},unknownHistory,@{},0,now).count==1);
    CHECK(!eligible(@[series],@{@"tt456:1:1":fresh},@{@"tt456":past},@{},@{},0,now).count);
    CHECK(eligible(@[NSNull.null],@{},@{},@{},@{},0,now).count==0);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
