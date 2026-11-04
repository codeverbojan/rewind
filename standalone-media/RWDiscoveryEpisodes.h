#import <Foundation/Foundation.h>
// Per-profile cache of validated episode identity/date and the viewing target.
// Invalidate after history changes; replacing a show's metadata invalidates it
// automatically. No torrent data or cross-profile state is retained.
@interface RWDiscoveryEpisodes : NSObject
- (NSDictionary *)episode:(NSString *)requested show:(NSDictionary *)show history:(NSDictionary *)history now:(NSDate *)now;
- (void)invalidate:(NSString *)title;
- (void)removeAll;
// Deep-capture metadata once at ingress. Only this owned snapshot can share
// indexes across workers; array class-cluster identity is not an ownership proof.
+ (NSDictionary *)immutableShow:(NSDictionary *)show;
+ (void)purgeReusableIndexes;
@property(nonatomic,readonly) NSDictionary *diagnostics;
@end
