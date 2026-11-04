#import <Foundation/Foundation.h>
@interface RWRatingPolicy : NSObject
+ (NSDictionary *)recordForPublisher:(NSDictionary *)record imdb:(NSString *)imdb;
+ (NSDictionary *)recordForEntity:(NSDictionary *)entity imdb:(NSString *)imdb;
+ (BOOL)allows:(NSDictionary *)rating age:(NSInteger)age;
+ (BOOL)needsLookup:(NSDictionary *)rating type:(NSString *)type now:(double)now;
@end
