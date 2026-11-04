#import <Foundation/Foundation.h>
@interface RWSkipPolicy : NSObject
+ (NSArray *)segments:(NSDictionary *)response imdb:(NSString *)imdb season:(NSInteger)season episode:(NSInteger)episode duration:(double)duration;
@end
