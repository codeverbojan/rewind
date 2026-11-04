#import <Foundation/Foundation.h>
@interface RewindStore:NSObject
@property BOOL restricted;
@property NSUInteger cancellations;
+ (instancetype)shared;
- (BOOL)allowed:(NSDictionary *)meta;
- (NSArray *)allowedItems:(NSArray *)items;
- (void)cancelRelatedTitles;
@end
@implementation RewindStore
+ (instancetype)shared{static RewindStore *s;if(!s)s=[self new];return s;}
- (BOOL)allowed:(NSDictionary *)meta{return !self.restricted||[meta[@"allowed"]boolValue];}
- (NSArray *)allowedItems:(NSArray *)items{NSMutableArray *a=[NSMutableArray new];for(NSDictionary *m in items)if([self allowed:m])[a addObject:m];return a;}
- (void)cancelRelatedTitles{self.cancellations++;}
@end
@interface Preparation:NSObject
@property BOOL cancelled;
- (void)cancel;
@end
@implementation Preparation
- (void)cancel{self.cancelled=YES;}
@end
@interface HomeFeeds:NSObject
@property NSUInteger catalogChanges;
- (void)catalogChanged;
@end
@implementation HomeFeeds
- (void)catalogChanged{self.catalogChanges++;}
@end
@interface Controller:NSObject
@property(copy) NSString *page,*relatedKey;
@property(strong) NSArray *relatedTitles;
@property(strong) NSDictionary *detail;
@property(strong) id presentedViewController;
@property(strong) Preparation *playbackPreparation;
@property(strong) HomeFeeds *homeFeeds;
@property BOOL reviewMode,previewStopped;
@property NSUInteger upcomingRefresh,relatedRequests,relatedGeneration,detailRenders,downloadRefresh,searchRefresh,catalogRefresh;
- (void)ratingsChanged;
@end
@implementation Controller
- (instancetype)init{if((self=[super init])){self.homeFeeds=[HomeFeeds new];self.playbackPreparation=[Preparation new];self.detail=@{@"allowed":@YES};self.relatedTitles=@[@{@"id":@"safe",@"allowed":@YES},@{@"id":@"over-age",@"allowed":@NO}];self.relatedKey=@"cached";self.relatedGeneration=4;}return self;}
- (void)appendNewlyRatedBrowse{}
- (void)appendNewlyRatedEntity{}
- (void)requestEntityHeader{}
- (void)updateEntityGrid{}
- (void)stopPreview{self.previewStopped=YES;}
- (void)go:(NSString *)page{self.page=page;}
- (void)requestDetailRender{self.detailRenders++;}
- (void)requestRelatedTitles{self.relatedRequests++;}
- (void)updateUpcomingList{self.upcomingRefresh++;}
- (void)refreshDownloads{self.downloadRefresh++;}
- (void)updateSearchResults{self.searchRefresh++;}
- (void)scheduleCatalogRender{self.catalogRefresh++;}
#include "RatingSurfaceUnderTest.inc"
@end
static int checks,failures;
#define CHECK(x) do{checks++;if(!(x)){failures++;fprintf(stderr,"FAIL line%d: %s\n",__LINE__,#x);}}while(0)
int main(){@autoreleasepool{RewindStore *s=RewindStore.shared;s.restricted=YES;
 Controller *c=[Controller new];c.page=@"Upcoming";[c ratingsChanged];CHECK(c.upcomingRefresh==1);CHECK(!c.relatedRequests&&!c.catalogRefresh);
 c=[Controller new];c.page=@"Details";[c ratingsChanged];CHECK(c.relatedTitles.count==1);CHECK(c.relatedRequests==1);CHECK(c.relatedGeneration>4&&!c.relatedKey);CHECK(s.cancellations==1);CHECK(c.detailRenders==1);
 c=[Controller new];c.page=@"Details";c.detail=@{@"allowed":@NO};[c ratingsChanged];CHECK([c.page isEqual:@"Home"]&&c.previewStopped&&c.playbackPreparation.cancelled);CHECK(!c.relatedRequests);
 c=[Controller new];c.page=@"Downloads";[c ratingsChanged];CHECK(c.downloadRefresh==1);
 c=[Controller new];c.page=@"Search";[c ratingsChanged];CHECK(c.searchRefresh==1);c.presentedViewController=@YES;[c ratingsChanged];CHECK(c.searchRefresh==1);
 for(NSString *page in @[@"Home",@"My List"]){c=[Controller new];c.page=page;[c ratingsChanged];CHECK(c.catalogRefresh==1);CHECK(c.homeFeeds.catalogChanges==1);}
 s.restricted=NO;c=[Controller new];c.page=@"Upcoming";[c ratingsChanged];CHECK(!c.upcomingRefresh);CHECK(c.homeFeeds.catalogChanges==1);c.page=@"Details";[c ratingsChanged];CHECK(c.detailRenders==1&&!c.relatedRequests&&c.relatedTitles.count==2);CHECK(c.homeFeeds.catalogChanges==2);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;}}
