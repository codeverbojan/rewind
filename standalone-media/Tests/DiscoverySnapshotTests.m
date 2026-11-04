#import "../RWDiscoverySnapshot.h"
#import "../RWAvailability.h"
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    double now=1792620400;
    NSDictionary *film=@{@"id":@"tt1",@"type":@"movie",@"genres":@[@"Family"],@"name":@"Film",@"released":@"2000-01-01"};
    NSDictionary *show=@{@"id":@"tt2",@"type":@"series",@"genres":@[@"Family"],@"name":@"Show",@"videos":@[@{@"id":@"tt2:1:1",@"season":@1,@"episode":@1,@"released":@"2000-01-01"},@{@"id":@"tt2:1:2",@"season":@1,@"episode":@2,@"released":@"2000-01-08"}]};
    NSDictionary *ready=[RWAvailability ready:@{} sourceKey:@"fixture" quality:0 now:now-5];
    NSDictionary *history=@{@"tt2:1:1":@{@"meta":show,@"completed":@YES,@"position":@100,@"duration":@100}};
    NSMutableDictionary *profile=[@{@"maxAge":@(-1),@"history":history,@"saved":@[film],@"liked":@[],@"hidden":@[],@"sourceAvailability":@{@"tt1":ready,@"tt2:1:1":ready}}mutableCopy];
    NSMutableDictionary *input=[@{@"profile":profile,@"groups":@[@[film,show,film]],@"family":@[film,show],@"shows":@{@"tt2":show},@"metadata":@{@"tt1":@{@"primaryLanguage":@"en"}},@"quality":@0,@"ageRatings":@{}}mutableCopy];
    NSArray *pool=[RWDiscoverySnapshot pool:input];CHECK(pool.count==2);CHECK(!pool[1][@"videos"]);
    NSData *before=[NSJSONSerialization dataWithJSONObject:input options:NSJSONWritingSortedKeys error:nil];
    __block NSDictionary *result;dispatch_semaphore_t finished=dispatch_semaphore_create(0);dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{result=[RWDiscoverySnapshot prepare:pool snapshot:input ratings:@{@"tt1":@{@"rating":@8.1,@"votes":@12000}} now:now];dispatch_semaphore_signal(finished);});dispatch_semaphore_wait(finished,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC));
    CHECK([result[@"off_main"]boolValue]);CHECK([result[@"items"]count]==2);
    NSDictionary *a=result[@"items"][0],*b=result[@"items"][1];
    CHECK([a[@"imdbRating"]isEqual:@"8.1"]);CHECK([a[@"discovery"][@"primaryLanguage"]isEqual:@"en"]);CHECK([a[@"availability"][@"hero_eligible"]boolValue]);
    CHECK([b[@"episodeVideoID"]isEqual:@"tt2:1:2"]);CHECK(![b[@"availability"][@"hero_eligible"]boolValue]); // Episode one evidence cannot qualify episode two.
    CHECK(!result[@"profile"][@"history"][@"tt2:1:1"][@"meta"][@"videos"]);
    CHECK([before isEqual:[NSJSONSerialization dataWithJSONObject:input options:NSJSONWritingSortedKeys error:nil]]);
    // A stripped persisted movie card must use real series identity and episode evidence.
    NSMutableDictionary *mislabelled=[show mutableCopy];mislabelled[@"type"]=@"movie";[mislabelled removeObjectForKey:@"videos"];
    profile[@"sourceAvailability"]=@{@"tt2":ready,@"tt2:1:1":ready};
    NSDictionary *corrected=[RWDiscoverySnapshot prepareItems:@[mislabelled] snapshot:input ratings:@{} now:now][@"items"][0];
    CHECK([corrected[@"type"]isEqual:@"series"]);CHECK([corrected[@"episodeVideoID"]isEqual:@"tt2:1:2"]);
    CHECK(![corrected[@"availability"][@"discovery_eligible"]boolValue]);CHECK([mislabelled[@"type"]isEqual:@"movie"]);
    NSMutableDictionary *expiredShow=[show mutableCopy];expiredShow[@"episodeIndexAt"]=@(now-86401);
    input[@"shows"]=@{@"tt2":expiredShow};
    corrected=[RWDiscoverySnapshot prepareItems:@[mislabelled] snapshot:input ratings:@{} now:now][@"items"][0];
    CHECK([corrected[@"type"]isEqual:@"series"]);CHECK(![corrected[@"episodeVideoID"]length]);CHECK(![corrected[@"availability"][@"discovery_eligible"]boolValue]);
    input[@"shows"]=@{@"tt2":show};
    profile[@"sourceAvailability"]=@{@"tt1":ready,@"tt2:1:1":ready};
    NSMutableDictionary *kid=[profile mutableCopy];kid[@"maxAge"]=@7;input[@"profile"]=kid;
    CHECK(![RWDiscoverySnapshot pool:input].count); // Missing rating is never safe for Kids.
    input[@"ageRatings"]=@{@"cache":@{@"tt1":@{@"minimumAge":@0},@"tt2":@{@"minimumAge":@0}},@"publishers":@{@"tt2":@{@"minimumAge":@12}}};
    NSArray *kids=[RWDiscoverySnapshot pool:input];CHECK(kids.count==1&&[kids[0][@"id"]isEqual:@"tt1"]);
    result=[RWDiscoverySnapshot prepare:pool snapshot:input ratings:@{} now:now];CHECK([result[@"items"]count]==1);CHECK(![result[@"profile"][@"history"]count]);
    input[@"profile"]=profile;input[@"offline"]=@{@"tt2:1:2":@{@"quality":@0,@"at":@(now-60)}};input[@"offlineAt"]=@(now-1);
    result=[RWDiscoverySnapshot prepare:pool snapshot:input ratings:@{} now:now];CHECK([result[@"items"][1][@"availability"][@"hero_eligible"]boolValue]);
    input[@"quality"]=@720;result=[RWDiscoverySnapshot prepare:pool snapshot:input ratings:@{} now:now];CHECK(![result[@"items"][1][@"availability"][@"hero_eligible"]boolValue]);
    input[@"quality"]=@0;input[@"offlineAt"]=@(now-121);result=[RWDiscoverySnapshot prepare:pool snapshot:input ratings:@{} now:now];CHECK(![result[@"items"][1][@"availability"][@"hero_eligible"]boolValue]);
    NSMutableArray *many=[NSMutableArray new];for(int i=0;i<600;i++)[many addObject:@{@"id":[NSString stringWithFormat:@"tt%u",100+i],@"type":@"movie"}];input[@"groups"]=@[many];CHECK([RWDiscoverySnapshot pool:input].count==500);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
