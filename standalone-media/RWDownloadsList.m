#import "RWDownloadsList.h"
#import "RWArtworkPolicy.h"
@interface RWDownloadCell : UITableViewCell
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIImageView *art;
@property(nonatomic,strong) UILabel *name,*kind,*status;
@property(nonatomic,strong) RWButton *resume,*keep,*remove;
@property(nonatomic,strong) NSDictionary *record;
@property(nonatomic,assign) BOOL artRequested;
- (void)loadArtwork;
@end
@implementation RWDownloadCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuse {
    if((self=[super initWithStyle:style reuseIdentifier:reuse])){self.backgroundColor=UIColor.clearColor;self.selectionStyle=UITableViewCellSelectionStyleNone;self.panel=RWPanel(CGRectZero);[self.contentView addSubview:self.panel];
        UIImageView *placeholder=[[UIImageView alloc]initWithImage:RWIcon(@"film",32,RWColor(0x66778b))];placeholder.frame=CGRectMake(78,46,32,32);[self.panel addSubview:placeholder];self.art=[[UIImageView alloc]initWithFrame:CGRectMake(14,14,160,90)];self.art.contentMode=UIViewContentModeScaleAspectFill;self.art.clipsToBounds=YES;self.art.layer.cornerRadius=6;[self.panel addSubview:self.art];
        self.name=RWLabel(@"",19,UIFontWeightSemibold,RWColor(0xf5f2eb));self.name.numberOfLines=2;[self.panel addSubview:self.name];self.kind=RWLabel(@"",12,UIFontWeightMedium,RWColor(0xa9b4c2));[self.panel addSubview:self.kind];self.status=RWLabel(@"",13,UIFontWeightRegular,RWColor(0xc2cbd7));[self.panel addSubview:self.status];
        self.resume=[RWButton text:@"Resume" action:nil];[self.resume appearance:YES];[self.resume icon:@"play"];[self.panel addSubview:self.resume];self.keep=[RWButton text:@"Keep" action:nil];[self.keep appearance:NO];[self.panel addSubview:self.keep];self.remove=[RWButton text:@"Remove" action:nil];[self.remove appearance:NO];[self.panel addSubview:self.remove];
    }return self;
}
- (void)layoutSubviews {[super layoutSubviews];CGFloat w=self.bounds.size.width-64;self.panel.frame=CGRectMake(32,0,w,168);self.name.frame=CGRectMake(194,13,w-210,47);self.kind.frame=CGRectMake(194,63,w-210,18);self.status.frame=CGRectMake(194,85,w-210,20);self.resume.frame=CGRectMake(194,112,122,44);self.keep.frame=CGRectMake(328,112,90,44);self.remove.frame=CGRectMake(430,112,110,44);}
- (void)prepareForReuse {[super prepareForReuse];self.resume.action=nil;self.keep.action=nil;self.remove.action=nil;self.record=nil;self.artRequested=NO;[[RewindStore shared]image:@"" into:self.art];}
- (void)loadArtwork {if(self.artRequested||!self.window||self.contentView.hidden)return;self.artRequested=YES;[[RewindStore shared]artwork:[RWArtworkPolicy URLsForMeta:self.record[@"meta"] landscape:YES] role:@"backdrop" identity:RWID(self.record[@"meta"]) into:self.art completion:nil];}
@end
@interface RWDownloadsList () <UITableViewDelegate,UITableViewDataSource>
@end
@implementation RWDownloadsList {
    NSArray *_items;NSDictionary *_snapshot,*_pending;BOOL _loading;UILabel *_space,*_note,*_footerLabel;RWButton *_clear,*_footerAction;UIActivityIndicatorView *_spinner;UIView *_header,*_footer;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame style:UITableViewStylePlain])){_items=@[];self.actionsEnabled=YES;self.backgroundColor=UIColor.clearColor;self.separatorStyle=UITableViewCellSeparatorStyleNone;self.rowHeight=184;self.estimatedRowHeight=0;self.dataSource=self;self.delegate=self;[self registerClass:RWDownloadCell.class forCellReuseIdentifier:@"download"];
        _header=[[UIView alloc]initWithFrame:CGRectMake(0,0,frame.size.width,150)];_space=RWLabel(@"",14,UIFontWeightSemibold,RWColor(0xc5c9cf));[_header addSubview:_space];_note=RWLabel(@"Temporary streams use a 2 GB cache. Keep a download to retain it. Your watch progress stays saved when cached video is removed.",13,UIFontWeightRegular,RWColor(0x9da4ae));_note.numberOfLines=2;[_header addSubview:_note];_clear=[RWButton text:@"Clear temporary downloads" action:nil];[_clear appearance:NO];[_header addSubview:_clear];self.tableHeaderView=_header;
        _footer=[[UIView alloc]initWithFrame:CGRectMake(0,0,frame.size.width,132)];_footerLabel=RWLabel(@"",14,UIFontWeightRegular,RWColor(0xa9b4c2));_footerLabel.numberOfLines=2;_footerLabel.textAlignment=NSTextAlignmentCenter;[_footer addSubview:_footerLabel];_footerAction=[RWButton text:@"Browse films" action:nil];[_footerAction appearance:NO];[_footer addSubview:_footerAction];_spinner=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];[_footer addSubview:_spinner];self.tableFooterView=_footer;
    }return self;
}
- (void)layoutSubviews {[super layoutSubviews];CGFloat w=self.bounds.size.width;_space.frame=CGRectMake(33,6,w-66,22);_note.frame=CGRectMake(33,37,w-66,40);_clear.frame=CGRectMake(32,88,260,44);_footerLabel.frame=CGRectMake(32,8,w-64,44);_footerAction.frame=CGRectMake((w-190)/2,64,190,44);_spinner.center=CGPointMake(w/2,85);}
- (void)updateSnapshot:(NSDictionary *)snapshot loading:(BOOL)loading {
    if(self.dragging||self.decelerating){_pending=@{@"snapshot":snapshot?:@{},@"loading":@(loading)};return;}
    NSArray *next=snapshot[@"items"]?:@[];NSArray *visible=[self.indexPathsForVisibleRows sortedArrayUsingSelector:@selector(compare:)];NSIndexPath *first=visible.firstObject;NSString *anchor=first&&first.row<_items.count?_items[first.row][@"videoID"]:nil;CGFloat delta=first?self.contentOffset.y-[self rectForRowAtIndexPath:first].origin.y:0;CGPoint offset=self.contentOffset;
    BOOL same=next.count==_items.count;for(NSUInteger i=0;same&&i<next.count;i++)same=[next[i][@"videoID"]isEqual:_items[i][@"videoID"]];_items=[next copy];_snapshot=snapshot;_loading=loading;
    if(!same)[self reloadData];else for(NSIndexPath *path in self.indexPathsForVisibleRows)[self configure:(RWDownloadCell *)[self cellForRowAtIndexPath:path] path:path];
    _space.text=[snapshot[@"spaceKnown"]boolValue]?[NSString stringWithFormat:@"%.1f GB available",[snapshot[@"freeBytes"]doubleValue]/1073741824.]:@"Storage on this iPad";_clear.hidden=[RewindStore shared].restricted;_clear.enabled=self.actionsEnabled;
    __weak RWDownloadsList *weak=self;_clear.action=^{if(weak.onClear&&[weak.profileID isEqual:[RewindStore shared].state[@"activeProfile"]]&&![RewindStore shared].restricted)weak.onClear();};
    NSString *error=RWString(snapshot[@"error"]);_footerLabel.text=loading?@"Checking saved videos…":error.length?error:_items.count?@"You’re all caught up":@"No saved video yet. Start a film or episode to cache it here.";_footerAction.hidden=loading||(_items.count&&!error.length);[_footerAction setTitle:error.length?@"Try again":@"Browse films" forState:UIControlStateNormal];_footerAction.action=^{if(error.length){if(weak.onRetry)weak.onRetry();}else if(weak.onBrowse)weak.onBrowse();};loading?[_spinner startAnimating]:[_spinner stopAnimating];
    [self layoutIfNeeded];if(!same&&anchor.length){NSUInteger index=[_items indexOfObjectPassingTest:^BOOL(NSDictionary *r,NSUInteger i,BOOL *stop){return [r[@"videoID"]isEqual:anchor];}];if(index!=NSNotFound)offset.y=[self rectForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]].origin.y+delta;}
    self.contentOffset=CGPointMake(0,MAX(0,MIN(offset.y,MAX(0,self.contentSize.height-self.bounds.size.height))));[self loadVisibleArtwork];
}
- (BOOL)permits:(NSDictionary *)record {return [self.profileID isEqual:[RewindStore shared].state[@"activeProfile"]]&&[[RewindStore shared]allowed:record[@"meta"]];}
- (void)configure:(RWDownloadCell *)cell path:(NSIndexPath *)path {
    if(!cell||path.row>=_items.count)return;NSDictionary *record=_items[path.row],*meta=record[@"meta"];cell.contentView.hidden=![self permits:record];if(cell.contentView.hidden){cell.resume.action=nil;cell.keep.action=nil;cell.remove.action=nil;return;}
    if(![cell.record[@"meta"]isEqual:meta]){cell.artRequested=NO;[[RewindStore shared]image:@"" into:cell.art];}cell.record=record;
    cell.name.text=RWString(meta[@"name"]);NSString *kind=[meta[@"type"]isEqual:@"series"]?@"Series":@"Film";if(meta[@"season"]&&meta[@"episode"])kind=[kind stringByAppendingFormat:@" · S%@ E%@",meta[@"season"],meta[@"episode"]];if([record[@"reportedBytes"]doubleValue]>0)kind=[kind stringByAppendingFormat:@" · Last saved %.0f MB",[record[@"reportedBytes"]doubleValue]/1048576.];cell.kind.text=kind;
    cell.status.text=[NSString stringWithFormat:@"%@ · %@",[record[@"offlineVerified"]boolValue]?@"Available offline":@"Cached · may need internet",RWTime([record[@"position"]doubleValue])];[cell.keep setTitle:[record[@"kept"]boolValue]?@"Kept":@"Keep" forState:UIControlStateNormal];cell.resume.enabled=self.actionsEnabled;cell.keep.enabled=self.actionsEnabled;cell.remove.enabled=self.actionsEnabled;
    __weak RWDownloadsList *weak=self;cell.resume.action=^{if([weak permits:record]&&weak.onResume)weak.onResume(record);};cell.keep.action=^{if([weak permits:record]&&weak.onKeep)weak.onKeep(record);};cell.remove.action=^{if([weak permits:record]&&weak.onRemove)weak.onRemove(record);};[cell setNeedsLayout];
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section{return _items.count;}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {RWDownloadCell *cell=[table dequeueReusableCellWithIdentifier:@"download" forIndexPath:path];[self configure:cell path:path];return cell;}
- (void)tableView:(UITableView *)table didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)path {RWDownloadCell *row=(RWDownloadCell *)cell;[[RewindStore shared]cancelArtwork:row.art];row.artRequested=NO;}
- (void)tableView:(UITableView *)table willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)path {[(RWDownloadCell *)cell loadArtwork];}
- (void)loadVisibleArtwork {for(RWDownloadCell *cell in self.visibleCells)[cell loadArtwork];}
- (void)applyPending {NSDictionary *pending=_pending;_pending=nil;if(pending)[self updateSnapshot:pending[@"snapshot"] loading:[pending[@"loading"]boolValue]];[self loadVisibleArtwork];}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)view {[self applyPending];}
- (void)scrollViewDidEndDragging:(UIScrollView *)view willDecelerate:(BOOL)decelerate {if(!decelerate)[self applyPending];}
- (void)didMoveToWindow {[super didMoveToWindow];[self loadVisibleArtwork];}
@end
