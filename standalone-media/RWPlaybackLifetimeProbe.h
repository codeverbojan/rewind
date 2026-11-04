#import <Foundation/Foundation.h>
// Observes weak lifetimes without prolonging player/transport ownership.
@interface RWPlaybackLifetimeProbe : NSObject
- (instancetype)initWithObjects:(NSDictionary *)objects;
- (NSDictionary *)snapshot;
@end
