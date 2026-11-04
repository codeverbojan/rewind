// One bounded preparation job on the store's existing serial worker. Missing
// membership is represented by noninteractive skeletons, never stale titles.
- (void)beginHomePreparationPass {
    RewindStore *s=[RewindStore shared];self.homeDeferredNeeded=NO;
    NSString *profile=s.state[@"activeProfile"];
    if(![self.homeDeferredProfile isEqual:profile]){self.homeDeferredBatch=nil;self.homeDeferredProfile=profile;}
    self.homeValidation=[s homeValidationWithFallback:self.homeDeferredBatch];
}
- (void)applyPreparedHome {
    if(![self.page isEqual:@"Home"]||!self.homeView||self.reviewMode||self.presentedViewController||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    if([self.homeView isInteracting]){[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(applyPreparedHome) object:nil];[self performSelector:@selector(applyPreparedHome) withObject:nil afterDelay:.15];return;}
    [self updateHomeList];
}
- (void)finishHomePreparationPass {
    // Ask only for the hero and visible cards plus their small horizontal
    // margin. Offscreen missing entries stay inert skeleton slots until needed.
    NSMutableSet *wanted=[[self.homeView preparationIDs]mutableCopy]?:[NSMutableSet new],*requested=[NSMutableSet new];
    NSDictionary *hero=self.homePlan[@"hero"]?:@{};NSString *heroID=RWID(hero);if(heroID.length)[wanted addObject:heroID];
    NSArray *rows=[@[@{@"items":@[hero]}]arrayByAddingObjectsFromArray:self.homePlan[@"rows"]?:@[]];
    if(!self.homeDeferredBusy&&!self.reviewMode&&[self.page isEqual:@"Home"]&&NSProcessInfo.processInfo.systemUptime>=self.discoveryMemoryCooldown)
        for(NSDictionary *row in rows)for(NSDictionary *title in row[@"items"]){NSString *key=RWID(title);if(requested.count<24&&[wanted containsObject:key]&&![self.homeValidation entryForTitle:title now:NSDate.date.timeIntervalSince1970])[requested addObject:key];}
    if(self.homeValidation&&!self.reviewMode)[[RewindStore shared]report:@{@"home_validation":self.homeValidation.diagnostics}];
    self.homeValidation=nil;
    if(!requested.count)return;
    self.homeDeferredBusy=YES;NSString *profile=[[RewindStore shared].state[@"activeProfile"]copy];__weak RewindController *weak=self;
    [[RewindStore shared]prepareHomeMetadata:self.homePlan requestedIDs:requested previous:self.homeDeferredBatch done:^(NSDictionary *result){
        RewindController *owner=weak;if(!owner)return;owner.homeDeferredBusy=NO;
        if(![profile isEqual:[RewindStore shared].state[@"activeProfile"]]){[owner applyPreparedHome];return;}
        if(NSProcessInfo.processInfo.systemUptime<owner.discoveryMemoryCooldown)return;
        owner.homeDeferredProfile=profile;owner.homeDeferredBatch=result;
        [[RewindStore shared]report:@{@"home_deferred_preparation":@{@"entries":@([result[@"entries"]count]),@"requested_entries":result[@"requested_entries"]?:@0,@"retained_entries":result[@"retained_entries"]?:@0,@"plan_entries":result[@"plan_entries"]?:@0,@"worker_seconds":result[@"enrichment_seconds"]?:@0,@"off_main":result[@"off_main"]?:@NO}}];
        [owner applyPreparedHome];
    }];
}
- (void)prepareHomeViewport {
    if(![self.page isEqual:@"Home"]||!self.homeView.window||self.homeDeferredBusy||self.reviewMode||self.presentedViewController||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive||NSProcessInfo.processInfo.systemUptime<self.discoveryMemoryCooldown)return;
    [self beginHomePreparationPass];[self finishHomePreparationPass];
}
- (void)scheduleHomeViewportPreparation {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(prepareHomeViewport) object:nil];
    [self performSelector:@selector(prepareHomeViewport) withObject:nil afterDelay:.12];
}
