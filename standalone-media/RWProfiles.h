#import <Foundation/Foundation.h>
@interface RWProfiles : NSObject
+ (void)prepare:(NSMutableDictionary *)state;
+ (NSMutableDictionary *)active:(NSMutableDictionary *)state;
+ (NSMutableDictionary *)make:(NSString *)name age:(NSInteger)age;
+ (BOOL)requiresPINFrom:(NSDictionary *)from to:(NSDictionary *)to;
+ (BOOL)validPIN:(NSString *)pin;
+ (NSDictionary *)credential:(NSString *)pin;
+ (BOOL)verifyPIN:(NSString *)pin credential:(NSDictionary *)credential;
@end
