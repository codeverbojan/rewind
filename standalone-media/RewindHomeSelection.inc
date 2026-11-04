- (void)refreshHomeAvailability {
    if(_discoveryPaused||_homeAvailabilityBusy||!_homeAvailabilityVisible)return;
    if([self resumeHomeRefreshBatch])return;
    if(!_discoveryPrepared.count){_homeRefreshRequested=YES;[self refreshDiscovery];return;}_homeRefreshRequested=NO;
    // The controller starts this once per destination visit. Per-title cooldowns
    // avoid retries while a new visit can advance to four different titles.
    double now=NSDate.date.timeIntervalSince1970;
    _homeAvailabilityBusy=YES;NSUInteger generation=++_homeGeneration;
    NSArray *input=_discoveryPrepared;NSString *mediaType=[_homeAvailabilityType copy];NSDictionary *profile=_discoveryContext?:@{};NSString *profileID=[self.state[@"activeProfile"]copy];NSInteger quality=self.quality;
    // Record membership/scalars are copied on main; workers never read live state.
    NSDictionary *observations=[[NSDictionary alloc]initWithDictionary:self.profile[@"sourceAvailability"]?:@{} copyItems:YES];
    NSDictionary *history=[[NSDictionary alloc]initWithDictionary:self.profile[@"history"]?:@{} copyItems:YES],*shows=[self discoveryShows]?:@{},*attempts=[_homeMetadataAttempts copy]?:@{};
    NSArray *watches=[self availabilityWatchTargets];
    dispatch_async(_recommendationQueue,^{@autoreleasepool{
        NSArray *scoped=input;if(mediaType.length){NSMutableArray *typed=[NSMutableArray new];for(NSDictionary *m in input)if([m[@"type"]isEqual:mediaType])[typed addObject:m];scoped=typed;}
        NSArray *eligible=[RWRecommendationPolicy homeRefreshCandidates:scoped profile:profile now:now];
        NSArray *prepared=[RWHomeDelivery refreshable:eligible observations:observations shows:shows history:history metadataAttempts:attempts quality:quality now:now];
        NSArray *ranked=[RWRecommendationPolicy rank:prepared current:nil profile:profile world:NO requireAvailability:NO now:now limit:40];
        NSArray *world=[RWRecommendationPolicy rank:prepared current:nil profile:profile world:YES requireAvailability:NO now:now limit:8];
        NSMutableArray *olderPool=[NSMutableArray new],*seriesPool=[NSMutableArray new],*recoveryPool=[NSMutableArray new];NSInteger year=[[NSCalendar currentCalendar]component:NSCalendarUnitYear fromDate:NSDate.date];
        for(NSDictionary *m in prepared){if([m[@"homeRecoverableListing"]boolValue])[recoveryPool addObject:m];NSInteger released=[RWString(m[@"releaseInfo"])integerValue];if(released>1900&&released<=year-10)[olderPool addObject:m];if([m[@"type"]isEqual:@"series"])[seriesPool addObject:m];}
        NSArray *older=[RWRecommendationPolicy rank:olderPool current:nil profile:profile world:NO requireAvailability:NO now:now limit:12],*shows=[RWRecommendationPolicy rank:seriesPool current:nil profile:profile world:NO requireAvailability:NO now:now limit:12];
        // A previously displayed title has low novelty and can fall outside
        // the ordinary top-40 pool. Rank recovery separately before the shared
        // selector reserves two slots when new discovery is available and fills
        // spare slots if only recovery remains; all normal policy gates apply.
        NSArray *recover=[RWRecommendationPolicy rank:recoveryPool current:nil profile:profile world:NO requireAvailability:NO now:now limit:4];
        NSArray *recoverWorld=[RWRecommendationPolicy rank:recoveryPool current:nil profile:profile world:YES requireAvailability:NO now:now limit:4];
        ranked=[recover arrayByAddingObjectsFromArray:ranked];world=[recoverWorld arrayByAddingObjectsFromArray:world];
        NSArray *discoveryTargets=[RWHomeDelivery targets:ranked world:world older:older shows:shows now:now limit:4];
        NSArray *targets=[RWHomeDelivery targets:discoveryTargets includingWatches:watches];
        dispatch_async(dispatch_get_main_queue(),^{
            if(generation!=self->_homeGeneration)return;
            if(self->_discoveryPaused||quality!=self.quality||![profileID isEqual:self.state[@"activeProfile"]]){self->_homeAvailabilityBusy=NO;return;}
            [self report:@{@"home_refresh":@{@"targets":@(targets.count),@"completed":@0,@"active":@YES}}];
            [self beginHomeRefreshTargets:targets profile:profileID generation:generation];
        });
    }});
}
