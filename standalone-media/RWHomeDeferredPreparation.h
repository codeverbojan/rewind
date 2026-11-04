#import <Foundation/Foundation.h>
// Revalidate cached Home membership independently of the 500-title ranking job.
// UI still owns live gates; no network, persistence, UIKit or new worker queue.
@interface RWHomeDeferredPreparation : NSObject
+ (NSDictionary *)boundedPlan:(NSDictionary *)home;
+ (NSDictionary *)prepare:(NSDictionary *)home snapshot:(NSDictionary *)snapshot ratings:(NSDictionary *)ratings profileID:(NSString *)profileID now:(double)now;
+ (NSDictionary *)prepare:(NSDictionary *)home requestedIDs:(NSSet *)requested previous:(NSDictionary *)previous snapshot:(NSDictionary *)snapshot ratings:(NSDictionary *)ratings profileID:(NSString *)profileID now:(double)now;
+ (BOOL)entry:(NSDictionary *)entry matchesTitle:(NSDictionary *)title;
@end
