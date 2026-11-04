#import <UIKit/UIKit.h>
@class TorrentEngine;
// Isolated libVLC path. All public calls are on the main thread; media reads
// happen on VLC's worker and only verified pieces cross from the torrent engine.
@interface RWLegacyPlayer : NSObject
@property(nonatomic,readonly) UIView *surface;
@property(nonatomic,readonly) NSString *error;
@property(nonatomic,readonly) NSDictionary *probe;
@property(nonatomic,readonly) NSDictionary *mediaRejectionAssessment;
@property(nonatomic,readonly) BOOL ready;
@property(nonatomic,readonly) BOOL frameVisible;
@property(nonatomic,readonly) BOOL ended;
@property(nonatomic,readonly) BOOL seekable;
@property(nonatomic,readonly) double position;
@property(nonatomic,readonly) double subtitlePosition;
@property(nonatomic,readonly) BOOL captionBuffering;
@property(nonatomic,readonly) double duration;
@property(nonatomic,readonly) float rate;
@property(nonatomic) BOOL subtitleTraceEnabled;
@property(nonatomic) BOOL startupTraceEnabled;
@property(nonatomic,copy) NSDictionary *audioPreference;
@property(nonatomic,readonly) NSDictionary *audioSelection;
@property(nonatomic,copy) void (^audioChoiceConfirmed)(NSDictionary *track);
- (void)recordSubtitleEvent:(NSString *)event track:(int)track at:(double)eventTime;
- (BOOL)beginPresentationTrace:(NSString *)directory;
- (BOOL)beginFrameClockTrace;
- (NSDictionary *)frameClockEvidence;
- (void)captureSubtitleFrame:(NSString *)path done:(void(^)(BOOL success))done;
- (instancetype)initWithEngine:(TorrentEngine *)engine size:(int64_t)size file:(NSString *)file quality:(NSInteger)quality;
// Fixed diagnostic override; normal initializer retains the vendor default.
- (instancetype)initWithEngine:(TorrentEngine *)engine size:(int64_t)size file:(NSString *)file quality:(NSInteger)quality diagnosticFont:(NSString *)font;
- (void)poll;
- (void)play;
- (void)pause;
- (void)seek:(double)seconds;
- (NSArray *)audioTracks;
- (NSArray *)subtitleTracks;
- (BOOL)selectAudio:(int)identifier;
- (int)selectedAudio;
- (void)selectSubtitle:(int)identifier;
- (int)selectedSubtitle;
- (void)setSubtitleDelay:(double)seconds;
- (double)subtitleDelay;
- (NSDictionary *)metrics;
- (void)stop;
@end
