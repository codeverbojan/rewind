#import <Foundation/Foundation.h>
// Main-run-loop caption-only clock; the owner supplies a weakly captured step.
@interface RWSubtitleTicker : NSObject
@property(nonatomic,readonly) BOOL running;
- (instancetype)initWithStep:(BOOL(^)(void))step;
- (instancetype)initWithStep:(BOOL(^)(void))step interval:(NSTimeInterval)interval;
- (void)invalidate;
@end
