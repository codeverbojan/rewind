#import <Foundation/Foundation.h>
@interface RWViewingSignals : NSObject
+ (NSDictionary *)merge:(NSDictionary *)previous metrics:(NSDictionary *)metrics duration:(double)duration;
+ (BOOL)meaningful:(NSDictionary *)record;
+ (BOOL)finished:(NSDictionary *)record;
@end
