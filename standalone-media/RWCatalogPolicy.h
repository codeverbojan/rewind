#import <Foundation/Foundation.h>
@interface RWCatalogPolicy : NSObject
+ (NSString *)URLForType:(NSString *)type sort:(NSString *)sort genre:(NSString *)genre year:(NSInteger)year skip:(NSUInteger)skip now:(NSDate *)now;
+ (NSArray *)filter:(NSArray *)items genre:(NSString *)genre year:(NSInteger)year rating:(double)rating sort:(NSString *)sort now:(NSDate *)now;
@end
