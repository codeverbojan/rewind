#import "RWHomeDeferredPreparation.h"
#import "RWHomeDelivery.h"
#import "RWHomePreparation.h"
#import "RWDiscoverySnapshot.h"
static NSDictionary *Map(id x){return [x isKindOfClass:NSDictionary.class]?x:@{};}
static NSArray *List(id x){return [x isKindOfClass:NSArray.class]?x:@[];}
static NSString *ID(NSDictionary *m){id x=m[@"id"]?:m[@"imdb_id"];return [x isKindOfClass:NSString.class]?x:@"";}
static NSDictionary *Title(id x){return [RWHomeDelivery titleMetadata:Map(x)];}
@implementation RWHomeDeferredPreparation
+ (NSDictionary *)boundedPlan:(NSDictionary *)home {
    // The migrated mixed layout can contain fourteen typed halves. Keep that
    // existing exception. A merged plan may have eight rails (twelve cards each).
    home=Map(home);NSMutableDictionary *plan=[NSMutableDictionary new];
    plan[@"hero"]=Title(home[@"hero"]);plan[@"ratingPriors"]=List(home[@"ratingPriors"]);
    plan[@"migratedLayout"]=@([home[@"migratedLayout"]boolValue]);plan[@"deferredPlan"]=@YES;NSMutableArray *rows=[NSMutableArray new];
    NSUInteger limit=[plan[@"migratedLayout"]boolValue]?14:12;
    for(id raw in List(home[@"rows"])){if(rows.count==limit)break;NSDictionary *row=Map(raw);NSMutableArray *items=[NSMutableArray new];
        for(id item in List(row[@"items"])){if(items.count==12)break;NSDictionary *m=Title(item);if(ID(m).length)[items addObject:m];}
        [rows addObject:@{@"items":items}];
    }plan[@"rows"]=rows;return plan;
}
+ (NSDictionary *)prepare:(NSDictionary *)home snapshot:(NSDictionary *)snapshot ratings:(NSDictionary *)ratings profileID:(NSString *)profileID now:(double)now {
    return [self prepare:home requestedIDs:nil previous:nil snapshot:snapshot ratings:ratings profileID:profileID now:now];
}
+ (NSDictionary *)prepare:(NSDictionary *)home requestedIDs:(NSSet *)requested previous:(NSDictionary *)previous snapshot:(NSDictionary *)snapshot ratings:(NSDictionary *)ratings profileID:(NSString *)profileID now:(double)now {
    NSDictionary *plan=[self boundedPlan:home];NSMutableDictionary *sources=[NSMutableDictionary new];NSMutableArray *titles=[NSMutableArray new];
    NSArray *rows=[@[@{@"items":@[plan[@"hero"]]}]arrayByAddingObjectsFromArray:plan[@"rows"]];
    for(NSDictionary *row in rows)for(NSDictionary *m in row[@"items"]){NSString *key=ID(m);if(key.length&&!sources[key]){sources[key]=m;if(!requested||[requested containsObject:key])[titles addObject:m];}}
    NSDictionary *work=[RWDiscoverySnapshot prepareItems:titles snapshot:snapshot ratings:ratings now:now];NSMutableDictionary *prepared=[NSMutableDictionary new];
    for(NSDictionary *m in work[@"items"])prepared[ID(m)]=m;
    // Cache negative age/type decisions as well. Missing an entry must mean
    // pending work, not an endless retry for a title correctly rejected by Kids.
    for(NSDictionary *source in titles){NSString *key=ID(source);if(!prepared[key]){NSMutableDictionary *denied=[source mutableCopy];denied[@"ageAllowed"]=@NO;denied[@"availability"]=@{@"discovery_eligible":@NO,@"hero_eligible":@NO};prepared[key]=denied;}}
    NSMutableDictionary *ready=[plan mutableCopy];ready[@"hero"]=prepared[ID(plan[@"hero"])]?:@{};NSMutableArray *readyRows=[NSMutableArray new];
    for(NSDictionary *row in plan[@"rows"]){NSMutableArray *items=[NSMutableArray new];for(NSDictionary *m in row[@"items"])if(prepared[ID(m)])[items addObject:prepared[ID(m)]];[readyRows addObject:@{@"items":items}];}ready[@"rows"]=readyRows;
    NSMutableDictionary *result=[[RWHomePreparation prepare:ready snapshot:snapshot ratings:ratings profileID:profileID now:now]mutableCopy];NSMutableDictionary *entries=[NSMutableDictionary new];
    // Retain already prepared offscreen cards only if their original dependency
    // scope, source and deadline still match. Never renew an old entry's TTL.
    NSDictionary *usable=[RWHomePreparation usable:previous snapshot:snapshot ratings:ratings profileID:profileID priors:plan[@"ratingPriors"] now:now];
    for(NSString *key in usable[@"entries"]){NSDictionary *entry=usable[@"entries"][key];if(sources[key]&&[self entry:entry matchesTitle:sources[key]])entries[key]=entry;}
    NSUInteger retained=entries.count;
    for(NSString *key in result[@"entries"]){NSMutableDictionary *entry=[result[@"entries"][key]mutableCopy];entry[@"source"]=sources[key];entries[key]=entry;}
    if(!result[@"scope"])return @{}; // Invalid time/profile must not revive a cache.
    double until=[result[@"validUntil"]doubleValue];for(NSDictionary *entry in entries.allValues)until=MIN(until,[entry[@"validUntil"]doubleValue]);
    result[@"entries"]=entries;result[@"validUntil"]=@(until);result[@"requested_entries"]=@(titles.count);result[@"retained_entries"]=@(retained);result[@"plan_entries"]=@(sources.count);result[@"enrichment_seconds"]=work[@"seconds"];return result;
}
+ (BOOL)entry:(NSDictionary *)entry matchesTitle:(NSDictionary *)title {
    return [RWHomePreparation entry:entry matchesTitle:title];
}
@end
