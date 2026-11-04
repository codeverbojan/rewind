#import <Foundation/Foundation.h>
#import "../RWPlaybackPreparation.h"
#import "../TorrentEngine.h"
@interface RWPlaybackPreparation (TestClock)
- (void)tick;
@end
// Deterministic engine boundary: no sockets, filesystem or device writes.
static NSMutableArray *cleanupCallbacks,*engines;
static int starts,retires,appends,payloadAllowed,payloadBlocked,checks,failures;
@implementation TorrentEngine
+ (void)afterCleanupWithPinned:(NSSet *)pinned ready:(void (^)(void))ready {[cleanupCallbacks addObject:[ready copy]];}
- (instancetype)init {if((self=[super init]))[engines addObject:self];return self;}
- (void)perform:(void (^)(TorrentEngine *))work {work(self);}
- (void)startPreparingCandidates:(NSArray *)candidates {starts++;}
- (void)appendCandidates:(NSArray *)candidates {appends++;}
- (void)setPreparationPayloadAllowed:(BOOL)allowed {if(allowed)payloadAllowed++;else payloadBlocked++;}
- (NSDictionary *)discoverySnapshot {return @{};}
- (NSDictionary *)preparationSnapshot {return @{@"payload_bytes":@1024};}
- (void)retireWithPinned:(NSSet *)pinned completion:(void (^)(NSDictionary *))completion {retires++;if(completion)completion(@{});}
@end
static void check(BOOL ok,const char *message){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",message);}}
static void finishCleanup(void){NSArray *callbacks=[cleanupCallbacks copy];[cleanupCallbacks removeAllObjects];for(void(^callback)(void) in callbacks)callback();}
static void drain(void){[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];}
int main(){@autoreleasepool{
    cleanupCallbacks=[NSMutableArray new];engines=[NSMutableArray new];__block double now=100;
    RWPlaybackPreparation *p=[[RWPlaybackPreparation alloc]initWithClock:^{return now;}];__block BOOL allow=YES;p.allowsPayload=^{return allow;};
    NSDictionary *identity=@{@"profile_id":@"main",@"type":@"movie",@"video_id":@"fixture",@"quality":@0,@"resume_position_seconds":@0};
    NSArray *sources=@[@{@"infoHash":@"1111111111111111111111111111111111111111"}];
    check([p beginWithIdentity:identity candidates:sources pinned:[NSSet set]],"A new detail intent starts once");
    [p tick];check(starts==0&&cleanupCallbacks.count==0,"Passing over a title does not create an engine");
    now=101;[p tick];[p tick];check(cleanupCallbacks.count==1,"Repeated ticks share the pending cleanup");
    [p cancel];finishCleanup();check(starts==0,"Leaving during cleanup cannot create a late engine");
    [p beginWithIdentity:identity candidates:sources pinned:[NSSet set]];now=102;[p tick];finishCleanup();drain();
    check(starts==1&&engines.count==1,"One engine starts after cleanup completes");
    check(![p beginWithIdentity:identity candidates:sources pinned:[NSSet set]],"Repeated detail renders reuse the intent");
    allow=NO;[p tick];drain();check(payloadBlocked>0,"Trailer activity suspends payload without rebuilding metadata connections");
    allow=YES;[p tick];drain();check(payloadAllowed>0&&starts==1,"Payload can resume in the same engine");
    NSMutableDictionary *other=[identity mutableCopy];other[@"video_id"]=@"other";int previous=appends;
    [p appendCandidates:sources identity:other];check(appends==previous,"Late results from a previous title are ignored");
    NSMutableDictionary *resume=[identity mutableCopy];resume[@"resume_position_seconds"]=@600;
    NSDictionary *report=nil;TorrentEngine *taken=[p takeEngineForIdentity:resume report:&report];
    check(taken==engines[0]&&retires==0,"Play takes the exact existing engine without retiring it");
    check([report[@"requested_identity"][@"resume_position_seconds"]intValue]==600,"Handoff carries the effective resume request");
    [p cancel];check(retires==0,"Leaving details cannot retire the engine now owned by the player");
    [taken retireWithPinned:[NSSet set] completion:nil];
    now=110;[p beginWithIdentity:identity candidates:sources pinned:[NSSet set]];now=111;[p tick];finishCleanup();drain();
    NSMutableDictionary *kids=[identity mutableCopy];kids[@"profile_id"]=@"kids";
    check(![p takeEngineForIdentity:kids report:nil]&&retires==2,"A different profile cannot inherit a prepared engine");
    now=120;[p beginWithIdentity:identity candidates:sources pinned:[NSSet set]];now=121;[p tick];finishCleanup();drain();
    NSMutableDictionary *quality=[identity mutableCopy];quality[@"quality"]=@1080;
    check(![p takeEngineForIdentity:quality report:nil]&&retires==3,"A different quality cannot inherit the wrong candidates");
    now=130;[p beginWithIdentity:identity candidates:sources pinned:[NSSet set]];now=131;[p tick];finishCleanup();drain();
    now=175;[p tick];check(retires==4,"An idle details screen releases its engine after its lifetime budget");
    check(![p beginWithIdentity:identity candidates:sources pinned:[NSSet set]],"Rendering the expired title cannot restart its preload loop");
    [p cancel];now=180;check([p beginWithIdentity:identity candidates:sources pinned:[NSSet set]],"A deliberate new visit may prepare again");
    [p suspendForMemoryPressure];check(![p beginWithIdentity:identity candidates:sources pinned:[NSSet set]],"Memory pressure prevents immediate restart");
    now=241;check([p beginWithIdentity:identity candidates:sources pinned:[NSSet set]],"A later visit can prepare after the memory cooldown");
    [p cancel];check(cleanupCallbacks.count==0,"No deferred engine creation remains after cancellation");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
