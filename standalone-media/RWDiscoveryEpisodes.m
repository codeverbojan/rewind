#import "RWDiscoveryEpisodes.h"
#import "RWTVPolicy.h"
#import "RWSourceWork.h"
#import "RWEpisodeCatalog.h"
#import "RWPackedEpisodes.h"
#import <objc/runtime.h>
static char RWOwnedEpisodeMetadata;
// Only immutable title metadata is shared. Viewing position, profile history,
// next-episode choice and age permissions remain local to each preparation pass.
@interface RWReusableEpisodeIndex : NSObject
@property(nonatomic,weak) NSDictionary *show;
@property(nonatomic,weak) NSArray *videos;
@property(nonatomic,strong) NSArray *ordered;
@property(nonatomic,strong) NSDictionary *byID;
@end
@implementation RWReusableEpisodeIndex @end
@interface RWReusableEpisodeCache : NSObject
- (RWReusableEpisodeIndex *)index:(NSString *)key;
- (void)put:(RWReusableEpisodeIndex *)index key:(NSString *)key;
- (void)clear;
- (NSDictionary *)diagnostics;
@end
@implementation RWReusableEpisodeCache {NSLock *_lock;NSMutableDictionary *_items;NSMutableArray *_order;NSUInteger _episodes;}
- (instancetype)init {if((self=[super init])){_lock=[NSLock new];_items=[NSMutableDictionary new];_order=[NSMutableArray new];}return self;}
- (RWReusableEpisodeIndex *)index:(NSString *)key {[_lock lock];RWReusableEpisodeIndex *value=_items[key];if(value){[_order removeObject:key];[_order addObject:key];}[_lock unlock];return value;}
- (void)put:(RWReusableEpisodeIndex *)index key:(NSString *)key {
    NSUInteger cost=index.ordered.count;if(cost>4096)return;[_lock lock];
    if(_items[key]){_episodes-=[_items[key]ordered].count;[_items removeObjectForKey:key];[_order removeObject:key];}
    while(_order.count&&(_items.count>=16||_episodes+cost>4096)){NSString *old=_order.firstObject;_episodes-=[_items[old]ordered].count;[_items removeObjectForKey:old];[_order removeObjectAtIndex:0];}
    _items[key]=index;[_order addObject:key];_episodes+=cost;[_lock unlock];
}
- (void)clear {[_lock lock];[_items removeAllObjects];[_order removeAllObjects];_episodes=0;[_lock unlock];}
- (NSDictionary *)diagnostics {[_lock lock];NSDictionary *value=@{@"shared_indexes":@(_items.count),@"shared_episodes":@(_episodes)};[_lock unlock];return value;}
@end
static RWReusableEpisodeCache *ReusableIndexes(void){static RWReusableEpisodeCache *cache;static dispatch_once_t once;dispatch_once(&once,^{cache=[RWReusableEpisodeCache new];});return cache;}
@interface RWEpisodeSnapshot : NSObject
@property(nonatomic,weak) NSDictionary *show;
@property(nonatomic,weak) NSArray *videos;
@property(nonatomic,strong) NSDictionary *byID,*next;
@property(nonatomic,assign) NSUInteger count;
@property(nonatomic,assign) double at;
@end
@implementation RWEpisodeSnapshot @end
@implementation RWDiscoveryEpisodes {NSMutableDictionary *_cache;NSMutableArray *_order;NSUInteger _builds,_hits,_indexBuilds,_indexHits,_ownedInputs,_unownedInputs,_retainedEpisodes,_packedRequests,_packedNext;}
- (instancetype)init {if((self=[super init])){_cache=[NSMutableDictionary new];_order=[NSMutableArray new];}return self;}
- (NSDictionary *)diagnostics {NSMutableDictionary *result=[@{@"builds":@(_builds),@"hits":@(_hits),@"cached_shows":@(_cache.count),@"cached_episodes":@(_retainedEpisodes),@"index_builds":@(_indexBuilds),@"index_hits":@(_indexHits),@"owned_inputs":@(_ownedInputs),@"unowned_inputs":@(_unownedInputs),@"packed_requests":@(_packedRequests),@"packed_next":@(_packedNext)}mutableCopy];[result addEntriesFromDictionary:ReusableIndexes().diagnostics];return result;}
+ (NSDictionary *)immutableShow:(NSDictionary *)show {
    if(![show isKindOfClass:NSDictionary.class]||![show[@"id"]isKindOfClass:NSString.class]||![show[@"videos"]isKindOfClass:NSArray.class])return nil;
    if(objc_getAssociatedObject(show,&RWOwnedEpisodeMetadata))return show;
    // Packed arrays validate and own their immutable buffers at construction.
    // Preserve that representation instead of expanding it at ingress.
    if([show[@"videos"]isKindOfClass:RWPackedEpisodes.class]){
        NSMutableDictionary *brief=[show mutableCopy];[brief removeObjectForKey:@"videos"];NSDictionary *captured=[RWSourceWork snapshot:brief];if(!captured)return nil;
        NSMutableDictionary *out=[captured mutableCopy];out[@"videos"]=show[@"videos"];NSDictionary *owned=[out copy];objc_setAssociatedObject(owned,&RWOwnedEpisodeMetadata,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);return owned;
    }
    NSDictionary *owned=[RWSourceWork snapshot:show];if(owned)objc_setAssociatedObject(owned,&RWOwnedEpisodeMetadata,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);return owned;
}
+ (void)purgeReusableIndexes {[ReusableIndexes()clear];}
- (void)invalidate:(NSString *)title {if(title){RWEpisodeSnapshot *old=_cache[title];_retainedEpisodes-=old.byID.count;[_cache removeObjectForKey:title];[_order removeObject:title];}}
- (void)removeAll {[_cache removeAllObjects];[_order removeAllObjects];_retainedEpisodes=0;}
- (NSDictionary *)episode:(NSString *)requested show:(NSDictionary *)show history:(NSDictionary *)history now:(NSDate *)now {
    if(!RWEpisodeMetadataUsable(show,now.timeIntervalSince1970))return nil;
    NSString *key=[show[@"id"]isKindOfClass:NSString.class]?show[@"id"]:@"";NSArray *videos=[show[@"videos"]isKindOfClass:NSArray.class]?show[@"videos"]:nil;
    if(!key.length||!videos.count)return nil;
    if([videos isKindOfClass:RWPackedEpisodes.class]){
        if(![[(RWPackedEpisodes *)videos titleIdentifier]isEqual:key])return nil;
        // Canonical packed entries are already validated and ordered. Explicit
        // lookup does not depend on history or release eligibility, just as the
        // existing byID lookup below. Callers enforce playback policy separately.
        if(requested.length){_packedRequests++;return [(RWPackedEpisodes *)videos episodeForID:requested];}
        BOOL hasHistory=NO;NSString *prefix=[key stringByAppendingString:@":"];
        for(id video in history)if([video isKindOfClass:NSString.class]&&[video hasPrefix:prefix]){hasHistory=YES;break;}
        if(!hasHistory){_packedNext++;
            // Without this show's history, the existing selector returns the
            // first released, non-special episode. No full byID map is needed.
            for(NSUInteger i=0;i<videos.count;i++){NSDictionary *e=videos[i];if([e[@"season"]integerValue]>0&&[RWTVPolicy released:e now:now])return e;}
            return nil;
        }
    }
    RWEpisodeSnapshot *entry=_cache[key];double time=now.timeIntervalSince1970;
    if(!entry||entry.show!=show||entry.videos!=videos||entry.count!=videos.count||time<entry.at||time-entry.at>=60){
        entry=[RWEpisodeSnapshot new];entry.show=show;entry.videos=videos;entry.count=videos.count;entry.at=time;
        BOOL owned=objc_getAssociatedObject(show,&RWOwnedEpisodeMetadata)!=nil;if(owned)_ownedInputs++;else _unownedInputs++;BOOL reusable=owned&&videos.count<=4096;RWReusableEpisodeIndex *index=reusable?[ReusableIndexes()index:key]:nil;
        if(index&&index.show==show&&index.videos==videos){_indexHits++;}else{
            index=[RWReusableEpisodeIndex new];index.show=show;index.videos=videos;index.ordered=[RWTVPolicy episodes:show];NSMutableDictionary *byID=[NSMutableDictionary new];for(NSDictionary *episode in index.ordered)byID[episode[@"id"]]=episode;index.byID=[byID copy];_indexBuilds++;
            if(reusable)[ReusableIndexes()put:index key:key];
        }
        entry.byID=index.byID;entry.next=[RWTVPolicy nextFromEpisodes:index.ordered history:history now:now];
        if([show[@"episodeIndexHistorical"]boolValue]){
            // A partial historical index cannot infer progress past an episode
            // it does not contain. Require fresh metadata before choosing next.
            NSString *prefix=[key stringByAppendingString:@":"];
            for(NSString *video in history){NSDictionary *r=history[video];if([video hasPrefix:prefix]&&!index.byID[video]&&([r[@"position"]doubleValue]>3||[r[@"completed"]boolValue]||[r[@"progressOverride"]isEqual:@"unwatched"])){entry.next=nil;break;}}
        }
        _builds++;
        // The store retains twelve shows. An eight-entry index thrashed on
        // every Home pass through them; sixteen keeps the working set bounded.
        [self invalidate:key];NSUInteger cost=entry.byID.count;
        while(_order.count&&(_order.count>=16||_retainedEpisodes+cost>4096))[self invalidate:_order.firstObject];
        if(cost<=4096){_cache[key]=entry;[_order addObject:key];_retainedEpisodes+=cost;}
    }else {_hits++;[_order removeObject:key];[_order addObject:key];}
    return requested.length?entry.byID[requested]:entry.next;
}
@end
