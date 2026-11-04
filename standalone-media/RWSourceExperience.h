#import <Foundation/Foundation.h>
@interface RWSourceExperience : NSObject
+ (NSString *)keyForSource:(NSDictionary *)source;
+ (NSString *)failureKind:(NSDictionary *)observation;
+ (NSDictionary *)record:(NSDictionary *)old source:(NSDictionary *)source success:(BOOL)success now:(double)now;
+ (NSDictionary *)record:(NSDictionary *)old source:(NSDictionary *)source success:(BOOL)success assessment:(NSDictionary *)assessment capability:(NSString *)capability now:(double)now;
+ (NSDictionary *)sourceForRanking:(NSDictionary *)source record:(NSDictionary *)record capability:(NSString *)capability now:(double)now;
+ (NSDictionary *)hints:(NSDictionary *)record now:(double)now;
+ (void)trim:(NSMutableDictionary *)history;
@end
