#import "RWLegacyPlayer.h"
#import "RWRemoteMKVProbe.h"
#import "TorrentEngine.h"
#import "RWSourcePolicy.h"
#import "RWMKVProbe.h"
#import "RWAudioPolicy.h"
#import "RWSubtitlePolicy.h"
#import "RWMKVAudioMap.h"
#import "RWCaptionClock.h"
#import <MobileVLCKit/vlc/vlc.h>
#include <atomic>
#include <fcntl.h>
#include <unistd.h>
#include "RWLegacyPresentationTrace.inc"
#include "RWLegacyStartupTrace.h"
#include "RWLegacyCaptionClock.inc"
#define VLC_FOURCC(a,b,c,d) ((uint32_t)(a)|((uint32_t)(b)<<8)|((uint32_t)(c)<<16)|((uint32_t)(d)<<24))

@interface RWVerifiedInput : NSObject {
@public std::atomic<bool> cancelled;
    std::atomic<int64_t> readOffset,totalReadBytes;std::atomic<int> readWaitMS,readTimeouts,seeks;
}
@property(nonatomic,strong) TorrentEngine *engine;
@property(nonatomic,assign) int64_t size;
@property(nonatomic,strong) NSString *file;
@property(nonatomic,strong) RWLegacyStartupTrace *startupTrace;
@end
@implementation RWVerifiedInput
@end
struct RWReadCursor { void *input; uint64_t offset; int fd; };
static int RWOpen(void *opaque,void **data,uint64_t *size) {
    RWVerifiedInput *input=(__bridge RWVerifiedInput *)opaque;
    if(input->cancelled.load())return -1;
    int fd=input.file?open(input.file.fileSystemRepresentation,O_RDONLY):-1;if(input.file&&fd<0)return -1;
    *data=new RWReadCursor{(__bridge_retained void *)input,0,fd};*size=(uint64_t)input.size;return 0;
}
static ssize_t RWRead(void *opaque,unsigned char *buffer,size_t length) {
    RWReadCursor *cursor=(RWReadCursor *)opaque;RWVerifiedInput *input=(__bridge RWVerifiedInput *)cursor->input;
    if(input->cancelled.load())return -1;if(cursor->offset>=(uint64_t)input.size)return 0;
    if(cursor->fd>=0){double began=input.startupTrace?NSProcessInfo.processInfo.systemUptime:0;ssize_t count=pread(cursor->fd,buffer,MIN(length,(size_t)256*1024),(off_t)cursor->offset);if(count>0)cursor->offset+=count;if(input.startupTrace){double now=NSProcessInfo.processInfo.systemUptime;[input.startupTrace readBytes:count seconds:now-began at:now];}return count;}
    // Never report temporary missing pieces as EOF. Wait only on VLC's worker,
    // bound the read and allow cancellation without waiting for the main queue.
    double began=NSProcessInfo.processInfo.systemUptime;input->readOffset.store(cursor->offset);
    while(!input->cancelled.load()&&NSProcessInfo.processInfo.systemUptime-began<60) {
        @autoreleasepool {
            __block NSData *bytes=nil;uint64_t offset=cursor->offset;
            dispatch_sync(input.engine.workQueue,^{
                if(input->cancelled.load())return;
                [input.engine prioritizeOffset:(int64_t)offset length:2*1024*1024];
                bytes=[input.engine readVerifiedBytesAt:(int64_t)offset length:MIN(length,(size_t)256*1024)];
            });
            if(input->cancelled.load())return -1;
            if(bytes.length){memcpy(buffer,bytes.bytes,bytes.length);cursor->offset+=bytes.length;input->totalReadBytes.fetch_add(bytes.length);input->readWaitMS.store(0);if(input.startupTrace){double now=NSProcessInfo.processInfo.systemUptime;[input.startupTrace readBytes:bytes.length seconds:now-began at:now];}return (ssize_t)bytes.length;}
            input->readWaitMS.store(int((NSProcessInfo.processInfo.systemUptime-began)*1000));
            [NSThread sleepForTimeInterval:.05];
        }
    }if(!input->cancelled.load())input->readTimeouts.fetch_add(1);return -1;
}
static int RWSeek(void *opaque,uint64_t offset) {
    RWReadCursor *c=(RWReadCursor *)opaque;RWVerifiedInput *input=(__bridge RWVerifiedInput *)c->input;
    if(input->cancelled.load()||offset>(uint64_t)input.size)return -1;c->offset=offset;input->seeks.fetch_add(1);return 0;
}
static void RWClose(void *opaque) {
    RWReadCursor *c=(RWReadCursor *)opaque;if(c->fd>=0)close(c->fd);id retained=CFBridgingRelease(c->input);(void)retained;delete c;
}
static void RWStartupLog(void *opaque,int level,const libvlc_log_t *context,const char *format,va_list args){
    (void)level;(void)context;@autoreleasepool{[(__bridge RWLegacyStartupTrace *)opaque log:format arguments:args at:NSProcessInfo.processInfo.systemUptime];}
}
// VLC reports completed decoder selection from its input worker. The bridge
// holds only a weak player callback and outlives event detachment during stop.
@interface RWLegacySubtitleEvents : NSObject
@property(nonatomic,copy) void (^selected)(int,double);
@end
@implementation RWLegacySubtitleEvents
@end
static void RWSubtitleSelected(const libvlc_event_t *event,void *opaque) {
    if(event->u.media_player_es_changed.i_type!=libvlc_track_text)return;
    @autoreleasepool {
        RWLegacySubtitleEvents *events=(__bridge RWLegacySubtitleEvents *)opaque;
        void (^selected)(int,double)=[events.selected copy];int identifier=event->u.media_player_es_changed.i_id;double at=NSProcessInfo.processInfo.systemUptime;
        if(selected)dispatch_async(dispatch_get_main_queue(),^{selected(identifier,at);});
    }
}
@interface RWLegacyPlayer (SubtitleEvents)
- (void)selectedSubtitleDidChange:(int)identifier;
@end
@implementation RWLegacyPlayer {
    libvlc_instance_t *_instance;libvlc_media_t *_media;libvlc_media_player_t *_player;
    RWVerifiedInput *_input;NSMutableData *_header;NSDictionary *_headerProbe;UIView *_surface;NSString *_error;NSDictionary *_probe;
    BOOL _ready,_stopped,_wantPlay,_headerReadPending,_stereoConfigured;NSInteger _quality;double _began;
    RWRemoteMKVProbe *_remoteProbe;BOOL _networkInput,_subtitleRefreshScheduled;NSUInteger _subtitleRefreshes;
    RWLegacySubtitleEvents *_subtitleEvents;BOOL _subtitleEventsAttached,_subtitleRefreshAwaitingSelection;int _subtitleRefreshTrack;BOOL _subtitleTraceEnabled;NSMutableArray *_subtitleTrace;
    BOOL _subtitleCaptureBusy;NSUInteger _subtitleCaptureCount;RWLegacyPresentationTrace *_presentationTrace;
    NSArray *_audioTracks,*_runtimeAudio;NSDictionary *_audioSelection,*_audioPending;BOOL _audioPendingManual;double _audioStarted,_audioChangeStarted;
    RWLegacyStartupTrace *_startupTrace;NSString *_startupFont;
    RWCaptionClock *_captionClock;BOOL _captionClockAttached;
}
- (instancetype)initWithEngine:(TorrentEngine *)engine size:(int64_t)size file:(NSString *)file quality:(NSInteger)quality {
    return [self initWithEngine:engine size:size file:file quality:quality diagnosticFont:nil];
}
- (instancetype)initWithEngine:(TorrentEngine *)engine size:(int64_t)size file:(NSString *)file quality:(NSInteger)quality diagnosticFont:(NSString *)font {
    if((self=[super init])) {
        // Exact PostScript name avoids the slow family-wide CoreText query on
        // iOS9. The explicit default value is only for the owned A/B diagnostic.
        _startupFont=[font isEqual:@"default"]?@"default":[font isEqual:@"Arial"]?@"Arial":@"HelveticaNeue";
        NSURL *remote=file?[NSURL URLWithString:file]:nil;_networkInput=[@[@"http",@"https"]containsObject:remote.scheme.lowercaseString];
        _quality=quality;_header=[NSMutableData new];if(file&&!_networkInput){NSFileHandle *f=[NSFileHandle fileHandleForReadingAtPath:file];[_header appendData:[f readDataOfLength:2*1024*1024]?:[NSData data]];[f closeFile];}_wantPlay=YES;_surface=[UIView new];_surface.backgroundColor=UIColor.blackColor;_began=NSProcessInfo.processInfo.systemUptime;
        // VLC 3 defaults to a 16 MiB prefetch/read window. Its worker can block
        // on a missing middle piece before servicing the demuxer's metadata seek.
        // A bounded window reproduced 0.47s vs 10.46s startup in the gap fixture.
        const char *fontOption=[_startupFont isEqual:@"HelveticaNeue"]?"--freetype-font=HelveticaNeue":"--freetype-font=Arial";
        const char *options[]={"--no-snapshot-preview","--no-video-title-show","--no-sub-autodetect-file","--no-osd","--avcodec-threads=2","--file-caching=1200","--network-caching=1500","--prefetch-buffer-size=64","--prefetch-read-size=16384","--stats",fontOption};
        // Statistics prove decoded pictures and audio. No web server, device
        // discovery, or network renderer is enabled.
        int optionCount=(int)(sizeof(options)/sizeof(options[0]))-([_startupFont isEqual:@"default"]?1:0);
        _instance=libvlc_new(optionCount,options);
        if(!_instance){_error=@"The MKV player could not start.";return self;}
        _input=[RWVerifiedInput new];_input->cancelled.store(false);_input->readOffset.store(0);_input->totalReadBytes.store(0);_input->readWaitMS.store(0);_input->readTimeouts.store(0);_input->seeks.store(0);_input.engine=engine;_input.file=file;_input.size=file?[[[NSFileManager defaultManager]attributesOfItemAtPath:file error:nil][NSFileSize]longLongValue]:size;
        if(_networkInput){
            __weak RWLegacyPlayer *weak=self;
            _remoteProbe=[[RWRemoteMKVProbe alloc]initWithURL:remote completion:^(NSDictionary *media,NSURL *resolved,NSString *error){
                RWLegacyPlayer *strong=weak;if(!strong||strong->_stopped)return;
                if(error){strong->_error=error;return;}strong->_headerProbe=media;
                strong->_media=libvlc_media_new_location(strong->_instance,resolved.absoluteString.UTF8String);
                if(!strong->_media){strong->_error=@"This stream could not be opened.";return;}
                libvlc_media_add_option(strong->_media,":no-sub-autodetect-file");[strong poll];
            }];
        }else{
            _media=libvlc_media_new_callbacks(_instance,RWOpen,RWRead,RWSeek,RWClose,(__bridge void *)_input);
            if(!_media){_error=@"This media could not be opened.";return self;}
            libvlc_media_add_option(_media,":no-sub-autodetect-file");
        }
        // VLC 3's preparser always skips imem callback inputs. Inspect the
        // verified EBML track header ourselves before creating a decoder.
    }return self;
}
- (UIView *)surface{return _surface;}
- (NSString *)error{return _error;}
- (NSDictionary *)probe{return _probe;}
- (BOOL)ready{return _ready;}
- (BOOL)startupTraceEnabled{return _startupTrace!=nil;}
- (void)setStartupTraceEnabled:(BOOL)enabled {
    if(!enabled||_startupTrace||_stopped||!_instance||_player)return;
    _startupTrace=[[RWLegacyStartupTrace alloc]initAt:_began];_input.startupTrace=_startupTrace;
    [_startupTrace event:@"trace_armed_after_instance" at:NSProcessInfo.processInfo.systemUptime values:@{}];
    libvlc_log_set(_instance,RWStartupLog,(__bridge void *)_startupTrace);
}
- (void)poll {
    if(_stopped||_error)return;
    if(!_player){
        if(!_headerProbe){if(_input.engine&&!_headerReadPending&&_header.length<2*1024*1024){_headerReadPending=YES;NSUInteger offset=_header.length;__weak RWLegacyPlayer *weak=self;
                [_input.engine perform:^(TorrentEngine *engine){[engine prioritizeOffset:offset length:256*1024];NSData *bytes=[engine readVerifiedBytesAt:offset length:MIN((NSUInteger)256*1024,2*1024*1024-offset)];
                    dispatch_async(dispatch_get_main_queue(),^{RWLegacyPlayer *strong=weak;if(!strong||strong->_stopped)return;strong->_headerReadPending=NO;if(bytes.length&&!strong->_player){[strong->_header appendData:bytes];[strong poll];}});}];}
            _headerProbe=[RWMKVProbe media:_header];if(!_headerProbe){if(NSProcessInfo.processInfo.systemUptime-_began>15||_header.length>=2*1024*1024)_error=@"The video header could not be verified.";return;}}
        NSMutableDictionary *m=[[RWMKVProbe selectAudioInMedia:_headerProbe preference:self.audioPreference]mutableCopy];_probe=m;
        NSDictionary *assessment=[RWSourcePolicy mediaAssessment:m quality:_quality];if(![assessment[@"status"]isEqual:@"compatible"]){_mediaRejectionAssessment=assessment;_error=assessment[@"reason"];return;}
        // Do not decode an arbitrary first/default track while runtime IDs are
        // unresolved. Explicit set_track below overrides this no-fallback policy.
        libvlc_media_add_option(_media,":audio-language=none");_audioStarted=NSProcessInfo.processInfo.systemUptime;
        _player=libvlc_media_player_new_from_media(_media);if(!_player){_error=@"The MKV player could not open this video.";return;}
        // VLC's iOS output otherwise adds its DVD-menu tap recognizer to the
        // drawable's superview, competing with Rewind's show-controls gesture.
        // Set this before play: the output reads mouse-events when it is built.
        libvlc_video_set_mouse_input(_player,0);
        _surface.userInteractionEnabled=NO;
        libvlc_media_player_set_nsobject(_player,(__bridge void *)_surface);libvlc_audio_set_volume(_player,100);
        _subtitleEvents=[RWLegacySubtitleEvents new];__weak RWLegacyPlayer *weak=self;
        _subtitleEvents.selected=^(int identifier,double at){[weak recordSubtitleEvent:@"decoder-selected" track:identifier at:at];[weak selectedSubtitleDidChange:identifier];};
        _subtitleEventsAttached=libvlc_event_attach(libvlc_media_player_event_manager(_player),libvlc_MediaPlayerESSelected,RWSubtitleSelected,(__bridge void *)_subtitleEvents)==0;
        _captionClock=[RWCaptionClock new];[_captionClock setRequestedPlaying:_wantPlay];_captionClockAttached=RWAttachCaptionClock(_player,_captionClock);
        [_startupTrace event:@"play_requested" at:NSProcessInfo.processInfo.systemUptime values:@{}];
        libvlc_media_player_play(_player);_stereoConfigured=libvlc_audio_set_channel(_player,libvlc_AudioChannel_Stereo)==0;
        libvlc_video_set_spu(_player,-1);_header=nil;
        if(!_wantPlay)libvlc_media_player_set_pause(_player,1);
    }
    [self pollAudio];
    if(!_stereoConfigured)_stereoConfigured=libvlc_audio_set_channel(_player,libvlc_AudioChannel_Stereo)==0;
    if(libvlc_media_player_get_state(_player)==libvlc_Error)_error=@"The MKV decoder could not play this source.";
}
- (double)position{return _player?MAX(0,libvlc_media_player_get_time(_player))/1000.:0;}
- (BOOL)captionBuffering {return !_stopped&&_captionClock.buffering;}
- (double)subtitlePosition {
    double reported=self.position;
    BOOL eligible=_captionClockAttached&&!_stopped&&_wantPlay&&_ready&&_player&&libvlc_media_player_get_state(_player)==libvlc_Playing&&fabs(libvlc_media_player_get_rate(_player)-1)<.001;
    return _captionClock?[_captionClock positionForReported:reported uptime:NSProcessInfo.processInfo.systemUptime eligible:eligible]:reported;
}
- (double)duration{return _player?libvlc_media_player_get_length(_player)/1000.:0;}
- (float)rate{return _player&&libvlc_media_player_is_playing(_player)?1:0;}
- (BOOL)seekable{return _player&&libvlc_media_player_is_seekable(_player);}
- (BOOL)ended{return _player&&libvlc_media_player_get_state(_player)==libvlc_Ended;}
- (BOOL)frameVisible {libvlc_media_stats_t s={};return _ready&&libvlc_media_get_stats(_media,&s)&&s.i_displayed_pictures>0;}
- (void)play{if(!_wantPlay)[_captionClock setRequestedPlaying:YES];_wantPlay=YES;if(_player)libvlc_media_player_set_pause(_player,0);}
- (void)pause{_wantPlay=NO;[_captionClock setRequestedPlaying:NO];if(_player)libvlc_media_player_set_pause(_player,1);}
- (void)seek:(double)seconds{if(_player&&libvlc_media_player_is_seekable(_player)){[_captionClock invalidate];libvlc_media_player_set_time(_player,(int64_t)(MAX(0,seconds)*1000));}}
- (NSArray *)tracks:(BOOL)audio {
    if(!_player)return @[];libvlc_track_description_t *head=audio?libvlc_audio_get_track_description(_player):libvlc_video_get_spu_description(_player);NSMutableArray *out=[NSMutableArray new];
    NSMutableDictionary *languages=[NSMutableDictionary new];libvlc_media_track_t **tracks=NULL;unsigned count=libvlc_media_tracks_get(_media,&tracks);
    for(unsigned i=0;i<MIN(count,128u);i++)if(tracks[i]->i_type==(audio?libvlc_track_audio:libvlc_track_text)&&tracks[i]->psz_language)languages[@(tracks[i]->i_id)]=@(tracks[i]->psz_language);
    if(tracks)libvlc_media_tracks_release(tracks,count);
    for(libvlc_track_description_t *t=head;t&&out.count<128;t=t->p_next)if(t->i_id>=0)[out addObject:@{@"id":@(t->i_id),@"name":t->psz_name?@(t->psz_name):@"Track",@"language":languages[@(t->i_id)]?:@""}];libvlc_track_description_list_release(head);return out;
}
- (NSArray *)audioTracks{return _audioTracks?:@[];}
- (NSDictionary *)audioSelection{return _audioSelection?:@{};}
- (int)selectedAudio{return _player?libvlc_audio_get_track(_player):-1;}
- (NSArray *)subtitleTracks {
    NSArray *names=[self tracks:NO];if(!_media||!names.count)return @[];
    libvlc_media_track_t **tracks=NULL;unsigned count=libvlc_media_tracks_get(_media,&tracks);NSMutableArray *raw=[NSMutableArray new];
    for(unsigned i=0;i<MIN(count,128u);i++){libvlc_media_track_t *t=tracks[i];if(t->i_type!=libvlc_track_text)continue;uint32_t c=t->i_codec;char bytes[]={(char)(c&255),(char)((c>>8)&255),(char)((c>>16)&255),(char)((c>>24)&255)};NSString *codec=[[NSString alloc]initWithBytes:bytes length:4 encoding:NSASCIIStringEncoding]?:@"";
        [raw addObject:@{@"id":@(t->i_id),@"codec":codec,@"language":t->psz_language?@(t->psz_language):@"",@"name":t->psz_description?@(t->psz_description):@""}];}
    if(tracks)libvlc_media_tracks_release(tracks,count);NSArray *mapped=[RWSubtitlePolicy mapMKV:self.probe[@"subtitleTracks"] runtime:raw];NSMutableArray *out=[NSMutableArray new];
    for(NSDictionary *name in names){NSMutableDictionary *entry=[name mutableCopy];for(NSDictionary *match in mapped)if([match[@"id"]isEqual:name[@"id"]]){entry[@"descriptor"]=match[@"descriptor"];entry[@"language"]=match[@"descriptor"][@"language"];entry[@"mapping"]=match[@"mapping"];if(![entry[@"language"]length])entry[@"name"]=@"Unknown language";if([match[@"descriptor"][@"forced"]boolValue])entry[@"name"]=[entry[@"name"]stringByAppendingString:@" · Forced"];if([match[@"descriptor"][@"sdh"]boolValue])entry[@"name"]=[entry[@"name"]stringByAppendingString:@" · SDH"];break;}[out addObject:entry];}return out;
}
- (BOOL)selectAudio:(int)identifier {
    if(!_player||_stopped)return NO;for(NSDictionary *track in _audioTracks)if([track[@"runtime_id"]intValue]==identifier)return [self requestAudio:track manual:YES];return NO;
}
- (BOOL)requestAudio:(NSDictionary *)track manual:(BOOL)manual {
    if(!_player||![track[@"compatible"]boolValue]||libvlc_audio_set_track(_player,[track[@"runtime_id"]intValue])!=0)return NO;
    _audioPending=track;_audioPendingManual=manual;_audioChangeStarted=NSProcessInfo.processInfo.systemUptime;[_startupTrace event:@"audio_requested" at:_audioChangeStarted values:@{@"runtime_id":track[@"runtime_id"],@"manual":@(manual)}];return YES;
}
- (void)pollAudio {
    if(!_player||_stopped)return;double now=NSProcessInfo.processInfo.systemUptime;
    if(!_audioTracks.count){
        libvlc_media_track_t **tracks=NULL;unsigned count=libvlc_media_tracks_get(_media,&tracks);NSMutableArray *raw=[NSMutableArray new];
        if(count<=128)for(unsigned i=0;i<count;i++){libvlc_media_track_t *t=tracks[i];if(t->i_type!=libvlc_track_audio||!t->audio)continue;
            char codec[4]={(char)t->i_codec,(char)(t->i_codec>>8),(char)(t->i_codec>>16),(char)(t->i_codec>>24)};
            NSString *code=[[NSString alloc]initWithBytes:codec length:4 encoding:NSASCIIStringEncoding]?:@"";
            [raw addObject:@{@"id":@(t->i_id),@"codec":code,@"channels":@(t->audio->i_channels),@"sampleRate":@(t->audio->i_rate),@"language":t->psz_language?@(t->psz_language):@"",@"name":t->psz_description?@(t->psz_description):@""}];
        }if(tracks)libvlc_media_tracks_release(tracks,count);
        _runtimeAudio=raw;_audioTracks=[RWMKVAudioMap mapHeader:_headerProbe[@"audioTracks"] runtime:raw];
    }
    if(_audioPending){
        if(self.selectedAudio==[_audioPending[@"runtime_id"]intValue]){
            NSDictionary *choice=_audioPending;BOOL manual=_audioPendingManual;_audioPending=nil;_audioPendingManual=NO;
            NSMutableDictionary *preference=[self.audioPreference mutableCopy]?:[NSMutableDictionary new];if(manual)preference[@"token"]=choice[@"token"];
            NSMutableDictionary *selection=[[RWAudioPolicy selection:_audioTracks preference:preference]mutableCopy];selection[@"track"]=choice;selection[@"confirmed"]=@YES;if(manual)selection[@"reason"]=@"manual";_audioSelection=selection;_ready=YES;[_startupTrace event:@"audio_confirmed" at:now values:@{@"runtime_id":choice[@"runtime_id"]}];
            _stereoConfigured=libvlc_audio_set_channel(_player,libvlc_AudioChannel_Stereo)==0;
            if(manual&&self.audioChoiceConfirmed)self.audioChoiceConfirmed(choice);
        }else if(now-_audioChangeStarted>3){_audioPending=nil;_audioPendingManual=NO;if(!_ready)_error=@"The selected audio track did not become ready.";else{NSMutableDictionary *s=[_audioSelection mutableCopy];s[@"message"]=@"The audio switch could not be confirmed. Try another track.";_audioSelection=s;}}
    }else if(!_ready&&_audioTracks.count){
        NSDictionary *selection=[RWAudioPolicy selection:_audioTracks preference:self.audioPreference];NSDictionary *choice=selection[@"track"];
        if(choice&&[self requestAudio:choice manual:NO])_audioSelection=selection;
    }
    if(!_ready&&!_audioPending&&now-_audioStarted>8)_error=@"This source's audio tracks could not be verified.";
}

