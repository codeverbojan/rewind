// Bounded production-path checks. No followed show or notification preference
// is changed. A labelled notification probe runs only with existing iOS consent.
- (BOOL)exerciseReminderStep:(NSString *)kind {
    RewindStore *store=RewindStore.shared;
    if([kind isEqual:@"reminder-open"]){
        if(![self.upcomingMode isEqual:@"Following"])return NO;
        for(NSIndexPath *path in self.upcomingList.indexPathsForVisibleRows){NSDictionary *meta=[self.upcomingList metaAtPath:path];if(![meta[@"type"]isEqual:@"series"])continue;
            UIView *cell=[self.upcomingList cellForRowAtIndexPath:path];NSMutableArray *views=[NSMutableArray arrayWithObject:cell];
            while(views.count){UIView *v=views.lastObject;[views removeLastObject];if([v isKindOfClass:RWButton.class]&&[[(RWButton *)v currentTitle]isEqual:@"Manage reminders"]){[(RWButton *)v sendActionsForControlEvents:UIControlEventTouchUpInside];if([self.presentedViewController isKindOfClass:UIAlertController.class])self.exerciseReminderSheet=(UIAlertController *)self.presentedViewController;return self.exerciseReminderSheet!=nil;}[views addObjectsFromArray:v.subviews];}
        }return NO;
    }
    if([kind isEqual:@"reminder-audit-menu"]){NSArray *titles=[self.exerciseReminderSheet.actions valueForKey:@"title"]?:@[];self.exerciseReminderReport=@{@"menu_actions":titles,@"profile":store.state[@"activeProfile"]};NSString *name=@"device-exercise-reminder-menu";NSString *path=[[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"]stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]];[NSFileManager.defaultManager removeItemAtPath:path error:nil];[self.exerciseReminderSheet.view layoutIfNeeded];RWCapture(self.exerciseReminderSheet.view,name);return titles.count==3&&[titles containsObject:@"Cancel"]&&[[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil]fileSize]>0;}
    if([kind isEqual:@"reminder-dismiss"]){if(self.presentedViewController!=self.exerciseReminderSheet)return NO;[self dismissViewControllerAnimated:NO completion:nil];self.exerciseReminderSheet=nil;return YES;}
    if([kind isEqual:@"reminder-fetch"]){self.exerciseReminderReport=@{@"fetch_pending":@YES};__weak RewindController *weak=self;NSString *run=self.exerciseRequest[@"run"];
        [store checkEpisodesForDiagnostics:^{if(![run isEqual:weak.exerciseRequest[@"run"]])return;weak.exerciseReminderReport=@{@"fetch":store.episodeCheckDiagnostics,@"profile":store.state[@"activeProfile"],@"metadata_paused_after":@(RWMetadataBudget.shared.paused)};}];return YES;}
    if([kind isEqual:@"reminder-audit-fetch"]){NSDictionary *fetch=self.exerciseReminderReport[@"fetch"];return [fetch[@"finished"]boolValue]&&[fetch[@"background"]boolValue]&&[fetch[@"requests"]integerValue]>0&&[fetch[@"accepted"]integerValue]>0&&[fetch[@"requests"]integerValue]<=4&&[fetch[@"concurrency_limit"]integerValue]==1;}
    if([kind isEqual:@"reminder-notify"]){UIApplication *app=UIApplication.sharedApplication;NSUInteger types=app.currentUserNotificationSettings.types;BOOL granted=(types&UIUserNotificationTypeAlert)!=0;
        self.exerciseReminderReport=@{@"notification_types":@(types),@"background_refresh_status":@(app.backgroundRefreshStatus),@"profile_alerts":store.profile[@"episodeNotifications"]?:@NO,@"probe_requested":@(granted),@"run":self.exerciseRequest[@"run"]};[store report:@{@"notification_environment":self.exerciseReminderReport}];
        if(granted){UILocalNotification *n=[UILocalNotification new];n.alertBody=@"Rewind notification test.";n.userInfo=@{@"rewindReminderProbe":self.exerciseRequest[@"run"]};[app presentLocalNotificationNow:n];}return YES;
    }
    if([kind isEqual:@"reminder-audit-notify"])return self.exerciseReminderReport[@"notification_types"]!=nil;
    return NO;
}
