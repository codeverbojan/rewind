#import <UIKit/UIKit.h>
// Uses the already bundled VLC engine only for verified, clear H.264/AAC previews.
// All public methods are main-thread calls; setup/teardown are serialized off-main.
@interface RWPreviewDecoder : NSObject
@property(nonatomic,readonly) UIView *surface;
@property(nonatomic,readonly) NSString *error;
@property(nonatomic,readonly) BOOL frameVisible,ended;
@property(nonatomic,readonly) double position;
- (instancetype)initWithSource:(NSDictionary *)source;
- (void)setVisible:(BOOL)visible muted:(BOOL)muted;
- (NSDictionary *)metrics;
- (void)stop;
@end
