#import <Foundation/Foundation.h>
// Only owned foreground diagnostics instantiate this bounded read-only probe.
// Never suspends a thread, changes registers or reads other processes.
@interface RWMainThreadStallProbe : NSObject
- (instancetype)initOnMainThread;
- (void)pulsePlaying:(BOOL)playing;
- (void)stop;
- (NSDictionary *)evidence;
@end
