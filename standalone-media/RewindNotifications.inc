// Notification destinations are resolved from the current owning profile, never
// from display text or a URL in the notification. No automatic media playback.
- (void)receiveReminder:(NSDictionary *)info userInitiated:(BOOL)opened origin:(NSString *)origin {
    RewindStore *store=RewindStore.shared;NSDictionary *payload=[info[@"rewindReminder"]isKindOfClass:NSDictionary.class]?info[@"rewindReminder"]:nil;
    NSString *token=RWString(payload[@"notificationID"]);
    NSDictionary *evidence=@{@"id":token,@"origin":origin?:@"",@"opened":@(opened),@"application_state":@(UIApplication.sharedApplication.applicationState),@"received_at":@(NSDate.date.timeIntervalSince1970)};
    self.notificationLastReceipt=evidence;[store report:@{@"notification_received":evidence}];
    if(opened&&[@[@"cold_launch",@"notification_callback"]containsObject:origin]){self.notificationOpenEvidence=evidence;[store report:@{@"notification_open":evidence}];}
    if(!opened)return;
    if(!payload){
        // Legacy generic notifications can only open the active profile's
        // filtered reminder list. They cannot identify another user's title.
        if(![info[@"rewindEpisodeUpdate"]boolValue]&&![info[@"rewindAvailabilityUpdate"]boolValue])return;
        token=[info[@"rewindEpisodeUpdate"]boolValue]?@"legacy-episode":@"legacy-availability";
    }
    if([token isEqual:self.lastReminderID]&&NSProcessInfo.processInfo.systemUptime-self.lastReminderAt<180)return;
    self.lastReminderID=token;self.lastReminderAt=NSProcessInfo.processInfo.systemUptime;self.pendingReminder=[info copy];self.reminderDeadline=self.lastReminderAt+180;
    [self processPendingReminder];
}
- (void)deferPendingReminder {
    if(self.reminderProcessScheduled)return;self.reminderProcessScheduled=YES;__weak RewindController *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/2),dispatch_get_main_queue(),^{weak.reminderProcessScheduled=NO;[weak processPendingReminder];});
}
- (void)processPendingReminder {
    if(!self.pendingReminder)return;RewindStore *s=RewindStore.shared;
    if(NSProcessInfo.processInfo.systemUptime>self.reminderDeadline){self.pendingReminder=nil;[s report:@{@"notification_route":@{@"status":@"expired"}}];return;}
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    if(!s.catalogReady||self.presentedViewController){[self deferPendingReminder];return;}
    NSDictionary *payload=self.pendingReminder[@"rewindReminder"];
    if(![payload isKindOfClass:NSDictionary.class]){
        if([self.page isEqual:@"Profiles"])return;
        self.upcomingMode=[self.pendingReminder[@"rewindEpisodeUpdate"]boolValue]?@"Following":@"Waiting";self.pendingReminder=nil;[self go:@"Upcoming"];[s report:@{@"notification_route":@{@"status":@"legacy_list"}}];return;
    }
    NSString *title=RWString(payload[@"titleID"]);NSDictionary *target=[RWReminderPolicy destination:self.pendingReminder state:s.state show:[s cachedShow:title] rating:[s.ratings rating:title] now:NSDate.date];
    if(!target){self.pendingReminder=nil;[s report:@{@"notification_route":@{@"status":@"stale_or_ineligible",@"id":self.lastReminderID?:@""}}];return;}
    if(![target[@"profileID"]isEqual:s.state[@"activeProfile"]]){
        if(![self.page isEqual:@"Profiles"]){[self.destinationStack removeAllObjects];[self go:@"Profiles"];}
        [s report:@{@"notification_route":@{@"status":@"choose_profile",@"id":self.lastReminderID?:@""}}];return;
    }
    if([self.page isEqual:@"Profiles"])return; // Cold launches retain Who's watching.
    self.pendingReminder=nil;NSDictionary *episode=target[@"episode"];
    self.notificationEpisodeID=[target[@"meta"][@"type"]isEqual:@"series"]?RWString(target[@"videoID"]):@"";self.notificationTitleID=title;self.notificationSeasonPending=self.notificationEpisodeID.length&&!episode[@"season"];
    if(episode[@"season"]){s.profile[@"selectedSeasons"][title]=episode[@"season"];[s save];}
    [self showDetails:target[@"meta"]];
    [s report:@{@"notification_route":@{@"status":@"details",@"id":self.lastReminderID?:@"",@"profile":target[@"profileID"],@"title":title,@"video":self.notificationEpisodeID?:@"",@"season":@(self.season)}}];
}
- (NSDictionary *)detailPlaybackEpisode:(NSDictionary *)show {
    RewindStore *s=RewindStore.shared;
    if([RWID(show)isEqual:self.notificationTitleID]&&self.notificationEpisodeID.length){
        if(![RWTVPolicy episodes:show].count)return nil;
        for(NSDictionary *ep in [RWTVPolicy episodes:show])if([ep[@"id"]isEqual:self.notificationEpisodeID]&&[RWTVPolicy released:ep now:NSDate.date]&&![[s record:ep[@"id"]][@"completed"]boolValue]){
            if(self.notificationSeasonPending){self.notificationSeasonPending=NO;self.season=[ep[@"season"]integerValue];s.profile[@"selectedSeasons"][RWID(show)]=ep[@"season"];[s save];}return ep;
        }
        if(![[s record:self.notificationEpisodeID][@"completed"]boolValue])return nil;
    }
    return [RWTVPolicy nextEpisode:show history:s.profile[@"history"] now:NSDate.date];
}
