#import "RWMetadataBudget.h"
@interface RWMetadataWork : NSObject
@property(nonatomic,strong) NSURLSessionTask *task;
@property(nonatomic,strong) NSString *host;
@property(nonatomic,assign) BOOL foreground,held,cancelling;
@property(nonatomic,assign) NSUInteger sequence;
@end
@implementation RWMetadataWork @end
@implementation RWMetadataBudget {
    NSMutableArray *_pending,*_active;BOOL _paused,_backgroundPaused,_draining;
    NSUInteger _sequence,_peakActive,_peakHost,_preemptions,_rejected;
}
+ (instancetype)shared {static RWMetadataBudget *value;static dispatch_once_t once;dispatch_once(&once,^{value=[RWMetadataBudget new];});return value;}
- (instancetype)init {if((self=[super init])){_pending=[NSMutableArray new];_active=[NSMutableArray new];}return self;}
- (RWMetadataWork *)work:(NSURLSessionTask *)task {for(RWMetadataWork *w in _active)if(w.task==task)return w;for(RWMetadataWork *w in _pending)if(w.task==task)return w;return nil;}
- (NSDictionary *)diagnostics {
    NSAssert(NSThread.isMainThread,@"Read metadata counters on main");NSMutableDictionary *hosts=[NSMutableDictionary new];NSUInteger cancelling=0,held=0;
    for(RWMetadataWork *w in _active){hosts[w.host]=@([hosts[w.host]integerValue]+1);if(w.cancelling)cancelling++;}
    for(RWMetadataWork *w in _pending)if(w.held)held++;
    return @{@"active":@(_active.count),@"pending":@(_pending.count),@"held":@(held),@"cancelling":@(cancelling),@"hosts":hosts,@"peak_active":@(_peakActive),@"peak_per_host":@(_peakHost),@"preemptions":@(_preemptions),@"rejected":@(_rejected),@"paused":@(_paused),@"background_paused":@(_backgroundPaused)};
}
- (void)enqueue:(NSURLSessionTask *)task foreground:(BOOL)foreground {
    if(!task)return;if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self enqueue:task foreground:foreground];});return;}
    if(task.state==NSURLSessionTaskStateCompleted||task.state==NSURLSessionTaskStateCanceling)return;
    RWMetadataWork *w=[self work:task];if(w){w.held=NO;w.foreground|=foreground;[self drain];return;}
    NSString *host=task.originalRequest.URL.host.lowercaseString;if(!host.length||_pending.count+_active.count>=64){_rejected++;[task cancel];return;}
    w=[RWMetadataWork new];w.task=task;w.host=host;w.foreground=foreground;w.sequence=++_sequence;[_pending addObject:w];[self drain];
}
- (void)complete:(NSURLSessionTask *)task {
    if(!task)return;if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self complete:task];});return;}
    RWMetadataWork *w=[self work:task];if(!w)return;[_active removeObjectIdenticalTo:w];[_pending removeObjectIdenticalTo:w];[self drain];
}
- (void)cancel:(NSURLSessionTask *)task {
    if(!task)return;if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self cancel:task];});return;}
    RWMetadataWork *w=[self work:task];if(!w){[task cancel];return;}
    if([_active containsObject:w]){w.cancelling=YES;[task cancel];}else{[_pending removeObjectIdenticalTo:w];[task cancel];}
    // A cancelling live request retains its slot until its completion callback.
    // Otherwise a replacement could briefly exceed the real network budget.
    [self drain];
}
- (void)suspendWork:(RWMetadataWork *)w {
    if(![_active containsObject:w]||w.cancelling)return;
    [w.task suspend];[_active removeObjectIdenticalTo:w];[_pending addObject:w];
}
- (void)hold:(NSURLSessionTask *)task {
    if(!task)return;if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self hold:task];});return;}
    RWMetadataWork *w=[self work:task];if(!w)return;w.held=YES;[self suspendWork:w];[self drain];
}
- (BOOL)paused {return _paused;}
- (BOOL)backgroundPaused {return _backgroundPaused;}
- (void)setBackgroundPaused:(BOOL)paused {
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{self.backgroundPaused=paused;});return;}
    if(_backgroundPaused==paused)return;_backgroundPaused=paused;
    if(paused)for(RWMetadataWork *w in [_active copy])if(!w.foreground)[self suspendWork:w];
    [self drain];
}
- (void)setPaused:(BOOL)paused {
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{self.paused=paused;});return;}
    if(_paused==paused)return;_paused=paused;if(paused)for(RWMetadataWork *w in [_active copy])[self suspendWork:w];else [self drain];
}
- (void)drain {
    if(_paused||_draining)return;_draining=YES;
    // Discard terminal tasks even when a client reports completion twice or an
    // external owner cancelled a task before the gate was notified.
    for(RWMetadataWork *w in [_pending copy])if(w.task.state==NSURLSessionTaskStateCompleted||w.task.state==NSURLSessionTaskStateCanceling)[_pending removeObjectIdenticalTo:w];
    [_pending sortUsingComparator:^NSComparisonResult(RWMetadataWork *a,RWMetadataWork *b){if(a.foreground!=b.foreground)return a.foreground?NSOrderedAscending:NSOrderedDescending;return a.sequence<b.sequence?NSOrderedAscending:NSOrderedDescending;}];
    for(RWMetadataWork *candidate in [_pending copy]){
        if(candidate.held||(_backgroundPaused&&!candidate.foreground))continue;RWMetadataWork *sameHost=nil;for(RWMetadataWork *w in _active)if([w.host isEqual:candidate.host]){sameHost=w;break;}
        if(candidate.foreground){
            if(sameHost&&!sameHost.foreground&&!sameHost.cancelling){[self suspendWork:sameHost];_preemptions++;sameHost=nil;}
            if(!sameHost&&_active.count>=2)for(RWMetadataWork *w in [[_active copy] reverseObjectEnumerator])if(!w.foreground&&!w.cancelling){[self suspendWork:w];_preemptions++;break;}
        }
        if(sameHost||_active.count>=2)continue;
        [_pending removeObjectIdenticalTo:candidate];[_active addObject:candidate];_peakActive=MAX(_peakActive,_active.count);NSUInteger matching=0;for(RWMetadataWork *w in _active)if([w.host isEqual:candidate.host])matching++;_peakHost=MAX(_peakHost,matching);[candidate.task resume];
    }_draining=NO;
}
@end
