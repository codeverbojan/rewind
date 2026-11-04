#import "../RWRecommendationPolicy.h"
#import "../RWDiscoveryMetadataPolicy.h"
#import "../RWProfiles.h"
static NSDictionary *Read(NSString *path){return [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] options:0 error:nil];}
static NSMutableDictionary *Title(NSString *identifier,NSString *language,double rating,NSInteger votes){return [@{@"id":identifier,@"name":identifier,@"type":@"movie",@"releaseInfo":@"2000",@"genres":@[@"Thriller",@"Crime"],@"imdbRating":@(rating),@"imdbVotes":@(votes),@"availability":@{@"discovery_eligible":@YES,@"hero_eligible":@NO},@"discovery":@{@"primaryLanguage":language,@"languageSource":@"fixture",@"industry":@"other",@"directors":@[],@"cast":@[],@"studios":@[]}}mutableCopy];}
int main(int argc,char **argv){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    NSString *folder=argc>1?@(argv[1]):@"";NSDictionary *entities=Read([folder stringByAppendingPathComponent:@"inception-entity.json"])[@"entities"],*labels=Read([folder stringByAppendingPathComponent:@"inception-entity-labels.json"])[@"entities"];
    NSDictionary *record=[RWDiscoveryMetadataPolicy recordForEntity:entities.allValues.firstObject imdb:@"tt1375666" labels:labels];
    CHECK(record!=nil);CHECK([[RWDiscoveryMetadataPolicy languageGroup:record]isEqual:@"unknown"]);CHECK([record[@"originalLanguages"]count]==3);
    CHECK(![RWDiscoveryMetadataPolicy recordForEntity:entities.allValues.firstObject imdb:@"tt12345" labels:labels]);
    CHECK([record[@"directors"]count]>0&&[record[@"studios"]count]>0);
    CHECK([[RWDiscoveryMetadataPolicy creditIDs:entities.allValues.firstObject role:@"director" entityID:@"Q25191"]containsObject:@"tt1375666"]);
    CHECK(![RWDiscoveryMetadataPolicy creditIDs:entities.allValues.firstObject role:@"cast" entityID:@"Q25191"].count);
    NSDictionary *parasiteEntity=Read([folder stringByAppendingPathComponent:@"world-language.json"])[@"entities"];
    NSDictionary *parasite=[RWDiscoveryMetadataPolicy recordForEntity:parasiteEntity.allValues.firstObject imdb:@"tt6751668" labels:@{}];
    CHECK([[RWDiscoveryMetadataPolicy languageGroup:parasite]isEqual:@"world"]);
    NSDictionary *indianEntity=Read([folder stringByAppendingPathComponent:@"bollywood-language.json"])[@"entities"];
    NSDictionary *indian=[RWDiscoveryMetadataPolicy recordForEntity:indianEntity.allValues.firstObject imdb:@"tt1187043" labels:@{}];
    CHECK([indian[@"industry"]isEqual:@"unknown"]); // Never label India = Bollywood.
    NSDictionary *prefs=@{@"languageMode":@"english_first",@"excludeBollywood":@YES,@"worldCinema":@YES};
    CHECK(![RWDiscoveryMetadataPolicy permits:@{@"discovery":indian} preferences:prefs world:YES]);
    CHECK([RWDiscoveryMetadataPolicy permits:@{@"discovery":parasite} preferences:prefs world:YES]);
    CHECK(![RWDiscoveryMetadataPolicy permits:@{@"discovery":parasite} preferences:prefs world:NO]);
    CHECK(![[RWDiscoveryMetadataPolicy moods:@{@"genres":@[@"Comedy",@"Crime"]}]containsObject:@"Light-hearted"]);
    CHECK([[RWDiscoveryMetadataPolicy moods:@{@"genres":@[@"Family",@"Comedy"]}]containsObject:@"Light-hearted"]);
    CHECK([[RWDiscoveryMetadataPolicy languageGroup:@{@"originalLanguages":@[@{@"id":@"Q7976",@"name":@"American English"}]}]isEqual:@"english"]);
    CHECK([[RWDiscoveryMetadataPolicy languageGroup:@{@"originalLanguages":@[@{@"id":@"Q7976"},@{@"id":@"Q1321"}]}]isEqual:@"unknown"]);
    CHECK([[RWDiscoveryMetadataPolicy preferences:@{@"worldCinema":NSNull.null,@"worldMinRating":@{}}][@"worldCinema"]boolValue]);
    NSDictionary *cartoon=@{@"genres":@[@"Animation",@"Comedy"]},*family=@{@"genres":@[@"Family",@"Comedy"]},*adultCartoon=@{@"genres":@[@"Animation",@"Adult animation"]};
    CHECK(![RWDiscoveryMetadataPolicy recommendationAudienceAllows:cartoon preferences:@{} restricted:NO]);
    CHECK(![RWDiscoveryMetadataPolicy recommendationAudienceAllows:family preferences:@{} restricted:NO]);
    CHECK([RWDiscoveryMetadataPolicy recommendationAudienceAllows:adultCartoon preferences:@{} restricted:NO]);
    CHECK([RWDiscoveryMetadataPolicy recommendationAudienceAllows:cartoon preferences:@{@"recommendationAudience":@"all_ages"} restricted:NO]);
    CHECK([RWDiscoveryMetadataPolicy recommendationAudienceAllows:cartoon preferences:@{} restricted:YES]);
    CHECK([RWDiscoveryMetadataPolicy recommendationAudienceAllows:@{@"genres":@[@"Drama"]} preferences:@{} restricted:NO]);
    for(NSString *qid in @[@"Q2143665",@"Q1273568",@"Q1361932",@"Q202866"]){NSDictionary *unlabelled=@{@"discovery":@{@"genres":@[@{@"id":qid,@"name":@""}]}};CHECK([RWDiscoveryMetadataPolicy isFamilyTitle:unlabelled]);CHECK(![RWDiscoveryMetadataPolicy recommendationAudienceAllows:unlabelled preferences:@{} restricted:NO]);CHECK([RWDiscoveryMetadataPolicy recommendationAudienceAllows:unlabelled preferences:@{@"recommendationAudience":@"all_ages"} restricted:NO]);}
    NSDictionary *adultID=@{@"genres":@[@"Animation"],@"discovery":@{@"genres":@[@{@"id":@"Q138600175",@"name":@""}]}};CHECK([RWDiscoveryMetadataPolicy isAdultAudience:adultID]);CHECK([RWDiscoveryMetadataPolicy recommendationAudienceAllows:adultID preferences:@{} restricted:NO]);
    NSMutableDictionary *profile=[RWProfiles make:@"Main" age:-1];profile[@"discoveryPreferences"]=prefs;
    NSMutableDictionary *english=Title(@"tt1",@"en",8,100000),*foreign=Title(@"tt2",@"ko",8.5,100000),*fewVotes=Title(@"tt3",@"ko",9.5,5),*future=Title(@"tt4",@"en",9,200000),*unavailable=Title(@"tt5",@"en",9,300000),*unknown=Title(@"tt6",@"en",8,20000);
    NSMutableDictionary *cartoonTitle=[english mutableCopy];cartoonTitle[@"id"]=@"tt3210";cartoonTitle[@"genres"]=@[@"Animation",@"Comedy"];
    CHECK(![RWRecommendationPolicy rank:@[cartoonTitle] current:nil profile:profile world:NO requireAvailability:YES now:1792607000 limit:10].count);
    CHECK(![RWRecommendationPolicy homeRefreshCandidates:@[cartoonTitle] profile:profile now:1792607000].count);
    CHECK([RWRecommendationPolicy rank:@[cartoonTitle] current:nil profile:profile world:NO requireAvailability:NO now:1792607000 limit:10].count==1); // explicit browsing remains accessible
    NSMutableDictionary *allAges=[profile mutableCopy];allAges[@"discoveryPreferences"]=@{@"recommendationAudience":@"all_ages"};
    CHECK([RWRecommendationPolicy rank:@[cartoonTitle] current:nil profile:allAges world:NO requireAvailability:YES now:1792607000 limit:10].count==1);
    CHECK([RWRecommendationPolicy homeRefreshCandidates:@[cartoonTitle] profile:allAges now:1792607000].count==1);
    cartoonTitle[@"genres"]=@[@"Animation",@"Adult animation"];
    CHECK([RWRecommendationPolicy rank:@[cartoonTitle] current:nil profile:profile world:NO requireAvailability:YES now:1792607000 limit:10].count==1);
    future[@"released"]=@"2027-01-01";unavailable[@"availability"]=@{@"state":@"waiting",@"watch_instead_of_play":@YES};unknown[@"availability"]=@{};
    double now=1792607000;NSArray *all=@[english,foreign,fewVotes,future,unavailable,unknown,english];
    NSArray *ranked=[RWRecommendationPolicy rank:all current:nil profile:profile world:NO requireAvailability:YES now:now limit:12];
    CHECK(ranked.count==1&&[ranked[0][@"id"]isEqual:@"tt1"]);
    ranked=[RWRecommendationPolicy rank:all current:nil profile:profile world:YES requireAvailability:YES now:now limit:12];
    CHECK(ranked.count==1&&[ranked[0][@"id"]isEqual:@"tt2"]);
    CHECK([RWRecommendationPolicy quality:fewVotes prior:6.5]<[RWRecommendationPolicy quality:foreign prior:6.5]);
    CHECK(![RWRecommendationPolicy rank:@[english] current:english profile:profile world:NO requireAvailability:YES now:now limit:12].count);
    profile[@"history"][@"tt1"]=@{@"meta":english,@"position":@7200,@"duration":@7200,@"completed":@YES};
    CHECK([RWRecommendationPolicy rank:@[english] current:nil profile:profile world:NO requireAvailability:YES now:now limit:12].count==1);
    profile[@"history"][@"tt1"]=@{@"meta":english,@"position":@400,@"duration":@7200,@"watchSeconds":@400,@"watchSignalVersion":@1};
    CHECK(![RWRecommendationPolicy rank:@[english] current:nil profile:profile world:NO requireAvailability:YES now:now limit:12].count);
    profile[@"history"]=[NSMutableDictionary new];profile[@"hidden"]=@[@"tt1"];
    CHECK(![RWRecommendationPolicy rank:@[english] current:nil profile:profile world:NO requireAvailability:YES now:now limit:12].count);profile[@"hidden"]=@[];
    NSMutableDictionary *kids=[RWProfiles make:@"Kids" age:7];CHECK(![RWRecommendationPolicy rank:@[english] current:nil profile:kids world:NO requireAvailability:YES now:now limit:12].count);
    NSMutableArray *pool=[NSMutableArray new];for(int i=0;i<500;i++){NSMutableDictionary *m=Title([NSString stringWithFormat:@"tt%05d",i+100],i%5?@"en":@"ko",8.2,100000);m[@"releaseInfo"]=i%2?@"2026":@"1995";[pool addObject:m];}
    double start=NSProcessInfo.processInfo.systemUptime;NSDictionary *home=[RWRecommendationPolicy home:pool profile:profile year:2026 now:now];double elapsed=NSProcessInfo.processInfo.systemUptime-start;
    CHECK([home[@"rows"]count]>=3);CHECK(![home[@"hero"]count]);NSMutableSet *seen=[NSMutableSet new];for(NSDictionary *row in home[@"rows"])for(NSDictionary *m in row[@"items"]){CHECK(![seen containsObject:m[@"id"]]);[seen addObject:m[@"id"]];}
    CHECK([[RWRecommendationPolicy home:pool profile:profile year:2026 now:now][@"rows"]isEqual:home[@"rows"]]);
    NSDictionary *seed=Read([[folder stringByDeletingLastPathComponent]stringByDeletingLastPathComponent].length?[[[folder stringByDeletingLastPathComponent]stringByDeletingLastPathComponent]stringByAppendingPathComponent:@"Resources/Rewind/discovery-metadata.json"]:@"")[@"titles"];
    CHECK([[RWDiscoveryMetadataPolicy languageGroup:seed[@"tt0903747"]]isEqual:@"english"]);
    CHECK([[RWDiscoveryMetadataPolicy languageGroup:seed[@"tt6751668"]]isEqual:@"world"]);
    CHECK(![RWDiscoveryMetadataPolicy permits:@{@"discovery":seed[@"tt1187043"]} preferences:prefs world:YES]);
    CHECK([RWRecommendationPolicy quality:@{@"imdbRating":NSNull.null,@"imdbVotes":NSNull.null} prior:6.5]==6.5);
    NSMutableDictionary *foreignShow=[foreign mutableCopy];foreignShow[@"type"]=@"series";
    CHECK(![RWRecommendationPolicy rank:@[foreignShow] current:nil profile:profile world:YES requireAvailability:NO now:now limit:12].count);
    NSMutableDictionary *foreignAnchor=[foreignShow mutableCopy];foreignAnchor[@"id"]=@"tt987654";
    CHECK([RWRecommendationPolicy rank:@[foreignShow] current:foreignAnchor profile:profile world:YES requireAvailability:NO now:now limit:12].count==1);
    CHECK(![RWRecommendationPolicy rank:@[foreignShow] current:foreignShow profile:profile world:YES requireAvailability:NO now:now limit:12].count);
    NSMutableArray *cold=[NSMutableArray new];for(NSDictionary *meta in pool){NSMutableDictionary *m=[meta mutableCopy];m[@"availability"]=@{};[cold addObject:m];}start=NSProcessInfo.processInfo.systemUptime;NSDictionary *emptyHome=[RWRecommendationPolicy home:cold profile:profile year:2026 now:now];double coldElapsed=NSProcessInfo.processInfo.systemUptime-start;CHECK([emptyHome[@"candidateCount"]integerValue]==500);CHECK(![emptyHome[@"rows"]count]&&![emptyHome[@"hero"]count]);
    for(int i=0;i<4;i++)cold[i][@"availability"]=@{@"discovery_eligible":@YES,@"hero_eligible":@NO};NSDictionary *sparseHome=[RWRecommendationPolicy home:cold profile:profile year:2026 now:now];CHECK([sparseHome[@"rows"]count]>=1);CHECK(![sparseHome[@"hero"]count]);
    for(NSDictionary *row in home[@"rows"])if(![@[@"for-you",@"world"]containsObject:row[@"recipe"]])CHECK([row[@"items"]count]>=6);
    NSMutableArray *small=[NSMutableArray new];for(int i=0;i<17;i++){NSMutableDictionary *m=Title([NSString stringWithFormat:@"tt%d",9000+i],@"en",8,100000);m[@"releaseInfo"]=@"2020";m[@"genres"]=i<2?@[@"Adventure"]:@[@"Drama"];[small addObject:m];}
    NSDictionary *smallHome=[RWRecommendationPolicy home:small profile:profile year:2026 now:now];NSMutableSet *smallIDs=[NSMutableSet new];
    for(NSDictionary *row in smallHome[@"rows"]){CHECK(![row[@"title"]isEqual:@"Epic adventures"]);if(![row[@"recipe"]isEqual:@"for-you"])CHECK([row[@"items"]count]>=6);for(NSDictionary *m in row[@"items"]){CHECK(![smallIDs containsObject:m[@"id"]]);[smallIDs addObject:m[@"id"]];}}
    CHECK(smallIDs.count==17);
    // Frozen mixed catalog: verify page semantics, not particular score ties.
    NSMutableArray *mixed=[NSMutableArray new];for(int i=0;i<140;i++){NSMutableDictionary *m=Title([NSString stringWithFormat:@"mix%d",i],i>=120?@"ko":@"en",8.2,100000);m[@"type"]=i<60||i>=120?@"movie":@"series";m[@"releaseInfo"]=i%2?@"2026":@"1995";m[@"ageAllowed"]=@YES;[mixed addObject:m];}
    NSDictionary *mixedHome=[RWRecommendationPolicy home:mixed profile:profile year:2026 now:now];NSMutableSet *types=[NSMutableSet new],*intents=[NSMutableSet new],*allIDs=[NSMutableSet new];BOOL typed=YES,unique=YES,minimum=YES,worldOnly=YES;
    for(NSDictionary *row in mixedHome[@"rows"]){[types addObject:row[@"mediaType"]];[intents addObject:row[@"recipe"]];minimum&=[row[@"items"]count]>=[row[@"minimumCount"]unsignedIntegerValue];for(NSDictionary *m in row[@"items"]){typed&=[m[@"type"]isEqual:row[@"mediaType"]];unique&=![allIDs containsObject:m[@"id"]];[allIDs addObject:m[@"id"]];if([row[@"id"]isEqual:@"world"])worldOnly&=[[RWDiscoveryMetadataPolicy languageGroup:m[@"discovery"]]isEqual:@"world"];}}
    CHECK(typed&&unique&&minimum&&worldOnly);CHECK(types.count==2);CHECK([mixedHome[@"rows"]count]<=12);CHECK([intents containsObject:@"new"]&&[intents containsObject:@"older"]&&[intents containsObject:@"world"]);CHECK([[RWRecommendationPolicy home:mixed profile:profile year:2026 now:now][@"rows"]isEqual:mixedHome[@"rows"]]);
    NSMutableDictionary *blocked=[profile mutableCopy];blocked[@"hidden"]=@[@"mix0",@"mix60"];blocked[@"history"]=@{@"mix2":@{@"meta":mixed[2],@"position":@30,@"duration":@1000}};blocked[@"liked"]=@[mixed[4]];
    mixed[6][@"availability"]=@{@"discovery_eligible":@NO,@"hero_eligible":@YES};mixed[8][@"released"]=@"2027-01-01";mixed[10][@"availability"]=@{@"discovery_eligible":@YES,@"hero_eligible":@NO,@"watch_instead_of_play":@YES};mixed[12][@"availability"]=@{@"discovery_eligible":@YES,@"hero_eligible":@YES};
    NSDictionary *blockedHome=[RWRecommendationPolicy home:mixed profile:blocked year:2026 now:now];CHECK([blockedHome[@"hero"][@"id"]isEqual:@"mix12"]);NSSet *bad=[NSSet setWithArray:@[@"mix0",@"mix60",@"mix2",@"mix4",@"mix6",@"mix8",@"mix10",@"mix12"]];BOOL absent=YES;
    for(NSDictionary *row in blockedHome[@"rows"])for(NSDictionary *m in row[@"items"])if([bad containsObject:m[@"id"]])absent=NO;CHECK(absent);
    NSMutableDictionary *unknownAge=[mixed[14]mutableCopy];unknownAge[@"ageAllowed"]=@NO;NSMutableDictionary *kidEligible=[mixed[15]mutableCopy];kidEligible[@"ageAllowed"]=@YES;kidEligible[@"genres"]=@[@"Family"];
    NSDictionary *kidHome=[RWRecommendationPolicy home:@[unknownAge,kidEligible] profile:kids year:2026 now:now];CHECK([kidHome[@"rows"]count]==1&&[kidHome[@"rows"][0][@"items"]count]==1);CHECK(![kidHome[@"rows"][0][@"id"]isEqual:@"world"]);
    CHECK(![RWRecommendationPolicy rank:@[kidEligible] current:nil profile:kids world:YES requireAvailability:YES now:now limit:10].count);
    NSSet *exclusions=[RWRecommendationPolicy homeExcludedIDsForProfile:blocked];CHECK([exclusions containsObject:@"mix0"]&&[exclusions containsObject:@"mix2"]&&[exclusions containsObject:@"mix4"]);CHECK(![exclusions containsObject:@"mix12"]);
    NSDictionary *signals=@{@"history":@{@"technical":@{@"meta":english,@"position":@0,@"completed":@YES,@"duration":@1000,@"watchSeconds":@0,@"watchSignalVersion":@1},@"watched":@{@"meta":foreign,@"position":@0,@"completed":@YES,@"duration":@1000,@"watchSeconds":@900,@"watchSignalVersion":@1}}};
    CHECK(![[RWRecommendationPolicy homeExcludedIDsForProfile:signals]containsObject:@"tt1"]);CHECK([[RWRecommendationPolicy homeExcludedIDsForProfile:signals]containsObject:@"tt2"]);
    // A two-title theme cannot become a specialist shelf just to fill space.
    NSMutableDictionary *thinAnchor=Title(@"liked-anchor",@"en",8,10000);thinAnchor[@"genres"]=@[@"Adventure",@"Fantasy"];NSMutableDictionary *thinProfile=[profile mutableCopy];thinProfile[@"liked"]=@[thinAnchor];small[0][@"genres"]=thinAnchor[@"genres"];small[1][@"genres"]=thinAnchor[@"genres"];
    NSDictionary *thinHome=[RWRecommendationPolicy home:small profile:thinProfile year:2026 now:now];BOOL noThin=YES;for(NSDictionary *row in thinHome[@"rows"])if([@[@"mood",@"because"]containsObject:row[@"recipe"]]&&[row[@"items"]count]<6)noThin=NO;CHECK(noThin);
    CHECK(![RWRecommendationPolicy homePendingEligible:@{@"imdbRating":@5.3} now:now]);
    CHECK(![RWRecommendationPolicy homePendingEligible:@{@"imdbRating":@8,@"releaseInfo":@"2027"} now:now]);
    CHECK(![RWRecommendationPolicy homePendingEligible:@{@"released":@"2027-01-01"} now:now]);
    CHECK([RWRecommendationPolicy homePendingEligible:@{@"imdbRating":@8,@"releaseInfo":@"2020"} now:now]);
    CHECK([RWRecommendationPolicy homePendingEligible:@{} now:now]);
    for(NSNumber *value in @[@4.8,@5.3,@5.5,@5.9]){NSMutableDictionary *low=Title(@"low-quality",@"en",value.doubleValue,100000);low[@"availability"]=@{@"discovery_eligible":@YES,@"hero_eligible":@YES};CHECK(![RWRecommendationPolicy homeQualityEligible:low]);NSDictionary *result=[RWRecommendationPolicy home:@[low] profile:profile year:2026 now:now];CHECK(![result[@"rows"]count]&&![result[@"hero"]count]);CHECK([RWRecommendationPolicy rank:@[low] current:nil profile:profile world:NO requireAvailability:YES now:now limit:12].count==1);}
    for(id value in @[@6,@8.2,@"6.0",@"",NSNull.null,@"5.2 malformed",@"NaN"]){NSMutableDictionary *m=Title(@"rating-parse",@"en",8,10000);m[@"imdbRating"]=value;CHECK([RWRecommendationPolicy homeQualityEligible:m]);}
    printf("{\"checks\":%d,\"failures\":%d,\"host_rank_500_seconds\":%.6f,\"host_cold_500_seconds\":%.6f}\n",checks,failures,elapsed,coldElapsed);return failures?1:0;
}}
