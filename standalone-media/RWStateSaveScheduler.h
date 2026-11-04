#import <Foundation/Foundation.h>
// Main-thread owner. Batch replaceable background observations for one second;
// user edits and lifecycle flushes persist the current state immediately.
@interface RWStateSaveScheduler:NSObject
- (instancetype)initWithPersist:(void(^)(void))persist;
- (void)requestDeferred:(BOOL)deferred;
@property(nonatomic,readonly) BOOL pending;
@end
