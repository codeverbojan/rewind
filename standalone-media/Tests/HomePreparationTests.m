#import "../RWHomePreparation.h"
#import "../RWDiscoveryMetadataPolicy.h"
#include <math.h>
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSDictionary *Clone(NSDictionary *x){return [NSJSONSerialization JSONObjectWithData:[NSJSONSerialization dataWithJSONObject:x options:0 error:nil] options:NSJSONReadingMutableContainers error:nil];}
static NSDictionary *Movie(NSString *key,NSString *language){return @{@"id":key,@"type":@"movie",@"name":key,@"ageAllowed":@YES,@"genres":@[@"Family"],@"imdbRating":@8.4,@"imdbVotes":@50000,@"discovery":@{@"primaryLanguage":language,@"languageSource":@"verified",@"industry":@"other"},@"availability":@{@"discovery_eligible":@YES,@"hero_eligible":@NO}};}
int main(){@autoreleasepool{
    double now=2000000000;NSDictionary *film=Movie(@"film",@"en"),*world=Movie(@"world",@"ko");
    NSDictionary *home=@{@"hero":@{},@"ratingPriors":@[@6.5,@6.5],@"rows":@[@{@"items":@[film,world]}]};
    NSDictionary *input=@{@"quality":@0,@"family":@[],@"shows":@{},@"metadata":@{},@"ageRatings":@{},@"offline":@{},@"offlineAt":@0,@"profile":@{@"maxAge":@(-1),@"discoveryPreferences":@{@"recommendationAudience":@"all_ages"},@"history":@{},@"sourceAvailability":@{}}};
    __block NSDictionary *prepared;dispatch_queue_t worker=dispatch_queue_create("home-preparation-tests",DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t finished=dispatch_semaphore_create(0);dispatch_async(worker,^{prepared=[RWHomePreparation prepare:home snapshot:input ratings:@{} profileID:@"main" now:now];dispatch_semaphore_signal(finished);});
    CHECK(dispatch_semaphore_wait(finished,dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC))==0);
    NSMutableDictionary *correctedInput=[input mutableCopy];correctedInput[@"shows"]=@{@"film":@{@"id":@"film",@"type":@"series",@"videos":@[@{@"id":@"film:1:1",@"season":@1,@"episode":@1}]}};
    RWHomeValidation *correctedValidation=[[RWHomeValidation alloc]initWithRanked:prepared fallback:@{} snapshot:correctedInput ratings:@{} profileID:@"main" priors:home[@"ratingPriors"] now:now];
    CHECK(![correctedValidation entryForTitle:film now:now]);
    CHECK([prepared[@"off_main"]boolValue]);CHECK([prepared[@"entries"]count]==2);CHECK([prepared[@"entries"][@"film"][@"regular"]boolValue]);CHECK(![prepared[@"entries"][@"film"][@"hero"]boolValue]);CHECK([prepared[@"entries"][@"world"][@"world"]boolValue]);CHECK(![prepared[@"entries"][@"world"][@"regular"]boolValue]);CHECK(![prepared[@"entries"][@"film"][@"world"]boolValue]);
    BOOL(^matches)(NSDictionary *,NSDictionary *,NSString *,NSArray *,double)=^BOOL(NSDictionary *scope,NSDictionary *ratings,NSString *profile,NSArray *priors,double time){return [RWHomePreparation matches:prepared snapshot:scope ratings:ratings profileID:profile priors:priors now:time];};
    CHECK(matches(input,@{},@"main",home[@"ratingPriors"],now));CHECK(matches(Clone(input),@{},@"main",home[@"ratingPriors"],now+29));
    CHECK(!matches(input,@{},@"main",home[@"ratingPriors"],now+300));CHECK(!matches(input,@{},@"main",home[@"ratingPriors"],now-1));CHECK(!matches(input,@{},@"kids",home[@"ratingPriors"],now));CHECK(!matches(input,@{@"film":@8.1},@"main",home[@"ratingPriors"],now));CHECK(!matches(input,@{},@"main",@[@7,@6.5],now));
    for(NSString *key in @[@"quality",@"family",@"metadata",@"offline"]){NSMutableDictionary *changed=(id)Clone(input);changed[key]=[key isEqual:@"quality"]?@720:[key isEqual:@"offlineAt"]?@(now):[key isEqual:@"family"]?@[film]:@{@"film":@1};CHECK(!matches(changed,@{},@"main",home[@"ratingPriors"],now));}
    for(NSString *key in @[@"maxAge",@"discoveryPreferences",@"sourceAvailability"]){NSMutableDictionary *changed=(id)Clone(input);changed[@"profile"][key]=[key isEqual:@"maxAge"]?@7:@{@"film":@{@"checked":@(now)}};CHECK(!matches(changed,@{},@"main",home[@"ratingPriors"],now));}
    NSMutableDictionary *exposure=(id)Clone(input);exposure[@"profile"][@"discoveryExposures"]=@{@"film":@{@"count":@1}};exposure[@"profile"][@"liked"]=@[film];exposure[@"profile"][@"hidden"]=@[@"film"];CHECK(matches(exposure,@{},@"main",home[@"ratingPriors"],now)); // These remain live owner-side exclusions.
    for(NSArray *boundary in @[@[@"ready_at",@(now-299),@1],@[@"checked",@(now-86399),@1],@[@"checked",@(now+2),@2],@[@"unready_at",@(now-86397),@3]]){
        NSMutableDictionary *scope=(id)Clone(input);scope[@"profile"][@"sourceAvailability"]=@{@"film":@{@"state":@"candidates",boundary[0]:boundary[1]}};
        NSDictionary *cache=[RWHomePreparation prepare:home snapshot:scope ratings:@{} profileID:@"main" now:now];double end=now+[boundary[2]doubleValue];CHECK([cache[@"validUntil"]doubleValue]==end);CHECK(![RWHomePreparation matches:cache snapshot:scope ratings:@{} profileID:@"main" priors:home[@"ratingPriors"] now:end]);
    }
    NSMutableDictionary *offline=(id)Clone(input);offline[@"offlineAt"]=@(now-119);offline[@"offline"]=@{@"film":@{@"quality":@0,@"at":@(now-1)}};CHECK([[RWHomePreparation prepare:home snapshot:offline ratings:@{} profileID:@"main" now:now][@"validUntil"]doubleValue]==now+1);
    double midnight=(floor(now/86400)+1)*86400;CHECK([[RWHomePreparation prepare:home snapshot:input ratings:@{} profileID:@"main" now:midnight-1][@"validUntil"]doubleValue]==midnight);
    NSDictionary *prefs=[RWDiscoveryMetadataPolicy preferences:@{@"recommendationAudience":@"all_ages"}];
    CHECK(![RWHomePreparation allows:film preferences:@{} restricted:NO world:NO hero:NO priors:@[]]);
    CHECK([RWHomePreparation allows:film preferences:prefs restricted:NO world:NO hero:NO priors:@[]]);
    CHECK([RWHomePreparation allows:film preferences:@{} restricted:YES world:NO hero:NO priors:@[]]);
    NSMutableDictionary *adultOnly=(id)Clone(input);adultOnly[@"profile"][@"discoveryPreferences"]=@{};CHECK(!matches(adultOnly,@{},@"main",home[@"ratingPriors"],now));NSMutableDictionary *bad=[world mutableCopy];bad[@"imdbRating"]=NSNull.null;CHECK(![RWHomePreparation allows:bad preferences:prefs restricted:NO world:YES hero:NO priors:@[]]);bad[@"imdbRating"]=@8.4;bad[@"imdbVotes"]=@100;CHECK(![RWHomePreparation allows:bad preferences:prefs restricted:NO world:YES hero:NO priors:@[]]);
    NSMutableDictionary *future=[film mutableCopy];future[@"availability"]=@{@"discovery_eligible":@NO,@"hero_eligible":@NO};CHECK(![RWHomePreparation allows:future preferences:prefs restricted:NO world:NO hero:NO priors:@[]]);CHECK([RWHomePreparation allows:world preferences:prefs restricted:YES world:NO hero:NO priors:@[]]);
    // Unrelated updates keep both cards; a changed title loses only its own entry.
    NSMutableDictionary *unrelated=(id)Clone(input);unrelated[@"metadata"]=@{@"elsewhere":@{@"name":@"New"}};unrelated[@"profile"][@"sourceAvailability"]=@{@"elsewhere":@{@"checked":@(now)}};unrelated[@"profile"][@"history"]=@{@"elsewhere:1:1":@{@"completed":@YES}};
    CHECK(matches(unrelated,@{@"elsewhere":@8},@"main",home[@"ratingPriors"],now));CHECK(matches(input,@{},@"main",home[@"ratingPriors"],now+31));
    NSMutableDictionary *one=(id)Clone(input);one[@"metadata"]=@{@"film":@{@"name":@"Updated"}};NSDictionary *partial=[RWHomePreparation usable:prepared snapshot:one ratings:@{} profileID:@"main" priors:home[@"ratingPriors"] now:now];CHECK([partial[@"entries"]count]==1&&partial[@"entries"][@"world"]&&!partial[@"entries"][@"film"]);
    one=(id)Clone(input);one[@"ageRatings"]=@{@"cache":@{@"film":@{@"minimumAge":@12}}};CHECK(!matches(one,@{},@"main",home[@"ratingPriors"],now));
    NSMutableDictionary *series=[Movie(@"show",@"en")mutableCopy];series[@"type"]=@"series";series[@"episodeVideoID"]=@"show:1:1";NSDictionary *seriesHome=@{@"ratingPriors":home[@"ratingPriors"],@"rows":@[@{@"items":@[film,series]}]};NSDictionary *seriesPrepared=[RWHomePreparation prepare:seriesHome snapshot:input ratings:@{} profileID:@"main" now:now];
    partial=[RWHomePreparation usable:seriesPrepared snapshot:input ratings:@{} profileID:@"main" priors:home[@"ratingPriors"] now:now+30];CHECK([partial[@"entries"]count]==1&&partial[@"entries"][@"film"]);
    for(NSString *kind in @[@"history",@"sourceAvailability",@"shows"]){NSMutableDictionary *changed=(id)Clone(input);if([kind isEqual:@"shows"])changed[@"shows"]=@{@"show":@{@"videos":@[]}};else changed[@"profile"][kind]=@{@"show:1:1":@{@"completed":@YES}};partial=[RWHomePreparation usable:seriesPrepared snapshot:changed ratings:@{} profileID:@"main" priors:home[@"ratingPriors"] now:now];CHECK([partial[@"entries"]count]==1&&partial[@"entries"][@"film"]);}
    NSMutableArray *rows=[NSMutableArray new];for(int r=0;r<20;r++){NSMutableArray *items=[NSMutableArray new];for(int i=0;i<20;i++)[items addObject:Movie([NSString stringWithFormat:@"%d:%d",r,i],@"en")];[rows addObject:@{@"items":items}];}NSDictionary *bounded=[RWHomePreparation prepare:@{@"hero":film,@"rows":rows} snapshot:input ratings:@{} profileID:@"main" now:now];CHECK([bounded[@"entries"]count]==145);
    NSMutableDictionary *low=[film mutableCopy];low[@"imdbRating"]=@5.5;low[@"availability"]=@{@"discovery_eligible":@YES,@"hero_eligible":@YES};CHECK(![RWHomePreparation allows:low preferences:prefs restricted:NO world:NO hero:NO priors:@[]]);CHECK(![RWHomePreparation allows:low preferences:prefs restricted:NO world:NO hero:YES priors:@[]]);low[@"imdbRating"]=@6;CHECK([RWHomePreparation allows:low preferences:prefs restricted:NO world:NO hero:NO priors:@[]]);
    // Real179World seed: Cave of the Yellow Dog,7.5/3844 votes. The
    // catalog prior7.5 qualifies it; falling back to6.5 rejects the same card.
    NSMutableDictionary *cave=[Movie(@"tt0432325",@"mn")mutableCopy];cave[@"imdbRating"]=@7.5;cave[@"imdbVotes"]=@3844;
    CHECK([RWHomePreparation allows:cave preferences:prefs restricted:YES world:YES hero:NO priors:@[@7.5,@7.5]]);
    CHECK(![RWHomePreparation allows:cave preferences:prefs restricted:YES world:YES hero:NO priors:nil]);
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
