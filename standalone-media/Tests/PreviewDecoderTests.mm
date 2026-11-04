#import "../RWPreviewDecoder.h"
#import "../RWPreviewTrace.h"
#import <MobileVLCKit/vlc/vlc.h>
#include <atomic>
#include <unistd.h>
static int Checks,Failures;static std::atomic<int> Active{0},Peak{0},Created{0},Released{0},Views{0},LastPause{-1};static std::atomic<bool> HoldCreate{false},HoldStop{false},MainUI{true},WorkerLifecycle{true};
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static void UI(){if(!NSThread.isMainThread)MainUI=false;}
@implementation UIColor
+ (instancetype)blackColor {UI();return [self new];}
@end
@implementation UIView
- (instancetype)init {if((self=[super init])){UI();Views++;}return self;}
- (void)setHidden:(BOOL)value{UI();_hidden=value;}
- (void)setUserInteractionEnabled:(BOOL)value{UI();_userInteractionEnabled=value;}
- (void)setBackgroundColor:(UIColor *)value{UI();_backgroundColor=value;}
- (void)removeFromSuperview{UI();}
- (UIView *)window{UI();return self;}
- (NSArray *)subviews{UI();return @[];}
- (void)dealloc{UI();Views--;}
@end
struct libvlc_instance_t{libvlc_log_cb log=NULL;void *context=NULL;};struct libvlc_media_t{bool playing=false,displayed=false;};struct libvlc_media_player_t{libvlc_media_t *media;bool started=false,muted=false;};
static void Emit(libvlc_instance_t *p,int level,const char *format,...){if(!p->log)return;va_list args;va_start(args,format);libvlc_log_t context={"adaptive"};p->log(p->context,level,&context,format,args);va_end(args);}
void libvlc_log_get_context(const libvlc_log_t *p,const char **module,const char **,unsigned *){*module=p->module;}
void libvlc_log_set(libvlc_instance_t *p,libvlc_log_cb log,void *context){if(NSThread.isMainThread)WorkerLifecycle=false;p->log=log;p->context=context;Emit(p,0,"initializing preview %s","https://cdn.example.test/private/asset?secret=PRIVATE");}
void libvlc_log_unset(libvlc_instance_t *p){if(NSThread.isMainThread)WorkerLifecycle=false;Emit(p,3,"retiring decoder");p->log=NULL;p->context=NULL;}
libvlc_instance_t *libvlc_new(int,const char *const *){if(NSThread.isMainThread)WorkerLifecycle=false;int n=++Active;Peak=MAX(Peak.load(),n);Created++;while(HoldCreate.load())usleep(1000);return new libvlc_instance_t;}
void libvlc_release(libvlc_instance_t *p){if(NSThread.isMainThread||p->log||p->context)WorkerLifecycle=false;delete p;Active--;Released++;}
libvlc_media_t *libvlc_media_new_path(libvlc_instance_t *,const char *p){if(NSThread.isMainThread)WorkerLifecycle=false;return access(p,R_OK)==0?new libvlc_media_t:NULL;}
void libvlc_media_release(libvlc_media_t *p){delete p;}
void libvlc_media_add_option(libvlc_media_t *,const char *){}
libvlc_media_player_t *libvlc_media_player_new_from_media(libvlc_media_t *m){return new libvlc_media_player_t{m,false,false};}
void libvlc_media_player_stop(libvlc_media_player_t *p){if(NSThread.isMainThread)WorkerLifecycle=false;while(HoldStop.load())usleep(1000);p->media->playing=false;}
void libvlc_media_player_release(libvlc_media_player_t *p){delete p;}
void libvlc_video_set_mouse_input(libvlc_media_player_t *,unsigned){UI();}
void libvlc_media_player_set_nsobject(libvlc_media_player_t *,void *){UI();}
void libvlc_audio_set_mute(libvlc_media_player_t *p,int m){UI();p->muted=m;}
int libvlc_audio_set_volume(libvlc_media_player_t *,int){UI();return 0;}
int libvlc_video_set_spu(libvlc_media_player_t *,int){UI();return 0;}
int libvlc_media_player_play(libvlc_media_player_t *p){UI();p->started=true;p->media->playing=true;p->media->displayed=true;return 0;}
void libvlc_media_player_set_pause(libvlc_media_player_t *p,int pause){UI();p->media->playing=!pause;LastPause=pause;}
libvlc_state_t libvlc_media_player_get_state(libvlc_media_player_t *p){return !p->started?libvlc_NothingSpecial:p->media->playing?libvlc_Playing:libvlc_Paused;}
int libvlc_video_get_size(libvlc_media_player_t *,unsigned,unsigned *w,unsigned *h){*w=100;*h=100;return 0;}
int64_t libvlc_media_player_get_time(libvlc_media_player_t *){return 200;}
int libvlc_media_get_stats(libvlc_media_t *m,libvlc_media_stats_t *s){if(m->displayed){s->i_displayed_pictures=5;s->i_decoded_video=10;s->i_decoded_audio=20;s->i_played_abuffers=20;}return 1;}
static BOOL Until(BOOL(^test)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:2];while(!test()&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];return test();}
int main(){@autoreleasepool{
    NSString *root=[NSTemporaryDirectory()stringByAppendingPathComponent:@"RewindNativePreview"];if([[NSFileManager defaultManager]fileExistsAtPath:root]){fprintf(stderr,"Refusing to remove an existing test directory\n");return 2;}
    NSDictionary *source=@{@"kind":@"apple-hls",@"hlsMaster":@"#EXTM3U\n",@"hlsVideo":@"#EXTM3U\n",@"hlsAudio":@"#EXTM3U\n",@"width":@100,@"height":@100};RWPreviewDecoder *a=nil,*last=nil;
    @try{
        a=[[RWPreviewDecoder alloc]initWithSource:source];[a setVisible:YES muted:YES];CHECK(Until(^BOOL{return a.frameVisible;}));CHECK(a.position>.05&&!a.error);CHECK([a.metrics[@"muted"]boolValue]);[a setVisible:NO muted:YES];CHECK(LastPause.load()==1);[a setVisible:YES muted:NO];CHECK(LastPause.load()==0&&a.frameVisible&&![a.metrics[@"muted"]boolValue]);
        CHECK([a.metrics[@"startup_trace"][@"first"]count]==1);CHECK(![[a.metrics description]containsString:@"PRIVATE"]);CHECK([a.metrics[@"surface"][@"attached"]boolValue]);
        HoldStop=true;double began=NSProcessInfo.processInfo.systemUptime;[a stop];CHECK(NSProcessInfo.processInfo.systemUptime-began<.05);CHECK(!a.surface&&!a.frameVisible);a=nil;
        // A stalled release must not retain abandoned view/playlist jobs.
        NSHashTable *abandoned=[NSHashTable weakObjectsHashTable];for(int i=0;i<40;i++){@autoreleasepool{last=[[RWPreviewDecoder alloc]initWithSource:source];[last setVisible:YES muted:YES];[abandoned addObject:last];}}
        CHECK(abandoned.allObjects.count==1);CHECK(Views.load()<=2);CHECK(Created.load()==1&&Peak.load()==1);HoldStop=false;CHECK(Until(^BOOL{return last.frameVisible;}));CHECK(Created.load()==2&&Peak.load()==1);[last stop];last=nil;CHECK(Until(^BOOL{return Views.load()==0&&Active.load()==0;}));
        // Cancelling during worker setup must not release UIKit objects off-main.
        HoldCreate=true;a=[[RWPreviewDecoder alloc]initWithSource:source];CHECK(Until(^BOOL{return Active.load()==1;}));[a stop];a=nil;CHECK(Views.load()==0);HoldCreate=false;CHECK(Until(^BOOL{return Active.load()==0;}));
        NSMutableDictionary *huge=[source mutableCopy];huge[@"hlsVideo"]=[@"a" stringByPaddingToLength:128*1024+1 withString:@"a" startingAtIndex:0];a=[[RWPreviewDecoder alloc]initWithSource:huge];CHECK(a.error.length);[a stop];a=nil;
        CHECK(MainUI.load()&&WorkerLifecycle.load());CHECK(Peak.load()==1&&Created.load()==Released.load());CHECK(Until(^BOOL{return [[NSFileManager defaultManager]contentsOfDirectoryAtPath:root error:nil].count==0;}));
        // Decoder callbacks may be concurrent. Retention, formatting and total
        // work are bounded; neither remote URLs nor local paths enter reports.
        RWPreviewTrace *trace=[RWPreviewTrace new];[trace record:"failed HTTP https://cdn.test/a?key=SECRET /private/var/mobile/SECRET" module:"http" level:4];
        [trace record:"Authorization: Bearer SECRET" module:"http" level:4];
        dispatch_apply(4,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^(size_t index){for(int i=0;i<1100;i++)[trace record:"buffering 25 percent" module:"adaptive" level:i%2?0:3];});
        NSDictionary *snapshot=trace.snapshot;CHECK([snapshot[@"messages"]integerValue]==4402);CHECK([snapshot[@"dropped"]integerValue]==306);CHECK([snapshot[@"first"]count]==16&&[snapshot[@"recent"]count]==48&&[snapshot[@"warnings_errors"]count]==16);
        CHECK(![snapshot.description containsString:@"SECRET"]&&![snapshot.description containsString:@"cdn.test"]);CHECK([snapshot.description containsString:@"buffering 25 percent"]);CHECK([NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil].length<24000);
    }@finally{HoldStop=false;HoldCreate=false;[a stop];[last stop];a=nil;last=nil;Until(^BOOL{return Active.load()==0&&Views.load()==0;});if([[NSFileManager defaultManager]contentsOfDirectoryAtPath:root error:nil].count==0)[[NSFileManager defaultManager]removeItemAtPath:root error:nil];}
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
