#import <Foundation/Foundation.h>
@interface RWHomeCategoryPolicy : NSObject
+ (NSArray *)categoriesForKids:(BOOL)kids;
+ (BOOL)matches:(NSDictionary *)meta category:(NSDictionary *)category;
@end
