#import <Foundation/Foundation.h>

// Pure preparation over an isolated snapshot. No live store, UIKit, file or
// network access; safe to run on the serial recommendation queue.
@interface RWDiscoverySnapshot : NSObject
+ (BOOL)matches:(NSDictionary *)snapshot profile:(NSDictionary *)profile quality:(NSInteger)quality;
+ (NSArray *)ratingIDs:(NSArray *)items snapshot:(NSDictionary *)snapshot includeSignals:(BOOL)includeSignals now:(double)now;
+ (NSDictionary *)prepareItems:(NSArray *)items snapshot:(NSDictionary *)snapshot ratings:(NSDictionary *)ratings now:(double)now;
+ (NSArray *)pool:(NSDictionary *)snapshot;
+ (NSArray *)filter:(NSArray *)items snapshot:(NSDictionary *)snapshot;
+ (NSDictionary *)prepare:(NSArray *)items snapshot:(NSDictionary *)snapshot ratings:(NSDictionary *)ratings now:(double)now;
@end
