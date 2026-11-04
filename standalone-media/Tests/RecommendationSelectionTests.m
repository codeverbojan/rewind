#import "../RWRecommendationPolicy.h"
#import "../RWHomeCategoryPolicy.h"
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSArray *Titles(NSUInteger count){NSMutableArray *items=[NSMutableArray new];for(NSUInteger i=0;i<count;i++){
    NSString *key=[NSString stringWithFormat:@"tt%07lu",(unsigned long)(9000000+i)];
    NSArray *genres=i%9==0?@[]:i%3==0?@[@"Thriller",@"Crime"]:i%3==1?@[@"Family",@"Comedy"]:@[@"Adventure",@"Fantasy"];
    NSDictionary *discovery=@{@"primaryLanguage":i%5==0?@"fr":@"en",@"industry":@"other",@"directors":i%7==0?@[]:@[@{@"id":[NSString stringWithFormat:@"Q%lu",(unsigned long)(200+i%19)]}],@"franchises":i%4?@[]:@[@{@"id":@"Q100",@"instanceOf":@[@"Q196600"]}],@"cast":i%9==0?@[]:@[@{@"id":[NSString stringWithFormat:@"Q%lu",(unsigned long)(500+i%23)]}],@"themes":i%9==0?@[]:@[@{@"id":[NSString stringWithFormat:@"Q%lu",(unsigned long)(700+i%11)],@"name":@"identity"}]};
    [items addObject:@{@"id":key,@"name":key,@"type":i%3==0?@"series":@"movie",@"genres":genres,@"discovery":discovery,@"releaseInfo":[NSString stringWithFormat:@"%lu",(unsigned long)(1950+i%77)],@"released":i%29==0?@"2199-01-01":@"2000-01-01",@"ageAllowed":@(i%4!=0),@"imdbRating":@(7+(i%20)*.1),@"imdbVotes":@(10000+i*100),@"availability":@{@"discovery_eligible":@(i%11!=0),@"hero_eligible":@(i%13==0),@"watch_instead_of_play":@(i%17==0)}}];
}return items;}
static NSDictionary *HomeWithoutTime(NSDictionary *home){NSMutableDictionary *copy=[home mutableCopy];[copy removeObjectForKey:@"seconds"];
    // 161 adds continuation recipe inputs, without changing initial ranking.
    // Compare every original field against the independent reference; verify
    // the added descriptors separately below.
    NSMutableArray *rows=[NSMutableArray new];for(NSDictionary *row in copy[@"rows"]){NSMutableDictionary *r=[row mutableCopy];[r removeObjectForKey:@"anchor"];[r removeObjectForKey:@"mood"];[rows addObject:r];}copy[@"rows"]=rows;return copy;}
