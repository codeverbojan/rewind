#import <UIKit/UIKit.h>
@interface RWTrailerView : UIView
@property(nonatomic,copy) void (^onStore)(NSString *url);
@property(nonatomic,copy) void (^onState)(NSString *state);
@property(nonatomic,readonly) BOOL embeddedVisible;
@property(nonatomic,readonly) BOOL usingVideoNetwork;
@property(nonatomic,copy) void (^onEmbeddedVisibility)(BOOL visible);
- (void)load:(NSDictionary *)source;
- (void)setVisible:(BOOL)visible;
- (void)playWithSound;
- (BOOL)canPlay;
- (NSDictionary *)diagnostics;
- (void)stop;
@end
