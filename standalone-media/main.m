#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import "TorrentEngine.h"
#import "TorrentLoader.h"

static NSString *ReportPath(void) {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0]
            stringByAppendingPathComponent:@"session-report.json"];
}

@interface LabController : UIViewController
@property(nonatomic,strong) UITextView *status;
@property(nonatomic,strong) NSMutableDictionary *report;
@property(nonatomic,strong) AVPlayerViewController *viewer;
@property(nonatomic,strong) id timeObserver;
@property(nonatomic,strong) TorrentEngine *engine;
@property(nonatomic,strong) TorrentLoader *loader;
@property(nonatomic,strong) UITextField *magnet;
@property(nonatomic,strong) UIButton *playTorrentButton;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,assign) BOOL playingTorrent;
@end

@implementation LabController
- (void)save {
    self.report[@"updated"] = @([[NSDate date] timeIntervalSince1970]);
    NSData *data = [NSJSONSerialization dataWithJSONObject:self.report options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:ReportPath() atomically:YES];
    NSDictionary *torrent = self.report[@"torrent"];
    self.status.text = [NSString stringWithFormat:
        @"%@\n%@\n\n%.1f / %.1f MB verified · %.0f KB/s\n%@ peers · %@ DHT nodes\n\n%@\n%@\n\n"
        @"Keep this app open while downloading. This first build plays H.264/AAC video in MP4 files, up to 512 MB.\n"
        @"The AAC test is Cosmos Laundromat, © 2015 Blender Foundation, Creative Commons.\n\n%@",
        torrent[@"state"] ?: @"Ready", torrent[@"video_name"] ?: @"Paste a magnet link or run the public test.",
        [torrent[@"video_verified_bytes"] doubleValue] / 1048576., [torrent[@"video_total_bytes"] doubleValue] / 1048576.,
        [torrent[@"download_bytes_per_second"] doubleValue] / 1024., torrent[@"peers"] ?: @0, torrent[@"dht_nodes"] ?: @0,
        torrent[@"error"] ?: @"", self.report[@"player_error"] ?: @"",
        [NSString stringWithFormat:@"Video played: %.1f seconds%@", [self.report[@"played_seconds"] doubleValue],
         [self.report[@"played_while_downloading"] boolValue] ? @" · streaming verified" : @""]];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"MiniStream Lab";
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.09 blue:0.14 alpha:1];
    self.engine = [TorrentEngine new];
    self.report = [@{@"build": @4, @"launched": @YES,
                     @"system": [[UIDevice currentDevice] systemVersion],
                     @"cpu_bits": @(sizeof(void *) * 8),
                     @"playback_started": @NO, @"played_seconds": @0,
                     @"finished": @NO} mutableCopy];
    UIButton *play = [UIButton buttonWithType:UIButtonTypeSystem];
    play.frame = CGRectMake(24, 90, 270, 44);
    play.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    [play setTitle:@"Play local video test" forState:UIControlStateNormal];
    play.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    play.backgroundColor = [UIColor colorWithRed:0.15 green:0.65 blue:0.57 alpha:1];
    [play setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    play.layer.cornerRadius = 10;
    [play addTarget:self action:@selector(playTest) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:play];
    self.magnet = [[UITextField alloc] initWithFrame:CGRectMake(24, 150, self.view.bounds.size.width - 48, 44)];
    self.magnet.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.magnet.backgroundColor = [UIColor whiteColor];
    self.magnet.borderStyle = UITextBorderStyleRoundedRect;
    self.magnet.placeholder = @"Paste magnet link";
    self.magnet.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.magnet.autocorrectionType = UITextAutocorrectionTypeNo;
    self.magnet.keyboardType = UIKeyboardTypeURL;
    [self.view addSubview:self.magnet];
    [self button:@"Start magnet" x:24 y:208 action:@selector(startCustom)];
    [self button:@"Test AAC movie" x:310 y:208 action:@selector(startPublic)];
    self.playTorrentButton = [self button:@"Play torrent video" x:24 y:266 action:@selector(playTorrent)];
    [self button:@"Pause download" x:310 y:266 action:@selector(pauseDownload)];
    self.status = [[UITextView alloc] initWithFrame:CGRectMake(20, 330, self.view.bounds.size.width - 40,
                                                             self.view.bounds.size.height - 350)];
    self.status.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.status.editable = NO;
    self.status.backgroundColor = [UIColor clearColor];
    self.status.textColor = [UIColor whiteColor];
    self.status.font = [UIFont systemFontOfSize:18];
    [self.view addSubview:self.status];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pauseDownload)
                                                 name:UIApplicationDidEnterBackgroundNotification object:nil];
    [self save];
}
- (UIButton *)button:(NSString *)title x:(CGFloat)x y:(CGFloat)y action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(x, y, 270, 44);
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [button setTitleColor:[UIColor colorWithRed:0.3 green:0.9 blue:0.78 alpha:1] forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    return button;
}
- (void)tick {
    self.report[@"torrent"] = [self.engine snapshot];
    self.playTorrentButton.enabled = self.engine.videoSize > 0;
    [self save];
}
- (void)startCustom { [self start:self.magnet.text publicTest:NO]; }
- (void)startPublic {
    [self start:@"magnet:?xt=urn:btih:c9e15763f722f23e98a29decdfae341b98d53056&dn=Cosmos%20Laundromat&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce" publicTest:YES];
}
- (void)start:(NSString *)magnet publicTest:(BOOL)test {
    [self.view endEditing:YES];
    [self cleanupPlayer];
    NSString *error = nil;
    BOOL ok = [self.engine startMagnet:[magnet stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
                           publicTest:test error:&error];
    if (!ok) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cannot start download" message:error preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        self.report[@"test_source"] = test ? @"WebTorrent public Cosmos Laundromat magnet (H.264 / AAC stereo)" : @"User-supplied magnet";
        self.report[@"played_seconds"] = @0;
        self.report[@"playback_started"] = @NO;
        self.report[@"finished"] = @NO;
        self.report[@"played_while_downloading"] = @NO;
        [self.report removeObjectForKey:@"player_error"];
        [UIApplication sharedApplication].idleTimerDisabled = YES;
    }
    [self tick];
}
- (void)pauseDownload {
    [self.engine pause];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self tick];
}
- (void)playTorrent {
    if (self.engine.videoSize <= 0) return;
    [self cleanupPlayer];
    self.playingTorrent = YES;
    self.loader = [[TorrentLoader alloc] initWithEngine:self.engine];
    [self playItem:[self.loader playerItem]];
}
- (void)playTest {
    if (self.viewer && self.viewer.presentingViewController) return;
    [self cleanupPlayer];
    self.playingTorrent = NO;
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"playback-test" withExtension:@"mp4"];
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    [self playItem:item];
}
- (void)playItem:(AVPlayerItem *)item {
    self.viewer = [AVPlayerViewController new];
    self.viewer.player = [AVPlayer playerWithPlayerItem:item];
    self.viewer.player.muted = NO;
    self.viewer.player.volume = 1.0;
    NSError *audioError = nil;
    BOOL audioReady = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&audioError];
    if (audioReady) audioReady = [[AVAudioSession sharedInstance] setActive:YES error:&audioError];
    self.report[@"audio_session_ready"] = @(audioReady);
    if (audioError) self.report[@"audio_session_error"] = audioError.localizedDescription;
    [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finished:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification object:item];
    __weak LabController *weakSelf = self;
    self.timeObserver = [self.viewer.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1)
                 queue:dispatch_get_main_queue() usingBlock:^(CMTime t) {
        LabController *strongSelf = weakSelf;
        if (!strongSelf) return;
        double seconds = CMTimeGetSeconds(t);
        if (isfinite(seconds)) {
            strongSelf.report[@"played_seconds"] = @(seconds);
            strongSelf.report[@"playback_started"] = @(seconds > 0.1);
            strongSelf.report[@"player_rate"] = @(strongSelf.viewer.player.rate);
            strongSelf.report[@"output_volume"] = @([AVAudioSession sharedInstance].outputVolume);
            if (strongSelf.playingTorrent && seconds > 0.5 &&
                ![strongSelf.report[@"torrent"][@"video_complete"] boolValue]) {
                strongSelf.report[@"played_while_downloading"] = @YES;
            }
            [strongSelf save];
        }
    }];
    [self presentViewController:self.viewer animated:YES completion:^{
        [weakSelf.viewer.player play];
    }];
}
- (void)selectCompatibleAudio:(AVPlayerItem *)item {
    NSMutableArray *tracks = [NSMutableArray new];
    AVPlayerItemTrack *chosen = nil;
    int best = -1;
    for (AVPlayerItemTrack *track in item.tracks) {
        AVAssetTrack *asset = track.assetTrack;
        if (![asset.mediaType isEqualToString:AVMediaTypeAudio]) continue;
        NSMutableArray *codecs = [NSMutableArray new];
        int score = 0;
        for (id raw in asset.formatDescriptions) {
            FourCharCode code = CMFormatDescriptionGetMediaSubType((__bridge CMFormatDescriptionRef)raw);
            char chars[5] = {(char)(code >> 24), (char)(code >> 16), (char)(code >> 8), (char)code, 0};
            NSString *name = [[NSString alloc] initWithBytes:chars length:4 encoding:NSASCIIStringEncoding];
            [codecs addObject:name ?: [NSString stringWithFormat:@"%u", (unsigned int)code]];
            if (code == 'aac ') score = 30;
            else if (code == '.mp3') score = MAX(score, 20);
            else if (code != 'ac-3' && code != 'ec-3') score = MAX(score, 10);
        }
        [tracks addObject:@{@"track_id": @(asset.trackID), @"codecs": codecs,
                            @"playable": @(asset.playable), @"initially_enabled": @(track.enabled)}];
        if (asset.playable && score > best) { best = score; chosen = track; }
    }
    AVMediaSelectionGroup *group = [item.asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicAudible];
    if (group) {
        AVMediaSelectionOption *selection = nil;
        int optionScore = -1;
        for (AVMediaSelectionOption *option in group.options) {
            if (!option.playable) continue;
            int score = 0;
            if ([option.mediaSubTypes containsObject:@((unsigned int)'aac ')]) score = 30;
            else if ([option.mediaSubTypes containsObject:@((unsigned int)'.mp3')]) score = 20;
            if (score > optionScore) { optionScore = score; selection = option; }
        }
        if (selection) {
            self.viewer.player.appliesMediaSelectionCriteriaAutomatically = NO;
            [item selectMediaOption:selection inMediaSelectionGroup:group];
            self.report[@"selected_audio_option"] = selection.displayName;
        }
    }
    if (chosen) {
        for (AVPlayerItemTrack *track in item.tracks)
            if ([track.assetTrack.mediaType isEqualToString:AVMediaTypeAudio]) track.enabled = track == chosen;
        self.report[@"selected_audio_track"] = @(chosen.assetTrack.trackID);
    }
    self.report[@"audio_tracks"] = tracks;
    self.report[@"native_audio_available"] = @(chosen != nil);
    NSMutableArray *outputs = [NSMutableArray new];
    for (AVAudioSessionPortDescription *port in [AVAudioSession sharedInstance].currentRoute.outputs)
        [outputs addObject:port.portType];
    self.report[@"audio_outputs"] = outputs;
    if (!chosen && tracks.count) self.report[@"player_error"] = @"This file's audio is not supported by the iPad's native player.";
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                       change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItem *item = object;
        self.report[@"player_status"] = @(item.status);
        if (item.status == AVPlayerItemStatusReadyToPlay) [self selectCompatibleAudio:item];
        if (item.error) self.report[@"player_error"] = item.error.localizedDescription;
        [self save];
    }
}
- (void)finished:(NSNotification *)note {
    self.report[@"finished"] = @YES;
    self.report[@"played_seconds"] = @(CMTimeGetSeconds(self.viewer.player.currentItem.duration));
    [self save];
    [self dismissViewControllerAnimated:YES completion:nil];
    [self cleanupPlayer];
}
- (void)cleanupPlayer {
    if (!self.viewer) return;
    [self.viewer.player pause];
    if (self.timeObserver) {
        [self.viewer.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
    [self.viewer.player.currentItem removeObserver:self forKeyPath:@"status"];
    [[NSNotificationCenter defaultCenter] removeObserver:self
        name:AVPlayerItemDidPlayToEndTimeNotification object:self.viewer.player.currentItem];
    self.viewer = nil;
    [self.loader stop]; self.loader = nil;
}
- (void)dealloc {
    [self cleanupPlayer];
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[LabController new]];
    nav.navigationBar.barStyle = UIBarStyleBlack;
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
