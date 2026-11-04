// Native browsing screens. Geometry is in iPad points, not browser pixels.
- (CGFloat)width { return self.view.bounds.size.width; }
- (void)go:(NSString *)page {
    [self.profileExperience cancelTransition];
    if(![page isEqual:@"Details"]){self.notificationEpisodeID=nil;self.notificationTitleID=nil;}
    if(![page isEqual:@"Details"])[[RewindStore shared]cancelRelatedTitles];
    double navigationBegan=NSProcessInfo.processInfo.systemUptime;BOOL enteredDownloads=[page isEqual:@"Downloads"]&&![self.page isEqual:@"Downloads"];
    if(![page isEqual:@"Details"]){[self.castService cancel];self.castRequestKey=nil;}
    [self.view endEditing:YES]; [self.searchTimer invalidate]; self.searchGeneration++;
    [self cancelSearchRequests];
    self.sourceGeneration++; self.loadingSources=NO; [self.sourceNotice removeFromSuperview]; self.sourceNotice=nil;
    if([page isEqual:@"Home"]&&![self.page isEqual:@"Home"]){self.homePlan=[RewindStore shared].discoveryHome;self.homeRefreshStarted=NO;}
    if([self.page isEqual:@"Explore"]&&![page isEqual:@"Explore"]){[[RewindStore shared].discoveryMetadata cancelEntitySearch];self.exploreGeneration++;self.exploreRemoteBusy=NO;}
    // Back restores controller pointers before go:. Use the actual old grid
    // as well, so its database is parked before the destination is restored.
    RWFeedStore *target=[page isEqual:@"Entity"]?self.entityFeed:[page isEqual:@"Explore"]?self.exploreFeed:([page isEqual:@"Home"]&&![self.filter isEqual:@"All"]&&[self hasBrowseFilters])?self.browseFeed:nil;
    if(self.feedGrid.feed!=target&&[self.feedGrid.feed isKindOfClass:RWFeedStore.class])[(RWFeedStore *)self.feedGrid.feed park];
    if(self.entityFeed!=target)[self.entityFeed park];if(self.exploreFeed!=target)[self.exploreFeed park];if(self.browseFeed!=target)[self.browseFeed park];[target activate];
    self.page = page;
    if(!self.destinationStack.count&&[@[@"Home",@"Search",@"Profiles",@"My List",@"Upcoming",@"Downloads",@"Preferences",@"Settings"]containsObject:page]){[self resetEntityFeed];[self resetExplore];}
    if([page isEqual:@"Home"]&&![self.filter isEqual:@"All"]&&[self hasBrowseFilters]&&![self.browseFeed.context isEqual:[self browseContext]])[self fetchBrowse];else[self render];[self recordDiscoveryTiming:@"navigation" seconds:NSProcessInfo.processInfo.systemUptime-navigationBegan];if(!self.reviewMode)[[RWUIProbe shared]transition:@"navigation_to_display_callback" started:navigationBegan];if(enteredDownloads&&!self.downloadsBusy)[self refreshDownloads];
}
- (UILabel *)label:(NSString *)text x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width size:(CGFloat)size weight:(CGFloat)weight color:(unsigned)color {
    UILabel *label = RWLabel(text,size,weight,RWColor(color)); label.frame = CGRectMake(x,y,width,size*1.45);
    [self.content addSubview:label]; return label;
}
- (RWButton *)button:(NSString *)text x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width primary:(BOOL)primary action:(void(^)(void))action {
    RWButton *button = [RWButton text:text action:action]; button.frame = CGRectMake(x,y,width,48);
    [button appearance:primary]; [self.content addSubview:button]; return button;
}
- (void)heading:(NSString *)title subtitle:(NSString *)subtitle {
    [self label:title x:32 y:28 width:[self width]-64 size:34 weight:UIFontWeightBold color:0xf5f2eb];
    [self label:subtitle x:33 y:82 width:[self width]-66 size:15 weight:UIFontWeightRegular color:0xa5aab3];
}
#include "RewindNavigation.inc"
- (void)rememberMyListPosition {
    if(![self.page isEqual:@"My List"]||self.myListSuspendedAnchor)return;
    self.myListSuspendedAnchor=self.feedGrid.positionAnchor;self.myListSuspendedProfile=[RewindStore shared].state[@"activeProfile"];
}
- (void)restoreMyListPosition {
    if(!self.myListSuspendedAnchor||!self.view.window||self.presentedViewController)return;
    if([self.page isEqual:@"My List"]&&[self.myListSuspendedProfile isEqual:[RewindStore shared].state[@"activeProfile"]])[self.feedGrid restorePositionAnchor:self.myListSuspendedAnchor];
    self.myListSuspendedAnchor=nil;self.myListSuspendedProfile=nil;
}
- (void)viewWillDisappear:(BOOL)animated {[self rememberMyListPosition];[super viewWillDisappear:animated];}
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [self.profileExperience cancelTransition];[self rememberMyListPosition];[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];__weak RewindController *weak=self;
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context){[weak restoreMyListPosition];}];
}
- (void)render {
    // Catalog and layout callbacks can arrive after playback covers this
    // controller. The player's onClose renders the current model on dismissal.
    if([self.presentedViewController isKindOfClass:RewindPlayer.class])return;
    if (!self.isViewLoaded) return;if([self.page isEqual:@"Details"])self.detailNeedsApply=NO;double renderBegan=NSProcessInfo.processInfo.systemUptime;
    if(!self.reviewMode)[RWUIProbe shared].context=@{@"screen":self.page?:@"Unknown",@"width":@([self width]),@"profile_age":[RewindStore shared].profile[@"maxAge"]?:@(-1)};
    NSString *homeScope=[NSString stringWithFormat:@"%@:%@",[RewindStore shared].state[@"activeProfile"],self.filter];
    if([self.page isEqual:@"Home"]&&self.homeView&&[self.homeScope isEqual:homeScope]&&[self.homeViewContext isEqual:[self currentHomeContext]]&&!([self hasBrowseFilters]&&![self.filter isEqual:@"All"])&&CGSizeEqualToSize(self.content.frame.size,CGSizeMake([self width],self.view.bounds.size.height-84))){
        [self updateHomeList];self.renderGeneration++;double elapsed=NSProcessInfo.processInfo.systemUptime-renderBegan;[[RewindStore shared]report:@{@"last_render_seconds":@(elapsed),@"last_render_mode":@"reused_home"}];[self recordDiscoveryTiming:@"home_apply" seconds:elapsed];return;
    }
    if([self.page isEqual:@"Upcoming"]&&self.upcomingList&&[self.upcomingScope isEqual:[RewindStore shared].state[@"activeProfile"]]&&CGSizeEqualToSize(self.content.frame.size,CGSizeMake([self width],self.view.bounds.size.height-84))){[self updateUpcomingList];self.renderGeneration++;[self recordDiscoveryTiming:@"upcoming_apply" seconds:NSProcessInfo.processInfo.systemUptime-renderBegan];return;}
    if([self.page isEqual:@"Entity"]&&[self.content.accessibilityIdentifier isEqual:@"Entity"]&&self.feedGrid&&[self.entityScreenScope isEqual:[NSString stringWithFormat:@"%@:%@:%@",[RewindStore shared].state[@"activeProfile"],self.entity[@"id"],self.entity[@"creditRole"]]]&&CGSizeEqualToSize(self.content.frame.size,CGSizeMake([self width],self.view.bounds.size.height-84))){[self updateEntityHeader];[self updateEntityGrid];return;}
    if([self.page isEqual:@"Explore"]&&[self.content.accessibilityIdentifier isEqual:@"Explore"]&&self.feedGrid&&[self.exploreScope isEqual:[self currentExploreScope]]&&CGSizeEqualToSize(self.content.frame.size,CGSizeMake([self width],self.view.bounds.size.height-84))){[self updateExploreGrid];return;}
    if([self.page isEqual:@"Downloads"]&&self.downloadsList&&[self.downloadsScope isEqual:[RewindStore shared].state[@"activeProfile"]]&&CGSizeEqualToSize(self.content.frame.size,CGSizeMake([self width],self.view.bounds.size.height-84))){[self updateDownloadsList];return;}
    BOOL preserveDetail=[self.page isEqual:@"Details"]&&[self.detailHeader.scope isEqual:[self currentPreviewKey]];
    if(preserveDetail)[self.detailHeader removeFromSuperview];else{[self stopPreview];self.detailHeader=nil;}
    BOOL preserveCast=[self.page isEqual:@"Details"]&&[self.castStage.scope isEqual:[self currentPreviewKey]];
    if(preserveCast)[self.castStage removeFromSuperview];else self.castStage=nil;
    self.previewStage=nil;self.heroOverlay=nil;self.displayedIDs=[NSMutableSet new];
    self.posters=[NSMutableArray new];self.posterRails=[NSMutableArray new];self.episodeList=nil;self.lastEpisodeScrollTime=0;self.lastEpisodeReport=0;
    NSDictionary *oldListAnchor=[self.content.accessibilityIdentifier isEqual:@"My List"]?[self.feedGrid positionAnchor]:nil;if([self.page isEqual:@"My List"]&&[self.myListSuspendedProfile isEqual:[RewindStore shared].state[@"activeProfile"]]&&self.myListSuspendedAnchor)oldListAnchor=self.myListSuspendedAnchor;
    CGFloat oldDownloadsOffset=self.downloadsList.contentOffset.y;CGFloat oldUpcomingOffset=self.upcomingList.contentOffset.y;CGFloat oldHomeOffset=self.homeView.contentOffset.y;CGFloat oldFeedOffset=self.feedGrid.contentOffset.y;CGFloat oldOffset = self.content.contentOffset.y; NSString *key=[self.page stringByAppendingString:[self.page isEqual:@"Home"]?self.filter:@""];
    BOOL retainOffset = [self.content.accessibilityIdentifier isEqual:key];
    if([self.content.accessibilityIdentifier isEqual:@"Entity"]&&[self.entityScreenScope isEqual:[self currentEntityScope]])[self rememberEntityRail];self.entityHighlightRail=nil;
    double teardownBegan=NSProcessInfo.processInfo.systemUptime;
    [self parkCurrentHome];if([self.page isEqual:@"Profiles"])[self.sidebar removeFromSuperview];[self.content removeFromSuperview];
    self.feedGrid=nil;self.searchExploreBar=nil;self.exploreSearch=nil;self.exploreMessage=nil;self.homeView=nil;self.homeViewContext=nil;self.homeHeaderRecord=nil;self.upcomingList=nil;self.downloadsList=nil;
    [[RWUIProbe shared]work:@"screen_teardown" started:teardownBegan];double contentBegan=NSProcessInfo.processInfo.systemUptime;
    CGFloat navigationHeight=[self.page isEqual:@"Profiles"]?0:84;
    self.content = [[UIScrollView alloc] initWithFrame:CGRectMake(0,navigationHeight,[self width],self.view.bounds.size.height-navigationHeight)];
    self.content.backgroundColor=RWColor(0x0e1116); self.content.alwaysBounceVertical=YES; self.content.accessibilityIdentifier=key;
    self.content.delegate=self;self.content.keyboardDismissMode=UIScrollViewKeyboardDismissModeOnDrag; [self.view addSubview:self.content];
    if ([self.page isEqual:@"Home"]) [self home]; else if ([self.page isEqual:@"Search"]) [self searchPage];
    else if ([self.page isEqual:@"Upcoming"]) [self upcomingPage]; else if ([self.page isEqual:@"Preferences"]) [self preferencesPage]; else if ([self.page isEqual:@"Entity"]) [self entityPage]; else if ([self.page isEqual:@"Explore"]) [self explorePage];
    else if ([self.page isEqual:@"My List"]) [self listPage]; else if ([self.page isEqual:@"Downloads"]) [self downloadsPage];
    else if ([self.page isEqual:@"Profiles"]) [self profilesPage]; else if ([self.page isEqual:@"Settings"]) [self settingsPage]; else if ([self.page isEqual:@"Details"]) [self detailPage];
    [[RWUIProbe shared]work:@"screen_content_create" started:contentBegan];[self recordDetailOpenStage:@"render.content" started:contentBegan];double detailStage=NSProcessInfo.processInfo.systemUptime;if(navigationHeight)[self navigation];
    if (retainOffset) self.content.contentOffset=CGPointMake(0,MIN(oldOffset,MAX(0,self.content.contentSize.height-self.content.bounds.size.height)));
    if(retainOffset&&self.feedGrid){[self.feedGrid layoutIfNeeded];self.feedGrid.contentOffset=CGPointMake(0,MIN(oldFeedOffset,MAX(0,self.feedGrid.contentSize.height-self.feedGrid.bounds.size.height)));}
    if(retainOffset&&[self.page isEqual:@"My List"]&&oldListAnchor)[self.feedGrid restorePositionAnchor:oldListAnchor];
    if(retainOffset&&self.homeView){[self.homeView layoutIfNeeded];self.homeView.contentOffset=CGPointMake(0,MIN(oldHomeOffset,MAX(0,self.homeView.contentSize.height-self.homeView.bounds.size.height)));}
    if(retainOffset&&self.downloadsList){[self.downloadsList layoutIfNeeded];self.downloadsList.contentOffset=CGPointMake(0,MIN(oldDownloadsOffset,MAX(0,self.downloadsList.contentSize.height-self.downloadsList.bounds.size.height)));}
    if(retainOffset&&self.upcomingList){[self.upcomingList layoutIfNeeded];self.upcomingList.contentOffset=CGPointMake(0,MIN(oldUpcomingOffset,MAX(0,self.upcomingList.contentSize.height-self.upcomingList.bounds.size.height)));}
    [self recordDetailOpenStage:@"render.navigation_offsets" started:detailStage];detailStage=NSProcessInfo.processInfo.systemUptime;
    [[RewindStore shared] report:@{@"screen":self.page,@"movies":@([RewindStore shared].movies.count),@"series":@([RewindStore shared].series.count),@"saved_count":@([RewindStore shared].saved.count),@"history_count":@([RewindStore shared].history.count)}];
    [self recordDetailOpenStage:@"render.report_counts" started:detailStage];detailStage=NSProcessInfo.processInfo.systemUptime;
    // Screenshots are produced only by the explicit one-shot layout review.
    // Ordinary browsing must not render and PNG-encode every screen on this A5.
    self.renderGeneration++;
    [self loadVisiblePosters];
    [self recordDetailOpenStage:@"render.visible_artwork" started:detailStage];detailStage=NSProcessInfo.processInfo.systemUptime;
    if([self.page isEqual:@"Details"]){[self updatePreviewVisibility];[self schedulePreview:NO];}
    [self recordDetailOpenStage:@"render.preview" started:detailStage];detailStage=NSProcessInfo.processInfo.systemUptime;
    [self prepareCurrentTitle];[self recordDetailOpenStage:@"render.playback_preparation" started:detailStage];detailStage=NSProcessInfo.processInfo.systemUptime;
    [self.profileExperience keepVisible];[self syncDiscoveryActivity];[self recordDetailOpenStage:@"render.discovery_activity" started:detailStage];
    if(!self.reviewMode){[[RewindStore shared]report:@{@"last_render_seconds":@(NSProcessInfo.processInfo.systemUptime-renderBegan)}];[self recordDiscoveryTiming:@"render" seconds:NSProcessInfo.processInfo.systemUptime-renderBegan];}
}
- (CGFloat)row:(NSString *)title subtitle:(NSString *)subtitle movies:(NSArray *)movies y:(CGFloat)y landscape:(BOOL)landscape {
    RewindStore *store=[RewindStore shared];movies=[RWDiscoveryCatalog uniqueVisible:[store allowedItems:movies] excluding:self.displayedIDs hidden:store.profile[@"hidden"] limit:12];
    if (!movies.count) return y; CGFloat w=[self width]; __weak RewindController *weak=self;
    [self label:title x:32 y:y width:w-172 size:23 weight:UIFontWeightSemibold color:0xf5f2eb];
    if (subtitle.length) [self label:subtitle x:33 y:y+35 width:w-100 size:13 weight:UIFontWeightRegular color:0xa0a6af];
    CGFloat top=y+(subtitle.length?65:48), cardWidth=landscape?264:148, height=landscape?204:270;
    RWPosterCollection *rail=[[RWPosterCollection alloc]initWithFrame:CGRectMake(0,top,w,height)];rail.horizontal=YES;rail.landscape=landscape;rail.reviewMode=self.reviewMode;rail.decelerationRate=UIScrollViewDecelerationRateFast;[self.content addSubview:rail];[self.posterRails addObject:rail];
    NSString *key=[NSString stringWithFormat:@"RWrail:%@:%@:%@:%@:%@",store.state[@"activeProfile"],self.page,self.filter,[self.page isEqual:@"Details"]?RWID(self.detail):@"",title];rail.accessibilityIdentifier=key;NSNumber *savedOffset=self.railOffsets[key];
    for(NSDictionary *m in movies)[self.displayedIDs addObject:RWID(m)];
    rail.onSelect=^(NSDictionary *meta){NSDictionary *r=meta[@"historyRecord"];if(r)[weak chooseSources:r[@"meta"] videoID:r[@"videoID"] restart:NO];else if(RWString(meta[@"episodeVideoID"]).length)[weak chooseSources:meta videoID:meta[@"episodeVideoID"] restart:NO];else [weak showDetails:meta];};
    rail.onScroll=^(CGPoint offset){if(!weak||weak.reviewMode)return;if(!weak.railOffsets)weak.railOffsets=[NSMutableDictionary new];if(weak.railOffsets.count>=128&&!weak.railOffsets[key])[weak.railOffsets removeObjectForKey:weak.railOffsets.allKeys.firstObject];weak.railOffsets[key]=@(offset.x);};
    [rail updateItems:movies loading:NO more:NO error:nil cursor:0 automatic:NO];[rail layoutIfNeeded];if(savedOffset)rail.contentOffset=CGPointMake(MAX(0,MIN(savedOffset.doubleValue,MAX(0,rail.contentSize.width-w))),0);
    for (int i=0;i<2;i++) {
        RWButton *arrow=[RWButton text:@"" action:^{ CGFloat x=rail.contentOffset.x+(i?1:-1)*(cardWidth+18)*2; x=MAX(0,MIN(x,MAX(0,rail.contentSize.width-w))); [rail setContentOffset:CGPointMake(x,0) animated:YES]; }];
        arrow.frame=CGRectMake(w-128+i*48,y-5,44,44); [arrow icon:i?@"chevron-right":@"chevron-left"]; arrow.accessibilityLabel=i?@"Next titles":@"Previous titles";
        [self.content addSubview:arrow];
    }
    return top+height+25;
}
- (void)home {
    if(![self.filter isEqual:@"All"]&&[self hasBrowseFilters]){[self filteredBrowsePage];return;}
    [self discoveryHomePage];
}
- (CGFloat)grid:(NSArray *)items y:(CGFloat)y {
    return [self grid:items.count>40?[items subarrayWithRange:NSMakeRange(0,40)]:items y:y inView:self.content];
}
- (CGFloat)grid:(NSArray *)items y:(CGFloat)y inView:(UIView *)parent {
    items=[[RewindStore shared]allowedItems:items];
    CGFloat w=[self width]; int columns=MAX(3,(int)((w-64)/165)); CGFloat width=(w-64-(columns-1)*20)/columns;
    __weak RewindController *weak=self;
    for (NSUInteger i=0;i<MIN(items.count,(NSUInteger)96);i++) {
        NSDictionary *m=[[RewindStore shared]discoveryMeta:items[i]]; RWPoster *poster=[[RWPoster alloc] initWithMeta:m width:width landscape:NO];
        CGRect frame=poster.frame; frame.origin=CGPointMake(32+(i%columns)*(width+20),y+(i/columns)*(poster.frame.size.height+25)); poster.frame=frame;
        poster.action=^(NSDictionary *meta){ [weak showDetails:meta]; }; [parent addSubview:poster];[self.posters addObject:poster];
    }
    return y+ceil(MIN(items.count,(NSUInteger)96)/(double)columns)*(width*1.45+76)+25;
}
- (void)empty:(NSString *)title message:(NSString *)message icon:(NSString *)icon action:(NSString *)action block:(void(^)(void))block y:(CGFloat)y {
    CGFloat w=[self width]; UIView *panel=RWPanel(CGRectMake(32,y,w-64,310)); [self.content addSubview:panel];
    UIImageView *symbol=[[UIImageView alloc] initWithImage:RWIcon(icon,34,RWColor(0xff9777))]; symbol.center=CGPointMake(panel.bounds.size.width/2,54); [panel addSubview:symbol];
    UILabel *heading=RWLabel(title,23,UIFontWeightSemibold,RWColor(0xf5f2eb)); heading.textAlignment=NSTextAlignmentCenter; heading.frame=CGRectMake(24,94,w-112,35); [panel addSubview:heading];
    UILabel *body=RWLabel(message,15,UIFontWeightRegular,RWColor(0xaab0b9)); body.numberOfLines=2; body.textAlignment=NSTextAlignmentCenter; body.frame=CGRectMake(35,140,w-134,52); [panel addSubview:body];
    RWButton *button=[RWButton text:action action:block]; [button appearance:YES]; button.frame=CGRectMake((w-64)/2-100,222,200,48); [panel addSubview:button];
}
- (void)listPage {
    [self heading:@"Your next great watch." subtitle:@"Everything you save, in one place."];NSArray *saved=[RewindStore shared].saved;__weak RewindController *weak=self;
    if(saved.count){self.feedGrid=[[RWPosterCollection alloc]initWithFrame:CGRectMake(0,145,[self width],MAX(100,self.content.bounds.size.height-145))];self.feedGrid.reviewMode=self.reviewMode;self.feedGrid.onSelect=^(NSDictionary *m){[weak showDetails:m];};[self.content addSubview:self.feedGrid];self.content.scrollEnabled=NO;[self.feedGrid updateItems:saved loading:NO more:NO error:nil cursor:0 automatic:NO];self.content.contentSize=self.content.bounds.size;}
    else{[self empty:@"Make a little room for great stories." message:@"Add films and series to My List.\nThey will be here whenever you are ready." icon:@"bookmark" action:@"Discover something" block:^{[weak resetBrowse];weak.filter=@"All";[weak go:@"Home"];} y:145];self.content.contentSize=CGSizeMake([self width],495);}
}
- (void)searchPage {
    [self heading:@"What are you in the mood for?" subtitle:@"Find a title, or follow a person, studio or mood."];
    NSString *query=self.search.text?:@"";
    UIView *field=RWPanel(CGRectMake(32,128,[self width]-64,60)); [self.content addSubview:field];
    self.search=[[UISearchBar alloc] initWithFrame:CGRectMake(5,4,field.bounds.size.width-10,52)];
    self.search.barStyle=UIBarStyleBlack; self.search.searchBarStyle=UISearchBarStyleMinimal; self.search.placeholder=@"Search movies and series";
    self.search.delegate=self; self.search.text=query; self.search.autocapitalizationType=UITextAutocapitalizationTypeNone; [field addSubview:self.search];
    self.searchMessageLabel=[self label:self.searchMessage.length?self.searchMessage:@"CURATED DISCOVERIES" x:33 y:217 width:[self width]-66 size:12 weight:UIFontWeightSemibold color:0xa8aeb7];
    self.searchExploreBar=[[UIView alloc]initWithFrame:CGRectMake(0,257,[self width],70)];[self.content addSubview:self.searchExploreBar];
    __weak RewindController *weak=self;NSArray *destinations=@[@"People",@"Studios",@"Moods"];CGFloat buttonWidth=([self width]-88)/3;
    for(NSUInteger i=0;i<destinations.count;i++){NSString *kind=destinations[i];RWButton *b=[RWButton text:kind action:^{[weak openExplore:kind];}];[b appearance:NO];b.frame=CGRectMake(32+i*(buttonWidth+12),0,buttonWidth,48);[self.searchExploreBar addSubview:b];}
    self.feedGrid=[[RWPosterCollection alloc]initWithFrame:CGRectZero];self.feedGrid.reviewMode=self.reviewMode;self.feedGrid.onSelect=^(NSDictionary *meta){[weak showDetails:meta];};
    self.searchResultsView=self.feedGrid;[self.content addSubview:self.feedGrid];self.content.scrollEnabled=NO;[self updateSearchResults];
}

