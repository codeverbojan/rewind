#import "RewindUI.h"
// Uses the same recycling, feed window and footer as title cards.
@interface RWEntityCard : RWPoster
@property(nonatomic,readonly) NSDictionary *diagnostics;
@property(nonatomic,assign) BOOL compact;
@end
