// Live provider paging plus a separately labelled component fault fixture.
// No profile mutations, movie playback or provider-result substitution.
- (NSDictionary *)exerciseFeedSnapshot {
    RWPosterCollection *grid=self.exerciseFeedFixture?:self.feedGrid;NSMutableDictionary *snapshot=[[grid continuationDiagnostics]mutableCopy]?:[NSMutableDictionary new];
    snapshot[@"page"]=self.page?:@"";snapshot[@"kind"]=self.exerciseFeedKind?:@"";snapshot[@"profile"]=[RewindStore shared].state[@"activeProfile"];snapshot[@"anchor"]=self.exerciseFeedAnchor?:@{};snapshot[@"fixture"]=@(self.exerciseFeedFixture!=nil);snapshot[@"title"]=self.exerciseFeedTitle?:@"";snapshot[@"explore"]=[self exerciseDiscoverySnapshot];return snapshot;
}
- (BOOL)exerciseFeedStep:(NSString *)kind {
    RewindStore *s=RewindStore.shared;
    if([@[@"feed-open-movies",@"feed-open-series",@"feed-open-entity",@"feed-open-studio"]containsObject:kind]){
        self.exerciseFeedKind=[kind substringFromIndex:10];self.exerciseFeedAnchor=nil;self.exerciseFeedStarted=NSProcessInfo.processInfo.systemUptime;
        if([self.exerciseFeedKind isEqual:@"studio"]){[self openEntity:@{@"id":@"Q127552",@"name":@"Pixar",@"type":@"studio",@"creditRole":@"studio",@"roles":@[@"studio"],@"profileID":s.state[@"activeProfile"],@"verifiedEntity":@YES}];}
        else if([self.exerciseFeedKind isEqual:@"entity"]){[self openEntity:@{@"id":@"Q25191",@"name":@"Christopher Nolan",@"type":@"person",@"creditRole":@"director",@"roles":@[@"director"],@"profileID":s.state[@"activeProfile"],@"verifiedEntity":@YES}];}
        else{[self resetBrowse];if(![self exercisePressNavigation:[self.exerciseFeedKind isEqual:@"series"]?@"Series":@"Movies"])return NO;self.browseGenre=@"Comedy";[self browseChanged];}
        return YES;
    }
    if([kind isEqual:@"feed-await-start"]||[kind isEqual:@"feed-await-page"]){
        NSDictionary *snap=[self exerciseFeedSnapshot];if([snap[@"error"]length]||NSProcessInfo.processInfo.systemUptime-self.exerciseFeedStarted>45)return NO;
        // A director biography may fill the first viewport. Loaded credits are
        // sufficient before scrolling; the appended page must expose cards.
        BOOL headerFirst=[kind isEqual:@"feed-await-start"]&&[@[@"entity",@"studio"]containsObject:self.exerciseFeedKind];
        BOOL ready=[snap[@"count"]unsignedIntegerValue]>0&&![snap[@"loading"]boolValue]&&(headerFirst||[snap[@"visible"]count]>0);
        if([kind isEqual:@"feed-await-page"])ready=ready&&([snap[@"cursor"]unsignedIntegerValue]>[self.exerciseFeedAnchor[@"cursor"]unsignedIntegerValue]||[snap[@"count"]unsignedIntegerValue]>[self.exerciseFeedAnchor[@"count"]unsignedIntegerValue]||![snap[@"more"]boolValue]);
        if(!ready)self.exerciseIndex--;return YES;
    }
    if([kind isEqual:@"feed-scroll-end"]){
        if(![[self.feedGrid continuationDiagnostics][@"more"]boolValue])return NO;
        [self.feedGrid layoutIfNeeded];[self.feedGrid setContentOffset:CGPointMake(0,MAX(0,self.feedGrid.contentSize.height-self.feedGrid.bounds.size.height)) animated:NO];
        self.exerciseFeedAnchor=[self.feedGrid continuationDiagnostics];self.exerciseFeedStarted=NSProcessInfo.processInfo.systemUptime;return YES;
    }
    if([kind isEqual:@"feed-audit-page"]){
        NSDictionary *snap=[self exerciseFeedSnapshot],*before=self.exerciseFeedAnchor;double anchor=[before[@"offset"]doubleValue]-[before[@"header_height"]doubleValue],offset=[snap[@"offset"]doubleValue]-[snap[@"header_height"]doubleValue];
        BOOL ok=[snap[@"auto_requests"]unsignedIntegerValue]>[before[@"auto_requests"]unsignedIntegerValue]&&[snap[@"manual_requests"]unsignedIntegerValue]==0&&[snap[@"count"]unsignedIntegerValue]>=[before[@"count"]unsignedIntegerValue]&&fabs(offset-anchor)<=2;
        NSMutableSet *ids=[NSMutableSet new];for(NSDictionary *card in snap[@"visible"]){if([ids containsObject:card[@"id"]])ok=NO;[ids addObject:card[@"id"]];if([@[@"movies",@"series"]containsObject:self.exerciseFeedKind]&&![card[@"type"]isEqual:[self.exerciseFeedKind isEqual:@"series"]?@"series":@"movie"])ok=NO;}
        RWCapture(self.view,[@"device-exercise-feed-page-" stringByAppendingString:self.exerciseFeedKind]);return ok;
    }
    if([kind isEqual:@"feed-open-title"]){
        for(RWPoster *poster in [self exerciseDiscoveryCards])if([s allowed:poster.meta]){self.exerciseFeedAnchor=[self.feedGrid continuationDiagnostics];self.exerciseFeedTitle=RWID(poster.meta);[poster sendActionsForControlEvents:UIControlEventTouchUpInside];return [self.page isEqual:@"Details"]&&[RWID(self.detail)isEqual:self.exerciseFeedTitle];}return NO;
    }
    if([kind isEqual:@"feed-back"])return [self exerciseContentBack];
    if([kind isEqual:@"feed-audit-return"]){
        NSDictionary *snap=[self exerciseFeedSnapshot],*anchor=self.exerciseFeedAnchor;BOOL ok=[snap[@"context"]isEqual:anchor[@"context"]]&&[snap[@"count"]unsignedIntegerValue]>=[anchor[@"count"]unsignedIntegerValue]&&fabs([snap[@"offset"]doubleValue]-[anchor[@"offset"]doubleValue])<=2;
        RWCapture(self.view,[@"device-exercise-feed-return-" stringByAppendingString:self.exerciseFeedKind]);return ok;
    }
    if([kind isEqual:@"feed-query-first"]){self.exerciseFeedKind=@"query";self.exerciseFeedStarted=NSProcessInfo.processInfo.systemUptime;return [self exerciseDiscoveryQuery:@"Warner"];}
    if([kind isEqual:@"feed-query-final"]){
        self.exerciseFeedAnchor=[self exerciseDiscoverySnapshot];self.exerciseFeedStarted=NSProcessInfo.processInfo.systemUptime;return [self exerciseDiscoveryQuery:@"Pixar"];
    }
    if([kind isEqual:@"feed-await-query"]||[kind isEqual:@"feed-audit-query"]){
        NSDictionary *view=[self exerciseDiscoverySnapshot];BOOL ready=[view[@"query"]isEqual:@"Pixar"]&&![view[@"busy"]boolValue]&&[self.exploreFeed.context hasSuffix:@":Pixar"]&&[[(NSArray *)view[@"visible"]firstObject][@"id"]isEqual:@"Q127552"];
        if(!ready){if([kind isEqual:@"feed-audit-query"]||[view[@"error"]length]||NSProcessInfo.processInfo.systemUptime-self.exerciseFeedStarted>30)return NO;self.exerciseIndex--;return YES;}
        if([kind isEqual:@"feed-audit-query"]){RWCapture(self.view,@"device-exercise-feed-query");self.exerciseFeedStarted=NSProcessInfo.processInfo.systemUptime;}return YES;
    }
    if([kind isEqual:@"feed-mood-await"]){
        if(![self.page isEqual:@"Explore"]||![self.exploreMood isEqual:@"Epic adventures"]||NSProcessInfo.processInfo.systemUptime-self.exerciseFeedStarted>45)return NO;
        self.exerciseFeedKind=@"mood";NSDictionary *view=[self exerciseDiscoverySnapshot];
        if([view[@"error"]length])return NO;if([view[@"busy"]boolValue]||![view[@"count"]unsignedIntegerValue]||![view[@"visible"]count])self.exerciseIndex--;return YES;
    }
    if([kind isEqual:@"feed-mood-scroll"]){
        self.exerciseFeedAnchor=[self.feedGrid continuationDiagnostics];[self.feedGrid layoutIfNeeded];[self.feedGrid setContentOffset:CGPointMake(0,MAX(0,self.feedGrid.contentSize.height-self.feedGrid.bounds.size.height)) animated:NO];return YES;
    }
    if([kind isEqual:@"feed-mood-audit"]){
        NSDictionary *snap=[self exerciseFeedSnapshot];NSString *type=[self.exploreType isEqual:@"Shows"]?@"series":@"movie";NSArray *cards=snap[@"visible"];NSMutableSet *seen=[NSMutableSet new];
        if([snap[@"error"]length]||[snap[@"loading"]boolValue]||[snap[@"more"]boolValue]||![cards count]||[snap[@"count"]unsignedIntegerValue]!=[self.exerciseFeedAnchor[@"count"]unsignedIntegerValue])return NO;
        for(NSDictionary *card in cards){if(![card[@"type"]isEqual:type]||[seen containsObject:card[@"id"]])return NO;[seen addObject:card[@"id"]];}
        RWCapture(self.view,[@"device-exercise-feed-mood-" stringByAppendingString:type]);return YES;
    }
    if([kind isEqual:@"feed-fixture"]){
        NSMutableArray *items=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];for(NSDictionary *m in s.movies)if([s allowed:m]&&![seen containsObject:RWID(m)]){[items addObject:m];[seen addObject:RWID(m)];if(items.count==12)break;}if(items.count!=12)return NO;
        self.exerciseFeedKind=@"controlled-retry";self.exerciseFeedFixtureCards=items;self.exerciseFeedAnchor=nil;
        RWPosterCollection *grid=[[RWPosterCollection alloc]initWithFrame:CGRectMake(0,84,[self width],self.view.bounds.size.height-84)];self.exerciseFeedFixture=grid;grid.backgroundColor=RWColor(0x0e1116);__weak RewindController *weak=self;NSString *run=self.exerciseRequest[@"run"];
        grid.onLoadMore=^(BOOL manual){RewindController *controller=weak;if(!controller||![controller.exerciseRequest[@"run"]isEqual:run])return;RWPosterCollection *view=controller.exerciseFeedFixture;
            NSArray *first=[controller.exerciseFeedFixtureCards subarrayWithRange:NSMakeRange(0,6)];[view updateItems:first loading:YES more:YES error:nil cursor:6 automatic:YES];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,.4*NSEC_PER_SEC),dispatch_get_main_queue(),^{RewindController *c=weak;if(!c||![c.exerciseRequest[@"run"]isEqual:run]||c.exerciseFeedFixture!=view)return;[view updateItems:manual?c.exerciseFeedFixtureCards:first loading:NO more:!manual error:manual?nil:@"Connection interrupted. Try again." cursor:manual?12:6 automatic:YES];});
        };
        [self.view addSubview:grid];[grid updateItems:[items subarrayWithRange:NSMakeRange(0,6)] loading:NO more:YES error:nil cursor:0 automatic:YES];return YES;
    }
    if([kind isEqual:@"feed-fixture-error"]){RWPosterCollection *grid=self.exerciseFeedFixture;[grid layoutIfNeeded];[grid setContentOffset:CGPointMake(0,MAX(0,grid.contentSize.height-grid.bounds.size.height)) animated:NO];[grid layoutIfNeeded];NSDictionary *state=[grid continuationDiagnostics];BOOL retry=NO;for(NSDictionary *footer in state[@"footers"])retry|=[footer[@"button"]isEqual:@"Try again"];self.exerciseFeedAnchor=state;RWCapture(self.view,@"device-exercise-feed-error");return [state[@"count"]intValue]==6&&[state[@"auto_requests"]intValue]==1&&[state[@"error"]length]&&retry;}
    if([kind isEqual:@"feed-fixture-retry"]){for(UIView *footer in [self.exerciseFeedFixture visibleSupplementaryViewsOfKind:UICollectionElementKindSectionFooter])for(UIView *v in footer.subviews)if([v isKindOfClass:RWButton.class]&&[[(RWButton *)v currentTitle]isEqual:@"Try again"]&&!v.hidden){[(RWButton *)v sendActionsForControlEvents:UIControlEventTouchUpInside];return YES;}return NO;}
    if([kind isEqual:@"feed-fixture-appended"]){NSDictionary *snap=[self.exerciseFeedFixture continuationDiagnostics];return [snap[@"count"]intValue]==12&&![snap[@"error"]length]&&[snap[@"manual_requests"]intValue]==1&&[snap[@"auto_requests"]intValue]==1&&fabs([snap[@"offset"]doubleValue]-[self.exerciseFeedAnchor[@"offset"]doubleValue])<=2;}
    if([kind isEqual:@"feed-fixture-end"]){RWPosterCollection *grid=self.exerciseFeedFixture;[grid layoutIfNeeded];[grid setContentOffset:CGPointMake(0,MAX(0,grid.contentSize.height-grid.bounds.size.height)) animated:NO];[grid layoutIfNeeded];NSDictionary *snap=[grid continuationDiagnostics];BOOL done=NO;for(NSDictionary *f in snap[@"footers"])done|=[f[@"label"]isEqual:@"You’re all caught up"]&&![f[@"button"]length];RWCapture(self.view,@"device-exercise-feed-end");return done;}
    if([kind isEqual:@"feed-fixture-dismiss"]){[self.exerciseFeedFixture removeFromSuperview];self.exerciseFeedFixture.onLoadMore=nil;self.exerciseFeedFixture=nil;self.exerciseFeedFixtureCards=nil;return YES;}
    return NO;
}
