#import "../RWHomeCategoryPolicy.h"
#import "../RWRecommendationPolicy.h"
#import "../RWHomeRailPolicy.h"
static int checks,failures;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSDictionary *Find(NSArray *rows,NSString *key){for(NSDictionary *r in rows)if([r[@"id"]isEqual:key])return r;return nil;}
int main(){@autoreleasepool{
 NSArray *kids=[RWHomeCategoryPolicy categoriesForKids:YES],*regular=[RWHomeCategoryPolicy categoriesForKids:NO];
 NSDictionary *adventure=Find(kids,@"category-animated-adventures"),*shorts=Find(regular,@"category-short-movies");
 CHECK([RWHomeCategoryPolicy matches:@{@"type":@"movie",@"genres":@[@"Animation",@"Adventure"]} category:adventure]);
 CHECK(![RWHomeCategoryPolicy matches:@{@"type":@"movie",@"genres":@[@"Animation"]} category:adventure]);
 CHECK(![RWHomeCategoryPolicy matches:@{@"type":@"series",@"genres":@[@"Animation",@"Adventure"]} category:adventure]);
 CHECK([RWHomeCategoryPolicy matches:@{@"type":@"movie",@"genres":@[],@"discovery":@{@"genres":@[@{@"name":@"animation"},@{@"name":@"adventure"}]}} category:adventure]);
 CHECK(![RWHomeCategoryPolicy matches:@{@"type":@"movie",@"discovery":NSNull.null} category:adventure]);
 for(NSString *v in @[@"90 min",@"72 minutes",@"8 mins"])CHECK([RWHomeCategoryPolicy matches:@{@"type":@"movie",@"runtime":v} category:shorts]);
 for(id v in @[@"91 min",@"1 hour",@"20-100 min",@"",@"90 min extra",NSNull.null])CHECK(![RWHomeCategoryPolicy matches:@{@"type":@"movie",@"runtime":v} category:shorts]);
 NSDictionary *cartoons=Find(kids,@"category-cartoon-time");CHECK([RWHomeCategoryPolicy matches:@{@"type":@"series",@"genres":@[@"Animation",@"Adventure"]} category:cartoons]);CHECK(![RWHomeCategoryPolicy matches:@{@"type":@"series",@"genres":@[@"Documentary",@"Animation",@"Family"]} category:cartoons]);CHECK(![RWHomeCategoryPolicy matches:@{@"type":@"series",@"genres":@[@"Animation"],@"discovery":@{@"genres":@[@{@"name":@"documentary"}]}} category:cartoons]);
 NSMutableArray *pool=[NSMutableArray new];NSArray *genres=@[@[@"Action",@"Adventure"],@[@"Crime",@"Mystery"],@[@"Comedy"],@[@"Science Fiction",@"Fantasy"],@[@"Animation",@"Adventure"],@[@"Documentary"],@[@"Romance"],@[@"Thriller"]];
 for(NSUInteger i=0;i<320;i++)[pool addObject:@{@"id":[NSString stringWithFormat:@"title-%lu",(unsigned long)i],@"name":[NSString stringWithFormat:@"Film %lu",(unsigned long)i],@"type":i%2?@"series":@"movie",@"genres":[genres[(i/2)%genres.count]arrayByAddingObject:@"Family"],@"runtime":i%2?@"25 min":@"88 min",@"released":@"2000-01-01",@"releaseInfo":@"2000",@"imdbRating":@8,@"imdbVotes":@100000,@"ageAllowed":@(i%7!=0),@"availability":@{@"discovery_eligible":@(i%11!=0),@"hero_eligible":@(i%13==0)},@"discovery":@{@"primaryLanguage":i%19?@"en":@"fr",@"industry":@"other",@"languageSource":@"fixture"}}];
 for(NSNumber *age in @[@(-1),@7]){
  NSDictionary *profile=@{@"maxAge":age,@"hidden":@[@"title-5"],@"discoveryPreferences":@{@"recommendationAudience":@"all_ages",@"languageMode":@"english_first",@"worldCinema":@YES}};
  NSDictionary *page=[RWRecommendationPolicy home:pool profile:profile year:2026 now:1792683561];
  CHECK([page[@"rows"]count]<=12);NSMutableSet *seen=[NSMutableSet new];if([page[@"hero"][@"id"]length])[seen addObject:page[@"hero"][@"id"]];NSUInteger themed=0;
  for(NSDictionary *row in page[@"rows"]){BOOL category=[row[@"recipe"]isEqual:@"category"];themed+=category;CHECK([row[@"items"]count]>=[row[@"minimumCount"]unsignedIntegerValue]);for(NSDictionary *m in row[@"items"]){CHECK(![seen containsObject:m[@"id"]]);[seen addObject:m[@"id"]];CHECK([m[@"type"]isEqual:row[@"mediaType"]]&&[m[@"availability"][@"discovery_eligible"]boolValue]);if(age.integerValue>=0)CHECK([m[@"ageAllowed"]boolValue]);if(category)CHECK([RWHomeCategoryPolicy matches:m category:row]);}if(category){NSArray *next=[RWHomeRailPolicy rank:pool row:row profile:profile excluding:seen available:YES now:1792683561];for(NSDictionary *m in next){CHECK([RWHomeCategoryPolicy matches:m category:row]);CHECK(![seen containsObject:m[@"id"]]);}CHECK([RWHomeRailPolicy provider:row restricted:age.integerValue>=0][@"genre"]!=nil);}}
  if(themed<4)fprintf(stderr,"age=%ld rows=%s\n",(long)age.integerValue,[[page[@"rows"]valueForKey:@"title"]description].UTF8String);CHECK(themed>=4);CHECK(![seen containsObject:@"title-5"]);CHECK([[RWRecommendationPolicy home:pool profile:profile year:2026 now:1792683561][@"rows"]isEqual:page[@"rows"]]);
 }
 // Regression: twelve qualified series formerly all went to the broad row,
 // leaving no coherent six-title comedy/drama collection.
 NSMutableArray *small=[NSMutableArray new];for(NSUInteger i=0;i<12;i++){NSMutableDictionary *m=[pool[i]mutableCopy];m[@"type"]=@"series";m[@"genres"]=i<6?@[@"Comedy"]:@[@"Drama"];m[@"ageAllowed"]=@YES;m[@"availability"]=@{@"discovery_eligible":@YES};m[@"discovery"]=@{@"primaryLanguage":@"en",@"languageSource":@"fixture",@"industry":@"other"};[small addObject:m];}
 NSDictionary *smallPage=[RWRecommendationPolicy home:small profile:@{@"maxAge":@(-1)} year:2026 now:1792683561];NSUInteger groups=0;NSMutableSet *smallIDs=[NSMutableSet new];
 for(NSDictionary *row in smallPage[@"rows"]){if([row[@"recipe"]isEqual:@"category"]){groups++;CHECK([row[@"items"]count]==6);}for(NSDictionary *m in row[@"items"]){CHECK(![smallIDs containsObject:m[@"id"]]);[smallIDs addObject:m[@"id"]];}}
 CHECK(groups==1&&smallIDs.count==12);CHECK([smallPage[@"rows"][0][@"recipe"]isEqual:@"for-you"]&&[smallPage[@"rows"][0][@"items"]count]==6);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
