#import <Foundation/Foundation.h>
@interface RWMediaCache : NSObject
+ (uint64_t)allocatedBytesAt:(NSString *)path;
+ (NSDictionary *)trimRoot:(NSString *)root pinned:(NSSet *)pinned budget:(uint64_t)budget;
+ (NSDictionary *)trimRoot:(NSString *)root pinned:(NSSet *)pinned active:(NSSet *)active budget:(uint64_t)budget;
@end
