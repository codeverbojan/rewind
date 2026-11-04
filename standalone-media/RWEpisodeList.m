#import "RWEpisodeList.h"
#import "RewindUI.h"
#import "RWTVPolicy.h"
#import "RWViewport.h"
@interface RWEpisodeCell : UIView
@property(nonatomic,strong) NSDictionary *episode;
@property(nonatomic,copy) void(^play)(NSDictionary *episode);
@property(nonatomic,copy) void(^options)(NSDictionary *episode,UIView *anchor);
- (void)configure:(NSDictionary *)episode record:(NSDictionary *)record next:(BOOL)next;
- (BOOL)loadImage;
- (void)cancelImage;
- (BOOL)imageLoaded;
- (NSDictionary *)progressSnapshot;
@end
@implementation RWEpisodeCell {
    RWButton *_body,*_more;UIImageView *_thumb;UILabel *_title,*_description,*_note,*_artLabel;UIProgressView *_progress;BOOL _released,_imageRequested;NSUInteger _imageAttempts,_binding;double _retryAfter;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])){__weak RWEpisodeCell *weak=self;
        _body=[RWButton text:@"" action:^{RWEpisodeCell *cell=weak;if(cell->_released&&cell.play)cell.play(cell.episode);}];_body.layer.cornerRadius=12;_body.clipsToBounds=YES;[self addSubview:_body];
        _thumb=[[UIImageView alloc]initWithFrame:CGRectZero];_thumb.contentMode=UIViewContentModeScaleAspectFill;_thumb.clipsToBounds=YES;_thumb.layer.cornerRadius=7;_thumb.backgroundColor=RWColor(0x28313b);[_body addSubview:_thumb];
        _artLabel=RWLabel(@"Series artwork",10,UIFontWeightMedium,UIColor.whiteColor);_artLabel.backgroundColor=[UIColor colorWithWhite:0 alpha:.65];_artLabel.textAlignment=NSTextAlignmentCenter;_artLabel.hidden=YES;[_body addSubview:_artLabel];
        _title=RWLabel(@"",17,UIFontWeightSemibold,RWColor(0xf4f1eb));_title.numberOfLines=2;[_body addSubview:_title];
        _description=RWLabel(@"",13,UIFontWeightRegular,RWColor(0xa9b3c0));_description.numberOfLines=2;[_body addSubview:_description];
        _note=RWLabel(@"",12,UIFontWeightMedium,RWColor(0xadb7c5));[_body addSubview:_note];
        _progress=[[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleDefault];_progress.progressTintColor=RWColor(0xff6847);_progress.trackTintColor=RWColor(0x34404f);[_body addSubview:_progress];
        _more=[RWButton text:@"•••" action:^{RWEpisodeCell *cell=weak;if(cell.options)cell.options(cell.episode,cell->_more);}];_more.accessibilityLabel=@"Episode options";[self addSubview:_more];
    }return self;
}
- (void)layoutSubviews {[super layoutSubviews];CGFloat w=self.bounds.size.width;_body.frame=self.bounds;_thumb.frame=CGRectMake(12,12,188,106);_artLabel.frame=CGRectMake(12,98,188,20);_title.frame=CGRectMake(218,12,w-308,43);_description.frame=CGRectMake(218,61,w-248,37);_note.frame=CGRectMake(218,111,w-248,22);_progress.frame=CGRectMake(12,129,188,3);_more.frame=CGRectMake(w-60,9,48,48);}
- (void)configure:(NSDictionary *)episode record:(NSDictionary *)record next:(BOOL)next {
    self.episode=episode;_released=[RWTVPolicy released:episode now:NSDate.date];BOOL completed=[record[@"completed"]boolValue];_imageRequested=NO;_imageAttempts=0;_retryAfter=0;_binding++;_artLabel.hidden=YES;
    // Clear the image's delivery identity before reuse; an old request cannot paint the new row.
    [[RewindStore shared]image:@"" into:_thumb];
    _body.backgroundColor=RWColor(next?0x242c36:0x171d25);
    _body.accessibilityLabel=[NSString stringWithFormat:@"Episode %@, %@, %@",episode[@"episode"],RWString(episode[@"name"]?:episode[@"title"]),completed?@"Watched":_released?@"Play":@"Not yet released"];
    _title.text=[NSString stringWithFormat:@"%@. %@",episode[@"episode"],RWString(episode[@"name"]?:episode[@"title"])];_description.text=RWString(episode[@"overview"]?:episode[@"description"]);
    double position=[record[@"position"]doubleValue],duration=[record[@"duration"]doubleValue];
    _note.text=completed?@"Watched":position>3?[NSString stringWithFormat:@"%@ watched%@",RWTime(position),duration>position?[NSString stringWithFormat:@" · %@ left",RWTime(duration-position)]:@""]:(_released?@"Play episode":@"Not yet released");
    _note.textColor=RWColor(completed?0x8ec4ab:0xadb7c5);_progress.progress=completed?1:(duration>0?MIN(1,position/duration):0);_more.hidden=!_released;
}
- (void)cancelImage {[[RewindStore shared]cancelArtwork:_thumb];_imageRequested=NO;_imageAttempts=0;}
- (BOOL)imageLoaded {return _thumb.image!=nil;}
- (NSDictionary *)progressSnapshot {return @{@"id":self.episode[@"id"]?:@"",@"note":_note.text?:@"",@"progress":@(_progress.progress),@"accessibility":_body.accessibilityLabel?:@""};}
- (BOOL)loadImage {
    [self layoutIfNeeded];
    if(_imageRequested||_imageAttempts>=2||NSProcessInfo.processInfo.systemUptime<_retryAfter)return NO;_imageRequested=YES;_imageAttempts++;NSUInteger binding=_binding;__weak RWEpisodeCell *weak=self;
    void(^finish)(BOOL)=^(BOOL success){RWEpisodeCell *cell=weak;if(!cell||cell->_binding!=binding)return;if(!success){cell->_imageRequested=NO;cell->_retryAfter=NSProcessInfo.processInfo.systemUptime+10;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC),dispatch_get_main_queue(),^{RWEpisodeCell *current=weak;if(!current||current->_binding!=binding||!current.window)return;CGRect r=[current convertRect:current.bounds toView:current.window];if(CGRectIntersectsRect(r,current.window.bounds))[current loadImage];});}};
    void(^fallback)(void)=^{RWEpisodeCell *cell=weak;if(!cell||cell->_binding!=binding)return;[[RewindStore shared]artwork:cell.episode[@"rewindArtwork"]?:@[] role:@"episode" identity:RWString(cell.episode[@"id"]) into:cell->_thumb completion:^(BOOL success){RWEpisodeCell *c=weak;if(c&&c->_binding==binding)c->_artLabel.hidden=!success;finish(success);}];};
    NSString *url=RWString(self.episode[@"thumbnail"]);if(url.length)[[RewindStore shared]artwork:@[url] role:@"episode" identity:RWString(self.episode[@"id"]) into:_thumb completion:^(BOOL success){if(success)finish(YES);else fallback();}];else fallback();return YES;
}
@end
@implementation RWEpisodeList {
    NSArray *_episodes;NSDictionary *_history;NSString *_nextID;NSMutableDictionary *_cells;NSMutableArray *_reuse;NSUInteger _created,_peak,_imageLoads;double _lastUpdate;
}
- (instancetype)initWithEpisodes:(NSArray *)episodes history:(NSDictionary *)history nextID:(NSString *)nextID width:(CGFloat)width {
    if((self=[super initWithFrame:CGRectMake(32,0,width-64,episodes.count*162)])){_episodes=[episodes copy];_history=[history copy];_nextID=[nextID copy];_cells=[NSMutableDictionary new];_reuse=[NSMutableArray new];}return self;
}
- (void)updateViewport:(CGRect)viewport loadImages:(BOOL)loadImages {
    double began=NSProcessInfo.processInfo.systemUptime;NSRange needed=RWVisibleRows(_episodes.count,162,CGRectGetMinY(viewport),viewport.size.height,1);NSRange visible=RWVisibleRows(_episodes.count,162,CGRectGetMinY(viewport),viewport.size.height,0);
    for(NSNumber *key in [_cells.allKeys copy])if(!NSLocationInRange(key.unsignedIntegerValue,needed)){RWEpisodeCell *cell=_cells[key];[cell cancelImage];[cell removeFromSuperview];cell.play=nil;cell.options=nil;[_reuse addObject:cell];[_cells removeObjectForKey:key];}
    __weak RWEpisodeList *weak=self;
    for(NSUInteger i=needed.location;i<NSMaxRange(needed);i++){
        RWEpisodeCell *cell=_cells[@(i)];if(!cell){cell=_reuse.lastObject;if(cell)[_reuse removeLastObject];else{cell=[[RWEpisodeCell alloc]initWithFrame:CGRectZero];_created++;}NSDictionary *episode=_episodes[i];[cell configure:episode record:_history[episode[@"id"]] next:[episode[@"id"]isEqual:_nextID]];
            cell.play=^(NSDictionary *episode){if(weak.onPlay)weak.onPlay(episode);};cell.options=^(NSDictionary *episode,UIView *anchor){if(weak.onOptions)weak.onOptions(episode,anchor);};_cells[@(i)]=cell;[self addSubview:cell];
        }
        cell.frame=CGRectMake(0,i*162,self.bounds.size.width,150);
        if(loadImages&&NSLocationInRange(i,visible)&&[cell loadImage])_imageLoads++;
    }
    // Keep a small spare pool only; long scrolling must not retain every old card.
    while(_reuse.count>2)[_reuse removeLastObject];_peak=MAX(_peak,_cells.count);_lastUpdate=NSProcessInfo.processInfo.systemUptime-began;
}
- (NSDictionary *)diagnostics {NSUInteger loaded=0;NSMutableArray *visible=[NSMutableArray new];for(RWEpisodeCell *cell in _cells.allValues){if([cell imageLoaded])loaded++;[visible addObject:[cell progressSnapshot]];}return @{@"next_id":_nextID?:@"",@"visible_progress":visible,@"loaded_images":@(loaded),@"episodes":@(_episodes.count),@"visible_cards":@(_cells.count),@"peak_cards":@(_peak),@"created_cards":@(_created),@"spare_cards":@(_reuse.count),@"thumbnail_requests":@(_imageLoads),@"last_update_seconds":@(_lastUpdate)};}
@end
