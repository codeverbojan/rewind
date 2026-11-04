#import "../RWDiscoverySnapshot.h"
#import "../RWDiscoveryMetadataPolicy.h"
#import "../RWRecommendationPolicy.h"
#import "../RWHomePreparation.h"
#import "../RWRatingPolicy.h"
static int checks,failures;
#define C(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL %d %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSString *RWID(NSDictionary *m){return m[@"id"]?:@"";}
@interface TestRatings:NSObject
@property NSDictionary *records;
- (NSDictionary *)rating:(NSString *)key;
@end
@implementation TestRatings
- (NSDictionary *)rating:(NSString *)key{return self.records[key];}
@end
@interface TestMetadata:NSObject
@property NSDictionary *records;
- (NSDictionary *)record:(NSString *)key;
@end
@implementation TestMetadata
- (NSDictionary *)record:(NSString *)key{return self.records[key];}
@end
@interface TestStore:NSObject
@property NSDictionary *profile;
@property NSArray *familyCatalog;
@property TestRatings *ratings;
@property TestMetadata *discoveryMetadata;
- (BOOL)allowed:(NSDictionary *)meta;
@end
@implementation TestStore
#include "KidsAdmissionUnderTest.inc"
@end
static NSMutableDictionary *Title(NSString *key,NSArray *genres){return [@{@"id":key,@"name":key,@"type":@"series",@"genres":genres,@"imdbRating":@8,@"imdbVotes":@20000,@"releaseInfo":@"2020",@"ageAllowed":@YES,@"availability":@{@"discovery_eligible":@YES},@"discovery":@{@"primaryLanguage":@"en",@"languageSource":@"fixture"}}mutableCopy];}
int main(){@autoreleasepool{
 TestStore *s=[TestStore new];s.ratings=[TestRatings new];s.discoveryMetadata=[TestMetadata new];
 NSDictionary *frasier=Title(@"tt0106004",@[@"Comedy"]),*bluey=Title(@"tt7678620",@[@"Animation",@"Family"]),*adult=Title(@"adult",@[@"Animation"]),*unknown=Title(@"unknown",@[@"Animation"]),*documented=Title(@"documented",@[]);
 s.ratings.records=@{@"tt0106004":@{@"minimumAge":@7},@"tt7678620":@{@"minimumAge":@0},@"adult":@{@"minimumAge":@18},@"documented":@{@"minimumAge":@7}};
 s.discoveryMetadata.records=@{@"documented":@{@"genres":@[@{@"name":@"children's television series"}]}};
 // This is the observed loophole: a Family response contained a Comedy-only
 // title. Provider group membership cannot override title-level audience data.
 s.familyCatalog=@[frasier,bluey];s.profile=@{@"maxAge":@12};
 C(![s allowed:frasier]);C([s allowed:bluey]);C([s allowed:documented]);C(![s allowed:adult]);C(![s allowed:unknown]);
 s.profile=@{@"maxAge":@(-1)};C([s allowed:frasier]);s.profile=@{@"maxAge":@0};C(![s allowed:documented]);s.profile=@{@"maxAge":@12};
 NSDictionary *snapshot=@{@"profile":s.profile,@"quality":@0,@"family":s.familyCatalog,@"metadata":s.discoveryMetadata.records,@"ageRatings":@{@"cache":s.ratings.records},@"shows":@{},@"offline":@{},@"offlineAt":@0};
 NSArray *eligible=[RWDiscoverySnapshot filter:@[frasier,bluey,documented,adult,unknown] snapshot:snapshot];
 C(![eligible containsObject:frasier]);C([eligible containsObject:bluey]);C([eligible containsObject:documented]);C(![eligible containsObject:adult]);C(![eligible containsObject:unknown]);
 NSDictionary *prefs=[RWDiscoveryMetadataPolicy preferences:@{}];C(![RWHomePreparation allows:frasier preferences:prefs restricted:YES world:NO hero:NO priors:nil]);C([RWHomePreparation allows:bluey preferences:prefs restricted:YES world:NO hero:NO priors:nil]);
 NSArray *ranked=[RWRecommendationPolicy rank:@[frasier,bluey] current:nil profile:s.profile world:NO requireAvailability:YES now:1792937000 limit:12];C(![ranked containsObject:frasier]);C([ranked containsObject:bluey]);
 NSDictionary *home=[RWRecommendationPolicy home:@[frasier,bluey] profile:s.profile year:2026 now:1792937000];for(NSDictionary *row in home[@"rows"])C(![row[@"items"]containsObject:frasier]);

 // Explicit adult-audience evidence overrides a generic animation/family tag
 // even when a stale, permissive age record and Family provider group exist.
 for(NSString *genre in @[@"Adult Animation",@"adult animated sitcom",@"adult cartoon",@"adult animated series"]){
  NSMutableDictionary *m=[bluey mutableCopy];m[@"genres"]=@[@"Animation",@"Family",genre];s.familyCatalog=@[m];s.profile=@{@"maxAge":@12};s.discoveryMetadata.records=@{};
  C(![RWDiscoveryMetadataPolicy isFamilyTitle:m]);C(![s allowed:m]);
  NSMutableDictionary *input=[snapshot mutableCopy];input[@"family"]=@[m];input[@"metadata"]=@{};C([RWDiscoverySnapshot filter:@[m] snapshot:input].count==0);
  C(![RWHomePreparation allows:m preferences:prefs restricted:YES world:NO hero:NO priors:nil]);
  s.profile=@{@"maxAge":@(-1)};C([s allowed:m]);
 }
 NSMutableDictionary *m=[bluey mutableCopy];s.profile=@{@"maxAge":@12};s.familyCatalog=@[bluey];s.discoveryMetadata.records=@{bluey[@"id"]:@{@"genres":@[@{@"name":@"adult animation"}]}};C(![s allowed:m]);
 NSMutableDictionary *input=[snapshot mutableCopy];input[@"metadata"]=s.discoveryMetadata.records;C([RWDiscoverySnapshot filter:@[m] snapshot:input].count==0);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
