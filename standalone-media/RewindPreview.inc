- (NSString *)currentPreviewKey {return [NSString stringWithFormat:@"%@:%@:%@",[RewindStore shared].state[@"activeProfile"],self.detail[@"type"],RWID(self.detail)];}
- (void)reportPreviewSession {if(self.reviewMode)return;if(!self.previewEvents)self.previewEvents=[NSMutableArray new];NSMutableDictionary *event=[self.previewSession.diagnostics mutableCopy]?:[NSMutableDictionary new];event[@"uptime"]=@(NSProcessInfo.processInfo.systemUptime);[self.previewEvents addObject:event];while(self.previewEvents.count>16)[self.previewEvents removeObjectAtIndex:0];[[RewindStore shared]report:@{@"preview_session":event,@"preview_events":[self.previewEvents copy]}];}
- (void)stopPreview {
    BOOL looking=[self.previewSession.state isEqual:@"lookup"];[self.previewSession cancel];if(looking)[[RewindStore shared]cancelTrailer:RWID(self.detail)];
    [self.preview stop];[self.preview removeFromSuperview];self.preview=nil;self.previewSource=nil;self.previewWantsSound=NO;self.heroOverlay.hidden=NO;
}
- (void)releasePreview {
    BOOL looking=[self.previewSession.state isEqual:@"lookup"];[self.previewSession event:@"released" generation:self.previewSession.generation];if(looking)[[RewindStore shared]cancelTrailer:RWID(self.detail)];
    [self.preview stop];[self.preview removeFromSuperview];self.preview=nil;self.previewSource=nil;self.previewWantsSound=NO;self.heroOverlay.hidden=NO;[self reportPreviewSession];[self syncDiscoveryActivity];
}
- (BOOL)previewIsVisible {
    if(![self.page isEqual:@"Details"]||!self.previewStage.window||self.loadingSources||self.presentedViewController||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return NO;
    CGRect frame=[self.previewStage convertRect:self.previewStage.bounds toView:self.view],visible=CGRectIntersection(frame,CGRectMake(0,84,[self width],MAX(0,self.view.bounds.size.height-84)));
    return frame.size.width>0&&frame.size.height>0&&!CGRectIsNull(visible)&&visible.size.width*visible.size.height>=frame.size.width*frame.size.height*.5;
}
- (void)loadNativePreviewFallback {
    NSUInteger generation=self.previewSession.generation;NSString *key=self.previewSession.key;NSDictionary *meta=self.detail;__weak RewindController *weak=self;
    [self.preview stop];[self.preview removeFromSuperview];self.preview=nil;self.previewSource=nil;self.heroOverlay.hidden=NO;[self reportPreviewSession];[self syncDiscoveryActivity];
    [[RewindStore shared]report:@{@"trailer_state":@"native_fallback_lookup",@"trailer_imdb":RWID(meta)}];
    [[RewindStore shared]nativeTrailer:meta done:^(id source,NSString *error){if(![weak.previewSession.key isEqual:key]||![weak.previewSession acceptSource:source!=nil generation:generation])return;weak.previewSource=source;[weak reportPreviewSession];if(source){[weak mountPreviewIfReady];[weak syncDiscoveryActivity];}else{[[RewindStore shared]report:@{@"trailer_state":@"artwork_only",@"trailer_error":error?:@"No compatible native preview"}];[weak syncDiscoveryActivity];}}];
}
- (void)mountPreviewIfReady {
    if(self.preview||!self.previewSource||![self.previewSession.state isEqual:@"loading"]||![self previewIsVisible])return;
    NSUInteger generation=self.previewSession.generation;__weak RewindController *weak=self;
    RWTrailerView *preview=[[RWTrailerView alloc]initWithFrame:self.previewStage.bounds];self.preview=preview;preview.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.previewStage insertSubview:preview belowSubview:self.heroOverlay];__weak RWTrailerView *weakPreview=preview;
    preview.onEmbeddedVisibility=^(BOOL shown){if(weak.preview==weakPreview)weak.heroOverlay.hidden=shown;};
    preview.onState=^(NSString *state){if(weak.preview!=weakPreview||weak.previewSession.generation!=generation)return;
        if([state isEqual:@"unavailable"]&&RWString(weak.previewSource[@"youtubeID"]).length&&[weak.previewSession beginNativeFallback]){NSUInteger fallbackGeneration=weak.previewSession.generation;dispatch_async(dispatch_get_main_queue(),^{if(weak.preview==weakPreview&&weak.previewSession.generation==fallbackGeneration)[weak loadNativePreviewFallback];});return;}
        if(![weak.previewSession event:state generation:generation])return;[weak reportPreviewSession];[weak syncDiscoveryActivity];
        if([@[@"ended",@"unavailable",@"released"]containsObject:state])dispatch_async(dispatch_get_main_queue(),^{if(weak.preview!=weakPreview||weak.previewSession.generation!=generation)return;[weak.preview stop];[weak.preview removeFromSuperview];weak.preview=nil;weak.previewSource=nil;weak.heroOverlay.hidden=NO;});
    };
    preview.onStore=^(NSString *url){NSURL *u=[NSURL URLWithString:url];if(![@[@"https",@"http"]containsObject:u.scheme]||[RewindStore shared].restricted)return;[weak.preview setVisible:NO];SFSafariViewController *store=[[SFSafariViewController alloc]initWithURL:u];[weak presentViewController:store animated:YES completion:nil];};
    [[RewindStore shared]setDiscoveryPaused:YES];[preview load:self.previewSource];[preview setVisible:YES];if(self.previewWantsSound)[preview playWithSound];
}
- (void)schedulePreview:(BOOL)withSound {
    if(self.reviewMode||![self.page isEqual:@"Details"]||!self.previewStage||self.loadingSources||NSProcessInfo.processInfo.systemUptime<self.discoveryMemoryCooldown)return;
    RewindStore *s=[RewindStore shared];if(![s allowed:self.detail])return;
    // Metadata can arrive after the initial card/title shell. Keep the preview
    // session waiting so the ordinary detail render can start it once identity
    // is complete; an incomplete title must not become a cached native miss.
    if([self.detail[@"type"]isEqual:@"movie"]&&!RWString(self.detail[@"preview"]).length&&![RWTrailerPolicy movieIdentityReady:self.detail])return;
    if(withSound&&self.preview.canPlay){[self.preview playWithSound];return;}
    if(!self.previewSession)self.previewSession=[RWPreviewSession new];[self.previewSession selectKey:[self currentPreviewKey]];
    if(![self.previewSession beginAllowed:[s.profile[@"autoplayTrailers"]boolValue] visible:[self previewIsVisible] manual:withSound])return;
    self.previewWantsSound=withSound;[self syncDiscoveryActivity];NSUInteger generation=self.previewSession.generation;NSString *key=self.previewSession.key;NSDictionary *meta=self.detail;__weak RewindController *weak=self;[self reportPreviewSession];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.15*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if(weak.previewSession.generation!=generation||![weak.previewSession.state isEqual:@"lookup"]||![weak.previewSession.key isEqual:key])return;
        [s trailer:meta done:^(id source,NSString *error){if(![weak.previewSession.key isEqual:key]||![weak.previewSession acceptSource:source!=nil generation:generation])return;
            weak.previewSource=source;[weak reportPreviewSession];if(!source){[s report:@{@"trailer_state":@"artwork_only",@"trailer_imdb":RWID(meta),@"trailer_error":error?:@"No compatible preview"}];[weak syncDiscoveryActivity];return;}[weak mountPreviewIfReady];[weak syncDiscoveryActivity];
        }];
    });
}
- (void)updatePreviewVisibility {
    BOOL visible=[self previewIsVisible];if(visible&&!self.preview){[self mountPreviewIfReady];if(!self.preview)[self schedulePreview:NO];}else[self.preview setVisible:visible];[self syncDiscoveryActivity];
}
- (void)resumePreviewAfterMenu {__weak RewindController *weak=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.4*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[weak applyPendingDetails];[weak updatePreviewVisibility];});}
- (void)updateEpisodeViewport:(BOOL)loadImages {
    if(!self.episodeList)return;
    CGRect viewport=[self.episodeList convertRect:self.content.bounds fromView:self.content];
    [self.episodeList updateViewport:viewport loadImages:loadImages];
    double now=NSProcessInfo.processInfo.systemUptime;
    if(!self.reviewMode&&now-self.lastEpisodeReport>1){self.lastEpisodeReport=now;[[RewindStore shared]report:@{@"episode_list":self.episodeList.diagnostics}];}
}
- (void)loadVisiblePosters {
    [[RewindStore shared]resumeArtwork];for(RWPosterCollection *rail in self.posterRails)[rail loadVisibleArtwork];for(RWPoster *poster in self.posters){if(self.reviewMode)[poster loadArtwork];else[poster loadArtworkIfVisible];}[self.downloadsList loadVisibleArtwork];[self.upcomingList loadVisibleArtwork];[self.homeView loadVisibleArtwork];[self.feedGrid loadVisibleArtwork];[self recordVisibleDiscovery];[self loadVisibleCast];[self updateEpisodeViewport:!self.content.dragging&&!self.content.decelerating];}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {if([scrollView.accessibilityIdentifier hasPrefix:@"RWrail:"]&&!self.reviewMode){if(!self.railOffsets)self.railOffsets=[NSMutableDictionary new];if(self.railOffsets.count>=128&&!self.railOffsets[scrollView.accessibilityIdentifier])[self.railOffsets removeObjectForKey:self.railOffsets.allKeys.firstObject];self.railOffsets[scrollView.accessibilityIdentifier]=@(scrollView.contentOffset.x);}
    double now=NSProcessInfo.processInfo.systemUptime;if(scrollView==self.content){[self updatePreviewVisibility];double dt=now-self.lastEpisodeScrollTime;double speed=dt>0&&self.lastEpisodeScrollTime>0?fabs(scrollView.contentOffset.y-self.lastEpisodeScrollY)/dt:0;[self updateEpisodeViewport:speed<600];self.lastEpisodeScrollTime=now;self.lastEpisodeScrollY=scrollView.contentOffset.y;}if(now-self.lastArtworkScroll>.1){self.lastArtworkScroll=now;[self loadVisiblePosters];}}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {[self applyPendingDetails];[self loadVisiblePosters];}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {if(!decelerate){[self applyPendingDetails];[self loadVisiblePosters];}}
