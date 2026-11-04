#import <Foundation/Foundation.h>
@interface RWDetailPresentation : NSObject
+ (NSDictionary *)textForMeta:(NSDictionary *)meta rating:(NSDictionary *)rating;
+ (NSDictionary *)layoutForWidth:(double)width;
@end
