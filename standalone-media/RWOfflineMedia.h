#import <Foundation/Foundation.h>
@interface RWOfflineMedia : NSObject
// Called only after libtorrent has verified every selected-file piece and
// acknowledged a disk flush. This records file identity, not a new verifier.
+ (NSDictionary *)certificateForPath:(NSString *)path root:(NSString *)root hash:(NSString *)hash fileIndex:(NSInteger)fileIndex;
+ (BOOL)validate:(NSDictionary *)certificate root:(NSString *)root hash:(NSString *)hash fileIndex:(NSInteger)fileIndex;
@end
