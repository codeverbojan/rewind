#import <UIKit/UIKit.h>
@interface RWSubtitleLabel : UILabel
- (void)placeIn:(CGRect)bounds picture:(CGRect)picture controls:(BOOL)controls;
- (NSDictionary *)layoutDiagnostics;
@end
