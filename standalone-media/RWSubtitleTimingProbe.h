#import <UIKit/UIKit.h>
// One admitted diagnostic run only. Reads the label; never refreshes captions.
@interface RWSubtitleTimingProbe : NSObject
- (instancetype)initWithSample:(NSDictionary *(^)(void))sample;
- (instancetype)initWithSample:(NSDictionary *(^)(void))sample watchMainThread:(BOOL)watch;
- (void)recordAssignment:(NSString *)text position:(double)position;
- (void)stop:(NSString *)reason;
- (NSDictionary *)summary;
- (NSDictionary *)evidence;
@end
