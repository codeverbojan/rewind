#import "RWEpisodeCatalog.h"
#import "RWDiscoveryEpisodes.h"
#import "RWTVPolicy.h"
#import "RWPackedEpisodes.h"
#include <math.h>
static NSDictionary *Map(id x){return [x isKindOfClass:NSDictionary.class]?x:@{};}
static NSArray *List(id x){return [x isKindOfClass:NSArray.class]?x:@[];}
static NSString *Text(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static BOOL Retained(NSDictionary *record,double now){id value=record[@"episodeIndexAt"];if(![value isKindOfClass:NSNumber.class])return NO;double at=[value doubleValue];return isfinite(at)&&isfinite(now)&&at>0&&now>=at&&now-at<30*86400;}
static NSDictionary *Compact(NSDictionary *show,double at){
    NSString *title=Text(show[@"id"]);NSArray *raw=List(show[@"videos"]);
    if(![show[@"type"]isEqual:@"series"]||([title rangeOfString:@"^tt[0-9]+$" options:NSRegularExpressionSearch].location!=0||[[title substringFromIndex:2]longLongValue]<=0)||title.length>32||!raw.count||raw.count>4096||!isfinite(at)||at<=0)return nil;
    NSMutableArray *safe=[NSMutableArray new];
    for(id value in raw){NSDictionary *e=Map(value);id season=e[@"season"],episode=e[@"episode"];
        if(![season respondsToSelector:@selector(integerValue)]||![episode respondsToSelector:@selector(integerValue)])continue;
        NSInteger s=[season integerValue],n=[episode integerValue];NSString *key=Text(e[@"id"]),*release=Text(e[@"released"]);
        if(s<0||n<1)continue;
        if(![key isEqual:[NSString stringWithFormat:@"%@:%ld:%ld",title,(long)s,(long)n]])continue;
        // Never turn a valid but oversized canonical list into a partial list
        // which could silently skip the viewer's next episode.
        if(s>100||n>2000||key.length>64||release.length>40)return nil;
        [safe addObject:@{@"id":key,@"season":@(s),@"episode":@(n),@"released":release}];
    }
    NSArray *ordered=[RWTVPolicy episodes:@{@"id":title,@"videos":safe}];if(!ordered.count)return nil;
    RWPackedEpisodes *packed=[RWPackedEpisodes episodes:ordered title:title];if(!packed)return nil;
    return [RWDiscoveryEpisodes immutableShow:@{@"id":title,@"type":@"series",@"videos":packed,@"episodeIndexAt":@(at)}];
}
static NSUInteger Cost(NSDictionary *show){return 256+[(RWPackedEpisodes *)show[@"videos"]storageBytes];}
@implementation RWEpisodeCatalog {NSMutableDictionary *_shows;NSUInteger _episodes,_bytes;NSMutableArray *_events;}
- (instancetype)initWithSnapshot:(NSDictionary *)snapshot now:(double)now {
    if((self=[super init])){_shows=[NSMutableDictionary new];_events=[NSMutableArray new];
        BOOL packed=[Map(snapshot)[@"version"]isEqual:@2];
        if(packed||[Map(snapshot)[@"version"]isEqual:@1]){
            NSDictionary *shows=Map(snapshot[@"shows"]);if(shows.count>(packed?256:64))return self;
            NSMutableArray *keys=[NSMutableArray new];for(id key in shows){NSDictionary *m=Map(shows[key]);if([key isKindOfClass:NSString.class]&&[m[@"id"]isEqual:key]&&Retained(m,now))[keys addObject:key];}
            [keys sortUsingComparator:^NSComparisonResult(id a,id b){NSComparisonResult r=[shows[a][@"episodeIndexAt"]compare:shows[b][@"episodeIndexAt"]];return r==NSOrderedSame?[a compare:b]:r;}];
            for(NSString *key in keys){@autoreleasepool{NSDictionary *record=shows[key];double at=[record[@"episodeIndexAt"]doubleValue];
                if(packed){RWPackedEpisodes *videos=[RWPackedEpisodes archive:record[@"packed"] title:key];if(videos)[self store:[RWDiscoveryEpisodes immutableShow:@{@"id":key,@"type":@"series",@"videos":videos,@"episodeIndexAt":@(at)}] now:at];}
                else [self accept:record now:at];
            }}[self expire:now];
        }
    }return self;
}
- (void)remove:(NSString *)key {NSDictionary *old=_shows[key];if(!old)return;_episodes-=[old[@"videos"]count];_bytes-=Cost(old);[_shows removeObjectForKey:key];}
- (void)event:(NSString *)reason key:(NSString *)key record:(NSDictionary *)record now:(double)now {
    [_events addObject:@{@"id":key?:@"",@"reason":reason,@"at":@(now),@"receipt":record[@"episodeIndexAt"]?:@0,@"episodes":@([record[@"videos"]count])}];while(_events.count>32)[_events removeObjectAtIndex:0];
}
- (NSDictionary *)maintain:(NSString *)key now:(double)now {
    NSDictionary *m=_shows[key];if(!m||!isfinite(now))return nil;
    double at=[m[@"episodeIndexAt"]doubleValue];if(now<at)return nil;
    if(!Retained(m,now)){[self event:@"retention_expired" key:key record:m now:now];[self remove:key];return nil;}
    if(now-at>=86400&&![m[@"episodeIndexHistorical"]boolValue]){
        NSMutableArray *past=[NSMutableArray new];NSDate *receipt=[NSDate dateWithTimeIntervalSince1970:at];
        for(NSDictionary *episode in m[@"videos"])if([RWTVPolicy released:episode now:receipt])[past addObject:episode];
        [self event:past.count?@"retained_released_episodes":@"schedule_expired" key:key record:m now:now];[self remove:key];if(!past.count)return nil;
        // Preserve the original receipt. Future/undated entries never become
        // historical merely because their scheduled release date later passes.
        m=[RWDiscoveryEpisodes immutableShow:@{@"id":key,@"type":@"series",@"videos":[RWPackedEpisodes episodes:past title:key],@"episodeIndexAt":@(at),@"episodeIndexHistorical":@YES}];
        _shows[key]=m;_episodes+=past.count;_bytes+=Cost(m);
    }return m;
}
- (void)expire:(double)now {for(NSString *key in _shows.allKeys)[self maintain:key now:now];}
- (BOOL)accept:(NSDictionary *)show now:(double)now {
    show=Map(show);
    NSString *key=Text(show[@"id"]);NSDictionary *prior=_shows[key];BOOL existed=prior!=nil;[self remove:key];NSDictionary *compact=Compact(show,now);if(!compact){if(existed)[self event:@"replaced_by_invalid_or_empty_index" key:key record:prior now:now];return existed;}
    [self store:compact now:now];return YES;
}
- (void)store:(NSDictionary *)compact now:(double)now {
    [self expire:now];NSString *key=compact[@"id"];NSUInteger count=[compact[@"videos"]count],bytes=Cost(compact);
    [self remove:key];if(bytes>1024*1024)return;
    // The byte budget is unchanged. Packed entries permit more complete series
    // without retaining per-episode dictionaries or repeated title strings.
    while(_shows.count&&(_shows.count>=256||_episodes+count>32768||_bytes+bytes>1024*1024)){
        NSString *old=[_shows.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a,NSString *b){NSComparisonResult r=[self->_shows[a][@"episodeIndexAt"]compare:self->_shows[b][@"episodeIndexAt"]];return r==NSOrderedSame?[a compare:b]:r;}].firstObject;[self event:@"capacity_eviction" key:old record:_shows[old] now:now];[self remove:old];
    }
    _shows[key]=compact;_episodes+=count;_bytes+=bytes;
}
- (NSDictionary *)show:(NSString *)title now:(double)now {return [self maintain:title now:now];}
- (NSDictionary *)showsByAddingDetails:(NSDictionary *)details now:(double)now {[self expire:now];NSMutableDictionary *out=[_shows mutableCopy];[out addEntriesFromDictionary:details?:@{}];return out;}
- (NSDictionary *)snapshot {
    NSMutableDictionary *records=[NSMutableDictionary new];for(NSString *key in _shows){NSDictionary *show=_shows[key];records[key]=@{@"id":key,@"episodeIndexAt":show[@"episodeIndexAt"],@"packed":[(RWPackedEpisodes *)show[@"videos"]archive]};}
    return @{@"version":@2,@"shows":records};
}
- (NSDictionary *)diagnostics {return @{@"storage_schema":@2,@"shows":@(_shows.count),@"episodes":@(_episodes),@"estimated_bytes":@(_bytes),@"max_shows":@256,@"max_episodes":@32768,@"max_bytes":@(1024*1024),@"ttl_seconds":@86400,@"historical_retention_seconds":@(30*86400),@"events":[_events copy]};}
@end
