#import "../RWUpcomingSelection.h"
#import "../RWAvailability.h"
static int checks,failures;
#define C(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL%d %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSDictionary *Title(int i){return @{@"id":[NSString stringWithFormat:@"tt%07d",i],@"name":@"Family story",@"type":@"movie",@"released":@"2030-01-01",@"releaseInfo":@"2030",@"genres":@[@"Family"],@"discovery":@{@"primaryLanguage":@"en",@"languageSource":@"fixture",@"industry":@"other"}};}
int main(){@autoreleasepool{
 double now=1792922400;NSMutableDictionary *profile=[@{@"maxAge":@(-1),@"hidden":@[],@"history":@{},@"discoveryPreferences":@{@"recommendationAudience":@"all_ages"},@"sourceAvailability":@{}}mutableCopy];NSMutableDictionary *snapshot=[@{@"profile":profile,@"groups":@[],@"family":@[],@"metadata":@{},@"ageRatings":@{},@"shows":@{},@"quality":@0,@"offline":@{}}mutableCopy];
 NSMutableArray *catalog=[NSMutableArray new];for(int i=10000;i<10600;i++){NSMutableDictionary *m=[Title(i)mutableCopy];m[@"type"]=@"series";m[@"released"]=@"2020-01-01";m[@"releaseInfo"]=@"2020";m[@"scheduledEpisode"]=@{@"id":[m[@"id"]stringByAppendingString:@":1:2"],@"season":@1,@"episode":@2,@"airAt":@(now+10000+i)};[catalog addObject:m];}
 [catalog addObject:Title(500)];[catalog addObject:Title(500)];
 NSArray *items=[RWUpcomingSelection items:catalog mode:@"Coming soon" snapshot:snapshot ratings:@{} following:@{} watching:@{} now:now];C(items.count==601);C([items.lastObject[@"id"]isEqual:@"tt0000500"]);C([items.firstObject[@"id"]isEqual:@"tt0010000"]);
 profile[@"hidden"]=@[@"tt0010000"];items=[RWUpcomingSelection items:catalog mode:@"Coming soon" snapshot:snapshot ratings:@{} following:@{} watching:@{} now:now];C(items.count==600);C(![[items valueForKey:@"id"]containsObject:@"tt0010000"]);
 profile[@"maxAge"]=@7;items=[RWUpcomingSelection items:catalog mode:@"Coming soon" snapshot:snapshot ratings:@{} following:@{} watching:@{} now:now];C(items.count==0);
 snapshot[@"ageRatings"]=@{@"cache":@{@"tt0000500":@{@"minimumAge":@6}}};items=[RWUpcomingSelection items:catalog mode:@"Coming soon" snapshot:snapshot ratings:@{} following:@{} watching:@{} now:now];C(items.count==1);
 profile[@"maxAge"]=@(-1);NSMutableDictionary *old=[Title(700)mutableCopy];old[@"released"]=@"2000-01-01";old[@"releaseInfo"]=@"2000";
 profile[@"sourceAvailability"]=@{old[@"id"]:[RWAvailability observeAnalysis:@{@"compatible":@0,@"listings":@0} complete:YES error:nil quality:0 now:now]};
 items=[RWUpcomingSelection items:@[old,Title(500)] mode:@"Waiting" snapshot:snapshot ratings:@{} following:@{} watching:@{} now:now];C(items.count==1&&[items[0][@"id"]isEqual:old[@"id"]]);
 items=[RWUpcomingSelection items:@[] mode:@"Following" snapshot:snapshot ratings:@{} following:@{old[@"id"]:@{@"meta":old}} watching:@{@"tt0000500":@{@"meta":Title(500)}} now:now];C(items.count==2);
 // A large unrelated schedule must not require episode preparation for two
 // followed titles. Waiting still uses exact episode availability after the
 // cheap title-identity filter, rather than trusting this candidate list.
 NSArray *candidates=[RWUpcomingSelection candidates:catalog mode:@"Following" snapshot:snapshot following:@{old[@"id"]:@{@"meta":old}} watching:@{}];C(candidates.count==1);C([candidates[0][@"id"]isEqual:old[@"id"]]);
 candidates=[RWUpcomingSelection candidates:catalog mode:@"Following" snapshot:snapshot following:@{} watching:@{}];C(candidates.count==0);
 candidates=[RWUpcomingSelection candidates:[catalog arrayByAddingObject:old] mode:@"Waiting" snapshot:snapshot following:@{} watching:@{}];C(candidates.count==1);
 NSMutableDictionary *series=[catalog[0]mutableCopy];series[@"episodeVideoID"]=[series[@"id"]stringByAppendingString:@":1:1"];series[@"scheduledEpisode"]=nil;
 profile[@"sourceAvailability"]=@{series[@"episodeVideoID"]:[RWAvailability observeAnalysis:@{@"compatible":@0,@"listings":@0} complete:YES error:nil quality:0 now:now]};
 candidates=[RWUpcomingSelection candidates:@[series,old] mode:@"Waiting" snapshot:snapshot following:@{} watching:@{}];C(candidates.count==1&&[candidates[0][@"id"]isEqual:series[@"id"]]);
 items=[RWUpcomingSelection items:@[series,old] mode:@"Waiting" snapshot:snapshot ratings:@{} following:@{} watching:@{} now:now];C(items.count==1);
 items=[RWUpcomingSelection items:@[series,old] mode:@"Waiting" snapshot:snapshot ratings:@{} following:@{} watching:@{} now:now+3700];C(items.count==0);
 // Preserve authoritative scheduled language when metadata has no language.
 snapshot[@"metadata"]=@{@"tt0010000":@{@"industry":@"unknown"}};profile[@"hidden"]=@[];items=[RWUpcomingSelection items:@[catalog[0]] mode:@"Coming soon" snapshot:snapshot ratings:@{} following:@{} watching:@{} now:now];C(items.count==1);C([items[0][@"discovery"][@"primaryLanguage"]isEqual:@"en"]);C([items[0][@"discovery"][@"industry"]isEqual:@"television"]);
 profile[@"discoveryPreferences"]=@{};C(![RWUpcomingSelection items:@[Title(500)] mode:@"Coming soon" snapshot:snapshot ratings:@{} following:@{} watching:@{} now:now].count);
 C([RWUpcomingSelection items:@[] mode:@"Following" snapshot:snapshot ratings:@{} following:@{} watching:@{@"tt0000500":@{@"meta":Title(500)}} now:now].count==1);
 profile[@"maxAge"]=@7;C([RWUpcomingSelection items:@[Title(500)] mode:@"Coming soon" snapshot:snapshot ratings:@{} following:@{} watching:@{} now:now].count==1);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
