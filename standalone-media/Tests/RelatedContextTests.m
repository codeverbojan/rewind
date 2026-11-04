#import "../RWRecommendationPolicy.h"
@interface RWRecommendationPolicy (RelatedContract)
+ (NSArray *)related:(NSArray *)items current:(NSDictionary *)current profile:(NSDictionary *)profile world:(BOOL)world now:(double)now limit:(NSUInteger)limit;
@end
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSMutableDictionary *Title(NSString *key,NSArray *genres){return [@{@"id":key,@"name":key,@"type":@"movie",@"releaseInfo":@"2000",@"genres":genres,@"ageAllowed":@YES,@"imdbRating":@8,@"imdbVotes":@50000,@"discovery":@{@"primaryLanguage":@"en",@"languageSource":@"fixture",@"industry":@"other"}}mutableCopy];}
static void Refs(NSMutableDictionary *m,NSString *kind,NSArray *ids){NSMutableDictionary *d=[m[@"discovery"]mutableCopy];NSMutableArray *refs=[NSMutableArray new];for(NSString *key in ids)[refs addObject:@{@"id":key}];d[kind]=refs;m[@"discovery"]=d;}
static NSArray *Rank(NSArray *items,NSDictionary *current,NSDictionary *profile,NSUInteger limit){
#ifdef RW_BASELINE
 return [RWRecommendationPolicy rank:items current:current profile:profile world:NO requireAvailability:NO now:1792793000 limit:limit];
#else
 return [RWRecommendationPolicy related:items current:current profile:profile world:NO now:1792793000 limit:limit];
#endif
}
int main(){@autoreleasepool{
 NSDictionary *p=@{@"maxAge":@(-1)};NSMutableDictionary *space=Title(@"space",@[@"Adventure",@"Sci-Fi"]);Refs(space,@"directors",@[@"Q25191"]);Refs(space,@"themes",@[@"Q1334052"]);
 NSMutableDictionary *ice=Title(@"ice",@[@"Animation",@"Adventure",@"Comedy"]);CHECK(!Rank(@[ice],space,p,12).count);
 NSMutableDictionary *fish=Title(@"fish",@[]);NSMutableDictionary *d=[fish[@"discovery"]mutableCopy];d[@"genres"]=@[@{@"name":@"adventure film"},@{@"name":@"family film"},@{@"name":@"animated film"}];fish[@"discovery"]=d;Refs(fish,@"themes",@[@"Q1334052"]);CHECK(!Rank(@[fish],space,p,12).count);
 NSMutableDictionary *horror=Title(@"horror",@[@"Horror",@"Sci-Fi",@"Thriller"]);CHECK(!Rank(@[horror],space,p,12).count);
 NSMutableDictionary *martian=Title(@"martian",@[@"Adventure",@"Drama",@"Sci-Fi"]),*arrival=Title(@"arrival",@[@"Drama",@"Mystery",@"Sci-Fi"]),*nolan=Title(@"director",@[@"Action",@"Crime",@"Drama"]);Refs(nolan,@"directors",@[@"Q25191"]);
 CHECK(Rank(@[martian],space,p,12).count==1);CHECK(Rank(@[arrival],space,p,12).count==1);CHECK(Rank(@[nolan],space,p,12).count==1);
 NSMutableDictionary *generic=Title(@"generic",@[@"Adventure"]);generic[@"imdbRating"]=@9.9;generic[@"releaseInfo"]=@"2026";CHECK(!Rank(@[generic],space,p,12).count);
 NSMutableDictionary *studio=Title(@"studio",@[@"Romance"]);Refs(studio,@"studios",@[@"Q10"]);Refs(space,@"studios",@[@"Q10"]);CHECK(!Rank(@[studio],space,p,12).count);
 NSMutableDictionary *actor=Title(@"actor",@[@"Romance"]);Refs(actor,@"cast",@[@"Q11"]);Refs(space,@"cast",@[@"Q11"]);CHECK(!Rank(@[actor],space,p,12).count);
 // Animation is not banned. A specific genre combination and theme can bridge it.
 NSMutableDictionary *matrix=Title(@"matrix",@[@"Action",@"Sci-Fi"]),*anime=Title(@"anime",@[@"Animation",@"Action",@"Sci-Fi"]);Refs(matrix,@"themes",@[@"Q11660"]);Refs(anime,@"themes",@[@"Q11660"]);CHECK(Rank(@[anime],matrix,p,12).count==1);
 NSMutableDictionary *doc=Title(@"documentary",@[@"Documentary",@"Sci-Fi"]);CHECK(!Rank(@[doc],space,p,12).count);
 NSMutableDictionary *child=Title(@"family",@[@"Animation",@"Adventure",@"Comedy",@"Family"]),*child2=Title(@"family2",@[@"Animation",@"Adventure",@"Comedy",@"Family"]);CHECK(Rank(@[child2],child,@{@"maxAge":@7},12).count==1);
 child2[@"ageAllowed"]=@NO;CHECK(!Rank(@[child2],child,@{@"maxAge":@7},12).count);
 NSMutableDictionary *series=Title(@"series",@[@"Drama",@"Mystery",@"Sci-Fi"]),*dark=Title(@"dark",@[@"Crime",@"Drama",@"Mystery"]);series[@"type"]=@"series";dark[@"type"]=@"series";CHECK(Rank(@[dark],series,p,12).count==1);CHECK(!Rank(@[martian],series,p,12).count);
 // Canonical genre aliases and exact verified director identity survive sparse metadata.
 NSMutableDictionary *alias=Title(@"alias",@[]);d=[alias[@"discovery"]mutableCopy];d[@"genres"]=@[@{@"name":@"science fiction film"},@{@"name":@"adventure film"}];alias[@"discovery"]=d;CHECK(Rank(@[alias],space,p,12).count==1);
 NSMutableDictionary *sparse=Title(@"sparse",@[]);Refs(sparse,@"directors",@[@"Q25191"]);CHECK(Rank(@[nolan],sparse,p,12).count==1);CHECK(!Rank(@[ice],Title(@"empty",@[]),p,12).count);
 NSArray *all=@[ice,fish,martian,arrival,nolan,generic,studio,actor,horror];NSData *before=[NSJSONSerialization dataWithJSONObject:all options:NSJSONWritingSortedKeys error:nil];NSArray *ordered=Rank(all,space,p,12);
 CHECK(ordered.count==3);CHECK([[ordered valueForKey:@"id"]containsObject:@"director"]);CHECK([[ordered.firstObject objectForKey:@"id"]isEqual:@"director"]);CHECK([ordered isEqual:Rank(all,space,p,12)]);CHECK([before isEqual:[NSJSONSerialization dataWithJSONObject:all options:NSJSONWritingSortedKeys error:nil]]);
 CHECK(!Rank(all,space,p,0).count);CHECK(Rank(all,space,p,1).count==1);CHECK(!Rank(@[space],space,p,12).count);CHECK(!Rank(@[martian],space,@{@"maxAge":@(-1),@"hidden":@[@"martian"]},12).count);
 NSMutableDictionary *future=[martian mutableCopy];future[@"releaseInfo"]=@"2199";CHECK(!Rank(@[future],space,p,12).count);future[@"releaseInfo"]=@"2000";future[@"availability"]=@{@"watch_instead_of_play":@YES};CHECK(!Rank(@[future],space,p,12).count);
 NSMutableDictionary *secondary=[space mutableCopy],*crime=Title(@"crime",@[@"Crime",@"Drama",@"Thriller"]);NSMutableDictionary *secondaryD=[space[@"discovery"]mutableCopy];secondaryD[@"genres"]=@[@{@"name":@"thriller film"}];secondary[@"discovery"]=secondaryD;CHECK(!Rank(@[crime],secondary,p,12).count);
 NSMutableDictionary *low=[martian mutableCopy];low[@"imdbRating"]=@4;CHECK(!Rank(@[low],space,p,12).count);
 printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
