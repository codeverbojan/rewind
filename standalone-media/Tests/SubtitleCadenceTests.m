#import <Foundation/Foundation.h>
#import "../RWSubtitleTicker.h"
#import "../RWSubtitles.h"
static const int UIApplicationStateActive=0;
@interface UIApplication:NSObject
@property(nonatomic) int applicationState;
+ (instancetype)sharedApplication;
@end
@implementation UIApplication
+ (instancetype)sharedApplication {static UIApplication *a;static dispatch_once_t once;dispatch_once(&once,^{a=[UIApplication new];});return a;}
@end
@interface TestLabel:NSObject
@property(nonatomic,copy) NSString *text;
@end
@implementation TestLabel
@end
@interface TestTrace:NSObject
- (void)recordAssignment:(NSString *)text position:(double)position;
@end
@implementation TestTrace
- (void)recordAssignment:(NSString *)text position:(double)position{}
@end
@interface TestLegacyClock:NSObject
@property(nonatomic) double subtitlePosition;
@property(nonatomic) BOOL captionBuffering;
@end
@implementation TestLegacyClock
@end
@interface RewindPlayer:NSObject
@property(nonatomic,strong) TestLegacyClock *legacy;
@property(nonatomic,strong) NSArray *cues;
@property(nonatomic) BOOL wantsPlay,closing,exhausted,mediaVerified,seeking,nativeSeekPending;
@property(nonatomic) double position,rate,subtitleDelay;
@property(nonatomic,strong) TestLabel *subtitleLabel;
@property(nonatomic,strong) TestTrace *exerciseSubtitleTiming;
@property(nonatomic,strong) RWSubtitleTicker *subtitleTicker;
- (void)refreshSubtitleText;
@end
@implementation RewindPlayer
- (double)playbackPosition{return self.position;}
- (double)playbackRate{return self.rate;}
- (void)layoutSubtitle{}
#include "subtitle-cadence-under-test.inc"
@end
static int checks,failures;
static void check(BOOL pass){checks++;if(!pass){failures++;fprintf(stderr,"Failed check %d\n",checks);}}
static void Wait(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:end];}
int main(){@autoreleasepool{
    RewindPlayer *p=[RewindPlayer new];p.subtitleLabel=[TestLabel new];p.rate=1;p.mediaVerified=YES;p.wantsPlay=YES;p.position=.25;
    p.cues=[RWSubtitles parse:[@"1\n00:00:00,000 --> 00:00:01,000\nFirst\n\n2\n00:00:02,000 --> 00:00:03,000\nSecond\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [p refreshSubtitleText];check(p.subtitleTicker.running);check([p.subtitleLabel.text isEqual:@"First"]);
    p.legacy=[TestLegacyClock new];p.legacy.subtitlePosition=2.25;[p refreshSubtitleText];check([p.subtitleLabel.text isEqual:@"Second"]);p.wantsPlay=NO;[p refreshSubtitleText];check([p.subtitleLabel.text isEqual:@"First"]);p.wantsPlay=YES;p.legacy=nil;[p refreshSubtitleText];
    RWSubtitleTicker *original=p.subtitleTicker;for(int i=0;i<20;i++)[p refreshSubtitleText];check(p.subtitleTicker==original);
    p.position=1.25;Wait(.22);check(!p.subtitleLabel.text.length);p.position=2.25;Wait(.22);check([p.subtitleLabel.text isEqual:@"Second"]);
    p.wantsPlay=NO;Wait(.22);check(!p.subtitleTicker.running);p.position=.25;[p refreshSubtitleText];check([p.subtitleLabel.text isEqual:@"First"]&&!p.subtitleTicker.running);
    p.wantsPlay=YES;[p refreshSubtitleText];check(p.subtitleTicker.running);UIApplication.sharedApplication.applicationState=1;Wait(.22);check(!p.subtitleTicker.running);
    UIApplication.sharedApplication.applicationState=0;[p refreshSubtitleText];check(p.subtitleTicker.running);
    for(NSString *key in @[@"closing",@"exhausted",@"seeking",@"nativeSeekPending"]){[p setValue:@YES forKey:key];[p refreshSubtitleText];check(!p.subtitleTicker.running);[p setValue:@NO forKey:key];[p refreshSubtitleText];check(p.subtitleTicker.running);}
    // A seek can expose its destination clock while VLC is still showing the
    // preceding frame. Suppress live overlay text until buffering completes;
    // the same ticker restores it and paused-seek captions remain readable.
    p.legacy=[TestLegacyClock new];p.position=.25;p.legacy.subtitlePosition=2.25;p.legacy.captionBuffering=YES;
    [p refreshSubtitleText];check(!p.subtitleLabel.text.length);check(p.subtitleTicker.running);
    p.legacy.captionBuffering=NO;Wait(.22);check([p.subtitleLabel.text isEqual:@"Second"]);
    p.legacy.captionBuffering=YES;Wait(.22);check(!p.subtitleLabel.text.length);check(p.subtitleTicker.running);
    p.wantsPlay=NO;[p refreshSubtitleText];check([p.subtitleLabel.text isEqual:@"First"]&&!p.subtitleTicker.running);
    p.wantsPlay=YES;p.legacy.captionBuffering=NO;[p refreshSubtitleText];check([p.subtitleLabel.text isEqual:@"Second"]&&p.subtitleTicker.running);
    p.legacy=nil;p.position=2.25;[p refreshSubtitleText];check([p.subtitleLabel.text isEqual:@"Second"]);
    p.rate=0;[p refreshSubtitleText];check(!p.subtitleTicker.running);p.rate=1;p.mediaVerified=NO;[p refreshSubtitleText];check(!p.subtitleTicker.running);
    p.mediaVerified=YES;p.cues=nil;[p refreshSubtitleText];check(!p.subtitleTicker.running&&!p.subtitleLabel.text.length);
    __block int calls=0;RWSubtitleTicker *ticker=[[RWSubtitleTicker alloc]initWithStep:^BOOL{calls++;return NO;}];Wait(.3);check(calls==1&&!ticker.running);
    __weak RWSubtitleTicker *weak=ticker;ticker=nil;check(!weak);
    ticker=[[RWSubtitleTicker alloc]initWithStep:^BOOL{calls++;return YES;}];[ticker invalidate];[ticker invalidate];Wait(.15);check(calls==1&&!ticker.running);
    __block __weak RWSubtitleTicker *selfStop;calls=0;ticker=[[RWSubtitleTicker alloc]initWithStep:^BOOL{calls++;[selfStop invalidate];return YES;}];selfStop=ticker;Wait(.3);check(calls==1&&!ticker.running);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
