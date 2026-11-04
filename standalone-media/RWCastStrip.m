#import "RWCastStrip.h"
#import "RWUIProbe.h"
#include <math.h>
// Test visibility through every clipping ancestor, including the vertical page.
static BOOL CastVisible(UIView *view) {
    if(!view.window||view.hidden||view.alpha<=0)return NO;
    CGRect visible=[view convertRect:view.bounds toView:view.window];
    for(UIView *parent=view.superview;parent;parent=parent.superview){if(parent.hidden||parent.alpha<=0)return NO;if(parent.clipsToBounds||parent==view.window)visible=CGRectIntersection(visible,[parent convertRect:parent.bounds toView:view.window]);}
    return !CGRectIsNull(visible)&&!CGRectIsEmpty(visible);
}
static BOOL CastMoving(UIView *view) {for(UIView *parent=view;parent;parent=parent.superview)if([parent isKindOfClass:UIScrollView.class]){UIScrollView *scroll=(UIScrollView *)parent;if(scroll.tracking||scroll.dragging||scroll.decelerating)return YES;}return NO;}
@interface RWCastCell : UICollectionViewCell
@property(nonatomic,strong) RWButton *button;
@property(nonatomic,strong) UIImageView *photo;
@property(nonatomic,strong) UILabel *initial,*name,*role;
@property(nonatomic,copy) NSDictionary *person;
@property(nonatomic,copy) void(^selectPerson)(NSDictionary *);
@property(nonatomic,assign) NSUInteger generation,attempts;
@property(nonatomic,assign) BOOL loading,scheduled;
@property(nonatomic,assign) double retryAfter;
@property(nonatomic,assign) double visibleSince;
- (void)bind:(NSDictionary *)person;
- (void)prepareContent;
- (void)loadPhoto;
- (void)suspend;
@end
@implementation RWCastCell {CALayer *_placeholder,*_namePlaceholder,*_rolePlaceholder;}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])){
        // Collection layout creates only fixed-size static shapes. The strip
        // builds the controls for one visible cell per scheduled slice.
        _placeholder=[CALayer layer];_namePlaceholder=[CALayer layer];_rolePlaceholder=[CALayer layer];
        for(CALayer *layer in @[_placeholder,_namePlaceholder,_rolePlaceholder]){layer.backgroundColor=RWColor(0x20242b).CGColor;layer.cornerRadius=4;[self.contentView.layer addSublayer:layer];}
        _placeholder.frame=CGRectMake(4,0,120,142);_placeholder.cornerRadius=10;_namePlaceholder.frame=CGRectMake(3,156,104,12);_rolePlaceholder.frame=CGRectMake(3,194,74,8);
        self.isAccessibilityElement=YES;self.accessibilityTraits=UIAccessibilityTraitButton;
    }return self;
}
- (void)prepareContent {
    if(_button||!_person||!CastVisible(self))return;
    double began=NSProcessInfo.processInfo.systemUptime;
        __weak RWCastCell *weak=self;_button=[RWButton text:@"" action:^{if(weak.selectPerson&&weak.person)weak.selectPerson(weak.person);}];_button.frame=CGRectMake(0,0,128,212);[self.contentView addSubview:_button];
        UIView *background=RWPanel(CGRectMake(4,0,120,142));background.userInteractionEnabled=NO;background.clipsToBounds=YES;background.layer.cornerRadius=10;[_button addSubview:background];
        _initial=RWLabel(@"",36,UIFontWeightLight,RWColor(0x798697));_initial.textAlignment=NSTextAlignmentCenter;_initial.frame=background.bounds;[background addSubview:_initial];
        _photo=[[UIImageView alloc]initWithFrame:background.bounds];_photo.contentMode=UIViewContentModeScaleAspectFill;_photo.clipsToBounds=YES;[background addSubview:_photo];
        _name=RWLabel(@"",14,UIFontWeightSemibold,RWColor(0xe4e8ee));_name.numberOfLines=2;_name.frame=CGRectMake(3,151,124,36);[_button addSubview:_name];
        _role=RWLabel(@"",12,UIFontWeightRegular,RWColor(0x9ca9b8));_role.frame=CGRectMake(3,191,124,20);[_button addSubview:_role];
    [_placeholder removeFromSuperlayer];[_namePlaceholder removeFromSuperlayer];[_rolePlaceholder removeFromSuperlayer];_placeholder=nil;_namePlaceholder=nil;_rolePlaceholder=nil;
    self.isAccessibilityElement=NO;[self updateLabels];
    [[RWUIProbe shared]work:@"cast_cell_content" started:began];
}
- (void)bind:(NSDictionary *)person {
    if([_person isEqual:person])return;
    NSString *oldURL=RWString(_person[@"image"]),*newURL=RWString(person[@"image"]);
    BOOL samePhoto=[oldURL isEqual:newURL]&&[RWString(_person[@"name"])isEqual:RWString(person[@"name"])];
    if(!samePhoto){[self suspend];_photo.image=nil;_attempts=0;_retryAfter=0;}
    _person=[person copy];[self updateLabels];
}
- (void)updateLabels {
    NSString *name=RWString(_person[@"name"]),*role=RWString(_person[@"role"]);_name.text=name;_role.text=role;_initial.text=[name substringToIndex:MIN((NSUInteger)1,name.length)];
    self.accessibilityLabel=[NSString stringWithFormat:@"%@, %@",name,role];
    _button.accessibilityLabel=[NSString stringWithFormat:@"%@, %@",name,_role.text];_button.accessibilityIdentifier=[@"RWCastPerson:" stringByAppendingString:name];
}
- (BOOL)accessibilityActivate {if(!self.selectPerson||!self.person)return NO;self.selectPerson(self.person);return YES;}
- (void)suspend {
    _generation++;_scheduled=NO;if(_loading)_attempts=0;_loading=NO;[[RewindStore shared]cancelArtwork:_photo];
}
- (void)requestPhoto {
    if(!_button||_loading||_photo.image||_attempts>=2||_retryAfter>NSProcessInfo.processInfo.systemUptime||!RWString(_person[@"image"]).length||!CastVisible(self))return;
    _loading=YES;_attempts++;NSUInteger generation=_generation;__weak RWCastCell *weak=self;
    NSString *identity=RWString(_person[@"personID"]);if(!identity.length)identity=RWString(_person[@"id"]);if(!identity.length)identity=RWString(_person[@"name"]);
    [[RewindStore shared]artwork:@[_person[@"image"]] role:@"portrait" identity:identity into:_photo completion:^(BOOL success){RWCastCell *cell=weak;if(!cell||cell.generation!=generation)return;cell.loading=NO;if(!success){cell.retryAfter=NSProcessInfo.processInfo.systemUptime+10;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC),dispatch_get_main_queue(),^{RWCastCell *cell=weak;if(cell&&cell.generation==generation)[cell loadPhoto];});}}];
}
- (void)loadPhoto {
    if(!_button||_loading||_scheduled||_photo.image||_attempts>=2||_retryAfter>NSProcessInfo.processInfo.systemUptime||!RWString(_person[@"image"]).length||!CastVisible(self))return;
    BOOL moving=NO;for(UIView *parent=self.superview;parent;parent=parent.superview)if([parent isKindOfClass:UIScrollView.class]){UIScrollView *scroll=(UIScrollView *)parent;moving|=scroll.tracking||scroll.dragging||scroll.decelerating;}
    if(!moving){[self requestPhoto];return;}_scheduled=YES;NSUInteger generation=_generation;__weak RWCastCell *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,120*NSEC_PER_MSEC),dispatch_get_main_queue(),^{RWCastCell *cell=weak;if(!cell||cell.generation!=generation)return;cell.scheduled=NO;[cell requestPhoto];});
}
- (void)prepareForReuse {[super prepareForReuse];[self suspend];self.visibleSince=0;self.selectPerson=nil;}
- (void)dealloc {[[RewindStore shared]cancelArtwork:_photo];}
@end