- (int)selectedSubtitle{return _player?libvlc_video_get_spu(_player):-1;}
- (void)setSubtitleDelay:(double)seconds{if(!_player||!isfinite(seconds))return;int64_t delay=(int64_t)(MAX(-10,MIN(10,seconds))*1000000);if(libvlc_video_get_spu_delay(_player)!=delay&&libvlc_video_set_spu_delay(_player,delay)==0)[self schedulePausedSubtitleRefresh];}
#include "RWLegacySubtitleRefresh.inc"
- (BOOL)beginPresentationTrace:(NSString *)directory {
    if(!_subtitleTraceEnabled||_stopped||_wantPlay||!_player||_presentationTrace)return NO;
    _presentationTrace=RWArmPresentation(_surface,directory,NO);return _presentationTrace!=nil;
}
- (BOOL)beginFrameClockTrace {
    if(!_subtitleTraceEnabled||_stopped||_wantPlay||!_player||_presentationTrace)return NO;
    _presentationTrace=RWArmPresentation(_surface,nil,YES);if(!_presentationTrace)return NO;
    return YES;
}
- (NSDictionary *)frameClockEvidence {return _presentationTrace.frameClock?[_presentationTrace clockEvidence]:@{};}
- (void)captureSubtitleFrame:(NSString *)path done:(void(^)(BOOL))done {
    // Only the opt-in, paused diagnostic player may request a frame. One
    // snapshot at a time, five per player, fixed 640px output. Snapshot export
    // may wait for VLC's output thread, so it must never run on the UI thread.
    if(!_subtitleTraceEnabled||_stopped||_wantPlay||!_player||_subtitleCaptureBusy||_subtitleCaptureCount>=5){done(NO);return;}
    _subtitleCaptureBusy=YES;_subtitleCaptureCount++;
    libvlc_media_player_t *player=_player;libvlc_instance_t *instance=_instance;
    libvlc_media_player_retain(player);libvlc_retain(instance);NSString *file=[path copy];
    [self recordSubtitleEvent:@"decoder-snapshot-request" track:libvlc_video_get_spu(player) at:0];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0),^{
        int result=libvlc_video_take_snapshot(player,0,file.fileSystemRepresentation,640,0);
        libvlc_media_player_release(player);libvlc_release(instance);
        dispatch_async(dispatch_get_main_queue(),^{self->_subtitleCaptureBusy=NO;
            [self recordSubtitleEvent:@"decoder-snapshot-return" track:self.selectedSubtitle at:0];
            done(!self->_stopped&&result==0);
        });
    });
}
- (double)subtitleDelay{return _player?libvlc_video_get_spu_delay(_player)/1000000.:0;}
- (NSDictionary *)metrics {libvlc_media_stats_t s={};if(!_media||_stopped)return @{};libvlc_media_get_stats(_media,&s);if(_startupTrace)[_startupTrace sample:@{@"ready":@(_ready),@"position":@(self.position),@"decoded_video":@(s.i_decoded_video),@"displayed_frames":@(s.i_displayed_pictures),@"decoded_audio":@(s.i_decoded_audio),@"played_audio_buffers":@(s.i_played_abuffers)} at:NSProcessInfo.processInfo.systemUptime];return @{@"caption_clock":_captionClock.diagnostics?:@{},@"startup_font":_startupFont?:@"default",@"startup_trace":[_startupTrace snapshot]?:@{},@"presentation_trace":[_presentationTrace snapshot]?:@{},@"audio_selection":self.audioSelection,@"audio_runtime":_runtimeAudio?:@[],@"audio_mapped_count":@(_audioTracks.count),@"audio_runtime_id":@(self.selectedAudio),@"callback_input":@(!_networkInput),@"read_offset":@(_input->readOffset.load()),@"read_bytes":@(_input->totalReadBytes.load()),@"read_wait_ms":@(_input->readWaitMS.load()),@"read_timeouts":@(_input->readTimeouts.load()),@"seeks":@(_input->seeks.load()),@"stereo_configured":@(_stereoConfigured),@"subtitle_refreshes":@(_subtitleRefreshes),@"subtitle_trace":[_subtitleTrace copy]?:@[],@"decoded_video":@(s.i_decoded_video),@"displayed_frames":@(s.i_displayed_pictures),@"decoded_audio":@(s.i_decoded_audio),@"played_audio_buffers":@(s.i_played_abuffers),@"lost_frames":@(s.i_lost_pictures),@"seekable":@(_player&&libvlc_media_player_is_seekable(_player))};}
- (void)stop {
    if(_stopped)return;_stopped=YES;[_captionClock setRequestedPlaying:NO];[_startupTrace cancel];@synchronized(_presentationTrace){_presentationTrace.cancelled=YES;}[_remoteProbe cancel];_remoteProbe=nil;if(_input)_input->cancelled.store(true);_surface.hidden=YES;
    libvlc_media_player_t *player=_player;libvlc_media_t *media=_media;libvlc_instance_t *instance=_instance;RWVerifiedInput *input=_input;UIView *surface=_surface;RWLegacyStartupTrace *startupTrace=_startupTrace;
    RWLegacySubtitleEvents *events=_subtitleEvents;BOOL attached=_subtitleEventsAttached;_subtitleEvents=nil;_subtitleRefreshAwaitingSelection=NO;
    RWCaptionClock *captionClock=_captionClock;BOOL captionClockAttached=_captionClockAttached;_captionClock=nil;_captionClockAttached=NO;
    _player=NULL;_media=NULL;_instance=NULL;
    // Stop may join a worker which is waiting for a torrent piece read.
    // Retain the stream and drawable until VLC has completely released them.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
        if(instance&&startupTrace)libvlc_log_unset(instance);if(media)libvlc_media_parse_stop(media);if(player){if(captionClockAttached)RWDetachCaptionClock(player,captionClock);if(attached)libvlc_event_detach(libvlc_media_player_event_manager(player),libvlc_MediaPlayerESSelected,RWSubtitleSelected,(__bridge void *)events);libvlc_media_player_stop(player);libvlc_media_player_release(player);}if(media)libvlc_media_release(media);if(instance)libvlc_release(instance);
        dispatch_async(dispatch_get_main_queue(),^{[surface removeFromSuperview];(void)input;});
    });
}
- (void)dealloc{[self stop];}
@end