- (BOOL)downloadRecordAllowed:(NSDictionary *)record {
    RewindStore *s=[RewindStore shared];NSDictionary *current=[s record:record[@"videoID"]];return [self.downloadsScope isEqual:s.state[@"activeProfile"]]&&[s allowed:record[@"meta"]]&&[RWString(current[@"source"][@"infoHash"]).lowercaseString isEqual:record[@"hash"]];
}
- (void)refreshDownloads {
    if(![self.page isEqual:@"Downloads"]||self.downloadsActionBusy)return;if(self.downloadsBusy){self.downloadsRefreshAgain=YES;return;}self.downloadsBusy=YES;self.downloadsRefreshAgain=NO;
    RewindStore *s=[RewindStore shared];NSString *profile=[s.state[@"activeProfile"]copy];NSUInteger generation=++self.downloadsGeneration;self.downloadsScope=profile;
    NSMutableArray *history=[NSMutableArray new];for(NSDictionary *raw in [s.profile[@"history"]allValues]){if(![raw isKindOfClass:NSDictionary.class])continue;NSMutableDictionary *record=[raw mutableCopy];record[@"meta"]=[raw[@"meta"]copy]?:@{};record[@"source"]=[raw[@"source"]copy]?:@{};[history addObject:record];}
    NSDictionary *gate=@{@"profile":@{@"maxAge":s.profile[@"maxAge"]?:@(-1)},@"family":[s.familyCatalog copy]?:@[],@"ageRatings":[s.ratings snapshot]};NSSet *pinned=[NSSet setWithArray:[s.state[@"keptDownloads"]copy]?:@[]];__weak RewindController *weak=self;[self updateDownloadsList];
    [TorrentEngine downloadInventory:history gate:gate pinned:pinned done:^(NSDictionary *snapshot){if(!weak||generation!=weak.downloadsGeneration||![profile isEqual:s.state[@"activeProfile"]])return;weak.downloadsBusy=NO;if(weak.downloadsRefreshAgain){[weak refreshDownloads];return;}if([snapshot[@"error"]length]&&[weak.downloadsSnapshot[@"items"]count]){NSMutableDictionary *retained=[snapshot mutableCopy];retained[@"items"]=weak.downloadsSnapshot[@"items"];weak.downloadsSnapshot=retained;}else weak.downloadsSnapshot=snapshot;if(!weak.reviewMode)[s report:@{@"download_inventory":snapshot[@"metrics"]?:@{}}];[weak updateDownloadsList];}];
}
- (void)updateDownloadsList {
    if(![self.page isEqual:@"Downloads"]||!self.downloadsList||(self.presentedViewController&&![self.presentedViewController isKindOfClass:UIAlertController.class]))return;self.downloadsList.actionsEnabled=!self.downloadsActionBusy;[self.downloadsList updateSnapshot:self.downloadsSnapshot loading:self.downloadsBusy||self.downloadsActionBusy];
}
- (void)toggleDownloadKeep:(NSDictionary *)record {
    if(![self downloadRecordAllowed:record]||self.downloadsActionBusy)return;RewindStore *s=[RewindStore shared];NSString *hash=record[@"hash"];NSMutableArray *pins=[s.state[@"keptDownloads"]mutableCopy]?:[NSMutableArray new];if([pins containsObject:hash])[pins removeObject:hash];else [pins addObject:hash];s.state[@"keptDownloads"]=pins;[s save];
    NSMutableArray *items=[NSMutableArray new];for(NSDictionary *old in self.downloadsSnapshot[@"items"]){NSMutableDictionary *item=[old mutableCopy];item[@"kept"]=@([pins containsObject:item[@"hash"]]);[items addObject:item];}NSMutableDictionary *snapshot=[self.downloadsSnapshot mutableCopy]?:[NSMutableDictionary new];snapshot[@"items"]=items;self.downloadsSnapshot=snapshot;[self updateDownloadsList];if(self.downloadsBusy)self.downloadsRefreshAgain=YES;
}
- (void)removeDownload:(NSDictionary *)record {
    if(![self downloadRecordAllowed:record]||self.downloadsActionBusy)return;__weak RewindController *weak=self;NSString *profile=self.downloadsScope,*hash=record[@"hash"];
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Remove download?" message:@"Downloaded video pieces will be removed from this iPad. Your watch progress stays saved." preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    void(^remove)(void)=^{if(![profile isEqual:[RewindStore shared].state[@"activeProfile"]]||![weak downloadRecordAllowed:record])return;weak.downloadsActionBusy=YES;[weak updateDownloadsList];
        [TorrentEngine removeDownload:hash done:^(BOOL ok){RewindStore *s=[RewindStore shared];weak.downloadsActionBusy=NO;if(ok){NSMutableArray *pins=[s.state[@"keptDownloads"]mutableCopy];[pins removeObject:hash];s.state[@"keptDownloads"]=pins;[s invalidateOfflineEvidence];[s save];if([profile isEqual:s.state[@"activeProfile"]])[weak refreshDownloads];}else if([profile isEqual:s.state[@"activeProfile"]]&&[weak.page isEqual:@"Downloads"]){[weak updateDownloadsList];RWAlert(weak,@"Download not removed",@"Try again after the player has finished closing.");}}];
    };
    if([self.exerciseRequest[@"action"]isEqual:@"download-controls"]&&self.exerciseResumeOwned)self.exerciseDownloadRemoval=[remove copy];
    [a addAction:[UIAlertAction actionWithTitle:@"Remove" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){remove();}]];[self presentViewController:a animated:YES completion:nil];
}
- (void)clearTemporaryDownloads {
    RewindStore *s=[RewindStore shared];if(s.restricted||self.downloadsActionBusy||![self.downloadsScope isEqual:s.state[@"activeProfile"]])return;self.downloadsActionBusy=YES;NSString *profile=self.downloadsScope;__weak RewindController *weak=self;[self updateDownloadsList];
    [TorrentEngine clearTemporary:[NSSet setWithArray:s.state[@"keptDownloads"]?:@[]] done:^(NSDictionary *report){weak.downloadsActionBusy=NO;[s invalidateOfflineEvidence];[s report:@{@"cache_cleanup":report}];if([profile isEqual:s.state[@"activeProfile"]])[weak refreshDownloads];}];
}
- (void)downloadsPage {
    [self heading:@"On this iPad" subtitle:@"Pick up a download and get back to the story."];NSString *profile=[RewindStore shared].state[@"activeProfile"];if(![self.downloadsScope isEqual:profile]){self.downloadsGeneration++;self.downloadsSnapshot=nil;self.downloadsBusy=NO;self.downloadsScope=profile;}
    CGFloat y=128;self.downloadsList=[[RWDownloadsList alloc]initWithFrame:CGRectMake(0,y,[self width],MAX(100,self.content.bounds.size.height-y))];self.downloadsList.profileID=profile;self.downloadsList.reviewMode=self.reviewMode;__weak RewindController *weak=self;
    self.downloadsList.onResume=^(NSDictionary *record){if(!weak.downloadsActionBusy&&[weak downloadRecordAllowed:record]){NSDictionary *latest=[[RewindStore shared]record:record[@"videoID"]];[weak chooseSources:latest[@"meta"] videoID:record[@"videoID"] restart:NO];}};self.downloadsList.onKeep=^(NSDictionary *record){[weak toggleDownloadKeep:record];};self.downloadsList.onRemove=^(NSDictionary *record){[weak removeDownload:record];};self.downloadsList.onClear=^{[weak clearTemporaryDownloads];};self.downloadsList.onRetry=^{[weak refreshDownloads];};self.downloadsList.onBrowse=^{weak.filter=@"Movies";[weak go:@"Home"];};
    [self.content addSubview:self.downloadsList];self.content.scrollEnabled=NO;self.content.contentSize=self.content.bounds.size;[self updateDownloadsList];if(!self.downloadsSnapshot&&!self.downloadsBusy)[self refreshDownloads];
}
- (void)detailPage {if([self.detail[@"type"]isEqual:@"series"])[self seriesDetailsPage];else[self movieDetailsPage];}
- (void)settingsPage {
    CGFloat w=[self width]; __weak RewindController *weak=self;
    [self heading:@"A space of your own." subtitle:@"Your sources. Your library. Your iPad."];
    CGFloat y=150;
    BOOL alerts=[[RewindStore shared].profile[@"episodeNotifications"]boolValue];BOOL granted=([UIApplication.sharedApplication currentUserNotificationSettings].types&UIUserNotificationTypeAlert)!=0;[self button:alerts?(granted?@"Episode alerts · On":@"Episode alerts · Blocked by iOS"):@"Episode alerts · Off" x:32 y:y width:245 primary:NO action:^{[RewindStore shared].profile[@"episodeNotifications"]=@(!alerts);[[RewindStore shared]save];if(!alerts)[UIApplication.sharedApplication registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeSound categories:nil]];[weak render];}];[self label:@"Follow a show to track new episodes. Background checks depend on iOS." x:33 y:y+58 width:w-66 size:13 weight:UIFontWeightRegular color:0xa5aab3];y+=108;
    [self button:[@"Profile · " stringByAppendingString:RWString([RewindStore shared].profile[@"name"])] x:32 y:y width:220 primary:YES action:^{[weak go:@"Profiles"]; }];
    BOOL autoplay=[[RewindStore shared].profile[@"autoplayTrailers"]boolValue];[self button:autoplay?@"Trailer autoplay · On":@"Trailer autoplay · Off" x:264 y:y width:240 primary:NO action:^{[RewindStore shared].profile[@"autoplayTrailers"]=@(!autoplay);[[RewindStore shared]save];[weak render];}];y+=86;
    BOOL startupSound=[RewindStore shared].state[@"startupSoundEnabled"]?[[RewindStore shared].state[@"startupSoundEnabled"]boolValue]:YES;
    [self button:startupSound?@"Startup sound · On":@"Startup sound · Off" x:32 y:y width:240 primary:NO action:^{[RewindStore shared].state[@"startupSoundEnabled"]=@(!startupSound);weak.profileExperience.soundEnabled=!startupSound;[weak.profileExperience stop];[[RewindStore shared]save];[weak render];}];
    [self label:@"Profile entrance and selection sounds. Respects silent mode." x:33 y:y+56 width:w-66 size:13 weight:UIFontWeightRegular color:0xa5aab3];y+=100;
    BOOL cinematic=[[RewindStore shared].state[@"profileMotion"]isEqual:@"cinematic"];
    RWButton *motion=[self button:cinematic?@"Profile animation · Cinematic":@"Profile animation · Follow iPad" x:32 y:y width:300 primary:NO action:^{[RewindStore shared].state[@"profileMotion"]=cinematic?@"system":@"cinematic";weak.profileExperience.cinematic=!cinematic;[weak.profileExperience stop];[[RewindStore shared]save];[weak render];}];motion.accessibilityIdentifier=@"RWProfileMotion";
    [self button:@"Preview introduction" x:344 y:y width:210 primary:NO action:^{[weak go:@"Profiles"];[weak.profileExperience replayIntroduction];}];
    [self label:@"Cinematic enables full motion in Rewind. Follow iPad respects Reduce Motion." x:33 y:y+56 width:w-66 size:13 weight:UIFontWeightRegular color:0xa5aab3];y+=100;
    [self label:@"Connected sources" x:33 y:y width:w-66 size:22 weight:UIFontWeightSemibold color:0xf5f2eb]; y+=46;
    UIView *catalog=RWPanel(CGRectMake(32,y,w-64,84)); [self.content addSubview:catalog];
    UIImageView *icon=[[UIImageView alloc] initWithImage:RWIcon(@"film",24,RWColor(0xffa186))]; icon.frame=CGRectMake(20,29,24,24); [catalog addSubview:icon];
    UILabel *name=RWLabel(@"Cinemeta",17,UIFontWeightSemibold,RWColor(0xf5f2eb)); name.frame=CGRectMake(63,15,w-200,25); [catalog addSubview:name];
    UILabel *subtitle=RWLabel(@"Film and series discovery · built in",13,UIFontWeightRegular,RWColor(0xa5acb6)); subtitle.frame=CGRectMake(63,46,w-200,20); [catalog addSubview:subtitle]; y+=100;
    UIView *sources=RWPanel(CGRectMake(32,y,w-64,84));[self.content addSubview:sources];
    UILabel *sourceName=RWLabel(@"Torrentio + YTS",17,UIFontWeightSemibold,RWColor(0xf5f2eb));sourceName.frame=CGRectMake(24,15,w-140,25);[sources addSubview:sourceName];
    UILabel *sourceInfo=RWLabel(@"Automatic movie and episode source lookup · built in",13,UIFontWeightRegular,RWColor(0xa5acb6));sourceInfo.frame=CGRectMake(24,46,w-140,20);[sources addSubview:sourceInfo];y+=110;
    NSInteger quality=[[RewindStore shared]quality];
    [self button:quality?[NSString stringWithFormat:@"Quality · %ldp",(long)quality]:@"Quality · Auto" x:32 y:y width:226 primary:YES action:^{[weak chooseQuality];}];
    RWButton *link=[self button:@"Open a link" x:270 y:y width:170 primary:NO action:^{ NSDictionary *meta=@{@"id":[@"rw:custom:" stringByAppendingString:[NSUUID UUID].UUIDString],@"type":@"movie",@"name":@"My video",@"genres":@[]}; [weak addSource:meta videoID:RWID(meta)]; }]; [link icon:@"link"];link.hidden=[RewindStore shared].restricted;y+=95;
    if(![RewindStore shared].restricted){[self button:[RWSourcePolicy legacyEnabled]?@"MKV playback · Verified":@"Check MKV playback" x:32 y:y width:260 primary:NO action:^{NSDictionary *m=@{@"id":@"rw:mkv-check",@"type":@"movie",@"name":@"Picture & sound check"};[weak play:m videoID:@"rw:mkv-check:preview" source:@{@"name":@"Local compatibility test",@"url":@"asset:surround-check.mkv"} resume:0];}];y+=76;}
    if(![RewindStore shared].restricted){[self button:[RWSourcePolicy nativeSurroundEnabled]?@"Surround audio · Verified":@"Check surround audio" x:32 y:y width:260 primary:NO action:^{NSDictionary *m=@{@"id":@"rw:surround-check",@"type":@"movie",@"name":@"Surround audio check"};[weak play:m videoID:@"rw:surround-check:preview" source:@{@"name":@"Local audio check",@"url":@"asset:surround-check.mp4"} resume:0];}];y+=76;}
    if(![RewindStore shared].restricted){[self button:@"Check trailer playback" x:32 y:y width:260 primary:NO action:^{[weak showDetails:@{@"id":@"tt11280740",@"type":@"series",@"name":@"Severance",@"releaseInfo":@"2022"}];}];y+=76;}
    [self label:@"Made for this iPad" x:33 y:y width:w-66 size:22 weight:UIFontWeightSemibold color:0xf5f2eb]; y+=44;
    UILabel *body=[self label:@"Your list and watch progress stay on this device. Rewind checks H.264 video and AAC audio before playback, and tries another source when one fails. Keep Rewind open while a film downloads; downloads pause when you leave the player." x:33 y:y width:w-66 size:15 weight:UIFontWeightRegular color:0xb5bbc4];
    body.numberOfLines=0; CGFloat height=[body sizeThatFits:CGSizeMake(w-66,CGFLOAT_MAX)].height; body.frame=CGRectMake(33,y,w-66,height); y+=height+40;
    [self label:@"About Rewind" x:33 y:y width:w-66 size:22 weight:UIFontWeightSemibold color:0xf5f2eb]; y+=43;
    UILabel *about=[self label:@"Independent software for a second life. Open films by Blender Foundation, Nina Paley and Brian Knappenberger; discovery by Cinemeta; source lookup by Torrentio and YTS; ratings and vote counts from IMDb (personal non-commercial data); discovery metadata from Wikidata (CC0) and TVmaze (CC BY-SA); icons by Lucide; age ratings from Wikidata and official distributors; cast data from TVmaze (CC BY-SA), TMDB public cast pages and Wikidata; photo credits are available on each portrait. Intro data provided by IntroDB (introdb.app). Artwork belongs to its respective owners." x:33 y:y width:w-66 size:14 weight:UIFontWeightRegular color:0xa5acb6]; about.numberOfLines=0; CGFloat aboutHeight=[about sizeThatFits:CGSizeMake(w-66,CGFLOAT_MAX)].height; about.frame=CGRectMake(33,y,w-66,aboutHeight); y+=aboutHeight+20;
    [self label:[NSString stringWithFormat:@"Rewind %@ · iPad edition",[[NSBundle mainBundle]objectForInfoDictionaryKey:@"CFBundleShortVersionString"]] x:33 y:y width:w-66 size:13 weight:UIFontWeightMedium color:0x9ba3af]; y+=43;
    [self button:@"Playback details" x:32 y:y width:177 primary:NO action:^{ RWAlert(weak,@"Playback details",@"Native H.264/AAC playback, with stereo downmix after the surround check. MKV playback uses the included VLC engine after its playback check. HEVC is unsupported on this iPad. Downloads must leave 512 MB free. Skip intro/recap uses available community timings, with your manual episode timings taking priority. Trailers play inside Rewind; artwork remains when playback is unavailable. Profiles keep separate lists and history."); }];
    [self button:@"Save diagnostics" x:221 y:y width:177 primary:NO action:^{ RWCapture(weak.view,@"Settings"); RWAlert(weak,@"Saved",@"The app report and its screen image are in Rewind's Documents folder."); }];
    self.content.contentSize=CGSizeMake(w,y+90);
}
