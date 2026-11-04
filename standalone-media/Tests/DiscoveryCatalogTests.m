#import "../RWDiscoveryCatalog.h"
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    NSDictionary *rich=@{@"id":@"tt1",@"type":@"movie",@"name":@"A film",@"poster":@"https://example.test/tt1.jpg",@"background":@"https://example.test/tt1-wide.jpg",@"description":@"A story.",@"genres":@[@"Drama"],@"imdbRating":@8.2,@"releaseInfo":@"1999",@"availability":@{@"state":@"ready"},@"videos":@[@{}]};
    NSDictionary *sparse=@{@"id":@"tt1",@"type":@"movie",@"name":@"A film",@"poster":NSNull.null,@"background":@"",@"genres":@[],@"imdbRating":@0};
    NSArray *merged=[RWDiscoveryCatalog merge:@[sparse] existing:@[rich] limit:500];NSDictionary *m=merged.firstObject;
    CHECK(merged.count==1);CHECK([m[@"poster"]isEqual:rich[@"poster"]]);CHECK([m[@"background"]isEqual:rich[@"background"]]);CHECK([m[@"description"]isEqual:rich[@"description"]]);CHECK([m[@"genres"]isEqual:rich[@"genres"]]);CHECK([m[@"imdbRating"]doubleValue]==8.2);
    CHECK(!m[@"availability"]&&!m[@"videos"]);CHECK(rich[@"availability"]&&sparse[@"poster"]==NSNull.null);
    m=[RWDiscoveryCatalog merge:@[@{@"id":@"tt1",@"type":@"movie",@"name":@"Updated title",@"imdbRating":@8.4}] existing:@[rich] limit:500].firstObject;
    CHECK([m[@"name"]isEqual:@"Updated title"]&&[m[@"imdbRating"]doubleValue]==8.4&&m[@"poster"]);
    m=[RWDiscoveryCatalog merge:@[@{@"id":@"tt1",@"type":@"series",@"name":@"Wrong show"}] existing:@[rich] limit:500].firstObject;CHECK([m[@"name"]isEqual:@"A film"]&&[m[@"type"]isEqual:@"movie"]);
    // A malformed movie catalog entry must not turn numbered TV episodes into a film.
    NSDictionary *wrongFilm=@{@"id":@"tt99",@"type":@"movie",@"name":@"Serialized story",@"videos":@[@{@"id":@"tt99:1:2",@"season":@1,@"episode":@2}],@"availability":@{@"discovery_eligible":@YES},@"episodeVideoID":@"tt99"};
    NSDictionary *fixed=[RWDiscoveryCatalog balancedPool:@[@[wrongFilm]] limit:10 allows:nil].firstObject;
    CHECK([fixed[@"type"]isEqual:@"series"]);CHECK(!fixed[@"availability"]&&!fixed[@"episodeVideoID"]);CHECK([wrongFilm[@"type"]isEqual:@"movie"]);
    fixed=[RWDiscoveryCatalog merge:@[] existing:@[wrongFilm] limit:10].firstObject;
    CHECK([fixed[@"type"]isEqual:@"series"]);CHECK(!fixed[@"videos"]&&!fixed[@"availability"]);
    NSMutableDictionary *plain=[wrongFilm mutableCopy];plain[@"videos"]=@[@{@"id":@"tt999:1:2",@"season":@1,@"episode":@2}];
    CHECK([[[RWDiscoveryCatalog balancedPool:@[@[plain]] limit:10 allows:nil].firstObject objectForKey:@"type"]isEqual:@"movie"]);
    plain[@"videos"]=@[@{@"id":@"tt99:1:2",@"season":@1,@"episode":@1}];
    CHECK([[[RWDiscoveryCatalog balancedPool:@[@[plain]] limit:10 allows:nil].firstObject objectForKey:@"type"]isEqual:@"movie"]);
    plain[@"videos"]=@[@{@"id":@"tt99:0:0",@"season":@0,@"episode":@0}];
    CHECK([[[RWDiscoveryCatalog balancedPool:@[@[plain]] limit:10 allows:nil].firstObject objectForKey:@"type"]isEqual:@"movie"]);
    NSDictionary *second=@{@"id":@"tt2",@"type":@"movie",@"name":@"B film"};
    merged=[RWDiscoveryCatalog merge:@[second,second] existing:@[rich,second] limit:500];CHECK(merged.count==2&&[merged[0][@"id"]isEqual:@"tt2"]&&[merged[1][@"id"]isEqual:@"tt1"]);
    CHECK([RWDiscoveryCatalog merge:@[NSNull.null,@{@"id":@"tt3",@"type":NSNull.null}] existing:@[rich] limit:500].count==1);
    CHECK([RWDiscoveryCatalog merge:@[second] existing:@[rich] limit:1].count==1);CHECK(![RWDiscoveryCatalog merge:@[second] existing:@[rich] limit:0].count);
    NSMutableArray *large=[NSMutableArray new];for(int i=0;i<700;i++)[large addObject:@{@"id":[NSString stringWithFormat:@"tt%d",i],@"name":@"Title",@"type":@"movie"}];CHECK([RWDiscoveryCatalog merge:large existing:@[] limit:999].count==500);
    NSArray *episodes=@[@{@"id":@"show",@"episodeVideoID":@"show:2:3"},@{@"id":@"show",@"episodeVideoID":@"show:1:5"},rich,second];
    NSArray *visible=[RWDiscoveryCatalog uniqueVisible:episodes excluding:[NSSet setWithObject:@"tt1"] hidden:@[@"tt2"] limit:12];CHECK(visible.count==1&&[visible[0][@"episodeVideoID"]isEqual:@"show:2:3"]);
    CHECK([RWDiscoveryCatalog uniqueVisible:episodes excluding:nil hidden:nil limit:12].count==3);CHECK([RWDiscoveryCatalog uniqueVisible:episodes excluding:nil hidden:nil limit:1].count==1);CHECK(![RWDiscoveryCatalog uniqueVisible:episodes excluding:nil hidden:nil limit:0].count);
    NSArray *sorted=[RWDiscoveryCatalog sortCredits:@[second,@{@"id":@"tt3",@"name":@"C film",@"imdbRating":NSNull.null,@"releaseInfo":NSNull.null},rich] byRating:YES];CHECK([sorted[0][@"id"]isEqual:@"tt1"]);CHECK([sorted[1][@"id"]isEqual:@"tt2"]);
    sorted=[RWDiscoveryCatalog sortCredits:sorted byRating:NO];CHECK([sorted[0][@"id"]isEqual:@"tt1"]);CHECK(![RWDiscoveryCatalog sortCredits:nil byRating:YES].count);
    NSDictionary *home=@{@"hero":@{},@"rows":@[@{@"id":@"for-you",@"title":@"For you",@"items":@[rich]}]};
    NSDictionary *arrival=@{@"hero":second,@"rows":@[@{@"id":@"for-you",@"title":@"For you",@"items":@[second,rich]},@{@"id":@"world",@"title":@"World Cinema",@"items":@[second,@{@"id":@"tt3",@"name":@"C"}]}]};
    NSDictionary *filled=[RWDiscoveryCatalog mergeHome:home incoming:arrival];NSArray *rails=filled[@"rows"];
    CHECK(rails.count==2&&[rails[0][@"id"]isEqual:@"for-you"]);CHECK([rails[0][@"items"][0][@"id"]isEqual:@"tt1"]&&[rails[0][@"items"][1][@"id"]isEqual:@"tt2"]);CHECK([rails[1][@"items"]count]==1);CHECK(![filled[@"hero"]count]);CHECK([home[@"rows"][0][@"items"]count]==1);
    CHECK([RWDiscoveryCatalog mergeHome:filled incoming:arrival][@"rows"]&&[[RWDiscoveryCatalog mergeHome:filled incoming:arrival][@"rows"]isEqual:rails]);CHECK([[RWDiscoveryCatalog mergeHome:nil incoming:arrival][@"hero"]isEqual:second]);
    // Reproduce a full row whose old candidates expired. Filtering only while
    // drawing hid the cards but left all 12 slots occupied in the saved page.
    NSMutableArray *oldCards=[NSMutableArray new];for(int i=0;i<12;i++)[oldCards addObject:@{@"id":[NSString stringWithFormat:@"old-%d",i]}];
    NSDictionary *full=@{@"hero":rich,@"rows":@[@{@"id":@"for-you",@"items":oldCards},@{@"id":@"older",@"items":@[second]}]};
    NSDictionary *newPage=@{@"hero":rich,@"rows":@[@{@"id":@"for-you",@"items":@[@{@"id":@"new-1"},@{@"id":@"old-0"},@{@"id":@"new-2"}]}]};
    CHECK([[RWDiscoveryCatalog mergeHome:full incoming:newPage][@"rows"][0][@"items"]count]==12);
    NSSet *eligible=[NSSet setWithArray:@[@"old-2",@"old-7",@"new-1",@"new-2",@"tt2"]];BOOL(^allows)(NSDictionary *,NSString *,BOOL)=^BOOL(NSDictionary *m,NSString *row,BOOL hero){return !hero&&[eligible containsObject:m[@"id"]];};
    NSDictionary *pruned=[RWDiscoveryCatalog filterHome:full allows:allows];CHECK(![pruned[@"hero"]count]);CHECK([pruned[@"rows"][0][@"items"]count]==2);CHECK([full[@"rows"][0][@"items"]count]==12);
    NSDictionary *repaired=[RWDiscoveryCatalog mergeHome:pruned incoming:[RWDiscoveryCatalog filterHome:newPage allows:allows]];
    NSArray *repairedCards=repaired[@"rows"][0][@"items"];CHECK(repairedCards.count==4);CHECK([repairedCards[0][@"id"]isEqual:@"old-2"]&&[repairedCards[1][@"id"]isEqual:@"old-7"]);CHECK([repairedCards[2][@"id"]isEqual:@"new-1"]&&[repairedCards[3][@"id"]isEqual:@"new-2"]);CHECK([repaired[@"rows"][1][@"items"][0][@"id"]isEqual:@"tt2"]);
    CHECK([[RWDiscoveryCatalog filterHome:repaired allows:allows]isEqual:repaired]);CHECK(![RWDiscoveryCatalog filterHome:nil allows:allows].count);
    NSDictionary *empty=[RWDiscoveryCatalog filterHome:full allows:^BOOL(NSDictionary *m,NSString *row,BOOL hero){return NO;}];CHECK([empty[@"rows"]count]==2&&! [empty[@"rows"][0][@"items"]count]);
    CHECK([[RWDiscoveryCatalog mergeHome:empty incoming:[RWDiscoveryCatalog filterHome:newPage allows:allows]][@"rows"][0][@"items"]count]==2);
    NSDictionary *oldTheme=@{@"rows":@[@{@"id":@"mood",@"title":@"Epic adventures",@"items":@[rich]},@{@"id":@"series",@"title":@"Series",@"items":@[second]}]};
    NSDictionary *newTheme=@{@"layoutVersion":@40,@"rows":@[@{@"id":@"mood",@"title":@"Slow burn",@"items":@[second]},@{@"id":@"more",@"title":@"More to discover",@"items":@[rich]}]};
    NSDictionary *themed=[RWDiscoveryCatalog mergeHome:oldTheme incoming:newTheme];
    CHECK([themed[@"rows"]count]==2);CHECK([themed[@"rows"][0][@"title"]isEqual:@"Slow burn"]);CHECK([themed[@"rows"][0][@"items"]count]==1);CHECK([themed[@"rows"][0][@"items"][0][@"id"]isEqual:@"tt2"]);CHECK([themed[@"rows"][1][@"items"][0][@"id"]isEqual:@"tt1"]);
    NSDictionary *typedOld=@{@"layoutVersion":@46,@"hero":@{},@"rows":@[@{@"id":@"typed",@"title":@"Series for you",@"mediaType":@"movie",@"items":@[rich]}]};
    NSDictionary *show=@{@"id":@"show",@"type":@"series",@"name":@"A series"};NSDictionary *typedNew=@{@"layoutVersion":@46,@"hero":@{},@"rows":@[@{@"id":@"typed",@"title":@"Series for you",@"mediaType":@"series",@"items":@[show,rich]}]};
    NSDictionary *typedPage=[RWDiscoveryCatalog mergeHome:typedOld incoming:typedNew];CHECK([typedPage[@"rows"][0][@"items"]count]==1&&[typedPage[@"rows"][0][@"items"][0][@"id"]isEqual:@"show"]);
    // Real157 failure: ranking rotates its franchise representative while a
    // stable Home keeps the prior card. Merging must retain the old position
    // without accumulating sequels or treating studio lists as franchises.
    NSDictionary *franchise=@{@"id":@"Q2316015",@"instanceOf":@[@"Q196600"]},*list=@{@"id":@"Q2732470",@"instanceOf":@[@"Q13406463"]};
    NSDictionary *toy=@{@"id":@"toy",@"type":@"movie",@"discovery":@{@"franchises":@[franchise,list]}},*sequel=@{@"id":@"sequel",@"type":@"movie",@"discovery":@{@"franchises":@[franchise,list]}},*fish=@{@"id":@"fish",@"type":@"movie",@"discovery":@{@"franchises":@[list]}};
    NSDictionary *(^page)(NSArray *)=^NSDictionary *(NSArray *items){return @{@"layoutVersion":@51,@"hero":@{},@"rows":@[@{@"id":@"films",@"mediaType":@"movie",@"title":@"Films",@"items":items}]};};
    NSDictionary *steady=[RWDiscoveryCatalog mergeHome:page(@[toy]) incoming:page(@[sequel,fish])];NSArray *steadyIDs=[steady[@"rows"][0][@"items"]valueForKey:@"id"];
    CHECK([steadyIDs isEqual:@[@"toy",@"fish"]]);CHECK([[[RWDiscoveryCatalog mergeHome:steady incoming:page(@[sequel,fish])][@"rows"][0][@"items"]valueForKey:@"id"]isEqual:steadyIDs]);
    CHECK([[[RWDiscoveryCatalog mergeHome:page(@[toy,sequel]) incoming:page(@[fish])][@"rows"][0][@"items"]valueForKey:@"id"]isEqual:steadyIDs]);
    NSMutableDictionary *heroPage=[page(@[fish])mutableCopy];heroPage[@"hero"]=toy;CHECK([[[RWDiscoveryCatalog mergeHome:heroPage incoming:page(@[sequel,fish])][@"rows"][0][@"items"]valueForKey:@"id"]isEqual:@[@"fish"]]);
    NSDictionary *prunedFranchise=[RWDiscoveryCatalog filterHome:page(@[toy]) allows:^BOOL(NSDictionary *m,NSString *row,BOOL hero){return ![m[@"id"]isEqual:@"toy"];}];CHECK([[[RWDiscoveryCatalog mergeHome:prunedFranchise incoming:page(@[sequel,fish])][@"rows"][0][@"items"]valueForKey:@"id"]isEqual:@[@"sequel",@"fish"]]);
    NSMutableDictionary *newLayout=[arrival mutableCopy];newLayout[@"layoutVersion"]=@168;
    CHECK([[RWDiscoveryCatalog mergeHome:home incoming:newLayout]isEqual:newLayout]);
    // The migration is one-time; new-layout membership still remains stable.
    NSMutableDictionary *stableLayout=[home mutableCopy];stableLayout[@"layoutVersion"]=@168;
    CHECK([[[RWDiscoveryCatalog mergeHome:stableLayout incoming:newLayout][@"rows"][0][@"items"]valueForKey:@"id"]isEqual:@[@"tt1",@"tt2"]]);
    NSMutableDictionary *leadingLayout=[arrival mutableCopy];leadingLayout[@"layoutVersion"]=@229;
    CHECK([[RWDiscoveryCatalog mergeHome:newLayout incoming:leadingLayout]isEqual:leadingLayout]);
    NSMutableDictionary *stableLeading=[home mutableCopy];stableLeading[@"layoutVersion"]=@229;
    CHECK([[[RWDiscoveryCatalog mergeHome:stableLeading incoming:leadingLayout][@"rows"][0][@"items"]valueForKey:@"id"]isEqual:@[@"tt1",@"tt2"]]);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
