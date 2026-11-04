#import "RWListAnchor.h"
#include <math.h>
#import "RWPosterCollection.h"
#import "RWEntityCard.h"
#import "RWViewport.h"
#import "RWHomePresentation.h"
#import "RWUIProbe.h"
static BOOL PermitsCard(NSDictionary *record){RewindStore *s=[RewindStore shared];if(![@[@"person",@"studio",@"mood"]containsObject:record[@"type"]?:@""])return [s allowed:record];if(![record[@"profileID"]isEqual:s.state[@"activeProfile"]])return NO;NSArray *credits=record[@"knownFor"];if(!credits.count)return !s.restricted&&[record[@"verifiedEntity"]boolValue];for(NSDictionary *m in credits)if(![s allowed:m])return NO;return YES;}
// Three static shapes, sized exactly like the eventual card. No shimmer,
// display link, repeated gradient drawing or accessibility announcements.
@interface RWPosterSkeleton : UIView
@property(nonatomic,assign) BOOL landscape,entity;
@end
@implementation RWPosterSkeleton {CALayer *_picture,*_title,*_detail;}
- (instancetype)initWithFrame:(CGRect)frame {if((self=[super initWithFrame:frame])){self.userInteractionEnabled=NO;self.accessibilityElementsHidden=YES;_picture=[CALayer layer];_title=[CALayer layer];_detail=[CALayer layer];for(CALayer *layer in @[_picture,_title,_detail]){layer.backgroundColor=RWColor(0x20242b).CGColor;layer.cornerRadius=4;[self.layer addSublayer:layer];}_picture.cornerRadius=12;}return self;}
- (void)layoutSubviews {[super layoutSubviews];CGFloat w=self.bounds.size.width,h=self.entity?w:self.landscape?w*.5625:w*1.45;[CATransaction begin];[CATransaction setDisableActions:YES];_picture.frame=CGRectMake(0,0,w,h);_title.frame=CGRectMake(0,h+13,w*.78,12);_detail.frame=CGRectMake(0,h+35,w*.44,8);[CATransaction commit];}
@end
@interface RWPosterCell : UICollectionViewCell
@property(nonatomic,strong) RWPoster *poster;
@property(nonatomic,strong) RWPosterSkeleton *skeleton;
@property(nonatomic,strong) NSDictionary *record;
@property(nonatomic,strong) NSDictionary *presentation;
@property(nonatomic,assign) BOOL landscape;
@property(nonatomic,assign) BOOL defersContents;
@property(nonatomic,assign) double visibleSince;
- (void)configure:(NSDictionary *)meta width:(CGFloat)width landscape:(BOOL)landscape action:(void(^)(NSDictionary *))action;
@end
@implementation RWPosterCell
#include "RWPosterBinding.inc"
- (void)layoutSubviews {[super layoutSubviews];if(self.contentView.bounds.size.width>0&&self.contentView.bounds.size.height>0){self.poster.frame=self.contentView.bounds;self.skeleton.frame=self.contentView.bounds;}}
- (void)prepareForReuse {[super prepareForReuse];[self.poster cancelArtwork];self.poster.action=nil;self.visibleSince=0;}
@end
@interface RWFeedFooter : UICollectionReusableView
@property(nonatomic,strong) UIActivityIndicatorView *spinner;
@property(nonatomic,strong) RWButton *button;
@property(nonatomic,strong) UILabel *label;
@property(nonatomic,assign) BOOL hasError,horizontal;
@property(nonatomic,strong) RWPosterSkeleton *skeleton;
@end
@implementation RWFeedFooter
- (instancetype)initWithFrame:(CGRect)frame {if((self=[super initWithFrame:frame])){self.skeleton=[[RWPosterSkeleton alloc]initWithFrame:CGRectZero];self.skeleton.hidden=YES;[self addSubview:self.skeleton];self.spinner=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];[self addSubview:self.spinner];self.label=RWLabel(@"",13,UIFontWeightRegular,RWColor(0xa9b2be));self.label.textAlignment=NSTextAlignmentCenter;[self addSubview:self.label];self.button=[RWButton text:@"Load more" action:nil];[self.button appearance:NO];[self addSubview:self.button];}return self;}
- (void)layoutSubviews {[super layoutSubviews];CGFloat w=self.bounds.size.width;if(self.horizontal){self.spinner.center=CGPointMake(w/2,75);self.button.frame=CGRectMake((w-44)/2,53,44,44);return;}self.spinner.center=CGPointMake(w/2-65,29);self.label.frame=CGRectMake(24,0,w-48,44);self.button.frame=CGRectMake((w-180)/2,self.hasError?48:8,180,44);}
@end
@interface RWPosterCollection () <UICollectionViewDataSource,UICollectionViewDelegateFlowLayout>
@end
@implementation RWPosterCollection {
    NSArray *_items;BOOL _loading,_more,_automatic,_updating,_requestScheduled,_recordsScheduled,_placeholders;
    NSString *_error,*_rangeError,*_lastAutoToken,*_feedScope;NSUInteger _cursor;NSDictionary *_pending,*_pendingPositionAnchor,*_pendingFeedPosition;BOOL _restoringPosition;
    id<RWPosterFeed> _feed;NSUInteger _feedCount,_feedRevision,_loadGeneration;BOOL _rangeLoading,_horizontalIntent,_horizontalRequestCommitted;NSRange _loadedRange;
    NSUInteger _automaticRequests,_manualRequests;
}
- (void)setHeaderView:(UIView *)headerView {
    if(_headerView==headerView)return;CGFloat before=_headerView.bounds.size.height,offset=self.contentOffset.y;[_headerView removeFromSuperview];_headerView=headerView;
    for(UICollectionReusableView *view in [self visibleSupplementaryViewsOfKind:UICollectionElementKindSectionHeader]){for(UIView *child in view.subviews)[child removeFromSuperview];if(headerView)[view addSubview:headerView];}
    [self.collectionViewLayout invalidateLayout];[self layoutIfNeeded];if(before>0&&offset>=before)self.contentOffset=CGPointMake(0,MAX(0,offset+headerView.bounds.size.height-before));
}
- (instancetype)initWithFrame:(CGRect)frame {
    UICollectionViewFlowLayout *layout=[UICollectionViewFlowLayout new];layout.minimumInteritemSpacing=20;layout.minimumLineSpacing=25;layout.sectionInset=UIEdgeInsetsMake(0,32,10,32);
    if((self=[super initWithFrame:frame collectionViewLayout:layout])){_items=@[];self.dataSource=self;self.delegate=self;self.backgroundColor=UIColor.clearColor;self.alwaysBounceVertical=YES;self.keyboardDismissMode=UIScrollViewKeyboardDismissModeOnDrag;[self registerClass:RWPosterCell.class forCellWithReuseIdentifier:@"poster"];[self registerClass:RWFeedFooter.class forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"footer"];[self registerClass:UICollectionReusableView.class forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"header"];}
    return self;
}
- (NSArray *)items{return _items;}
- (NSDictionary *)positionAnchor {
    // An unfinished restore does not describe a new browsing position.
    if(_pendingFeedPosition||_restoringPosition||_updating)return nil;
    if(_pendingPositionAnchor)return _pendingPositionAnchor;
    if(![self recordCount])return nil;
    UICollectionViewLayoutAttributes *first=nil;
    for(UICollectionViewLayoutAttributes *a in [self.collectionViewLayout layoutAttributesForElementsInRect:self.bounds])if(a.representedElementCategory==UICollectionElementCategoryCell&&(!first||a.indexPath.item<first.indexPath.item))first=a;
    if(!first)return nil;
    if(_feed||self.horizontal){RWPosterCell *cell=(RWPosterCell *)[self cellForItemAtIndexPath:first.indexPath];NSDictionary *m=cell.record?:(_feed?[_feed cachedItem:first.indexPath.item]:_items[first.indexPath.item]);if(!RWID(m).length)return nil;return @{@"id":RWID(m),@"delta":@(self.horizontal?self.contentOffset.x-first.frame.origin.x:self.contentOffset.y-first.frame.origin.y)};}
    return [RWListAnchor capture:_items index:first.indexPath.item delta:self.contentOffset.y-first.frame.origin.y];
}
#include "RWPosterFeedPosition.inc"
- (void)restorePositionIndex:(NSUInteger)index delta:(double)delta {[self restorePositionIndex:index delta:delta context:_feed.context];}
- (void)applyPositionAnchor {
    if(!_pendingPositionAnchor||_restoringPosition||_updating)return;
    NSUInteger index=[RWListAnchor index:_pendingPositionAnchor items:_items];if(index==NSNotFound){_pendingPositionAnchor=nil;return;}
    UICollectionViewLayoutAttributes *frame=[self layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
    if(!frame||self.contentSize.height<=0)return;
    double delta=[_pendingPositionAnchor[@"delta"]doubleValue];if(!isfinite(delta)){_pendingPositionAnchor=nil;return;}
    _restoringPosition=YES;_pendingPositionAnchor=nil;
    self.contentOffset=CGPointMake(0,MAX(0,MIN(frame.frame.origin.y+delta,MAX(0,self.contentSize.height-self.bounds.size.height))));_restoringPosition=NO;
}
- (void)restorePositionAnchor:(NSDictionary *)anchor {
    if(_feed||self.horizontal||![anchor[@"delta"]isKindOfClass:NSNumber.class])return;
    _pendingPositionAnchor=[anchor copy];[self setNeedsLayout];[self layoutIfNeeded];[self applyPositionAnchor];
}
- (void)layoutSubviews {[super layoutSubviews];[self applyPositionAnchor];[self applyFeedPosition];}
- (NSUInteger)recordCount{return _feed?_feedCount:_items.count;}
- (NSUInteger)displayCount{return _placeholders?(self.horizontal?5:8):[self recordCount];}
- (void)setHorizontal:(BOOL)horizontal {_horizontal=horizontal;UICollectionViewFlowLayout *layout=(UICollectionViewFlowLayout *)self.collectionViewLayout;layout.sectionInset=UIEdgeInsetsMake(0,32,horizontal?0:10,32);layout.scrollDirection=horizontal?UICollectionViewScrollDirectionHorizontal:UICollectionViewScrollDirectionVertical;self.alwaysBounceVertical=!horizontal;self.alwaysBounceHorizontal=horizontal;self.showsHorizontalScrollIndicator=NO;self.directionalLockEnabled=YES;[layout invalidateLayout];}
- (void)setLandscape:(BOOL)landscape {if(_landscape==landscape)return;_landscape=landscape;[self.collectionViewLayout invalidateLayout];[self reloadData];}
- (CGSize)cardSize {if(self.horizontal&&self.entityCards&&self.compactEntityCards)return CGSizeMake(MIN(340,MAX(280,(self.bounds.size.width-84)/2)),96);if(self.horizontal&&self.entityCards){CGFloat width=MAX(120,MIN(220,self.bounds.size.height-141));return CGSizeMake(width,width+141);}if(self.horizontal){CGFloat width=RWPosterRailWidth(self.bounds.size.height-self.contentInset.top-self.contentInset.bottom,self.landscape);return CGSizeMake(width,(self.landscape?width*.5625:width*1.45)+51);}CGFloat available=MAX(320,self.bounds.size.width);NSUInteger columns=MAX(3,(NSUInteger)((available-64)/(self.entityCards?205:165)));CGFloat w=(available-64-(columns-1)*20)/columns;return CGSizeMake(w,self.entityCards?w+141:w*1.45+51);}
- (void)updateItems:(NSArray *)items loading:(BOOL)loading more:(BOOL)more error:(NSString *)error cursor:(NSUInteger)cursor automatic:(BOOL)automatic {
    if(_updating){_pending=@{@"items":items?:@[],@"loading":@(loading),@"more":@(more),@"error":error?:@"",@"cursor":@(cursor),@"automatic":@(automatic)};return;}
    BOOL footerChanged=_loading!=loading||_more!=more||![( _error?:@"")isEqual:error?:@""];BOOL wasFeed=_feed!=nil;_pendingFeedPosition=nil;BOOL oldPlaceholders=_placeholders;_feed=nil;_rangeError=nil;if(wasFeed){_loadGeneration++;_rangeLoading=NO;_items=@[];[self reloadData];}NSArray *old=_items,*next=[items copy]?:@[];BOOL placeholders=loading&&!next.count&&!error.length;_loading=loading;_more=more;_error=[error copy];_cursor=cursor;_automatic=automatic;
    BOOL prefix=old.count<=next.count;for(NSUInteger i=0;prefix&&i<old.count;i++)if(![RWID(old[i])isEqual:RWID(next[i])])prefix=NO;
    if(!oldPlaceholders&&!placeholders&&prefix&&old.count<next.count&&self.window){
        // Establish UIKit's old item count before changing the data source.
        // Changing it before the update block can crash a just-mounted grid.
        [self layoutIfNeeded];NSMutableArray *paths=[NSMutableArray new];for(NSUInteger i=old.count;i<next.count;i++)[paths addObject:[NSIndexPath indexPathForItem:i inSection:0]];
        _updating=YES;[UIView performWithoutAnimation:^{[self performBatchUpdates:^{self->_items=next;[self insertItemsAtIndexPaths:paths];} completion:^(BOOL finished){[self finishUpdate];}];}];
    }else{_items=next;_placeholders=placeholders;if(oldPlaceholders!=placeholders||!prefix||old.count!=next.count)[self reloadData];
        else for(NSIndexPath *path in self.indexPathsForVisibleItems){RWPosterCell *cell=(RWPosterCell *)[self cellForItemAtIndexPath:path];[self configureCell:cell at:path];}}
    if(oldPlaceholders!=placeholders||!prefix||old.count!=next.count||footerChanged)[self.collectionViewLayout invalidateLayout];for(RWFeedFooter *footer in [self visibleSupplementaryViewsOfKind:UICollectionElementKindSectionFooter])[self configureFooter:footer];
    [self considerMore];
}
- (void)finishUpdate {
    _updating=NO;NSDictionary *pending=_pending;_pending=nil;
    if(pending){if(pending[@"feed"])[self updateFeed:pending[@"feed"] loading:[pending[@"loading"]boolValue] more:[pending[@"more"]boolValue] error:pending[@"error"] cursor:[pending[@"cursor"]unsignedIntegerValue] automatic:[pending[@"automatic"]boolValue]];
        else [self updateItems:pending[@"items"] loading:[pending[@"loading"]boolValue] more:[pending[@"more"]boolValue] error:pending[@"error"] cursor:[pending[@"cursor"]unsignedIntegerValue] automatic:[pending[@"automatic"]boolValue]];}
    [self applyFeedPosition];[self loadVisibleArtwork];[self considerMore];
}
- (id<RWPosterFeed>)feed {return _feed;}
- (void)updateFeed:(id<RWPosterFeed>)feed loading:(BOOL)loading more:(BOOL)more error:(NSString *)error cursor:(NSUInteger)cursor automatic:(BOOL)automatic {
    if(_updating){_pending=@{@"feed":feed,@"loading":@(loading),@"more":@(more),@"error":error?:@"",@"cursor":@(cursor),@"automatic":@(automatic)};return;}
    // A new query can reuse the same feed object. Its old pagination token
    // and cells belong to the previous context even when the count matches.
    BOOL same=_feed==feed&&[_feedScope isEqual:feed.context],oldPlaceholders=_placeholders;_feedScope=[feed.context copy];NSUInteger old=[self recordCount],next=feed.count;BOOL placeholders=loading&&!next&&!error.length;_loading=loading;_more=more;_error=[error copy];_cursor=cursor;_automatic=automatic;if(!same){_lastAutoToken=nil;_horizontalIntent=NO;_horizontalRequestCommitted=NO;_automaticRequests=0;_manualRequests=0;_restoringPosition=YES;self.contentOffset=CGPointZero;_restoringPosition=NO;}
    if(!same||_feedRevision!=feed.revision){_loadGeneration++;_rangeError=nil;_rangeLoading=NO;_loadedRange=NSMakeRange(NSNotFound,0);}
    if(!oldPlaceholders&&!placeholders&&same&&next>old&&self.window){[self layoutIfNeeded];NSMutableArray *paths=[NSMutableArray new];for(NSUInteger i=old;i<next;i++)[paths addObject:[NSIndexPath indexPathForItem:i inSection:0]];_updating=YES;
        [UIView performWithoutAnimation:^{[self performBatchUpdates:^{self->_feedCount=next;self->_feedRevision=feed.revision;[self insertItemsAtIndexPaths:paths];} completion:^(BOOL finished){[self finishUpdate];}];}];
    }else{_feed=feed;_items=@[];_feedCount=next;_feedRevision=feed.revision;_placeholders=placeholders;if(oldPlaceholders!=placeholders||!same||next!=old)[self reloadData];else for(NSIndexPath *path in self.indexPathsForVisibleItems)[self configureCell:(RWPosterCell *)[self cellForItemAtIndexPath:path] at:path];}
    [self.collectionViewLayout invalidateLayout];for(RWFeedFooter *footer in [self visibleSupplementaryViewsOfKind:UICollectionElementKindSectionFooter])[self configureFooter:footer];[self requestVisibleRecords];[self considerMore];
}
- (void)requestVisibleRecords {
    if(!_feed||!_feedCount||_rangeLoading||_rangeError.length||(!self.window&&!self.reviewMode))return;
    NSUInteger first=NSNotFound,last=0;for(NSIndexPath *p in self.indexPathsForVisibleItems){first=MIN(first,(NSUInteger)p.item);last=MAX(last,(NSUInteger)p.item);}
    if(first==NSNotFound)return; // Wait for actual visible cells, not a guessed first page.
    if(_loadedRange.location!=NSNotFound&&first>=_loadedRange.location&&last<NSMaxRange(_loadedRange)){BOOL ready=YES;for(NSUInteger i=first;i<=last&&i-first<24;i++)if(![_feed cachedItem:i]){ready=NO;break;}if(ready)return;}
    NSRange range=RWFeedVisibleRange(_feedCount,first,last,self.horizontal);_rangeLoading=YES;NSUInteger generation=_loadGeneration;id<RWPosterFeed> feed=_feed;__weak RWPosterCollection *weak=self;
    [feed loadRange:range done:^(NSString *error){RWPosterCollection *view=weak;if(!view||view->_feed!=feed||view->_loadGeneration!=generation)return;view->_rangeLoading=NO;
        if(error){view->_rangeError=error;[view.collectionViewLayout invalidateLayout];for(RWFeedFooter *footer in [view visibleSupplementaryViewsOfKind:UICollectionElementKindSectionFooter])[view configureFooter:footer];return;}
        view->_loadedRange=range;for(NSIndexPath *path in view.indexPathsForVisibleItems)[view configureCell:(RWPosterCell *)[view cellForItemAtIndexPath:path] at:path];
        [view requestVisibleRecords];[view considerMore];
    }];
}
- (void)scheduleVisibleRecords {if(_recordsScheduled||!_feed)return;_recordsScheduled=YES;__weak RWPosterCollection *weak=self;dispatch_async(dispatch_get_main_queue(),^{RWPosterCollection *view=weak;if(!view)return;view->_recordsScheduled=NO;[view requestVisibleRecords];});}
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{return [self displayCount];}
- (void)configureCell:(RWPosterCell *)cell at:(NSIndexPath *)path {
    if(path.item>=[self displayCount])return;__weak RWPosterCollection *weak=self;
    NSDictionary *record=_placeholders?nil:_feed?[_feed cachedItem:path.item]:_items[path.item];
    if(!record||[record[@"homePreparationPending"]boolValue]){[cell.poster cancelArtwork];[cell.poster removeFromSuperview];cell.poster=nil;cell.record=nil;cell.presentation=nil;cell.contentView.backgroundColor=UIColor.clearColor;
        if(!cell.skeleton){cell.skeleton=[[RWPosterSkeleton alloc]initWithFrame:cell.contentView.bounds];[cell.contentView addSubview:cell.skeleton];}cell.skeleton.landscape=self.landscape;cell.skeleton.entity=self.entityCards;cell.skeleton.hidden=NO;[cell.skeleton setNeedsLayout];[self requestVisibleRecords];return;}
    cell.skeleton.hidden=YES;
    cell.contentView.backgroundColor=UIColor.clearColor;
    // Recheck the live profile before rendering or selecting a cached card.
    if(!PermitsCard(record)){[cell.poster removeFromSuperview];cell.poster=nil;cell.record=nil;return;}
    cell.defersContents=self.defersContents&&!self.reviewMode;
    [cell configure:record width:[self cardSize].width landscape:self.landscape action:^(NSDictionary *meta){if(weak.onSelect&&PermitsCard(meta))weak.onSelect(meta);}];
    if([cell.poster isKindOfClass:RWEntityCard.class]){((RWEntityCard *)cell.poster).compact=self.compactEntityCards;cell.poster.frame=CGRectMake(0,0,[self cardSize].width,[self cardSize].height);[cell.poster layoutIfNeeded];}
    if(cell.poster.defersContents&&!cell.poster.contentsPrepared){
        if(!cell.skeleton){cell.skeleton=[[RWPosterSkeleton alloc]initWithFrame:cell.contentView.bounds];[cell.contentView addSubview:cell.skeleton];}cell.skeleton.landscape=self.landscape;cell.skeleton.entity=NO;cell.skeleton.hidden=NO;[cell.skeleton setNeedsLayout];
        if(self.onContentNeeded)self.onContentNeeded();
    }
    if(self.reviewMode)[cell.poster loadArtwork];
    // A loaded record can replace a skeleton in an already-visible cell,
    // without another willDisplay callback. Start its entity artwork now.
    else if([cell.poster isKindOfClass:RWEntityCard.class])[cell.poster loadArtworkIfVisible];
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)path {RWPosterCell *cell=[self dequeueReusableCellWithReuseIdentifier:@"poster" forIndexPath:path];[self configureCell:cell at:path];return cell;}
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)path{return [self cardSize];}
#include "RWPosterFooterGeometry.inc"
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout referenceSizeForHeaderInSection:(NSInteger)section{return self.horizontal?CGSizeZero:CGSizeMake(self.bounds.size.width,self.headerView.bounds.size.height);}
- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)path {if([kind isEqual:UICollectionElementKindSectionHeader]){UICollectionReusableView *view=[self dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"header" forIndexPath:path];for(UIView *child in view.subviews)if(child!=self.headerView)[child removeFromSuperview];if(self.headerView)[view addSubview:self.headerView];return view;}RWFeedFooter *footer=[self dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"footer" forIndexPath:path];[self configureFooter:footer];return footer;}
- (void)configureFooter:(RWFeedFooter *)footer {
    footer.horizontal=self.horizontal;footer.skeleton.landscape=self.landscape;footer.skeleton.hidden=!(_loading&&self.horizontal);footer.spinner.hidden=!_loading||self.horizontal;_loading&&!self.horizontal?[footer.spinner startAnimating]:[footer.spinner stopAnimating];
    footer.hasError=(_error.length||_rangeError.length)&&!_loading;footer.button.hidden=_loading||(!_more&&!_error.length&&!_rangeError.length);footer.label.hidden=(_loading&&self.horizontal)||(!footer.button.hidden&&!footer.hasError);
    footer.label.text=_loading?@"Loading…":footer.hasError?(_rangeError.length?_rangeError:_error):[self recordCount]?@"You’re all caught up":self.emptyMessage?:@"";footer.label.numberOfLines=2;[footer setNeedsLayout];
    NSString *title=(_error.length||_rangeError.length)?@"Try again":@"Load more";[footer.button setTitle:title forState:UIControlStateNormal];footer.button.accessibilityLabel=title;
    if(self.horizontal){footer.skeleton.hidden=YES;footer.label.hidden=YES;footer.spinner.hidden=!_loading;_loading?[footer.spinner startAnimating]:[footer.spinner stopAnimating];footer.button.hidden=_loading||!footer.hasError;[footer.button setTitle:@"" forState:UIControlStateNormal];[footer.button icon:@"rotate-cw"];footer.button.backgroundColor=UIColor.clearColor;footer.button.layer.borderWidth=0;footer.button.accessibilityLabel=@"Retry loading titles";}
    __weak RWFeedFooter *weakFooter=footer;__weak RWPosterCollection *weak=self;footer.button.action=^{RWPosterCollection *view=weak;if(!view)return;view->_manualRequests++;view->_horizontalIntent=YES;if(view->_rangeError.length){view->_rangeError=nil;[view requestVisibleRecords];[view configureFooter:weakFooter];}else if(view.onLoadMore){if(view.horizontal)view->_horizontalRequestCommitted=YES;view.onLoadMore(YES);}};
}
#include "RWFeedContinuation.inc"
- (NSDictionary *)continuationDiagnostics {
    NSMutableArray *visible=[NSMutableArray new],*footers=[NSMutableArray new];NSUInteger slots=self.indexPathsForVisibleItems.count;
    for(NSIndexPath *path in [self.indexPathsForVisibleItems sortedArrayUsingSelector:@selector(compare:)]){RWPosterCell *cell=(RWPosterCell *)[self cellForItemAtIndexPath:path];if(cell.record)[visible addObject:@{@"index":@(path.item),@"id":RWID(cell.record),@"type":cell.record[@"type"]?:@""}];}
    for(RWFeedFooter *footer in [self visibleSupplementaryViewsOfKind:UICollectionElementKindSectionFooter])[footers addObject:@{@"button":footer.button.hidden?@"":footer.button.currentTitle?:@"",@"label":footer.label.hidden?@"":footer.label.text?:@"",@"spinner":@(!footer.spinner.hidden),@"button_visible":@(!footer.button.hidden),@"width":@(footer.bounds.size.width)}];
    return @{@"position_anchor":[self positionAnchor]?:@{},@"range_loading":@(_rangeLoading),@"updating":@(_updating),@"visible_slots":@(slots),@"pending_cells":@(slots-visible.count),@"prepared_visible":@([self visiblePreparedCount]),@"position_restore_pending":_pendingFeedPosition?:@{},@"count":@([self recordCount]),@"cursor":@(_cursor),@"loading":@(_loading),@"more":@(_more),@"automatic":@(_automatic),@"paused":@(self.continuationPaused),@"error":_rangeError?:_error?:@"",@"auto_requests":@(_automaticRequests),@"manual_requests":@(_manualRequests),@"offset":@(self.horizontal?self.contentOffset.x:self.contentOffset.y),@"horizontal":@(self.horizontal),@"horizontal_intent":@(_horizontalIntent),@"horizontal_request_committed":@(_horizontalRequestCommitted),@"header_height":@(self.headerView.bounds.size.height),@"context":_feed.context?:@"",@"visible":visible,@"footers":footers};
}
- (void)loadVisibleArtwork {for(RWPosterCell *cell in self.visibleCells)self.reviewMode?[cell.poster loadArtwork]:[cell.poster loadArtworkIfVisible];if(self.onContentNeeded&&[self hasPendingVisibleContent])self.onContentNeeded();}
- (BOOL)hasPendingVisibleContent {for(RWPosterCell *cell in self.visibleCells)if(cell.poster.defersContents&&!cell.poster.contentsPrepared&&[cell.poster artworkVisible])return YES;return NO;}
- (NSUInteger)visiblePreparedCount {NSUInteger count=0;for(RWPosterCell *cell in self.visibleCells)if(cell.poster.contentsPrepared&&[cell.poster artworkVisible])count++;return count;}
- (BOOL)prepareNextVisibleContent {
    BOOL moving=NO;for(UIView *parent=self;parent;parent=parent.superview)if([parent isKindOfClass:UIScrollView.class]){UIScrollView *s=(UIScrollView *)parent;moving|=s.tracking||s.dragging||s.decelerating;}
    double now=NSProcessInfo.processInfo.systemUptime;
    for(NSIndexPath *path in [self.indexPathsForVisibleItems sortedArrayUsingSelector:@selector(compare:)]){
        RWPosterCell *cell=(RWPosterCell *)[self cellForItemAtIndexPath:path];RWPoster *poster=cell.poster;
        if(!poster||!poster.defersContents||poster.contentsPrepared||![poster artworkVisible])continue;
        // Recheck current Kids/hidden permissions at deferred execution time.
        if(!PermitsCard(cell.record)){[poster cancelArtwork];[poster removeFromSuperview];cell.poster=nil;cell.record=nil;cell.presentation=nil;cell.skeleton.hidden=YES;continue;}
        if(moving&&(!cell.visibleSince||now-cell.visibleSince<.12))continue;
        if([poster prepareVisibleContents]){cell.skeleton.hidden=YES;[poster loadArtworkIfVisible];return YES;}
    }return NO;
}
- (void)cancelVisibleArtwork {for(RWPosterCell *cell in self.visibleCells)[cell.poster cancelArtwork];}
- (NSSet *)preparationIDs {
    if(!self.window||_feed||_placeholders)return [NSSet set];
    NSUInteger first=NSNotFound,last=0;for(NSIndexPath *p in self.indexPathsForVisibleItems){first=MIN(first,(NSUInteger)p.item);last=MAX(last,(NSUInteger)p.item);}
    NSRange range=RWFeedVisibleRange(_items.count,first,last,YES);NSMutableSet *ids=[NSMutableSet new];
    for(NSUInteger i=range.location;i<NSMaxRange(range);i++){NSString *key=RWID(_items[i]);if(key.length)[ids addObject:key];}return ids;
}
- (NSUInteger)visiblePendingCount {NSUInteger count=0;if(self.window&&!_feed)for(NSIndexPath *p in self.indexPathsForVisibleItems)if((NSUInteger)p.item<_items.count&&[_items[p.item][@"homePreparationPending"]boolValue])count++;return count;}
- (NSArray *)visibleMetadata {NSMutableArray *out=[NSMutableArray new];for(RWPosterCell *cell in self.visibleCells){RWPoster *p=cell.poster;if(!p||!p.window)continue;CGRect visible=[p convertRect:p.bounds toView:p.window];for(UIView *parent=p.superview;parent;parent=parent.superview)if(parent.clipsToBounds||parent==p.window)visible=CGRectIntersection(visible,[parent convertRect:parent.bounds toView:p.window]);if(!CGRectIsNull(visible)&&visible.size.width*visible.size.height>=p.bounds.size.width*p.bounds.size.height*.5)[out addObject:p.meta];}return out;}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {_pendingFeedPosition=nil;if(self.horizontal){_horizontalIntent=YES;_horizontalRequestCommitted=NO;[self retryContinuationFromGesture];[self considerMore];}}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {if(self.onScroll)self.onScroll(self.contentOffset);[self requestVisibleRecords];[self considerMore];}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {if(!decelerate){[self loadVisibleArtwork];if(self.onScrollSettled)self.onScrollSettled();}}
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {[self loadVisibleArtwork];[self considerMore];if(self.onScrollSettled)self.onScrollSettled();}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {[self loadVisibleArtwork];[self considerMore];if(self.onScrollSettled)self.onScrollSettled();}
- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)path {[(RWPosterCell *)cell setVisibleSince:0];[[(RWPosterCell *)cell poster]cancelArtwork];}
- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)path {RWPosterCell *posterCell=(RWPosterCell *)cell;posterCell.visibleSince=NSProcessInfo.processInfo.systemUptime;[posterCell.poster loadArtworkIfVisible];[self scheduleVisibleRecords];if(self.onContentNeeded&&posterCell.poster.defersContents&&!posterCell.poster.contentsPrepared)self.onContentNeeded();}
- (void)didMoveToWindow {[super didMoveToWindow];[self scheduleVisibleRecords];[self loadVisibleArtwork];[self considerMore];}
@end
