- (void)prepareUpcomingMode:(NSString *)mode done:(void(^)(NSArray *,NSString *))done {
    double captured=NSProcessInfo.processInfo.systemUptime;NSDictionary *snapshot=[self discoveryInputSnapshot],*ratings=[_discoveryRatings copy]?:@{};NSString *profile=[self.state[@"activeProfile"]copy];NSArray *catalog=[self.upcomingCatalog copy]?:@[];
    NSDictionary *following=[[NSDictionary alloc]initWithDictionary:self.profile[@"following"]?:@{} copyItems:YES],*watching=[[NSDictionary alloc]initWithDictionary:self.profile[@"availabilityWatch"]?:@{} copyItems:YES];double captureSeconds=NSProcessInfo.processInfo.systemUptime-captured;
    dispatch_async(_recommendationQueue,^{@autoreleasepool{double began=NSProcessInfo.processInfo.systemUptime;NSArray *items=[RWUpcomingSelection items:catalog mode:mode snapshot:snapshot ratings:ratings following:following watching:watching now:NSDate.date.timeIntervalSince1970];double seconds=NSProcessInfo.processInfo.systemUptime-began;
        dispatch_async(dispatch_get_main_queue(),^{BOOL current=[self discoveryJobMatches:snapshot profile:profile];[self report:@{@"upcoming_preparation":@{@"capture_main_seconds":@(captureSeconds),@"worker_seconds":@(seconds),@"items":@(items.count),@"mode":mode,@"off_main":@YES,@"current":@(current)}}];done(current?items:nil,current?nil:@"This profile has changed.");});
    }});
}
