#import "RWStateSaveScheduler.h"
@implementation RWStateSaveScheduler {
    void(^_persist)(void);BOOL _pending;
}
- (instancetype)initWithPersist:(void(^)(void))persist {if((self=[super init]))_persist=[persist copy];return self;}
- (BOOL)pending {return _pending;}
- (void)requestDeferred:(BOOL)deferred {
    if(deferred){if(!_pending){_pending=YES;[self performSelector:@selector(flush) withObject:nil afterDelay:1];}}
    else [self flush];
}
- (void)flush {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(flush) object:nil];_pending=NO;if(_persist)_persist();
}
@end
