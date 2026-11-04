#import "RWPlaybackPreparation.h"
#import "TorrentEngine.h"

static BOOL SameTitle(NSDictionary *a,NSDictionary *b){
    if(!a||!b)return NO;
    for(NSString *key in @[@"profile_id",@"type",@"video_id",@"quality"])
        if(!a[key]||![a[key]isEqual:b[key]])return NO;
    return YES;
}
@implementation RWPlaybackPreparation {
    double (^_clock)(void);
    NSDictionary *_identity,*_expiredIdentity,*_snapshot;
    NSArray *_candidates;NSSet *_pinned;
    TorrentEngine *_engine;NSTimer *_timer;
    NSUInteger _generation;double _began,_cooldownUntil;
    BOOL _starting,_pollPending;
}
- (instancetype)init {return [self initWithClock:^{return NSProcessInfo.processInfo.systemUptime;}];}
- (instancetype)initWithClock:(double(^)(void))clock {if((self=[super init])){_clock=[clock copy];_snapshot=@{};}return self;}
- (NSDictionary *)diagnostics {return @{@"identity":_identity?:@{},@"detail_dwell_seconds":@(_identity?MAX(0,_clock()-_began):0),@"engine_created":@(_engine!=nil),@"preparation":_snapshot?:@{}};}
- (BOOL)canPrepareIdentity:(NSDictionary *)identity {return _clock()>=_cooldownUntil&&!SameTitle(_expiredIdentity,identity);}
- (BOOL)beginWithIdentity:(NSDictionary *)identity candidates:(NSArray *)candidates pinned:(NSSet *)pinned {
    NSAssert(NSThread.isMainThread,@"Preparation intent must run on main");
    if(![self canPrepareIdentity:identity])return NO;
    if(SameTitle(_identity,identity)){
        // The prefix contains container information needed by both Start over
        // and Resume. Carry the new target without rebuilding the connection.
        _identity=[identity copy];[self appendCandidates:candidates identity:identity];return NO;
    }
    [self cancel];_identity=[identity copy];_candidates=[candidates copy]?:@[];_pinned=[pinned copy]?:[NSSet set];_began=_clock();_snapshot=@{};
    _timer=[NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(tick) userInfo:nil repeats:YES];return YES;
}
- (void)appendCandidates:(NSArray *)candidates identity:(NSDictionary *)identity {
    if(!SameTitle(_identity,identity)||!candidates.count)return;
    _candidates=[candidates copy];if(_engine)[_engine perform:^(TorrentEngine *engine){[engine appendCandidates:candidates];}];
}
- (void)tick {
    if(!_identity)return;
    if(_clock()-_began>=45){NSDictionary *expired=_identity;[self cancel];_expiredIdentity=expired;return;}
    if(_clock()-_began<1)return;
    if(!_engine){
        if(_starting||!_candidates.count)return;
        _starting=YES;NSUInteger generation=_generation;__weak RWPlaybackPreparation *weak=self;
        [TorrentEngine afterCleanupWithPinned:_pinned ready:^{
            RWPlaybackPreparation *strong=weak;if(!strong||strong->_generation!=generation||!strong->_identity)return;
            strong->_starting=NO;strong->_engine=[TorrentEngine new];NSArray *sources=strong->_candidates;
            [strong->_engine perform:^(TorrentEngine *engine){[engine startPreparingCandidates:sources];}];[strong tick];
        }];return;
    }
    if(_pollPending)return;_pollPending=YES;
    BOOL payload=self.allowsPayload?self.allowsPayload():NO;NSUInteger generation=_generation;__weak RWPlaybackPreparation *weak=self;
    [_engine perform:^(TorrentEngine *engine){
        [engine setPreparationPayloadAllowed:payload];[engine discoverySnapshot];NSDictionary *snapshot=[engine preparationSnapshot];
        dispatch_async(dispatch_get_main_queue(),^{RWPlaybackPreparation *strong=weak;if(!strong||strong->_generation!=generation)return;strong->_pollPending=NO;strong->_snapshot=snapshot;});
    }];
}
- (TorrentEngine *)takeEngineForIdentity:(NSDictionary *)identity report:(NSDictionary **)report {
    NSAssert(NSThread.isMainThread,@"Preparation handoff must run on main");
    if(!SameTitle(_identity,identity)||!_engine){[self cancel];return nil;}
    if(report)*report=@{@"identity":_identity,@"requested_identity":[identity copy],@"detail_dwell_seconds":@(MAX(0,_clock()-_began)),@"preparation":_snapshot?:@{},@"cleanup_completed_before_play":@YES};
    TorrentEngine *engine=_engine;_engine=nil;[self cancel];return engine;
}
- (void)cancel {
    _generation++;[_timer invalidate];_timer=nil;TorrentEngine *engine=_engine;_engine=nil;
    _identity=nil;_expiredIdentity=nil;_candidates=nil;_starting=NO;_pollPending=NO;
    if(engine)[engine retireWithPinned:_pinned?:[NSSet set] completion:nil];_pinned=nil;
}
- (void)suspendForMemoryPressure {[self cancel];_cooldownUntil=_clock()+60;}
- (void)dealloc {[_timer invalidate];if(_engine)[_engine retireWithPinned:_pinned?:[NSSet set] completion:nil];}
@end
