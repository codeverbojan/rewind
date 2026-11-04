#import <Foundation/Foundation.h>
@interface UIColor:NSObject
+ (instancetype)blackColor;
@end
@interface UIView:NSObject
@property(nonatomic,strong) UIColor *backgroundColor;
@property(nonatomic) BOOL hidden,userInteractionEnabled;
@property(nonatomic) NSRect bounds;
@property(nonatomic) CGFloat alpha;
@property(nonatomic,readonly) UIView *window;
@property(nonatomic,readonly) NSArray *subviews;
- (void)removeFromSuperview;
@end
