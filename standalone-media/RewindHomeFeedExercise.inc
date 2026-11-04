- (NSDictionary *)exerciseHomeArtworkSnapshot {
    NSMutableArray *views=[NSMutableArray arrayWithArray:self.homeView.visibleCells],*cards=[NSMutableArray new];NSUInteger loaded=0;
    while(views.count){UIView *v=views.lastObject;[views removeLastObject];
        if([v isKindOfClass:RWPoster.class]){RWPoster *p=(RWPoster *)v;if(![p artworkVisible]||!RWID(p.meta).length)continue;NSMutableDictionary *d=[p.artworkState mutableCopy];d[@"id"]=RWID(p.meta);d[@"name"]=RWString(p.meta[@"name"]);[cards addObject:d];loaded+=[d[@"loaded"]boolValue];}
        else [views addObjectsFromArray:v.subviews];
    }
    NSDictionary *home=self.homeView.diagnostics;BOOL ready=cards.count>0&&loaded==cards.count&&![home[@"visible_pending_titles"]unsignedIntegerValue]&&![home[@"content_pending"]boolValue];
    return @{@"cards":cards,@"loaded":@(loaded),@"settled":@(ready),@"home":home};
}
- (RWPosterCollection *)exerciseHomeRail:(NSString *)key {
    for(NSUInteger i=0;i<self.homeView.displayedRows.count;i++)if([self.homeView.displayedRows[i][@"id"]isEqual:key]){
        NSIndexPath *path=[NSIndexPath indexPathForRow:i inSection:0];[self.homeView scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionTop animated:NO];[self.homeView layoutIfNeeded];UITableViewCell *cell=[self.homeView cellForRowAtIndexPath:path];NSMutableArray *views=[NSMutableArray arrayWithObject:cell.contentView];
        while(views.count){UIView *v=views.lastObject;[views removeLastObject];if([v isKindOfClass:RWPosterCollection.class])return (RWPosterCollection *)v;[views addObjectsFromArray:v.subviews];}
    }return nil;
}
- (BOOL)exerciseHomeRailStep:(NSDictionary *)step {
    NSString *kind=step[@"kind"],*key=step[@"row"];
    if([kind isEqual:@"rail-destination"]){self.exerciseRailSettleStarted=NSProcessInfo.processInfo.systemUptime;BOOL ok=[self exercisePressNavigation:step[@"destination"]];[self.homeView setContentOffset:CGPointZero animated:NO];return ok&&[self.page isEqual:@"Home"]&&self.homeView.window;}
    if(![self.page isEqual:@"Home"]||!self.homeView.window)return NO;
    if([kind isEqual:@"rail-categories-settle-artwork"]){
        double now=NSProcessInfo.processInfo.systemUptime;if(self.exerciseRailSettleIndex!=self.exerciseIndex){self.exerciseRailSettleIndex=self.exerciseIndex;self.exerciseRailSettleStarted=now;}
        if(![[self exerciseHomeArtworkSnapshot][@"settled"]boolValue]&&now-self.exerciseRailSettleStarted<12)self.exerciseIndex--;
        return YES; // The following capture records and fails any timeout.
    }
    if([kind isEqual:@"rail-categories-ready"]){
        NSDictionary *refresh=[RewindStore.shared homeAvailabilityDiagnostics],*pass=refresh[@"last_pass"];NSString *type=[self.filter isEqual:@"Movies"]?@"movie":[self.filter isEqual:@"Series"]?@"series":@"all";
        BOOL settled=![refresh[@"active"]boolValue]&&![refresh[@"waiting_preparation"]boolValue]&&[refresh[@"media_type"]isEqual:type]&&[pass[@"media_type"]isEqual:type]&&[pass[@"profile"]isEqual:RewindStore.shared.state[@"activeProfile"]]&&[pass[@"generation"]isEqual:refresh[@"generation"]];
        if(!settled||[self.homePlan[@"layoutVersion"]integerValue]<229||[self.homeFeeds.diagnostics[@"activating"]boolValue]||![self.homeView visibleMetadata].count){if(NSProcessInfo.processInfo.systemUptime-self.exerciseRailSettleStarted>16)return NO;self.exerciseIndex--;return YES;}return YES;
    }
    if([kind isEqual:@"rail-categories-lower"]){NSString *target=nil;for(NSDictionary *row in self.homeView.displayedRows)if([row[@"recipe"]isEqual:@"category"]){target=row[@"id"];break;}if(target)[self exerciseHomeRail:target];else [self.homeView setContentOffset:CGPointMake(0,MAX(0,self.homeView.contentSize.height-self.homeView.bounds.size.height)) animated:NO];return YES;}
    if([kind isEqual:@"rail-categories-audit"]){
        RewindStore *s=[RewindStore shared];NSMutableArray *rows=[NSMutableArray new],*titles=[NSMutableArray new],*rails=[NSMutableArray new];NSUInteger denied=0,wrongType=0,unknown=0;NSString *type=[self.filter isEqual:@"All"]?nil:[self.filter isEqual:@"Series"]?@"series":@"movie";
        for(NSDictionary *row in self.homeView.displayedRows){RWHomeRowFeed *feed=row[@"feed"];NSMutableDictionary *out=[NSMutableDictionary new];for(NSString *field in @[@"id",@"title",@"recipe",@"mediaType",@"landscape",@"anyGenres",@"allGenres",@"maxMinutes"]){if(row[field])out[field]=row[field];}out[@"count"]=@(feed?feed.count:[row[@"items"]count]);[rows addObject:out];if(type.length&&row[@"mediaType"]&&![row[@"mediaType"]isEqual:type])wrongType++;}
        for(NSDictionary *m in [self.homeView visibleMetadata]){BOOL allowed=[s allowed:m];denied+=!allowed;wrongType+=type.length&&![m[@"type"]isEqual:type];NSDictionary *rating=[s.ratings rating:RWID(m)];unknown+=s.restricted&&(!rating||[rating[@"minimumAge"]integerValue]<0);[titles addObject:@{@"id":RWID(m),@"name":m[@"name"]?:@"",@"type":m[@"type"]?:@"",@"allowed":@(allowed),@"minimum_age":rating[@"minimumAge"]?:@(-1),@"recommendation_audience_allowed":@([RWDiscoveryMetadataPolicy recommendationAudienceAllows:m preferences:s.profile[@"discoveryPreferences"] restricted:s.restricted]),@"genres":m[@"genres"]?:@[],@"runtime":m[@"runtime"]?:@""}];}
        NSMutableArray *views=[NSMutableArray arrayWithArray:self.homeView.visibleCells];while(views.count){UIView *v=views.lastObject;[views removeLastObject];if([v isKindOfClass:RWPosterCollection.class])[rails addObject:[(RWPosterCollection *)v continuationDiagnostics]];[views addObjectsFromArray:v.subviews];}
        NSString *name=[NSString stringWithFormat:@"device-exercise-rail-categories-%@-%@-%@",s.restricted?@"kids":@"regular",self.filter,step[@"label"]];RWCapture(self.view,name);
        self.exerciseProfileAudit=@{@"artwork":[self exerciseHomeArtworkSnapshot],@"artwork_settle_seconds":@([step[@"label"]isEqual:@"settled"]?NSProcessInfo.processInfo.systemUptime-self.exerciseRailSettleStarted:0),@"orientation":@(UIApplication.sharedApplication.statusBarOrientation),@"root_width":@(self.view.bounds.size.width),@"root_height":@(self.view.bounds.size.height),@"key_window":@(self.view.window.isKeyWindow),@"availability_refresh":[s homeAvailabilityDiagnostics],@"home_continuation":self.homeFeeds.diagnostics,@"layout":self.homePlan[@"layoutVersion"]?:@0,@"rows":rows,@"rails":rails,@"titles":titles,@"denied":@(denied),@"wrong_type":@(wrongType),@"unknown_age":@(unknown),@"profile":s.state[@"activeProfile"],@"restricted":@(s.restricted),@"destination":self.filter,@"capture":name};return !denied&&!wrongType&&!unknown&&(![step[@"label"]isEqual:@"settled"]||[[self exerciseHomeArtworkSnapshot][@"settled"]boolValue]);
    }
    RWPosterCollection *rail=[self exerciseHomeRail:key];
    if(!rail||!rail.feed){if([kind isEqual:@"rail-ready"]){self.exerciseIndex--;return YES;}return NO;}
    if([kind isEqual:@"rail-ready"]){if([[self.homeFeeds diagnostics][@"activating"]boolValue]||(rail.feed.count&&![rail visibleMetadata].count)){self.exerciseIndex--;return YES;}return YES;}
    if([kind isEqual:@"rail-end"]){[rail.delegate scrollViewWillBeginDragging:rail];[rail layoutIfNeeded];CGFloat end=MAX(12,rail.contentSize.width-rail.bounds.size.width);if(fabs(rail.contentOffset.x-end)<1)[rail setContentOffset:CGPointMake(MAX(0,end-rail.bounds.size.width),0) animated:NO];[rail setContentOffset:CGPointMake(end,0) animated:YES];return YES;}
    if([kind isEqual:@"rail-await"]){if([[rail continuationDiagnostics][@"loading"]boolValue]||[[self.homeFeeds diagnostics][@"active"]length]){self.exerciseIndex--;return YES;}return YES;}
    if([kind isEqual:@"rail-settled"]){
        double now=NSProcessInfo.processInfo.systemUptime;if(self.exerciseRailSettleIndex!=self.exerciseIndex){self.exerciseRailSettleIndex=self.exerciseIndex;self.exerciseRailSettleStarted=now;}
        NSDictionary *d=rail.continuationDiagnostics,*h=self.homeFeeds.diagnostics;
        BOOL ready=![d[@"loading"]boolValue]&&![d[@"range_loading"]boolValue]&&![d[@"updating"]boolValue]&&[d[@"visible_slots"]unsignedIntegerValue]>0&&![d[@"pending_cells"]unsignedIntegerValue]&&![h[@"active"]length]&&![h[@"activating"]boolValue];
        // Preserve the immediate capture. This separate, bounded observation
        // proves whether existing metadata actually becomes visible before we
        // compare the viewport through a profile return. Timeout remains visible
        // in the next audit; it never counts as a passing ready window.
        if(!ready&&now-self.exerciseRailSettleStarted<8){self.exerciseIndex--;return YES;}return YES;
    }
    if([kind isEqual:@"rail-audit"]){
        RewindStore *s=[RewindStore shared];NSUInteger denied=0,unknown=0;NSMutableArray *titles=[NSMutableArray new];
        for(NSDictionary *m in [rail visibleMetadata]){NSDictionary *rating=[s.ratings rating:RWID(m)];BOOL allowed=[s allowed:m];denied+=!allowed;unknown+=s.restricted&&(!rating||[rating[@"minimumAge"]integerValue]<0);[titles addObject:@{@"id":RWID(m),@"type":m[@"type"]?:@"",@"allowed":@(allowed),@"minimum_age":rating[@"minimumAge"]?:@(-1),@"availability":[s availability:m videoID:[s availabilityVideoID:m]],@"language":[RWDiscoveryMetadataPolicy languageGroup:m[@"discovery"]]?:@"",@"card_text":[RWHomePresentation cardText:m]}];}
        NSString *name=[NSString stringWithFormat:@"device-exercise-rail-%@-%@-%@",s.restricted?@"kids":@"regular",key,step[@"label"]?:@"view"];RWCapture(self.view,name);
        self.exerciseProfileAudit=@{@"home_continuation":self.homeFeeds.diagnostics,@"ratings":s.ratings.diagnostics,@"headings":[self.homeView.displayedRows valueForKey:@"title"],@"rail":rail.continuationDiagnostics,@"titles":titles,@"denied":@(denied),@"unknown_age":@(unknown),@"profile":s.state[@"activeProfile"],@"restricted":@(s.restricted),@"capture":name};return !denied&&!unknown;
    }return NO;
}
