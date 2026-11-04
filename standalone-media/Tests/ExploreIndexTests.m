#import "../RWExploreIndex.h"
#import "../RWDiscoveryMetadataPolicy.h"
static NSDictionary *Title(NSString *identifier,NSString *name,NSInteger year,double rating,NSUInteger votes,NSArray *cast,NSArray *directors,NSArray *studios){return @{@"id":identifier,@"type":@"movie",@"name":name,@"releaseInfo":[@(year)stringValue],@"imdbRating":@(rating),@"imdbVotes":@(votes),@"genres":@[@"Adventure",@"Fantasy"],@"background":[@"https://images.test/" stringByAppendingString:identifier],@"discovery":@{@"cast":cast,@"directors":directors,@"studios":studios}};}
static NSDictionary *Claim(id value){return @{@"mainsnak":@{@"datavalue":@{@"value":value}}};}
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    NSDictionary *a=@{@"id":@"Q1",@"name":@"Alice Average"},*b=@{@"id":@"Q2",@"name":@"Zoe Acclaimed"},*c=@{@"id":@"Q3",@"name":@"Alicia Newcomer"},*d=@{@"id":@"Q4",@"name":@"Zoe Acclaimed Jr"},*studio=@{@"id":@"Q10",@"name":@"Good Studio"};
    NSMutableArray *titles=[@[Title(@"tt1",@"A solid film",2022,6.8,90000,@[a],@[],@[studio]),Title(@"tt2",@"An acclaimed release",2026,8.2,90000,@[b,b],@[b],@[studio]),Title(@"tt3",@"One vote",2026,10,1,@[c],@[],@[]),Title(@"tt4",@"Future title",2028,10,500000,@[d],@[],@[])]mutableCopy];double now=1792454400;
    NSArray *(^index)(NSString *,NSString *)=^NSArray *(NSString *kind,NSString *query){return [RWExploreIndex records:titles kind:kind mood:nil query:query profile:@"regular" entities:@{} now:now];};
    NSArray *people=index(@"People",@"");CHECK(people.count==3);CHECK([people[0][@"id"]isEqual:@"Q2"]);CHECK(![[people valueForKey:@"id"]containsObject:@"Q4"]);CHECK([people[0][@"roles"]count]==2);CHECK([people[0][@"knownFor"]count]==1);CHECK([people[0][@"creditCount"]integerValue]==1);CHECK(!people[0][@"imdbRating"]);CHECK([people[0][@"profileID"]isEqual:@"regular"]);
    CHECK([index(@"People",@"Alice").firstObject[@"id"]isEqual:@"Q1"]);CHECK([index(@"People",@"zoe acclaimed").firstObject[@"id"]isEqual:@"Q2"]);CHECK([index(@"People",@"accla zoe").firstObject[@"id"]isEqual:@"Q2"]);CHECK(!index(@"People",@"missing").count);
    NSArray *studios=index(@"Studios",@"");CHECK(studios.count==1&&[studios[0][@"type"]isEqual:@"studio"]);CHECK([studios[0][@"creditCount"]integerValue]==2);CHECK([studios[0][@"knownFor"][0][@"id"]isEqual:@"tt2"]);
    [titles addObject:Title(@"tt5",@"Recent good film",2026,7.9,100000,@[a],@[],@[])];[titles addObject:Title(@"tt6",@"Older film",1999,7.5,100000,@[a],@[],@[])];[titles addObject:Title(@"tt7",@"Old film",1998,7.4,100000,@[a],@[],@[])];
    NSArray *alice=index(@"People",@"Alice");CHECK([alice[0][@"knownFor"]count]==3&&[alice[0][@"creditCount"]integerValue]==4);CHECK([alice[0][@"knownFor"][0][@"id"]isEqual:@"tt5"]);
    [titles addObject:Title(@"tt8",@"Malformed identity",2026,10,100000,@[@{@"id":@"Qno",@"name":@"Bad"},@{@"id":@"Q11",@"name":@""}],@[],@[])];CHECK(index(@"People",@"").count==3);
    NSArray *moods=index(@"Moods",@"");CHECK(moods.count>0);NSDictionary *adventure=nil;for(NSDictionary *m in moods)if([m[@"name"]isEqual:@"Epic adventures"])adventure=m;CHECK(adventure&&[adventure[@"image"]hasPrefix:@"https://images.test/"]);CHECK([adventure[@"imageRole"]isEqual:@"mood-artwork"]);
    NSArray *moodTitles=[RWExploreIndex records:titles kind:@"Moods" mood:@"Epic adventures" query:@"solid" profile:@"regular" entities:@{} now:now];CHECK(moodTitles.count==1&&[moodTitles[0][@"id"]isEqual:@"tt1"]);
    NSDictionary *cache=@{@"Q2:person":@{@"image":@"https://image.test/person.jpg",@"imageRole":@"portrait"}};NSArray *cached=[RWExploreIndex records:titles kind:@"People" mood:nil query:@"Zoe Acclaimed" profile:@"kids" entities:cache now:now];CHECK([cached[0][@"image"]isEqual:@"https://image.test/person.jpg"]);CHECK([cached[0][@"profileID"]isEqual:@"kids"]);
    CHECK([[RWDiscoveryMetadataPolicy displayName:@{@"labels":@{@"mul":@{@"value":@"Anne Hathaway"}}}]isEqual:@"Anne Hathaway"]);CHECK([[RWDiscoveryMetadataPolicy displayName:@{@"labels":@{@"en":@{@"value":@"English"},@"mul":@{@"value":@"Fallback"}}}]isEqual:@"English"]);
    NSDictionary *entity=@{@"id":@"Q10",@"labels":@{@"mul":@{@"value":@"Studio"}},@"claims":@{@"P18":@[Claim(@"Office.jpg")],@"P154":@[Claim(@"Studio.svg")]}};
    NSDictionary *logo=[RWDiscoveryMetadataPolicy entityProfile:entity role:@"studio"],*portrait=[RWDiscoveryMetadataPolicy entityProfile:entity role:@"person"];
    CHECK([logo[@"imageFile"]isEqual:@"Studio.svg"]&&[logo[@"imageRole"]isEqual:@"logo"]);CHECK([portrait[@"imageFile"]isEqual:@"Office.jpg"]&&[portrait[@"imageRole"]isEqual:@"portrait"]);
    CHECK(![[RWDiscoveryMetadataPolicy entityProfile:@{@"claims":@{@"P18":@[Claim(@"Office.jpg")]}} role:@"studio"][@"imageFile"]length]);
    NSMutableArray *many=[NSMutableArray new];for(int i=0;i<600;i++)[many addObject:Title([NSString stringWithFormat:@"tt%d",i],@"Film",2020,7,10000,@[@{@"id":[NSString stringWithFormat:@"Q%d",i+1],@"name":[NSString stringWithFormat:@"Person %d",i]}],@[],@[])];CHECK([RWExploreIndex records:many kind:@"People" mood:nil query:nil profile:@"regular" entities:@{} now:now].count==600);
    // A company may be credited in several relationships; title counts and
    // representative work stay deduplicated, while all verified roles survive.
    NSDictionary *company=@{@"id":@"Q50",@"name":@"Mixed Company"},*network=@{@"id":@"Q51",@"name":@"Good Network"};
    NSMutableDictionary *mixed=[Title(@"tt50",@"A strong new release",2026,8.4,100000,@[],@[],@[company])mutableCopy];mixed[@"discovery"]=@{@"studios":@[company],@"distributors":@[company],@"networks":@[]};
    NSMutableDictionary *broadcast=[Title(@"tt51",@"A well regarded show",2025,8.2,80000,@[],@[],@[])mutableCopy];broadcast[@"type"]=@"series";broadcast[@"discovery"]=@{@"networks":@[network],@"distributors":@[company]};
    NSArray *mixedRows=[RWExploreIndex records:@[mixed,broadcast] kind:@"Studios" mood:nil query:@"" profile:@"regular" entities:@{} now:now];CHECK(mixedRows.count==2);NSDictionary *companyRow=mixedRows[0],*networkRow=mixedRows[1];CHECK([companyRow[@"id"]isEqual:@"Q50"]);CHECK([companyRow[@"roles"]isEqual:@[@"studio",@"distributor"]]);CHECK([companyRow[@"creditCount"]integerValue]==2&&[companyRow[@"knownFor"]count]==2);CHECK([companyRow[@"creditRole"]isEqual:@"studio"]);CHECK([companyRow[@"kindLabel"]isEqual:@"Production · Distribution"]);CHECK([networkRow[@"roles"]isEqual:@[@"network"]]&&[networkRow[@"creditRole"]isEqual:@"network"]);CHECK([networkRow[@"kindLabel"]isEqual:@"Original broadcaster"]);CHECK([networkRow[@"knownFor"][0][@"type"]isEqual:@"series"]);
    NSArray *networkMatch=[RWExploreIndex records:@[mixed,broadcast] kind:@"Studios" mood:nil query:@"Good Network" profile:@"kids" entities:@{} now:now];CHECK(networkMatch.count==1&&[networkMatch[0][@"id"]isEqual:@"Q51"]&&[networkMatch[0][@"profileID"]isEqual:@"kids"]);
    NSArray *onlyDistribution=[RWExploreIndex records:@[broadcast] kind:@"Studios" mood:nil query:@"Mixed Company" profile:@"regular" entities:@{} now:now];CHECK(onlyDistribution.count==1&&[onlyDistribution[0][@"creditRole"]isEqual:@"distributor"]);CHECK([onlyDistribution[0][@"kindLabel"]isEqual:@"Distribution"]);
    // Future or undated credits must not create discovery entities or anchor
    // representative work, even when an upstream rating is implausibly high.
    NSMutableDictionary *future=[Title(@"tt90",@"Later this year",2026,10,900000,@[d],@[d],@[studio])mutableCopy];future[@"released"]=@"2026-12-20T00:00:00Z";
    NSDictionary *undated=Title(@"tt91",@"Undated project",0,10,900000,@[d],@[d],@[studio]);
    for(NSString *kind in @[@"People",@"Studios",@"Moods"])CHECK(![RWExploreIndex records:@[future,undated] kind:kind mood:nil query:@"" profile:@"regular" entities:@{} now:now].count);
    CHECK(![RWExploreIndex records:@[future] kind:@"Moods" mood:@"Epic adventures" query:@"" profile:@"regular" entities:@{} now:now].count);
    NSMutableDictionary *released=[future mutableCopy];released[@"released"]=@"2026-01-01T00:00:00Z";NSArray *valid;
    // A single title snapshot is deduplicated by identity; choose a distinct
    // released title for the mixed discovery case.
    released[@"id"]=@"tt92";valid=[RWExploreIndex records:@[future,released,undated] kind:@"People" mood:nil query:@"" profile:@"regular" entities:@{} now:now];CHECK(valid.count==1&&[valid[0][@"creditCount"]integerValue]==1);CHECK([valid[0][@"knownFor"][0][@"released"]isEqual:released[@"released"]]);
    // One highly-rated ensemble must not monopolize default discovery. Named
    // searches keep exact/prefix relevance; all identities/credits survive.
    NSMutableArray *ensemble=[NSMutableArray new];for(int i=0;i<6;i++)[ensemble addObject:@{@"id":[NSString stringWithFormat:@"Q%d",100+i],@"name":[NSString stringWithFormat:@"Star %d",i]}];
    NSArray *diverseTitles=@[Title(@"tt100",@"One ensemble",2020,9.5,900000,ensemble,@[],ensemble),Title(@"tt101",@"Another excellent film",2020,9,900000,@[a],@[],@[a]),Title(@"tt102",@"Excellent recent film",2026,8.7,900000,@[b],@[],@[b]),Title(@"tt103",@"Poor alternative",2020,3,900000,@[c],@[],@[c])];
    for(NSString *kind in @[@"People",@"Studios"]){NSArray *rows=[RWExploreIndex records:diverseTitles kind:kind mood:nil query:@"" profile:@"regular" entities:@{} now:now];CHECK(rows.count==9);CHECK([rows[0][@"id"]isEqual:@"Q100"]);CHECK([rows[1][@"id"]isEqual:@"Q2"]);CHECK([rows[2][@"id"]isEqual:@"Q1"]);CHECK([rows.lastObject[@"id"]isEqual:@"Q3"]);CHECK([NSSet setWithArray:[rows valueForKey:@"id"]].count==9);CHECK([rows isEqual:[RWExploreIndex records:[[diverseTitles reverseObjectEnumerator]allObjects] kind:kind mood:nil query:@"" profile:@"regular" entities:@{} now:now]]);CHECK([RWExploreIndex records:diverseTitles kind:kind mood:nil query:@"Star 3" profile:@"regular" entities:@{} now:now].count==1);CHECK([[RWExploreIndex records:diverseTitles kind:kind mood:nil query:@"Star" profile:@"regular" entities:@{} now:now]valueForKey:@"id"]&&[[[RWExploreIndex records:diverseTitles kind:kind mood:nil query:@"Star" profile:@"regular" entities:@{} now:now]valueForKey:@"id"]isEqual:[ensemble valueForKey:@"id"]]);}
    NSArray *allRows=[RWExploreIndex records:many kind:@"People" mood:nil query:nil profile:@"regular" entities:@{} now:now];CHECK(allRows.count==600&&[NSSet setWithArray:[allRows valueForKey:@"id"]].count==600);
    // Mood browsing is a recommendation surface; typing a title is deliberate search.
    NSMutableDictionary *child=[Title(@"tt700",@"Child adventure",2020,9,90000,@[a],@[],@[studio])mutableCopy];child[@"genres"]=@[@"Animation",@"Family",@"Adventure",@"Fantasy"];
    NSMutableDictionary *grown=[Title(@"tt701",@"Adult animation",2020,8,90000,@[b],@[],@[studio])mutableCopy];grown[@"genres"]=@[@"Animation",@"Adult Animation",@"Adventure",@"Fantasy"];
    NSArray *audienceTitles=@[child,grown];
    NSArray *(^audience)(NSString *,NSString *,NSString *,NSDictionary *,BOOL)=^NSArray *(NSString *kind,NSString *mood,NSString *query,NSDictionary *prefs,BOOL restricted){return [RWExploreIndex records:audienceTitles kind:kind mood:mood query:query profile:@"main" preferences:prefs restricted:restricted entities:@{} now:now];};
    NSArray *adultMood=audience(@"Moods",@"Epic adventures",@"",@{},NO);CHECK(adultMood.count==1&&[adultMood[0][@"id"]isEqual:@"tt701"]);
    NSArray *adultIndex=audience(@"Moods",nil,@"Epic",@{},NO);CHECK(adultIndex.count==1&&[adultIndex[0][@"knownFor"][0][@"id"]isEqual:@"tt701"]);
    CHECK(audience(@"Moods",@"Epic adventures",@"Child",@{},NO).count==1);
    CHECK(audience(@"Moods",@"Epic adventures",@"",@{},YES).count==2); // input already age-gated
    CHECK(audience(@"Moods",@"Epic adventures",@"",@{@"recommendationAudience":@"all_ages"},NO).count==2);
    CHECK(audience(@"People",nil,@"",@{},NO).count==2);
    CHECK(audience(@"Studios",nil,@"",@{},NO).count==1);
    CHECK([[RWExploreIndex moodDescription:@"Epic adventures"]isEqual:@"Big journeys into unfamiliar worlds."]);
    CHECK(![RWExploreIndex moodDescription:@"Unsupported mood"].length);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
