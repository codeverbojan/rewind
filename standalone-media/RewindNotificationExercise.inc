// Bounded notification routing using the existing strictly owned temporary
// profile. The optional OS delivery probe persists only that profile until cleanup.
- (NSDictionary *)notificationExerciseSnapshot {
    RewindStore *s=RewindStore.shared;return @{@"page":self.page?:@"",@"profile":s.state[@"activeProfile"],@"detail":RWID(self.detail),@"episode":[self detailPlaybackEpisode:self.detail?:@{}][@"id"]?:@"",@"season":@(self.season),@"pending":@(self.pendingReminder!=nil),@"pending_owner":RWString(self.pendingReminder[@"rewindReminder"][@"profileID"]),@"modal":@(self.presentedViewController!=nil),@"receipt":self.notificationLastReceipt?:@{},@"opened":self.notificationOpenEvidence?:@{}};
}
- (BOOL)exerciseNotificationStep:(NSString *)kind {
    RewindStore *s=RewindStore.shared;NSString *owned=@"rw-device-resume-check";NSInteger build=[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue];
    NSDictionary *profile=s.state[@"profiles"][owned];if(![RWDeviceExercise ownsResumeProfile:profile build:build])return NO;
    if([kind isEqual:@"notification-probe-open"]){
        NSDictionary *payload=profile[@"sources"][@"rw:notification-owner"][@"payload"];
        NSDictionary *proof=self.notificationOpenEvidence;
        if(![proof[@"id"]isEqual:payload[@"rewindReminder"][@"notificationID"]]||![@[@"cold_launch",@"notification_callback"]containsObject:proof[@"origin"]?:@""]||![proof[@"opened"]boolValue])return NO;
        self.exerciseResumeOwned=YES;self.exerciseNotificationPayload=payload;self.exerciseProfile=owned;[self selectProfile:owned];self.exerciseReminderReport=[self notificationExerciseSnapshot];return YES;
    }
    if(!self.exerciseResumeOwned)return NO;
    if([kind isEqual:@"notification-prepare"]){
        if(!s.catalogReady){if(NSProcessInfo.processInfo.systemUptime-self.exerciseStarted>20)return NO;self.exerciseIndex--;return YES;}
        NSDictionary *show=[s cachedShow:@"tt0369179"];NSDictionary *ep=nil;for(NSDictionary *e in [RWTVPolicy episodes:show])if([e[@"season"]intValue]==2&&[e[@"episode"]intValue]==1){ep=e;break;}if(!ep)return NO;
        self.exerciseEpisodeShow=show;NSMutableDictionary *brief=[show mutableCopy];[brief removeObjectForKey:@"videos"];
        s.profile[@"following"][RWID(show)]=@{@"meta":brief,@"seen":@[],@"checked":@(NSDate.date.timeIntervalSince1970),@"started":@(NSDate.date.timeIntervalSince1970),@"baseline":@YES};
        s.profile[@"episodeUpdates"][RWID(show)]=@{@"episode":ep,@"detected":@(NSDate.date.timeIntervalSince1970)};s.profile[@"episodeNotifications"]=@YES;
        s.profile[@"availabilityWatch"][RWID(show)]=@{@"meta":brief,@"videoID":ep[@"id"],@"checked":@(NSDate.date.timeIntervalSince1970)};s.profile[@"availabilityUpdates"][RWID(show)]=brief;
        self.exerciseNotificationPayload=[RWReminderPolicy payload:@"episode" profile:owned title:RWID(show) video:ep[@"id"]];[s save];return self.exerciseNotificationPayload!=nil;
    }
    if([kind isEqual:@"notification-foreground"]){
        if(!(UIApplication.sharedApplication.currentUserNotificationSettings.types&UIUserNotificationTypeAlert))return NO;
        UILocalNotification *note=[UILocalNotification new];note.alertBody=@"Rewind notification test.";note.userInfo=self.exerciseNotificationPayload;[UIApplication.sharedApplication presentLocalNotificationNow:note];return YES;
    }
    if([kind isEqual:@"notification-open"]||[kind isEqual:@"notification-duplicate"]){[self receiveReminder:self.exerciseNotificationPayload userInitiated:YES origin:@"device_recipe"];return YES;}
    if([kind isEqual:@"notification-availability"]){NSDictionary *p=self.exerciseNotificationPayload[@"rewindReminder"];[self receiveReminder:[RWReminderPolicy payload:@"availability" profile:owned title:p[@"titleID"] video:p[@"videoID"]] userInitiated:YES origin:@"device_recipe"];return YES;}
    if([kind isEqual:@"notification-other-profile"]){
        NSString *original=profile[@"sources"][@"rw:resume-owner"][@"original"];self.exerciseProfile=original;[self selectProfile:original];
        NSDictionary *p=self.exerciseNotificationPayload[@"rewindReminder"];self.exerciseNotificationPayload=[RWReminderPolicy payload:@"episode" profile:owned title:p[@"titleID"] video:p[@"videoID"]];[self receiveReminder:self.exerciseNotificationPayload userInitiated:YES origin:@"device_recipe"];return YES;
    }
    if([kind isEqual:@"notification-owner"]){self.exerciseProfile=owned;[self selectProfile:owned];return YES;}
    if([kind isEqual:@"notification-modal"]){
        self.exerciseReminderSheet=[UIAlertController alertControllerWithTitle:@"Notification routing check" message:@"Temporary test sheet" preferredStyle:UIAlertControllerStyleAlert];[self presentViewController:self.exerciseReminderSheet animated:NO completion:nil];
        NSDictionary *p=self.exerciseNotificationPayload[@"rewindReminder"];[self receiveReminder:[RWReminderPolicy payload:@"episode" profile:owned title:p[@"titleID"] video:p[@"videoID"]] userInitiated:YES origin:@"device_recipe"];return YES;
    }
    if([kind isEqual:@"notification-hidden"]){NSDictionary *p=self.exerciseNotificationPayload[@"rewindReminder"];[s.profile[@"hidden"]addObject:p[@"titleID"]];[self receiveReminder:[RWReminderPolicy payload:@"episode" profile:owned title:p[@"titleID"] video:p[@"videoID"]] userInitiated:YES origin:@"device_recipe"];return YES;}
    if([kind isEqual:@"notification-reset"]){[s.profile[@"hidden"]removeObject:self.exerciseNotificationPayload[@"rewindReminder"][@"titleID"]];return YES;}
    if([kind isEqual:@"notification-legacy"]){[self receiveReminder:@{@"rewindEpisodeUpdate":@YES} userInitiated:YES origin:@"device_recipe"];return YES;}
    if([kind isEqual:@"notification-schedule"]){
        UIApplication *app=UIApplication.sharedApplication;if(!(app.currentUserNotificationSettings.types&UIUserNotificationTypeAlert))return NO;
        UILocalNotification *n=[UILocalNotification new];n.alertBody=@"Rewind notification test. Tap to open the episode.";n.soundName=UILocalNotificationDefaultSoundName;n.userInfo=self.exerciseNotificationPayload;n.fireDate=[NSDate dateWithTimeIntervalSinceNow:25];
        s.profile[@"sources"][@"rw:notification-owner"]=@{@"payload":n.userInfo,@"fire_at":@(n.fireDate.timeIntervalSince1970),@"scheduled_at":@(NSDate.date.timeIntervalSince1970)};[s save];[app scheduleLocalNotification:n];
        self.exerciseReminderReport=@{@"scheduled":@YES,@"fire_at":@(n.fireDate.timeIntervalSince1970),@"notification_id":n.userInfo[@"rewindReminder"][@"notificationID"],@"profile":owned};return YES;
    }
    if([kind hasPrefix:@"notification-audit-"]){
        NSDictionary *snap=[self notificationExerciseSnapshot];self.exerciseReminderReport=snap;NSString *label=[kind substringFromIndex:19];BOOL ok=NO;
        if([@[@"episode",@"availability",@"owner",@"after-modal",@"delivery"]containsObject:label])ok=[snap[@"page"]isEqual:@"Details"]&&[snap[@"profile"]isEqual:owned]&&[snap[@"detail"]isEqual:@"tt0369179"]&&[snap[@"episode"]isEqual:@"tt0369179:2:1"]&&[snap[@"season"]intValue]==2&&!self.pendingReminder;
        else if([label isEqual:@"foreground"])ok=[self.page isEqual:@"Home"]&&!self.pendingReminder&&[snap[@"receipt"][@"origin"]isEqual:@"notification_callback"]&&![snap[@"receipt"][@"opened"]boolValue];
        else if([@[@"noop",@"ignored"]containsObject:label])ok=[self.page isEqual:@"Home"]&&!self.pendingReminder;
        else if([label isEqual:@"profile"])ok=[self.page isEqual:@"Profiles"]&&![snap[@"profile"]isEqual:owned]&&[snap[@"pending_owner"]isEqual:owned];
        else if([label isEqual:@"deferred"])ok=[self.page isEqual:@"Home"]&&self.pendingReminder&&self.presentedViewController==self.exerciseReminderSheet;
        else if([label isEqual:@"legacy"])ok=[self.page isEqual:@"Upcoming"]&&[self.upcomingMode isEqual:@"Following"]&&!self.pendingReminder;
        if([@[@"episode",@"profile",@"availability",@"delivery",@"legacy"]containsObject:label])ok=[self exerciseCastCapture:[@"device-exercise-" stringByAppendingString:kind]]&&ok;
        return ok;
    }
    return NO;
}
- (void)finishNotificationExercise:(NSString *)status {
    if(![self.exerciseRequest[@"action"]hasPrefix:@"notification-"]&&![self.exerciseRequest[@"action"]isEqual:@"resume-cleanup"])return;
    self.pendingReminder=nil;self.notificationEpisodeID=nil;self.notificationTitleID=nil;self.exerciseNotificationPayload=nil;
    RewindStore *s=RewindStore.shared;NSDictionary *p=s.state[@"profiles"][@"rw-device-resume-check"];
    if([self.exerciseRequest[@"action"]isEqual:@"notification-schedule"]&&[status isEqual:@"complete"])return;
    if(![RWDeviceExercise ownsResumeProfile:p build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]])return;
    NSString *identifier=p[@"sources"][@"rw:notification-owner"][@"payload"][@"rewindReminder"][@"notificationID"];
    if(identifier.length)for(UILocalNotification *n in UIApplication.sharedApplication.scheduledLocalNotifications)if([n.userInfo[@"rewindReminder"][@"notificationID"]isEqual:identifier])[UIApplication.sharedApplication cancelLocalNotification:n];
}
