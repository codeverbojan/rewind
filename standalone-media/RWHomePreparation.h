#import <Foundation/Foundation.h>
// Short-lived synchronous owner-thread pass. Never dispatch or retain across
// UI updates: its current inputs are live owner-side containers.
@interface RWHomeValidation : NSObject
- (instancetype)initWithRanked:(NSDictionary *)ranked fallback:(NSDictionary *)fallback snapshot:(NSDictionary *)snapshot ratings:(NSDictionary *)ratings profileID:(NSString *)profileID priors:(NSArray *)priors now:(double)now;
- (NSDictionary *)entryForTitle:(NSDictionary *)title now:(double)now;
- (NSDictionary *)entryForPreparedMetadata:(NSDictionary *)meta now:(double)now;
- (NSDictionary *)diagnostics;
@end
// Ephemeral presentation reuse, never persisted. prepare: receives isolated
// value snapshots on the worker. usable: compares synchronously on the current
// input's owner and does not retain that input. No additional worker queue.
@interface RWHomePreparation : NSObject
+ (BOOL)entry:(NSDictionary *)entry matchesTitle:(NSDictionary *)title;
+ (BOOL)allows:(NSDictionary *)meta preferences:(NSDictionary *)preferences restricted:(BOOL)restricted world:(BOOL)world hero:(BOOL)hero priors:(NSArray *)priors;
+ (NSDictionary *)prepare:(NSDictionary *)home snapshot:(NSDictionary *)snapshot ratings:(NSDictionary *)ratings profileID:(NSString *)profileID now:(double)now;
+ (NSDictionary *)usable:(NSDictionary *)prepared snapshot:(NSDictionary *)snapshot ratings:(NSDictionary *)ratings profileID:(NSString *)profileID priors:(NSArray *)priors now:(double)now;
+ (BOOL)matches:(NSDictionary *)prepared snapshot:(NSDictionary *)snapshot ratings:(NSDictionary *)ratings profileID:(NSString *)profileID priors:(NSArray *)priors now:(double)now;
@end
