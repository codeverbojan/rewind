#import <UIKit/UIKit.h>
@class TorrentEngine, RWPlaybackLifetimeProbe;
@interface RewindPlayer : UIViewController
@property(nonatomic,copy) void (^onClose)(void);
@property(nonatomic,copy) NSString *nextEpisodeLabel;
@property(nonatomic,copy) BOOL (^canPlayNextEpisode)(void);
@property(nonatomic,copy) void (^onNextEpisode)(void);
@property(nonatomic,assign) BOOL reviewOnly;
@property(nonatomic,assign) double playRequestedAtUptime;
@property(nonatomic,strong) TorrentEngine *preparedEngine;
@property(nonatomic,copy) NSDictionary *preparationReport;
// Local USB exercise hooks. Enable before presentation to avoid history writes.
- (void)beginDeviceExercise;
- (BOOL)beginRecoveryExercise;
- (BOOL)beginLifecycleExercise:(NSString *)backend;
- (RWPlaybackLifetimeProbe *)deviceExerciseLifetimeProbe;
- (NSDictionary *)deviceExerciseTransportSnapshot;
- (void)beginSubtitleExercise;
- (BOOL)beginSubtitleLayoutOrientation:(UIInterfaceOrientation)orientation;
- (BOOL)beginResumeExercise;
- (BOOL)beginAudioExercise;
- (BOOL)beginLegacyFontExercise:(NSString *)font;
- (BOOL)beginEpisodeExercise;
- (BOOL)beginOfflineExercise;
- (BOOL)beginKidsExercise:(NSString *)run;
- (NSDictionary *)deviceExerciseSnapshot;
- (BOOL)deviceExerciseControl:(NSString *)control;
- (NSDictionary *)subtitleTimingEvidence;
- (instancetype)initWithMeta:(NSDictionary *)meta videoID:(NSString *)videoID candidates:(NSArray *)candidates quality:(NSInteger)quality resume:(double)resume;
- (instancetype)initWithMeta:(NSDictionary *)meta videoID:(NSString *)videoID source:(NSDictionary *)source resume:(double)resume;
@end
