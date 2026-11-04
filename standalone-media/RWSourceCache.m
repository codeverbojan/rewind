#import "RWSourceCache.h"
#include <math.h>
@implementation RWSourceCache {
    NSMutableDictionary *_entries;
    NSUInteger _capacity;
    uint64_t _clock;
}
- (instancetype)initWithCapacity:(NSUInteger)capacity {if((self=[super init])){_capacity=MAX(1,MIN(32,capacity));_entries=[NSMutableDictionary new];}return self;}
- (NSArray *)sourcesForKey:(NSString *)key now:(double)now freshOnly:(BOOL)freshOnly {
    NSMutableDictionary *entry=_entries[key];if(!entry||!isfinite(now))return nil;
    double age=now-[entry[@"created"]doubleValue];
    if(age<0||age>=1800){[_entries removeObjectForKey:key];return nil;}
    if(freshOnly&&(age>=180||[entry[@"volatile"]boolValue]))return nil;
    entry[@"used"]=@(++_clock);return entry[@"sources"];
}
- (void)storeSources:(NSArray *)sources forKey:(NSString *)key now:(double)now {
    if(!key.length||!isfinite(now)||!sources.count)return;
    NSMutableArray *magnets=[NSMutableArray new];BOOL volatileURL=NO;
    for(id raw in sources){if(![raw isKindOfClass:NSDictionary.class])continue;
        NSString *url=[raw[@"url"]isKindOfClass:NSString.class]?raw[@"url"]:@"";
        if([url hasPrefix:@"magnet:"]){if(magnets.count<384)[magnets addObject:[raw copy]];}else if(url.length)volatileURL=YES;
    }
    if(!magnets.count){[_entries removeObjectForKey:key];return;}
    if(!_entries[key]&&_entries.count>=_capacity){
        NSString *oldest=nil;uint64_t order=UINT64_MAX;
        for(NSString *candidate in _entries){uint64_t used=[_entries[candidate][@"used"]unsignedLongLongValue];if(used<order){order=used;oldest=candidate;}}
        if(oldest)[_entries removeObjectForKey:oldest];
    }
    _entries[key]=[@{@"sources":[magnets copy],@"created":@(now),@"used":@(++_clock),@"volatile":@(volatileURL)}mutableCopy];
}
- (void)removeObjectForKey:(NSString *)key {[_entries removeObjectForKey:key];}
- (void)removeAllObjects {[_entries removeAllObjects];}
@end
