#import <Foundation/Foundation.h>
typedef long long libvlc_time_t;
typedef struct {libvlc_time_t time,lastSeek;BOOL seekable;int seeks,track,requests;BOOL reject;} TestPlayer;
static BOOL libvlc_media_player_is_seekable(TestPlayer *p){return p->seekable;}
static libvlc_time_t libvlc_media_player_get_time(TestPlayer *p){return p->time;}
static void libvlc_media_player_set_time(TestPlayer *p,libvlc_time_t time){p->lastSeek=time;p->seeks++;}
static int libvlc_video_get_spu(TestPlayer *p){return p->track;}
static int libvlc_video_set_spu(TestPlayer *p,int track){if(p->reject)return -1;p->track=track;p->requests++;return 0;}
static NSMutableArray *Jobs;
@interface RWLegacyPlayer:NSObject {@public BOOL _subtitleRefreshScheduled,_stopped,_wantPlay;TestPlayer *_player;NSUInteger _subtitleRefreshes;BOOL _subtitleEventsAttached,_subtitleRefreshAwaitingSelection;int _subtitleRefreshTrack;BOOL _subtitleTraceEnabled;NSMutableArray *_subtitleTrace;}
- (void)setSubtitleTraceEnabled:(BOOL)enabled;
- (void)recordSubtitleEvent:(NSString *)event track:(int)track at:(double)at;
- (void)schedulePausedSubtitleRefresh;
- (void)selectSubtitle:(int)identifier;
- (void)selectedSubtitleDidChange:(int)identifier;
@end
@implementation RWLegacyPlayer
#define dispatch_async(queue,block) [Jobs addObject:[block copy]]
#include "../RWLegacySubtitleRefresh.inc"
#undef dispatch_async
@end
static void Drain(void){while(Jobs.count){void(^job)(void)=[Jobs.firstObject copy];[Jobs removeObjectAtIndex:0];job();}}
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(x) do{checks++;if(!(x)){failures++;fprintf(stderr,"FAIL line%d\n",__LINE__);}}while(0)
 Jobs=[NSMutableArray new];TestPlayer media={12345,0,YES,0};RWLegacyPlayer *view=[RWLegacyPlayer new];view->_player=&media;
 [view schedulePausedSubtitleRefresh];[view schedulePausedSubtitleRefresh];CHECK(Jobs.count==1&&media.seeks==0);Drain();CHECK(media.seeks==1&&media.lastSeek==12345&&view->_subtitleRefreshes==1&&!view->_wantPlay);
 [view schedulePausedSubtitleRefresh];view->_wantPlay=YES;Drain();CHECK(media.seeks==1);[view schedulePausedSubtitleRefresh];CHECK(Jobs.count==0);
 view->_wantPlay=NO;[view schedulePausedSubtitleRefresh];view->_stopped=YES;Drain();CHECK(media.seeks==1);[view schedulePausedSubtitleRefresh];CHECK(Jobs.count==0);
 view->_stopped=NO;media.seekable=NO;[view schedulePausedSubtitleRefresh];CHECK(Jobs.count==0);media.seekable=YES;
 [view schedulePausedSubtitleRefresh];media.seekable=NO;Drain();CHECK(media.seeks==1);media.seekable=YES;
 [view schedulePausedSubtitleRefresh];view->_player=NULL;Drain();CHECK(media.seeks==1);[view schedulePausedSubtitleRefresh];CHECK(Jobs.count==0);
 view->_player=&media;media.time=-1;[view schedulePausedSubtitleRefresh];Drain();CHECK(media.seeks==1);
 media.time=22000;[view schedulePausedSubtitleRefresh];Drain();CHECK(media.seeks==2&&media.lastSeek==22000);
 [view schedulePausedSubtitleRefresh];view=nil;Drain();CHECK(media.seeks==2&&Jobs.count==0);
 // The input worker has not switched decoders when set_spu returns.
 view=[RWLegacyPlayer new];view->_player=&media;view->_subtitleEventsAttached=YES;media.track=-1;int before=media.seeks;
 [view selectSubtitle:2];[view schedulePausedSubtitleRefresh];Drain();CHECK(media.seeks==before&&view->_subtitleRefreshAwaitingSelection);
 [view selectedSubtitleDidChange:-1];Drain();CHECK(media.seeks==before&&view->_subtitleRefreshAwaitingSelection);
 [view selectedSubtitleDidChange:2];Drain();CHECK(media.seeks==before+1&&!view->_subtitleRefreshAwaitingSelection);
 [view selectedSubtitleDidChange:2];Drain();CHECK(media.seeks==before+1);
 [view selectSubtitle:-1];[view selectSubtitle:3];[view selectedSubtitleDidChange:-1];Drain();CHECK(media.seeks==before+1);
 [view selectedSubtitleDidChange:3];Drain();CHECK(media.seeks==before+2);
 [view selectSubtitle:2];view->_wantPlay=YES;[view selectedSubtitleDidChange:2];Drain();CHECK(media.seeks==before+2&&!view->_subtitleRefreshAwaitingSelection);
 view->_wantPlay=NO;media.reject=YES;[view selectSubtitle:3];Drain();CHECK(!view->_subtitleRefreshAwaitingSelection&&media.seeks==before+2);media.reject=NO;
 [view selectSubtitle:-1];view->_stopped=YES;[view selectedSubtitleDidChange:-1];Drain();CHECK(media.seeks==before+2);
 view->_stopped=NO;view->_subtitleRefreshAwaitingSelection=NO;[view schedulePausedSubtitleRefresh];[view selectSubtitle:2];Drain();CHECK(media.seeks==before+2);
 [view selectedSubtitleDidChange:2];Drain();CHECK(media.seeks==before+3);
 // Reselecting an already active track still redraws a paused cue.
 before=media.seeks;int requests=media.requests;[view selectSubtitle:media.track];Drain();CHECK(media.seeks==before+1&&media.requests==requests);
 view->_wantPlay=YES;[view selectSubtitle:media.track];Drain();CHECK(media.seeks==before+1&&media.requests==requests);
 CHECK(view->_subtitleTrace==nil);[view setSubtitleTraceEnabled:YES];view->_wantPlay=NO;
 before=media.seeks;[view selectSubtitle:media.track];Drain();CHECK(media.seeks==before+1);CHECK(view->_subtitleTrace.count==3);
 CHECK([view->_subtitleTrace[0][@"event"]isEqual:@"selection-request"]);CHECK([view->_subtitleTrace[2][@"event"]isEqual:@"refresh-issued"]);
 CHECK(![view->_subtitleTrace[2][@"wants_play"]boolValue]);
 for(int n=0;n<40;n++)[view recordSubtitleEvent:@"bounded" track:n at:123];
 CHECK(view->_subtitleTrace.count==32&&[view->_subtitleTrace[0][@"track"]intValue]==8);CHECK([view->_subtitleTrace.lastObject[@"at"]doubleValue]==123);
 CHECK([view->_subtitleTrace.lastObject[@"observed"]doubleValue]>123);[view setSubtitleTraceEnabled:NO];CHECK(!view->_subtitleTrace);
 [view recordSubtitleEvent:@"disabled" track:0 at:0];CHECK(!view->_subtitleTrace);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
