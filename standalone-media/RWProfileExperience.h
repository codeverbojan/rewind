#import "RewindUI.h"

@interface RWProfileButton : RWButton
@property(nonatomic,strong) UIView *profileAvatar;
@property(nonatomic,copy) NSString *profileName;
@property(nonatomic,assign) BOOL cinematic;
@property(nonatomic,assign) BOOL kids;
@end

unsigned RWProfileAvatarColor(NSString *identifier, NSDictionary *profiles);
UIView *RWProfileAvatar(CGRect frame, unsigned color, BOOL kidsBadge);

// Owns only the lightweight profile entrance, short sound cues and outgoing
// profile view. No snapshots, network work or persistent user state. The one
// delayed handoff is bounded and cancelled whenever the stage is dismissed.
@interface RWProfileExperience : NSObject
@property(nonatomic,assign) BOOL soundEnabled;
@property(nonatomic,assign) BOOL cinematic;
@property(nonatomic,assign) BOOL diagnosticSampling;
- (void)prepare:(UIView *)page brand:(UIView *)brand heading:(UIView *)heading cards:(NSArray *)cards footer:(UIView *)footer;
- (void)presentIfActive;
- (void)replayIntroduction;
- (void)selectCard:(UIView *)card page:(UIView *)page host:(UIView *)host change:(void(^)(void))change destination:(UIView *(^)(void))destination;
- (void)keepVisible;
- (void)cancelTransition;
- (void)stop;
- (NSDictionary *)diagnostics;
@end
