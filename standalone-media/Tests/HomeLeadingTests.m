#import "../RWRecommendationPolicy.h"
#import "../RWHomeCategoryPolicy.h"
#import "../RWDiscoveryMetadataPolicy.h"
static int Checks,Failures;
#define C(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSMutableDictionary *Title(NSString *key,NSArray *genres,double rating){return [@{@"id":key,@"name":key,@"type":@"series",@"genres":genres,@"imdbRating":@(rating),@"imdbVotes":@100000,@"releaseInfo":@"2020",@"released":@"2020-01-01",@"ageAllowed":@YES,@"availability":@{@"discovery_eligible":@YES},@"discovery":@{@"primaryLanguage":@"en",@"industry":@"other",@"languageSource":@"fixture"}}mutableCopy];}
static NSDictionary *Lead(NSDictionary *page){for(NSDictionary *r in page[@"rows"])if([r[@"id"]isEqual:@"for-you-series"])return r;return @{};}
static void Audit(NSDictionary *page){NSMutableSet *seen=[NSMutableSet new];for(NSDictionary *r in page[@"rows"]){C([r[@"items"]count]>=[r[@"minimumCount"]unsignedIntegerValue]);for(NSDictionary *m in r[@"items"]){C(![seen containsObject:m[@"id"]]);[seen addObject:m[@"id"]];C([m[@"availability"][@"discovery_eligible"]boolValue]);C([m[@"type"]isEqual:r[@"mediaType"]]);if([r[@"recipe"]isEqual:@"category"])C([RWHomeCategoryPolicy matches:m category:r]);}}}
int main(){@autoreleasepool{
 C(![RWDiscoveryMetadataPolicy isChildFocused:@{@"genres":@[@"Family"]}]);
 C([RWDiscoveryMetadataPolicy isChildFocused:@{@"genres":@[@"Children’s television series"]}]);
 C(![RWDiscoveryMetadataPolicy isChildFocused:@{@"genres":@[@"Animation",@"Adult animation"]}]);
 C(![RWDiscoveryMetadataPolicy isChildFocused:@{@"genres":@[@"Animation",@"Documentary"]}]);
 C(![RWDiscoveryMetadataPolicy isChildFocused:@{@"name":@"Children cartoon kids",@"genres":@[@"Drama"]}]);
 double now=1793080179;NSMutableArray *pool=[NSMutableArray new];
 for(int i=0;i<24;i++)[pool addObject:Title([NSString stringWithFormat:@"strong-%d",i],@[@"Mystery",@"Thriller"],i?8.4:9.5)];
 for(int i=0;i<10;i++)[pool addObject:Title([NSString stringWithFormat:@"weak-%d",i],@[@"Drama"],6.0)];
 NSDictionary *adult=@{@"maxAge":@(-1),@"discoveryPreferences":@{@"worldCinema":@NO}};
 NSDictionary *page=[RWRecommendationPolicy home:pool profile:adult year:2026 now:now];NSArray *lead=Lead(page)[@"items"];C(lead.count>=4);C([lead[0][@"id"]isEqual:@"strong-0"]);NSArray *expected=[RWRecommendationPolicy rank:pool current:nil profile:adult world:NO requireAvailability:YES now:now limit:4];C(lead.count>=4&&[[[lead subarrayWithRange:NSMakeRange(0,4)]valueForKey:@"id"]isEqual:[expected valueForKey:@"id"]]);Audit(page);
 NSMutableArray *kids=[NSMutableArray new];for(int i=0;i<16;i++)[kids addObject:Title([NSString stringWithFormat:@"child-%d",i],@[@"Animation",@"Adventure",@"Family"],8.0)];for(int i=0;i<12;i++)[kids addObject:Title([NSString stringWithFormat:@"nature-%d",i],@[@"Documentary",@"Family"],9.2)];for(int i=0;i<8;i++)[kids addObject:Title([NSString stringWithFormat:@"family-%d",i],@[@"Family",@"Drama"],8.5)];
 NSMutableDictionary *restricted=[@{@"maxAge":@10,@"discoveryPreferences":@{@"worldCinema":@NO}}mutableCopy];page=[RWRecommendationPolicy home:kids profile:restricted year:2026 now:now];lead=Lead(page)[@"items"];C(lead.count>=4);for(NSUInteger i=0;i<MIN((NSUInteger)4,lead.count);i++)C([lead[i][@"id"]hasPrefix:@"child-"]);Audit(page);
 // An existing preference for nature must still be meaningful in Kids.
 restricted[@"liked"]=@[[kids[16]mutableCopy]];page=[RWRecommendationPolicy home:kids profile:restricted year:2026 now:now];lead=Lead(page)[@"items"];C([[lead valueForKey:@"id"]filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'nature-'"]].count>0);Audit(page);
 // Sparse catalogs keep a coherent six-title category when a different
 // category can be reserved without sacrificing the best leading result.
 NSMutableArray *small=[NSMutableArray new];for(int i=0;i<12;i++)[small addObject:Title([NSString stringWithFormat:@"small-%d",i],i<6?@[@"Comedy"]:@[@"Drama"],i?8:9.5)];page=[RWRecommendationPolicy home:small profile:adult year:2026 now:now];C([Lead(page)[@"items"][0][@"id"]isEqual:@"small-0"]);NSUInteger categories=0;for(NSDictionary *r in page[@"rows"])categories+=[r[@"recipe"]isEqual:@"category"];C(categories==1);Audit(page);
 printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
