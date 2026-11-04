#import "../RWRecommendationPolicy.h"
#import "../RWHomeDelivery.h"
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSMutableDictionary *Title(NSString *key,NSString *type){return [@{@"id":key,@"name":key,@"type":type,@"releaseInfo":@"2000",@"imdbRating":@8,@"imdbVotes":@100000,@"genres":@[@"Crime",@"Thriller"],@"discovery":@{@"primaryLanguage":@"en",@"languageSource":@"fixture",@"industry":@"other"}}mutableCopy];}
int main(){@autoreleasepool{
 double now=1792791240;NSDictionary *profile=@{@"maxAge":@(-1)};NSMutableDictionary *movie=Title(@"tt1",@"movie"),*show=Title(@"tt2",@"series"),*anchor=Title(@"tt3",@"movie");
 NSArray *(^related)(NSDictionary *)=^NSArray *(NSDictionary *current){return [RWRecommendationPolicy rank:@[movie,show] current:current profile:profile world:NO requireAvailability:NO now:now limit:12];};
 CHECK(related(anchor).count==1&&[related(anchor)[0][@"type"]isEqual:@"movie"]);
 anchor[@"type"]=@"series";CHECK(related(anchor).count==1&&[related(anchor)[0][@"type"]isEqual:@"series"]);
 anchor[@"genres"]=@[];CHECK(!related(anchor).count);CHECK([RWRecommendationPolicy rank:@[movie,show] current:nil profile:profile world:NO requireAvailability:NO now:now limit:12].count==2);
 anchor[@"genres"]=@[@"Drama"];movie[@"genres"]=@[@"Drama"];show[@"genres"]=@[@"Drama"];CHECK(!related(anchor).count);
 anchor[@"genres"]=@[];anchor[@"discovery"]=@{@"directors":@[@{@"id":@"Q123"}]};show[@"discovery"]=anchor[@"discovery"];show[@"discovery"]=@{@"primaryLanguage":@"en",@"languageSource":@"fixture",@"industry":@"other",@"directors":@[@{@"id":@"Q123"}]};CHECK(related(anchor).count==1);
 NSMutableDictionary *low=Title(@"tt4",@"movie"),*future=Title(@"tt5",@"movie"),*hidden=Title(@"tt6",@"movie"),*continueTitle=Title(@"tt7",@"movie"),*liked=Title(@"tt8",@"movie");low[@"imdbRating"]=@5.9;future[@"releaseInfo"]=@"2199";
 NSDictionary *context=@{@"maxAge":@(-1),@"hidden":@[@"tt6"],@"liked":@[liked],@"history":@{@"tt7":@{@"meta":continueTitle,@"position":@30,@"duration":@3000}}};NSArray *all=@[low,future,hidden,continueTitle,liked,movie];
#ifdef RW_BASELINE
 NSArray *candidates=all;
#else
 NSArray *candidates=[RWRecommendationPolicy homeRefreshCandidates:all profile:context now:now];
#endif
 NSArray *ranked=[RWRecommendationPolicy rank:candidates current:nil profile:context world:NO requireAvailability:NO now:now limit:40];CHECK(ranked.count==1&&[ranked[0][@"id"]isEqual:@"tt1"]);
 NSArray *plain=@[Title(@"tt10",@"movie"),Title(@"tt11",@"movie"),Title(@"tt12",@"movie"),Title(@"tt13",@"movie"),Title(@"tt14",@"movie"),Title(@"tt15",@"movie")];NSMutableDictionary *obs=[NSMutableDictionary new];
 for(NSString *key in @[@"tt14",@"tt15"])obs[key]=@{@"state":@"candidates",@"policy":@34,@"quality":@0,@"checked":@(now-90000)};
 NSArray *(^refresh)(NSArray *,NSDictionary *,NSInteger)=^NSArray *(NSArray *items,NSDictionary *observations,NSInteger quality){return [RWHomeDelivery refreshable:items observations:observations shows:@{} history:@{} metadataAttempts:@{} quality:quality now:now];};
 NSArray *prepared=refresh(plain,obs,0);CHECK(prepared.count==6);CHECK([prepared[4][@"homeRecoverableListing"]boolValue]&&![prepared[4][@"availability"][@"discovery_eligible"]boolValue]&&![prepared[4][@"availability"][@"hero_eligible"]boolValue]);
 NSArray *(^select)(NSArray *,NSUInteger)=^NSArray *(NSArray *items,NSUInteger limit){return [RWHomeDelivery targets:items world:@[] older:@[] shows:@[] now:now limit:limit];};
 NSArray *selected=select(prepared,4);CHECK(selected.count==4);CHECK([[selected valueForKey:@"id"]isEqual:@[@"tt14",@"tt15",@"tt10",@"tt11"]]);CHECK([[NSSet setWithArray:[selected valueForKey:@"id"]]count]==4);
 CHECK(select(prepared,0).count==0);CHECK(select(prepared,1).count==1&&[select(prepared,1)[0][@"id"]isEqual:@"tt14"]);CHECK(select(prepared,100).count==4);
 CHECK(![RWHomeDelivery titleMetadata:prepared[4]][@"homeRecoverableListing"]);
 NSArray *combined=[RWHomeDelivery targets:selected includingWatches:@[plain[1],plain[2]]];CHECK([[combined valueForKey:@"id"]isEqual:@[@"tt11",@"tt12",@"tt14",@"tt15"]]);
 // No eligibility fabricated from expired or differently scoped observations.
 for(NSDictionary *change in @[@{@"checked":@(now-8*86400)},@{@"checked":@(now+1)},@{@"policy":@33},@{@"quality":@720},@{@"state":@"waiting"},@{@"state":@"unknown"}]){NSMutableDictionary *entry=[obs[@"tt14"]mutableCopy];[entry addEntriesFromDictionary:change];NSArray *items=refresh(@[plain[4]],@{@"tt14":entry},0);CHECK(!items.count||![items[0][@"homeRecoverableListing"]boolValue]);}
 NSMutableDictionary *failed=[obs[@"tt14"]mutableCopy];failed[@"unready_at"]=@(now-60);CHECK(!refresh(@[plain[4]],@{@"tt14":failed},0).count);
 NSMutableDictionary *fresh=[obs[@"tt14"]mutableCopy];fresh[@"checked"]=@(now);NSArray *updated=refresh(prepared,@{@"tt14":fresh,@"tt15":fresh},0);CHECK(updated.count==4);CHECK(![[select(updated,4)valueForKey:@"id"]containsObject:@"tt14"]);
 NSMutableDictionary *episode=Title(@"tt20",@"series");episode[@"episodeVideoID"]=@"tt20:2:1";CHECK(![refresh(@[episode],@{@"tt20:1:1":obs[@"tt14"]},0)[0][@"homeRecoverableListing"]boolValue]);CHECK([refresh(@[episode],@{@"tt20:2:1":obs[@"tt14"]},0)[0][@"homeRecoverableListing"]boolValue]);
 NSMutableDictionary *allExpired=[NSMutableDictionary new];for(NSDictionary *m in plain)allExpired[m[@"id"]]=obs[@"tt14"];
 NSArray *expired=refresh(plain,allExpired,0);CHECK(select(expired,4).count==4);
 [allExpired removeObjectForKey:@"tt15"];expired=refresh(plain,allExpired,0);CHECK([[select(expired,4)valueForKey:@"id"]isEqual:@[@"tt10",@"tt11",@"tt15",@"tt12"]]);
 CHECK(!plain[4][@"homeRecoverableListing"]&&[obs[@"tt14"][@"checked"]doubleValue]==now-90000);
 // International recovery must not be starved behind two English recoveries
 // and two new English candidates, including when explicit watches take slots.
 NSMutableDictionary *international=Title(@"tt30",@"movie");international[@"discovery"]=@{@"primaryLanguage":@"ja",@"languageSource":@"fixture",@"industry":@"other"};
 NSDictionary *worldRecovered=refresh(@[international],@{@"tt30":obs[@"tt14"]},0).firstObject;
 NSArray *recoveryFirst=@[prepared[4],prepared[5],prepared[0],prepared[1],prepared[2],prepared[3]];
 NSArray *fair=[RWHomeDelivery targets:recoveryFirst world:@[worldRecovered] older:@[prepared[5]] shows:@[] now:now limit:4];
 CHECK([[fair valueForKey:@"id"]isEqual:@[@"tt14",@"tt30",@"tt10",@"tt11"]]);
 NSUInteger recoveryCount=0;for(NSDictionary *m in fair)recoveryCount+=[m[@"homeRecoverableListing"]boolValue];CHECK(recoveryCount==2);
 combined=[RWHomeDelivery targets:fair includingWatches:@[plain[1],plain[3]]];CHECK([[combined valueForKey:@"id"]isEqual:@[@"tt11",@"tt13",@"tt14",@"tt30"]]);
 CHECK(![fair[1][@"availability"][@"discovery_eligible"]boolValue]);
 fair=[RWHomeDelivery targets:recoveryFirst world:@[international] older:@[prepared[5]] shows:@[] now:now limit:4];CHECK([[fair valueForKey:@"id"]isEqual:@[@"tt14",@"tt30",@"tt15",@"tt10"]]);
 CHECK([RWHomeDelivery targets:prepared world:@[international] older:@[] shows:@[] now:now limit:1].count==1);
 // Fresh or recently failed World entries cannot bypass their cooldown.
 NSMutableDictionary *recent=[international mutableCopy];recent[@"availability"]=@{@"checked":@(now),@"discovery_eligible":@YES};
 CHECK(![[[RWHomeDelivery targets:prepared world:@[recent] older:@[] shows:@[] now:now limit:4]valueForKey:@"id"]containsObject:@"tt30"]);
 recent[@"availability"]=@{@"retry_after":@(now+60)};CHECK(![[[RWHomeDelivery targets:prepared world:@[recent] older:@[] shows:@[] now:now limit:4]valueForKey:@"id"]containsObject:@"tt30"]);
 recent[@"id"]=@"tt31";fair=[RWHomeDelivery targets:recoveryFirst world:@[recent,international,international] older:@[] shows:@[] now:now limit:4];CHECK(fair.count==4&&[[NSSet setWithArray:[fair valueForKey:@"id"]]count]==4&&[fair[1][@"id"]isEqual:@"tt30"]);
 printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
