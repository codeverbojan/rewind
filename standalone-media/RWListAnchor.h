#import <Foundation/Foundation.h>
@interface RWListAnchor : NSObject
+ (NSDictionary *)capture:(NSArray *)items index:(NSUInteger)index delta:(double)delta;
+ (NSUInteger)index:(NSDictionary *)anchor items:(NSArray *)items;
@end
