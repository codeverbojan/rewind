#import "RWHomeView.h"
#import "RWUIProbe.h"

@interface RWHomeShelf : UITableViewCell
@property(nonatomic,strong) UILabel *heading;
@property(nonatomic,strong) UIView *headingPlaceholder;
@property(nonatomic,strong) RWPosterCollection *rail;
@property(nonatomic,copy) NSString *identity;
@property(nonatomic,copy) NSString *rowIdentifier,*feedContext;
@end
@implementation RWHomeShelf
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuse {
    if((self=[super initWithStyle:style reuseIdentifier:reuse])){self.selectionStyle=UITableViewCellSelectionStyleNone;self.backgroundColor=UIColor.clearColor;
        self.heading=RWLabel(@"",23,UIFontWeightSemibold,RWColor(0xf5f2eb));[self.contentView addSubview:self.heading];
        self.headingPlaceholder=[UIView new];self.headingPlaceholder.backgroundColor=RWColor(0x20242b);self.headingPlaceholder.layer.cornerRadius=4;self.headingPlaceholder.userInteractionEnabled=NO;self.headingPlaceholder.accessibilityElementsHidden=YES;[self.contentView addSubview:self.headingPlaceholder];
        self.rail=[[RWPosterCollection alloc]initWithFrame:CGRectZero];self.rail.horizontal=YES;[self.contentView addSubview:self.rail];
    }return self;
}
- (void)layoutSubviews {[super layoutSubviews];self.heading.frame=CGRectMake(32,0,MAX(1,self.bounds.size.width-64),34);self.headingPlaceholder.frame=CGRectMake(32,9,MIN(210,MAX(1,self.bounds.size.width-64)),18);self.rail.frame=CGRectMake(0,48,self.bounds.size.width,MAX(1,self.bounds.size.height-68));}
- (void)prepareForReuse {[super prepareForReuse];self.rail.onSelect=nil;self.rail.onScroll=nil;self.rail.onScrollSettled=nil;self.rail.onContentNeeded=nil;self.rail.onLoadMore=nil;}
@end
@interface RWHomeView () <UITableViewDataSource,UITableViewDelegate>
@end
@implementation RWHomeView {NSArray *_rows;double _lastViewport;NSUInteger _applies,_structureUpdates,_reactivations,_pendingTitles;BOOL _parked;NSUInteger _contentGeneration,_contentSlices,_contentPrepared;BOOL _contentScheduled;double _contentStarted;NSMutableArray *_anchorAudit;}
- (NSArray *)displayedRows {return _rows;}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame style:UITableViewStylePlain])){_rows=@[];self.dataSource=self;self.delegate=self;self.backgroundColor=UIColor.clearColor;self.separatorStyle=UITableViewCellSeparatorStyleNone;self.estimatedRowHeight=0;self.tableFooterView=[[UIView alloc]initWithFrame:CGRectMake(0,0,1,24)];[self registerClass:RWHomeShelf.class forCellReuseIdentifier:@"shelf"];}
    return self;
}
- (CGFloat)height:(NSDictionary *)row {return [row[@"landscape"]boolValue]?278:344;}
- (NSString *)key:(NSDictionary *)row {return [NSString stringWithFormat:@"%@:%@",self.scope?:@"",row[@"id"]];}
- (void)updateRows:(NSArray *)rows header:(UIView *)header {
    _applies++;NSArray *next=[rows copy]?:@[];BOOL same=next.count==_rows.count;
    _pendingTitles=0;for(NSDictionary *row in next)for(NSDictionary *card in row[@"items"])if([card[@"homePreparationPending"]boolValue])_pendingTitles++;
    for(NSUInteger i=0;same&&i<next.count;i++)same=[next[i][@"id"]isEqual:_rows[i][@"id"]]&&[self height:next[i]]==[self height:_rows[i]];
    // A newly eligible shelf may appear above the current one. Restore the
    // visible shelf and its displacement, rather than jumping to the top.
    NSIndexPath *anchor=[[self indexPathsForVisibleRows]sortedArrayUsingSelector:@selector(compare:)].firstObject;
    NSString *anchorID=anchor&&anchor.row<_rows.count?_rows[anchor.row][@"id"]:nil;
    CGFloat offset=self.contentOffset.y,delta=anchor?offset-[self rectForRowAtIndexPath:anchor].origin.y:0;
    BOOL headerChanged=self.tableHeaderView!=header;if(!same)[self saveVisibleAnchors];_rows=next;
    if(headerChanged)self.tableHeaderView=header;
    if(!same){_structureUpdates++;[self reloadData];}
    else for(NSIndexPath *path in self.indexPathsForVisibleRows)[self configure:(RWHomeShelf *)[self cellForRowAtIndexPath:path] path:path];
    [self layoutIfNeeded];
    if(!same||headerChanged){if(offset>0&&anchorID)for(NSUInteger i=0;i<_rows.count;i++)if([anchorID isEqual:_rows[i][@"id"]]){offset=[self rectForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]].origin.y+delta;break;}
        self.contentOffset=CGPointMake(0,MAX(0,MIN(offset,MAX(0,self.contentSize.height-self.bounds.size.height))));}
    [self loadVisibleArtwork];
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section{return _rows.count;}
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)path{return [self height:_rows[path.row]];}
- (void)configure:(RWHomeShelf *)cell path:(NSIndexPath *)path {
    if(!cell||path.row>=_rows.count)return;NSDictionary *row=_rows[path.row];NSString *key=[self key:row];BOOL changed=![cell.identity isEqual:key]||(row[@"feed"]&&cell.rail.feed!=row[@"feed"]);
    // The seed row can mount before its persisted feed arrives. Its row key
    // stays the same, but binding that feed must restore the saved position.
    // Disable the old row's callback before changing its reused scroll view.
    if(changed)[self saveAnchorForShelf:cell];
    cell.rail.onScroll=nil;cell.rail.onLoadMore=nil;cell.rail.onScrollSettled=nil;cell.identity=key;cell.rowIdentifier=row[@"id"];cell.feedContext=[(id<RWPosterFeed>)row[@"feed"] context];cell.heading.text=row[@"title"];cell.rail.landscape=[row[@"landscape"]boolValue];cell.rail.reviewMode=self.reviewMode;
    __weak RWHomeView *weak=self;cell.rail.defersContents=!self.reviewMode;cell.rail.onContentNeeded=^{[weak scheduleContentPreparation];};
    BOOL loading=[row[@"loading"]boolValue],initial=loading&&!row[@"feed"];cell.headingPlaceholder.hidden=!initial;cell.heading.hidden=initial;
    [cell setNeedsLayout];[cell layoutIfNeeded];
    cell.rail.continuationPaused=[row[@"paused"]boolValue];
    if(row[@"feed"]){NSString *identifier=row[@"id"];cell.rail.onLoadMore=^(BOOL manual){if(weak.onLoadMore)weak.onLoadMore(identifier,manual);};[cell.rail updateFeed:row[@"feed"] loading:loading more:[row[@"more"]boolValue] error:row[@"error"] cursor:[row[@"cursor"]unsignedIntegerValue] automatic:YES];}
    else [cell.rail updateItems:row[@"items"] loading:loading more:NO error:nil cursor:0 automatic:NO];
    if(changed){[cell.rail layoutIfNeeded];// A fresh destination begins at the leading edge. Persisted database
    // anchors are used only after this page has actually scrolled in this run,
    // so another tab/profile or an old diagnostic cannot open it far to the right.
    if(row[@"feed"]&&self.restoreAnchor&&[self.railOffsets[key]doubleValue]>0){__weak RWHomeShelf *shelf=cell;NSString *context=[(id<RWPosterFeed>)row[@"feed"] context];self.restoreAnchor(row[@"id"],^(NSUInteger index,NSDictionary *anchor){RWHomeShelf *target=shelf;BOOL matches=[target.identity isEqual:key];CGFloat before=target.rail.contentOffset.x;if(matches&&index!=NSNotFound)[target.rail restorePositionIndex:index delta:[anchor[@"delta"]doubleValue] context:context];
        RWHomeView *owner=weak;if(owner){if(!owner->_anchorAudit)owner->_anchorAudit=[NSMutableArray new];[owner->_anchorAudit addObject:@{@"key":key,@"context":context?:@"",@"matches":@(matches),@"index":index==NSNotFound?@(-1):@(index),@"anchor":anchor?:@{},@"before":@(before),@"after":@(target.rail.contentOffset.x),@"count":@(target.rail.feed.count),@"width":@(target.rail.contentSize.width),@"bounds":@(target.rail.bounds.size.width),@"dragging":@(target.rail.dragging),@"decelerating":@(target.rail.decelerating)}];while(owner->_anchorAudit.count>16)[owner->_anchorAudit removeObjectAtIndex:0];}
    });}else{CGFloat x=[self.railOffsets[key]doubleValue];cell.rail.contentOffset=CGPointMake(MAX(0,MIN(x,MAX(0,cell.rail.contentSize.width-cell.rail.bounds.size.width))),0);}}
    cell.rail.onSelect=^(NSDictionary *meta){if(weak.onSelect)weak.onSelect(meta);};
    cell.rail.onScroll=^(CGPoint offset){RWHomeView *view=weak;if(!view)return;if(view.railOffsets.count>=128&&!view.railOffsets[key])[view.railOffsets removeObjectForKey:view.railOffsets.allKeys.firstObject];view.railOffsets[key]=@(offset.x);[view notifyViewport];};
    __weak RWHomeShelf *shelf=cell;cell.rail.onScrollSettled=^{RWHomeView *view=weak;[view saveAnchorForShelf:shelf];if(view.window&&view.onViewport)view.onViewport();};
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {RWHomeShelf *cell=[table dequeueReusableCellWithIdentifier:@"shelf" forIndexPath:path];cell.frame=CGRectMake(0,0,self.bounds.size.width,[self height:_rows[path.row]]);[self configure:cell path:path];return cell;}
#include "RWHomeAnchorLifecycle.inc"
- (void)saveVisibleAnchors {
    if(!self.onAnchor)return;for(RWHomeShelf *cell in self.visibleCells)[self saveAnchorForShelf:cell];
}
- (void)parkForReuse {
    [self saveVisibleAnchors];
    [self cancelContentPreparation];
    [self removeFromSuperview];_parked=YES;
    // Keep header geometry for the scroll anchor, but release the hero image,
    // labels and actions. Poster controls release their artwork on detachment.
    if(self.tableHeaderView)self.tableHeaderView=[[UIView alloc]initWithFrame:self.tableHeaderView.frame];
}
- (void)loadVisibleArtwork {if(!self.window&&!self.reviewMode)return;for(RWHomeShelf *cell in self.visibleCells)[cell.rail loadVisibleArtwork];}
- (BOOL)canPrepareContent {return self.window&&!self.hidden&&!self.reviewMode&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive;}
- (BOOL)hasPendingVisibleContent {for(RWHomeShelf *cell in self.visibleCells)if([cell.rail hasPendingVisibleContent])return YES;return NO;}
- (void)prepareNextVisibleContent {
    double began=NSProcessInfo.processInfo.systemUptime;
    for(NSIndexPath *path in [self.indexPathsForVisibleRows sortedArrayUsingSelector:@selector(compare:)]){
        RWHomeShelf *cell=(RWHomeShelf *)[self cellForRowAtIndexPath:path];if([cell.rail prepareNextVisibleContent]){_contentPrepared++;break;}
    }
    _contentSlices++;[[RWUIProbe shared]work:@"home_card_slice" started:began];
}
#include "RWHomeContentScheduling.inc"
- (NSSet *)preparationIDs {NSMutableSet *ids=[NSMutableSet new];if(self.window)for(RWHomeShelf *cell in self.visibleCells)[ids unionSet:[cell.rail preparationIDs]];return ids;}
- (NSDictionary *)viewportAnchor {
    NSIndexPath *path=[[self indexPathsForVisibleRows]sortedArrayUsingSelector:@selector(compare:)].firstObject;
    if(!path||path.row>=_rows.count)return @{};
    return @{@"row":_rows[path.row][@"id"]?:@"",@"delta":@(self.contentOffset.y-[self rectForRowAtIndexPath:path].origin.y),@"offset":@(self.contentOffset.y)};
}
- (NSArray *)visibleMetadata {if(!self.window)return @[];NSMutableArray *out=[NSMutableArray new];for(RWHomeShelf *cell in self.visibleCells)[out addObjectsFromArray:[cell.rail visibleMetadata]];return out;}
- (NSDictionary *)diagnostics {NSUInteger cards=0,pending=0,prepared=0;for(RWHomeShelf *cell in self.visibleCells){cards+=cell.rail.visibleCells.count;pending+=[cell.rail visiblePendingCount];prepared+=[cell.rail visiblePreparedCount];}return @{@"anchor_restores":_anchorAudit?:@[],@"shelves":@(_rows.count),@"pending_titles":@(_pendingTitles),@"visible_pending_titles":@(pending),@"preparation_titles":@([self preparationIDs].count),@"initial_loading":@([_rows.firstObject[@"loading"]boolValue]),@"visible_shelves":@(self.window?self.visibleCells.count:0),@"visible_cards":@(self.window?cards:0),@"applies":@(_applies),@"structure_updates":@(_structureUpdates),@"reactivations":@(_reactivations),@"parked":@(_parked),@"reusable":@YES,@"visible_prepared_cards":@(prepared),@"content_slices":@(_contentSlices),@"content_prepared":@(_contentPrepared),@"content_pending":@([self hasPendingVisibleContent]),@"content_scheduled":@(_contentScheduled)};}
- (void)notifyViewport {if(!self.window)return;double now=NSProcessInfo.processInfo.systemUptime;if(now-_lastViewport<.15)return;_lastViewport=now;[self loadVisibleArtwork];if(self.onViewport)self.onViewport();}
- (BOOL)isInteracting {if(self.tracking||self.dragging||self.decelerating)return YES;for(RWHomeShelf *cell in self.visibleCells)if(cell.rail.tracking||cell.rail.dragging||cell.rail.decelerating)return YES;return NO;}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {[self notifyViewport];}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {if(!decelerate){[self loadVisibleArtwork];if(self.window&&self.onViewport)self.onViewport();}}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {if(!self.window)return;[self loadVisibleArtwork];if(self.onViewport)self.onViewport();}
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {if(!self.window)return;[self loadVisibleArtwork];if(self.onViewport)self.onViewport();}
- (void)didMoveToWindow {[super didMoveToWindow];if(!self.window)[self cancelContentPreparation];if(self.window&&_parked){_parked=NO;_reactivations++;}[self loadVisibleArtwork];}
@end
