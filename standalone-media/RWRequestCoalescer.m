#import "RWRequestCoalescer.h"
@implementation RWRequestCoalescer {
    NSMutableDictionary *_pending;
    NSUInteger _joinedCount;
}
- (instancetype)init {if((self=[super init]))_pending=[NSMutableDictionary new];return self;}
- (NSUInteger)joinedCount {return _joinedCount;}
- (void)perform:(NSString *)key start:(void (^)(RWLookupResult))start done:(RWLookupResult)done {
    NSAssert(NSThread.isMainThread,@"Lookups must run on the main queue");
    NSMutableArray *waiters=_pending[key];
    if(waiters){if(waiters.count>=64){done(nil,@"Too many requests for this title. Try again shortly.");return;}[waiters addObject:[done copy]];_joinedCount++;return;}
    if(_pending.count>=64){done(nil,@"Too many requests are still pending. Try again shortly.");return;}
    waiters=[NSMutableArray arrayWithObject:[done copy]];_pending[key]=waiters;
    __weak RWRequestCoalescer *weak=self;
    start(^(id result,NSString *error){
        RWRequestCoalescer *strong=weak;if(!strong||strong->_pending[key]!=waiters)return;
        NSArray *callbacks=[waiters copy];[strong->_pending removeObjectForKey:key];
        // Release callbacks before calling them: a callback may start a retry.
        [waiters removeAllObjects];for(RWLookupResult callback in callbacks)callback(result,error);
    });
}
@end
