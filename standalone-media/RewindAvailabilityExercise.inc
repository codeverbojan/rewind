// Read-only browsing acceptance. Use live displayed rows and current policy;
// no synthetic source observations, reminder changes or player launches.
- (NSDictionary *)exerciseAvailabilityTitle:(NSDictionary *)meta {
    RewindStore *s=[RewindStore shared];NSString *video=[s availabilityVideoID:meta];NSDictionary *observation=s.profile[@"sourceAvailability"][video?:@""]?:@{};
    return @{@"id":RWID(meta),@"name":RWString(meta[@"name"]),@"type":RWString(meta[@"type"]),@"released":RWString(meta[@"released"]),@"year":RWString(meta[@"releaseInfo"]),@"rating":meta[@"imdbRating"]?:@"",@"allowed":@([s allowed:meta]),@"hidden":@([s.profile[@"hidden"]containsObject:RWID(meta)]),@"pending":@([meta[@"homePreparationPending"]boolValue]),@"availability":[s availability:meta],@"video_id":video?:@"",@"lookup_state":observation[@"state"]?:@"",@"ready_at":observation[@"ready_at"]?:@0,@"watching":@([s watchingAvailability:meta]),@"following":@([s following:meta]),@"scheduled":@([RWUpcomingPolicy scheduled:meta now:NSDate.date.timeIntervalSince1970]),@"scheduled_episode":meta[@"scheduledEpisode"]?:@{},@"language_allowed":@([RWDiscoveryMetadataPolicy permits:meta preferences:s.profile[@"discoveryPreferences"] world:NO]),@"world_allowed":@([RWDiscoveryMetadataPolicy permits:meta preferences:s.profile[@"discoveryPreferences"] world:YES])};
}
- (NSDictionary *)exerciseAvailabilitySnapshot {
    RewindStore *s=[RewindStore shared];NSMutableArray *rows=[NSMutableArray new],*items=[NSMutableArray new];
    if([self.page isEqual:@"Home"])for(NSDictionary *row in self.homeView.displayedRows){NSMutableArray *cards=[NSMutableArray new];for(NSDictionary *meta in row[@"items"])[cards addObject:[self exerciseAvailabilityTitle:meta]];[rows addObject:@{@"id":row[@"id"]?:@"",@"title":row[@"title"]?:@"",@"cards":cards}];}
    if([self.page isEqual:@"Upcoming"])for(NSDictionary *meta in self.upcomingList.items)[items addObject:[self exerciseAvailabilityTitle:meta]];
    NSDictionary *hero=self.homeHeaderRecord[@"hero"]?:@{};
    return @{@"width":@(self.view.bounds.size.width),@"height":@(self.view.bounds.size.height),@"page":self.page?:@"",@"profile":s.state[@"activeProfile"],@"restricted":@(s.restricted),@"rows":rows,@"hero":RWID(hero).length?[self exerciseAvailabilityTitle:hero]:@{},@"mode":self.upcomingMode?:@"",@"release_kind":self.upcomingKind?:@"movie",@"upcoming":items,@"detail":[self.page isEqual:@"Details"]?[self exerciseAvailabilityTitle:self.detail]:@{},@"play_button":self.moviePlayButton.currentTitle?:@"",@"detail_target":self.exerciseAvailabilityTarget?:@"",@"upcoming_days":@([s upcomingDays]),@"offset":@(self.upcomingList.contentOffset.y),@"list_diagnostics":self.upcomingList.diagnostics?:@{}};
}
- (BOOL)exerciseAvailabilityStep:(NSString *)kind {
    if([kind isEqual:@"avail-upcoming"]||[kind isEqual:@"avail-upcoming-refresh"]){BOOL opened=[self exercisePressNavigation:@"Upcoming"]&&[self.page isEqual:@"Upcoming"];if(opened&&[kind isEqual:@"avail-upcoming-refresh"])[[RewindStore shared]retryUpcoming];return opened;}
    if([kind isEqual:@"avail-episodes"]){if(![self.page isEqual:@"Upcoming"])return NO;for(UIView *v in self.content.subviews)if([v.accessibilityIdentifier isEqual:@"UpcomingKind"]){UISegmentedControl *tabs=(UISegmentedControl *)v;tabs.selectedSegmentIndex=1;[tabs sendActionsForControlEvents:UIControlEventValueChanged];return YES;}return NO;}
    if([kind isEqual:@"avail-scroll-coming"]){if(![self.page isEqual:@"Upcoming"])return NO;[self.upcomingList setContentOffset:CGPointMake(0,MAX(0,self.upcomingList.contentSize.height-self.upcomingList.bounds.size.height)) animated:NO];[self.upcomingList loadVisibleArtwork];[self.upcomingList loadMoreIfNearEnd];return YES;}
    if([kind isEqual:@"avail-waiting"]||[kind isEqual:@"avail-following"]){
        if(![self.page isEqual:@"Upcoming"])return NO;for(UIView *view in self.content.subviews)if([view isKindOfClass:UISegmentedControl.class]){UISegmentedControl *tabs=(UISegmentedControl *)view;if(tabs.numberOfSegments==3&&[[tabs titleForSegmentAtIndex:0]isEqual:@"Coming soon"]){tabs.selectedSegmentIndex=[kind isEqual:@"avail-waiting"]?1:2;[tabs sendActionsForControlEvents:UIControlEventValueChanged];return YES;}}return NO;
    }
    if([kind isEqual:@"avail-open-followed"]){
        if(![self.page isEqual:@"Upcoming"]||![self.upcomingMode isEqual:@"Following"])return NO;
        for(NSIndexPath *path in [self.upcomingList.indexPathsForVisibleRows sortedArrayUsingSelector:@selector(compare:)]){NSDictionary *meta=[self.upcomingList metaAtPath:path];if([meta[@"type"]isEqual:@"movie"]){self.exerciseAvailabilityTarget=RWID(meta);self.exerciseExploreOffset=self.upcomingList.contentOffset.y;[self.upcomingList.delegate tableView:self.upcomingList didSelectRowAtIndexPath:path];return [self.page isEqual:@"Details"];}}return NO;
    }
    if([kind isEqual:@"avail-back"])return [self exerciseContentBack]&&[self.page isEqual:@"Upcoming"];
    if(![kind hasPrefix:@"avail-audit-"])return NO;
    NSDictionary *snapshot=[self exerciseAvailabilitySnapshot];NSString *target=[kind substringFromIndex:[@"avail-audit-" length]];BOOL ok=YES;
    if([target hasPrefix:@"home"]){
        ok=[self.page isEqual:@"Home"]&&[snapshot[@"rows"]count]>0;NSMutableSet *seen=[NSMutableSet new];NSDictionary *hero=snapshot[@"hero"];
        if([hero count]){ok=ok&&[hero[@"availability"][@"hero_eligible"]boolValue]&&[hero[@"allowed"]boolValue];[seen addObject:hero[@"id"]];}
        for(NSDictionary *row in snapshot[@"rows"]){BOOL task=[@[@"continue",@"up-next"]containsObject:row[@"id"]];NSString *type=nil;
            for(NSDictionary *card in row[@"cards"]){if([seen containsObject:card[@"id"]]||![card[@"allowed"]boolValue]||[card[@"hidden"]boolValue])ok=NO;[seen addObject:card[@"id"]];if(task)continue;
                if(type&&![type isEqual:card[@"type"]])ok=NO;type=card[@"type"];
                if(![card[@"pending"]boolValue]&&(![card[@"availability"][@"discovery_eligible"]boolValue]||[card[@"availability"][@"watch_instead_of_play"]boolValue]))ok=NO;
            }
            if(!task&&type.length){NSString *word=[type isEqual:@"movie"]?@"Films":@"Series";if([row[@"title"]rangeOfString:word options:NSCaseInsensitiveSearch].location==NSNotFound)ok=NO;}
        }
    }else if([target isEqual:@"detail"]){NSDictionary *d=snapshot[@"detail"];BOOL waiting=[d[@"availability"][@"watch_instead_of_play"]boolValue];NSString *button=snapshot[@"play_button"];ok=[self.page isEqual:@"Details"]&&[d[@"id"]isEqual:self.exerciseAvailabilityTarget]&&[d[@"watching"]boolValue]&&(waiting?[button isEqual:@"Reminder set"]:[@[@"Play",@"Resume"]containsObject:button]);}
    else {NSString *mode=[target hasPrefix:@"coming"]?@"Coming soon":[target isEqual:@"waiting"]?@"Waiting":@"Following";ok=[self.page isEqual:@"Upcoming"]&&[self.upcomingMode isEqual:mode];
        for(NSDictionary *card in snapshot[@"upcoming"]){if(![card[@"allowed"]boolValue])ok=NO;NSString *state=card[@"availability"][@"state"];if([mode isEqual:@"Following"]){if(![card[@"watching"]boolValue]&&![card[@"following"]boolValue])ok=NO;}else if(![state isEqual:[mode isEqual:@"Waiting"]?@"waiting":@"upcoming"]&&!([mode isEqual:@"Coming soon"]&&[card[@"scheduled"]boolValue]))ok=NO;}
        if([target hasPrefix:@"coming"]&&![target isEqual:@"coming-lower"]){ok=ok&&fabs(self.upcomingList.contentOffset.y)<=0.5;NSString *type=[target hasPrefix:@"coming-episodes"]?@"series":@"movie";for(NSDictionary *m in snapshot[@"upcoming"])ok=ok&&[m[@"type"]isEqual:type];}
        if([target isEqual:@"return"])ok=ok&&fabs(self.upcomingList.contentOffset.y-self.exerciseExploreOffset)<=1;
    }
    return [self exerciseCastCapture:[@"device-exercise-availability-" stringByAppendingString:target]]&&ok;
}
