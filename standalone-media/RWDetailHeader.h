#import <UIKit/UIKit.h>
@interface RWDetailHeader : UIView
@property(nonatomic,readonly) UIView *stage,*overlay;
@property(nonatomic,readonly) NSString *scope;
- (instancetype)initWithScope:(NSString *)scope;
- (void)updateMeta:(NSDictionary *)meta rating:(NSDictionary *)rating width:(CGFloat)width;
- (NSDictionary *)diagnostics;
@end