int main(){@autoreleasepool{
    Class reference=NSClassFromString(@"RWRecommendationReference72");CHECK(reference!=Nil);double now=1792683561;
    NSArray *signals=Titles(24);NSUInteger counts[]={0,1,2,39,40,41,79,80,81,500,524},limits[]={0,1,8,40,100};
    for(NSUInteger c=0;c<sizeof(counts)/sizeof(counts[0]);c++){@autoreleasepool{
        NSArray *items=Titles(counts[c]);NSData *before=[NSJSONSerialization dataWithJSONObject:items options:NSJSONWritingSortedKeys error:nil];
        for(NSUInteger mode=0;mode<3;mode++){
            // Preserve the independent rank-order comparison under explicit all-ages intent.
            // Default grown-up admission is covered by DiscoveryRecommendationTests.
            NSDictionary *profile=@{@"maxAge":mode==2?@7:@(-1),@"liked":mode==0?@[]:[signals subarrayWithRange:NSMakeRange(0,6)],@"saved":mode==0?@[]:[signals subarrayWithRange:NSMakeRange(6,6)],@"hidden":@[@"tt9000010"],@"history":@{},@"discoveryPreferences":@{@"recommendationAudience":@"all_ages",@"languageMode":mode==1?@"all":@"english_first",@"worldCinema":@YES},@"pageDirectorCounts":@{@"Q207":@2},@"pageFranchises":@[@"Q100"]};
            // 167 intentionally changes Home recipes and row allocation. Keep the
            // independent ranker parity below, and test new Home semantics here.
            NSDictionary *actual=[RWRecommendationPolicy home:items profile:profile year:2026 now:now];
            CHECK([HomeWithoutTime(actual)isEqual:HomeWithoutTime([RWRecommendationPolicy home:items profile:profile year:2026 now:now])]);
            CHECK([actual[@"layoutVersion"]integerValue]==229&&[actual[@"rows"]count]<=12);
            NSMutableSet *assigned=[NSMutableSet new];if([actual[@"hero"][@"id"]length])[assigned addObject:actual[@"hero"][@"id"]];
            for(NSDictionary *row in actual[@"rows"]){CHECK([row[@"items"]count]>=[row[@"minimumCount"]unsignedIntegerValue]);for(NSDictionary *m in row[@"items"]){CHECK(![assigned containsObject:m[@"id"]]);[assigned addObject:m[@"id"]];CHECK([m[@"type"]isEqual:row[@"mediaType"]]);CHECK([m[@"availability"][@"discovery_eligible"]boolValue]&&![m[@"availability"][@"watch_instead_of_play"]boolValue]);if(mode==2)CHECK([m[@"ageAllowed"]boolValue]);if([row[@"recipe"]isEqual:@"category"])CHECK([RWHomeCategoryPolicy matches:m category:row]);}}

            for(NSDictionary *row in actual[@"rows"]){if([row[@"recipe"]isEqual:@"mood"])CHECK([row[@"mood"]length]&&[row[@"title"]hasSuffix:row[@"mood"]]);if([row[@"recipe"]isEqual:@"because"])CHECK([row[@"anchor"][@"id"]length]&&[row[@"id"]hasSuffix:row[@"anchor"][@"id"]]);}
            for(NSUInteger l=0;l<sizeof(limits)/sizeof(limits[0]);l++)for(NSUInteger kind=0;kind<3;kind++){
                NSDictionary *current=kind==2?signals[7]:nil;BOOL world=kind==1,require=kind!=2;
                // 142 intentionally limits contextual recommendations to the
                // current media type. Preserve the independent old ranker for
                // ordering within that admissible pool; new coverage tests
                // separately prove wrong-type/featureless rejection.
                NSArray *referenceItems=current?[items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *m,NSDictionary *bindings){return [m[@"type"]isEqual:current[@"type"]];}]]:items;
                // 178 intentionally rejects non-family Kids candidates. Keep
                // parity inside this fixture's explicit Family subset; the
                // KidsAudience suite separately tests the new admission rule.
                if(mode==2)referenceItems=[referenceItems filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *m,NSDictionary *bindings){return [m[@"genres"]containsObject:@"Family"];}]];
                NSArray *old=[reference rank:referenceItems current:current profile:profile world:world requireAvailability:require now:now limit:limits[l]],*fresh=[RWRecommendationPolicy rank:referenceItems current:current profile:profile world:world requireAvailability:require now:now limit:limits[l]];
                CHECK([old isEqual:fresh]);CHECK(fresh.count<=MIN(limits[l],40));
            }
        }
        CHECK([before isEqual:[NSJSONSerialization dataWithJSONObject:items options:NSJSONWritingSortedKeys error:nil]]);
    }}
    // Empty and identical feature vectors; ties; duplicate identities carrying
    // different metadata. Selection must keep the old deterministic ordering.
    NSMutableArray *duplicates=[NSMutableArray new];for(NSUInteger i=0;i<90;i++){NSMutableDictionary *m=[Titles(1).firstObject mutableCopy];m[@"id"]=[NSString stringWithFormat:@"duplicate-%lu",(unsigned long)(i%45)];m[@"released"]=@"2000-01-01";m[@"discovery"]=@{@"primaryLanguage":@"en",@"industry":@"other"};m[@"genres"]=i%2?@[@"Drama"]:@[];m[@"availability"]=@{@"discovery_eligible":@YES};[duplicates addObject:m];}
    NSDictionary *regular=@{@"maxAge":@(-1)};
    CHECK([[reference rank:duplicates current:nil profile:regular world:NO requireAvailability:YES now:now limit:100]isEqual:[RWRecommendationPolicy rank:duplicates current:nil profile:regular world:NO requireAvailability:YES now:now limit:100]]);
    // A new pass must see changes to the very same metadata objects. Reuse is
    // deliberately pass-scoped, not a stale process-global recommendation cache.
    for(NSUInteger pass=0;pass<3;pass++){
        duplicates[0][@"genres"]=pass==1?@[@"Crime",@"Thriller"]:@[@"Drama"];duplicates[0][@"imdbRating"]=@(7+pass);
        CHECK([HomeWithoutTime([RWRecommendationPolicy home:duplicates profile:regular year:2026 now:now])isEqual:HomeWithoutTime([RWRecommendationPolicy home:duplicates profile:regular year:2026 now:now])]);
    }
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
