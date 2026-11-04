#import "RWUpcomingSelection.h"
#import "RWUpcomingPolicy.h"
#import "RWDiscoverySnapshot.h"
#import "RWDiscoveryMetadataPolicy.h"
static NSString *Text(id x){return [x isKindOfClass:NSString.class]?x:@"";}
@implementation RWUpcomingSelection
+ (NSArray *)candidates:(NSArray *)catalog mode:(NSString *)mode snapshot:(NSDictionary *)snapshot following:(NSDictionary *)following watching:(NSDictionary *)watching {
    BOOL coming=[mode isEqual:@"Coming soon"],waiting=[mode isEqual:@"Waiting"];
    NSMutableSet *wanted=[NSMutableSet new];
    if(waiting){for(NSString *key in snapshot[@"profile"][@"sourceAvailability"]){NSDictionary *r=snapshot[@"profile"][@"sourceAvailability"][key];if([r[@"state"]isEqual:@"waiting"])[wanted addObject:[key componentsSeparatedByString:@":"].firstObject];}}
    else if(!coming){[wanted addObjectsFromArray:following.allKeys?:@[]];[wanted addObjectsFromArray:watching.allKeys?:@[]];}
    if(!coming&&!wanted.count)return @[];
    NSMutableArray *pool=[catalog mutableCopy]?:[NSMutableArray new];[pool addObjectsFromArray:[RWDiscoverySnapshot pool:snapshot]];
    for(NSDictionary *group in @[snapshot[@"profile"][@"sourceAvailability"]?:@{},watching?:@{},following?:@{}])for(NSDictionary *r in group.allValues)if([r[@"meta"]isKindOfClass:NSDictionary.class])[pool addObject:r[@"meta"]];
    if(coming)return pool;
    NSMutableArray *selected=[NSMutableArray new];for(NSDictionary *m in pool)if([wanted containsObject:Text(m[@"id"])])[selected addObject:m];return selected;
}
+ (NSArray *)items:(NSArray *)catalog mode:(NSString *)mode snapshot:(NSDictionary *)snapshot ratings:(NSDictionary *)ratings following:(NSDictionary *)following watching:(NSDictionary *)watching now:(double)now {
    NSArray *pool=[self candidates:catalog mode:mode snapshot:snapshot following:following watching:watching];
    BOOL coming=[mode isEqual:@"Coming soon"],waiting=[mode isEqual:@"Waiting"];NSMutableArray *result=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];NSDictionary *prefs=snapshot[@"profile"][@"discoveryPreferences"];
    for(NSUInteger start=0;start<pool.count;start+=128){@autoreleasepool{
        NSArray *slice=[pool subarrayWithRange:NSMakeRange(start,MIN((NSUInteger)128,pool.count-start))];
        // Scheduled language is supplied by TVmaze. Enrichment may replace the
        // discovery record, so retain its authoritative fallback by identity.
        NSMutableDictionary *schedule=[NSMutableDictionary new];for(NSDictionary *raw in slice)if(raw[@"scheduledEpisode"])schedule[raw[@"id"]]=raw;
        NSDictionary *prepared=[RWDiscoverySnapshot prepareItems:slice snapshot:snapshot ratings:ratings now:now];
        for(NSDictionary *original in prepared[@"items"]){NSDictionary *m=original;NSString *key=Text(m[@"id"]);if([seen containsObject:key])continue;NSString *state=m[@"availability"][@"state"];
            BOOL include=coming?([state isEqual:@"upcoming"]||[RWUpcomingPolicy scheduled:m now:now]):waiting?[state isEqual:@"waiting"]:(watching[key]!=nil||following[key]!=nil);if(!include)continue;
            if(coming){if(![RWDiscoveryMetadataPolicy recommendationAudienceAllows:m preferences:prefs restricted:[snapshot[@"profile"][@"maxAge"]integerValue]>=0])continue;if([snapshot[@"profile"][@"hidden"]containsObject:key])continue;
                if(m[@"scheduledEpisode"]){NSMutableDictionary *copy=[m mutableCopy],*record=[schedule[key][@"discovery"]mutableCopy]?:[NSMutableDictionary new];[record addEntriesFromDictionary:m[@"discovery"]?:@{}];
                    if(!Text(record[@"industry"]).length||[record[@"industry"]isEqual:@"unknown"])record[@"industry"]=@"television";
                    if(!Text(record[@"primaryLanguage"]).length){record[@"primaryLanguage"]=schedule[key][@"discovery"][@"primaryLanguage"]?:@"";record[@"languageSource"]=schedule[key][@"discovery"][@"languageSource"]?:@"";}copy[@"discovery"]=record;m=copy;
                }
                if(![RWDiscoveryMetadataPolicy permits:m preferences:prefs world:NO]&&![RWDiscoveryMetadataPolicy permits:m preferences:prefs world:YES])continue;
            }
            [seen addObject:key];[result addObject:m];
        }
    }}
    return [RWUpcomingPolicy orderedTitles:result];
}
@end
