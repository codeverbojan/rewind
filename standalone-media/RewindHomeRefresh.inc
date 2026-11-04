// Retain only the current four-title visit across a temporary modal/background
// pause. Completed identities and their observations are never retried here.
- (void)clearHomeRefreshBatch {_homeRefreshBatch=nil;_homeRefreshFinished=nil;_homeRefreshBatchScope=nil;}
- (NSDictionary *)currentHomeRefreshBatchScope {return @{@"profile":self.state[@"activeProfile"]?:@"",@"quality":@(self.quality),@"type":_homeAvailabilityType?:@"all"};}
- (void)suspendHomeRefresh {if(_homeAvailabilityBusy&&_homeAvailabilityVisible)_homeRefreshRequested=YES;}
- (void)beginHomeRefreshTargets:(NSArray *)targets profile:(NSString *)profileID generation:(NSUInteger)generation {
    _homeRefreshBatch=[targets subarrayWithRange:NSMakeRange(0,MIN((NSUInteger)4,targets.count))];_homeRefreshFinished=[NSMutableSet new];_homeRefreshBatchScope=[self currentHomeRefreshBatchScope];_homeCompleted=0;
    [self refreshHomeTargets:_homeRefreshBatch index:0 profile:profileID generation:generation];
    if(_homeRefreshBatch.count>1)[self refreshHomeTargets:_homeRefreshBatch index:1 profile:profileID generation:generation];
}
- (BOOL)resumeHomeRefreshBatch {
    if(!_homeRefreshRequested||!_homeRefreshBatch.count)return NO;
    if(![_homeRefreshBatchScope isEqual:[self currentHomeRefreshBatchScope]]){[self clearHomeRefreshBatch];return NO;}
    NSMutableArray *remaining=[NSMutableArray new];for(NSDictionary *meta in _homeRefreshBatch)if(![_homeRefreshFinished containsObject:RWID(meta)]){
        [remaining addObject:meta];
        // An unfinished metadata lookup was cancelled, not a failed attempt.
        // Completed failures are excluded above and retain their retry cooldown.
        [_homeMetadataAttempts removeObjectForKey:RWID(meta)];
    }
    _homeRefreshRequested=NO;_homeAvailabilityBusy=YES;NSUInteger generation=++_homeGeneration;
    [self beginHomeRefreshTargets:remaining profile:self.state[@"activeProfile"] generation:generation];return YES;
}
- (NSDictionary *)homeAvailabilityDiagnostics {
    return @{@"media_type":_homeAvailabilityType?:@"all",@"profile":self.state[@"activeProfile"]?:@"",@"generation":@(_homeGeneration),@"active":@(_homeAvailabilityBusy),@"waiting_preparation":@(_homeRefreshRequested),@"last_pass":[_homeRefreshAudit.lastObject copy]?:@{}};
}
- (void)traceHomeRefresh:(NSArray *)targets completed:(NSUInteger)completed active:(BOOL)active {
    if(!_homeRefreshAudit)_homeRefreshAudit=[NSMutableArray new];NSMutableDictionary *entry=_homeRefreshAudit.lastObject;
    if(!entry||[entry[@"generation"]unsignedIntegerValue]!=_homeGeneration){
        if([entry[@"active"]boolValue]){entry[@"active"]=@NO;entry[@"superseded"]=@YES;}
        NSMutableDictionary *types=[NSMutableDictionary new];NSMutableArray *ids=[NSMutableArray new],*watchIDs=[NSMutableArray new],*recoveryIDs=[NSMutableArray new];for(NSDictionary *m in targets){[ids addObject:RWID(m)];types[RWID(m)]=m[@"type"]?:@"";if([self watchingAvailability:m])[watchIDs addObject:RWID(m)];if([m[@"homeRecoverableListing"]boolValue])[recoveryIDs addObject:RWID(m)];}
        entry=[@{@"generation":@(_homeGeneration),@"profile":self.state[@"activeProfile"],@"quality":@(self.quality),@"media_type":_homeAvailabilityType?:@"all",@"target_ids":ids,@"target_types":types,@"watch_ids":watchIDs,@"recovery_ids":recoveryIDs,@"targets":@(targets.count),@"started":@(NSDate.date.timeIntervalSince1970)}mutableCopy];[_homeRefreshAudit addObject:entry];if(_homeRefreshAudit.count>32)[_homeRefreshAudit removeObjectAtIndex:0];
    }
    entry[@"completed"]=@(completed);entry[@"active"]=@(active);
    [self report:@{@"home_refresh":[entry copy],@"home_refresh_history":[_homeRefreshAudit copy]}];
}
- (void)refreshHomeTargets:(NSArray *)targets index:(NSUInteger)index profile:(NSString *)profileID generation:(NSUInteger)generation {
    if(generation!=_homeGeneration)return;
    // Enforce the visit budget at execution as well as in target selection.
    // Older callers/test fixtures must not revive the former 24-title batch.
    if(targets.count>4)targets=[targets subarrayWithRange:NSMakeRange(0,4)];
    if(index==0)[self traceHomeRefresh:targets completed:0 active:YES];
    if(index>=targets.count&&_homeCompleted<targets.count)return;
    if(index>=targets.count||_discoveryPaused||![profileID isEqual:self.state[@"activeProfile"]]){
        _homeAvailabilityBusy=NO;
        if(index>=targets.count&&!_discoveryPaused&&[profileID isEqual:self.state[@"activeProfile"]]){
            if(targets.count){self.profile[@"homeDiscoveryRefresh"]=@{@"at":@(NSDate.date.timeIntervalSince1970),@"quality":@(self.quality)};[self saveForReason:NSStringFromSelector(_cmd)];}
            if(targets.count)[self refreshDiscovery];[self refreshDiscoveryCandidates];[self.discoveryMetadata enqueue:[self discoveryPool]];
            [self traceHomeRefresh:targets completed:self->_homeCompleted active:NO];[self clearHomeRefreshBatch];
        }return;
    }
    NSMutableDictionary *meta=[targets[index]mutableCopy];[meta removeObjectForKey:@"homeRecoverableListing"];void(^advance)(void)=^{
        if(generation!=self->_homeGeneration)return;
        [self->_homeRefreshFinished addObject:RWID(meta)];self->_homeCompleted++;if([RWHomeDelivery publishCompleted:self->_homeCompleted total:targets.count]){self->_homePublicationRequested=YES;[self refreshDiscovery];}
        [self traceHomeRefresh:targets completed:self->_homeCompleted active:YES];
        [self refreshHomeTargets:targets index:index+2 profile:profileID generation:generation];
    };
    if(![self allowed:meta]||[self.profile[@"hidden"]containsObject:RWID(meta)]){advance();return;}
    void(^load)(NSDictionary *)=^(NSDictionary *full){
        if(generation!=self->_homeGeneration)return;
        if(self->_discoveryPaused||![profileID isEqual:self.state[@"activeProfile"]]){self->_homeAvailabilityBusy=NO;return;}
        NSString *videoID=[self availabilityVideoID:full];
        if(![self allowed:full]||[self.profile[@"hidden"]containsObject:RWID(full)]){advance();return;}
        if(!videoID.length||[RWAvailability futureRelease:full now:NSDate.date.timeIntervalSince1970]){[self recordAvailabilityWatchCheck:full videoID:videoID];advance();return;}
        // A foreground lookup or another completed job may have updated this
        // exact episode after selection. Recheck live scope before networking.
        NSDictionary *live=[self availability:full videoID:videoID];
        if(![RWHomeDelivery needsRefresh:@{@"availability":live} now:NSDate.date.timeIntervalSince1970]){[self recordAvailabilityWatchCheck:full videoID:videoID];advance();return;}
        [self streams:full videoID:videoID foreground:NO done:^(id result,NSString *error){if(generation!=self->_homeGeneration)return;[self recordAvailabilityWatchCheck:full videoID:videoID];advance();}];
    };
    // Reuse the episode metadata that already established this exact target.
    NSDictionary *canonical=[self canonicalShow:RWID(meta)];
    if([meta[@"type"]isEqual:@"series"]&&(![canonical[@"videos"]count]||([canonical[@"episodeIndexHistorical"]boolValue]&&![self availabilityVideoID:meta].length))){
        double tried=[_homeMetadataAttempts[RWID(meta)]doubleValue],now=NSDate.date.timeIntervalSince1970;if(tried>0&&now>=tried&&now-tried<300){advance();return;}
        if(!_homeMetadataAttempts)_homeMetadataAttempts=[NSMutableDictionary new];_homeMetadataAttempts[RWID(meta)]=@(NSDate.date.timeIntervalSince1970);
        if(_homeMetadataAttempts.count>256){NSArray *old=[_homeMetadataAttempts keysSortedByValueUsingSelector:@selector(compare:)];[_homeMetadataAttempts removeObjectForKey:old.firstObject];}
        NSString *url=[NSString stringWithFormat:@"https://v3-cinemeta.strem.io/meta/series/%@.json",Esc(RWID(meta))];
        [self JSON:url foreground:NO done:^(id result,NSString *error){NSDictionary *full=[result[@"meta"]isKindOfClass:NSDictionary.class]?result[@"meta"]:nil;if(![RWID(full)isEqual:RWID(meta)]||![full[@"type"]isEqual:@"series"])full=nil;if(full&&generation==self->_homeGeneration)[self acceptShow:full profile:profileID notify:NO];load(full?:meta);}];
    }else load(meta);
}
