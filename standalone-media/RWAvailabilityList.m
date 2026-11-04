#import "RWReminderPolicy.h"
#import "RWAvailabilityList.h"
#import "RWHomePresentation.h"
#import "RWUpcomingPolicy.h"
#import "RWDiscoveryMetadataPolicy.h"
@interface RWAvailabilityCell : UITableViewCell
@property(nonatomic,strong) RWPoster *poster;
@property(nonatomic,strong) UILabel *name, *status, *type, *summary;
@property(nonatomic,strong) RWButton *follow;
@property(nonatomic,strong) NSDictionary *meta;
@end
@implementation RWAvailabilityCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuse {
    if((self=[super initWithStyle:style reuseIdentifier:reuse])){self.backgroundColor=UIColor.clearColor;self.selectionStyle=UITableViewCellSelectionStyleNone;
        self.name=RWLabel(@"",20,UIFontWeightSemibold,RWColor(0xf5f2eb));self.name.numberOfLines=2;[self.contentView addSubview:self.name];
        self.type=RWLabel(@"",12,UIFontWeightSemibold,RWColor(0x9aa8ba));[self.contentView addSubview:self.type];
        self.summary=RWLabel(@"",13,UIFontWeightRegular,RWColor(0x929faf));self.summary.numberOfLines=2;[self.contentView addSubview:self.summary];
        self.status=RWLabel(@"",15,UIFontWeightRegular,RWColor(0xaeb8c5));self.status.numberOfLines=2;[self.contentView addSubview:self.status];
        self.follow=[RWButton text:@"Remind me" action:nil];[self.follow appearance:NO];[self.contentView addSubview:self.follow];
    }return self;
}
- (void)layoutSubviews {[super layoutSubviews];CGFloat width=self.bounds.size.width,imageW=MIN(420,(width-88)*.5),x=32+imageW+24,remaining=width-x-32;self.poster.frame=CGRectMake(32,0,imageW,imageW*.5625);self.type.frame=CGRectMake(x,0,remaining,18);self.name.frame=CGRectMake(x,25,remaining,52);self.status.frame=CGRectMake(x,80,remaining,40);self.summary.frame=CGRectMake(x,124,remaining,36);self.follow.frame=CGRectMake(x,172,MIN(194,remaining),44);}
- (void)prepareForReuse {[super prepareForReuse];self.poster.action=nil;self.follow.action=nil;}
@end
@interface RWAvailabilityList () <UITableViewDelegate,UITableViewDataSource>
@end
@implementation RWAvailabilityList {NSArray *_items,*_sections,*_sectionTitles;BOOL _loading,_moreRequested;NSString *_lastMode;NSMutableArray *_anchorSamples;}
- (NSArray *)items {return _items;}
- (NSDictionary *)diagnostics {return @{@"anchor_samples":[_anchorSamples copy]?:@[],@"mode":self.reminderMode?:@"",@"items":@(_items.count)};}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame style:UITableViewStylePlain])){_items=@[];_sections=@[];_sectionTitles=@[];self.backgroundColor=UIColor.clearColor;self.separatorStyle=UITableViewCellSeparatorStyleNone;self.rowHeight=260;self.estimatedRowHeight=0;self.dataSource=self;self.delegate=self;
        [self registerClass:RWAvailabilityCell.class forCellReuseIdentifier:@"availability"];
        UILabel *end=RWLabel(@"You’re all caught up",13,UIFontWeightRegular,RWColor(0x8f9baa));end.textAlignment=NSTextAlignmentCenter;end.frame=CGRectMake(0,0,frame.size.width,64);self.tableFooterView=end;
    }return self;
}
- (void)updateItems:(NSArray *)items {
    NSMutableArray *primary=[NSMutableArray new],*world=[NSMutableArray new],*episodes=[NSMutableArray new],*worldEpisodes=[NSMutableArray new];
    for(NSDictionary *m in items?:@[]){BOOL international=self.separatesWorldCinema&&[[RWDiscoveryMetadataPolicy languageGroup:m[@"discovery"]]isEqual:@"world"],scheduled=self.separatesWorldCinema&&[RWUpcomingPolicy scheduled:m now:NSDate.date.timeIntervalSince1970];[(scheduled?(international?worldEpisodes:episodes):(international?world:primary))addObject:m];}
    NSMutableArray *sections=[NSMutableArray new],*titles=[NSMutableArray new],*next=[NSMutableArray new];NSArray *groups=@[episodes,primary,worldEpisodes,world],*labels=@[@"New episodes",self.separatesWorldCinema?@"On the horizon":@"",@"International episodes",@"International releases"];
    for(NSUInteger i=0;i<groups.count;i++)if([groups[i]count]){[sections addObject:groups[i]];[titles addObject:labels[i]];[next addObjectsFromArray:groups[i]];}
    BOOL same=next.count==_items.count&&[_sectionTitles isEqual:titles]&&_sections.count==sections.count;for(NSUInteger i=0;same&&i<sections.count;i++)same=[_sections[i]count]==[sections[i]count];for(NSUInteger i=0;same&&i<next.count;i++)same=[RWID(next[i])isEqual:RWID(_items[i])];
    NSString *anchorID=nil;CGFloat anchorDelta=0;NSUInteger oldCount=_items.count;
    // The top is a position, not an attachment to the first partial result.
    // Preserve title identity only after scrolling away from it, so earlier
    // schedule results cannot push an untouched fresh page down the list.
    if(!same&&self.contentOffset.y>0.5&&[_lastMode isEqual:self.reminderMode]){NSArray *visible=[self.indexPathsForVisibleRows sortedArrayUsingSelector:@selector(compare:)];NSIndexPath *path=visible.firstObject;if(path){anchorID=RWID([self metaAtPath:path]);anchorDelta=self.contentOffset.y-[self rectForRowAtIndexPath:path].origin.y;}}
    _lastMode=[self.reminderMode copy];CGPoint offset=self.contentOffset;_items=next;_sections=sections;_sectionTitles=titles;if(!same)[self reloadData];else for(NSIndexPath *path in self.indexPathsForVisibleRows)[self configure:(RWAvailabilityCell *)[self cellForRowAtIndexPath:path] path:path];
    self.tableFooterView.hidden=!next.count;[self layoutIfNeeded];NSIndexPath *restored=nil;
    if(anchorID.length)for(NSUInteger section=0;section<_sections.count&&!restored;section++)for(NSUInteger row=0;row<[_sections[section]count];row++)if([RWID(_sections[section][row])isEqual:anchorID]){restored=[NSIndexPath indexPathForRow:row inSection:section];offset.y=[self rectForRowAtIndexPath:restored].origin.y+anchorDelta;break;}
    CGFloat target=MAX(0,MIN(offset.y,MAX(0,self.contentSize.height-self.bounds.size.height)));self.contentOffset=CGPointMake(0,target);
    if(restored){if(!_anchorSamples)_anchorSamples=[NSMutableArray new];[_anchorSamples addObject:@{@"id":anchorID,@"before_count":@(oldCount),@"after_count":@(next.count),@"before_delta":@(anchorDelta),@"after_delta":@(self.contentOffset.y-[self rectForRowAtIndexPath:restored].origin.y),@"clamped":@(fabs(target-offset.y)>.5)}];if(_anchorSamples.count>20)[_anchorSamples removeObjectAtIndex:0];}
    [self loadVisibleArtwork];
}
- (NSDictionary *)metaAtPath:(NSIndexPath *)path {return path.section<_sections.count&&path.row<[_sections[path.section]count]?_sections[path.section][path.row]:nil;}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table{return _sections.count;}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section{return [_sections[section]count];}
- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section{return [_sectionTitles[section]length]?42:0;}
- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {if(![_sectionTitles[section]length])return nil;UIView *header=[[UIView alloc]initWithFrame:CGRectMake(0,0,self.bounds.size.width,42)];header.backgroundColor=RWColor(0x0b1018);UILabel *label=RWLabel(_sectionTitles[section],15,UIFontWeightSemibold,RWColor(0xaeb8c5));label.frame=CGRectMake(32,0,self.bounds.size.width-64,32);[header addSubview:label];return header;}
- (void)setLoading:(BOOL)loading error:(NSString *)error retry:(void(^)(void))retry {
    _loading=loading;if(!loading)_moreRequested=NO;UIView *footer=[[UIView alloc]initWithFrame:CGRectMake(0,0,self.bounds.size.width,100)];
    if(error.length&&!loading){RWButton *button=[RWButton text:@"Couldn’t refresh releases · Retry" action:retry];[button appearance:NO];button.frame=CGRectMake(32,4,self.bounds.size.width-64,44);[footer addSubview:button];}
    else if(self.hasMore&&!loading){__weak RWAvailabilityList *weak=self;RWButton *more=[RWButton text:@"Scroll for later episodes" action:^{if(weak.onMore)weak.onMore();}];more.layer.borderWidth=0;more.frame=CGRectMake(32,4,self.bounds.size.width-64,40);[footer addSubview:more];}
    else{UILabel *label=RWLabel(loading?@"Looking ahead…":@"You’re all caught up",13,UIFontWeightRegular,RWColor(0x8f9baa));label.textAlignment=NSTextAlignmentCenter;label.frame=CGRectMake(0,0,self.bounds.size.width,40);[footer addSubview:label];}
    NSString *credit=self.scheduleDays?[NSString stringWithFormat:@"TVmaze · Episode dates for the next %lu days",(unsigned long)self.scheduleDays]:@"Episode dates · TVmaze";
    RWButton *source=[RWButton text:credit action:^{[UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://www.tvmaze.com"]];}];source.titleLabel.font=[UIFont systemFontOfSize:12];source.layer.borderWidth=0;source.frame=CGRectMake(32,48,self.bounds.size.width-64,40);[footer addSubview:source];source.hidden=!self.scheduleDays;self.tableFooterView=footer;
}
- (void)loadMoreIfNearEnd {
    if(self.hasMore&&!_loading&&!_moreRequested&&self.onMore&&self.contentOffset.y+self.bounds.size.height>=self.contentSize.height-250){_moreRequested=YES;self.onMore();}
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {if(self.tracking||self.dragging||self.decelerating)[self loadMoreIfNearEnd];}
- (void)configure:(RWAvailabilityCell *)cell path:(NSIndexPath *)path {
    NSDictionary *meta=[self metaAtPath:path];if(!cell||!meta)return;RewindStore *s=[RewindStore shared];cell.contentView.hidden=![s allowed:meta];if(cell.contentView.hidden){cell.follow.action=nil;cell.poster.action=nil;return;}
    if(![cell.meta isEqual:meta]){[cell.poster removeFromSuperview];cell.meta=meta;cell.poster=[[RWPoster alloc]initWithMeta:meta width:MIN(420,(self.bounds.size.width-88)*.5) landscape:YES];cell.poster.hidesArtworkBadges=YES;cell.poster.clipsToBounds=YES;[cell.contentView addSubview:cell.poster];}
    cell.name.text=RWString(meta[@"name"]);cell.summary.text=RWString(meta[@"description"]);cell.type.text=[meta[@"type"]isEqual:@"series"]?@"SERIES":@"FILM";NSDictionary *a=[s availability:meta];NSString *status=RWString(a[@"label"]);
    NSString *rating=[RWHomePresentation cardText:meta][@"rating"];if(rating.length)cell.type.text=[cell.type.text stringByAppendingFormat:@" · %@",rating];
    if([RWUpcomingPolicy scheduled:meta now:NSDate.date.timeIntervalSince1970])status=[RWUpcomingPolicy scheduleLabel:meta];
    else if([a[@"state"]isEqual:@"upcoming"]&&RWString(meta[@"released"]).length>=10){NSString *day=[meta[@"released"]substringToIndex:10];NSDateFormatter *format=[NSDateFormatter new];format.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];format.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];format.dateFormat=@"yyyy-MM-dd";format.lenient=NO;NSDate *date=[format dateFromString:day];if(date&&[[format stringFromDate:date]isEqual:day]){format.dateFormat=@"d MMM yyyy";status=[@"Expected " stringByAppendingString:[format stringFromDate:date]];}}
    else if([a[@"state"]isEqual:@"upcoming"]&&RWString(meta[@"releaseInfo"]).length)status=[status stringByAppendingFormat:@" · %@ · Date to be announced",RWString(meta[@"releaseInfo"])];
    if(!status.length)status=[a[@"discovery_eligible"]boolValue]?@"Playback options found":@"Waiting for playback availability";cell.status.text=status;
    NSDictionary *reminder=[RWReminderPolicy presentation:meta mode:self.reminderMode following:[s following:meta] watching:[s watchingAvailability:meta] alerts:[s.profile[@"episodeNotifications"]boolValue]];[cell.follow setTitle:reminder[@"title"] forState:UIControlStateNormal];[cell.follow icon:reminder[@"icon"]];
    __weak RWAvailabilityList *weak=self;__weak RWButton *followButton=cell.follow;cell.follow.action=^{if(weak.onFollow&&[s allowed:meta])weak.onFollow(meta,followButton);};cell.poster.action=^(NSDictionary *m){if(weak.onSelect&&[s allowed:m])weak.onSelect(m);};
    [cell setNeedsLayout];[cell layoutIfNeeded];
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {RWAvailabilityCell *cell=[table dequeueReusableCellWithIdentifier:@"availability" forIndexPath:path];[self configure:cell path:path];return cell;}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {NSDictionary *meta=[self metaAtPath:path];if(meta&&self.onSelect&&[[RewindStore shared]allowed:meta])self.onSelect(meta);}
- (void)tableView:(UITableView *)table willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)path {RWPoster *poster=((RWAvailabilityCell *)cell).poster;self.reviewMode?[poster loadArtwork]:[poster loadArtworkIfVisible];}
- (void)loadVisibleArtwork {for(RWAvailabilityCell *cell in self.visibleCells)self.reviewMode?[cell.poster loadArtwork]:[cell.poster loadArtworkIfVisible];}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {[self loadVisibleArtwork];[self loadMoreIfNearEnd];}
- (void)didMoveToWindow {[super didMoveToWindow];[self loadVisibleArtwork];}
@end
