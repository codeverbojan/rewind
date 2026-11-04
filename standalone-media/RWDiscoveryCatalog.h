#import <Foundation/Foundation.h>
@interface RWDiscoveryCatalog : NSObject
+ (NSArray *)balancedPool:(NSArray *)groups limit:(NSUInteger)limit allows:(BOOL(^)(NSDictionary *title))allows;
+ (NSArray *)merge:(NSArray *)incoming existing:(NSArray *)existing limit:(NSUInteger)limit;
+ (NSArray *)uniqueVisible:(NSArray *)items excluding:(NSSet *)excluded hidden:(NSArray *)hidden limit:(NSUInteger)limit;
+ (NSArray *)sortCredits:(NSArray *)items byRating:(BOOL)rating;
+ (NSDictionary *)mergeHome:(NSDictionary *)existing incoming:(NSDictionary *)incoming;
+ (NSDictionary *)filterHome:(NSDictionary *)home allows:(BOOL(^)(NSDictionary *title,NSString *row,BOOL hero))allows;
@end
