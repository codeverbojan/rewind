- (NSString *)names:(id)value {
    if([value isKindOfClass:NSString.class])return value;
    if(![value isKindOfClass:NSArray.class])return @"";
    NSMutableArray *names=[NSMutableArray new];for(id person in value){NSString *name=[person isKindOfClass:NSDictionary.class]?RWString(person[@"name"]):RWString(person);if(name.length)[names addObject:name];}return [names componentsJoinedByString:@", "];
}
- (NSString *)factsFor:(NSDictionary *)meta {
    NSDictionary *text=[RWDetailPresentation textForMeta:meta rating:[[RewindStore shared].ratings rating:RWID(meta)]];NSMutableArray *parts=[NSMutableArray arrayWithObject:[text[@"kind"]capitalizedString]];for(NSString *key in @[@"facts",@"rating"])if([text[key]length])[parts addObject:text[key]];return [parts componentsJoinedByString:@"  ·  "];
}
- (void)requestDetailRender {
    if(![self.page isEqual:@"Details"]||self.reviewMode)return;self.detailNeedsApply=YES;NSString *key=[self currentPreviewKey];if(self.detailApplyScheduled&&[self.detailApplyKey isEqual:key])return;
    self.detailApplyKey=key;self.detailApplyScheduled=YES;__weak RewindController *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.25*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(![weak.detailApplyKey isEqual:key])return;weak.detailApplyScheduled=NO;if([[weak currentPreviewKey]isEqual:key])[weak applyPendingDetails];});
}
- (void)applyPendingDetails {
    if(!self.detailNeedsApply||![self.page isEqual:@"Details"]||self.presentedViewController||self.loadingSources||!self.view.window||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    BOOL moving=self.content.dragging||self.content.decelerating||self.castStage.rail.tracking||self.castStage.rail.dragging||self.castStage.rail.decelerating;for(RWPosterCollection *rail in self.posterRails)moving|=rail.dragging||rail.decelerating;
    if(moving){[self requestDetailRender];return;}self.detailNeedsApply=NO;[self render];
}
- (CGFloat)detailHero:(NSDictionary *)meta series:(BOOL)series {
    CGFloat width=[self width];__weak RewindController *weak=self;NSString *scope=[self currentPreviewKey];
    RWButton *back=[self button:@"Back" x:24 y:0 width:100 primary:NO action:^{[weak destinationBack];}];[back icon:@"arrow-left"];back.layer.borderWidth=0;back.backgroundColor=UIColor.clearColor;
    if(!self.previewSession)self.previewSession=[RWPreviewSession new];[self.previewSession selectKey:scope];
    if(![self.detailHeader.scope isEqual:scope])self.detailHeader=[[RWDetailHeader alloc]initWithScope:scope];
    [self.detailHeader updateMeta:[[RewindStore shared]discoveryMeta:meta] rating:[[RewindStore shared].ratings rating:RWID(meta)] width:width];[self.content addSubview:self.detailHeader];
    self.previewStage=self.detailHeader.stage;self.heroOverlay=self.detailHeader.overlay;self.heroOverlay.hidden=self.preview.embeddedVisible;
    if(!self.reviewMode)[[RewindStore shared]report:@{@"detail_header":self.detailHeader.diagnostics}];
    return CGRectGetMaxY(self.detailHeader.frame)+14;
}
- (void)titleOptions:(NSDictionary *)meta anchor:(UIView *)anchor {
    RewindStore *s=[RewindStore shared];__weak RewindController *weak=self;BOOL series=[meta[@"type"]isEqual:@"series"];
    NSDictionary *next=series?[RWTVPolicy nextEpisode:meta history:s.profile[@"history"] now:NSDate.date]:nil;
    NSString *videoID=series?RWString(next[@"id"]):RWID(meta);NSDictionary *playMeta=series&&next?[RWTVPolicy episodeMeta:next show:meta]:meta;
    UIAlertController *menu=[UIAlertController alertControllerWithTitle:RWString(meta[@"name"]) message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    if(videoID.length&&[s record:videoID])[menu addAction:[UIAlertAction actionWithTitle:@"Start from beginning" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[weak chooseSources:playMeta videoID:videoID restart:YES];}]];
    [menu addAction:[UIAlertAction actionWithTitle:s.quality?[NSString stringWithFormat:@"Quality · %ldp",(long)s.quality]:@"Quality · Auto" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[weak chooseQuality];}]];
    BOOL liked=NO;for(NSDictionary *item in s.profile[@"liked"])if([RWID(item)isEqual:RWID(meta)])liked=YES;
    [menu addAction:[UIAlertAction actionWithTitle:liked?@"Remove like":@"I like this" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[s feedback:meta like:YES];[weak render];}]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Not for me" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[s feedback:meta like:NO];[weak go:@"Home"];}]];
    if(series)[menu addAction:[UIAlertAction actionWithTitle:[s following:meta]?@"Turn off episode reminders":@"Remind me about new episodes" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[s remindEpisodes:meta enabled:![s following:meta]];[weak render];}]];
    if(!series){
        if([s watchingAvailability:meta])[menu addAction:[UIAlertAction actionWithTitle:@"Stop availability reminder" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[s watchAvailability:meta enabled:NO];[weak refreshMovieAvailability];}]];
        [menu addAction:[UIAlertAction actionWithTitle:@"Check availability again" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[s refreshStreams:meta videoID:RWID(meta) done:^(id sources,NSString *error){[weak refreshMovieAvailability];}];}]];
    }
    if(series)[menu addAction:[UIAlertAction actionWithTitle:[s watchingAvailability:meta]?@"Stop availability reminder":@"Watch for episode availability" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[s watchAvailability:meta enabled:![s watchingAvailability:meta]];}]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a){[weak resumePreviewAfterMenu];}]];menu.popoverPresentationController.sourceView=anchor;menu.popoverPresentationController.sourceRect=anchor.bounds;[weak.preview setVisible:NO];[self presentViewController:menu animated:YES completion:nil];
}
- (void)detailSecondaryActions:(NSDictionary *)meta x:(CGFloat)x y:(CGFloat)y {
    RewindStore *s=[RewindStore shared];__weak RewindController *weak=self;
    RWButton *save=[self button:@"My List" x:x y:y width:132 primary:NO action:^{[s toggleSaved:meta];[weak render];}];[save icon:[s isSaved:meta]?@"check":@"plus"];save.accessibilityLabel=[s isSaved:meta]?@"Remove from My List":@"Add to My List";
    __block __weak RWButton *weakMore;RWButton *more=[self button:@"" x:x+144 y:y width:48 primary:NO action:^{[weak titleOptions:meta anchor:weakMore];}];weakMore=more;[more icon:@"more-horizontal"];more.accessibilityLabel=@"More options";more.layer.cornerRadius=24;more.backgroundColor=UIColor.clearColor;
}
- (CGFloat)detailSynopsis:(NSDictionary *)meta y:(CGFloat)y compact:(BOOL)compact {
    NSString *text=RWString(meta[@"description"]);if(!text.length)return y;
    UILabel *description=[self label:text x:33 y:y width:[self width]-66 size:16 weight:UIFontWeightRegular color:0xc2cbd5];description.numberOfLines=compact?2:0;CGFloat height=[description sizeThatFits:CGSizeMake([self width]-66,compact?46:CGFLOAT_MAX)].height;description.frame=CGRectMake(33,y,[self width]-66,height);return y+height+26;
}
- (CGFloat)aboutTitle:(NSDictionary *)m y:(CGFloat)y {
    CGFloat w=[self width];
    y=[self detailSynopsis:m y:y compact:NO];
    y=[self castFor:m y:y];
    y=[self creativeCredits:m y:y];
    for(NSArray *field in @[@[@"director",@"Director"],@[@"writer",[m[@"type"]isEqual:@"series"]?@"Creators / writers":@"Written by"],@[@"genres",@"Genres"],@[@"country",@"Country"],@[@"awards",@"Awards"]]){
        if([field[0]isEqual:@"director"]&&[[[RewindStore shared]discoveryMeta:m][@"discovery"][@"directors"]count])continue;
        NSString *value=[self names:m[field[0]]];if(!value.length)continue;UILabel *label=[self label:field[1] x:33 y:y width:165 size:13 weight:UIFontWeightSemibold color:0x919dac];(void)label;
        UILabel *v=[self label:value x:205 y:y width:w-238 size:14 weight:UIFontWeightRegular color:0xd2d9e2];v.numberOfLines=0;CGFloat height=MAX(22,[v sizeThatFits:CGSizeMake(w-238,CGFLOAT_MAX)].height);v.frame=CGRectMake(205,y,w-238,height);y+=height+17;
    }
    [self label:@"Title information supplied by Cinemeta." x:33 y:y+3 width:w-66 size:11 weight:UIFontWeightRegular color:0x7f8b9b];return y+53;
}
- (void)movieDetailsPage {
    NSDictionary *m=self.detail;RewindStore *s=[RewindStore shared];CGFloat w=[self width],y=[self detailHero:m series:NO];__weak RewindController *weak=self;
    NSDictionary *record=[s record:RWID(m)];BOOL resume=[record[@"position"]doubleValue]>3&&![record[@"completed"]boolValue];
    self.moviePlayButton=[self button:resume?@"Resume":@"Play" x:32 y:y width:200 primary:YES action:^{
        if([[s availability:m][@"watch_instead_of_play"]boolValue]){[s watchAvailability:m enabled:![s watchingAvailability:m]];[weak refreshMovieAvailability];}
        else [weak chooseSources:m videoID:RWID(m) restart:NO];
    }];[self detailSecondaryActions:m x:244 y:y];y+=58;
    self.movieAvailabilityLabel=[self label:@"" x:33 y:y width:w-66 size:13 weight:UIFontWeightRegular color:0xa5b0bd];self.movieAvailabilityLabel.numberOfLines=2;BOOL waiting=[[s availability:m][@"watch_instead_of_play"]boolValue];self.movieAvailabilityLabel.hidden=!waiting;self.movieAvailabilityLabel.frame=CGRectMake(33,y,w-66,waiting?40:0);if(waiting)y+=46;[self refreshMovieAvailability];
    if(resume){UIProgressView *progress=[[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleDefault];progress.frame=CGRectMake(33,y,198,3);progress.progressTintColor=RWColor(0xff6847);progress.trackTintColor=RWColor(0x293440);double duration=[record[@"duration"]doubleValue];progress.progress=duration>0?[record[@"position"]doubleValue]/duration:0;[self.content addSubview:progress];[self label:duration>0?[NSString stringWithFormat:@"%@ remaining",RWTime(MAX(0,duration-[record[@"position"]doubleValue]))]:[NSString stringWithFormat:@"Watched %@",RWTime([record[@"position"]doubleValue])] x:246 y:y-7 width:230 size:12 weight:UIFontWeightRegular color:0x9ca9b8];y+=28;}
    y=[self aboutTitle:m y:y];y=[self row:@"More like this" subtitle:nil movies:[self recommendations] y:y landscape:NO];self.content.contentSize=CGSizeMake(w,y+24);
}
- (void)refreshMovieAvailability {
    if(![self.page isEqual:@"Details"]||![self.detail[@"type"]isEqual:@"movie"])return;
    RewindStore *s=[RewindStore shared];NSDictionary *state=[s availability:self.detail],*record=[s record:RWID(self.detail)];BOOL wait=[state[@"watch_instead_of_play"]boolValue],watch=[s watchingAvailability:self.detail];
    BOOL resume=[record[@"position"]doubleValue]>3&&![record[@"completed"]boolValue];
    [self.moviePlayButton setTitle:wait?(watch?@"Reminder set":@"Remind me"):(resume?@"Resume":@"Play") forState:UIControlStateNormal];
    [self.moviePlayButton icon:wait?(watch?@"check":@"plus"):@"play"];
    if(self.movieAvailabilityLabel&&self.movieAvailabilityLabel.hidden==wait)[self requestDetailRender];
    self.movieAvailabilityLabel.text=wait?(watch?[NSString stringWithFormat:@"%@ · We’ll check when you open Rewind.",state[@"label"]]:state[@"label"]):@"";
}
