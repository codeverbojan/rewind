#import <Foundation/Foundation.h>
@interface RWTrailerPolicy : NSObject
+ (NSDictionary *)embeddedSource:(NSDictionary *)meta;
+ (BOOL)embeddedRuntimeFailure:(NSArray *)errors;
+ (NSArray *)appleIDs:(NSDictionary *)entity imdb:(NSString *)imdb;
+ (NSString *)cachedEntityID:(NSDictionary *)meta;
+ (BOOL)movieIdentityReady:(NSDictionary *)meta;
+ (NSDictionary *)source:(NSDictionary *)response ids:(NSArray *)ids meta:(NSDictionary *)meta;
@end
