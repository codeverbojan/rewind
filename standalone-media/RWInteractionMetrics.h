#import <Foundation/Foundation.h>
// Main-owned bounded sample storage; summary calculation can run on a worker
// over an immutable snapshot. No event contents, text or touch coordinates.
@interface RWInteractionMetrics : NSObject
- (void)add:(NSString *)kind seconds:(double)seconds context:(NSDictionary *)context;
- (NSDictionary *)snapshot;
+ (NSDictionary *)summarize:(NSDictionary *)snapshot;
@end
