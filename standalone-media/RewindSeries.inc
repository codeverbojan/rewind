- (void)addEpisodeAction:(NSString *)title sheet:(UIAlertController *)sheet block:(void(^)(void))block {
    if([self.exerciseRequest[@"action"]isEqual:@"episode-progress"])self.exerciseEpisodeActions[title]=[block copy];
    [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){block();}]];
}
- (void)episodeOptions:(NSDictionary *)episode show:(NSDictionary *)show anchor:(UIView *)anchor {
    RewindStore *s=[RewindStore shared];NSString *identifier=RWString(episode[@"id"]);NSDictionary *m=[RWTVPolicy episodeMeta:episode show:show];__weak RewindController *weak=self;
    UIAlertController *a=[UIAlertController alertControllerWithTitle:RWString(episode[@"name"]?:episode[@"title"]) message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    self.exerciseEpisodeActions=[NSMutableDictionary new];
    [a addAction:[UIAlertAction actionWithTitle:@"Start from beginning" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){[weak chooseSources:m videoID:identifier restart:YES];}]];
    BOOL watched=[[s record:identifier][@"completed"]boolValue];[self addEpisodeAction:watched?@"Mark as unwatched":@"Mark as watched" sheet:a block:^{if([s markEpisode:episode show:show watched:!watched])[weak render];}];
    [a addAction:[UIAlertAction actionWithTitle:@"Adjust intro timing" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){[weak editIntro:identifier];}]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a){[weak resumePreviewAfterMenu];}]];a.popoverPresentationController.sourceView=anchor;a.popoverPresentationController.sourceRect=anchor.bounds;[self presentViewController:a animated:YES completion:nil];
}
- (void)seriesDetailsPage {
    RewindStore *s=[RewindStore shared];NSDictionary *show=self.detail;CGFloat w=[self width];__weak RewindController *weak=self;
    NSArray *episodes=[RWTVPolicy episodes:show];NSDictionary *next=[self detailPlaybackEpisode:show];
    NSMutableOrderedSet *seasons=[NSMutableOrderedSet new];for(NSDictionary *e in episodes)if([e[@"season"]integerValue]>0)[seasons addObject:e[@"season"]];
    if(self.season<=0||![seasons containsObject:@(self.season)])self.season=next?[next[@"season"]integerValue]:[seasons.firstObject integerValue];
    CGFloat y=[self detailHero:show series:YES];NSDictionary *r=next?[s record:next[@"id"]]:nil;BOOL resume=[r[@"position"]doubleValue]>3&&![r[@"completed"]boolValue];
    NSString *playText=next?[NSString stringWithFormat:@"%@ S%02ld E%02ld",resume?@"Resume":@"Play",(long)[next[@"season"]integerValue],(long)[next[@"episode"]integerValue]]:(episodes.count?@"All caught up":@"Loading episodes…");
    BOOL waiting=[[s availability:show][@"watch_instead_of_play"]boolValue];if(waiting)playText=[s watchingAvailability:show]?@"Reminder set":@"Remind me";
    RWButton *play=[self button:playText x:32 y:y width:230 primary:YES action:^{if(waiting){[s watchAvailability:show enabled:![s watchingAvailability:show]];[weak render];}else if(next)[weak chooseSources:[RWTVPolicy episodeMeta:next show:show] videoID:next[@"id"] restart:NO];}];[play icon:waiting?@"plus":@"play"];play.enabled=waiting||next!=nil;
    [self detailSecondaryActions:show x:274 y:y];y+=62;
    NSString *status=next?[NSString stringWithFormat:@"%@%@",RWString(next[@"name"]?:next[@"title"]),resume?[NSString stringWithFormat:@"  ·  %@ watched",RWTime([r[@"position"]doubleValue])]:@""]:@"Your episode progress is saved separately for this profile.";
    [self label:status x:33 y:y width:w-66 size:14 weight:UIFontWeightRegular color:0xb6bec9];y+=34;
    y=[self detailSynopsis:show y:y compact:YES];
    NSArray *tabs=@[@"Episodes",@"About",@"More like this"];CGFloat tx=32;
    for(NSString *tab in tabs){RWButton *b=[self button:tab x:tx y:y width:160 primary:[self.detailTab isEqual:tab] action:^{weak.detailTab=tab;[weak render];}];b.layer.cornerRadius=0;b.layer.borderWidth=0;b.backgroundColor=UIColor.clearColor;[b setTitleColor:RWColor([self.detailTab isEqual:tab]?0xf5f2eb:0x929ca9) forState:UIControlStateNormal];if([self.detailTab isEqual:tab]){UIView *line=[[UIView alloc]initWithFrame:CGRectMake(0,45,160,3)];line.backgroundColor=RWColor(0xff6847);line.userInteractionEnabled=NO;[b addSubview:line];}tx+=172;}y+=64;
    if([self.detailTab isEqual:@"About"]){y=[self aboutTitle:show y:y];self.content.contentSize=CGSizeMake(w,y+20);return;}
    if([self.detailTab isEqual:@"More like this"]){y=[self row:@"Your next series" subtitle:nil movies:[self recommendations] y:y landscape:NO];self.content.contentSize=CGSizeMake(w,y+20);return;}
    __block __weak RWButton *weakSeason;RWButton *seasonButton=[self button:[NSString stringWithFormat:@"Season %ld",(long)self.season] x:32 y:y width:176 primary:NO action:^{
        UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"Seasons" message:nil preferredStyle:UIAlertControllerStyleActionSheet];weak.exerciseEpisodeActions=[NSMutableDictionary new];for(NSNumber *season in seasons)[weak addEpisodeAction:[NSString stringWithFormat:@"Season %@%@",season,weak.season==season.integerValue?@" · Selected":@""] sheet:menu block:^{weak.season=season.integerValue;s.profile[@"selectedSeasons"][RWID(show)]=season;[s save];[weak render];if(weak.episodeList)[weak.content setContentOffset:CGPointMake(0,MAX(0,weak.episodeList.frame.origin.y-80)) animated:NO];[weak resumePreviewAfterMenu];}];
        [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a){[weak resumePreviewAfterMenu];}]];menu.popoverPresentationController.sourceView=weakSeason;menu.popoverPresentationController.sourceRect=weakSeason.bounds;[weak.preview setVisible:NO];[weak presentViewController:menu animated:YES completion:nil];
    }];weakSeason=seasonButton;[seasonButton icon:@"chevron-down"];seasonButton.accessibilityLabel=@"Choose season";
    NSUInteger watched=0,total=0;for(NSDictionary *e in episodes)if([e[@"season"]integerValue]==self.season){total++;if([[s record:e[@"id"]][@"completed"]boolValue])watched++;}
    [self label:[NSString stringWithFormat:@"%lu of %lu watched",(unsigned long)watched,(unsigned long)total] x:w-220 y:y+15 width:188 size:13 weight:UIFontWeightMedium color:0x9da8b6];y+=70;
    NSMutableArray *seasonEpisodes=[NSMutableArray new];for(NSDictionary *ep in episodes)if([ep[@"season"]integerValue]==self.season){NSMutableDictionary *row=[ep mutableCopy];row[@"rewindArtwork"]=[RWArtworkPolicy URLsForMeta:show landscape:YES];[seasonEpisodes addObject:row];}
    self.episodeList=[[RWEpisodeList alloc]initWithEpisodes:seasonEpisodes history:s.profile[@"history"] nextID:next[@"id"] width:w];
    CGRect listFrame=self.episodeList.frame;listFrame.origin.y=y;self.episodeList.frame=listFrame;
    self.episodeList.onPlay=^(NSDictionary *ep){[weak chooseSources:[RWTVPolicy episodeMeta:ep show:show] videoID:ep[@"id"] restart:NO];};
    self.episodeList.onOptions=^(NSDictionary *ep,UIView *anchor){[weak episodeOptions:ep show:show anchor:anchor];};
    [self.content addSubview:self.episodeList];y+=self.episodeList.bounds.size.height;
    if(!episodes.count){[self label:@"Episode information is loading. Check Wi-Fi if it does not appear." x:33 y:y width:w-66 size:15 weight:UIFontWeightRegular color:0xa9b3c0];y+=60;}
    self.content.contentSize=CGSizeMake(w,y+24);
}
