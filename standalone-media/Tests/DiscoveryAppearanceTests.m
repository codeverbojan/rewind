#import <Foundation/Foundation.h>
static int checks,failures;
#define C(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL %d %s\n",__LINE__,#__VA_ARGS__);}}while(0)
enum {UIApplicationStateActive,UIApplicationStateBackground};
@interface UIApplication:NSObject
@property NSInteger applicationState;
+ (instancetype)sharedApplication;
@end
@implementation UIApplication
+ (instancetype)sharedApplication{static UIApplication *app; if(!app)app=[self new];return app;}
@end
@interface RewindStore:NSObject
@property BOOL paused,upcoming,home;
@property NSString *homeType;
@property NSUInteger resumed;
+ (instancetype)shared;
- (void)setArtworkVisible:(BOOL)b inView:(id)view;
- (void)setDiscoveryPaused:(BOOL)b;
- (BOOL)setHomeAvailabilityVisible:(BOOL)b mediaType:(NSString *)type;
- (void)setUpcomingVisible:(BOOL)b;
@end
@implementation RewindStore
+ (instancetype)shared{static RewindStore *s;if(!s)s=[self new];return s;}
- (void)setArtworkVisible:(BOOL)b inView:(id)view{}
- (void)setDiscoveryPaused:(BOOL)b{if(self.paused&&!b)self.resumed++;self.paused=b;}
- (BOOL)setHomeAvailabilityVisible:(BOOL)b mediaType:(NSString *)type{BOOL changed=self.home!=b||![(self.homeType?:@"")isEqual:type?:@""];self.home=b;self.homeType=type;return changed;}
- (void)setUpcomingVisible:(BOOL)b{self.upcoming=b;}
@end
@interface Preview:NSObject
@property BOOL usingVideoNetwork;
@property NSString *state;
@end
@implementation Preview @end
@interface Feeds:NSObject
@property NSUInteger cancelled;
- (void)cancel;
@end
@implementation Feeds
- (void)cancel{self.cancelled++;}
@end
@interface ControllerBase:NSObject
- (void)viewDidAppear:(BOOL)b;
@end
@implementation ControllerBase
- (void)viewDidAppear:(BOOL)b{}
@end
@interface Controller:ControllerBase
@property BOOL reviewMode,homeRefreshStarted,filtered;
@property double discoveryMemoryCooldown;
@property NSString *page,*filter;
@property id presentedViewController,view;
@property Preview *preview,*previewSession;
@property Feeds *homeFeeds;
- (BOOL)hasBrowseFilters;
- (void)presentProfileEntrance;
- (void)restoreMyListPosition;
- (void)processPendingReminder;
- (void)applyPendingDetails;
- (void)refreshDownloads;
- (void)prepareCurrentTitle;
- (void)loadVisiblePosters;
- (void)schedulePreview:(BOOL)b;
- (void)syncDiscoveryActivity;
@end
@implementation Controller
- (BOOL)hasBrowseFilters{return self.filtered;}
- (void)presentProfileEntrance{}
- (void)restoreMyListPosition{}
- (void)processPendingReminder{}
- (void)applyPendingDetails{}
- (void)refreshDownloads{}
- (void)prepareCurrentTitle{}
- (void)loadVisiblePosters{}
- (void)schedulePreview:(BOOL)b{}
#include "discovery-appearance-under-test.inc"
@end
int main(){@autoreleasepool{
 Controller *c=[Controller new];c.homeFeeds=[Feeds new];c.filter=@"All";RewindStore *s=RewindStore.shared;
 for(NSString *page in @[@"Entity",@"Explore",@"Upcoming",@"Home",@"Search"]){
  c.page=page;c.presentedViewController=[NSObject new];[c syncDiscoveryActivity];C(s.paused);
  c.presentedViewController=nil;NSUInteger resumed=s.resumed;[c viewDidAppear:NO];C(!s.paused);C(s.resumed==resumed+1);C(s.upcoming==[page isEqual:@"Upcoming"]);
  [c viewDidAppear:NO];C(s.resumed==resumed+1);
 }
 c.page=@"Home";c.filter=@"All";[c syncDiscoveryActivity];c.homeRefreshStarted=YES;
 c.filter=@"Series";[c syncDiscoveryActivity];C([s.homeType isEqual:@"series"]&&!c.homeRefreshStarted);
 c.homeRefreshStarted=YES;[c syncDiscoveryActivity];C(c.homeRefreshStarted);
 c.filter=@"Movies";[c syncDiscoveryActivity];C([s.homeType isEqual:@"movie"]&&!c.homeRefreshStarted);
 c.homeRefreshStarted=YES;c.filter=@"All";[c syncDiscoveryActivity];C(!s.homeType&&!c.homeRefreshStarted);
 // A return must still respect player, profile, background and memory gates.
 c.page=@"Entity";c.presentedViewController=[NSObject new];[c viewDidAppear:NO];C(s.paused);c.presentedViewController=nil;
 c.page=@"Profiles";[c viewDidAppear:NO];C(s.paused);c.page=@"Entity";
 UIApplication.sharedApplication.applicationState=UIApplicationStateBackground;[c viewDidAppear:NO];C(s.paused);UIApplication.sharedApplication.applicationState=UIApplicationStateActive;
 c.discoveryMemoryCooldown=NSProcessInfo.processInfo.systemUptime+30;[c viewDidAppear:NO];C(s.paused);c.discoveryMemoryCooldown=0;
 c.preview=[Preview new];c.preview.usingVideoNetwork=YES;[c viewDidAppear:NO];C(s.paused);c.preview=nil;
 c.previewSession=[Preview new];c.previewSession.state=@"lookup";[c viewDidAppear:NO];C(s.paused);c.previewSession=nil;
 [c viewDidAppear:NO];C(!s.paused);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
