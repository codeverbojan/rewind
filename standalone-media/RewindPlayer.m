#import "RWPlaybackLifetimeProbe.h"
#import "RWArtworkPolicy.h"
#import "RewindPlayer.h"
#import "RewindUI.h"
#import "TorrentEngine.h"
#import "TorrentLoader.h"
#import "RWLegacyPlayer.h"
#import "RWSourcePolicy.h"
#import "RWSourceWork.h"
#import "RWAudioPolicy.h"
#import "RWPlaybackMetrics.h"
#include "RWPlayerState.h"
#include "RWNativeBufferRecovery.h"
#import "RWSubtitles.h"
#import "RWSubtitleLabel.h"
#import "RWSubtitleTimingProbe.h"
#import "RWSubtitleTicker.h"
#import "RWSubtitleLoadProbe.h"
#import "RWSubtitlePolicy.h"
#import "RWSubtitleDownload.h"
#import "RWAtomicWriter.h"
#import "RWDeviceExercise.h"
#import <mach/mach.h>
#import <AVFoundation/AVFoundation.h>

@interface RewindPlayer () <UIGestureRecognizerDelegate>
@property(nonatomic,strong) NSDictionary *meta;
@property(nonatomic,strong) NSDictionary *source;
@property(nonatomic,strong) NSString *videoID;
@property(nonatomic,strong) AVPlayer *player;
@property(nonatomic,strong) RWLegacyPlayer *legacy;
@property(nonatomic,strong) NSMutableDictionary *exerciseSubtitleFrames;
@property(nonatomic,strong) AVPlayerLayer *video;
@property(nonatomic,strong) TorrentEngine *engine;
@property(nonatomic,strong) TorrentLoader *loader;
@property(nonatomic,strong) id observer;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) UIView *controls;
@property(nonatomic,strong) CAGradientLayer *topShade;
@property(nonatomic,strong) CAGradientLayer *bottomShade;
@property(nonatomic,strong) UILabel *titleLabel;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UILabel *timeLabel;
@property(nonatomic,strong) RWSubtitleLabel *subtitleLabel;
@property(nonatomic,strong) RWSubtitleTimingProbe *exerciseSubtitleTiming;
@property(nonatomic,strong) RWSubtitleTicker *subtitleTicker;
@property(nonatomic,strong) NSOperationQueue *exerciseSubtitleQueue;
@property(nonatomic,strong) NSBlockOperation *exerciseSubtitleLoadTask;
@property(nonatomic,strong) NSDictionary *exerciseSubtitleLoad;
@property(nonatomic,strong) NSMutableDictionary *exerciseRealCaptions;
@property(nonatomic,assign) UIInterfaceOrientation exerciseLayoutOrientation;
@property(nonatomic,strong) UISlider *scrubber;
@property(nonatomic,strong) UIProgressView *bufferedTrack;
@property(nonatomic,strong) RWButton *audioButton;
@property(nonatomic,strong) UIActivityIndicatorView *spinner;
@property(nonatomic,strong) RWButton *playButton;
@property(nonatomic,strong) RWButton *closeButton;
@property(nonatomic,strong) RWButton *backward;
@property(nonatomic,strong) RWButton *forward;
@property(nonatomic,strong) RWButton *restart;
@property(nonatomic,strong) RWButton *skipIntro,*nextEpisodeButton;
@property(nonatomic,assign) BOOL nextEpisodeRequested,playbackEnded;
@property(nonatomic,strong) RWButton *captions;
@property(nonatomic,strong) RWButton *storeButton;
@property(nonatomic,strong) NSArray *cues;
@property(nonatomic,strong) NSArray *automaticSegments;
@property(nonatomic,strong) NSDictionary *activeSegment;
@property(nonatomic,assign) double resumePosition;
@property(nonatomic,assign) double lastSaved;
@property(nonatomic,assign) double lastInteraction;
@property(nonatomic,assign) BOOL observed;
@property(nonatomic,assign) BOOL closing;
@property(nonatomic,assign) BOOL seeking;
@property(nonatomic,assign) BOOL resumed;
@property(nonatomic,assign) BOOL transient;
@property(nonatomic,copy) NSString *exercisePersistenceProfile;
@property(nonatomic,copy) NSString *exerciseLegacyFont;
@property(nonatomic,strong) NSArray *candidates;
@property(nonatomic,strong) NSArray *ranked;
@property(nonatomic,strong) NSMutableArray *attempts;
@property(nonatomic,strong) RWButton *qualityButton;
@property(nonatomic,assign) NSInteger quality;
@property(nonatomic,assign) NSUInteger candidateIndex;
@property(nonatomic,assign) NSUInteger playbackGeneration,nativeSeekGeneration;
@property(nonatomic,assign) BOOL nativeSeekPending,nativeSeekFinished;
@property(nonatomic,assign) double nativeSeekStarted,nativeSeekCompleted,nativeSeekTarget;
@property(nonatomic,assign) double attemptStarted;
@property(nonatomic,assign) double lastProgress;
@property(nonatomic,assign) double lastPosition;
@property(nonatomic,assign) BOOL mediaVerified;
@property(nonatomic,assign) BOOL hasStartedPlayback;
@property(nonatomic,assign) BOOL verifyingMedia;
@property(nonatomic,assign) BOOL wantsPlay;
@property(nonatomic,assign) BOOL exhausted;
@property(nonatomic,assign) BOOL resumeAfterForeground;
@property(nonatomic,strong) RWPlaybackMetrics *metrics;
@property(nonatomic,strong) NSMutableSet *deadSwarms;
@property(nonatomic,strong) NSDictionary *lastTorrentSnapshot;
@property(nonatomic,assign) BOOL discovering;
@property(nonatomic,assign) BOOL refreshing;
@property(nonatomic,assign) BOOL sourceLookupPending, automaticSources;
@property(nonatomic,assign) NSUInteger sourceLookupGeneration;
@property(nonatomic,assign) double startupBegan;
@property(nonatomic,assign) double lastDownloadProgress;
@property(nonatomic,assign) int64_t lastPayload;
@property(nonatomic,strong) UIView *loadingPanel;
@property(nonatomic,strong) UILabel *loadingTitle;
@property(nonatomic,strong) UILabel *loadingDetail;
@property(nonatomic,strong) UIProgressView *loadingProgress;
@property(nonatomic,strong) RWButton *retryButton;
@property(nonatomic,strong) NSMutableSet *triedSources;
@property(nonatomic,strong) UIImageView *loadingArt;
@property(nonatomic,strong) UIView *loadingShade;
@property(nonatomic,strong) CAGradientLayer *loadingGradient;
@property(nonatomic,strong) UILabel *loadingName;
@property(nonatomic,strong) RWButton *keepButton;
@property(nonatomic,assign) BOOL recordedGoodSource;
@property(nonatomic,strong) NSString *subtitleName;
@property(nonatomic,strong) RWSubtitleDownload *subtitleTask;
@property(nonatomic,strong) NSBlockOperation *subtitleParseTask;
@property(nonatomic,strong) NSData *subtitleData;
@property(nonatomic,strong) NSString *subtitleFormat;
@property(nonatomic,strong) NSDictionary *subtitleDecode;
@property(nonatomic,strong) NSString *subtitleProfileID,*subtitleContentDigest,*subtitleEncodingChoice;
@property(nonatomic,strong) NSMutableDictionary *subtitleProfileSnapshot;
@property(nonatomic,strong) NSDictionary *subtitleDescriptor,*subtitleAddedFile;
@property(nonatomic,assign) BOOL subtitleSelectionManual;
@property(nonatomic,strong) NSDictionary *subtitlePendingChoice;
@property(nonatomic,assign) double subtitleChoiceStarted;
@property(nonatomic,assign) NSUInteger subtitleGeneration;
@property(nonatomic,strong) NSDictionary *subtitleTransfer;
@property(nonatomic,assign) BOOL subtitlePending;
@property(nonatomic,assign) BOOL automaticSubtitlesTried;
@property(nonatomic,assign) BOOL subtitleAutomatic;
@property(nonatomic,assign) double subtitleStarted;
@property(nonatomic,assign) double subtitleDelay;
@property(nonatomic,strong) NSMutableDictionary *transientSubtitlePreferences,*exerciseSubtitleActions;
@property(nonatomic,assign) BOOL deviceExerciseEnabled,exerciseRecovery;
@property(nonatomic,copy) NSString *exercisePersistenceRun;
@property(nonatomic,assign) double lastMetricFile;
@property(nonatomic,assign) NSUInteger memoryWarnings;
@property(nonatomic,assign) BOOL enginePollPending;
@property(nonatomic,strong) NSArray *torrentSubtitleFiles;
@property(nonatomic,strong) AVMediaSelectionGroup *captionGroup;
@property(nonatomic,assign) BOOL mediaSelectionLoaded;
@property(nonatomic,strong) NSArray *audioChoices;
@property(nonatomic,copy) NSString *audioProfileID;
@property(nonatomic,strong) NSMutableDictionary *audioProfileSnapshot;
@property(nonatomic,strong) NSDictionary *audioSelection;
@property(nonatomic,strong) NSMutableDictionary *exerciseAudioActions;
@property(nonatomic,assign) double lastUITick, maxUITickGap, lastEnginePoll;
@property(nonatomic,assign) NSUInteger controlsTapCount, controlTouchCount;
@property(nonatomic,copy) NSString *lastControlTouch;
@end

