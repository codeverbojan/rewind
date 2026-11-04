#import "../RWHomeDeferredPreparation.h"
#import "../RWHomePreparation.h"
#import "../RWAvailability.h"
#import "../RWDiscoveryEpisodes.h"
#include <math.h>
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSMutableDictionary *Clone(NSDictionary *x){return [NSJSONSerialization JSONObjectWithData:[NSJSONSerialization dataWithJSONObject:x options:0 error:nil] options:NSJSONReadingMutableContainers error:nil];}
static NSDictionary *Film(NSString *key){return @{@"id":key,@"name":key,@"type":@"movie",@"released":@"2020-01-01",@"genres":@[@"Family"],@"discovery":@{@"primaryLanguage":@"en",@"languageSource":@"verified",@"industry":@"other"}};}
int main(){@autoreleasepool{
    double now=1792607000;NSDictionary *a=Film(@"a"),*b=Film(@"b");
    NSDictionary *positive=[RWAvailability observe:@[@{@"filename":@"Film.2020.720p.WEBRip.x264.AAC.mp4"}] complete:YES error:nil now:now];
    NSDictionary *negative=[RWAvailability observe:@[] complete:YES error:nil now:now];
    NSDictionary *home=@{@"hero":a,@"ratingPriors":@[@6.5,@6.5],@"rows":@[@{@"items":@[a,b]}]};
    NSDictionary *input=@{@"quality":@0,@"family":@[],@"shows":@{},@"metadata":@{},@"ageRatings":@{},@"offline":@{},@"offlineAt":@0,@"profile":@{@"maxAge":@(-1),@"discoveryPreferences":@{@"recommendationAudience":@"all_ages"},@"history":@{},@"sourceAvailability":@{@"a":positive,@"b":negative}}};
    NSDictionary *original=Clone(input);__block NSDictionary *prepared;
    dispatch_queue_t queue=dispatch_queue_create("test.home.deferred",DISPATCH_QUEUE_SERIAL);dispatch_semaphore_t done=dispatch_semaphore_create(0);
    dispatch_async(queue,^{prepared=[RWHomeDeferredPreparation prepare:home snapshot:input ratings:@{@"a":@{@"rating":@8.2,@"votes":@5000}} profileID:@"main" now:now];dispatch_semaphore_signal(done);});
    CHECK(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC))==0);CHECK([prepared[@"off_main"]boolValue]);CHECK([original isEqual:input]);
    NSDictionary *entries=prepared[@"entries"];CHECK(entries.count==2);CHECK([entries[@"a"][@"regular"]boolValue]);CHECK(![entries[@"a"][@"hero"]boolValue]);CHECK(![entries[@"b"][@"regular"]boolValue]);CHECK([entries[@"a"][@"meta"][@"imdbRating"]isEqual:@"8.2"]);
    CHECK([RWHomeDeferredPreparation entry:entries[@"a"] matchesTitle:a]);NSMutableDictionary *changed=[a mutableCopy];changed[@"name"]=@"New name";CHECK(![RWHomeDeferredPreparation entry:entries[@"a"] matchesTitle:changed]);changed=[a mutableCopy];changed[@"poster"]=@"https://example.test/new.jpg";CHECK(![RWHomeDeferredPreparation entry:entries[@"a"] matchesTitle:changed]);changed=[a mutableCopy];changed[@"type"]=@"series";CHECK(![RWHomeDeferredPreparation entry:entries[@"a"] matchesTitle:changed]);
    changed=[a mutableCopy];changed[@"videos"]=@[@{@"id":@"irrelevant"}];CHECK([RWHomeDeferredPreparation entry:entries[@"a"] matchesTitle:changed]);CHECK(!entries[@"a"][@"meta"][@"videos"]);
    NSDictionary *ratings=@{@"a":@{@"rating":@8.2,@"votes":@5000}};
    CHECK([RWHomePreparation usable:prepared snapshot:input ratings:ratings profileID:@"main" priors:home[@"ratingPriors"] now:now]);
    CHECK(![RWHomePreparation usable:prepared snapshot:input ratings:ratings profileID:@"kids" priors:home[@"ratingPriors"] now:now]);
    NSMutableDictionary *scope=Clone(input);scope[@"profile"][@"sourceAvailability"][@"a"]=negative;
    NSDictionary *usable=[RWHomePreparation usable:prepared snapshot:scope ratings:ratings profileID:@"main" priors:home[@"ratingPriors"] now:now];CHECK(!usable[@"entries"][@"a"]&&usable[@"entries"][@"b"]);
    // Negative Kids decisions are complete entries, not endless pending cards.
    scope=Clone(input);scope[@"profile"][@"maxAge"]=@7;
    NSDictionary *kids=[RWHomeDeferredPreparation prepare:home snapshot:scope ratings:@{} profileID:@"kids" now:now];CHECK([kids[@"entries"]count]==2);CHECK(![kids[@"entries"][@"a"][@"regular"]boolValue]);CHECK(![kids[@"entries"][@"a"][@"meta"][@"ageAllowed"]boolValue]);
    CHECK([RWHomePreparation usable:kids snapshot:scope ratings:@{} profileID:@"kids" priors:home[@"ratingPriors"] now:now]);
    scope[@"ageRatings"]=@{@"cache":@{@"a":@{@"minimumAge":@0}}};CHECK(![RWHomePreparation usable:kids snapshot:scope ratings:@{} profileID:@"kids" priors:home[@"ratingPriors"] now:now][@"entries"][@"a"]);
    kids=[RWHomeDeferredPreparation prepare:home snapshot:scope ratings:@{} profileID:@"kids" now:now];CHECK([kids[@"entries"][@"a"][@"regular"]boolValue]);CHECK(![kids[@"entries"][@"b"][@"regular"]boolValue]);
    // A series title must reselect the current episode, not reuse a stale hint.
    NSMutableDictionary *series=[a mutableCopy];series[@"type"]=@"series";series[@"episodeVideoID"]=@"a:99:99";
    NSDictionary *show=[RWDiscoveryEpisodes immutableShow:@{@"id":@"a",@"videos":@[@{@"id":@"a:1:1",@"season":@1,@"episode":@1,@"released":@"2020-01-01"},@{@"id":@"a:1:2",@"season":@1,@"episode":@2,@"released":@"2020-01-02"}]}];
    scope=Clone(input);scope[@"shows"]=@{@"a":show};scope[@"profile"][@"sourceAvailability"]=@{@"a:1:1":positive,@"a:1:2":negative};NSDictionary *seriesHome=@{@"rows":@[@{@"items":@[series]}],@"ratingPriors":home[@"ratingPriors"]};
    NSDictionary *sp=[RWHomeDeferredPreparation prepare:seriesHome snapshot:scope ratings:@{} profileID:@"main" now:now];CHECK([sp[@"entries"][@"a"][@"videoID"]isEqual:@"a:1:1"]);CHECK(!sp[@"entries"][@"a"][@"meta"][@"episodeVideoID"]);CHECK([sp[@"entries"][@"a"][@"regular"]boolValue]);
    scope[@"profile"][@"history"]=@{@"a:1:1":@{@"completed":@YES,@"updated":@(now-1),@"position":@100,@"duration":@100,@"meta":series}};
    CHECK(![RWHomePreparation usable:sp snapshot:scope ratings:@{} profileID:@"main" priors:home[@"ratingPriors"] now:now]);
    sp=[RWHomeDeferredPreparation prepare:seriesHome snapshot:scope ratings:@{} profileID:@"main" now:now];CHECK([sp[@"entries"][@"a"][@"videoID"]isEqual:@"a:1:2"]);CHECK(![sp[@"entries"][@"a"][@"regular"]boolValue]);
    // Evicting a full show must invalidate an admitted title, including an
    // offscreen retained entry. Re-preparing cannot reuse a stale episode hint.
    scope=Clone(input);scope[@"shows"]=@{@"a":show};scope[@"profile"][@"sourceAvailability"]=@{@"a:1:1":positive,@"a:1:2":negative};
    sp=[RWHomeDeferredPreparation prepare:seriesHome snapshot:scope ratings:@{} profileID:@"main" now:now];CHECK([sp[@"entries"][@"a"][@"regular"]boolValue]);
    scope[@"shows"]=@{};
    CHECK(![RWHomePreparation usable:sp snapshot:scope ratings:@{} profileID:@"main" priors:home[@"ratingPriors"] now:now+1]);
    NSDictionary *evicted=[RWHomeDeferredPreparation prepare:seriesHome requestedIDs:[NSSet set] previous:sp snapshot:scope ratings:@{} profileID:@"main" now:now+1];CHECK(![evicted[@"entries"]count]);
    evicted=[RWHomeDeferredPreparation prepare:seriesHome snapshot:scope ratings:@{} profileID:@"main" now:now+1];CHECK(![evicted[@"entries"][@"a"][@"regular"]boolValue]);CHECK(![evicted[@"entries"][@"a"][@"videoID"]length]);CHECK([evicted[@"entries"][@"a"][@"meta"][@"availability"][@"state"]isEqual:@"unknown"]);
    scope[@"shows"]=@{@"a":show};scope[@"profile"][@"history"]=@{@"a:1:1":@{@"completed":@YES,@"updated":@(now-1),@"position":@100,@"duration":@100,@"meta":series}};
    CHECK(![RWHomePreparation usable:evicted snapshot:scope ratings:@{} profileID:@"main" priors:home[@"ratingPriors"] now:now+2]);
    NSDictionary *returned=[RWHomeDeferredPreparation prepare:seriesHome snapshot:scope ratings:@{} profileID:@"main" now:now+2];CHECK([returned[@"entries"][@"a"][@"videoID"]isEqual:@"a:1:2"]);CHECK(![returned[@"entries"][@"a"][@"regular"]boolValue]);
    // Bound every job, including all twelve themed rows and old mixed layouts.
    NSMutableArray *rows=[NSMutableArray new];for(int r=0;r<20;r++){NSMutableArray *items=[NSMutableArray new];for(int i=0;i<20;i++)[items addObject:Film([NSString stringWithFormat:@"%d-%d",r,i])];[rows addObject:@{@"items":items}];}
    for(NSNumber *migrated in @[@NO,@YES]){NSDictionary *large=@{@"hero":a,@"rows":rows,@"migratedLayout":migrated};NSDictionary *plan=[RWHomeDeferredPreparation boundedPlan:large];CHECK([plan[@"rows"]count]==(migrated.boolValue?14:12));CHECK([plan[@"rows"][0][@"items"]count]==12);NSDictionary *result=[RWHomeDeferredPreparation prepare:plan snapshot:input ratings:@{} profileID:@"main" now:now];CHECK([result[@"entries"]count]==(migrated.boolValue?169:145));CHECK(result[@"entries"][@"7-11"]);}
    CHECK(![[RWHomeDeferredPreparation prepare:@{} snapshot:input ratings:@{} profileID:@"main" now:now][@"entries"]count]);
    CHECK(![RWHomePreparation usable:prepared snapshot:input ratings:ratings profileID:@"main" priors:home[@"ratingPriors"] now:now+300]);
    // Visible-range preparation must leave unseen titles uncomputed, retain
    // still-valid earlier cards, and never renew their original deadlines.
    NSDictionary *part=[RWHomeDeferredPreparation prepare:home requestedIDs:[NSSet setWithObject:@"a"] previous:nil snapshot:input ratings:ratings profileID:@"main" now:now];
    CHECK([part[@"entries"]count]==1&&part[@"entries"][@"a"]&&!part[@"entries"][@"b"]);CHECK([part[@"requested_entries"]intValue]==1);CHECK([part[@"plan_entries"]intValue]==2);
    NSDictionary *merged=[RWHomeDeferredPreparation prepare:home requestedIDs:[NSSet setWithObject:@"b"] previous:part snapshot:input ratings:ratings profileID:@"main" now:now+1];
    CHECK([merged[@"entries"]count]==2);CHECK([merged[@"retained_entries"]intValue]==1);CHECK([merged[@"requested_entries"]intValue]==1);CHECK(merged[@"entries"][@"a"]==part[@"entries"][@"a"]);CHECK([merged[@"entries"][@"a"][@"validUntil"]isEqual:part[@"entries"][@"a"][@"validUntil"]]);
    CHECK([RWHomePreparation usable:merged snapshot:input ratings:ratings profileID:@"main" priors:home[@"ratingPriors"] now:now+2][@"entries"][@"a"]);
    scope=Clone(input);scope[@"profile"][@"sourceAvailability"][@"a"]=negative;
    NSDictionary *(^subset)(NSDictionary *,NSDictionary *,NSDictionary *,NSString *,double)=^NSDictionary *(NSDictionary *plan,NSDictionary *prior,NSDictionary *context,NSString *profile,double at){return [RWHomeDeferredPreparation prepare:plan requestedIDs:[NSSet setWithObject:@"b"] previous:prior snapshot:context ratings:ratings profileID:profile now:at];};
    CHECK(!subset(home,merged,scope,@"main",now+2)[@"entries"][@"a"]);
    CHECK(!subset(home,merged,input,@"kids",now+2)[@"entries"][@"a"]);
    CHECK(!subset(home,merged,input,@"main",now+301)[@"entries"][@"a"]);
    CHECK(!subset(home,merged,input,@"main",now-1)[@"entries"][@"a"]);
    CHECK(!subset(home,merged,input,@"main",NAN).count);
    NSDictionary *onlyB=@{@"ratingPriors":home[@"ratingPriors"],@"rows":@[@{@"items":@[b]}]};CHECK(!subset(onlyB,merged,input,@"main",now+2)[@"entries"][@"a"]);
    changed=[a mutableCopy];changed[@"poster"]=@"https://example.test/changed.jpg";NSDictionary *changedHome=@{@"hero":changed,@"ratingPriors":home[@"ratingPriors"],@"rows":@[@{@"items":@[changed,b]}]};CHECK(!subset(changedHome,merged,input,@"main",now+2)[@"entries"][@"a"]);
    NSDictionary *none=[RWHomeDeferredPreparation prepare:home requestedIDs:[NSSet set] previous:nil snapshot:input ratings:ratings profileID:@"main" now:now];CHECK(![none[@"entries"]count]);CHECK([none[@"requested_entries"]intValue]==0);
    none=[RWHomeDeferredPreparation prepare:home requestedIDs:[NSSet setWithObject:@"outside-plan"] previous:nil snapshot:input ratings:ratings profileID:@"main" now:now];CHECK(![none[@"entries"]count]);
    scope=Clone(input);scope[@"profile"][@"maxAge"]=@7;
    part=[RWHomeDeferredPreparation prepare:home requestedIDs:[NSSet setWithObject:@"a"] previous:nil snapshot:scope ratings:ratings profileID:@"kids" now:now];CHECK(part[@"entries"][@"a"]&&!part[@"entries"][@"b"]);CHECK(![part[@"entries"][@"a"][@"regular"]boolValue]);
    merged=subset(home,part,scope,@"kids",now+1);CHECK([merged[@"entries"]count]==2&&! [merged[@"entries"][@"a"][@"regular"]boolValue]);
    scope[@"ageRatings"]=@{@"cache":@{@"a":@{@"minimumAge":@0}}};CHECK(!subset(home,merged,scope,@"kids",now+2)[@"entries"][@"a"]);
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
