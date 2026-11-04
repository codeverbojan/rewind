#import "RWHomePreparation.h"
#import "RWMediaIdentity.h"
#import "RWDiscoveryMetadataPolicy.h"
#import "RWRecommendationPolicy.h"
#import "RWHomeDelivery.h"
#import "RWEpisodeCatalog.h"
#include <math.h>
#include <float.h>
static NSDictionary *Map(id v){return [v isKindOfClass:NSDictionary.class]?v:@{};}
static NSArray *List(id v){return [v isKindOfClass:NSArray.class]?v:@[];}
static NSString *Text(id v){return [v isKindOfClass:NSString.class]?v:@"";}
static double Number(id v){return [v isKindOfClass:NSString.class]||[v isKindOfClass:NSNumber.class]?[v doubleValue]:0;}
static NSString *Identifier(NSDictionary *m){return Text(m[@"id"]?:m[@"imdb_id"]);}
static NSDictionary *Scope(NSDictionary *input,NSDictionary *ratings,NSString *profileID,NSArray *priors){
    NSDictionary *profile=Map(input[@"profile"]);
    // Exposure/like changes affect ranking and live exclusions, not the
    // prepared title. All inputs to age/episode/availability/metadata do matter.
    NSMutableDictionary *scope=[NSMutableDictionary new];
    for(NSString *key in @[@"family",@"shows",@"metadata",@"ageRatings",@"quality",@"offline",@"offlineAt"])if(input[key])scope[key]=input[key];
    for(NSString *key in @[@"maxAge",@"discoveryPreferences",@"history",@"sourceAvailability"])if(profile[key])scope[key]=profile[key];
    scope[@"ratings"]=ratings?:@{};scope[@"profileID"]=profileID?:@"";scope[@"priors"]=priors?:@[];return scope;
}
static BOOL Same(id a,id b){return a==b||(a&&b&&[a isEqual:b]);}
static BOOL EntryMatches(NSDictionary *entry,NSString *key,NSDictionary *old,NSDictionary *current){
    if(RWNormalizeMediaIdentity(entry[@"meta"],current[@"shows"][key])!=entry[@"meta"])return NO;
    for(NSString *field in @[@"metadata",@"ratings"])if(!Same(old[field][key],current[field][key]))return NO;
    for(NSString *field in @[@"cache",@"publishers"])if(!Same(old[@"ageRatings"][field][key],current[@"ageRatings"][field][key]))return NO;
    NSString *video=entry[@"videoID"];if(!Same(old[@"sourceAvailability"][video],current[@"sourceAvailability"][video])||!Same(old[@"offline"][video],current[@"offline"][video]))return NO;
    if((old[@"offline"][video]||current[@"offline"][video])&&!Same(old[@"offlineAt"],current[@"offlineAt"]))return NO;
    if([entry[@"meta"][@"type"]isEqual:@"series"]){
        // Shows are explicitly owned immutable records. A replacement needs
        // fresh episode preparation; never deep-compare thousands of episodes.
        if(old[@"shows"][key]!=current[@"shows"][key])return NO;
        NSString *prefix=[key stringByAppendingString:@":"];NSMutableSet *ids=[NSMutableSet setWithArray:Map(old[@"history"]).allKeys];[ids addObjectsFromArray:Map(current[@"history"]).allKeys];
        for(NSString *identifier in ids)if([identifier hasPrefix:prefix]&&!Same(old[@"history"][identifier],current[@"history"][identifier]))return NO;
    }return YES;
}
static double Deadline(NSDictionary *input,double now,NSString *video,BOOL series){
    // Bound reuse even with no publication. Expire sooner at every relevant
    // observation boundary and at UTC midnight (date-only release policy).
    double end=MIN(now+(series?30:300),(floor(now/86400)+1)*86400);
    for(NSDictionary *observation in @[Map(Map(Map(input[@"profile"])[@"sourceAvailability"])[video])]){
        double ttl=[observation[@"state"]isEqual:@"candidates"]?86400:[observation[@"state"]isEqual:@"waiting"]?3600:180;
        for(NSArray *pair in @[@[@"checked",@(ttl)],@[@"ready_at",@300],@[@"unready_at",@86400]]){
            double at=[observation[pair[0]]doubleValue];if(!isfinite(at)||at<=0)continue;
            if(at>now)end=MIN(end,at);double expires=at+[pair[1]doubleValue];if(expires>now)end=MIN(end,expires);
        }
    }
    if(series){NSString *title=[[video componentsSeparatedByString:@":"]firstObject];double deadline=RWEpisodeMetadataDeadline(Map(Map(input[@"shows"])[title]));if(deadline>0)end=MIN(end,deadline);}
    if(Map(input[@"offline"])[video]){double offline=[input[@"offlineAt"]doubleValue];if(offline>now)end=MIN(end,offline);if(offline>0&&offline+120>now)end=MIN(end,offline+120);}return end;
}
@implementation RWHomePreparation
+ (BOOL)entry:(NSDictionary *)entry matchesTitle:(NSDictionary *)title {
    if(![entry[@"meta"][@"type"]isEqual:title[@"type"]])return NO;
    // Published ranking records are immutable by ownership contract. Keeping
    // their identity avoids rebuilding an identical title dictionary on Home.
    if(entry[@"input"]==title)return YES;
    return [(entry[@"source"]?:entry[@"meta"])isEqual:[RWHomeDelivery titleMetadata:title]];
}
+ (BOOL)allows:(NSDictionary *)m preferences:(NSDictionary *)prefs restricted:(BOOL)restricted world:(BOOL)world hero:(BOOL)hero priors:(NSArray *)priors {
    if(![RWDiscoveryMetadataPolicy recommendationAudienceAllows:m preferences:prefs restricted:restricted])return NO;
    if(![RWRecommendationPolicy homeQualityEligible:m]||(restricted&&![RWDiscoveryMetadataPolicy isFamilyTitle:m]))return NO;
    if(![m[@"availability"][hero?@"hero_eligible":@"discovery_eligible"]boolValue])return NO;
    if(!restricted&&![RWDiscoveryMetadataPolicy permits:m preferences:prefs world:world])return NO;
    if(world){double rating=Number(m[@"imdbRating"]),votes=Number(m[@"imdbVotes"]);
        if(!isfinite(rating)||!isfinite(votes)||rating>10||![[RWDiscoveryMetadataPolicy languageGroup:m[@"discovery"]]isEqual:@"world"]||![prefs[@"worldCinema"]boolValue]||rating<[prefs[@"worldMinRating"]doubleValue]||votes<2000)return NO;
        double prior=priors.count==2?[priors[0]doubleValue]:6.5;if([RWRecommendationPolicy quality:m prior:prior]<7.2)return NO;
    }return YES;
}
+ (NSDictionary *)prepare:(NSDictionary *)home snapshot:(NSDictionary *)input ratings:(NSDictionary *)ratings profileID:(NSString *)profileID now:(double)now {
    if(!isfinite(now)||now<=0||!profileID.length)return @{};
    double began=NSProcessInfo.processInfo.systemUptime;NSDictionary *prefs=[RWDiscoveryMetadataPolicy preferences:input[@"profile"][@"discoveryPreferences"]];BOOL restricted=[input[@"profile"][@"maxAge"]integerValue]>=0;NSArray *priors=List(home[@"ratingPriors"]);
    NSMutableArray *titles=[NSMutableArray arrayWithObject:Map(home[@"hero"])];NSUInteger rows=0,limit=[home[@"migratedLayout"]boolValue]?14:12;for(NSDictionary *row in List(home[@"rows"])){if(rows++==limit)break;NSArray *items=List(row[@"items"]);[titles addObjectsFromArray:items.count>12?[items subarrayWithRange:NSMakeRange(0,12)]:items];}
    NSMutableDictionary *entries=[NSMutableDictionary new];double validUntil=now+300;
    for(NSDictionary *raw in titles){NSString *key=Identifier(raw);if(!key.length||entries[key])continue;NSDictionary *meta=[RWHomeDelivery titleMetadata:raw];BOOL ageAllowed=[raw[@"ageAllowed"]boolValue];
        BOOL series=[raw[@"type"]isEqual:@"series"];NSString *video=series?Text(raw[@"episodeVideoID"]):key;double until=Deadline(input,now,video,series);validUntil=MIN(validUntil,until);
        entries[key]=@{@"input":raw,@"meta":meta,@"videoID":video,@"validUntil":@(until),@"regular":@(ageAllowed&&[self allows:meta preferences:prefs restricted:restricted world:NO hero:NO priors:priors]),@"world":@(ageAllowed&&[self allows:meta preferences:prefs restricted:restricted world:YES hero:NO priors:priors]),@"hero":@(ageAllowed&&[self allows:meta preferences:prefs restricted:restricted world:NO hero:YES priors:priors])};
    }
    return @{@"scope":Scope(input,ratings,profileID,priors),@"entries":entries,@"preparedAt":@(now),@"validUntil":@(validUntil),@"worker_seconds":@(NSProcessInfo.processInfo.systemUptime-began),@"off_main":@(!NSThread.isMainThread)};
}
+ (NSDictionary *)usable:(NSDictionary *)prepared snapshot:(NSDictionary *)input ratings:(NSDictionary *)ratings profileID:(NSString *)profileID priors:(NSArray *)priors now:(double)now {
    if(!prepared.count||!isfinite(now)||now<[prepared[@"preparedAt"]doubleValue])return nil;
    NSDictionary *old=prepared[@"scope"],*current=Scope(input,ratings,profileID,priors);
    for(NSString *key in @[@"profileID",@"maxAge",@"discoveryPreferences",@"quality",@"family",@"priors"])if(!Same(old[key],current[key]))return nil;
    NSMutableDictionary *entries=[NSMutableDictionary new];double until=DBL_MAX;
    for(NSString *key in prepared[@"entries"]){NSDictionary *entry=prepared[@"entries"][key];double deadline=[entry[@"validUntil"]doubleValue];if(now<deadline&&EntryMatches(entry,key,old,current)){entries[key]=entry;until=MIN(until,deadline);}}
    // The owner only needs the small validated map, not a retained second
    // copy of the worker's full input scope during UI construction.
    return entries.count?@{@"entries":entries,@"validUntil":@(until)}:nil;
}
+ (BOOL)matches:(NSDictionary *)prepared snapshot:(NSDictionary *)input ratings:(NSDictionary *)ratings profileID:(NSString *)profileID priors:(NSArray *)priors now:(double)now {
    NSDictionary *usable=[self usable:prepared snapshot:input ratings:ratings profileID:profileID priors:priors now:now];return usable&&[usable[@"entries"]count]==[prepared[@"entries"]count];
}
@end

