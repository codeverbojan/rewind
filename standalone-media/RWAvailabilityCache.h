#import <Foundation/Foundation.h>

// Source observations are a regenerable cache, not the user's library/history.
// Retain all fields except these provider payloads unused by Rewind. Do not
// replace this with a title-field allowlist: new metadata must survive upgrades.
@interface RWAvailabilityCache : NSObject
+ (NSDictionary *)metadata:(NSDictionary *)metadata;
// Owner-thread startup migration. Copies changed paths, never edits aliases in
// saved/history/following. Returns the number of observations compacted.
+ (NSUInteger)compactState:(NSMutableDictionary *)state;
// Once after loading disk state: replace cache metadata with deeply owned
// snapshots, leaving all user/history aliases and observation values intact.
+ (NSUInteger)prepareSnapshots:(NSMutableDictionary *)state;
@end
