#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
static NSMutableArray *Jobs;
@interface AVPlayer:NSObject
@property(nonatomic,strong) NSMutableArray *callbacks;
@property(nonatomic,assign) NSUInteger plays;
@property(nonatomic,assign) CMTime target;
- (void)seekToTime:(CMTime)t toleranceBefore:(CMTime)b toleranceAfter:(CMTime)a completionHandler:(void(^)(BOOL))done;
- (void)play;
@end
@implementation AVPlayer
- (instancetype)init{if((self=[super init]))self.callbacks=[NSMutableArray new];return self;}
- (void)seekToTime:(CMTime)t toleranceBefore:(CMTime)b toleranceAfter:(CMTime)a completionHandler:(void(^)(BOOL))done{self.target=t;[self.callbacks addObject:[done copy]];}
- (void)play{self.plays++;}
@end
@interface TestMetrics:NSObject
@property(nonatomic,strong) NSMutableArray *events;
- (void)recordEvent:(NSString *)name values:(NSDictionary *)values uptime:(double)at;
@end
@implementation TestMetrics
- (instancetype)init{if((self=[super init]))self.events=[NSMutableArray new];return self;}
- (void)recordEvent:(NSString *)name values:(NSDictionary *)values uptime:(double)at{[self.events addObject:@{@"name":name,@"values":values}];}
@end
@interface RewindPlayer:NSObject
@property(nonatomic,strong) AVPlayer *player;
@property(nonatomic,strong) TestMetrics *metrics;
@property(nonatomic,assign) BOOL closing,wantsPlay,nativeSeekPending,nativeSeekFinished;
@property(nonatomic,assign) NSUInteger playbackGeneration,nativeSeekGeneration;
@property(nonatomic,assign) double nativeSeekStarted,nativeSeekCompleted,nativeSeekTarget,lastProgress;
- (void)seekNative:(double)target;
@end
@implementation RewindPlayer
#define dispatch_async(queue,...) [Jobs addObject:[(__VA_ARGS__) copy]]
#include "../RWNativeSeek.inc"
#undef dispatch_async
@end
static void Drain(void){while(Jobs.count){void(^job)(void)=[Jobs.firstObject copy];[Jobs removeObjectAtIndex:0];job();}}
static void Complete(AVPlayer *p,NSUInteger index,BOOL done){void(^callback)(BOOL)=p.callbacks[index];callback(done);}
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(x) do{checks++;if(!(x)){failures++;fprintf(stderr,"FAIL line%d\n",__LINE__);}}while(0)
 Jobs=[NSMutableArray new];RewindPlayer *v=[RewindPlayer new];AVPlayer *p=[AVPlayer new];v.player=p;v.metrics=[TestMetrics new];v.wantsPlay=YES;
 [v seekNative:480];CHECK(v.nativeSeekPending&&!v.nativeSeekFinished&&p.plays==0);CHECK(CMTimeGetSeconds(p.target)==480&&v.nativeSeekGeneration==1);
 Complete(p,0,YES);CHECK(v.nativeSeekPending&&p.plays==0);Drain();CHECK(!v.nativeSeekPending&&v.nativeSeekFinished&&p.plays==1&&v.lastProgress>0);
 CHECK([v.metrics.events.lastObject[@"values"][@"finished"]boolValue]);
 // Current user intent wins, even if it changed after AVPlayer finished but
 // before the completion reaches the main queue (pause or background).
 [v seekNative:490];Complete(p,1,YES);v.wantsPlay=NO;Drain();CHECK(p.plays==1&&!v.nativeSeekPending);
 [v seekNative:495];Complete(p,2,YES);v.wantsPlay=YES;Drain();CHECK(p.plays==2);
 // A superseded completion cannot clear the newer pending seek or play it.
 [v seekNative:500];[v seekNative:510];Complete(p,3,NO);Drain();CHECK(v.nativeSeekPending&&v.nativeSeekTarget==510&&p.plays==2);
 Complete(p,3,YES);Drain();CHECK(v.nativeSeekPending&&p.plays==2);
 Complete(p,4,YES);Drain();CHECK(!v.nativeSeekPending&&p.plays==3);
 [v seekNative:520];double progress=v.lastProgress;Complete(p,5,NO);Drain();CHECK(!v.nativeSeekPending&&!v.nativeSeekFinished&&p.plays==3&&v.lastProgress==progress);
 // Source replacement, close, another AVPlayer instance, and deallocation
 // must all reject callbacks owned by an old decoder.
 [v seekNative:530];Complete(p,6,YES);v.playbackGeneration++;v.nativeSeekPending=NO;Drain();CHECK(p.plays==3&&!v.nativeSeekPending);
 [v seekNative:540];Complete(p,7,YES);v.closing=YES;Drain();CHECK(p.plays==3);NSUInteger calls=p.callbacks.count;[v seekNative:550];CHECK(p.callbacks.count==calls);
 v.closing=NO;[v seekNative:550];AVPlayer *replacement=[AVPlayer new];v.player=replacement;Complete(p,8,YES);Drain();CHECK(p.plays==3&&replacement.plays==0);
 [v seekNative:NAN];CHECK(replacement.callbacks.count==0);v.player=nil;[v seekNative:600];CHECK(replacement.callbacks.count==0);
 v.player=replacement;[v seekNative:600];__weak RewindPlayer *weak=v;v=nil;CHECK(weak==nil);Complete(replacement,0,YES);Drain();CHECK(replacement.plays==0);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
