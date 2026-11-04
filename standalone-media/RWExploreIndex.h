#import <Foundation/Foundation.h>
// Pure local index over an already age-gated, immutable title snapshot. It is
// deliberately labelled as local discovery, not a global people search.
@interface RWExploreIndex : NSObject
+ (NSArray *)records:(NSArray *)titles kind:(NSString *)kind mood:(NSString *)mood query:(NSString *)query profile:(NSString *)profile entities:(NSDictionary *)entities now:(double)now;
+ (NSArray *)records:(NSArray *)titles kind:(NSString *)kind mood:(NSString *)mood query:(NSString *)query profile:(NSString *)profile preferences:(NSDictionary *)preferences restricted:(BOOL)restricted entities:(NSDictionary *)entities now:(double)now;
+ (NSArray *)moodNames;
+ (NSString *)moodDescription:(NSString *)mood;
@end
