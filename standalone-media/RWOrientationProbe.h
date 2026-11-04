#import <UIKit/UIKit.h>
// One short-lived modal requests UIKit's real interface orientation. No device
// sensor injection, private API, rotation-lock preference or OS configuration.
@interface RWOrientationProbe : UIViewController
@property(nonatomic,assign) UIInterfaceOrientation target;
@end
@implementation RWOrientationProbe
- (UIInterfaceOrientationMask)supportedInterfaceOrientations{return (UIInterfaceOrientationMask)(1UL<<self.target);}
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation{return self.target;}
- (BOOL)shouldAutorotate{return YES;}
- (BOOL)prefersStatusBarHidden{return YES;}
- (void)loadView{self.view=[UIView new];self.view.backgroundColor=[UIColor colorWithRed:.055 green:.067 blue:.086 alpha:1];}
@end
