#import <Foundation/Foundation.h>
@interface RWUpcomingSelection : NSObject
+ (NSArray *)candidates:(NSArray *)catalog mode:(NSString *)mode snapshot:(NSDictionary *)snapshot following:(NSDictionary *)following watching:(NSDictionary *)watching;
// Worker-only value inputs; no store, network or UI access. Process all bounded
// schedule buckets in small preparation batches, not only the first 501 titles.
+ (NSArray *)items:(NSArray *)catalog mode:(NSString *)mode snapshot:(NSDictionary *)snapshot ratings:(NSDictionary *)ratings following:(NSDictionary *)following watching:(NSDictionary *)watching now:(double)now;
@end
