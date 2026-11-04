#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
// Production navigation method with ownership/action facades. Real UIKit
// rendering and latency require the physical-device recipe separately.
static NSUInteger ButtonCreates,IconCreates,FontCreates;
enum {UIControlStateNormal=0,UIAccessibilityTraitSelected=2};
static const CGFloat UIFontWeightRegular=0,UIFontWeightSemibold=.3,UIFontWeightHeavy=.6;
@interface Layer:NSObject
@property CGFloat cornerRadius;
@end
@implementation Layer @end
@interface UIView:NSObject
@property CGRect frame;
@property(readonly) CGRect bounds;
@property NSInteger tag;
@property BOOL hidden;
@property NSUInteger accessibilityTraits;
@property(strong) NSString *accessibilityLabel;
@property(strong) id backgroundColor;
@property(strong) Layer *layer;
@property(strong) NSMutableArray *subviews;
@property(weak) UIView *superview;
@property(copy) void(^onMount)(UIView *);
- (instancetype)initWithFrame:(CGRect)frame;
- (void)addSubview:(UIView *)view;
- (void)removeFromSuperview;
- (void)bringSubviewToFront:(UIView *)view;
- (UIView *)viewWithTag:(NSInteger)tag;
@end
@implementation UIView
- (CGRect)bounds{return CGRectMake(0,0,self.frame.size.width,self.frame.size.height);}
- (instancetype)init{return [self initWithFrame:CGRectZero];}
- (instancetype)initWithFrame:(CGRect)frame{if((self=[super init])){_frame=frame;_subviews=[NSMutableArray new];_layer=[Layer new];}return self;}
- (void)addSubview:(UIView *)view{[view removeFromSuperview];if(self.onMount)self.onMount(view);[_subviews addObject:view];view.superview=self;}
- (void)removeFromSuperview{[self.superview.subviews removeObjectIdenticalTo:self];self.superview=nil;}
- (void)bringSubviewToFront:(UIView *)view{if(view.superview==self){[_subviews removeObjectIdenticalTo:view];[_subviews addObject:view];}}
- (UIView *)viewWithTag:(NSInteger)tag{if(self.tag==tag)return self;for(UIView *v in _subviews){UIView *found=[v viewWithTag:tag];if(found)return found;}return nil;}
@end
@interface UIColor:NSObject
+ (id)clearColor;
@end
@implementation UIColor
+ (id)clearColor{return @0;}
@end
// Native avatar rendering is covered by the physical profile recipe. These
// facades keep this test focused on navigation ownership and control reuse.
static id RWProfileAvatarColor(NSString *key,NSDictionary *profiles){return key;}
static UIView *RWProfileAvatar(CGRect frame,id color,BOOL kids){UIView *v=[[UIView alloc]initWithFrame:frame];v.backgroundColor=color;return v;}
@interface UILabel:UIView
@property(strong) NSString *text;
@property(strong) id font;
@end
@implementation UILabel @end
@interface UIImageView:UIView
- (instancetype)initWithImage:(id)image;
@end
@implementation UIImageView
- (instancetype)initWithImage:(id)image{return [self init];}
@end
@interface UIFont:NSObject
+ (id)systemFontOfSize:(CGFloat)size weight:(CGFloat)weight;
@end
@implementation UIFont
+ (id)systemFontOfSize:(CGFloat)size weight:(CGFloat)weight{FontCreates++;return @(weight);}
@end
static id RWColor(unsigned value){return @(value);}
static id RWIcon(NSString *name,CGFloat size,id color){IconCreates++;return name;}
static UILabel *RWLabel(NSString *text,CGFloat size,CGFloat weight,id color){UILabel *v=[UILabel new];v.text=text;return v;}
static void RWTracking(UILabel *label,CGFloat spacing){}
static NSString *RWString(id value){return [value isKindOfClass:NSString.class]?value:@"";}
@interface RWButton:UIView
@property(copy) void(^action)(void);
@property(strong) UILabel *titleLabel;
@property(strong) id color;
+ (instancetype)text:(NSString *)text action:(void(^)(void))action;
- (void)icon:(NSString *)name;
- (void)setTitleColor:(id)color forState:(NSUInteger)state;
@end
@implementation RWButton
+ (instancetype)text:(NSString *)text action:(void(^)(void))action{ButtonCreates++;RWButton *b=[self new];b.titleLabel=[UILabel new];b.titleLabel.text=text;b.action=action;b.accessibilityTraits=1;return b;}
- (void)icon:(NSString *)name{RWIcon(name,20,nil);}
- (void)setTitleColor:(id)color forState:(NSUInteger)state{self.color=color;}
@end
@interface RewindStore:NSObject
@property(strong) NSMutableDictionary *state,*profile;
@property(strong) NSDictionary *discoveryHome;
@property BOOL restricted;
+ (instancetype)shared;
@end
@implementation RewindStore
+ (instancetype)shared{static RewindStore *s;static dispatch_once_t once;dispatch_once(&once,^{s=[self new];s.state=[@{@"activeProfile":@"main"}mutableCopy];s.profile=[@{@"name":@"Main"}mutableCopy];s.discoveryHome=@{@"generation":@1};});return s;}
@end
@interface RWUIProbe:NSObject
+ (instancetype)shared;
- (void)work:(NSString *)name started:(double)started;
@end
@implementation RWUIProbe
+ (instancetype)shared{static RWUIProbe *p;static dispatch_once_t once;dispatch_once(&once,^{p=[self new];});return p;}
- (void)work:(NSString *)name started:(double)started{}
@end
@interface RewindController:NSObject
@property(strong) UIView *view,*sidebar,*menuAnchor;
@property(strong) NSDictionary *navigationState,*homePlan;
@property(strong) NSArray *navigationTabs;
@property(strong) RWButton *navigationBrand,*navigationSearch,*navigationProfile;
@property(strong) NSMutableArray *destinationStack;
@property(strong) NSString *filter,*page,*menuProfile;
@property NSUInteger resets;
- (CGFloat)width;
- (void)resetBrowse;
- (void)go:(NSString *)page;
- (void)profileMenu:(UIView *)anchor;
@end
@implementation RewindController
- (CGFloat)width{return self.view.frame.size.width;}
- (void)resetBrowse{self.resets++;}
- (void)go:(NSString *)page{self.page=page;}
- (void)profileMenu:(UIView *)anchor{self.menuAnchor=anchor;self.menuProfile=[RewindStore shared].state[@"activeProfile"];}
#include "../RewindNavigation.inc"
@end
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
int main(){@autoreleasepool{
    RewindController *c=[RewindController new];c.view=[[UIView alloc]initWithFrame:CGRectMake(0,0,1024,768)];c.page=@"Home";c.filter=@"All";c.destinationStack=[NSMutableArray new];[c navigation];UIView *bar=c.sidebar;NSArray *tabs=[c.navigationTabs copy];
    CHECK(ButtonCreates==8&&IconCreates==2&&bar.subviews.count==8);CHECK(c.view.subviews.count==1&&bar.superview==c.view);CHECK(![tabs[0]viewWithTag:7101].hidden);
    NSUInteger fonts=FontCreates;[c navigation];CHECK(FontCreates==fonts&&ButtonCreates==8&&IconCreates==2);
    for(int i=0;i<20;i++){c.page=i%2?@"Home":@"Search";[c navigation];CHECK(c.sidebar==bar&&[tabs isEqual:c.navigationTabs]&&c.view.subviews.count==1);CHECK([tabs[0]viewWithTag:7101].hidden==!(i%2));}
    CHECK(ButtonCreates==8&&IconCreates==2);
    // Reused closures must use the current plan, destination stack and profile.
    for(NSUInteger i=0;i<5;i++){[c.destinationStack addObject:@1];[RewindStore shared].discoveryHome=@{@"generation":@(i+2)};RWButton *button=tabs[i];button.action();CHECK(c.destinationStack.count==0);
        CHECK([c.page isEqual:i<3?@"Home":i==3?@"Upcoming":@"My List"]);if(i<3)CHECK(c.homePlan==[RewindStore shared].discoveryHome);[c navigation];
        for(NSUInteger j=0;j<5;j++){RWButton *b=tabs[j];CHECK([b viewWithTag:7101].hidden==(j!=i));CHECK((b.accessibilityTraits&1)==1);CHECK(!!(b.accessibilityTraits&UIAccessibilityTraitSelected)==(j==i));}
    }
    [c.destinationStack addObject:@1];c.navigationSearch.action();CHECK([c.page isEqual:@"Search"]&&!c.destinationStack.count);[c navigation];for(RWButton *b in tabs)CHECK([b viewWithTag:7101].hidden);
    c.filter=@"Series";NSUInteger resets=c.resets;c.navigationBrand.action();CHECK([c.page isEqual:@"Home"]&&[c.filter isEqual:@"All"]&&c.resets==resets+1);
    c.view.frame=CGRectMake(0,0,768,1024);[c navigation];CHECK(c.sidebar==bar&&bar.frame.size.width==768);CHECK(((UIView *)tabs[0]).frame.origin.x==184&&c.navigationSearch.frame.origin.x==638&&c.navigationProfile.frame.origin.x==694);
    c.view.frame=CGRectMake(0,0,1024,768);[c navigation];CHECK(((UIView *)tabs[0]).frame.origin.x==226&&c.navigationProfile.frame.origin.x==950);
    [bar removeFromSuperview];[RewindStore shared].state[@"activeProfile"]=@"kids";[RewindStore shared].profile[@"name"]=@"Child";[RewindStore shared].restricted=YES;
    __block BOOL freshAtMount=NO;__weak RewindController *weak=c;c.view.onMount=^(UIView *v){freshAtMount=[weak.navigationProfile.accessibilityLabel isEqual:@"Profile, Child"]&&[weak.navigationProfile.backgroundColor isEqual:UIColor.clearColor]&&[[weak.navigationProfile viewWithTag:9100].backgroundColor isEqual:@"kids"];};[c navigation];CHECK(freshAtMount&&bar.superview==c.view);c.navigationProfile.action();CHECK(c.menuAnchor==c.navigationProfile&&[c.menuProfile isEqual:@"kids"]);
    [RewindStore shared].profile[@"name"]=@"Renamed";[c navigation];CHECK([c.navigationProfile.accessibilityLabel isEqual:@"Profile, Renamed"]);CHECK(ButtonCreates==8&&IconCreates==2);
    c.menuAnchor=nil;c.view.onMount=nil;__weak RewindController *released=c;c=nil;CHECK(released==nil); // No action/controller retain cycle.
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
