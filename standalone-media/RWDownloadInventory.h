#import <Foundation/Foundation.h>
@interface RWDownloadInventory : NSObject
// Synchronous read-only inspection, for the media queue. Input contains only
// the active profile's immutable history and age-rating snapshot.
+ (NSDictionary *)snapshotRoot:(NSString *)root history:(NSArray *)history gate:(NSDictionary *)gate pinned:(NSSet *)pinned;
@end
