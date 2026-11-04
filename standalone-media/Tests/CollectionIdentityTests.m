#import "../RWDiscoveryMetadataPolicy.h"
#import "../RWRecommendationPolicy.h"
static int checks,failures;
#define CHECK(...) do {checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSDictionary *S(id value){return @{@"mainsnak":@{@"datavalue":@{@"value":value}}};}
static NSDictionary *E(NSString *key,NSString *type){return @{@"id":key,@"lastrevid":@42,@"claims":@{@"P31":@[S(@{@"id":type})]}};}
static NSMutableDictionary *Title(NSString *key,NSArray *refs){return [@{@"id":key,@"name":key,@"type":@"movie",@"releaseInfo":@"2001",@"genres":@[@"Family",@"Adventure"],@"ageAllowed":@YES,@"imdbRating":@8,@"imdbVotes":@50000,@"availability":@{@"discovery_eligible":@YES},@"discovery":@{@"primaryLanguage":@"en",@"languageSource":@"test",@"industry":@"other",@"franchises":refs}}mutableCopy];}
int main(){@autoreleasepool{
 NSDictionary *list=@{@"id":@"Q2732470",@"name":@"list of Pixar films"},*series=@{@"id":@"Q2316015",@"name":@"Toy Story"};
 NSDictionary *entities=@{@"Q2732470":E(@"Q2732470",@"Q13406463"),@"Q2316015":E(@"Q2316015",@"Q196600")};
 NSDictionary *raw=@{@"franchises":@[list,series],@"fetchedAt":@10,@"cast":@[@{@"id":@"Q1"}]};
 NSDictionary *fixed=[RWDiscoveryMetadataPolicy normalizeCollections:raw entities:entities];
 CHECK([fixed[@"collections"]count]==2);CHECK([fixed[@"franchises"]count]==1);CHECK([fixed[@"franchises"][0][@"id"]isEqual:@"Q2316015"]);
 CHECK([fixed[@"cast"]isEqual:raw[@"cast"]]&&[fixed[@"fetchedAt"]isEqual:@10]);CHECK(!raw[@"collections"]);
 CHECK([[RWDiscoveryMetadataPolicy normalizeCollections:fixed entities:@{}]isEqual:fixed]);
 CHECK(![RWDiscoveryMetadataPolicy isNarrativeFranchise:list]);CHECK(![RWDiscoveryMetadataPolicy isNarrativeFranchise:series]);
 CHECK(![RWDiscoveryMetadataPolicy isNarrativeFranchise:@{@"instanceOf":@[@"Q56884562"]}]);
 CHECK(![RWDiscoveryMetadataPolicy isNarrativeFranchise:@{@"instanceOf":@[@"Q196600",@"Q13406463"]}]);
 CHECK(![[[RWDiscoveryMetadataPolicy normalizeCollections:raw entities:@{@"Q2316015":E(@"Q9",@"Q196600")}]objectForKey:@"franchises"]count]);
 NSDictionary *entity=@{@"id":@"Q171048",@"claims":@{@"P345":@[S(@"tt0114709")],@"P179":@[S(@{@"id":@"Q2732470"}),S(@{@"id":@"Q2316015"})]}};
 CHECK([[RWDiscoveryMetadataPolicy collectionIDs:entity]isEqual:@[@"Q2732470",@"Q2316015"]]);
 CHECK([[[RWDiscoveryMetadataPolicy recordForEntity:entity imdb:@"tt0114709" labels:entities]objectForKey:@"franchises"]count]==1);
 NSMutableArray *films=[NSMutableArray new];for(int i=0;i<5;i++){NSMutableDictionary *m=Title([NSString stringWithFormat:@"tt%d",i],@[list]);m[@"discovery"]=[RWDiscoveryMetadataPolicy normalizeCollections:m[@"discovery"] entities:entities];[films addObject:m];}
 NSDictionary *kids=@{@"maxAge":@12};double now=1792851552;
 NSDictionary *home=[RWRecommendationPolicy home:films profile:kids year:2026 now:now];CHECK([home[@"rows"][0][@"items"]count]==5);
 for(int i=0;i<2;i++){NSMutableDictionary *m=Title([NSString stringWithFormat:@"tt%d",20+i],@[list,series]);m[@"discovery"]=[RWDiscoveryMetadataPolicy normalizeCollections:m[@"discovery"] entities:entities];[films addObject:m];}
 home=[RWRecommendationPolicy home:films profile:kids year:2026 now:now];CHECK([home[@"rows"][0][@"items"]count]==6);
 films[0][@"ageAllowed"]=@NO;films[1][@"availability"]=@{@"discovery_eligible":@NO};films[2][@"released"]=@"2199-01-01";
 home=[RWRecommendationPolicy home:films profile:kids year:2026 now:now];CHECK([home[@"rows"][0][@"items"]count]==3);
 // Old embedded records can bypass service migration; rank still rejects the
 // untyped collection as a hard cap or as invented contextual evidence.
 NSMutableDictionary *a=Title(@"a",@[list]),*b=Title(@"b",@[list]);a[@"genres"]=@[@"Sci-Fi"];b[@"genres"]=@[@"Romance"];
 CHECK([RWRecommendationPolicy rank:@[a,b] current:nil profile:@{@"maxAge":@(-1)} world:NO requireAvailability:YES now:now limit:12].count==2);
 CHECK(![RWRecommendationPolicy related:@[b] current:a profile:@{@"maxAge":@(-1)} world:NO now:now limit:12].count);
 NSMutableDictionary *typed=[fixed mutableCopy];typed[@"primaryLanguage"]=@"en";typed[@"languageSource"]=@"fixture";typed[@"industry"]=@"other";a[@"discovery"]=typed;b[@"discovery"]=typed;CHECK([RWRecommendationPolicy related:@[b] current:a profile:@{@"maxAge":@(-1)} world:NO now:now limit:12].count==1);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
