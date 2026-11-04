// Ordinary Upcoming/detail/related screens, scoped to two disposable profiles.
// Controlled maturity transitions never alter stored ratings or real profiles.
- (NSDictionary *)exerciseKidsSurfacesSnapshot {
    RewindStore *s=RewindStore.shared;NSMutableArray *fixture=[NSMutableArray new];
    for(NSDictionary *m in self.upcomingList.items)if([RWID(m)hasPrefix:@"rw:kids-surface-"])[fixture addObject:m];
    NSMutableArray *r=[NSMutableArray arrayWithArray:self.relatedTitles?:@[]];if([self.page isEqual:@"Details"]&&self.detail)[r addObject:self.detail];
    return @{@"page":self.page?:@"",@"profile":s.state[@"activeProfile"],@"age":s.profile[@"maxAge"],@"mode":self.upcomingMode?:@"",@"upcoming":[self exerciseKidsTitleAudit:self.upcomingList.items?:@[]],@"fixture":[self exerciseKidsTitleAudit:fixture],@"detail":[self exerciseDetailSnapshot],@"related_audit":[self exerciseKidsTitleAudit:r],@"related_key":self.relatedKey?:@"",@"generation":@(self.relatedGeneration),@"revoked_related":self.exerciseKidsRevoked?:@"",@"overrides":[self.exerciseKidsRatings.overrides copy]?:@{},@"no_player":@(!self.presentedViewController),@"navigation_profile":self.navigationState[@"profile"]?:@""};
}
- (void)exerciseKidsRating:(NSString *)identifier age:(NSInteger)age {
    self.exerciseKidsRatings.overrides[identifier]=@{@"minimumAge":@(age),@"label":age<0?@"Rating unavailable":@"Controlled diagnostic rating",@"checked":@(NSDate.date.timeIntervalSince1970),@"source":@"owned-device-fixture"};
}
- (BOOL)exerciseKidsSurfacesStep:(NSString *)kind {
    RewindStore *s=RewindStore.shared;NSString *run=self.exerciseRequest[@"run"];NSInteger build=[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue];
    if(![self.exerciseRequest[@"action"]isEqual:@"kids-surfaces"])return NO;
    if([kind isEqual:@"kids-surface-prepare"]){
        if(!s.catalogReady||self.exerciseKidsRatings||s.state[@"profiles"][@"rw-device-kids-0"]||s.state[@"profiles"][@"rw-device-kids-12"]||[s.state[@"profiles"]count]>4)return NO;
        RWKidsSurfaceRatings *ratings=[RWKidsSurfaceRatings new];ratings.original=s.ratings;ratings.overrides=[NSMutableDictionary new];ratings.run=run;ratings.build=build;self.exerciseKidsRatings=ratings;s.ratings=ratings;
        NSDateFormatter *date=[NSDateFormatter new];date.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"];date.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];date.dateFormat=@"yyyy-MM-dd'T'HH:mm:ss'Z'";
        NSString *future=[date stringFromDate:[NSDate dateWithTimeIntervalSinceNow:7*86400]];NSMutableArray *metas=[NSMutableArray new];
        for(NSString *group in @[@"up",@"wait"])for(NSNumber *age in @[@0,@10,@(-1)]){
            NSString *identifier=[NSString stringWithFormat:@"rw:kids-surface-%@-%@",group,age];[self exerciseKidsRating:identifier age:age.integerValue];
            [metas addObject:@{@"id":identifier,@"type":@"movie",@"name":[NSString stringWithFormat:@"%@ · %@",[group isEqual:@"up"]?@"Release check":@"Waiting check",age.integerValue<0?@"Unrated":age.integerValue?@"Older family":@"All ages"],@"genres":@[@"Family"],@"released":[group isEqual:@"up"]?future:@"2020-01-01T00:00:00Z",@"discovery":@{@"primaryLanguage":@"en",@"languageSource":@"owned-fixture",@"industry":@"hollywood"}}];
        }
        self.exerciseKidsMetas=metas;NSString *original=s.state[@"activeProfile"];double now=NSDate.date.timeIntervalSince1970;
        for(NSNumber *age in @[@0,@12]){NSMutableDictionary *p=[RWProfiles make:@"Device Kids check" age:age.integerValue];p[@"autoplayTrailers"]=@NO;p[@"sources"][@"rw:kids-owner"]=@{@"protocol":@1,@"build":@(build),@"original":original,@"run":run,@"age":age};
            for(NSDictionary *m in metas){NSString *identifier=RWID(m);p[@"availabilityWatch"][identifier]=@{@"meta":m,@"videoID":identifier,@"checked":@(now),@"initialState":@"unknown"};if([identifier containsString:@"-wait-"]){NSMutableDictionary *o=[[RWAvailability observe:@[] complete:YES error:nil quality:0 now:now]mutableCopy];o[@"meta"]=m;p[@"sourceAvailability"][identifier]=o;}}
            s.state[@"profiles"][[NSString stringWithFormat:@"rw-device-kids-%@",age]]=p;
        }[s save];return YES;
    }
    if(![RWDeviceExercise ownsKidsProfile:s.profile build:build run:run]||s.ratings!=self.exerciseKidsRatings)return NO;
    if([kind isEqual:@"kids-surface-upcoming"]){self.upcomingMode=@"Coming soon";return [self exercisePressNavigation:@"Upcoming"]&&[self.page isEqual:@"Upcoming"];}
    if([kind isEqual:@"kids-surface-arrive"]){[self exerciseKidsRating:@"rw:kids-surface-up--1" age:0];[[NSNotificationCenter defaultCenter]postNotificationName:@"RWRatingsUpdated" object:s.ratings];return YES;}
    if([kind isEqual:@"kids-surface-revoke"]){[self exerciseKidsRating:@"rw:kids-surface-up-10" age:16];[[NSNotificationCenter defaultCenter]postNotificationName:@"RWRatingsUpdated" object:s.ratings];return YES;}
    if([kind isEqual:@"kids-surface-waiting"])return [self exerciseAvailabilityStep:@"avail-waiting"];
    if([kind isEqual:@"kids-surface-following"])return [self exerciseAvailabilityStep:@"avail-following"];
    if([kind isEqual:@"kids-surface-open-followed"]){
        for(NSIndexPath *path in [self.upcomingList.indexPathsForVisibleRows sortedArrayUsingSelector:@selector(compare:)]){NSDictionary *m=[self.upcomingList metaAtPath:path];if([RWID(m)isEqual:@"rw:kids-surface-wait-0"]){self.exerciseDetailID=RWID(m);[self.upcomingList.delegate tableView:self.upcomingList didSelectRowAtIndexPath:path];return [self.page isEqual:@"Details"];}}
        return NO;
    }
    if([kind isEqual:@"kids-surface-back"])return [self exerciseContentBack]&&[self.page isEqual:@"Upcoming"];
    if([kind isEqual:@"kids-surface-film"]||[kind isEqual:@"kids-surface-series"]){
        NSString *type=[kind isEqual:@"kids-surface-film"]?@"movie":@"series";NSDictionary *target=nil;
        for(NSDictionary *m in s.familyCatalog)if([m[@"type"]isEqual:type]&&[s allowed:m]){if(!target)target=m;if([RWID(m)isEqual:@"tt0114709"]||[RWID(m)isEqual:@"tt0417299"]){target=m;break;}}
        if(!target)return NO;self.exerciseDetailID=RWID(target);[self showDetails:target];self.exerciseKidsDeadline=NSProcessInfo.processInfo.systemUptime+30;return [self.page isEqual:@"Details"];
    }
    if([kind isEqual:@"kids-surface-await-related"]){
        BOOL ready=self.relatedTitles.count>0&&[self exerciseRelatedRail]!=nil;
        if(!ready){if(NSProcessInfo.processInfo.systemUptime>self.exerciseKidsDeadline)return NO;self.exerciseIndex--;}return YES;
    }
    if([kind isEqual:@"kids-surface-related-tab"]){return [self exerciseDiscoveryButton:@"More like this"]&&[self.detailTab isEqual:@"More like this"];}
    if([kind isEqual:@"kids-surface-related-scroll"]){RWPosterCollection *rail=[self exerciseRelatedRail];if(!rail)return NO;[self.content setContentOffset:CGPointMake(0,MAX(0,MIN(rail.frame.origin.y-44,self.content.contentSize.height-self.content.bounds.size.height))) animated:NO];[self loadVisiblePosters];return YES;}
    if([kind isEqual:@"kids-surface-revoke-related"]){
        NSDictionary *m=self.relatedTitles.firstObject;if(!m)return NO;self.exerciseKidsRevoked=RWID(m);[self exerciseKidsRating:self.exerciseKidsRevoked age:18];NSUInteger generation=self.relatedGeneration;
        [[NSNotificationCenter defaultCenter]postNotificationName:@"RWRatingsUpdated" object:s.ratings];BOOL removed=YES;for(NSDictionary *item in self.relatedTitles)if([RWID(item)isEqual:self.exerciseKidsRevoked])removed=NO;
        self.exerciseKidsDeadline=NSProcessInfo.processInfo.systemUptime+20;return removed&&self.relatedGeneration>generation;
    }
    if([kind isEqual:@"kids-surface-open-related"]){
        RWPosterCollection *rail=[self exerciseRelatedRail];
        for(NSIndexPath *path in [rail.indexPathsForVisibleItems sortedArrayUsingSelector:@selector(compare:)]){
            if(path.item>=rail.items.count)continue;NSDictionary *m=rail.items[path.item];if(![s allowed:m])return NO;
            UICollectionViewCell *cell=[rail cellForItemAtIndexPath:path];if(!cell.window)continue;
            NSMutableArray *queue=[NSMutableArray arrayWithArray:cell.contentView.subviews];
            while(queue.count){UIView *view=queue.lastObject;[queue removeLastObject];
                if([view isKindOfClass:RWPoster.class]&&[RWID(((RWPoster *)view).meta)isEqual:RWID(m)]){
                    self.exerciseDetailID=RWID(m);[(RWPoster *)view sendActionsForControlEvents:UIControlEventTouchUpInside];
                    return [self.page isEqual:@"Details"]&&[RWID(self.detail)isEqual:self.exerciseDetailID];
                }[queue addObjectsFromArray:view.subviews];
            }
        }return NO;
    }
    if([kind isEqual:@"kids-surface-detail-revoke"]){[self exerciseKidsRating:RWID(self.detail) age:18];[[NSNotificationCenter defaultCenter]postNotificationName:@"RWRatingsUpdated" object:s.ratings];return [self.page isEqual:@"Home"]&&!self.presentedViewController;}
    if([kind hasPrefix:@"kids-surface-audit-"]){
        NSString *label=[kind substringFromIndex:[@"kids-surface-audit-" length]];NSDictionary *snap=[self exerciseKidsSurfacesSnapshot];NSInteger age=[s.profile[@"maxAge"]integerValue];BOOL ok=[snap[@"navigation_profile"]isEqual:s.state[@"activeProfile"]]&&!self.presentedViewController;
        NSArray *titles=[self.page isEqual:@"Upcoming"]?snap[@"upcoming"]:[self.page isEqual:@"Details"]?snap[@"related_audit"]:@[];for(NSDictionary *m in titles)if(![m[@"allowed"]boolValue]||[m[@"minimum_age"]integerValue]<0||[m[@"minimum_age"]integerValue]>age)ok=NO;
        if([self.page isEqual:@"Upcoming"]){NSUInteger count=[snap[@"fixture"]count];NSUInteger expected=[self.upcomingMode isEqual:@"Following"]?(age==0?3:4):[self.upcomingMode isEqual:@"Waiting"]?(age==0?1:2):[label isEqual:@"coming-initial"]?1:[label isEqual:@"coming-12"]?3:2;ok=ok&&count==expected;}
        if([label hasPrefix:@"switched"])ok=ok&&[self.page isEqual:@"Home"]&&!self.detail&&!self.relatedTitles.count&&!self.destinationStack.count;
        if([label isEqual:@"related-revoked"])for(NSDictionary *m in self.relatedTitles)if([RWID(m)isEqual:self.exerciseKidsRevoked])ok=NO;
        if([label isEqual:@"detail-blocked"])ok=ok&&[self.page isEqual:@"Home"];
        if([self.page isEqual:@"Details"])ok=ok&&[s allowed:self.detail]&&[RWID(self.detail)isEqual:self.exerciseDetailID];
        self.exerciseKidsReport=snap;NSString *name=[@"device-exercise-" stringByAppendingString:kind];RWCapture(self.view,name);return ok;
    }
    return NO;
}
- (void)finishKidsSurfacesExercise {
    if(!self.exerciseKidsRatings)return;
    RewindStore *s=RewindStore.shared;RWRatings *original=self.exerciseKidsRatings.original;if(s.ratings==self.exerciseKidsRatings)s.ratings=original;[s report:@{@"kids_surface_fixture":@{@"ratings_restored":@(s.ratings==original),@"run":self.exerciseRequest[@"run"]}}];
    [s cancelRelatedTitles];self.relatedGeneration++;self.relatedKey=nil;self.relatedTitles=@[];self.exerciseKidsRatings=nil;self.exerciseKidsRevoked=nil;
}
