#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <math.h>
@class UICollectionView,UICollectionViewLayout;
@interface NSIndexPath (Item)
+ (instancetype)indexPathForItem:(NSUInteger)item inSection:(NSUInteger)section;
@end
@implementation NSIndexPath (Item)
+ (instancetype)indexPathForItem:(NSUInteger)item inSection:(NSUInteger)section {return [self indexPathWithIndex:item];}
@end
@interface UICollectionViewLayoutAttributes:NSObject
@property CGRect frame;
@end
@implementation UICollectionViewLayoutAttributes
@end
@interface TestFeed:NSObject
@property NSString *context;
@end
@implementation TestFeed
@end
@interface PositionHarness:NSObject {
@public NSDictionary *_pendingFeedPosition;BOOL _restoringPosition,_updating;TestFeed *_feed;
}
@property BOOL dragging,decelerating,horizontal,hasLayout;
@property(nonatomic,copy) void(^onLoadMore)(BOOL);
@property NSUInteger count;
@property CGSize contentSize;
@property CGRect bounds;
@property CGPoint contentOffset;
- (NSUInteger)recordCount;
- (void)setNeedsLayout;
- (void)layoutIfNeeded;
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)p;
- (void)applyFeedPosition;
- (void)restorePositionIndex:(NSUInteger)index delta:(double)delta context:(NSString *)context;
@end
@implementation PositionHarness
- (NSUInteger)recordCount{return self.count;}
- (void)setNeedsLayout {}
- (void)layoutIfNeeded {}
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)p {if(!self.hasLayout)return nil;UICollectionViewLayoutAttributes *a=[UICollectionViewLayoutAttributes new];a.frame=CGRectMake([p indexAtPosition:0]*289+32,[p indexAtPosition:0]*200,264,200);return a;}
#include "../RWPosterFeedPosition.inc"
#include "../RWPosterFooterGeometry.inc"
@end
static int checks,failures;
#define C(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"line%d\n",__LINE__);}}while(0)
int main(){@autoreleasepool{
 PositionHarness *v=[PositionHarness new];v.horizontal=YES;v.bounds=CGRectMake(0,0,768,210);v.contentSize=CGSizeMake(64,210);v->_updating=YES;
 [v restorePositionIndex:16 delta:106 context:@"regular:films"];C(v->_pendingFeedPosition!=nil);C(v.contentOffset.x==0);
 v->_updating=NO;[v applyFeedPosition];C(v->_pendingFeedPosition!=nil); // Feed is still pending.
 v->_feed=[TestFeed new];v->_feed.context=@"kids:films";v.count=21;v.contentSize=CGSizeMake(6400,210);v.hasLayout=YES;[v applyFeedPosition];C(v.contentOffset.x==0&&v->_pendingFeedPosition!=nil);
 v->_feed.context=@"regular:films";v.hasLayout=NO;[v applyFeedPosition];C(v->_pendingFeedPosition!=nil);v.hasLayout=YES;v.contentSize=CGSizeMake(3507,210);[v applyFeedPosition];C(v->_pendingFeedPosition!=nil&&v.contentOffset.x==0);v.contentSize=CGSizeMake(6400,210);[v applyFeedPosition];C(v.contentOffset.x==4762);C(!v->_pendingFeedPosition&&!v->_restoringPosition);
 v.contentOffset=CGPointMake(800,0);[v applyFeedPosition];C(v.contentOffset.x==800); // One-shot; no snap-back on later layouts.
 v->_updating=YES;[v restorePositionIndex:4 delta:15 context:@"regular:films"];v.dragging=YES;v->_updating=NO;[v applyFeedPosition];C(!v->_pendingFeedPosition&&v.contentOffset.x==800);v.dragging=NO;
 [v restorePositionIndex:99 delta:0 context:@"regular:films"];C(!v->_pendingFeedPosition&&v.contentOffset.x==800);
 [v restorePositionIndex:NSNotFound delta:0 context:@"regular:films"];[v restorePositionIndex:0 delta:NAN context:@"regular:films"];C(!v->_pendingFeedPosition);
 [v restorePositionIndex:20 delta:800 context:@"regular:films"];C(v.contentOffset.x==5632);
 [v restorePositionIndex:0 delta:-100 context:@"regular:films"];C(v.contentOffset.x==0);
 v.horizontal=NO;v.contentSize=CGSizeMake(768,4500);v.bounds=CGRectMake(0,0,768,700);[v restorePositionIndex:8 delta:35 context:@"regular:films"];C(v.contentOffset.y==1635);
 // Rebinding temporarily removes the callback while UIKit measures the row.
 // A persisted feed must keep its footer extent, or restoring the final card
 // clamps 64pt left even though the anchor identity is correct.
 v.horizontal=YES;v.count=15;v.bounds=CGRectMake(0,0,768,210);v.onLoadMore=^(BOOL manual){};
 CGSize tail=[v collectionView:nil layout:nil referenceSizeForFooterInSection:0];C(tail.width==64);
 v.onLoadMore=nil;tail=[v collectionView:nil layout:nil referenceSizeForFooterInSection:0];C(tail.width==64);
 v.contentSize=CGSizeMake(4374+tail.width,210);[v restorePositionIndex:12 delta:170 context:@"regular:films"];C(v.contentOffset.x==3670);
 v->_feed=nil;C([v collectionView:nil layout:nil referenceSizeForFooterInSection:0].width==0);
 v.horizontal=NO;C([v collectionView:nil layout:nil referenceSizeForFooterInSection:0].height==104);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
