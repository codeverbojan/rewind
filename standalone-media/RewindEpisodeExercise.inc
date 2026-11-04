// Uses cached real episode metadata and normal UI/store paths. Only the owned
// temporary profile receives seeded positions; no episode video is downloaded.
- (NSDictionary *)exerciseEpisodeSnapshot {
    RewindStore *s=RewindStore.shared;NSMutableArray *labels=[NSMutableArray new],*rows=[NSMutableArray new],*views=[NSMutableArray arrayWithObject:self.content];
    while(views.count){UIView *v=views.lastObject;[views removeLastObject];if([v isKindOfClass:RWButton.class]&&[(RWButton *)v currentTitle].length)[labels addObject:[(RWButton *)v currentTitle]];[views addObjectsFromArray:v.subviews];}
    for(NSDictionary *row in self.homeView.displayedRows)if([@[@"continue",@"up-next"]containsObject:row[@"id"]]){NSMutableArray *cards=[NSMutableArray new];for(NSDictionary *meta in row[@"items"])[cards addObject:@{@"id":RWID(meta),@"video":meta[@"historyRecord"][@"videoID"]?:meta[@"episodeVideoID"]?:@"",@"position":meta[@"historyRecord"][@"position"]?:@0}];[rows addObject:@{@"id":row[@"id"],@"cards":cards}];}
    return @{@"profile":s.state[@"activeProfile"],@"page":self.page?:@"",@"show":RWID(self.exerciseEpisodeShow),@"next":[RWTVPolicy nextEpisode:self.exerciseEpisodeShow history:s.profile[@"history"] now:NSDate.date][@"id"]?:@"",@"season":@(self.season),@"saved_season":s.profile[@"selectedSeasons"][RWID(self.exerciseEpisodeShow)]?:@0,@"buttons":labels,@"list":self.episodeList.diagnostics?:@{},@"rows":rows,@"continuing":[s.continuingHistory valueForKey:@"videoID"]?:@[],@"up_next":[s.upNext valueForKey:@"episodeVideoID"]?:@[],@"targets":[self.exerciseEpisodeTargets valueForKey:@"id"]?:@[]};
}
- (BOOL)exerciseEpisodeStep:(NSString *)kind {
    RewindStore *s=RewindStore.shared;NSString *owned=@"rw-device-resume-check";NSDictionary *profile=s.state[@"profiles"][owned];
    if(!self.exerciseResumeOwned||![RWDeviceExercise ownsResumeProfile:profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]])return NO;
    if([kind isEqual:@"episode-other-profile"]){NSString *original=profile[@"sources"][@"rw:resume-owner"][@"original"];self.exerciseProfile=original;[self selectProfile:original];return ![s.state[@"activeProfile"]isEqual:owned];}
    if([kind isEqual:@"episode-return-profile"]){self.exerciseProfile=owned;[self selectProfile:owned];[s setDiscoveryPaused:YES];return YES;}
    if(![s.state[@"activeProfile"]isEqual:owned])return NO;
    if([kind isEqual:@"episode-prepare"]){
        NSDictionary *show=[s cachedShow:@"tt0369179"];NSArray *episodes=[RWTVPolicy episodes:show];NSMutableArray *first=[NSMutableArray new];NSDictionary *second=nil;
        for(NSDictionary *e in episodes)if([RWTVPolicy released:e now:NSDate.date]){if([e[@"season"]intValue]==1)[first addObject:e];else if([e[@"season"]intValue]==2&&!second)second=e;}
        if(first.count<2||!second)return NO;self.exerciseEpisodeShow=show;self.exerciseEpisodeTargets=@[first.firstObject,first.lastObject,second];
        for(NSUInteger i=0;i<2;i++){NSDictionary *e=self.exerciseEpisodeTargets[i];[s remember:[RWTVPolicy episodeMeta:e show:show] videoID:e[@"id"] source:@{} position:i?80:30 duration:600];}
        [self updateHomeList];return s.continuingHistory.count==1&&[s.continuingHistory.firstObject[@"videoID"]isEqual:first.lastObject[@"id"]]&&!s.upNext.count;
    }
    NSDictionary *last=self.exerciseEpisodeTargets[1],*next=self.exerciseEpisodeTargets[2];
    if([kind isEqual:@"episode-open"]){[self showDetails:self.exerciseEpisodeShow];return [self.page isEqual:@"Details"]&&[RWID(self.detail)isEqual:RWID(self.exerciseEpisodeShow)];}
    if([kind isEqual:@"episode-scroll-season"]){[self.content setContentOffset:CGPointMake(0,MAX(0,self.episodeList.frame.origin.y-80)) animated:NO];return self.season==2;}
    if([kind isEqual:@"episode-scroll-last"]){CGFloat y=self.episodeList.frame.origin.y+([last[@"episode"]integerValue]-1)*162;[self.content setContentOffset:CGPointMake(0,MIN(y,MAX(0,self.content.contentSize.height-self.content.bounds.size.height))) animated:NO];return self.season==1;}
    if([kind hasPrefix:@"episode-menu-"]){
        if([kind isEqual:@"episode-menu-season"]){NSMutableArray *views=[NSMutableArray arrayWithObject:self.content];while(views.count){UIView *v=views.lastObject;[views removeLastObject];if([v isKindOfClass:RWButton.class]&&[v.accessibilityLabel isEqual:@"Choose season"]){[(RWButton *)v sendActionsForControlEvents:UIControlEventTouchUpInside];break;}[views addObjectsFromArray:v.subviews];}}
        else {if(!self.episodeList.onOptions||self.season!=1)return NO;BOOL pressed=NO;NSString *prefix=[NSString stringWithFormat:@"Episode %@, ",last[@"episode"]];
            for(UIView *cell in self.episodeList.subviews){BOOL target=NO;RWButton *more=nil;for(UIView *view in cell.subviews)if([view isKindOfClass:RWButton.class]){target|=[view.accessibilityLabel hasPrefix:prefix];if([view.accessibilityLabel isEqual:@"Episode options"])more=(RWButton *)view;}if(target&&more&&!more.hidden){[more sendActionsForControlEvents:UIControlEventTouchUpInside];pressed=YES;break;}}
            if(!pressed)return NO;
        }
        if([self.presentedViewController isKindOfClass:UIAlertController.class])self.exerciseReminderSheet=(UIAlertController *)self.presentedViewController;
        return self.exerciseReminderSheet!=nil;
    }
    if([kind hasPrefix:@"episode-choice:"]){NSString *title=[kind substringFromIndex:15];void(^action)(void)=self.exerciseEpisodeActions[title];if(!action||self.presentedViewController!=self.exerciseReminderSheet)return NO;[self dismissViewControllerAnimated:NO completion:nil];self.exerciseReminderSheet=nil;action();return YES;}
    if([kind hasPrefix:@"episode-audit-"]){
        NSDictionary *state=[self exerciseEpisodeSnapshot];BOOL ok=YES;
        if([kind isEqual:@"episode-audit-resume"]){NSString *label=[NSString stringWithFormat:@"Resume S01 E%02ld",(long)[last[@"episode"]integerValue]];BOOL progress=NO;for(NSDictionary *cell in state[@"list"][@"visible_progress"])if([cell[@"id"]isEqual:last[@"id"]])progress=[cell[@"note"]hasPrefix:@"1:20 watched"]&&fabs([cell[@"progress"]doubleValue]-80.0/600)<.001;ok=[state[@"buttons"]containsObject:label]&&[state[@"next"]isEqual:last[@"id"]]&&progress;}
        else if([kind isEqual:@"episode-audit-next"]){ok=[state[@"buttons"]containsObject:@"Play S02 E01"]&&[state[@"next"]isEqual:next[@"id"]]&&!s.continuingHistory.count&&[s.upNext.firstObject[@"episodeVideoID"]isEqual:next[@"id"]];}
        else if([kind isEqual:@"episode-audit-season"]){ok=self.season==2&&[state[@"saved_season"]intValue]==2&&[state[@"list"][@"next_id"]isEqual:next[@"id"]]&&[state[@"list"][@"visible_progress"]count]>0;}
        else if([kind isEqual:@"episode-audit-unwatched"]){ok=[state[@"next"]isEqual:last[@"id"]]&&![[s record:last[@"id"]][@"completed"]boolValue]&&[[s record:last[@"id"]][@"position"]doubleValue]==0&&[s.upNext.firstObject[@"episodeVideoID"]isEqual:last[@"id"]];}
        else if([kind isEqual:@"episode-audit-home-resume"]||[kind isEqual:@"episode-audit-home-next"]){BOOL resume=[kind hasSuffix:@"resume"];NSString *rowID=resume?@"continue":@"up-next",*video=resume?last[@"id"]:next[@"id"];NSUInteger matches=0;for(NSDictionary *row in state[@"rows"])for(NSDictionary *card in row[@"cards"])if([card[@"id"]isEqual:RWID(self.exerciseEpisodeShow)]){matches++;if(![row[@"id"]isEqual:rowID]||![card[@"video"]isEqual:video])ok=NO;}ok=ok&&matches==1&&[self.page isEqual:@"Home"];}
        else return NO;
        self.exerciseEpisodeReport=state;RWCapture(self.view,[kind stringByReplacingOccurrencesOfString:@"episode-audit-" withString:@"device-exercise-episodes-"]);return ok;
    }
    return NO;
}
