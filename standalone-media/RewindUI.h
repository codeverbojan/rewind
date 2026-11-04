#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "RewindStore.h"
UIColor *RWColor(unsigned int rgb);
UIColor *RWLogoBackdrop(UIImage *image);
UILabel *RWLabel(NSString *text, CGFloat size, CGFloat weight, UIColor *color);
UIImage *RWIcon(NSString *name, CGFloat size, UIColor *color);
UIView *RWPanel(CGRect frame);
void RWTracking(UILabel *label, CGFloat spacing);
void RWShade(UIView *view, BOOL horizontal);
@interface RWButton : UIButton
@property(nonatomic,copy) void (^action)(void);
+ (instancetype)text:(NSString *)text action:(void(^)(void))action;
- (void)icon:(NSString *)name;
- (void)appearance:(BOOL)primary;
@end
// Quiet, native text tabs with full-size touch targets and selected semantics.
@interface RWTextTabs : UIControl
@property(nonatomic,assign) NSInteger selectedSegmentIndex;
- (instancetype)initWithItems:(NSArray *)items;
@end
@interface RWGradient : UIView
@end
@interface RWPoster : UIControl
@property(nonatomic,strong) NSDictionary *meta;
@property(nonatomic,copy) void(^action)(NSDictionary *meta);
@property(nonatomic,assign) BOOL defersContents;
@property(nonatomic,assign) BOOL hidesArtworkBadges;
@property(nonatomic,readonly) BOOL contentsPrepared;
- (BOOL)artworkVisible;
- (NSDictionary *)artworkState;
- (BOOL)prepareVisibleContents;
- (instancetype)initWithMeta:(NSDictionary *)meta width:(CGFloat)width landscape:(BOOL)landscape;
- (void)loadArtworkIfVisible;
- (void)cancelArtwork;
- (void)loadArtwork;
- (void)updateMeta:(NSDictionary *)meta;
@end
void RWAlert(UIViewController *controller, NSString *title, NSString *message);
void RWCapture(UIView *view, NSString *name);