- (void)viewDidDisappear:(BOOL)animated {[super viewDidDisappear:animated];[[RewindStore shared]setArtworkVisible:NO inView:self.view];[self.playbackPreparation cancel];[self releasePreview];}
- (void)viewDidAppear:(BOOL)animated {[super viewDidAppear:animated];[self presentProfileEntrance];[self restoreMyListPosition];[self processPendingReminder];[self applyPendingDetails];[[RewindStore shared]setArtworkVisible:YES inView:self.view];if([self.page isEqual:@"Downloads"])[self refreshDownloads];[self prepareCurrentTitle];[self loadVisiblePosters];if([self.page isEqual:@"Details"]&&!self.preview)[self schedulePreview:NO];[self syncDiscoveryActivity];}
- (void)previewBackground {[self discardParkedHome];[[RewindStore shared]setDiscoveryPaused:YES];[self.playbackPreparation cancel];[self releasePreview];[self.castService cancel];self.castRequestKey=nil;}
- (void)previewForeground {[self applyPendingDetails];[self syncDiscoveryActivity];[self prepareCurrentTitle];self.castRequestKey=nil;[self loadVisiblePosters];if([self.page isEqual:@"Details"])[self schedulePreview:NO];}
- (void)didReceiveMemoryWarning {[super didReceiveMemoryWarning];[self.homeFeeds discardMemory];self.homeDeferredBatch=nil;self.homeValidation=nil;[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(prepareHomeViewport) object:nil];[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(applyPreparedHome) object:nil];[self discardParkedHome];[RWDiscoveryEpisodes purgeReusableIndexes];[self.browseFeed discardMemory];[self.entityFeed discardMemory];[self.exploreFeed cancelPages];[self.exploreFeed discardMemory];self.exploreGeneration++;self.exploreBusy=NO;if([self.page isEqual:@"Explore"]){self.exploreError=@"Loading paused to free memory. Try again.";[self updateExploreGrid];}self.discoveryMemoryCooldown=NSProcessInfo.processInfo.systemUptime+30;self.entityGeneration++;self.entityBusy=NO;if([self.page isEqual:@"Entity"])self.entityError=@"This lookup paused to free memory. Try again shortly.";[[RewindStore shared]setDiscoveryPaused:YES];[self.playbackPreparation suspendForMemoryPressure];[self releasePreview];[self.castService cancel];self.castRequestKey=nil;}
- (void)ratingsChanged {
    [self.homeFeeds catalogChanged];
    [self appendNewlyRatedBrowse];[self appendNewlyRatedEntity];if([self.page isEqual:@"Entity"]){[self requestEntityHeader];[self updateEntityGrid];}
    if([RewindStore shared].restricted&&[self.page isEqual:@"Details"]&&![[RewindStore shared]allowed:self.detail]){[self.playbackPreparation cancel];[self stopPreview];[self go:@"Home"];return;}
    if([self.page isEqual:@"Details"]){
        if([RewindStore shared].restricted){
            // The old ranking captured an earlier maturity snapshot. Remove
            // revoked titles immediately and invalidate its pending callback.
            [[RewindStore shared]cancelRelatedTitles];self.relatedGeneration++;self.relatedKey=nil;
            self.relatedTitles=[[RewindStore shared]allowedItems:self.relatedTitles];[self requestRelatedTitles];
        }
        [self requestDetailRender];
    }
    if(![RewindStore shared].restricted||self.reviewMode)return;
    if([self.page isEqual:@"Upcoming"])[self updateUpcomingList];
    else if([self.page isEqual:@"Downloads"])[self refreshDownloads];
    else if([self.page isEqual:@"Search"]&&!self.presentedViewController)[self updateSearchResults];else if([@[@"Home",@"My List"]containsObject:self.page])[self scheduleCatalogRender];
}
- (void)feedbackMenu {
    __weak RewindController *weak=self;RewindStore *s=[RewindStore shared];NSDictionary *meta=self.detail;
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Make recommendations yours" message:@"Your choices affect only this profile." preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"Like / undo like" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){[s feedback:meta like:YES];[weak render];}]];
    [a addAction:[UIAlertAction actionWithTitle:@"Not for me" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){[s feedback:meta like:NO];[weak go:@"Home"];}]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=self.content;a.popoverPresentationController.sourceRect=CGRectMake([self width]-200,480,150,48);[self presentViewController:a animated:YES completion:nil];
}
