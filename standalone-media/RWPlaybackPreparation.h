#import <Foundation/Foundation.h>
@class TorrentEngine;
@interface RWPlaybackPreparation : NSObject
@property(nonatomic,copy) BOOL (^allowsPayload)(void);
@property(nonatomic,readonly) NSDictionary *diagnostics;
- (instancetype)initWithClock:(double(^)(void))clock;
- (BOOL)canPrepareIdentity:(NSDictionary *)identity;
// Main queue only. Repeated renders of the same title share this intent.
- (BOOL)beginWithIdentity:(NSDictionary *)identity candidates:(NSArray *)candidates pinned:(NSSet *)pinned;
- (void)appendCandidates:(NSArray *)candidates identity:(NSDictionary *)identity;
- (TorrentEngine *)takeEngineForIdentity:(NSDictionary *)identity report:(NSDictionary **)report;
- (void)cancel;
- (void)suspendForMemoryPressure;
@end
