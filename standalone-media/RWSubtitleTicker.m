#import "RWSubtitleTicker.h"
@implementation RWSubtitleTicker {
    NSTimer *_timer;
    BOOL(^_step)(void);
}
- (instancetype)initWithStep:(BOOL(^)(void))step {
    return [self initWithStep:step interval:.1];
}
- (instancetype)initWithStep:(BOOL(^)(void))step interval:(NSTimeInterval)interval {
    if((self=[super init])){
        _step=[step copy];
        // Only the measured MKV caption path requests20Hz; native remains10Hz.
        // No arbitrary high-frequency or unbounded timer intervals.
        _timer=[NSTimer timerWithTimeInterval:interval==.05?.05:.1 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
        [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
    }return self;
}
- (BOOL)running {return _timer.isValid;}
- (void)tick:(NSTimer *)timer {
    // A callback can clear captions and invalidate this timer itself.
    BOOL(^step)(void)=[_step copy];if(!step||!step())[self invalidate];
}
- (void)invalidate {[_timer invalidate];_timer=nil;_step=nil;}
- (void)dealloc {[_timer invalidate];}
@end
