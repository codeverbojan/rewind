#import <Foundation/Foundation.h>
#include <math.h>
// Recheck compact snapshots on their consumer's clock, including snapshots
// already queued on a worker. Full detail metadata has its existing lifecycle.
static inline double RWEpisodeMetadataDeadline(NSDictionary *show) {
    id stamp=show[@"episodeIndexAt"];if(![stamp isKindOfClass:NSNumber.class])return 0;
    double at=[stamp doubleValue];if(!isfinite(at)||at<=0)return 0;
    return at+([show[@"episodeIndexHistorical"]isEqual:@YES]?30*86400:86400);
}
static inline BOOL RWEpisodeMetadataUsable(NSDictionary *show,double now) {
    id stamp=show[@"episodeIndexAt"];if(!stamp)return YES;
    if(![stamp isKindOfClass:NSNumber.class])return NO;double at=[stamp doubleValue];
    return isfinite(at)&&isfinite(now)&&at>0&&now>=at&&now<RWEpisodeMetadataDeadline(show);
}
// Canonical episode metadata only. Source health, age policy, history and the
// selected episode are never cached here. Full detail pages keep their own cache.
@interface RWEpisodeCatalog : NSObject
- (instancetype)initWithSnapshot:(NSDictionary *)snapshot now:(double)now;
- (BOOL)accept:(NSDictionary *)show now:(double)now;
- (NSDictionary *)show:(NSString *)title now:(double)now;
- (NSDictionary *)showsByAddingDetails:(NSDictionary *)details now:(double)now;
- (NSDictionary *)snapshot;
- (NSDictionary *)diagnostics;
@end