@implementation RWHomeValidation {
    NSDictionary *_ranked,*_fallback,*_current;
    BOOL _rankedValid,_fallbackValid;
    double _began;
    NSMapTable *_decisions,*_titles,*_metadata;
    NSUInteger _dependencyChecks,_decisionHits,_titleHits,_rankedHits,_fallbackHits,_sourceChecks;
}
static BOOL ValidScope(NSDictionary *batch,NSDictionary *current,double now){
    if(!batch.count||!isfinite(now)||now<[batch[@"preparedAt"]doubleValue])return NO;
    NSDictionary *old=batch[@"scope"];
    for(NSString *key in @[@"profileID",@"maxAge",@"discoveryPreferences",@"quality",@"family",@"priors"])if(!Same(old[key],current[key]))return NO;
    return YES;
}
- (instancetype)initWithRanked:(NSDictionary *)ranked fallback:(NSDictionary *)fallback snapshot:(NSDictionary *)input ratings:(NSDictionary *)ratings profileID:(NSString *)profileID priors:(NSArray *)priors now:(double)now {
    if((self=[super init])){_ranked=ranked;_fallback=fallback;_current=Scope(input,ratings,profileID,priors);_began=now;
        _rankedValid=ValidScope(ranked,_current,now);_fallbackValid=ValidScope(fallback,_current,now);
        NSPointerFunctionsOptions keys=NSPointerFunctionsStrongMemory|NSPointerFunctionsObjectPointerPersonality;
        _decisions=[NSMapTable mapTableWithKeyOptions:keys valueOptions:NSPointerFunctionsStrongMemory];
        _titles=[NSMapTable mapTableWithKeyOptions:keys valueOptions:NSPointerFunctionsStrongMemory];
        _metadata=[NSMapTable mapTableWithKeyOptions:keys valueOptions:NSPointerFunctionsStrongMemory];
    }return self;
}
- (BOOL)live:(NSDictionary *)entry now:(double)now {return entry&&isfinite(now)&&now>=_began&&now<[entry[@"validUntil"]doubleValue];}
- (BOOL)validate:(NSDictionary *)entry batch:(NSDictionary *)batch key:(NSString *)key now:(double)now {
    if(![self live:entry now:now])return NO;
    NSNumber *known=[_decisions objectForKey:entry];if(known){_decisionHits++;return known.boolValue;}
    _dependencyChecks++;BOOL valid=EntryMatches(entry,key,batch[@"scope"],_current);[_decisions setObject:@(valid) forKey:entry];return valid;
}
- (NSDictionary *)entryForTitle:(NSDictionary *)title now:(double)now {
    if(!title||!isfinite(now)||now<_began)return nil;
    NSDictionary *known=[_titles objectForKey:title];if([self live:known now:now]){_titleHits++;return known;}
    NSString *key=Identifier(title);if(!key.length)return nil;
    for(NSUInteger i=0;i<2;i++){
        if(i?!_fallbackValid:!_rankedValid)continue;NSDictionary *batch=i?_fallback:_ranked,*entry=batch[@"entries"][key];
        if(![self live:entry now:now])continue;
        _sourceChecks++;if(![RWHomePreparation entry:entry matchesTitle:title])continue;
        if(![self validate:entry batch:batch key:key now:now])continue;
        [_titles setObject:entry forKey:title];[_metadata setObject:entry forKey:entry[@"meta"]];if(i)_fallbackHits++;else _rankedHits++;return entry;
    }return nil;
}
- (NSDictionary *)entryForPreparedMetadata:(NSDictionary *)meta now:(double)now {
    NSDictionary *entry=meta?[_metadata objectForKey:meta]:nil;return [self live:entry now:now]?entry:nil;
}
- (NSDictionary *)diagnostics {return @{@"dependency_checks":@(_dependencyChecks),@"decision_hits":@(_decisionHits),@"title_hits":@(_titleHits),@"ranked_hits":@(_rankedHits),@"fallback_hits":@(_fallbackHits),@"source_checks":@(_sourceChecks)};}
@end
