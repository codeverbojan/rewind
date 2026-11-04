#import "RWPreviewDecoder.h"
#import "RWPreviewTrace.h"
#import <MobileVLCKit/vlc/vlc.h>
#include <atomic>
static void PreviewLog(void *data,int level,const libvlc_log_t *context,const char *format,va_list arguments){
    char message[769];vsnprintf(message,sizeof(message),format,arguments);const char *module=NULL;libvlc_log_get_context(context,&module,NULL,NULL);
    [(__bridge RWPreviewTrace *)data record:message module:module level:level];
}
static dispatch_queue_t PreviewQueue(void){static dispatch_queue_t queue;static dispatch_once_t once;dispatch_once(&once,^{queue=dispatch_queue_create("org.local.rewind.preview-decoder",DISPATCH_QUEUE_SERIAL);});return queue;}
static NSString *PreviewRoot(void){return [NSTemporaryDirectory()stringByAppendingPathComponent:@"RewindNativePreview"];}
static void PreviewRelease(libvlc_media_player_t *player,libvlc_media_t *media,libvlc_instance_t *instance,NSString *path,RWPreviewTrace *trace){
    __attribute__((objc_precise_lifetime)) RWPreviewTrace *retainedTrace=trace;
    // Unset waits for active log callbacks. The context stays alive until that
    // wait and the complete worker-side decoder release have finished.
    if(instance)libvlc_log_unset(instance);if(player){libvlc_media_player_stop(player);libvlc_media_player_release(player);}if(media)libvlc_media_release(media);if(instance)libvlc_release(instance);if(path)[[NSFileManager defaultManager]removeItemAtPath:path error:nil];
}
@implementation RWPreviewDecoder {
    libvlc_instance_t *_instance;libvlc_media_t *_media;libvlc_media_player_t *_player;UIView *_surface;NSString *_error,*_folder;NSDictionary *_source;RWPreviewTrace *_trace;std::atomic<bool> _stopped;BOOL _visible,_muted;
}
- (instancetype)initWithSource:(NSDictionary *)source {
    if((self=[super init])){NSAssert(NSThread.isMainThread,@"Create preview on main");static __weak RWPreviewDecoder *active;[active stop];active=self;_stopped.store(false);_muted=YES;_surface=[UIView new];_surface.backgroundColor=UIColor.blackColor;_surface.userInteractionEnabled=NO;
        // Paths are generated locally. No server, media download or external path
        // is created: only three bounded playlist descriptions are written.
        NSUInteger bytes=0;for(NSString *key in @[@"hlsMaster",@"hlsVideo",@"hlsAudio"]){if(![source[key]isKindOfClass:NSString.class]){_error=@"Incomplete preview description.";return self;}bytes+=[source[key]lengthOfBytesUsingEncoding:NSUTF8StringEncoding];}
        if(bytes>128*1024||![source[@"kind"]isEqual:@"apple-hls"]||[source[@"width"]integerValue]>1280||[source[@"height"]integerValue]>720){_error=@"Unsupported preview description.";return self;}
        _source=[source copy];__weak RWPreviewDecoder *weak=self;dispatch_async(PreviewQueue(),^{RWPreviewDecoder *owner=weak;if(!owner)return;@autoreleasepool{
            __block NSDictionary *description=nil;dispatch_sync(dispatch_get_main_queue(),^{if(!owner->_stopped.load())description=owner->_source;});if(!description)return;
            if(owner->_stopped.load())return;static dispatch_once_t cleanup;dispatch_once(&cleanup,^{[[NSFileManager defaultManager]removeItemAtPath:PreviewRoot() error:nil];});
            NSString *folder=[PreviewRoot()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];NSError *fileError=nil;[[NSFileManager defaultManager]createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:&fileError];
            for(NSArray *pair in @[@[@"hlsMaster",@"index.m3u8"],@[@"hlsVideo",@"video.m3u8"],@[@"hlsAudio",@"audio.m3u8"]])if(!fileError)[description[pair[0]]writeToFile:[folder stringByAppendingPathComponent:pair[1]] atomically:YES encoding:NSUTF8StringEncoding error:&fileError];
            libvlc_instance_t *instance=NULL;libvlc_media_t *media=NULL;libvlc_media_player_t *player=NULL;RWPreviewTrace *trace=[RWPreviewTrace new];
            if(!fileError&&!owner->_stopped.load()){
                // The iPad trace reaches text-renderer setup but never finishes
                // video-output initialization. Hero previews have no subtitle/OSD
                // surface, so skip that module; the movie player keeps its own
                // unchanged subtitle renderer. Keep the same startup deadline.
                const char *options[]={"--no-video-title-show","--no-sub-autodetect-file","--no-osd","--text-renderer=none","--avcodec-threads=2","--network-caching=800","--file-caching=300","--stats"};instance=libvlc_new((int)(sizeof(options)/sizeof(options[0])),options);
                if(instance)libvlc_log_set(instance,PreviewLog,(__bridge void *)trace);
                if(instance)media=libvlc_media_new_path(instance,[[folder stringByAppendingPathComponent:@"index.m3u8"]fileSystemRepresentation]);
                if(media){libvlc_media_add_option(media,":demux=adaptive");libvlc_media_add_option(media,":no-sub-autodetect-file");player=libvlc_media_player_new_from_media(media);}
            }
            // Main never waits on PreviewQueue. Publishing synchronously ensures
            // cancelled setup is released before a later decoder can be created.
            __block BOOL accepted=NO;dispatch_sync(dispatch_get_main_queue(),^{
                if(owner->_stopped.load())return;if(!player){owner->_error=fileError.localizedDescription?:@"The native preview decoder could not start.";return;}
                owner->_folder=folder;owner->_instance=instance;owner->_media=media;owner->_player=player;owner->_trace=trace;libvlc_video_set_mouse_input(player,0);libvlc_media_player_set_nsobject(player,(__bridge void *)owner->_surface);libvlc_audio_set_mute(player,owner->_muted);libvlc_audio_set_volume(player,100);libvlc_video_set_spu(player,-1);accepted=YES;
                if(owner->_visible)libvlc_media_player_play(player);
            });if(!accepted)PreviewRelease(player,media,instance,folder,trace);
        }});
    }return self;
}
- (UIView *)surface{return _surface;}
- (NSString *)error {if(_player&&libvlc_media_player_get_state(_player)==libvlc_Error)return @"The preview could not be decoded.";unsigned int w=0,h=0;if(_player&&!libvlc_video_get_size(_player,0,&w,&h)&&(w>1280||h>720))return @"Preview dimensions exceed the device limit.";return _error;}
- (BOOL)frameVisible {if(!_player||self.error)return NO;libvlc_media_stats_t stats={};return libvlc_media_get_stats(_media,&stats)&&stats.i_displayed_pictures>0;}
- (BOOL)ended{return _player&&libvlc_media_player_get_state(_player)==libvlc_Ended;}
- (double)position{return _player?MAX(0,libvlc_media_player_get_time(_player))/1000.:0;}
- (void)setVisible:(BOOL)visible muted:(BOOL)muted {
    _visible=visible;_muted=muted;if(!_player||_stopped.load())return;libvlc_audio_set_mute(_player,muted);
    if(!visible)libvlc_media_player_set_pause(_player,1);else if(libvlc_media_player_get_state(_player)==libvlc_NothingSpecial)libvlc_media_player_play(_player);else libvlc_media_player_set_pause(_player,0);
}
- (NSDictionary *)metrics {libvlc_media_stats_t s={};if(!_media||_stopped.load())return @{};libvlc_media_get_stats(_media,&s);return @{@"state":@(_player?libvlc_media_player_get_state(_player):libvlc_NothingSpecial),@"input_bytes":@(s.i_read_bytes),@"demux_bytes":@(s.i_demux_read_bytes),@"decoded_video":@(s.i_decoded_video),@"displayed_frames":@(s.i_displayed_pictures),@"decoded_audio":@(s.i_decoded_audio),@"played_audio_buffers":@(s.i_played_abuffers),@"lost_frames":@(s.i_lost_pictures),@"position":@(self.position),@"muted":@(_muted),@"surface":@{@"width":@(_surface.bounds.size.width),@"height":@(_surface.bounds.size.height),@"attached":@(_surface.window!=nil),@"alpha":@(_surface.alpha),@"children":@(_surface.subviews.count)},@"startup_trace":_trace.snapshot?:@{}};}
- (void)stop {
    if(_stopped.exchange(true))return;_source=nil;_surface.hidden=YES;libvlc_media_player_t *player=_player;libvlc_media_t *media=_media;libvlc_instance_t *instance=_instance;NSString *folder=_folder;UIView *surface=_surface;RWPreviewTrace *trace=_trace;_trace=nil;_surface=nil;_player=NULL;_media=NULL;_instance=NULL;_folder=nil;
    if(!player&&!media&&!instance&&!folder){[surface removeFromSuperview];return;}
    dispatch_async(PreviewQueue(),^{PreviewRelease(player,media,instance,folder,trace);dispatch_async(dispatch_get_main_queue(),^{[surface removeFromSuperview];});});
}
- (void)dealloc {[self stop];}
@end
