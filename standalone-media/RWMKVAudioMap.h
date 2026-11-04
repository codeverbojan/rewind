#import <Foundation/Foundation.h>
// Bind immutable header descriptors to actual VLC ES IDs. Never treat a
// container audio ordinal as a runtime ID. Unproven/ambiguous bindings omitted.
@interface RWMKVAudioMap : NSObject
+ (NSArray *)mapHeader:(NSArray *)header runtime:(NSArray *)runtime;
@end
