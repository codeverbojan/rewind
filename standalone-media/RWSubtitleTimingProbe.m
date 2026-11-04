#import "RWSubtitleTimingProbe.h"
#import <QuartzCore/QuartzCore.h>
#import "RWMainThreadStallProbe.h"
#import "RWUIProbe.h"
#include <math.h>
@implementation RWSubtitleTimingProbe {
    CADisplayLink *_link;
    NSDictionary *(^_sample)(void);
    NSMutableArray *_samples,*_assignments;
    double _began,_cost,_maxCost;
    NSString *_stopped;
    RWMainThreadStallProbe *_stallProbe;
}
- (instancetype)initWithSample:(NSDictionary *(^)(void))sample {
    return [self initWithSample:sample watchMainThread:NO];
}
- (instancetype)initWithSample:(NSDictionary *(^)(void))sample watchMainThread:(BOOL)watch {
    if((self=[super init])){
        _sample=[sample copy];_samples=[NSMutableArray new];_assignments=[NSMutableArray new];
        _began=NSProcessInfo.processInfo.systemUptime;
        if(watch){_stallProbe=[[RWMainThreadStallProbe alloc]initOnMainThread];[[RWUIProbe shared]beginIntervalTrace];}
        _link=[CADisplayLink displayLinkWithTarget:self selector:@selector(observe:)];
        _link.frameInterval=3;[_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }return self;
}
- (void)observe:(CADisplayLink *)link {
    double now=NSProcessInfo.processInfo.systemUptime;
    if(now-_began>45||_samples.count>=1024){[self stop:@"bounded_limit"];return;}
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive){[self stop:@"inactive"];return;}
    NSDictionary *value=_sample?_sample():nil;
    if(!value){[self stop:@"player_unavailable"];return;}
    [_stallProbe pulsePlaying:[value[@"wants_play"]boolValue]&&[value[@"rate"]doubleValue]>0];
    NSMutableDictionary *entry=[value mutableCopy];entry[@"seconds"]=@(now-_began);[_samples addObject:entry];
    double cost=NSProcessInfo.processInfo.systemUptime-now;_cost+=cost;_maxCost=MAX(_maxCost,cost);
}
- (void)recordAssignment:(NSString *)text position:(double)position {
    if(_stopped||_assignments.count>=256||!isfinite(position))return;
    [_assignments addObject:@{@"seconds":@(NSProcessInfo.processInfo.systemUptime-_began),@"position":@(position),@"text":text?:@""}];
}
- (void)stop:(NSString *)reason {if(_stopped)return;_stopped=[reason copy];[_stallProbe stop];[_link invalidate];_link=nil;_sample=nil;}
- (NSDictionary *)summary {return @{@"status":_stopped?:@"running",@"samples":@(_samples.count),@"assignments":@(_assignments.count),@"observer_seconds":@(_cost),@"max_observer_seconds":@(_maxCost),@"frame_interval":@3};}
- (NSDictionary *)evidence {NSMutableDictionary *out=[[self summary]mutableCopy];out[@"began_uptime"]=@(_began);out[@"observations"]=[_samples copy];out[@"changes"]=[_assignments copy];if(_stallProbe){out[@"main_thread_stalls"]=[_stallProbe evidence];out[@"main_thread_intervals"]=[[RWUIProbe shared]intervalTrace];}return out;}
- (void)dealloc {[_link invalidate];}
@end
