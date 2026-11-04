#import "RWUIProbe.h"
#import "RWInteractionMetrics.h"
#import "RewindStore.h"
#import <QuartzCore/QuartzCore.h>
@implementation RWUIProbe {RWInteractionMetrics *_metrics;CADisplayLink *_link;NSMutableArray *_pending,*_intervalTrace;double _traceUntil,_until,_lastTick,_lastPublish;NSUInteger _ticks;BOOL _publishing,_publishAgain;}
+ (instancetype)shared {static RWUIProbe *probe;static dispatch_once_t once;dispatch_once(&once,^{probe=[RWUIProbe new];});return probe;}
- (instancetype)init {if((self=[super init])){_metrics=[RWInteractionMetrics new];_pending=[NSMutableArray new];_context=@{@"screen":@"Launch"};}return self;}
- (void)resetMeasurements {_metrics=[RWInteractionMetrics new];[_pending removeAllObjects];_lastTick=0;}
- (NSDictionary *)measurementSnapshot {return [_metrics snapshot];}
- (void)beginIntervalTrace {_intervalTrace=[NSMutableArray new];_traceUntil=NSProcessInfo.processInfo.systemUptime+45;}
- (NSArray *)intervalTrace {return [_intervalTrace copy]?:@[];}
- (void)wake {
    if(UIApplication.sharedApplication.applicationState==UIApplicationStateBackground)return;
    _until=NSProcessInfo.processInfo.systemUptime+3;
    if(!_link){_lastTick=0;_link=[CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];[_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];}
}
- (void)transition:(NSString *)kind started:(double)started {
    if(!isfinite(started)||started<=0)return;[self wake];
    for(NSDictionary *old in [_pending copy])if([old[@"kind"]isEqual:kind])[_pending removeObject:old];
    if(_pending.count>=12)[_pending removeObjectAtIndex:0];
    [_pending addObject:@{@"kind":kind,@"start":@(started),@"tick":@(_ticks),@"context":[self.context copy]?:@{}}];
}
- (void)touchTimestamp:(double)timestamp dispatched:(double)dispatched finished:(double)finished context:(NSDictionary *)context {
    if(timestamp>0&&timestamp<=dispatched)[_metrics add:@"touch_delivery_delay" seconds:dispatched-timestamp context:context];
    [_metrics add:@"touch_handler_duration" seconds:finished-dispatched context:context];
    [self transition:@"touch_to_display_callback" started:timestamp];
}
- (void)work:(NSString *)kind started:(double)started {
    // Aggregate locally; never encode/write a report from a measured scope.
    if(!NSThread.isMainThread)return;
    double end=NSProcessInfo.processInfo.systemUptime;[_metrics add:kind seconds:end-started context:self.context];
    if(_intervalTrace&&end<=_traceUntil&&end-started>=.003){if(_intervalTrace.count>=128)[_intervalTrace removeObjectAtIndex:0];[_intervalTrace addObject:@{@"kind":kind,@"start":@(started),@"end":@(end),@"screen":self.context[@"screen"]?:@""}];}
}
- (void)tick:(CADisplayLink *)link {
    double now=NSProcessInfo.processInfo.systemUptime;_ticks++;
    if(_lastTick>0)[_metrics add:@"display_callback_interval" seconds:now-_lastTick context:self.context];_lastTick=now;
    for(NSDictionary *pending in [_pending copy])if(_ticks-[pending[@"tick"]unsignedIntegerValue]>=2){
        // Two callbacks provide a display opportunity after view construction.
        // This is deliberately not named first-frame or screen-present latency.
        if([pending[@"context"]isEqual:self.context])[_metrics add:pending[@"kind"] seconds:now-[pending[@"start"]doubleValue] context:pending[@"context"]];[_pending removeObject:pending];
    }
    if(now>=_until){[self stop];return;}
    if(now-_lastPublish>=5)[self publish];
}
- (void)publish {
    if(_publishing){_publishAgain=YES;return;}_publishing=YES;_lastPublish=NSProcessInfo.processInfo.systemUptime;NSDictionary *snapshot=[_metrics snapshot];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0),^{NSDictionary *summary=[RWInteractionMetrics summarize:snapshot];dispatch_async(dispatch_get_main_queue(),^{self->_publishing=NO;[[RewindStore shared]report:@{@"interaction_metrics":@{@"surfaces":summary,@"window_seconds":@3,@"measurement":@"UIEvent timestamp to dispatch, handler work, and CADisplayLink callback gaps. Display-opportunity timings do not prove actual first pixels. Pre-main/icon launch time is excluded."}}];if(self->_publishAgain){self->_publishAgain=NO;[self publish];}});});
}
- (void)stop {[_link invalidate];_link=nil;_lastTick=0;[_pending removeAllObjects];[self publish];}
@end
@implementation RWApplication
- (void)sendEvent:(UIEvent *)event {
    double began=NSProcessInfo.processInfo.systemUptime;BOOL ended=NO,active=NO;
    if([RWUIProbe shared].deviceExerciseActive&&event.type==UIEventTypeTouches)for(UITouch *touch in event.allTouches)if(touch.phase==UITouchPhaseBegan){[[NSNotificationCenter defaultCenter]postNotificationName:@"RWDeviceExerciseUserTouch" object:nil];break;}
    if(event.type==UIEventTypeTouches)for(UITouch *touch in event.allTouches){ended|=touch.phase==UITouchPhaseEnded;active|=touch.phase==UITouchPhaseBegan||touch.phase==UITouchPhaseMoved||touch.phase==UITouchPhaseEnded;}
    if(event.type==UIEventTypeTouches)for(UITouch *touch in event.allTouches)if(touch.phase==UITouchPhaseBegan){[[NSNotificationCenter defaultCenter]postNotificationName:@"RWUserTouchBegan" object:nil];break;}
    RWUIProbe *probe=[RWUIProbe shared];NSDictionary *context=probe.context;if(active)[probe wake];
    [super sendEvent:event];
    if(ended)[probe touchTimestamp:event.timestamp dispatched:began finished:NSProcessInfo.processInfo.systemUptime context:context];
}
@end
