#import <Foundation/Foundation.h>
// A caption-only estimate between VLC's 250ms interface-clock updates.
// All methods may be called on either the VLC event thread or the main thread.
@interface RWCaptionClock : NSObject
@property(nonatomic,readonly) BOOL buffering;
- (void)setRequestedPlaying:(BOOL)playing;
- (void)setRunning:(BOOL)running;
- (void)setBuffering:(BOOL)buffering;
- (void)invalidate;
- (void)sample:(double)position uptime:(double)uptime;
- (double)positionForReported:(double)reported uptime:(double)uptime eligible:(BOOL)eligible;
- (NSDictionary *)diagnostics;
@end
