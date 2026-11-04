#import "RWCaptionClock.h"
#include <math.h>
@implementation RWCaptionClock {
    BOOL _requested,_running,_buffering,_hasSample,_coherent;
    double _position,_uptime;
    NSUInteger _samples,_estimates,_fallbacks,_resets;
}
- (instancetype)init {if((self=[super init]))_requested=YES;return self;}
- (void)invalidate {@synchronized(self){_hasSample=NO;_coherent=NO;_resets++;}}
- (void)setRequestedPlaying:(BOOL)value {@synchronized(self){_requested=value;[self invalidate];}}
- (void)setRunning:(BOOL)value {@synchronized(self){_running=value;[self invalidate];}}
- (void)setBuffering:(BOOL)value {@synchronized(self){if(value!=_buffering){_buffering=value;[self invalidate];}}}
- (BOOL)buffering {@synchronized(self){return _buffering;}}
- (void)sample:(double)position uptime:(double)uptime {
    @synchronized(self){
        if(!_requested||!_running||_buffering||!isfinite(position)||position<0||!isfinite(uptime)||uptime<0){[self invalidate];return;}
        double elapsed=uptime-_uptime,advance=position-_position;
        // Two consecutive 1x updates are required after every discontinuity.
        // A seek/jump, duplicate, reversed or long-delayed update cannot anchor
        // extrapolation. Never accumulate estimated time into a later anchor.
        _coherent=_hasSample&&elapsed>0&&elapsed<=.5&&advance>=.01&&fabs(advance-elapsed)<=.075;
        _position=position;_uptime=uptime;_hasSample=YES;_samples++;
    }
}
- (double)positionForReported:(double)reported uptime:(double)uptime eligible:(BOOL)eligible {
    @synchronized(self){
        double age=uptime-_uptime;
        // 300ms bounds the known 250ms period plus observed scheduling jitter.
        // Raw clock mismatch also closes the callback/getter ordering window.
        if(!eligible||!_requested||!_running||_buffering||!_coherent||!isfinite(reported)||!isfinite(uptime)||age<0||age>.3||fabs(reported-_position)>.003){_fallbacks++;return reported;}
        _estimates++;return reported+age;
    }
}
- (NSDictionary *)diagnostics {@synchronized(self){return @{@"requested":@(_requested),@"running":@(_running),@"buffering":@(_buffering),@"coherent":@(_coherent),@"samples":@(_samples),@"estimates":@(_estimates),@"fallbacks":@(_fallbacks),@"resets":@(_resets),@"anchor_position":@(_position),@"anchor_uptime":@(_uptime)};}}
@end
