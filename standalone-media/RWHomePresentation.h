#import <Foundation/Foundation.h>
@interface RWHomePresentation : NSObject
+ (NSDictionary *)normalizedHome:(NSDictionary *)home;
+ (NSArray *)initialLoadingRows;
+ (NSDictionary *)cardText:(NSDictionary *)meta;
+ (NSDictionary *)posterContent:(NSDictionary *)meta;
+ (NSString *)heading:(NSDictionary *)row kids:(BOOL)kids;
+ (NSArray *)rows:(NSArray *)rows mediaType:(NSString *)type;
@end
