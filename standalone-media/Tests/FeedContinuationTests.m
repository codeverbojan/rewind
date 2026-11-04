#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <math.h>
@interface RWPosterCollection:NSObject {
@public BOOL _horizontalIntent,_horizontalRequestCommitted,_requestScheduled,_loading,_more,_automatic,_updating;NSString *_error,*_rangeError,*_lastAutoToken;NSUInteger _cursor,_loadGeneration;
@public NSUInteger _automaticRequests,_manualRequests;BOOL _restoringPosition;id _pendingFeedPosition;
}
@property(nonatomic,assign) BOOL horizontal,continuationPaused;
@property(nonatomic,copy) void(^onScroll)(CGPoint);
@property(nonatomic,assign) CGSize contentSize;
@property(nonatomic,assign) CGPoint contentOffset;
@property(nonatomic,assign) CGRect bounds;
@property(nonatomic,strong) id window;
@property(nonatomic,copy) void(^onLoadMore)(BOOL manual);
@property(nonatomic,assign) NSUInteger count;
- (NSUInteger)recordCount;
- (void)considerMore;
@end
@implementation RWPosterCollection
- (NSUInteger)recordCount{return self.count;}
#include "../RWFeedContinuation.inc"
#define UIScrollView RWPosterCollection
- (void)requestVisibleRecords {}
#include "PosterScrollUnderTest.inc"
#undef UIScrollView
@end
static void Spin(void){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:.03];while(end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.001]];}
static RWPosterCollection *Grid(void){RWPosterCollection *g=[RWPosterCollection new];g->_automatic=YES;g->_more=YES;g.bounds=CGRectMake(0,0,1024,600);g.contentSize=CGSizeMake(1024,1000);g.window=[NSObject new];g.count=20;return g;}
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    __block NSUInteger requests=0;RWPosterCollection *g=Grid();g.onLoadMore=^(BOOL manual){requests++;};
    [g considerMore];[g considerMore];Spin();CHECK(requests==1);[g considerMore];Spin();CHECK(requests==1);
    g->_cursor=20;[g considerMore];Spin();CHECK(requests==2);
    // An intervening same-count metadata refresh invalidates the scheduled
    // block; it must reschedule, rather than consume an unsent request token.
    requests=0;g=Grid();g.onLoadMore=^(BOOL manual){requests++;};[g considerMore];g->_loadGeneration++;Spin();CHECK(requests==1);
    requests=0;g=Grid();g.onLoadMore=^(BOOL manual){requests++;};[g considerMore];g->_loading=YES;Spin();CHECK(requests==0);g->_loading=NO;[g considerMore];Spin();CHECK(requests==1);
    requests=0;g=Grid();g.onLoadMore=^(BOOL manual){requests++;};[g considerMore];g.window=nil;Spin();CHECK(requests==0);g.window=[NSObject new];[g considerMore];Spin();CHECK(requests==1);
    requests=0;g=Grid();g.onLoadMore=^(BOOL manual){requests++;};g->_error=@"Offline";[g considerMore];Spin();CHECK(requests==0);g->_error=nil;[g considerMore];Spin();CHECK(requests==1);
    requests=0;g=Grid();g.onLoadMore=^(BOOL manual){requests++;};g.contentSize=CGSizeMake(1024,3000);[g considerMore];Spin();CHECK(requests==0);g.contentOffset=CGPointMake(0,2400);[g considerMore];Spin();CHECK(requests==1);
    requests=0;g=Grid();g.onLoadMore=^(BOOL manual){requests++;};g.horizontal=YES;[g considerMore];Spin();CHECK(requests==0);
    requests=0;g=Grid();g.onLoadMore=^(BOOL manual){requests++;};[g considerMore];g.contentSize=CGSizeMake(1024,3000);Spin();CHECK(requests==0);g.contentOffset=CGPointMake(0,2400);[g considerMore];Spin();CHECK(requests==1);
    requests=0;g=Grid();g.onLoadMore=^(BOOL manual){requests++;};[g considerMore];g->_rangeError=@"Read failed";Spin();CHECK(requests==0);g->_rangeError=nil;[g considerMore];Spin();CHECK(requests==1);
    requests=0;g=Grid();g.onLoadMore=^(BOOL manual){requests++;};[g considerMore];g->_cursor=40;g.count=40;Spin();CHECK(requests==1&&g->_automaticRequests==1);[g considerMore];Spin();CHECK(requests==1);
    requests=0;g=Grid();g.onLoadMore=^(BOOL manual){requests++;};[g considerMore];g->_updating=YES;Spin();CHECK(requests==0);g->_updating=NO;[g considerMore];Spin();CHECK(requests==1);
    // Restored offsets can emit later UIKit callbacks after the synchronous
    // restoration flag is cleared. Those callbacks are not browsing intent.
    requests=0;g=Grid();g.horizontal=YES;g.contentSize=CGSizeMake(2500,280);g.contentOffset=CGPointMake(1800,0);g.onLoadMore=^(BOOL manual){requests++;};
    g->_restoringPosition=YES;[g scrollViewDidScroll:g];Spin();CHECK(requests==0&&!g->_horizontalIntent);
    g->_restoringPosition=NO;[g scrollViewDidScroll:g];[g scrollViewDidScroll:g];Spin();CHECK(requests==0&&!g->_horizontalIntent);
    [g scrollViewWillBeginDragging:g];[g scrollViewDidScroll:g];Spin();CHECK(requests==1&&g->_horizontalIntent);
    // Short horizontal rows wait for actual browsing intent, then continue.
    requests=0;g=Grid();g.horizontal=YES;g.contentSize=CGSizeMake(500,280);g.onLoadMore=^(BOOL manual){requests++;};[g considerMore];Spin();CHECK(requests==0);g->_horizontalIntent=YES;[g considerMore];Spin();CHECK(requests==1);[g considerMore];Spin();CHECK(requests==1);
    // Longer rows prefetch only near the right edge. Append pauses prefetch
    // once the new extent has moved beyond the lookahead distance.
    g->_cursor=20;g.count=40;g.contentSize=CGSizeMake(6000,280);g.contentOffset=CGPointMake(3000,0);[g considerMore];Spin();CHECK(requests==1);g.contentOffset=CGPointMake(5000,0);[g scrollViewWillBeginDragging:g];Spin();CHECK(requests==2);g->_cursor=40;g.count=60;g.contentSize=CGSizeMake(9000,280);[g considerMore];Spin();CHECK(requests==2);
    // A queued request never escapes detach, error, changed scope or an
    // explicit end marker; identical count/cursor cannot form a request loop.
    g->_cursor=60;g.contentOffset=CGPointMake(8500,0);[g scrollViewWillBeginDragging:g];g->_more=NO;Spin();CHECK(requests==2);g->_more=YES;g->_error=@"Offline";[g considerMore];Spin();CHECK(requests==2);g->_error=nil;[g considerMore];g.window=nil;Spin();CHECK(requests==2);g.window=[NSObject new];[g considerMore];Spin();CHECK(requests==3);g.contentOffset=CGPointMake(INFINITY,0);g->_cursor=80;[g considerMore];Spin();CHECK(requests==3);
    // Retrying is driven by a new drag, never a layout/metadata callback.
    requests=0;g=Grid();g.horizontal=YES;g->_horizontalIntent=YES;g.contentSize=CGSizeMake(500,280);g.continuationPaused=YES;
    __block BOOL manual=NO;g.onLoadMore=^(BOOL value){requests++;manual=value;g->_loading=YES;};
    [g considerMore];Spin();CHECK(requests==0);[g retryContinuationFromGesture];CHECK(requests==1&&manual&&g->_manualRequests==1);[g retryContinuationFromGesture];CHECK(requests==1);
    g->_loading=NO;g.window=nil;[g retryContinuationFromGesture];CHECK(requests==1);g.window=[NSObject new];g->_rangeError=@"Disk";[g retryContinuationFromGesture];CHECK(requests==1);g->_rangeError=nil;g.contentSize=CGSizeMake(6000,280);[g retryContinuationFromGesture];CHECK(requests==1);g.contentOffset=CGPointMake(5500,0);[g scrollViewWillBeginDragging:g];CHECK(requests==2);g->_loading=NO;g->_more=NO;[g retryContinuationFromGesture];CHECK(requests==2);
    // One actual horizontal gesture owns one bounded request. Tiny appends,
    // metadata publications and idle end-of-row layouts cannot renew it.
    requests=0;g=Grid();g.horizontal=YES;g.contentSize=CGSizeMake(500,280);g.onLoadMore=^(BOOL value){requests++;};
    [g scrollViewWillBeginDragging:g];Spin();CHECK(requests==1);g->_cursor++;g.count++;[g considerMore];Spin();CHECK(requests==1);
    [g scrollViewDidScroll:g];Spin();CHECK(requests==1);[g scrollViewWillBeginDragging:g];Spin();CHECK(requests==2);
    // A quiet pause also cancels a queued automatic callback; clearing it
    // after local enrichment allows one automatic request without a retry UI.
    requests=0;g=Grid();g.onLoadMore=^(BOOL value){requests++;};[g considerMore];g.continuationPaused=YES;Spin();CHECK(requests==0);g.continuationPaused=NO;[g considerMore];Spin();CHECK(requests==1);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
