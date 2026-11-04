#import "../RWDiscoverySnapshot.h"
#import "../RWRecommendationPolicy.h"
#import "../RWRecommendationSignals.h"
static NSMutableDictionary *Title(NSString *key){return [@{@"id":key,@"type":@"movie",@"name":key,@"genres":@[@"Family"],@"ageAllowed":@YES,@"description":@"Unneeded long description",@"videos":@[@{}],@"discovery":@{@"themes":@[@{@"id":@"Q12"}]}}mutableCopy];}
static NSDictionary *Selection(NSArray *signals){NSMutableDictionary *out=[NSMutableDictionary new];for(NSDictionary *s in signals)out[s[@"meta"][@"id"]]=@[s[@"kind"],s[@"weight"],s[@"at"]];return out;}
int main(){@autoreleasepool{int checks=0,failures=0;double now=1792620400;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    NSMutableArray *likes=[NSMutableArray new],*saves=[NSMutableArray new],*pool=[NSMutableArray new];NSMutableDictionary *history=[NSMutableDictionary new],*metadata=[NSMutableDictionary new];
    for(int i=0;i<1000;i++){NSString *key=[NSString stringWithFormat:@"history-%04d",i];history[key]=@{@"meta":Title(key),@"source":@{@"opaque":@"not needed for ranking"},@"watchSignalVersion":@1,@"watchSeconds":@900,@"position":@900,@"duration":@1000,@"completed":@YES,@"updated":@(now-i)};}
    for(int i=0;i<30;i++){NSMutableDictionary *m=Title([NSString stringWithFormat:@"like-%02d",i]);m[@"discoveryLikedAt"]=@(now-30+i);[likes addObject:m];}
    for(int i=0;i<20;i++){NSMutableDictionary *m=Title([NSString stringWithFormat:@"save-%02d",i]);m[@"discoverySavedAt"]=@(now-i);[saves addObject:m];}
    for(int i=0;i<600;i++)[pool addObject:Title([NSString stringWithFormat:@"pool-%03d",i])];
    history[@"short-start"]=@{@"meta":Title(@"short-start"),@"position":@20,@"watchSeconds":@0,@"duration":@1000,@"completed":@NO};
    history[@"seek-only"]=@{@"meta":Title(@"seek-only"),@"position":@999,@"watchSeconds":@0,@"duration":@1000,@"completed":@YES};
    NSMutableDictionary *profile=[@{@"maxAge":@(-1),@"liked":likes,@"saved":saves,@"history":history,@"hidden":@[],@"discoveryPreferences":@{@"recommendationAudience":@"all_ages"}}mutableCopy];
    NSMutableDictionary *input=[@{@"profile":profile,@"quality":@0,@"groups":@[pool],@"metadata":metadata}mutableCopy];
    NSData *before=[NSJSONSerialization dataWithJSONObject:input options:NSJSONWritingSortedKeys error:nil];
    NSArray *ids=[RWDiscoverySnapshot ratingIDs:pool snapshot:input includeSignals:YES now:now];CHECK(ids.count==525);CHECK([NSSet setWithArray:ids].count==525);CHECK([ids containsObject:@"history-0000"]);CHECK(![ids containsObject:@"history-0999"]);
    CHECK([RWDiscoverySnapshot ratingIDs:pool snapshot:input includeSignals:NO now:now].count==501);
    NSDictionary *prepared=[RWDiscoverySnapshot prepare:@[pool[0]] snapshot:input ratings:@{} now:now],*compact=prepared[@"profile"];
    CHECK([compact[@"liked"]count]==12&&[compact[@"saved"]count]==6&&[compact[@"history"]count]==6);
    CHECK([Selection([RWRecommendationSignals select:profile now:now allows:nil])isEqual:Selection([RWRecommendationSignals select:compact now:now allows:nil])]);
    CHECK([compact[@"rankingExcludedIDs"]containsObject:@"like-00"]);CHECK([compact[@"rankingExcludedIDs"]containsObject:@"history-0999"]);CHECK(![compact[@"rankingExcludedIDs"]containsObject:@"short-start"]);
    CHECK([[RWRecommendationPolicy homeExcludedIDsForProfile:compact]isEqual:[RWRecommendationPolicy homeExcludedIDsForProfile:profile]]);
    CHECK(![[RWRecommendationPolicy homeExcludedIDsForProfile:compact]containsObject:@"seek-only"]);
    CHECK(!compact[@"history"][@"history-0000"][@"source"]);CHECK(!compact[@"history"][@"history-0000"][@"meta"][@"videos"]);CHECK(!compact[@"liked"][0][@"description"]);
    CHECK([[NSJSONSerialization dataWithJSONObject:input options:NSJSONWritingSortedKeys error:nil]isEqual:before]);
    NSDictionary *rating=@{@"rating":@8.3,@"votes":@10000};NSDictionary *enriched=[RWDiscoverySnapshot prepareItems:@[pool[0]] snapshot:input ratings:@{pool[0][@"id"]:rating} now:now];CHECK(!enriched[@"profile"]);CHECK([enriched[@"items"][0][@"imdbRating"]isEqual:@"8.3"]);
    CHECK([[RWDiscoverySnapshot prepareItems:pool snapshot:input ratings:@{} now:now][@"items"]count]==501);
    CHECK([RWDiscoverySnapshot matches:input profile:profile quality:0]);CHECK(![RWDiscoverySnapshot matches:input profile:profile quality:720]);
    NSMutableDictionary *changed=[profile mutableCopy];changed[@"maxAge"]=@7;CHECK(![RWDiscoverySnapshot matches:input profile:changed quality:0]);changed=[profile mutableCopy];changed[@"hidden"]=@[@"pool-001"];CHECK(![RWDiscoverySnapshot matches:input profile:changed quality:0]);changed=[profile mutableCopy];changed[@"discoveryPreferences"]=@{@"worldCinema":@NO};CHECK(![RWDiscoverySnapshot matches:input profile:changed quality:0]);
    // A selected item may disappear from Kids after ratings change. Unknown
    // ratings never become safe merely because the feedback record says so.
    changed=[profile mutableCopy];changed[@"maxAge"]=@7;input[@"profile"]=changed;CHECK(![[RWDiscoverySnapshot prepare:@[pool[0]] snapshot:input ratings:@{} now:now][@"profile"][@"liked"]count]);
    input[@"ageRatings"]=@{@"cache":@{@"like-29":@{@"minimumAge":@0},@"history-0000":@{@"minimumAge":@0}},@"publishers":@{@"history-0000":@{@"minimumAge":@12}}};
    NSDictionary *kid=[RWDiscoverySnapshot prepare:@[] snapshot:input ratings:@{} now:now][@"profile"];CHECK([kid[@"liked"]count]==1);CHECK(![kid[@"history"]count]);CHECK(![kid[@"rankingExcludedIDs"]containsObject:@"history-0000"]);
    // Original-context exclusions survive even when old feedback no longer
    // occupies one of the selected metadata slots.
    NSMutableDictionary *oldLike=Title(@"like-00"),*oldWatch=Title(@"history-0999"),*newTitle=Title(@"new-title");for(NSMutableDictionary *m in @[oldLike,oldWatch,newTitle]){m[@"discovery"]=@{@"primaryLanguage":@"en",@"languageSource":@"fixture",@"industry":@"other"};m[@"availability"]=@{@"discovery_eligible":@YES};}
    NSArray *rank=[RWRecommendationPolicy rank:@[oldLike,oldWatch,newTitle] current:nil profile:compact world:NO requireAvailability:YES now:now limit:12];CHECK(rank.count==1&&[rank[0][@"id"]isEqual:@"new-title"]);
    printf("{\"checks\":%d,\"failures\":%d,\"history_records\":%lu,\"prepared_history_records\":%lu}\n",checks,failures,(unsigned long)history.count,(unsigned long)[compact[@"history"]count]);return failures?1:0;
}}
