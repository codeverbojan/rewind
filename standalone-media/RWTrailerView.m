#import "RWTrailerPolicy.h"
#import "RWPreviewDecoder.h"
#import "RWTrailerView.h"
#import "RewindUI.h"
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>
@interface RWTrailerBridge : NSObject <WKScriptMessageHandler>
@property(nonatomic,weak) RWTrailerView *owner;
@end
@interface RWTrailerView () <WKNavigationDelegate>
- (void)webEvent:(NSDictionary *)event;
@end
@implementation RWTrailerBridge
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {if([message.body isKindOfClass:NSDictionary.class])[self.owner webEvent:message.body];}
@end
@implementation RWTrailerView {
    RWPreviewDecoder *_decoder;AVPlayer *_player;AVPlayerLayer *_layer;NSTimer *_timer;NSDictionary *_source;
    RWButton *_sound,*_store;BOOL _visible,_started,_muted,_stopped,_checked;double _began,_lastTick,_visibleElapsed,_hiddenAt;
    WKWebView *_web;BOOL _webReady;NSInteger _webState;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])){self.clipsToBounds=YES;_muted=YES;__weak RWTrailerView *weak=self;
        _sound=[RWButton text:@"" action:^{[weak toggleSound];}];[_sound appearance:NO];[_sound icon:@"volume-off"];_sound.accessibilityLabel=@"Turn preview sound on";_sound.layer.cornerRadius=22;_sound.backgroundColor=[UIColor colorWithWhite:.08 alpha:.7];[self addSubview:_sound];_sound.hidden=YES;
        _store=[RWButton text:@"Apple TV" action:^{RWTrailerView *s=weak;if(s.onStore)s.onStore(RWString(s->_source[@"storeURL"]));}];[_store appearance:NO];[_store icon:@"external-link"];[self addSubview:_store];_store.hidden=YES;
    }return self;
}
- (void)emitState:(NSString *)state {if(self.onState)self.onState(state);}
- (void)layoutSubviews {[super layoutSubviews];CGFloat w=self.bounds.size.width,h=self.bounds.size.height;_layer.frame=self.bounds;_web.frame=self.bounds;_decoder.surface.frame=self.bounds;_sound.frame=CGRectMake(w-66,h-60,44,44);_store.frame=CGRectMake(20,h-60,130,44);}
- (void)showEmbeddedPage {if(!_web||_stopped||!_started)return;[UIView animateWithDuration:.25 animations:^{self->_web.alpha=1;}];if(self.onEmbeddedVisibility)self.onEmbeddedVisibility(YES);}
- (void)loadEmbedded:(NSString *)identifier {
    WKWebViewConfiguration *config=[WKWebViewConfiguration new];config.allowsInlineMediaPlayback=YES;config.mediaPlaybackRequiresUserAction=NO;config.allowsAirPlayForMediaPlayback=NO;
    RWTrailerBridge *bridge=[RWTrailerBridge new];bridge.owner=self;[config.userContentController addScriptMessageHandler:bridge name:@"rewindTrailer"];
    // Load the official embed as the main document with its required Referer.
    // Standard media events remove the local-HTML/iframe postMessage handshake.
    // The provider's player controls remain intact; media URLs are never extracted.
    NSString *observer=[NSString stringWithContentsOfFile:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Rewind/trailer-bridge.js"] encoding:NSUTF8StringEncoding error:nil];
    if(!observer.length){[self unavailable:@"Missing bundled trailer bridge"];return;}
    [config.userContentController addUserScript:[[WKUserScript alloc]initWithSource:observer injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES]];
    _web=[[WKWebView alloc]initWithFrame:CGRectZero configuration:config];_web.navigationDelegate=self;_web.opaque=NO;_web.backgroundColor=UIColor.clearColor;_web.scrollView.scrollEnabled=NO;_web.alpha=0;[self insertSubview:_web atIndex:0];
    NSString *referrer=[NSString stringWithFormat:@"https://%@/",NSBundle.mainBundle.bundleIdentifier.lowercaseString];
    NSURL *url=[NSURL URLWithString:[NSString stringWithFormat:@"https://www.youtube.com/embed/%@?playsinline=1&controls=1&autoplay=0&rel=0",identifier]];
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];[request setValue:referrer forHTTPHeaderField:@"Referer"];
    [_web loadRequest:request];[self setNeedsLayout];
    [[RewindStore shared]report:@{@"trailer_state":@"embedded_loading",@"trailer_mode":@"direct_embed",@"trailer_error":@"",@"trailer_script_errors":@[],@"trailer_resource_errors":@[],@"trailer_document_loaded":@NO,@"trailer_imdb":RWString(_source[@"imdb"]),@"trailer_youtube_id":identifier,@"trailer_lookup_seconds":_source[@"lookupSeconds"]?:@0}];
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {}
- (void)webEvent:(NSDictionary *)event {
    if(_stopped||!_web)return;NSString *kind=RWString(event[@"event"]);
    if([kind isEqual:@"ready"]){_webReady=YES;[_web evaluateJavaScript:[NSString stringWithFormat:@"window.RWTrailerCommand&&window.RWTrailerCommand(%@,%@)",_visible?@"true":@"false",_muted?@"true":@"false"] completionHandler:nil];}
    else if([kind isEqual:@"state"]){_webState=[event[@"value"]integerValue];if(_webState==1){if(!_visible){
        // A late iframe event can arrive after our first pause. Force another
        // pause even though the native visibility flag has not changed.
        [_web evaluateJavaScript:@"window.RWTrailerCommand&&window.RWTrailerCommand(false,true)" completionHandler:nil];
        [[RewindStore shared]report:@{@"trailer_state":@"embedded_paused_offscreen"}];return;
    }_started=YES;[self showEmbeddedPage];[[RewindStore shared]report:@{@"trailer_state":@"embedded_playing",@"trailer_elapsed_seconds":@(NSProcessInfo.processInfo.systemUptime-_began)}];[self emitState:@"playing"];}else if(_webState==0)[self retirePreview:@"ended"];}
    else if([kind isEqual:@"document_loaded"]){[[RewindStore shared]report:@{@"trailer_document_loaded":@YES}];}
    else if([kind isEqual:@"network_error"]){[self unavailable:@"Trailer script could not be downloaded"]; }
    else if([kind isEqual:@"blocked"]){[self unavailable:@"Provider requires user-initiated playback"];}
    else if([kind isEqual:@"script_errors"]){[[RewindStore shared]report:@{@"trailer_script_errors":event[@"value"]?:@[]}];if([RWTrailerPolicy embeddedRuntimeFailure:event[@"value"]]){[[RewindStore shared]embeddedTrailerUnsupported];[self unavailable:@"Embedded player script is incompatible with this system"];}}
    else if([kind isEqual:@"resource_errors"]){[[RewindStore shared]report:@{@"trailer_resource_errors":event[@"value"]?:@[]}];}
    else if([kind isEqual:@"compatibility"]){[[RewindStore shared]report:@{@"trailer_browser_features":event[@"value"]?:@{}}];}
    else if([kind isEqual:@"player_error_text"]||[kind isEqual:@"media_error"])[self unavailable:[NSString stringWithFormat:@"Embedded trailer %@: %@",kind,event[@"value"]?:@0]];
}
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {if(error.code!=NSURLErrorCancelled){[[RewindStore shared]report:@{@"trailer_network_error":@{@"code":@(error.code),@"domain":error.domain?:@""}}];[self unavailable:error.localizedDescription];}}
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {if(error.code!=NSURLErrorCancelled){[[RewindStore shared]report:@{@"trailer_network_error":@{@"code":@(error.code),@"domain":error.domain?:@""}}];[self unavailable:error.localizedDescription];}}
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {[self unavailable:@"Trailer web process stopped"];}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))handler {
    // Keep playback inside this player; never launch the YouTube app or browser.
    BOOL topLink=action.targetFrame.isMainFrame&&action.navigationType==WKNavigationTypeLinkActivated;
    handler(topLink||!action.targetFrame?WKNavigationActionPolicyCancel:WKNavigationActionPolicyAllow);
}
- (void)stopEmbedded {if(self.onEmbeddedVisibility)self.onEmbeddedVisibility(NO);[_web.configuration.userContentController removeScriptMessageHandlerForName:@"rewindTrailer"];_web.navigationDelegate=nil;[_web stopLoading];[_web removeFromSuperview];_web=nil;_webReady=NO;}
- (void)load:(NSDictionary *)source {
    [self stop];_source=source;_stopped=NO;_started=NO;_checked=NO;_muted=YES;_sound.hidden=YES;_store.hidden=YES;[_sound icon:@"volume-off"];_webState=-1;_hiddenAt=_visible?0:NSProcessInfo.processInfo.systemUptime;_began=NSProcessInfo.processInfo.systemUptime-[source[@"lookupSeconds"]doubleValue];NSString *url=RWString(source[@"url"]);
    if([source[@"kind"]isEqual:@"apple-hls"]){_decoder=[[RWPreviewDecoder alloc]initWithSource:source];_decoder.surface.alpha=0;[self insertSubview:_decoder.surface atIndex:0];[_decoder setVisible:_visible muted:YES];[self setNeedsLayout];_lastTick=NSProcessInfo.processInfo.systemUptime;_visibleElapsed=0;_timer=[NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(tick)userInfo:nil repeats:YES];[[RewindStore shared]report:@{@"trailer_state":@"native_loading",@"trailer_decoder":@"vlc_hls",@"trailer_imdb":RWString(source[@"imdb"]),@"trailer_lookup_seconds":source[@"lookupSeconds"]?:@0,@"trailer_width":source[@"width"]?:@0,@"trailer_height":source[@"height"]?:@0}];return;}
    if(RWString(source[@"youtubeID"]).length){_lastTick=NSProcessInfo.processInfo.systemUptime;_visibleElapsed=0;[self loadEmbedded:source[@"youtubeID"]];_timer=[NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(tick)userInfo:nil repeats:YES];return;}
    NSURL *u=[url hasPrefix:@"asset:"]?[NSURL fileURLWithPath:[[[NSBundle mainBundle]resourcePath]stringByAppendingPathComponent:[@"Rewind/" stringByAppendingString:[url substringFromIndex:6]]]]:[NSURL URLWithString:url];
    if(!u){[self unavailable:@"No compatible preview"];return;}
    _player=[AVPlayer playerWithURL:u];_player.muted=YES;_layer=[AVPlayerLayer playerLayerWithPlayer:_player];_layer.videoGravity=AVLayerVideoGravityResizeAspect;_layer.hidden=YES;[self.layer insertSublayer:_layer atIndex:0];[self setNeedsLayout];[self layoutIfNeeded];_lastTick=NSProcessInfo.processInfo.systemUptime;_visibleElapsed=0;
    _timer=[NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(tick)userInfo:nil repeats:YES];
    [[RewindStore shared]report:@{@"trailer_state":@"native_loading",@"trailer_error":@"",@"trailer_imdb":RWString(source[@"imdb"]),@"trailer_lookup_seconds":source[@"lookupSeconds"]?:@0,@"trailer_host":u.host?:@"bundle"}];
}
- (void)unavailable:(NSString *)message {
    [self stopEmbedded];
    [[RewindStore shared]report:@{@"trailer_native_status":@(_player.currentItem.status),@"trailer_native_position":@(isfinite(CMTimeGetSeconds(_player.currentTime))?CMTimeGetSeconds(_player.currentTime):0),@"trailer_native_frame":@(_layer.readyForDisplay),@"trailer_visible":@(_visible),@"trailer_native_rate":@(_player.rate)}];
    [_timer invalidate];_timer=nil;NSString *reason=_decoder.error?:_player.currentItem.error.localizedDescription?:message;if(_decoder)[[RewindStore shared]report:@{@"trailer_decoder_metrics":[_decoder metrics]}];[_decoder stop];_decoder=nil;
    [_player pause];[_player.currentItem.asset cancelLoading];[_player replaceCurrentItemWithPlayerItem:nil];_layer.player=nil;[_layer removeFromSuperlayer];_layer=nil;_player=nil;
    _sound.hidden=YES;_store.hidden=YES;_stopped=YES;
    [[RewindStore shared]trailerFailed:RWString(_source[@"imdb"]) embedded:RWString(_source[@"youtubeID"]).length>0];[[RewindStore shared]report:@{@"trailer_state":@"unavailable",@"trailer_error":reason,@"trailer_elapsed_seconds":@(NSProcessInfo.processInfo.systemUptime-_began)}];[self emitState:@"unavailable"];
}
- (void)tick {
    if(_stopped)return;double now=NSProcessInfo.processInfo.systemUptime;if(_visible)_visibleElapsed+=now-_lastTick;_lastTick=now;
    if(!_visible&&_hiddenAt>0&&now-_hiddenAt>30){[self stop];[[RewindStore shared]report:@{@"trailer_state":@"released_offscreen"}];[self emitState:@"released"];return;}
    if(_web){if(!_started&&_visibleElapsed>8)[self unavailable:@"No embedded first frame within eight visible seconds"];return;}
    if(_decoder){if(_decoder.error){[self unavailable:_decoder.error];return;}
        if(_visible&&_decoder.frameVisible&&_decoder.position>.05&&!_started){_started=YES;[UIView animateWithDuration:.25 animations:^{self->_decoder.surface.alpha=1;}];_sound.hidden=NO;_store.hidden=!RWString(_source[@"storeURL"]).length;[self setNeedsLayout];[[RewindStore shared]report:@{@"trailer_state":@"native_playing",@"trailer_decoder":@"vlc_hls",@"trailer_decoder_metrics":[_decoder metrics],@"trailer_elapsed_seconds":@(now-_began)}];[self emitState:@"playing"];}
        if(_decoder.ended){[self retirePreview:@"ended"];return;}if(!_started&&_visibleElapsed>6)[self unavailable:@"Native preview startup deadline (6 seconds)"];return;}
    if(_player.currentItem.status==AVPlayerItemStatusFailed){[self unavailable:@"Native trailer failed"];return;}
    if(_player.currentItem.status==AVPlayerItemStatusReadyToPlay){
        if(!_checked){BOOL compatible=YES;for(AVAssetTrack *t in [_player.currentItem.asset tracksWithMediaType:AVMediaTypeVideo])if(fabs(t.naturalSize.width)>1920||fabs(t.naturalSize.height)>1080||t.nominalFrameRate>31)compatible=NO;
            AVPlayerItemTrack *audio=nil;for(AVPlayerItemTrack *t in _player.currentItem.tracks)if([t.assetTrack.mediaType isEqual:AVMediaTypeAudio])for(id raw in t.assetTrack.formatDescriptions){const AudioStreamBasicDescription *a=CMAudioFormatDescriptionGetStreamBasicDescription((__bridge CMAudioFormatDescriptionRef)raw);if(a&&a->mFormatID==kAudioFormatMPEG4AAC&&a->mChannelsPerFrame<=2&&a->mSampleRate<=48000&&!audio)audio=t;}
            if(!compatible||!audio){[self unavailable:@"Unsupported trailer format"];return;}for(AVPlayerItemTrack *t in _player.currentItem.tracks)if([t.assetTrack.mediaType isEqual:AVMediaTypeAudio])t.enabled=t==audio;_checked=YES;}
        double p=CMTimeGetSeconds(_player.currentTime),d=CMTimeGetSeconds(_player.currentItem.duration);
        if(_visible&&_player.rate==0&&(!isfinite(d)||p<d-.3))[_player play];
        if(_visible&&_layer.readyForDisplay&&p>.05&&!_started){_started=YES;_layer.hidden=NO;_layer.opacity=1;CABasicAnimation *fade=[CABasicAnimation animationWithKeyPath:@"opacity"];fade.fromValue=@0;fade.toValue=@1;fade.duration=.25;[_layer addAnimation:fade forKey:@"firstFrame"];_sound.hidden=NO;_store.hidden=!RWString(_source[@"storeURL"]).length;[self setNeedsLayout];[[RewindStore shared]report:@{@"trailer_state":@"native_playing",@"trailer_elapsed_seconds":@(NSProcessInfo.processInfo.systemUptime-_began)}];[self emitState:@"playing"];}
        if(d>0&&p>=d-.3)[self retirePreview:@"ended"];
    }
    if(!_stopped&&_visibleElapsed>6&&!_started)[self unavailable:@"Trailer startup deadline (6 seconds)"];
}
- (void)retirePreview:(NSString *)reason {[self stop];_sound.hidden=YES;_store.hidden=YES;[[RewindStore shared]report:@{@"trailer_state":reason}];[self emitState:reason];}
- (void)setVisible:(BOOL)visible {BOOL changed=visible!=_visible;_visible=visible;if(changed)_hiddenAt=visible?0:NSProcessInfo.processInfo.systemUptime;if(_stopped)return;if(_decoder){if(changed)[_decoder setVisible:visible muted:_muted];return;}if(_web&&_webReady){if(changed)[_web evaluateJavaScript:[NSString stringWithFormat:@"window.RWTrailerCommand&&window.RWTrailerCommand(%@,%@)",visible?@"true":@"false",_muted?@"true":@"false"] completionHandler:nil];return;}if(!visible)[_player pause];else [_player play];}
- (void)toggleSound {_muted=!_muted;if(!_muted){[[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayback error:nil];[[AVAudioSession sharedInstance]setActive:YES error:nil];}_player.muted=_muted;[_decoder setVisible:_visible muted:_muted];if(_webReady)[_web evaluateJavaScript:[NSString stringWithFormat:@"window.RWTrailerCommand&&window.RWTrailerCommand(%@,%@)",_visible?@"true":@"false",_muted?@"true":@"false"] completionHandler:nil];[_sound icon:_muted?@"volume-off":@"volume-on"];_sound.accessibilityLabel=_muted?@"Turn preview sound on":@"Mute preview";}
- (BOOL)embeddedVisible {return _web&&_web.alpha>0&&!_stopped;}
- (BOOL)usingVideoNetwork {return !_stopped&&_visible&&(_web||_player||_decoder);}
- (BOOL)canPlay {return !_stopped;}
- (NSDictionary *)diagnostics {
    double position=_decoder?_decoder.position:_player?CMTimeGetSeconds(_player.currentTime):0;
    BOOL frame=_decoder?_decoder.frameVisible:(_layer.readyForDisplay&&!_layer.hidden);
    return @{@"imdb":RWString(_source[@"imdb"]),@"decoder":_decoder?@"vlc_hls":_player?@"native_file":_web?@"web":@"none",@"visible":@(_visible&&self.window!=nil),@"started":@(_started),@"stopped":@(_stopped),@"native_frame_visible":@(frame),@"position":@(isfinite(position)?position:0),@"muted":@(_muted),@"appleID":RWString(_source[@"appleID"]),@"movieID":RWString(_source[@"movieID"]),@"previewID":RWString(_source[@"previewID"]),@"lookup_seconds":_source[@"lookupSeconds"]?:@0};
}
- (void)playWithSound {if(_stopped)return;if(_muted)[self toggleSound];if(_decoder){[_decoder setVisible:YES muted:NO];return;}if(_web){if(_webReady)[_web evaluateJavaScript:@"window.RWTrailerCommand&&window.RWTrailerCommand(true,false)" completionHandler:nil];return;}double p=CMTimeGetSeconds(_player.currentTime),d=CMTimeGetSeconds(_player.currentItem.duration);if(d>0&&p>=d-.5)[_player seekToTime:kCMTimeZero];[_player play];}
- (void)stop {_stopped=YES;[_decoder stop];_decoder=nil;[_timer invalidate];_timer=nil;[self stopEmbedded];[_player pause];[_player.currentItem.asset cancelLoading];[_player replaceCurrentItemWithPlayerItem:nil];_layer.player=nil;[_layer removeFromSuperlayer];_layer=nil;_player=nil;}
- (void)dealloc {[self stop];}
@end
