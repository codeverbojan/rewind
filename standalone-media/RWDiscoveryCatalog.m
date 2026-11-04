#import "RWDiscoveryCatalog.h"
#import "RWCollectionIdentity.h"
#import "RWMediaIdentity.h"
#include <math.h>
static NSDictionary *DCMap(id x){return [x isKindOfClass:NSDictionary.class]?x:@{};}
static NSArray *DCList(id x){return [x isKindOfClass:NSArray.class]?x:@[];}
static NSString *DCText(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static NSString *DCID(NSDictionary *m){return DCText(m[@"id"]?:m[@"imdb_id"]);}
static BOOL DCValue(id value){if(!value||value==NSNull.null)return NO;if([value isKindOfClass:NSString.class])return [value length]>0;if([value respondsToSelector:@selector(count)])return [value count]>0;return [value isKindOfClass:NSNumber.class];}
static double DCNumber(id value){double n=[value respondsToSelector:@selector(doubleValue)]?[value doubleValue]:0;return isfinite(n)?n:0;}
static NSArray *DCFranchises(NSDictionary *meta){NSMutableArray *out=[NSMutableArray new];NSUInteger count=0;for(id raw in DCList(DCMap(meta[@"discovery"])[@"franchises"])){if(count++==6)break;NSDictionary *ref=DCMap(raw);NSString *key=DCText(ref[@"id"]);if(key.length&&RWIsNarrativeFranchise(ref))[out addObject:key];}return out;}
@implementation RWDiscoveryCatalog
+ (NSArray *)balancedPool:(NSArray *)groups limit:(NSUInteger)limit allows:(BOOL(^)(NSDictionary *))allows {
    limit=MIN(limit,(NSUInteger)500);if(!limit)return @[];
    groups=DCList(groups);NSMutableArray *out=[NSMutableArray new],*positions=[NSMutableArray new];NSMutableDictionary *indices=[NSMutableDictionary new];
    for(NSUInteger i=0;i<groups.count;i++)[positions addObject:@0];
    BOOL remaining=YES;
    while(out.count<limit&&remaining){remaining=NO;
        for(NSUInteger g=0;g<groups.count&&out.count<limit;g++){NSArray *group=DCList(groups[g]);NSUInteger position=[positions[g]unsignedIntegerValue];
            while(position<group.count){NSDictionary *m=RWNormalizeMediaIdentity(DCMap(group[position++]),nil);NSString *key=DCID(m);
                if(!key.length||indices[key]||![@[@"movie",@"series"]containsObject:DCText(m[@"type"])]||(allows&&!allows(m)))continue;
                indices[key]=@(out.count);[out addObject:m];break;
            }positions[g]=@(position);if(position<group.count)remaining=YES;
        }
    }
    // Membership is balanced; duplicate metadata still follows source priority.
    // Only the selected IDs are retained, not another full catalog dictionary.
    NSMutableSet *resolved=[NSMutableSet new];
    for(id raw in groups)for(id value in DCList(raw)){NSDictionary *m=RWNormalizeMediaIdentity(DCMap(value),nil);NSString *key=DCID(m);NSNumber *index=indices[key];
        if(index&&![resolved containsObject:key]&&[@[@"movie",@"series"]containsObject:DCText(m[@"type"])]&&(!allows||allows(m))){out[index.unsignedIntegerValue]=m;[resolved addObject:key];}
        if(resolved.count==out.count)return out;
    }return out;
}
+ (NSDictionary *)filterHome:(NSDictionary *)home allows:(BOOL(^)(NSDictionary *,NSString *,BOOL))allows {
    if(!DCMap(home).count||!allows)return home?:@{};NSMutableDictionary *out=[home mutableCopy];
    NSDictionary *hero=DCMap(home[@"hero"]);out[@"hero"]=DCID(hero).length&&allows(hero,@"",YES)?hero:@{};
    NSMutableArray *rows=[NSMutableArray new];for(id raw in DCList(home[@"rows"])){NSDictionary *row=DCMap(raw);NSString *key=DCText(row[@"id"]);if(!key.length)continue;
        NSMutableArray *items=[NSMutableArray new];for(id value in DCList(row[@"items"])){NSDictionary *title=DCMap(value);if(DCID(title).length&&allows(title,key,NO))[items addObject:title];}
        // Keep the row identity and order, including an emptied row that can
        // receive fresh cards during this visit. Hidden cards consume no slots.
        NSMutableDictionary *filtered=[row mutableCopy];filtered[@"items"]=items;[rows addObject:filtered];
    }out[@"rows"]=rows;return out;
}
+ (NSDictionary *)mergeHome:(NSDictionary *)existing incoming:(NSDictionary *)incoming {
    if(!DCMap(incoming).count)return existing?:@{};
    if(!DCMap(existing).count)return incoming;
    // One-time taxonomy migration: old broad rails must not consume the new
    // themed assignments. Later publications retain their stable row order.
    if([incoming[@"layoutVersion"]integerValue]>=229&&[existing[@"layoutVersion"]integerValue]<229)return incoming;
    if([incoming[@"layoutVersion"]integerValue]>=168&&[existing[@"layoutVersion"]integerValue]<168)return incoming;
    NSMutableDictionary *result=[incoming mutableCopy];result[@"hero"]=DCMap(existing[@"hero"]);
    NSMutableSet *seen=[NSMutableSet new];NSString *hero=DCID(result[@"hero"]);if(hero.length)[seen addObject:hero];
    NSMutableSet *franchises=[NSMutableSet setWithArray:DCFranchises(result[@"hero"])];
    NSMutableArray *rows=[NSMutableArray new];NSMutableDictionary *byID=[NSMutableDictionary new];
    NSMutableSet *incomingRows=[NSMutableSet new];NSMutableDictionary *latest=[NSMutableDictionary new],*incomingTitles=[NSMutableDictionary new],*incomingTypes=[NSMutableDictionary new];
    for(NSDictionary *row in DCList(incoming[@"rows"])){if(DCText(row[@"id"]).length){[incomingRows addObject:row[@"id"]];incomingTitles[row[@"id"]]=DCText(row[@"title"]);incomingTypes[row[@"id"]]=DCText(row[@"mediaType"]);}for(NSDictionary *m in DCList(row[@"items"]))if(DCID(m).length)latest[DCID(m)]=m;}
    // Existing posters keep their place. Newly qualified titles fill the end
    // of that same rail; newly available rails append below existing content.
    for(NSDictionary *source in @[existing,incoming])for(id raw in DCList(source[@"rows"])){
        NSDictionary *row=DCMap(raw);NSString *key=DCText(row[@"id"]);if(!key.length||([incoming[@"layoutVersion"]integerValue]>=40&&![incomingRows containsObject:key]))continue;
        // A different mood or "Because you liked" anchor is a new recipe.
        // Retaining its old cards would put unrelated titles under the heading.
        if(source==existing&&incomingTitles[key]&&(![DCText(row[@"title"])isEqual:incomingTitles[key]]||![DCText(row[@"mediaType"])isEqual:incomingTypes[key]]))continue;
        NSMutableDictionary *saved=byID[key];
        if(!saved){if(rows.count==12)continue;saved=[row mutableCopy];saved[@"items"]=[NSMutableArray new];byID[key]=saved;[rows addObject:saved];}
        NSMutableArray *items=saved[@"items"];for(id rawTitle in DCList(row[@"items"])){NSDictionary *title=DCMap(rawTitle);NSString *identifier=DCID(title);if(!identifier.length||[seen containsObject:identifier]||items.count>=12)continue;NSDictionary *updated=latest[identifier]?:title;NSString *type=DCText(saved[@"mediaType"]);if(type.length&&![updated[@"type"]isEqual:type])continue;
            NSArray *identities=DCFranchises(updated);BOOL repeated=NO;for(NSString *identity in identities)if([franchises containsObject:identity])repeated=YES;if(repeated)continue;
            [items addObject:updated];[seen addObject:identifier];[franchises addObjectsFromArray:identities];}
    }result[@"rows"]=rows;return result;
}
+ (NSArray *)merge:(NSArray *)incoming existing:(NSArray *)existing limit:(NSUInteger)limit {
    if(!limit)return @[];limit=MIN(limit,(NSUInteger)500);NSMutableDictionary *old=[NSMutableDictionary new],*incomingByID=[NSMutableDictionary new];NSMutableOrderedSet *order=[NSMutableOrderedSet new];
    for(id raw in DCList(existing)){NSDictionary *m=RWNormalizeMediaIdentity(DCMap(raw),nil);NSString *key=DCID(m);if(key.length&&!old[key]&&old.count<500)old[key]=m;}
    for(id raw in DCList(incoming)){NSDictionary *m=RWNormalizeMediaIdentity(DCMap(raw),nil);NSString *key=DCID(m);if(!key.length||![ @[@"movie",@"series"]containsObject:m[@"type"]?:@""])continue;if(!incomingByID[key])incomingByID[key]=m;[order addObject:key];if(order.count==limit)break;}
    for(id raw in DCList(existing)){NSString *key=DCID(DCMap(raw));if(!key.length||[order containsObject:key])continue;if(order.count>=limit)break;[order addObject:key];}
    NSMutableArray *out=[NSMutableArray new];NSArray *volatileKeys=@[@"videos",@"availability",@"historyRecord",@"discovery",@"episodeVideoID",@"episodeCaption",@"ageAllowed"];
    for(NSString *key in order){NSMutableDictionary *merged=[DCMap(old[key])mutableCopy];NSDictionary *update=DCMap(incomingByID[key]);if(DCText(merged[@"type"]).length&&DCText(update[@"type"]).length&&![merged[@"type"]isEqual:update[@"type"]])update=@{};
        for(NSString *field in update)if(DCValue(update[field])){if([field isEqual:@"imdbRating"]&&(DCNumber(update[field])<1||DCNumber(update[field])>10))continue;merged[field]=update[field];}
        if(![ @[@"movie",@"series"]containsObject:merged[@"type"]?:@""]||!DCText(merged[@"name"]).length)continue;
        for(NSString *field in volatileKeys)[merged removeObjectForKey:field];[out addObject:merged];
    }return out;
}
+ (NSArray *)uniqueVisible:(NSArray *)items excluding:(NSSet *)excluded hidden:(NSArray *)hidden limit:(NSUInteger)limit {
    if(!limit)return @[];NSMutableSet *seen=[NSMutableSet setWithSet:excluded?:[NSSet set]];[seen addObjectsFromArray:DCList(hidden)];NSMutableArray *out=[NSMutableArray new];for(id raw in DCList(items)){NSDictionary *m=RWNormalizeMediaIdentity(DCMap(raw),nil);NSString *key=DCID(m);if(!key.length||[seen containsObject:key])continue;[seen addObject:key];[out addObject:m];if(out.count>=limit)break;}return out;
}
+ (NSArray *)sortCredits:(NSArray *)items byRating:(BOOL)rating {
    return [DCList(items) sortedArrayUsingComparator:^NSComparisonResult(id av,id bv){NSDictionary *a=DCMap(av),*b=DCMap(bv);NSString *field=rating?@"imdbRating":@"releaseInfo";double x=DCNumber(a[field]),y=DCNumber(b[field]);return x==y?[DCText(a[@"name"])compare:DCText(b[@"name"])]:x>y?NSOrderedAscending:NSOrderedDescending;}];
}
@end
