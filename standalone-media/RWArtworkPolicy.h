#import <Foundation/Foundation.h>
@interface RWArtworkPolicy : NSObject
+ (NSArray *)URLsForMeta:(NSDictionary *)meta landscape:(BOOL)landscape;
+ (NSArray *)validURLs:(NSArray *)urls;
+ (NSDictionary *)requestForRole:(NSString *)role identity:(NSString *)identity width:(double)width height:(double)height scale:(double)scale;
+ (NSString *)variantKey:(NSString *)url request:(NSDictionary *)request;
+ (NSDictionary *)sizing:(NSDictionary *)request sourceWidth:(double)width height:(double)height;
@end