@interface RWCastStrip () <UICollectionViewDataSource,UICollectionViewDelegateFlowLayout>
@end
@implementation RWCastStrip {
    NSArray *_people,*_presented;UILabel *_credit;BOOL _needsApply,_updating,_hasOffset,_wasVisible;
    CGFloat _wantedOffset;double _lastPhotoPass;NSUInteger _created,_binds,_applies,_viewportPasses;
    NSUInteger _contentGeneration,_contentSlices,_contentBuilt;BOOL _contentScheduled;
}
- (instancetype)initWithScope:(NSString *)scope {
    if((self=[super initWithFrame:CGRectZero])){_scope=[scope copy];_people=@[];_presented=@[];
        UICollectionViewFlowLayout *layout=[UICollectionViewFlowLayout new];layout.scrollDirection=UICollectionViewScrollDirectionHorizontal;layout.itemSize=CGSizeMake(128,212);layout.minimumLineSpacing=16;layout.minimumInteritemSpacing=16;layout.sectionInset=UIEdgeInsetsMake(0,32,0,32);
        _rail=[[UICollectionView alloc]initWithFrame:CGRectZero collectionViewLayout:layout];_rail.backgroundColor=UIColor.clearColor;_rail.showsHorizontalScrollIndicator=NO;_rail.alwaysBounceHorizontal=YES;_rail.dataSource=self;_rail.delegate=self;[_rail registerClass:RWCastCell.class forCellWithReuseIdentifier:@"cast"];[self addSubview:_rail];
        _credit=RWLabel(@"",11,UIFontWeightRegular,RWColor(0x8e9bab));[self addSubview:_credit];
    }return self;
}
- (BOOL)updatePeople:(NSArray *)people {
    NSArray *bounded=people.count>12?[people subarrayWithRange:NSMakeRange(0,12)]:people?:@[];
    if([_people isEqualToArray:bounded])return NO;
    _people=[[NSArray alloc]initWithArray:bounded copyItems:YES];_needsApply=YES;
    NSMutableOrderedSet *providers=[NSMutableOrderedSet new];for(NSDictionary *person in _people)if(RWString(person[@"credit"]).length)[providers addObject:RWString(person[@"provider"])];
    _credit.text=providers.count?[NSString stringWithFormat:@"%@ · Tap a portrait to explore",[providers.array componentsJoinedByString:@" / "]]:@"";
    [self updateViewport];return YES;
}
- (void)restoreOffset:(CGFloat)offset {if(!isfinite(offset))return;_wantedOffset=MAX(0,offset);_hasOffset=YES;[self updateViewport];}
- (void)layoutSubviews {[super layoutSubviews];BOOL changed=_rail.bounds.size.width!=self.bounds.size.width;_rail.frame=CGRectMake(0,0,self.bounds.size.width,218);_credit.frame=CGRectMake(33,224,MAX(0,self.bounds.size.width-66),18);if(changed)[_rail.collectionViewLayout invalidateLayout];[self updateViewport];}
- (void)suspendArtwork {[self cancelContentPreparation];for(RWCastCell *cell in _rail.visibleCells)[cell suspend];}
- (BOOL)canPrepareContent {return CastVisible(_rail)&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive;}
- (BOOL)hasPendingVisibleContent {for(RWCastCell *cell in _rail.visibleCells)if(!cell.button&&cell.person&&CastVisible(cell))return YES;return NO;}
- (void)prepareNextVisibleContent {
    double began=NSProcessInfo.processInfo.systemUptime;BOOL moving=CastMoving(_rail);
    for(NSIndexPath *path in [_rail.indexPathsForVisibleItems sortedArrayUsingSelector:@selector(compare:)]){
        RWCastCell *cell=(RWCastCell *)[_rail cellForItemAtIndexPath:path];if(!cell||cell.button||!cell.person||!CastVisible(cell))continue;
        if(moving&&(!cell.visibleSince||began-cell.visibleSince<.12))continue;
        [cell prepareContent];if(cell.button){_contentBuilt++;[cell loadPhoto];}break;
    }
    _contentSlices++;[[RWUIProbe shared]work:@"cast_content_slice" started:began];
}
#include "RWCastContentScheduling.inc"
- (void)updateViewport {
    if(_updating)return;BOOL visible=CastVisible(_rail);if(!visible){if(_wasVisible)[self suspendArtwork];_wasVisible=NO;return;}_wasVisible=YES;
    if(_needsApply&&CastMoving(_rail))return;_updating=YES;double began=NSProcessInfo.processInfo.systemUptime;_viewportPasses++;BOOL appliedOffset=NO;
    if(_needsApply){CGFloat offset=_hasOffset?_wantedOffset:_rail.contentOffset.x;NSUInteger count=_presented.count;_presented=_people;_needsApply=NO;_applies++;
        if(count!=_presented.count)[_rail reloadData];else for(NSIndexPath *path in _rail.indexPathsForVisibleItems)[self configure:(RWCastCell *)[_rail cellForItemAtIndexPath:path] at:path];
        _wantedOffset=offset;_hasOffset=YES;
    }
    if(_hasOffset){[_rail layoutIfNeeded];[_rail setContentOffset:CGPointMake(MAX(0,MIN(_wantedOffset,MAX(0,_rail.contentSize.width-_rail.bounds.size.width))),0) animated:NO];_hasOffset=NO;appliedOffset=YES;}
    for(RWCastCell *cell in _rail.visibleCells)[cell loadPhoto];[self scheduleContentPreparation];_updating=NO;
    if(appliedOffset&&self.onOffset)self.onOffset(_rail.contentOffset.x);
    [[RWUIProbe shared]work:@"cast_viewport" started:began];
}
- (void)configure:(RWCastCell *)cell at:(NSIndexPath *)path {if((NSUInteger)path.item>=_presented.count)return;_binds++;[cell bind:_presented[path.item]];__weak RWCastStrip *weak=self;cell.selectPerson=^(NSDictionary *person){if(weak.onSelect)weak.onSelect(person);};}
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section {return _presented.count;}
- (UICollectionViewCell *)collectionView:(UICollectionView *)view cellForItemAtIndexPath:(NSIndexPath *)path {RWCastCell *cell=[view dequeueReusableCellWithReuseIdentifier:@"cast" forIndexPath:path];if(!cell.tag){cell.tag=8201;_created++;}[self configure:cell at:path];return cell;}
- (void)collectionView:(UICollectionView *)view willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)path {[(RWCastCell *)cell setVisibleSince:NSProcessInfo.processInfo.systemUptime];[(RWCastCell *)cell loadPhoto];[self scheduleContentPreparation];}
- (void)collectionView:(UICollectionView *)view didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)path {[(RWCastCell *)cell setVisibleSince:0];[(RWCastCell *)cell suspend];}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {if(!_updating&&!_hasOffset&&self.onOffset)self.onOffset(scrollView.contentOffset.x);double now=NSProcessInfo.processInfo.systemUptime;if(now-_lastPhotoPass>.1){_lastPhotoPass=now;[self updateViewport];}}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {if(!decelerate)[self updateViewport];}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {[self updateViewport];}
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {[self updateViewport];}
- (void)didMoveToWindow {[super didMoveToWindow];if(self.window)[self updateViewport];else[self suspendArtwork];}
- (NSDictionary *)diagnostics {
    NSMutableArray *visible=[NSMutableArray new];NSUInteger photos=0;
    for(NSIndexPath *path in [_rail.indexPathsForVisibleItems sortedArrayUsingSelector:@selector(compare:)]){RWCastCell *cell=(RWCastCell *)[_rail cellForItemAtIndexPath:path];if(CastVisible(cell)){[visible addObject:@{@"index":@(path.item),@"name":RWString(cell.person[@"name"]),@"photo":@(cell.photo.image!=nil)}];photos+=cell.photo.image!=nil;}}
    return @{@"scope":self.scope?:@"",@"people":@(_people.count),@"presented":@(_presented.count),@"created_cells":@(_created),@"binds":@(_binds),@"applies":@(_applies),@"viewport_passes":@(_viewportPasses),@"offset":@(_rail.contentOffset.x),@"maximum_offset":@(MAX(0,_rail.contentSize.width-_rail.bounds.size.width)),@"visible":visible,@"visible_photos":@(photos),@"pending":@(_needsApply),@"content_slices":@(_contentSlices),@"content_built":@(_contentBuilt),@"content_pending":@([self hasPendingVisibleContent]),@"content_scheduled":@(_contentScheduled)};
}
@end
