#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "../RWDiscoveryMetadataPolicy.h"

// Execute the production controller residency methods with small view facades.
// This verifies ownership, context and mount ordering, not UIKit performance.
@interface TestView:NSObject
@property(nonatomic,assign) CGRect frame,bounds;
@property(nonatomic,assign) CGSize contentSize;
@property(nonatomic,assign) BOOL scrollEnabled,mounted;
@property(nonatomic,strong) NSString *accessibilityIdentifier;
@property(nonatomic,strong) NSMutableArray *children;
@property(nonatomic,copy) void(^onMount)(id);
- (void)addSubview:(TestView *)view;
@end
@implementation TestView
- (instancetype)init {if((self=[super init]))_children=[NSMutableArray new];return self;}
- (void)addSubview:(TestView *)view {if(self.onMount)self.onMount(view);[_children addObject:view];view.mounted=YES;}
@end
@interface RWHomeView:TestView
@property(nonatomic,strong) NSString *scope;
@property(nonatomic,assign) NSUInteger parks,loads,anchorSaves;
@property(nonatomic,assign) CGFloat offset;
@property(nonatomic,strong) NSArray *cards;
- (void)saveVisibleAnchors;
- (void)parkForReuse;
- (void)loadVisibleArtwork;
- (NSDictionary *)diagnostics;
@end
@implementation RWHomeView
- (void)saveVisibleAnchors {_anchorSaves++;}
- (void)parkForReuse {[self saveVisibleAnchors];_parks++;self.mounted=NO;}
- (void)loadVisibleArtwork {_loads++;}
- (NSDictionary *)diagnostics {return @{ @"parks":@(_parks) };}
@end
@interface RewindStore:NSObject
@property(nonatomic,strong) NSMutableDictionary *state,*profile;
+ (instancetype)shared;
- (void)report:(NSDictionary *)value;
@end
@implementation RewindStore
+ (instancetype)shared {static RewindStore *value;static dispatch_once_t once;dispatch_once(&once,^{value=[self new];value.state=[@{@"activeProfile":@"main"}mutableCopy];value.profile=[@{@"maxAge":@(-1)}mutableCopy];});return value;}
- (void)report:(NSDictionary *)value {}
@end
@interface HomeHarness:NSObject
@property(nonatomic,strong) RWHomeView *homeView,*parkedHomeView;
@property(nonatomic,strong) NSDictionary *homeViewContext,*parkedHomeContext,*homeHeaderRecord;
@property(nonatomic,strong) NSString *page,*filter,*homeScope;
@property(nonatomic,strong) TestView *content;
@property(nonatomic,assign) BOOL reviewMode,updatedWhileDetached;
@property(nonatomic,assign) double discoveryMemoryCooldown;
@property(nonatomic,assign) NSUInteger updates,visibleReports;
@property(nonatomic,strong) NSArray *allowedCards;
- (void)updateHomeList;
- (void)recordVisibleDiscovery;
- (void)installHome;
@end
@implementation HomeHarness
#include "../RewindHomeResidency.inc"
- (instancetype)init {if((self=[super init])){_filter=@"All";_page=@"Home";_content=[TestView new];_content.bounds=CGRectMake(0,0,768,940);_content.accessibilityIdentifier=@"HomeAll";_allowedCards=@[@"current"];}return self;}
- (void)installHome {self.homeView=[RWHomeView new];self.homeView.frame=self.content.bounds;self.homeView.scope=@"main:All";self.homeViewContext=[self currentHomeContext];self.homeView.cards=@[@"expired",@"hidden"];self.homeView.offset=380;self.homeView.mounted=YES;self.homeHeaderRecord=@{@"old":@YES};self.content.accessibilityIdentifier=@"HomeAll";}
- (void)updateHomeList {_updates++;_updatedWhileDetached=!self.homeView.mounted;self.homeView.cards=self.allowedCards;}
- (void)recordVisibleDiscovery {if(self.homeView.mounted)_visibleReports++;}
@end
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static HomeHarness *Park(void){HomeHarness *h=[HomeHarness new];[h installHome];h.page=@"Search";[h parkCurrentHome];h.homeView=nil;h.homeViewContext=nil;h.homeHeaderRecord=nil;h.content.accessibilityIdentifier=@"Search";return h;}
int main(){@autoreleasepool{
    HomeHarness *h=Park();RWHomeView *original=h.parkedHomeView;
    CHECK(original&&original.parks==1&&!original.mounted);CHECK(h.updates==0&&h.visibleReports==0&&original.loads==0);
    __block BOOL freshBeforeMount=NO;h.content.onMount=^(RWHomeView *view){freshBeforeMount=[view.cards isEqual:@[@"current"]]&&!view.mounted;};h.page=@"Home";
    CHECK([h restoreParkedHome]);CHECK(h.homeView==original&&!h.parkedHomeView&&!h.parkedHomeContext);CHECK(h.updatedWhileDetached&&freshBeforeMount);CHECK(h.homeView.offset==380);CHECK(h.updates==1&&h.visibleReports==1&&h.homeView.loads==1);CHECK(!h.homeHeaderRecord&&!h.content.scrollEnabled);CHECK(![h restoreParkedHome]);
    // Repeated navigation has one owner and always revalidates live cards.
    for(int i=0;i<20;i++){h.content.accessibilityIdentifier=@"HomeAll";h.page=@"Details";[h parkCurrentHome];h.homeView=nil;h.homeViewContext=nil;h.page=@"Home";CHECK([h restoreParkedHome]);CHECK(h.homeView==original&&!h.parkedHomeView);}
    CHECK(original.parks==21&&h.updates==21);CHECK(original.anchorSaves==21);
    h=Park();h.page=@"Home";h.filter=@"Movies";CHECK(![h restoreParkedHome]&&h.parkedHomeView);h.filter=@"All";CHECK([h restoreParkedHome]);
    // Profile and age changes must not mount even a single old frame.
    h=Park();[RewindStore shared].state[@"activeProfile"]=@"kids";[RewindStore shared].profile[@"maxAge"]=@7;h.page=@"Home";CHECK(![h restoreParkedHome]&&!h.parkedHomeView&&h.updates==0&&h.content.children.count==0);
    [RewindStore shared].state[@"activeProfile"]=@"main";[RewindStore shared].profile[@"maxAge"]=@(-1);
    h=Park();[RewindStore shared].profile[@"maxAge"]=@12;CHECK(![h restoreParkedHome]&&!h.parkedHomeView);[RewindStore shared].profile[@"maxAge"]=@(-1);
    h=Park();[RewindStore shared].profile[@"discoveryPreferences"]=@{@"languageMode":@"all"};CHECK(![h restoreParkedHome]&&!h.parkedHomeView);[[RewindStore shared].profile removeObjectForKey:@"discoveryPreferences"];
    h=Park();h.page=@"Profiles";[h parkCurrentHome];CHECK(!h.parkedHomeView);CHECK(!h.homeView||h.homeView.anchorSaves==1);
    h=Park();h.content.bounds=CGRectMake(0,0,1024,684);CHECK(![h restoreParkedHome]&&!h.parkedHomeView);
    h=Park();h.reviewMode=YES;CHECK(![h restoreParkedHome]&&!h.parkedHomeView);
    h=Park();h.discoveryMemoryCooldown=NSProcessInfo.processInfo.systemUptime+30;CHECK(![h restoreParkedHome]&&!h.parkedHomeView);
    h=Park();[h discardParkedHome];CHECK(!h.parkedHomeView&&!h.parkedHomeContext&&! [h restoreParkedHome]);
    h=[HomeHarness new];[h installHome];[h parkCurrentHome];CHECK(!h.parkedHomeView);CHECK(h.homeView.anchorSaves==1); // same-screen rebuild
    h=[HomeHarness new];[h installHome];h.content.accessibilityIdentifier=@"HomeMovies";h.page=@"Search";[h parkCurrentHome];CHECK(!h.parkedHomeView);CHECK(h.homeView.anchorSaves==1);
    h=[HomeHarness new];[h installHome];h.page=@"Profiles";[h parkCurrentHome];CHECK(!h.parkedHomeView);CHECK(!h.homeView||h.homeView.anchorSaves==1);
    h=[HomeHarness new];[h installHome];h.page=@"Search";h.reviewMode=YES;[h parkCurrentHome];CHECK(!h.parkedHomeView);CHECK(h.homeView.anchorSaves==0);
    h=[HomeHarness new];[h installHome];h.page=@"Search";h.discoveryMemoryCooldown=NSProcessInfo.processInfo.systemUptime+30;[h parkCurrentHome];CHECK(!h.parkedHomeView);CHECK(h.homeView.anchorSaves==1);
    // Replacing the single cached viewport releases the prior one.
    h=Park();__weak RWHomeView *retired=h.parkedHomeView;[h installHome];h.page=@"Details";[h parkCurrentHome];CHECK(!retired&&h.parkedHomeView==h.homeView);
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
