#import <Foundation/Foundation.h>
@interface RWAvailability : NSObject
+ (NSDictionary *)observeAnalysis:(NSDictionary *)analysis complete:(BOOL)complete error:(NSString *)error quality:(NSInteger)quality now:(double)now;
+ (NSDictionary *)observe:(NSArray *)sources complete:(BOOL)complete error:(NSString *)error now:(double)now;
+ (NSDictionary *)observe:(NSArray *)sources complete:(BOOL)complete error:(NSString *)error quality:(NSInteger)quality now:(double)now;
+ (NSDictionary *)presentation:(NSDictionary *)meta observation:(NSDictionary *)observation now:(double)now;
+ (NSDictionary *)presentation:(NSDictionary *)meta observation:(NSDictionary *)observation quality:(NSInteger)quality now:(double)now;
+ (BOOL)futureRelease:(NSDictionary *)meta now:(double)now;
+ (NSDictionary *)ready:(NSDictionary *)observation sourceKey:(NSString *)sourceKey quality:(NSInteger)quality now:(double)now;
+ (NSDictionary *)failed:(NSDictionary *)observation sourceKey:(NSString *)sourceKey now:(double)now;
+ (BOOL)newOptions:(NSDictionary *)before after:(NSDictionary *)after;
@end
