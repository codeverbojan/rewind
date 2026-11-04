#import <Foundation/Foundation.h>
enum { RWUpcomingCacheSchema = 2 };
static const NSUInteger RWUpcomingCacheBytes = 4 * 1024 * 1024;
@interface RWUpcomingPolicy : NSObject
+ (NSArray *)requests:(NSDate *)now;
+ (NSArray *)titles:(NSDictionary *)entities now:(double)now;
+ (NSString *)day:(NSDate *)now;
+ (NSArray *)scheduleRequests:(NSDate *)now days:(NSUInteger)days;
+ (NSArray *)scheduledTitles:(NSArray *)episodes now:(double)now query:(NSString *)query;
+ (BOOL)scheduled:(NSDictionary *)meta now:(double)now;
+ (NSString *)scheduleLabel:(NSDictionary *)meta;
+ (NSArray *)orderedTitles:(NSArray *)titles;
+ (NSUInteger)cachedDays:(NSDictionary *)cache now:(double)now;
+ (NSArray *)merge:(NSArray *)existing incoming:(NSArray *)incoming now:(double)now;
@end
