#import "RWHomeDelivery.h"
#import "RWDiscoveryMetadataPolicy.h"
#import "RWAvailability.h"
#import "RWDiscoveryEpisodes.h"
#include <math.h>
static NSDictionary *HMap(id x){return [x isKindOfClass:NSDictionary.class]?x:@{};}
static NSArray *HList(id x){return [x isKindOfClass:NSArray.class]?x:@[];}
static NSString *HID(NSDictionary *m){id key=m[@"id"]?:m[@"imdb_id"];return [key isKindOfClass:NSString.class]?key:@"";}
static NSDictionary *Context(NSDictionary *profile,NSInteger quality){
    return @{@"age":profile[@"maxAge"]?:@(-1),@"preferences":[RWDiscoveryMetadataPolicy preferences:profile[@"discoveryPreferences"]],@"quality":@(quality),@"schema":@39};
}
@implementation RWHomeDelivery
+ (NSArray *)displaySignature:(NSDictionary *)home {
    NSMutableArray *result=[NSMutableArray new];
    NSArray *rows=[@[@{@"id":@"hero",@"items":@[HMap(home[@"hero"])]}]arrayByAddingObjectsFromArray:HList(home[@"rows"])];
    for(NSDictionary *row in rows){NSMutableArray *cards=[NSMutableArray new];
        for(NSDictionary *m in HList(row[@"items"])){NSMutableDictionary *card=[NSMutableDictionary new];
            for(NSString *key in @[@"id",@"name",@"type",@"poster",@"background",@"imdbRating",@"imdbVotes",@"releaseInfo",@"showLanguage",@"description",@"runtime"])if(m[key])card[key]=m[key];
            NSDictionary *discovery=HMap(m[@"discovery"]);card[@"language"]=discovery[@"primaryLanguage"]?:discovery[@"originalLanguages"]?:@[];[cards addObject:card];
        }[result addObject:@[@[row[@"id"]?:@"",row[@"title"]?:@"",row[@"mediaType"]?:@"",row[@"minimumCount"]?:@0],cards]];
    }return result;
}
+ (NSDictionary *)titleMetadata:(NSDictionary *)meta {
    NSMutableDictionary *title=[HMap(meta)mutableCopy];
    for(NSString *key in @[@"videos",@"episodeVideoID",@"episodeCaption",@"season",@"episode",@"historyRecord",@"source",@"homeRecoverableListing"])[title removeObjectForKey:key];
    if([title[@"type"]isEqual:@"series"]&&[title[@"seriesName"]isKindOfClass:NSString.class]&&[title[@"seriesName"]length])title[@"name"]=title[@"seriesName"];
    return title;
}
+ (BOOL)needsRefresh:(NSDictionary *)meta now:(double)now {
    NSDictionary *a=HMap(meta[@"availability"]);
    if([a[@"watch_instead_of_play"]boolValue]||[a[@"hero_eligible"]boolValue]||[a[@"retry_after"]doubleValue]>now)return NO;
    double checked=[a[@"checked"]doubleValue],age=now-checked;
    double cooldown=[a[@"discovery_eligible"]boolValue]?6*3600:300;
    return !(checked>0&&age>=0&&age<cooldown);
}
+ (NSArray *)retainedTitles:(NSDictionary *)observations {
    // Provider pages rotate independently of this profile's acquired titles.
    // Reuse their existing bounded metadata as a final catalog group. Nothing
    // here grants current availability, age permission or recommendation rank.
    observations=HMap(observations);NSMutableArray *keys=[NSMutableArray new];
    for(id key in observations)if([key isKindOfClass:NSString.class]&&[key length]<=128)[keys addObject:key];
    [keys sortUsingComparator:^NSComparisonResult(NSString *a,NSString *b){
        id av=HMap(observations[a])[@"checked"],bv=HMap(observations[b])[@"checked"];
        double at=[av isKindOfClass:NSNumber.class]?[av doubleValue]:0,bt=[bv isKindOfClass:NSNumber.class]?[bv doubleValue]:0;
        if(!isfinite(at))at=0;if(!isfinite(bt))bt=0;
        if(at!=bt)return at>bt?NSOrderedAscending:NSOrderedDescending;return [a compare:b];
    }];
    NSMutableArray *titles=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];NSUInteger read=0;
    for(NSString *key in keys){if(read++==256)break;NSDictionary *record=HMap(observations[key]),*meta=HMap(record[@"meta"]);NSString *title=HID(meta),*type=meta[@"type"];
        if(!title.length||title.length>128||[seen containsObject:title]||![@[@"candidates",@"ready"]containsObject:record[@"state"]?:@""])continue;
        if(!([type isEqual:@"movie"]&&[key isEqual:title])&&!([type isEqual:@"series"]&&[key hasPrefix:[title stringByAppendingString:@":"]]))continue;
        NSMutableDictionary *brief=[[self titleMetadata:meta]mutableCopy];brief[@"id"]=title;
        for(NSString *field in @[@"availability",@"ageAllowed",@"homePreparationPending"])[brief removeObjectForKey:field];
        [seen addObject:title];[titles addObject:brief];
    }return titles;
}
+ (NSArray *)refreshable:(NSArray *)prepared observations:(NSDictionary *)observations shows:(NSDictionary *)shows history:(NSDictionary *)history metadataAttempts:(NSDictionary *)attempts quality:(NSInteger)quality now:(double)now {
    NSMutableArray *out=[NSMutableArray new];RWDiscoveryEpisodes *episodes=[RWDiscoveryEpisodes new];NSDate *date=[NSDate dateWithTimeIntervalSince1970:now];
    for(id raw in prepared){
        if(![raw isKindOfClass:NSDictionary.class])continue;NSDictionary *meta=raw;NSString *title=HID(meta),*video=nil;NSDictionary *episode=nil;BOOL changedEpisode=NO;
        if([meta[@"type"]isEqual:@"movie"])video=title;
        else if([meta[@"type"]isEqual:@"series"]){
            NSDictionary *show=HMap(shows[title]);
            if([HList(show[@"videos"])count]){
                episode=[episodes episode:nil show:show history:history now:date];
                if(!episode){
                    if(![show[@"episodeIndexHistorical"]boolValue])continue;
                    double tried=[attempts[title]doubleValue];if(tried>0&&now>=tried&&now-tried<300)continue;
                    // This partial index cannot identify the next episode.
                    // Queue metadata only; no old episode or source result is
                    // carried forward as evidence that the series is playable.
                    NSMutableDictionary *pending=[[self titleMetadata:meta]mutableCopy];
                    pending[@"availability"]=[RWAvailability presentation:pending observation:@{} quality:quality now:now];
                    [out addObject:pending];continue;
                }
                video=episode[@"id"];changedEpisode=![video isEqual:meta[@"episodeVideoID"]];
            }
            else {
                double tried=[attempts[title]doubleValue];if(tried>0&&now>=tried&&now-tried<300)continue;
                NSString *explicitID=[meta[@"episodeVideoID"]isKindOfClass:NSString.class]?meta[@"episodeVideoID"]:@"";NSArray *parts=[explicitID componentsSeparatedByString:@":"];NSCharacterSet *invalid=NSCharacterSet.decimalDigitCharacterSet.invertedSet;
                if(parts.count==3&&[parts[0]isEqual:title]&&[parts[1]length]&&[parts[2]length]&&[parts[1]rangeOfCharacterFromSet:invalid].location==NSNotFound&&[parts[2]rangeOfCharacterFromSet:invalid].location==NSNotFound&&[parts[2]integerValue]>0)video=explicitID;
            }
        }
        // Current observations and episode selection do not depend on the full
        // ranking job surviving a Home/Search transition. This only selects
        // background checks; it never promotes a card to ready-to-play.
        NSDictionary *observation=video.length?HMap(observations[video]):@{};NSDictionary *candidate=meta;
        if(observation.count||changedEpisode){
            NSMutableDictionary *copy=[meta mutableCopy],*target=[meta mutableCopy];if(episode)target[@"released"]=episode[@"released"]?:@"";
            copy[@"availability"]=[RWAvailability presentation:target observation:observation quality:quality now:now];if(video.length)copy[@"episodeVideoID"]=video;candidate=copy;
        }
        if([self needsRefresh:candidate now:now]){
            NSMutableDictionary *copy=[candidate mutableCopy];[copy removeObjectForKey:@"homeRecoverableListing"];
            double age=now-[observation[@"checked"]doubleValue];
            // Only a hint for which exact title/episode to check next. Expired
            // listings never become display or playback evidence without a new
            // lookup. Reserve part of the existing budget for useful recovery.
            if([observation[@"policy"]integerValue]==34&&[observation[@"quality"]integerValue]==quality&&[observation[@"state"]isEqual:@"candidates"]&&age>=86400&&age<7*86400&&![copy[@"availability"][@"discovery_eligible"]boolValue])copy[@"homeRecoverableListing"]=@YES;
            [out addObject:copy];
        }
    }return out;
}
+ (NSDictionary *)snapshot:(NSDictionary *)home profile:(NSDictionary *)profile quality:(NSInteger)quality now:(double)now {
    if(!HMap(home).count)return @{};
    // The producer supplies already ranked, bounded title metadata. This cache
    // is a layout hint only; every card is rechecked by current profile and
    // availability policy before UIKit displays it.
    NSMutableArray *rows=[NSMutableArray new];NSUInteger titles=0;
    for(id raw in HList(home[@"rows"])){NSDictionary *row=HMap(raw);NSArray *items=HList(row[@"items"]);
        if(![row[@"id"]isKindOfClass:NSString.class]||!items.count)continue;
        NSMutableArray *cards=[NSMutableArray new];for(id item in items){NSDictionary *m=HMap(item);if(!HID(m).length)continue;[cards addObject:[self titleMetadata:m]];if(cards.count==12)break;}
        if(!cards.count)continue;NSMutableDictionary *copy=[row mutableCopy];copy[@"items"]=cards;[rows addObject:copy];titles+=cards.count;if(rows.count==12)break;
    }
    if(!titles&&!HID(HMap(home[@"hero"])).length)return @{};
    NSMutableDictionary *page=[home mutableCopy];page[@"rows"]=rows;if(home[@"hero"])page[@"hero"]=[self titleMetadata:home[@"hero"]];
    NSDictionary *result=@{@"page":page,@"context":Context(profile,quality),@"savedAt":@(now)};
    NSData *data=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
    return data.length&&data.length<=1024*1024?result:@{};
}
+ (NSDictionary *)restore:(NSDictionary *)snapshot profile:(NSDictionary *)profile quality:(NSInteger)quality now:(double)now {
    snapshot=HMap(snapshot);double saved=[snapshot[@"savedAt"]doubleValue];
    if(saved<=0||now<saved||now-saved>=86400||![HMap(snapshot[@"context"])isEqual:Context(profile,quality)])return @{};
    NSDictionary *page=HMap(snapshot[@"page"]);if(![page[@"rows"]isKindOfClass:NSArray.class]||[page[@"rows"]count]>12)return @{};
    for(id raw in page[@"rows"]){NSDictionary *row=HMap(raw);if(![row[@"id"]isKindOfClass:NSString.class]||![row[@"items"]isKindOfClass:NSArray.class]||[row[@"items"]count]>12)return @{};for(id title in row[@"items"])if(!HID(HMap(title)).length)return @{};}
    return page;
}
+ (NSArray *)targets:(NSArray *)ranked world:(NSArray *)world older:(NSArray *)older shows:(NSArray *)shows now:(double)now limit:(NSUInteger)limit {
    if(!limit)return @[];limit=MIN(limit,(NSUInteger)4);
    // Interleave the ranked groups, rather than spending every visit on the
    // same first World/older/show entries. Recent results are skipped, including
    // negative results and failed requests, so an outage cannot cause a loop.
    NSArray *groups=@[ranked,older,shows,world];NSMutableArray *out=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(NSUInteger index=0;index<40;index++)for(NSArray *group in groups){
        if(index>=group.count)continue;NSDictionary *m=HMap(group[index]);NSString *key=HID(m);
        if(!key.length||[seen containsObject:key])continue;[seen addObject:key];NSDictionary *a=HMap(m[@"availability"]);
        if(![self needsRefresh:m now:now])continue;
        [out addObject:m];
    }
    // Keep one eligible international discovery in the first two positions so
    // the explicit-watch reservation cannot discard it. This uses the same
    // four checks, and only already admitted, cooldown-eligible candidates.
    NSDictionary *worldTarget=nil;
    if(limit>=2)for(NSDictionary *candidate in world){
        for(NSDictionary *m in out)if([HID(m)isEqual:HID(candidate)]){worldTarget=m;break;}
        if(worldTarget)break;
    }
    NSArray *(^finish)(NSArray *)=^NSArray *(NSArray *input){
        NSMutableArray *selected=[input mutableCopy];
        if(worldTarget&&![HID(selected.firstObject)isEqual:HID(worldTarget)]){
            for(NSUInteger i=0;i<selected.count;i++)if([HID(selected[i])isEqual:HID(worldTarget)]){[selected removeObjectAtIndex:i];break;}
            [selected insertObject:worldTarget atIndex:MIN((NSUInteger)1,selected.count)];
        }
        return selected.count>limit?[selected subarrayWithRange:NSMakeRange(0,limit)]:selected;
    };
    // Reclaim at most two expired positive listings, in the same ranked,
    // interleaved order. The other slots remain available for new discovery.
    NSMutableArray *recovery=[NSMutableArray new];NSMutableSet *recovered=[NSMutableSet new];
    for(NSUInteger index=0;index<40&&recovery.count<MIN(limit,(NSUInteger)2);index++)for(NSArray *group in groups){
        if(index>=group.count)continue;NSDictionary *m=HMap(group[index]);NSString *key=HID(m);
        if(!key.length||[recovered containsObject:key]||![m[@"homeRecoverableListing"]boolValue]||![self needsRefresh:m now:now])continue;
        [recovery addObject:m];[recovered addObject:key];if(recovery.count==MIN(limit,(NSUInteger)2))break;
    }
    if(!recovery.count)return finish(out);
    // An expired international listing shares the two recovery slots; it must
    // not consume a third slot reserved for new discoveries.
    if(worldTarget&&[worldTarget[@"homeRecoverableListing"]boolValue]&&![recovered containsObject:HID(worldTarget)]){
        if(recovery.count==2){[recovered removeObject:HID(recovery[1])];[recovery removeObjectAtIndex:1];}
        [recovery addObject:worldTarget];[recovered addObject:HID(worldTarget)];
    }
    for(NSDictionary *m in out){if(recovery.count==limit)break;if(![m[@"homeRecoverableListing"]boolValue]&&![recovered containsObject:HID(m)]){[recovery addObject:m];[recovered addObject:HID(m)];}}
    // The reserved discovery slots are not useful when no new candidates
    // remain. Fill spare capacity from further recovery candidates, without
    // exceeding the same four-title visit budget or duplicating an identity.
    for(NSDictionary *m in out){if(recovery.count==limit)break;if(![recovered containsObject:HID(m)]){[recovery addObject:m];[recovered addObject:HID(m)];}}
    return finish(recovery);
}
+ (BOOL)publishCompleted:(NSUInteger)completed total:(NSUInteger)total {
    return completed>0&&(completed>=total||completed%8==0);
}
+ (NSArray *)targets:(NSArray *)ranked includingWatches:(NSArray *)watches {
    // Following is explicit intent. Reserve up to two of the SAME four slots;
    // deduplicate with discovery targets rather than opening another lane.
    NSMutableArray *out=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    NSArray *priority=watches.count>2?[watches subarrayWithRange:NSMakeRange(0,2)]:watches?:@[];
    for(NSArray *group in @[priority,ranked?:@[]])for(NSDictionary *meta in group){NSString *identifier=HID(meta);if(!identifier.length||[seen containsObject:identifier])continue;[seen addObject:identifier];[out addObject:meta];if(out.count==4)return out;}
    return out;
}
@end