@implementation RewindPlayer { RWPlaybackMotion _motion; RWNativeBufferRecovery _nativeBufferRecovery; }
#include "RewindAudio.inc"
#include "RewindPlayback.inc"
#include "RewindLegacy.inc"
- (instancetype)initWithMeta:(NSDictionary *)meta videoID:(NSString *)videoID source:(NSDictionary *)source resume:(double)resume{
    if((self=[super init])){self.playRequestedAtUptime=NSProcessInfo.processInfo.systemUptime;self.meta=meta;source=[RWSourcePolicy sources:@[source] withMeta:meta videoID:videoID].firstObject;self.source=source;self.candidates=@[source];self.ranked=@[source];self.attempts=[NSMutableArray new];self.deadSwarms=[NSMutableSet new];self.triedSources=[NSMutableSet new];self.videoID=videoID;self.resumePosition=resume;self.modalPresentationStyle=UIModalPresentationFullScreen;self.transient=[videoID hasSuffix:@":preview"];[self captureAudioPreferences];[self captureSubtitlePreferences];}return self;
}
- (BOOL)prefersStatusBarHidden{return YES;}
- (void)viewDidLoad{
    [super viewDidLoad];self.metrics=[[RWPlaybackMetrics alloc]initAtUptime:self.playRequestedAtUptime>0?self.playRequestedAtUptime:NSProcessInfo.processInfo.systemUptime];self.view.backgroundColor=[UIColor blackColor];self.lastInteraction=[NSDate date].timeIntervalSince1970;
    [self.metrics setContext:@{@"video_id":self.videoID?:@"",@"type":self.meta[@"type"]?:@"",@"profile_id":[RewindStore shared].state[@"activeProfile"]?:@"",@"requested_quality":@(self.quality),@"requested_position_seconds":@(self.resumePosition),@"build":[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]?:@"development"}];
    [self.metrics setExpectedStartPosition:self.resumePosition];
    [[RewindStore shared]report:@{@"playback_session_id":self.metrics.sessionID,@"player_ready":@NO,@"playback_exhausted":@NO,@"playback_failure_reason":@"",@"discovery":@{},@"torrent":@{},@"selected_source":@{},@"playback_attempts":@[],@"source_query":self.videoID?:@"",@"source_candidates":@0,@"source_eligible":@0,@"source_providers":@{},@"source_error":@""}];
    self.video=[AVPlayerLayer playerLayerWithPlayer:nil];self.video.videoGravity=AVLayerVideoGravityResizeAspect;[self.view.layer addSublayer:self.video];
    self.loadingArt=[[UIImageView alloc]initWithFrame:self.view.bounds];self.loadingArt.contentMode=UIViewContentModeScaleAspectFill;self.loadingArt.clipsToBounds=YES;[self.view addSubview:self.loadingArt];
    [[RewindStore shared]artwork:[RWArtworkPolicy URLsForMeta:self.meta landscape:YES] role:@"hero" identity:RWID(self.meta) into:self.loadingArt completion:nil];
    self.loadingShade=[UIView new];self.loadingShade.backgroundColor=UIColor.clearColor;self.loadingGradient=[CAGradientLayer layer];self.loadingGradient.colors=@[(id)[UIColor colorWithWhite:0 alpha:.10].CGColor,(id)[UIColor colorWithWhite:0 alpha:.5].CGColor,(id)[UIColor colorWithWhite:0 alpha:.96].CGColor];self.loadingGradient.locations=@[@0,@.38,@1];[self.loadingShade.layer addSublayer:self.loadingGradient];[self.view addSubview:self.loadingShade];
    self.controls=[UIView new];self.controls.backgroundColor=[UIColor colorWithWhite:0 alpha:0.12];[self.view addSubview:self.controls];
    self.topShade=[CAGradientLayer layer];self.topShade.colors=@[(id)[UIColor colorWithWhite:0 alpha:.8].CGColor,(id)[UIColor clearColor].CGColor];[self.controls.layer addSublayer:self.topShade];
    self.bottomShade=[CAGradientLayer layer];self.bottomShade.colors=@[(id)[UIColor clearColor].CGColor,(id)[UIColor colorWithWhite:0 alpha:.9].CGColor];[self.controls.layer addSublayer:self.bottomShade];
    __weak RewindPlayer *weak=self;
    self.closeButton=[RWButton text:@"" action:^{[weak close];}];[self.closeButton icon:@"arrow-left"];self.closeButton.accessibilityLabel=@"Close player";[self.controls addSubview:self.closeButton];
    self.titleLabel=RWLabel(RWString(self.meta[@"name"]),21,UIFontWeightSemibold,[UIColor whiteColor]);[self.controls addSubview:self.titleLabel];
    self.statusLabel=RWLabel(@"Preparing your film…",12,UIFontWeightMedium,RWColor(0xb8bec8));self.statusLabel.numberOfLines=2;[self.controls addSubview:self.statusLabel];
    self.playButton=[RWButton text:@"" action:^{[weak togglePlay];}];[self.playButton appearance:YES];self.playButton.layer.cornerRadius=42;[self.playButton setImage:RWIcon(@"pause",30,RWColor(0x15181d)) forState:UIControlStateNormal];self.playButton.accessibilityLabel=@"Pause";[self.controls addSubview:self.playButton];
    self.backward=[RWButton text:@"" action:^{[weak jump:-15];}];self.backward.accessibilityLabel=@"Back 15 seconds";[self.backward setImage:RWIcon(@"rotate-ccw",40,[UIColor whiteColor]) forState:UIControlStateNormal];[self.controls addSubview:self.backward];
    self.forward=[RWButton text:@"" action:^{[weak jump:15];}];self.forward.accessibilityLabel=@"Forward 15 seconds";[self.forward setImage:RWIcon(@"rotate-cw",40,[UIColor whiteColor]) forState:UIControlStateNormal];[self.controls addSubview:self.forward];
    for(RWButton *button in @[self.backward,self.forward]){UILabel *seconds=RWLabel(@"15",11,UIFontWeightBold,[UIColor whiteColor]);seconds.textAlignment=NSTextAlignmentCenter;seconds.frame=CGRectMake(18,26,28,20);[button addSubview:seconds];}
    self.restart=[RWButton text:@"Start over" action:^{[weak seek:0];}];[self.restart icon:@"rotate-ccw"];[self.controls addSubview:self.restart];
    self.qualityButton=[RWButton text:@"Quality" action:^{[weak choosePlaybackQuality];}];[self.controls addSubview:self.qualityButton];
    self.keepButton=[RWButton text:@"Keep download" action:^{[weak toggleKeep];}];[self.keepButton icon:@"download"];[self.controls addSubview:self.keepButton];
    self.captions=[RWButton text:@"Subtitles" action:^{[weak chooseSubtitles];}];[self.captions icon:@"captions"];[self.controls addSubview:self.captions];
    self.skipIntro=[RWButton text:@"Skip intro" action:^{[weak seek:[weak.activeSegment[@"end"]doubleValue]];}];[self.skipIntro appearance:YES];[self.skipIntro icon:@"chevron-right"];self.skipIntro.hidden=YES;[self.view addSubview:self.skipIntro];
    self.nextEpisodeButton=[RWButton text:self.nextEpisodeLabel?:@"Next episode" action:^{[weak nextEpisode];}];[self.nextEpisodeButton appearance:YES];[self.nextEpisodeButton icon:@"chevron-right"];self.nextEpisodeButton.accessibilityLabel=@"Next episode";self.nextEpisodeButton.hidden=YES;[self.controls addSubview:self.nextEpisodeButton];
    self.audioButton=[RWButton text:@"Audio" action:^{[weak chooseAudio];}];[self.controls addSubview:self.audioButton];
    self.bufferedTrack=[[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleDefault];self.bufferedTrack.trackTintColor=[UIColor colorWithWhite:1 alpha:.18];self.bufferedTrack.progressTintColor=[UIColor colorWithWhite:1 alpha:.5];[self.controls addSubview:self.bufferedTrack];
    self.scrubber=[UISlider new];self.scrubber.minimumTrackTintColor=RWColor(0xff6847);self.scrubber.maximumTrackTintColor=[UIColor clearColor];self.scrubber.accessibilityLabel=@"Playback position";[self.scrubber addTarget:self action:@selector(scrubBegin)forControlEvents:UIControlEventTouchDown];[self.scrubber addTarget:self action:@selector(scrubEnd)forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];[self.controls addSubview:self.scrubber];
    self.timeLabel=RWLabel(@"0:00 / —",12,UIFontWeightMedium,RWColor(0xd4d9df));[self.controls addSubview:self.timeLabel];
    self.subtitleLabel=[[RWSubtitleLabel alloc]initWithFrame:CGRectZero];self.subtitleDelay=0;NSInteger size=[[self subtitlePreferences][@"subtitleSize"]integerValue];self.subtitleLabel.font=[UIFont systemFontOfSize:size>=20&&size<=28?size:24 weight:UIFontWeightSemibold];[self.view addSubview:self.subtitleLabel];
    self.spinner=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];[self.view addSubview:self.spinner];self.spinner.hidesWhenStopped=YES;[self.spinner startAnimating];
    self.loadingPanel=[UIView new];self.loadingPanel.backgroundColor=UIColor.clearColor;[self.view addSubview:self.loadingPanel];
    self.loadingName=RWLabel(RWString(self.meta[@"name"]),36,UIFontWeightBold,RWColor(0xf8f5ef));self.loadingName.numberOfLines=2;[self.loadingPanel addSubview:self.loadingName];
    self.loadingTitle=RWLabel(@"Finding a fast source",17,UIFontWeightMedium,RWColor(0xf5f2eb));self.loadingTitle.textAlignment=NSTextAlignmentLeft;[self.loadingPanel addSubview:self.loadingTitle];
    self.loadingDetail=RWLabel(@"Checking live connections…",15,UIFontWeightRegular,RWColor(0xa5acb6));self.loadingDetail.numberOfLines=3;self.loadingDetail.textAlignment=NSTextAlignmentLeft;[self.loadingPanel addSubview:self.loadingDetail];
    self.loadingProgress=[[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleDefault];self.loadingProgress.progressTintColor=RWColor(0xff6847);self.loadingProgress.trackTintColor=RWColor(0x303640);self.loadingProgress.hidden=YES;[self.loadingPanel addSubview:self.loadingProgress];
    self.retryButton=[RWButton text:@"Try again" action:^{[weak retrySources];}];[self.retryButton appearance:YES];self.retryButton.hidden=YES;[self.loadingPanel addSubview:self.retryButton];
    [self.view bringSubviewToFront:self.spinner];
    for(UIControl *control in @[self.closeButton,self.playButton,self.backward,self.forward,self.restart,self.qualityButton,self.keepButton,self.captions,self.audioButton,self.scrubber,self.skipIntro,self.nextEpisodeButton,self.retryButton])
        [control addTarget:self action:@selector(controlTouched:) forControlEvents:UIControlEventTouchDown];
    if(self.reviewOnly){[self updatePlayback];return;}
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(sourceResultsUpdated:)name:@"RWSourceResultsUpdated" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(sourceLookupMeasured:)name:@"RWSourceLookupMeasured" object:nil];

    UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(toggleControls:)];tap.cancelsTouchesInView=NO;tap.delegate=self;[self.view addGestureRecognizer:tap];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(background)name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(foreground)name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(memoryWarningReceived)name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    NSArray *latest=[[RewindStore shared]cachedStreams:self.meta videoID:self.videoID];
    if(latest.count){self.candidates=[self.candidates arrayByAddingObjectsFromArray:latest];self.candidates=[RWSourcePolicy sources:[[RewindStore shared]withSourceExperience:self.candidates] withMeta:self.meta videoID:self.videoID];self.ranked=[RWSourcePolicy rank:self.candidates quality:self.quality freeBytes:0];}
    if(self.ranked.count)[self.metrics markStage:@"sources_cached" uptime:NSProcessInfo.processInfo.systemUptime];
    self.refreshing=YES;
    if(self.preparedEngine)[self adoptPreparedEngine];
    else [TorrentEngine afterCleanupWithPinned:[NSSet setWithArray:[RewindStore shared].state[@"keptDownloads"]?:@[]] ready:^{if(weak.closing)return;[weak.metrics markStage:@"cleanup_ready" uptime:NSProcessInfo.processInfo.systemUptime];weak.refreshing=NO;if(weak.ranked.count){[weak startNextSource];if(weak.automaticSources)[weak lookupSources:NO];}else [weak retrySources];}];
    self.timer=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick)userInfo:nil repeats:YES];
    [UIApplication sharedApplication].idleTimerDisabled=YES;
}
- (void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];CGFloat w=self.view.bounds.size.width,h=self.view.bounds.size.height;self.video.frame=self.view.bounds;self.legacy.surface.frame=self.view.bounds;self.loadingArt.frame=self.view.bounds;self.loadingShade.frame=self.view.bounds;self.loadingGradient.frame=self.view.bounds;self.controls.frame=self.view.bounds;
    self.topShade.frame=CGRectMake(0,0,w,180);self.bottomShade.frame=CGRectMake(0,h-210,w,210);
    self.keepButton.frame=CGRectMake(w-190,28,164,48);self.closeButton.frame=CGRectMake(24,24,48,48);self.titleLabel.frame=CGRectMake(92,28,w-310,34);
    self.statusLabel.frame=CGRectMake(93,68,w-160,40);self.playButton.frame=CGRectMake(w/2-42,h/2-42,84,84);
    self.backward.frame=CGRectMake(w/2-168,h/2-32,64,64);self.forward.frame=CGRectMake(w/2+104,h/2-32,64,64);
    self.scrubber.frame=CGRectMake(32,h-123,w-64,44);self.timeLabel.frame=CGRectMake(36,h-69,178,28);self.audioButton.frame=CGRectMake(222,h-79,78,48);self.bufferedTrack.frame=CGRectMake(34,h-102,w-68,2);
    self.restart.frame=CGRectMake(w-332,h-79,140,48);self.captions.frame=CGRectMake(w-176,h-79,144,48);
    self.skipIntro.frame=CGRectMake(w-190,h-190,158,48);self.nextEpisodeButton.frame=CGRectMake(w-250,h-190,218,48);[self layoutSubtitle];
    CGFloat pw=w-96;self.loadingPanel.frame=CGRectMake(48,h-285,pw,245);
    self.loadingName.frame=CGRectMake(0,0,pw-30,96);self.loadingTitle.frame=CGRectMake(0,112,pw-48,28);self.loadingDetail.frame=CGRectMake(0,149,pw-48,44);self.loadingProgress.frame=CGRectMake(46,216,MIN(360,pw-60),3);self.retryButton.frame=CGRectMake(0,201,160,44);
    self.spinner.center=CGPointMake(self.loadingPanel.hidden?w/2:62,self.loadingPanel.hidden?h/2:h-67);self.storeButton.frame=CGRectMake(230,h-145,144,48);self.qualityButton.frame=CGRectMake(w-462,h-79,118,48);
}
- (void)layoutSubtitle {
    if(!self.isViewLoaded||!self.subtitleLabel)return;
    CGRect picture=self.video.videoRect;
    if(self.legacy){CGFloat width=[self.legacy.probe[@"width"]doubleValue],height=[self.legacy.probe[@"height"]doubleValue];picture=width>0&&height>0?AVMakeRectWithAspectRatioInsideRect(CGSizeMake(width,height),self.view.bounds):self.view.bounds;}
    [self.subtitleLabel placeIn:self.view.bounds picture:picture controls:self.controls.alpha>.01];
}
- (void)prepareItem:(AVPlayerItem *)item{
    if(self.player)return;
    [self.metrics markStage:@"player_preparing" uptime:NSProcessInfo.processInfo.systemUptime];
    self.player=[AVPlayer playerWithPlayerItem:item];self.player.appliesMediaSelectionCriteriaAutomatically=NO;self.player.muted=NO;self.player.volume=1;self.video.player=self.player;
    NSError *audioError=nil;[[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayback error:&audioError];[[AVAudioSession sharedInstance]setActive:YES error:&audioError];
    NSInteger output=MIN(2,[AVAudioSession sharedInstance].maximumOutputNumberOfChannels);if(output>0)[[AVAudioSession sharedInstance]setPreferredOutputNumberOfChannels:output error:nil];
    self.observed=YES;[item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew context:NULL];
    [self preloadMediaSelection:item];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(ended)name:AVPlayerItemDidPlayToEndTimeNotification object:item];
    __weak RewindPlayer *weak=self;self.observer=[self.player addPeriodicTimeObserverForInterval:CMTimeMake(1,2)queue:dispatch_get_main_queue()usingBlock:^(CMTime time){[weak updatePlayback];}];
}
- (void)preloadMediaSelection:(AVPlayerItem *)item {
    AVAsset *asset=item.asset;NSUInteger generation=self.playbackGeneration;__weak RewindPlayer *weak=self;
    [asset loadValuesAsynchronouslyForKeys:@[@"availableMediaCharacteristicsWithMediaSelectionOptions"] completionHandler:^{
        AVMediaSelectionGroup *group=nil;
        if([asset statusOfValueForKey:@"availableMediaCharacteristicsWithMediaSelectionOptions" error:nil]==AVKeyValueStatusLoaded)group=[asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicLegible];
        dispatch_async(dispatch_get_main_queue(),^{if(weak.closing||weak.playbackGeneration!=generation||weak.player.currentItem!=item)return;weak.captionGroup=group;weak.mediaSelectionLoaded=YES;});
    }];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    AVPlayerItem *item=object;__weak RewindPlayer *weak=self;NSUInteger generation=self.playbackGeneration;
    dispatch_async(dispatch_get_main_queue(),^{
        if(weak.closing||weak.exhausted||generation!=weak.playbackGeneration||item!=weak.player.currentItem)return;
        if(item.status==AVPlayerItemStatusReadyToPlay&&!weak.mediaVerified)[weak loadPlaybackProperties:item];
        else if(item.status==AVPlayerItemStatusFailed)[weak failSource:item.error.localizedDescription?:@"The video could not be decoded."];
    });
}
- (void)tick {
    [self confirmSubtitleChoice];
    if(![[RewindStore shared]allowed:self.meta]){[self close];return;}
    if(self.closing||self.exhausted||self.refreshing||[UIApplication sharedApplication].applicationState!=UIApplicationStateActive)return;double now=NSProcessInfo.processInfo.systemUptime;
    if(!self.hasStartedPlayback&&self.startupBegan>0&&now-self.startupBegan>=RWStartupLimitSeconds){[self showUnavailable:@"This connection could not start the video in time. Try another quality or try again later."];return;}
    if(self.lastUITick>0)self.maxUITickGap=MAX(self.maxUITickGap,now-self.lastUITick);self.lastUITick=now;
    if(self.engine&&(self.discovering||[RWString(self.source[@"url"])hasPrefix:@"magnet:"])){
        if(self.enginePollPending)return;self.enginePollPending=YES;
        BOOL discovery=self.discovering,pendingSubtitle=self.subtitlePending;NSUInteger generation=self.playbackGeneration,subtitleGeneration=self.subtitleGeneration;__weak RewindPlayer *weak=self;
        [self.engine perform:^(TorrentEngine *engine){
            NSDictionary *race=discovery?[engine discoverySnapshot]:nil;
            NSDictionary *snapshot=(!discovery||[race[@"selected"]boolValue])?[engine snapshot]:nil;
            NSDictionary *selected=engine.selectedSource;NSArray *files=snapshot?[engine subtitleFiles]:@[];NSData *subtitle=pendingSubtitle?[engine subtitleData]:nil;
            dispatch_async(dispatch_get_main_queue(),^{
                if(weak.closing||weak.exhausted||weak.playbackGeneration!=generation)return;weak.enginePollPending=NO;weak.lastEnginePoll=NSProcessInfo.processInfo.systemUptime-now;
                if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
                weak.torrentSubtitleFiles=files;
                [weak consumeRace:race snapshot:snapshot selected:selected];
                if(weak.closing||weak.playbackGeneration!=generation||weak.discovering||weak.exhausted)return;
                if(subtitle&&weak.subtitlePending&&weak.subtitleGeneration==subtitleGeneration)[weak installSubtitleData:subtitle];
                [weak finishTick];
            });
        }];
    }else [self finishTick];
}
#include "RewindTorrentSelection.inc"
- (void)finishTick {
    if(self.refreshing)return;
    double now=NSProcessInfo.processInfo.systemUptime;
    [self pollLegacy];if(self.closing||self.exhausted)return;
    if(!self.hasStartedPlayback&&self.mediaVerified&&[self frameVisible]){self.hasStartedPlayback=YES;self.lastInteraction=[NSDate date].timeIntervalSince1970;}
    if(!self.hasStartedPlayback && RWInitialWaitExpired(now-self.startupBegan,now-self.attemptStarted,now-self.lastDownloadProgress)){[self failSource:@"The source did not deliver playable opening data in time."];return;}
    if(self.subtitlePending&&now-self.subtitleStarted>20){BOOL automatic=self.subtitleAutomatic;[self clearSubtitles];if(!automatic)RWAlert(self,@"Subtitles unavailable",@"The subtitle file has not arrived from this source. Try another language.");}
    double position=[self playbackPosition];
    if(self.mediaVerified && isfinite(position) && fabs(position-self.lastPosition)>.2){self.lastPosition=position;self.lastProgress=now;}
    if(RWNativeSeekExpired(self.nativeSeekPending,self.wantsPlay,now-self.nativeSeekStarted)){[self failSource:@"The seek did not finish loading video in time."];return;}
    double recoveryBuffer=self.player&&!self.legacy?[self nativeBufferedAhead]:0;
    if(self.player&&!self.legacy&&_nativeBufferRecovery.resume(now,position,self.player.rate,self.mediaVerified&&self.hasStartedPlayback&&self.player.currentItem.status==AVPlayerItemStatusReadyToPlay,self.wantsPlay,self.seeking||self.nativeSeekPending,recoveryBuffer,MAX(0,[self playbackDuration]-position))){
        [self.player play];[self.metrics recordEvent:@"native_buffer_resume" values:@{@"position":@(position),@"buffered_seconds":@(recoveryBuffer),@"attempt":@(_nativeBufferRecovery.attempts)} uptime:now];
    }
    if(RWPlaybackStalled(self.hasStartedPlayback,self.wantsPlay,self.seeking||self.nativeSeekPending,now-self.lastProgress)&&!_nativeBufferRecovery.grace(now)){[self failSource:@"The connection stopped delivering video."];return;}
    [self updatePlayback];
    double interactionNow=[NSDate date].timeIntervalSince1970;
    if(self.presentedViewController||self.seeking||self.nativeSeekPending){self.lastInteraction=interactionNow;self.controls.alpha=1;}
    else if(self.hasStartedPlayback&&self.wantsPlay&&[self playbackRate]>0&&interactionNow-self.lastInteraction>5)self.controls.alpha=0;
}
- (void)updatePlayback{
    if(!self.hasStartedPlayback&&self.mediaVerified&&[self frameVisible]){self.hasStartedPlayback=YES;self.lastInteraction=[NSDate date].timeIntervalSince1970;}
    BOOL loading=!self.mediaVerified||![self frameVisible];self.loadingPanel.hidden=!loading;if(!loading)[self.metrics markStage:@"loading_overlay_removed" uptime:NSProcessInfo.processInfo.systemUptime];
    if(!loading&&[self.statusLabel.text isEqual:@"Selecting a live connection"])self.statusLabel.text=@"";
    self.titleLabel.hidden=loading;self.statusLabel.hidden=loading;self.qualityButton.hidden=loading&&!self.exhausted;
    self.loadingArt.hidden=!loading;self.loadingShade.hidden=!loading;self.keepButton.hidden=loading||self.transient||!RWString(self.source[@"infoHash"]).length;
    for(UIView *control in @[self.playButton,self.backward,self.forward,self.restart,self.captions,self.scrubber,self.timeLabel,self.bufferedTrack,self.audioButton])control.hidden=loading;
    if(loading){self.controls.alpha=1;if(!self.exhausted)[self.spinner startAnimating];}
    if(self.mediaVerified&&loading){self.loadingTitle.text=@"Starting playback";self.loadingDetail.text=@"Picture and sound checked. Buffering the opening…";}
    double buffered=0;for(NSValue *range in self.player.currentItem.loadedTimeRanges){CMTimeRange t=range.CMTimeRangeValue;double start=CMTimeGetSeconds(t.start),end=CMTimeGetSeconds(CMTimeRangeGetEnd(t));double current=[self playbackPosition];if(isfinite(current)&&start<=current+.2&&end>=current)buffered=MAX(buffered,end-current);}
    self.loadingProgress.hidden=!(loading&&self.mediaVerified&&buffered>0&&!self.exhausted);self.loadingProgress.progress=MIN(1,buffered/4.);
    double position=[self playbackPosition],duration=[self playbackDuration];if(!isfinite(position))position=0;
    self.bufferedTrack.progress=isfinite(duration)&&duration>0?MIN(1,(position+buffered)/duration):0;
    if(!self.seeking){self.scrubber.maximumValue=isfinite(duration)&&duration>0?duration:1;self.scrubber.value=position;}
    self.timeLabel.text=[NSString stringWithFormat:@"%@ / %@",RWTime(position),isfinite(duration)?RWTime(duration):@"—"];
    BOOL spin=_motion.spinner(NSProcessInfo.processInfo.systemUptime,position,self.mediaVerified,[self frameVisible],self.wantsPlay,self.seeking,self.exhausted);
    self.spinner.center=loading?CGPointMake(62,self.view.bounds.size.height-67):CGPointMake(self.view.bounds.size.width/2,self.view.bounds.size.height/2);
    if(spin)[self.spinner startAnimating];else [self.spinner stopAnimating];
    if(self.mediaVerified&&[self frameVisible]&&position>self.resumePosition+5&&!self.recordedGoodSource){self.recordedGoodSource=YES;NSMutableDictionary *observation=[self.source mutableCopy];NSDictionary *timing=[self.metrics snapshot];if([timing[@"attempts"]integerValue]==1&&[timing[@"first_advancing_playback_seconds"]doubleValue]>=0)observation[@"tap_to_advancing_seconds"]=timing[@"first_advancing_playback_seconds"];if(!self.exerciseRecovery&&![RWString(self.source[@"url"])hasPrefix:@"asset:"])[self.metrics recordSourceOutcome:[[RewindStore shared]sourceSucceeded:observation] engine:self.lastTorrentSnapshot[@"session_id"] uptime:NSProcessInfo.processInfo.systemUptime];}
    if(!loading&&(!self.transient||(self.deviceExerciseEnabled&&[self.videoID hasPrefix:@"rw:subtitle-"]))&&!self.automaticSubtitlesTried&&(self.legacy||self.mediaSelectionLoaded)){self.automaticSubtitlesTried=YES;[self selectPreferredSubtitles];}
    self.spinner.accessibilityLabel=spin?@"Buffering":@"";
    [self.playButton setImage:RWIcon(self.wantsPlay?@"pause":@"play",30,RWColor(0x15181d)) forState:UIControlStateNormal];self.playButton.accessibilityLabel=self.wantsPlay?@"Pause":@"Play";
    NSDictionary *intro=[[RewindStore shared]profile][@"intros"][self.videoID];NSArray *segments=intro?@[intro]:(self.automaticSegments?:@[]);self.activeSegment=nil;
    for(NSDictionary *segment in segments)if(isfinite(duration)&&[segment[@"end"]doubleValue]<=duration&&position>=[segment[@"start"]doubleValue]&&position<[segment[@"end"]doubleValue]){self.activeSegment=segment;break;}
    self.skipIntro.hidden=loading||self.activeSegment==nil;[self.skipIntro setTitle:self.activeSegment[@"label"]?:@"Skip intro" forState:UIControlStateNormal];
    self.nextEpisodeButton.hidden=loading||!self.onNextEpisode||!self.nextEpisodeLabel.length||!self.skipIntro.hidden;
    [self refreshSubtitleText];
    if(self.reviewOnly)return;
    [self.metrics recordAtUptime:NSProcessInfo.processInfo.systemUptime position:position ready:self.mediaVerified wantsPlay:self.wantsPlay frameVisible:[self frameVisible] seeking:self.seeking||self.nativeSeekPending];
    double now=[NSDate date].timeIntervalSince1970;if(now-self.lastSaved>5){self.lastSaved=now;[self persist];[self collectMetrics];
        [[RewindStore shared]report:@{@"screen":@"player",@"title":RWString(self.meta[@"name"]),@"position":@(position),@"duration":@(isfinite(duration)?duration:0),@"player_rate":@([self playbackRate]),@"resume_requested":@(self.resumePosition)}];}
}
- (void)persist{if(self.transient||(!self.player&&!self.legacy)||!self.mediaVerified)return;if(self.exercisePersistenceProfile&&(![[RewindStore shared].state[@"activeProfile"]isEqual:self.exercisePersistenceProfile]||!(self.exercisePersistenceRun?[RWDeviceExercise ownsKidsProfile:[RewindStore shared].profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue] run:self.exercisePersistenceRun]:[RWDeviceExercise ownsResumeProfile:[RewindStore shared].profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]])))return;double p=[self playbackPosition],d=[self playbackDuration];NSMutableDictionary *source=[self.source mutableCopy];if(self.lastTorrentSnapshot){source[@"downloadComplete"]=self.lastTorrentSnapshot[@"video_complete"]?:@NO;source[@"downloadBytes"]=self.lastTorrentSnapshot[@"video_verified_bytes"]?:@0;if([self.lastTorrentSnapshot[@"offline_certificate"]count])source[@"offlineCertificate"]=self.lastTorrentSnapshot[@"offline_certificate"];}NSDictionary *metrics=[self.metrics snapshot];[[RewindStore shared]notePlayback:self.meta videoID:self.videoID source:source quality:self.quality metrics:metrics];[[RewindStore shared]remember:self.meta videoID:self.videoID source:source position:p duration:d metrics:metrics];}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    // A button or slider owns its touch; the background tap must not also hide
    // the controls or compete with the slider's drag recognizer.
    for(UIView *view=touch.view;view;view=view.superview)if([view isKindOfClass:UIControl.class])return NO;
    return YES;
}
- (void)controlTouched:(UIControl *)control {
    self.lastInteraction=[NSDate date].timeIntervalSince1970;self.controlTouchCount++;
    self.lastControlTouch=control.accessibilityLabel?:NSStringFromClass(control.class);
}
- (void)toggleControls:(UITapGestureRecognizer*)tap {
    if(!self.mediaVerified||self.presentedViewController)return;
    self.controlsTapCount++;self.controls.alpha=self.controls.alpha>0?0:1;[self layoutSubtitle];self.lastInteraction=[NSDate date].timeIntervalSince1970;
}
- (NSDictionary *)controlsDiagnostics {
    NSMutableDictionary *hits=[NSMutableDictionary new];
    if(self.controls.alpha>.01&&!self.presentedViewController)for(UIControl *control in @[self.closeButton,self.audioButton,self.captions,self.scrubber]){
        if(control.hidden)continue;
        CGPoint point=[control convertPoint:CGPointMake(CGRectGetMidX(control.bounds),CGRectGetMidY(control.bounds)) toView:self.view];
        UIView *hit=[self.view hitTest:point withEvent:nil];
        hits[control.accessibilityLabel?:NSStringFromClass(control.class)]=@(hit==control||[hit isDescendantOfView:control]);
    }
    return @{@"visible":@(self.controls.alpha>.01),@"background_taps":@(self.controlsTapCount),@"control_touches":@(self.controlTouchCount),@"last_control_touch":self.lastControlTouch?:@"",@"root_gesture_count":@(self.view.gestureRecognizers.count),@"menu_presented":@(self.presentedViewController!=nil),@"button_hit_tests":hits};
}
- (void)togglePlay{if(!self.mediaVerified)return;self.wantsPlay=!self.wantsPlay;self.lastProgress=NSProcessInfo.processInfo.systemUptime;[UIApplication sharedApplication].idleTimerDisabled=YES;self.lastInteraction=[NSDate date].timeIntervalSince1970;if(!self.wantsPlay){[self pauseMedia];[self persist];}else{[self.engine resume];double position=[self playbackPosition],duration=[self playbackDuration];if(isfinite(duration)&&position>=duration-.5)[self seek:0];[self playMedia];}[self updatePlayback];}
- (void)seek:(double)seconds{if(!self.mediaVerified||!isfinite(seconds))return;self.playbackEnded=NO;[self.metrics noteSeek];self.lastProgress=NSProcessInfo.processInfo.systemUptime;self.lastInteraction=[NSDate date].timeIntervalSince1970;double d=[self playbackDuration];double target=MAX(0,seconds);if(isfinite(d))target=MIN(target,MAX(0,d-0.1));[self.engine resetPlaybackRequests];if(self.legacy)[self.legacy seek:target];else [self seekNative:target];}
#include "RWNativeSeek.inc"
- (double)nativeBufferedAhead {
    double current=[self playbackPosition];if(!isfinite(current))return 0;double end=current;
    // Join overlapping ranges independent of their order. Never count a
    // disjoint future range as buffer at the current playhead.
    NSArray *ranges=self.player.currentItem.loadedTimeRanges;
    for(NSUInteger pass=0;pass<ranges.count;pass++){double previous=end;for(NSValue *value in ranges){CMTimeRange range=value.CMTimeRangeValue;double start=CMTimeGetSeconds(range.start),duration=CMTimeGetSeconds(range.duration);if(!isfinite(start)||!isfinite(duration)||duration<0)continue;if(start<=end+.05&&start+duration>end)end=start+duration;}if(end==previous)break;}
    return MAX(0,end-current);
}
- (NSDictionary *)nativeSeekSnapshot {
    NSMutableArray *ranges=[NSMutableArray new];for(NSValue *value in self.player.currentItem.loadedTimeRanges){CMTimeRange range=value.CMTimeRangeValue;double start=CMTimeGetSeconds(range.start),duration=CMTimeGetSeconds(range.duration);if(isfinite(start)&&isfinite(duration)&&duration>=0)[ranges addObject:@{@"start":@(start),@"duration":@(duration)}];if(ranges.count==8)break;}
    return @{@"buffered_ahead":@([self nativeBufferedAhead]),@"buffer_resume_attempts":@(_nativeBufferRecovery.attempts),@"buffer_resume_requests":@(_nativeBufferRecovery.requests),@"pending":@(self.nativeSeekPending),@"finished":@(self.nativeSeekFinished),@"generation":@(self.nativeSeekGeneration),@"target":@(self.nativeSeekTarget),@"elapsed":@(self.nativeSeekStarted>0?MAX(0,(self.nativeSeekCompleted?:NSProcessInfo.processInfo.systemUptime)-self.nativeSeekStarted):0),@"rate":@(self.player.rate),@"buffer_empty":@(self.player.currentItem.playbackBufferEmpty),@"buffer_full":@(self.player.currentItem.playbackBufferFull),@"likely_to_keep_up":@(self.player.currentItem.playbackLikelyToKeepUp),@"loaded_ranges":ranges};
}
- (void)jump:(double)seconds{[self seek:[self playbackPosition]+seconds];}
- (void)scrubBegin{self.seeking=YES;self.lastInteraction=[NSDate date].timeIntervalSince1970;}
- (void)scrubEnd{self.seeking=NO;[self seek:self.scrubber.value];}
- (void)ended{self.playbackEnded=YES;self.wantsPlay=NO;[self pauseMedia];[self persist];self.controls.alpha=1;self.statusLabel.text=@"Finished · added to your watch history";[self.playButton setImage:RWIcon(@"play",30,RWColor(0x15181d)) forState:UIControlStateNormal];self.playButton.accessibilityLabel=@"Play again";self.resumePosition=0;
    if([self.videoID isEqual:@"rw:surround-check:preview"]&&!self.presentedViewController){
        UIAlertController *check=[UIAlertController alertControllerWithTitle:@"Did you hear all three tones?" message:@"They check the centre and rear channels used by surround films." preferredStyle:UIAlertControllerStyleAlert];
        [check addAction:[UIAlertAction actionWithTitle:@"All three worked" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[RWSourcePolicy setNativeSurroundEnabled:YES];[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"RWNativeSurroundQualified"];[[RewindStore shared]report:@{@"native_surround_user_confirmed":@YES}];}]];
        [check addAction:[UIAlertAction actionWithTitle:@"Sound was missing" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){[RWSourcePolicy setNativeSurroundEnabled:NO];[NSUserDefaults.standardUserDefaults setBool:NO forKey:@"RWNativeSurroundQualified"];[[RewindStore shared]report:@{@"native_surround_user_confirmed":@NO}];}]];
        [self presentViewController:check animated:YES completion:nil];
    }
}
- (void)background{[self.subtitleTicker invalidate];self.subtitleTicker=nil;[self.exerciseSubtitleTiming stop:@"background"];[self.exerciseSubtitleLoadTask cancel];self.resumeAfterForeground=self.wantsPlay;self.wantsPlay=NO;[self pauseMedia];[self.engine pause];[self persist];self.controls.alpha=1;[UIApplication sharedApplication].idleTimerDisabled=NO;}
- (void)foreground{if(self.closing||self.exhausted)return;self.lastUITick=0;self.attemptStarted=self.lastProgress=self.lastDownloadProgress=NSProcessInfo.processInfo.systemUptime;self.startupBegan=NSProcessInfo.processInfo.systemUptime;[self.engine resume];self.wantsPlay=self.resumeAfterForeground;if(self.wantsPlay&&self.mediaVerified)[self playMedia];[UIApplication sharedApplication].idleTimerDisabled=YES;}
- (void)chooseAudio {
    if(self.deviceExerciseEnabled)self.exerciseAudioActions=[NSMutableDictionary new];
    if(self.legacy){[self legacyTrackMenu:YES];return;}
    self.lastInteraction=[NSDate date].timeIntervalSince1970;__weak RewindPlayer *weak=self;
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Audio language" message:[self.audioSelection[@"message"]length]?self.audioSelection[@"message"]:@"Available audio tracks supported by this iPad" preferredStyle:UIAlertControllerStyleActionSheet];NSUInteger count=0;
    for(NSDictionary *choice in self.audioChoices){AVPlayerItemTrack *track=choice[@"track"];count++;NSString *label=[choice[@"descriptor"][@"label"]stringByAppendingString:track.enabled?@" · Selected":@""];
        void(^action)(void)=^{[weak selectNativeAudio:choice remember:YES];};if(self.deviceExerciseEnabled)self.exerciseAudioActions[label]=[action copy];
        [a addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){action();}]];
    }
    if(!count)a.message=@"This source has no alternative compatible audio track.";
    [a addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=self.audioButton;a.popoverPresentationController.sourceRect=self.audioButton.bounds;[self presentViewController:a animated:YES completion:nil];
}
#include "RewindSubtitleState.inc"
#include "RewindSubtitles.inc"
- (void)toggleKeep {
    NSString *hash=RWString(self.source[@"infoHash"]);if(!hash.length)return;
    NSMutableArray *kept=[[RewindStore shared].state[@"keptDownloads"]mutableCopy]?:[NSMutableArray new];
    if([kept containsObject:hash])[kept removeObject:hash];else[kept addObject:hash];
    [RewindStore shared].state[@"keptDownloads"]=kept;[[RewindStore shared]save];
    [self.keepButton setTitle:[kept containsObject:hash]?@"Download kept":@"Keep download" forState:UIControlStateNormal];
}
- (BOOL)beginLifecycleExercise:(NSString *)backend {
    if(self.isViewLoaded||![self.videoID isEqual:[NSString stringWithFormat:@"rw:lifecycle-%@:preview",backend]]||![RWDeviceExercise isLifecycleSource:self.source backend:backend])return NO;
    [self beginSubtitleExercise];self.exerciseRecovery=YES;return YES;
}
- (RWPlaybackLifetimeProbe *)deviceExerciseLifetimeProbe {
    if(!self.deviceExerciseEnabled||!self.transient||!self.exerciseRecovery||![self.videoID hasPrefix:@"rw:lifecycle-"])return nil;
    NSMutableDictionary *objects=[NSMutableDictionary dictionaryWithObject:self forKey:@"player"];
    if(self.engine)objects[@"engine"]=self.engine;if(self.loader)objects[@"loader"]=self.loader;if(self.player)objects[@"native_player"]=self.player;if(self.legacy)objects[@"legacy_player"]=self.legacy;
    return [[RWPlaybackLifetimeProbe alloc]initWithObjects:objects];
}
- (NSDictionary *)deviceExerciseTransportSnapshot {
    if(!self.deviceExerciseEnabled||!self.transient||!self.exerciseRecovery||![self.videoID hasPrefix:@"rw:lifecycle-"])return @{};
    return @{@"loader":self.loader.diagnostics?:@{},@"metrics":[self.metrics snapshot]?:@{},@"active_sessions":@([TorrentEngine activeSessionCount])};
}
- (BOOL)beginRecoveryExercise {
    if(self.isViewLoaded||![self.videoID isEqual:@"rw:recovery-mkv:preview"]||![RWDeviceExercise isRecoverySource:self.source])return NO;
    [self beginSubtitleExercise];self.exerciseRecovery=YES;return YES;
}
- (void)beginDeviceExercise {NSAssert(!self.isViewLoaded,@"Arm before presenting the player");self.transient=YES;self.deviceExerciseEnabled=YES;}
- (BOOL)beginKidsExercise:(NSString *)run {
    RewindStore *s=RewindStore.shared;
    if(self.isViewLoaded||![self.videoID isEqual:@"tt1727587"]||![RWID(self.meta)isEqual:self.videoID]||![s.state[@"activeProfile"]isEqual:@"rw-device-kids-12"]||![RWDeviceExercise ownsKidsProfile:s.profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue] run:run]||![s allowed:self.meta])return NO;
    [self beginDeviceExercise];self.transient=NO;self.exercisePersistenceProfile=@"rw-device-kids-12";self.exercisePersistenceRun=run;return YES;
}
- (BOOL)beginSubtitleLayoutOrientation:(UIInterfaceOrientation)orientation {
    if(self.isViewLoaded||!self.deviceExerciseEnabled||!self.transient||![@[@"rw:subtitle-native:preview",@"rw:subtitle-mkv:preview"]containsObject:self.videoID]||![@[@(UIInterfaceOrientationPortrait),@(UIInterfaceOrientationLandscapeLeft),@(UIInterfaceOrientationLandscapeRight)]containsObject:@(orientation)])return NO;
    self.exerciseLayoutOrientation=orientation;return YES;
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {return self.exerciseLayoutOrientation?(UIInterfaceOrientationMask)(1UL<<self.exerciseLayoutOrientation):[super supportedInterfaceOrientations];}
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {if(self.exerciseLayoutOrientation)return self.exerciseLayoutOrientation;return [super preferredInterfaceOrientationForPresentation];}
- (void)beginSubtitleExercise {[self beginDeviceExercise];self.transientSubtitlePreferences=[@{@"subtitleLanguage":@"en",@"subtitlesEnabled":@YES,@"subtitleSize":@24,@"subtitleDelay":@0}mutableCopy];}
- (BOOL)beginLegacyFontExercise:(NSString *)font {
    if(self.isViewLoaded||!self.deviceExerciseEnabled||![@[@"default",@"Arial",@"HelveticaNeue"]containsObject:font])return NO;
    BOOL audio=[@[@"rw:audio-mkv",@"rw:audio-mkv-other"]containsObject:self.videoID]&&[self.source[@"url"]isEqual:@"asset:audio-check.mkv"]&&!self.transient&&[self.exercisePersistenceProfile isEqual:@"rw-device-resume-check"]&&[RWDeviceExercise ownsResumeProfile:RewindStore.shared.profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]];
    BOOL subtitles=self.transient&&(([self.videoID isEqual:@"rw:subtitle-mkv:preview"]&&[self.source[@"url"]isEqual:@"asset:subtitle-check.mkv"])||([self.videoID isEqual:@"rw:font-captions:preview"]&&[self.source[@"url"]isEqual:@"asset:subtitle-font-check.mkv"]));
    if(!audio&&!subtitles)return NO;self.exerciseLegacyFont=font;return YES;
}
- (BOOL)beginAudioExercise {
    RewindStore *store=RewindStore.shared;NSString *ext=[@[@"rw:audio-native",@"rw:audio-native-other",@"rw:audio-native-fallback",@"rw:audio-native-named"]containsObject:self.videoID]?@"mp4":[@[@"rw:audio-mkv",@"rw:audio-mkv-other",@"rw:audio-mkv-fallback",@"rw:audio-mkv-named"]containsObject:self.videoID]?@"mkv":nil;
    NSInteger build=[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue];NSString *key=store.state[@"activeProfile"];
    BOOL owned=[key isEqual:@"rw-device-resume-check"]&&[RWDeviceExercise ownsResumeProfile:store.profile build:build];
    owned=owned||([key isEqual:@"rw-device-audio-other"]&&[RWDeviceExercise ownsAudioCompanion:store.profile parent:store.state[@"profiles"][@"rw-device-resume-check"] build:build]);
    if(self.isViewLoaded||!ext||![self.source[@"url"]isEqual:[([self.videoID hasSuffix:@"-fallback"]?@"asset:audio-fallback.":[self.videoID hasSuffix:@"-named"]?@"asset:audio-named.":@"asset:audio-check.") stringByAppendingString:ext]]||!owned)return NO;
    [self beginDeviceExercise];self.transient=NO;self.exercisePersistenceProfile=key;return YES;
}
- (BOOL)beginResumeExercise {
    RewindStore *store=[RewindStore shared];
    NSInteger build=[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue];NSString *key=store.state[@"activeProfile"];
    BOOL primary=[key isEqual:@"rw-device-resume-check"]&&[RWDeviceExercise ownsResumeProfile:store.profile build:build];
    BOOL companion=[key isEqual:@"rw-device-audio-other"]&&[RWDeviceExercise ownsAudioCompanion:store.profile parent:store.state[@"profiles"][@"rw-device-resume-check"] build:build];
    if(self.isViewLoaded||(!primary&&!companion))return NO;
    NSString *backend=[self.videoID isEqual:@"rw:resume-native"]?@"mp4":[self.videoID isEqual:@"rw:resume-mkv"]?@"mkv":nil;
    BOOL torrent=[self.videoID isEqual:@"rw:resume-torrent"]&&[RWDeviceExercise isResumeTorrentSource:self.source];
    if((torrent&&!primary)||(!torrent&&(!backend||![self.source[@"url"]isEqual:[@"asset:subtitle-check." stringByAppendingString:backend]])))return NO;
    [self beginDeviceExercise];self.transient=NO;self.exercisePersistenceProfile=key;return YES;
}
- (BOOL)beginEpisodeExercise {
    RewindStore *store=[RewindStore shared];NSDictionary *source=store.profile[@"sources"][self.videoID];
    if(self.isViewLoaded||![store.state[@"activeProfile"]isEqual:@"rw-device-resume-check"]||![RWDeviceExercise ownsResumeProfile:store.profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]]||![RWDeviceExercise isEpisodeExerciseSource:source videoID:self.videoID])return NO;
    [self beginDeviceExercise];self.transient=NO;self.exercisePersistenceProfile=@"rw-device-resume-check";
    // Fixed generated clips only; synthetic episode IDs are never sent to providers.
    self.automaticSources=NO;self.source=source;self.candidates=@[source];self.ranked=@[source];return YES;
}
- (BOOL)beginOfflineExercise {
    RewindStore *store=[RewindStore shared];NSDictionary *source=store.profile[@"sources"][self.videoID];
    if(self.isViewLoaded||![self.videoID isEqual:@"rw:offline-check"]||![store.state[@"activeProfile"]isEqual:@"rw-device-resume-check"]||![RWDeviceExercise ownsResumeProfile:store.profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]]||![RWDeviceExercise isOfflineExerciseSource:source])return NO;
    [self beginDeviceExercise];self.transient=NO;self.exercisePersistenceProfile=@"rw-device-resume-check";self.automaticSources=NO;self.source=source;self.candidates=@[source];self.ranked=@[source];return YES;
}
- (NSDictionary *)deviceExerciseSnapshot {
    double position=[self playbackPosition],duration=[self playbackDuration];if(!isfinite(position))position=0;if(!isfinite(duration))duration=0;
    UIAlertController *sheet=[self.presentedViewController isKindOfClass:UIAlertController.class]?(UIAlertController *)self.presentedViewController:nil;
    return @{@"subtitle_position":@(self.legacy?self.legacy.subtitlePosition:position),@"subtitle_choice_pending":@(self.subtitlePendingChoice!=nil),@"real_captions":[RWSourceWork snapshot:self.exerciseRealCaptions]?:@{},@"subtitle_refresh_active":@(self.subtitleTicker.running),@"subtitle_timing":self.exerciseSubtitleTiming.summary?:@{},@"subtitle_load":self.exerciseSubtitleLoad?:@{},@"subtitle_layout":[self.subtitleLabel layoutDiagnostics]?:@{},@"player_size":@[@(self.view.bounds.size.width),@(self.view.bounds.size.height)],@"subtitle_frames":[self.exerciseSubtitleFrames copy]?:@{},@"controls_alpha":@(self.controls.alpha),@"controls_hidden":@(self.controls.hidden),@"native_seek":[self nativeSeekSnapshot],@"ended":@(self.playbackEnded),@"video_id":self.videoID?:@"",@"next_episode_label":self.nextEpisodeLabel?:@"",@"next_episode_visible":@(!self.nextEpisodeButton.hidden),@"next_episode_requested":@(self.nextEpisodeRequested),@"torrent":self.lastTorrentSnapshot?:@{},@"position":@(position),@"requested_position":@(self.resumePosition),@"resumed":@(self.resumed),@"persistence_profile":self.exercisePersistenceProfile?:@"",@"duration":@(duration),@"frame_visible":@([self frameVisible]),@"media_verified":@(self.mediaVerified),@"wants_play":@(self.wantsPlay),@"exhausted":@(self.exhausted),@"closing":@(self.closing),@"audio_selection":self.audioSelection?:@{},@"audio_track_count":@(self.legacy?[self.legacy audioTracks].count:self.audioChoices.count),@"transient":@(self.transient),@"backend":self.legacy?@"mkv":@"native",@"keep_visible":@(!self.keepButton.hidden),@"subtitle_identity":self.subtitleDescriptor?:@{},@"subtitle_content_digest":self.subtitleContentDigest?:@"",@"subtitle_adjustment_key":[self subtitleAdjustmentKey],@"subtitle_decode":self.subtitleDecode?:@{},@"subtitle_transfer":self.subtitleTransfer?:@{},@"subtitle_text":self.subtitleLabel.text?:@"",@"subtitle_name":self.subtitleName?:@"",@"subtitle_cues":@(self.cues.count),@"subtitle_delay":@(self.subtitleDelay),@"subtitle_font":@(self.subtitleLabel.font.pointSize),@"embedded_subtitle":@(self.legacy?self.legacy.selectedSubtitle:-1),@"embedded_delay":@(self.legacy?self.legacy.subtitleDelay:0),@"embedded_metrics":[self.legacy metrics]?:@{},@"embedded_refreshes":[self.legacy metrics][@"subtitle_refreshes"]?:@0,@"embedded_tracks":self.legacy.subtitleTracks?:@[],@"subtitle_enabled":[self subtitlePreferences][@"subtitlesEnabled"]?:@NO,@"menu":sheet.title?:@"",@"menu_actions":[sheet.actions valueForKey:@"title"]?:@[]};
}
- (NSDictionary *)subtitleTimingEvidence {
    if(!self.deviceExerciseEnabled||!self.transient)return nil;
    return @{ @"timing":self.exerciseSubtitleTiming.evidence?:@{}, @"load":self.exerciseSubtitleLoad?:@{}, @"frame_clock":[self.legacy frameClockEvidence]?:@{} };
}
- (BOOL)deviceExerciseControl:(NSString *)control {
    if(!self.deviceExerciseEnabled||(!self.transient&&!self.exercisePersistenceProfile)||!self.isViewLoaded)return NO;
    if([control isEqual:@"close"]){if(!self.closing){if(self.presentedViewController){__weak RewindPlayer *weak=self;[self dismissViewControllerAnimated:NO completion:^{[weak close];}];return YES;}[self.closeButton sendActionsForControlEvents:UIControlEventTouchUpInside];}return self.closing;}
    if(self.closing||!self.mediaVerified||![self frameVisible])return NO;
    if([control isEqual:@"lifecycle-seek:30"]){
        NSString *backend=[self.videoID isEqual:@"rw:lifecycle-native:preview"]?@"native":[self.videoID isEqual:@"rw:lifecycle-mkv:preview"]?@"mkv":nil;
        if(!self.transient||!self.exerciseRecovery||!backend||![RWDeviceExercise isLifecycleSource:self.source backend:backend]||self.wantsPlay||self.presentedViewController)return NO;
        [self seek:30];return YES;
    }
    if([control isEqual:@"recovery-caption-observe"]||[control isEqual:@"recovery-clock-audit"]){
        if(!self.exerciseRecovery||!self.transient||![self.videoID isEqual:@"rw:recovery-mkv:preview"]||![RWDeviceExercise isRecoverySource:self.source]||self.presentedViewController)return NO;
        if([control isEqual:@"recovery-clock-audit"]){if(!self.exerciseSubtitleTiming)return NO;[self.exerciseSubtitleTiming stop:@"completed"];return YES;}
        if(self.exerciseSubtitleTiming||!self.wantsPlay||!self.legacy)return NO;
        __weak RewindPlayer *weak=self;
        self.exerciseSubtitleTiming=[[RWSubtitleTimingProbe alloc]initWithSample:^NSDictionary *{
            RewindPlayer *owner=weak;if(!owner||owner.closing)return nil;
            return @{@"caption_buffering":@(owner.legacy.captionBuffering),@"position":@([owner playbackPosition]),@"caption_position":@(owner.legacy.subtitlePosition),@"text":owner.subtitleLabel.text?:@"",@"hidden":@(owner.subtitleLabel.hidden),@"rate":@([owner playbackRate]),@"wants_play":@(owner.wantsPlay)};
        }];return YES;
    }
    if([control hasPrefix:@"recovery-seek:"]){
        if(!self.exerciseRecovery||!self.transient||![RWDeviceExercise isRecoverySource:self.source]||self.presentedViewController)return NO;
        NSString *value=[[control componentsSeparatedByString:@":"]lastObject];if(![@[@"30",@"150"]containsObject:value])return NO;
        [self seek:value.doubleValue];return YES;
    }
    if([control isEqual:@"subtitle-test-manual-link"]||[control hasPrefix:@"subtitle-test-seek:"]){
        RewindStore *store=RewindStore.shared;NSInteger build=[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue];NSString *key=store.state[@"activeProfile"];
        BOOL owned=([key isEqual:@"rw-device-resume-check"]&&[RWDeviceExercise ownsResumeProfile:store.profile build:build])||([key isEqual:@"rw-device-audio-other"]&&[RWDeviceExercise ownsAudioCompanion:store.profile parent:store.state[@"profiles"][@"rw-device-resume-check"] build:build]);
        if(self.transient||!owned||![self.exercisePersistenceProfile isEqual:key]||![@[@"rw:resume-native",@"rw:resume-mkv"]containsObject:self.videoID]||![@[@"asset:subtitle-check.mp4",@"asset:subtitle-check.mkv"]containsObject:self.source[@"url"]]||self.wantsPlay||self.presentedViewController)return NO;
        if([control isEqual:@"subtitle-test-manual-link"])return [self addSubtitleURL:@"http://127.0.0.1:18882/scoped.ru.forced.sdh.srt"];
        NSString *value=[[control componentsSeparatedByString:@":"]lastObject];if(![@[@"2",@"32",@"52"]containsObject:value])return NO;
        if([value isEqual:@"52"]&&[self.videoID isEqual:@"rw:resume-mkv"]&&![self.legacy beginPresentationTrace:[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"]])return NO;
        [self seek:value.doubleValue];return YES;
    }
    if([control hasPrefix:@"title-caption-"]){
        if(!self.transient)return NO;BOOL known=NO;for(NSString *key in @[@"tenzing",@"just-play-dead",@"matrix",@"back-to-future",@"two-half-early",@"two-half-late",@"breaking-bad",@"severance"])if([self.videoID isEqual:[RWDeviceExercise playbackCase:key][@"video_id"]])known=YES;if(!known)return NO;
        if(!self.exerciseRealCaptions)self.exerciseRealCaptions=[NSMutableDictionary new];
        if([control isEqual:@"title-caption-known-approach"]||[control isEqual:@"title-caption-known-seek"]){
            if(self.wantsPlay||self.presentedViewController||!self.legacy||![self.videoID isEqual:@"tt11280740:2:1"])return NO;
            BOOL exact=NO;for(NSDictionary *choice in [self subtitleChoices])if([RWDeviceExercise isManualCaptionChoice:choice source:self.source videoID:self.videoID]&&[choice[@"descriptor"][@"token"]isEqual:self.subtitleDescriptor[@"token"]])exact=YES;if(!exact)return NO;
            BOOL interior=[control hasSuffix:@"-seek"];double target=interior?2648.5:2642;
            if(interior){self.legacy.subtitleTraceEnabled=YES;if(![self.legacy beginPresentationTrace:[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"]])return NO;}
            self.exerciseRealCaptions[@"stage"]=interior?@"known-interior":@"known-approach";self.exerciseRealCaptions[@"target"]=@(target);self.exerciseRealCaptions[@"seek_started"]=@(NSProcessInfo.processInfo.systemUptime);self.exerciseRealCaptions[@"displayed_before"]=self.legacy.metrics[@"displayed_frames"]?:@0;
            [self seek:target];return YES;
        }
        if([control isEqual:@"title-caption-english"]||[control isEqual:@"title-caption-manual"]){
            if(![self.presentedViewController.title isEqual:@"Subtitles"])return NO;
            NSDictionary *choice=[RWSubtitlePolicy select:[self subtitleChoices] preference:@{@"enabled":@YES,@"language":@"en",@"forced":@NO,@"sdh":@NO}];
            BOOL manual=[control isEqual:@"title-caption-manual"];
            if(manual){choice=nil;for(NSDictionary *candidate in [self subtitleChoices])if([RWDeviceExercise isManualCaptionChoice:candidate source:self.source videoID:self.videoID]){if(choice)return NO;choice=candidate;}}
            self.exerciseRealCaptions[@"manual_unlabelled"]=@(manual);
            self.exerciseRealCaptions[@"choice_count"]=@([self subtitleChoices].count);
            if(!choice){self.exerciseRealCaptions[@"status"]=manual?@"manual_sidecar_identity_not_present":@"no_matching_english_captions";return NO;}
            self.exerciseRealCaptions[@"selected"]=choice[@"descriptor"];self.exerciseRealCaptions[@"status"]=@"selecting";self.exerciseRealCaptions[@"choice_started"]=@(NSProcessInfo.processInfo.systemUptime);
            return [self deviceExerciseControl:[@"subtitle-choice:" stringByAppendingString:choice[@"label"]]];
        }
        if([control isEqual:@"title-caption-export"]){
            if(![self.exerciseRealCaptions[@"manual_unlabelled"]boolValue]||self.wantsPlay||self.presentedViewController||self.subtitleData.length!=125647||!self.cues.count||![self.subtitleDecode[@"status"]isEqual:@"ok"]||![self.subtitleDescriptor[@"token"]isEqual:self.exerciseRealCaptions[@"selected"][@"token"]])return NO;
            BOOL exact=NO;for(NSDictionary *choice in [self subtitleChoices])if([RWDeviceExercise isManualCaptionChoice:choice source:self.source videoID:self.videoID]&&[choice[@"descriptor"][@"token"]isEqual:self.subtitleDescriptor[@"token"]])exact=YES;if(!exact)return NO;
            NSString *path=[[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"]stringByAppendingPathComponent:@"device-exercise-title-caption.srt"];
            if(![self.subtitleData writeToFile:path atomically:YES])return NO;
            self.exerciseRealCaptions[@"downloaded_bytes"]=@(self.subtitleData.length);self.exerciseRealCaptions[@"content_digest"]=self.subtitleContentDigest;self.exerciseRealCaptions[@"ready_elapsed"]=@(NSProcessInfo.processInfo.systemUptime-[self.exerciseRealCaptions[@"choice_started"]doubleValue]);return YES;
        }
        if([control isEqual:@"title-caption-off-choice"]){self.exerciseRealCaptions[@"off_started"]=@(NSProcessInfo.processInfo.systemUptime);return [self deviceExerciseControl:@"subtitle-choice:Off"];}
        if([control hasPrefix:@"title-caption-seek:"]){
            if(self.wantsPlay||self.presentedViewController)return NO;NSString *stage=[[control componentsSeparatedByString:@":"]lastObject];double duration=[self playbackDuration];
            if(![@[@"middle",@"end"]containsObject:stage]||!isfinite(duration)||duration<240)return NO;
            double target=duration*([stage isEqual:@"middle"]?.5:.9);self.exerciseRealCaptions[@"stage"]=stage;self.exerciseRealCaptions[@"target"]=@(target);self.exerciseRealCaptions[@"seek_started"]=@(NSProcessInfo.processInfo.systemUptime);self.exerciseRealCaptions[@"displayed_before"]=self.legacy.metrics[@"displayed_frames"]?:@0;
            [self seek:target];return YES;
        }
        return NO;
    }
    if([control hasPrefix:@"subtitle-clock-seek:"]){
        NSString *value=[[control componentsSeparatedByString:@":"]lastObject];
        if(!self.transient||self.wantsPlay||self.presentedViewController||![self.videoID isEqual:@"rw:subtitle-mkv:preview"]||![self.source[@"url"]isEqual:@"asset:subtitle-frame-clock.mkv"]||![@[@"12",@"6"]containsObject:value])return NO;
        [self seek:value.doubleValue];return YES;
    }
    if([control hasPrefix:@"subtitle-timing-"]){
        if(!self.transient||![@[@"rw:subtitle-native:preview",@"rw:subtitle-mkv:preview"]containsObject:self.videoID]||self.presentedViewController)return NO;
        if([control isEqual:@"subtitle-timing-load"]){
            if(self.wantsPlay||self.exerciseSubtitleLoadTask)return NO;
            self.exerciseSubtitleLoad=@{@"status":@"running"};self.exerciseSubtitleQueue=[NSOperationQueue new];self.exerciseSubtitleQueue.maxConcurrentOperationCount=1;
            NSBlockOperation *task=[NSBlockOperation new];self.exerciseSubtitleLoadTask=task;
            __weak NSBlockOperation *weakTask=task;__weak RewindPlayer *weak=self;
            [task addExecutionBlock:^{@autoreleasepool {NSDictionary *report=[RWSubtitleLoadProbe runCancelled:^BOOL{return !weakTask||weakTask.cancelled;}];dispatch_async(dispatch_get_main_queue(),^{RewindPlayer *owner=weak;if(!owner||owner.closing||weakTask.cancelled)return;owner.exerciseSubtitleLoad=report;});}}];
            [self.exerciseSubtitleQueue addOperation:task];return YES;
        }
        if([control isEqual:@"subtitle-timing-start"]){
            if(self.wantsPlay||self.exerciseSubtitleTiming||![self.subtitleName isEqual:@"Timing sample"]||self.cues.count!=24)return NO;
            if([self.source[@"url"]isEqual:@"asset:subtitle-frame-clock.mkv"]&&(![self.videoID isEqual:@"rw:subtitle-mkv:preview"]||![self.legacy beginFrameClockTrace]))return NO;
            __weak RewindPlayer *weak=self;
            self.exerciseSubtitleTiming=[[RWSubtitleTimingProbe alloc]initWithSample:^NSDictionary *{
                RewindPlayer *owner=weak;if(!owner||owner.closing)return nil;double position=[owner playbackPosition];if(!isfinite(position))return nil;
                return @{@"caption_position":@(owner.legacy?owner.legacy.subtitlePosition:position),@"position":@(position),@"text":owner.subtitleLabel.text?:@"",@"hidden":@(owner.subtitleLabel.hidden),@"rate":@([owner playbackRate]),@"wants_play":@(owner.wantsPlay)};
            } watchMainThread:[self.source[@"url"]isEqual:@"asset:subtitle-frame-clock.mkv"]];return YES;
        }
        if([control isEqual:@"subtitle-timing-stop"]){if(!self.exerciseSubtitleTiming)return NO;[self.exerciseSubtitleTiming stop:@"completed"];return YES;}
        return NO;
    }
    if([control isEqual:@"keep-download"]){if(self.keepButton.hidden||![RWDeviceExercise isOfflineExerciseSource:self.source])return NO;[self.keepButton sendActionsForControlEvents:UIControlEventTouchUpInside];return YES;}
    if([control isEqual:@"next-episode"]){if(self.nextEpisodeButton.hidden)return NO;[self.nextEpisodeButton sendActionsForControlEvents:UIControlEventTouchUpInside];return self.nextEpisodeRequested;}
    if([control isEqual:@"audio-menu"]){[self.audioButton sendActionsForControlEvents:UIControlEventTouchUpInside];return [self.presentedViewController isKindOfClass:UIAlertController.class];}
    if([control hasPrefix:@"audio-choice:"]){NSString *label=[control substringFromIndex:[@"audio-choice:" length]];void(^action)(void)=self.exerciseAudioActions[label];if(!action||![self.presentedViewController isKindOfClass:UIAlertController.class])return NO;[self dismissViewControllerAnimated:NO completion:action];return YES;}
    if([control hasPrefix:@"subtitle-frame:"]){
        NSString *label=[control substringFromIndex:[@"subtitle-frame:" length]];
        BOOL subtitleFixture=self.transient&&[self.videoID isEqual:@"rw:subtitle-mkv:preview"]&&[@[@"embedded-settled",@"embedded-french-settled",@"embedded-off-settled",@"embedded-return",@"embedded-delay"]containsObject:label];
        BOOL seekFixture=!self.transient&&[self.exercisePersistenceProfile isEqual:@"rw-device-resume-check"]&&[RWDeviceExercise ownsResumeProfile:RewindStore.shared.profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]]&&[self.videoID isEqual:@"rw:resume-mkv"]&&[@[@"seek-52",@"seek-52-delayed"]containsObject:label]&&fabs([self playbackPosition]-52)<.2;
        BOOL fontFixture=self.transient&&[self.videoID isEqual:@"rw:font-captions:preview"]&&[self.source[@"url"]isEqual:@"asset:subtitle-font-check.mkv"]&&[@[@"font-1",@"font-2",@"font-3",@"font-4",@"font-5"]containsObject:label];
        if((!subtitleFixture&&!seekFixture&&!fontFixture)||self.wantsPlay||self.presentedViewController||!self.legacy.subtitleTraceEnabled||(!fontFixture&&![self.source[@"url"]isEqual:@"asset:subtitle-check.mkv"]))return NO;
        if(self.exerciseSubtitleFrames[label])return YES;
        if(!self.exerciseSubtitleFrames)self.exerciseSubtitleFrames=[NSMutableDictionary new];
        NSString *name=[@"device-exercise-subtitle-frame-" stringByAppendingString:label],*path=[[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"]stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]];
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
        double began=NSProcessInfo.processInfo.systemUptime,position=[self playbackPosition];int track=self.legacy.selectedSubtitle;
        self.exerciseSubtitleFrames[label]=@{@"status":@"pending",@"started":@(began)};
        __weak RewindPlayer *weak=self;
        [self.legacy captureSubtitleFrame:path done:^(BOOL success){RewindPlayer *owner=weak;if(!owner||owner.closing)return;
            NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];unsigned long long bytes=[attributes fileSize];
            owner.exerciseSubtitleFrames[label]=@{@"status":success&&bytes>0&&bytes<2*1024*1024?@"complete":@"failed",@"file":[name stringByAppendingPathExtension:@"png"],@"bytes":@(bytes),@"started":@(began),@"seconds":@(NSProcessInfo.processInfo.systemUptime-began),@"track":@(track),@"position_before":@(position),@"position_after":@([owner playbackPosition]),@"wants_play":@(owner.wantsPlay)};
        }];return YES;
    }
    if([control hasPrefix:@"subtitle-capture:"]){if(!self.transient||!self.legacy.subtitleTraceEnabled)return NO;[self.legacy recordSubtitleEvent:control track:self.legacy.selectedSubtitle at:0];return YES;}
    if([control isEqual:@"subtitle-layout-toggle"]){if(!self.transient||![@[@"rw:subtitle-native:preview",@"rw:subtitle-mkv:preview"]containsObject:self.videoID]||self.wantsPlay||self.presentedViewController)return NO;[self toggleControls:nil];return YES;}
    if([control isEqual:@"subtitle-dismiss-error"]){if(![self.presentedViewController.title isEqual:@"Subtitles unavailable"])return NO;[self dismissViewControllerAnimated:NO completion:nil];return YES;}
    if([control isEqual:@"subtitle-menu"]){if([self.presentedViewController.title isEqual:@"Subtitles"])return YES;if(self.presentedViewController)return NO;[self.captions sendActionsForControlEvents:UIControlEventTouchUpInside];return [self.presentedViewController.title isEqual:@"Subtitles"];}
    if([control hasPrefix:@"subtitle-choice:"]){
        NSString *title=[control substringFromIndex:[@"subtitle-choice:" length]];
        if([title isEqual:@"embedded-font-sample"]){if(!self.transient||![self.videoID isEqual:@"rw:font-captions:preview"]||![self.source[@"url"]isEqual:@"asset:subtitle-font-check.mkv"]||self.legacy.subtitleTracks.count!=1)return NO;title=self.legacy.subtitleTracks.firstObject[@"name"];}
        if([@[@"embedded-English",@"embedded-French"]containsObject:title]){NSString *language=[title isEqual:@"embedded-French"]?@"fr":@"en";title=nil;for(NSDictionary *track in self.legacy.subtitleTracks)if([RWSubtitles language:RWString(track[@"language"]).length?RWString(track[@"language"]):RWString(track[@"name"]) matches:language]){title=track[@"name"];break;}}
        void(^action)(void)=title?[self.exerciseSubtitleActions[title]copy]:nil;if(!action||![self.presentedViewController isKindOfClass:UIAlertController.class])return NO;
        [self dismissViewControllerAnimated:NO completion:action];return YES;
    }
    // Fixed owned clip only: model a native rate-zero refill while playback
    // intent remains true. This is a controlled fixture, not a natural stall.
    if([control isEqual:@"fixture-native-buffer-stop"]){
        RewindStore *store=RewindStore.shared;
        if(self.transient||![self.videoID isEqual:@"rw:offline-check"]||![self.exercisePersistenceProfile isEqual:@"rw-device-resume-check"]||![RWDeviceExercise ownsResumeProfile:store.profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]]||!self.player||self.legacy||!self.wantsPlay||self.nativeSeekPending||[self nativeBufferedAhead]<5)return NO;
        [self.player pause];return self.player.rate==0&&self.wantsPlay;
    }
    if([control isEqual:@"network-seek-600"]){if(!self.transient||![self.videoID isEqual:@"rw:cosmos"]||[self playbackDuration]<630)return NO;[self seek:600];return YES;}
    if([@[@"subtitle-text-seek:6",@"subtitle-text-seek:10"]containsObject:control]){if(!self.transient||![self.videoID isEqual:@"rw:subtitle-native:preview"]||!self.subtitleData.length)return NO;[self seek:[[[control componentsSeparatedByString:@":"]lastObject]doubleValue]];return YES;}
    if([control isEqual:@"subtitle-seek-boundary"]){[self seek:25.2];return YES;}
    BOOL pause=[control isEqual:@"pause"],resume=[control isEqual:@"resume"];if(!pause&&!resume)return NO;
    if(self.wantsPlay==pause)[self.playButton sendActionsForControlEvents:UIControlEventTouchUpInside];return self.wantsPlay==resume;
}
- (void)nextEpisode {
    if(self.closing||!self.mediaVerified||!self.onNextEpisode)return;
    if(!self.canPlayNextEpisode||!self.canPlayNextEpisode()){self.nextEpisodeButton.hidden=YES;self.nextEpisodeLabel=nil;return;}
    self.nextEpisodeRequested=YES;[self close];
}
- (void)close {
    if(self.closing)return;double closeBegan=NSProcessInfo.processInfo.systemUptime;self.closing=YES;[self.exerciseSubtitleTiming stop:@"closed"];[self.exerciseSubtitleLoadTask cancel];self.exerciseSubtitleActions=nil;self.exerciseAudioActions=nil;[self clearSubtitles];[self persist];[self collectMetrics];[self saveMetricSamples];[self.timer invalidate];self.timer=nil;[self stopCurrentSource];[[NSNotificationCenter defaultCenter]removeObserver:self];[UIApplication sharedApplication].idleTimerDisabled=NO;
    TorrentEngine *engine=self.engine;self.engine=nil;
    NSSet *pinned=[NSSet setWithArray:[RewindStore shared].state[@"keptDownloads"]?:@[]];
    // Queue cleanup before dismissal; a new player waits on the same serial queue.
    [engine retireWithPinned:pinned completion:^(NSDictionary *report){[[RewindStore shared]report:@{@"cache_cleanup":report}];}];
    void (^onClose)(void)=[(self.nextEpisodeRequested?self.onNextEpisode:self.onClose) copy];
    [self dismissViewControllerAnimated:!self.nextEpisodeRequested completion:^{[[RewindStore shared]report:@{@"player_close_ms":@((NSProcessInfo.processInfo.systemUptime-closeBegan)*1000)}];if(onClose)onClose();}];
}
- (void)dealloc {[self.subtitleTicker invalidate];[self.exerciseSubtitleTiming stop:@"deallocated"];[self.exerciseSubtitleLoadTask cancel];if(self.preparedEngine)[self.preparedEngine retireWithPinned:[NSSet setWithArray:[RewindStore shared].state[@"keptDownloads"]?:@[]] completion:nil]; [self.timer invalidate];[[NSNotificationCenter defaultCenter]removeObserver:self]; }
@end
