#import "RWSourceWork.h"
static id SourceSnapshot(id value,NSUInteger depth,NSUInteger *remaining){
    if(!value||depth>32||!*remaining)return nil;(*remaining)--;
    if([value isKindOfClass:NSString.class]||[value isKindOfClass:NSNumber.class]||value==NSNull.null)return [value copy];
    if([value isKindOfClass:NSArray.class]){NSMutableArray *copy=[NSMutableArray new];for(id item in value){id captured=SourceSnapshot(item,depth+1,remaining);if(!captured)return nil;[copy addObject:captured];}return [copy copy];}
    if([value isKindOfClass:NSDictionary.class]){NSMutableDictionary *copy=[NSMutableDictionary new];for(id key in value){if(![key isKindOfClass:NSString.class])return nil;id captured=SourceSnapshot(value[key],depth+1,remaining);if(!captured)return nil;copy[[key copy]]=captured;}return [copy copy];}
    return nil;
}
@interface RWSourceWorkItem:NSObject
@property BOOL foreground;
@property(copy) BOOL(^valid)(void);
@property(copy) id(^task)(void);
@property(copy) void(^done)(id,NSString *);
@end
@implementation RWSourceWorkItem @end
@implementation RWSourceWork {NSMutableArray *_pending;dispatch_queue_t _queue;BOOL _active,_pumping;NSUInteger _submitted,_completed,_skipped,_rejected,_peak,_mainTasks;double _seconds,_maximum;}
+ (id)snapshot:(id)value {NSUInteger remaining=200000;return SourceSnapshot(value,0,&remaining);}
- (instancetype)init {if((self=[super init])){_pending=[NSMutableArray new];_queue=dispatch_queue_create("org.rewind.source-work",DISPATCH_QUEUE_SERIAL);}return self;}
- (NSDictionary *)diagnostics {NSAssert(NSThread.isMainThread,@"Read source queue on main");return @{@"submitted":@(_submitted),@"completed":@(_completed),@"skipped":@(_skipped),@"rejected":@(_rejected),@"pending":@(_pending.count),@"active":@(_active),@"peak":@(_peak),@"worker_seconds":@(_seconds),@"worker_max_seconds":@(_maximum),@"main_tasks":@(_mainTasks)};}
- (void)submitForeground:(BOOL)foreground valid:(BOOL(^)(void))valid task:(id(^)(void))task done:(void(^)(id,NSString *))done {
    NSAssert(NSThread.isMainThread,@"Submit source work on main");
    if(!valid()){_skipped++;done(nil,@"Source request changed.");return;}
    if(_pending.count+(_active?1:0)>=16){_rejected++;done(nil,@"Source processing is busy. Try again shortly.");return;}
    RWSourceWorkItem *item=[RWSourceWorkItem new];item.foreground=foreground;item.valid=valid;item.task=task;item.done=done;[_pending addObject:item];_submitted++;_peak=MAX(_peak,_pending.count+(_active?1:0));[self pump];
}
- (void)pump {
    if(_active||_pumping)return;_pumping=YES;
    while(_pending.count&&!_active){RWSourceWorkItem *item=_pending.firstObject;for(RWSourceWorkItem *candidate in _pending)if(candidate.foreground){item=candidate;break;}[_pending removeObjectIdenticalTo:item];
        if(!item.valid()){_skipped++;item.done(nil,@"Source request changed.");continue;}
        _active=YES;dispatch_async(_queue,^{@autoreleasepool{
            double began=NSProcessInfo.processInfo.systemUptime;BOOL main=NSThread.isMainThread;id result=item.task();double seconds=NSProcessInfo.processInfo.systemUptime-began;
            dispatch_async(dispatch_get_main_queue(),^{self->_active=NO;self->_completed++;self->_seconds+=seconds;self->_maximum=MAX(self->_maximum,seconds);if(main)self->_mainTasks++;
                if(item.valid())item.done(result,result?nil:@"Source processing failed.");else{self->_skipped++;item.done(nil,@"Source request changed.");}[self pump];});
        }});
    }_pumping=NO;
}
@end
