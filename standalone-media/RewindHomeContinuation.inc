// Category membership is rechecked with age/source eligibility on every cache window.
- (BOOL)homeRailRecordAllowed:(NSDictionary *)meta row:(NSDictionary *)row {
    NSMutableDictionary *live=[[RWHomeDelivery titleMetadata:meta]mutableCopy];NSDictionary *metadata=[self.discoveryMetadata record:RWID(meta)];if(metadata.count)live[@"discovery"]=metadata;
    if([row[@"recipe"]isEqual:@"category"]&&![RWHomeCategoryPolicy matches:live category:row])return NO;
    if(![self allowed:live]||[self.profile[@"hidden"]containsObject:RWID(live)])return NO;
    live[@"availability"]=[self availability:live videoID:[self availabilityVideoID:live]];
    return [RWHomePreparation allows:live preferences:[RWDiscoveryMetadataPolicy preferences:self.profile[@"discoveryPreferences"]] restricted:self.restricted world:[row[@"recipe"]isEqual:@"world"] hero:[row[@"recipe"]isEqual:@"hero"] priors:self.discoveryHome[@"ratingPriors"]];
}
// Initial shelf membership is independent of viewport/image preparation. Take
// one bounded metadata snapshot and use the existing serial worker; no requests.
- (void)prepareHomeFeedRows:(NSArray *)rows done:(void(^)(NSArray *,NSString *))done {
    if(rows.count>14){done(nil,@"Home has too many opening rows.");return;}
    NSMutableArray *input=[NSMutableArray new],*titles=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(NSDictionary *row in rows){NSMutableDictionary *copy=[NSMutableDictionary new];
        for(NSString *key in @[@"id",@"title",@"mediaType",@"recipe",@"anchor",@"mood",@"anyGenres",@"allGenres",@"maxMinutes",@"providerGenre"])if(row[key])copy[key]=row[key];
        NSMutableArray *items=[NSMutableArray new];for(NSDictionary *m in row[@"items"]){if(items.count==12)break;NSDictionary *title=[RWHomeDelivery titleMetadata:m];if(!RWID(title).length)continue;[items addObject:title];if(![seen containsObject:RWID(title)]){[seen addObject:RWID(title)];[titles addObject:title];}}copy[@"items"]=items;[input addObject:copy];
    }
    NSDictionary *snapshot=[self discoveryInputSnapshot],*ratings=[_discoveryRatings copy]?:@{};NSString *profile=[self.state[@"activeProfile"]copy];NSArray *priors=[self.discoveryHome[@"ratingPriors"]copy];
    dispatch_async(_recommendationQueue,^{@autoreleasepool{
        NSDictionary *prepared=[RWDiscoverySnapshot prepareItems:titles snapshot:snapshot ratings:ratings now:NSDate.date.timeIntervalSince1970];NSMutableDictionary *byID=[NSMutableDictionary new];for(NSDictionary *m in prepared[@"items"])byID[RWID(m)]=m;
        NSMutableArray *out=[NSMutableArray new];NSSet *excluded=[RWRecommendationPolicy homeExcludedIDsForProfile:snapshot[@"profile"]];BOOL kids=[snapshot[@"profile"][@"maxAge"]integerValue]>=0;NSDictionary *prefs=[RWDiscoveryMetadataPolicy preferences:snapshot[@"profile"][@"discoveryPreferences"]];
        for(NSDictionary *row in input){NSMutableDictionary *copy=[row mutableCopy];NSMutableArray *items=[NSMutableArray new];BOOL world=[row[@"recipe"]isEqual:@"world"];
            for(NSDictionary *title in row[@"items"]){NSDictionary *m=byID[RWID(title)];if(!m||(kids&&![m[@"ageAllowed"]boolValue])||[excluded containsObject:RWID(m)]||([row[@"recipe"]isEqual:@"category"]&&![RWHomeCategoryPolicy matches:m category:row])||![RWHomePreparation allows:m preferences:prefs restricted:kids world:world hero:[row[@"recipe"]isEqual:@"hero"] priors:priors])continue;
                NSMutableDictionary *card=[m mutableCopy];[card removeObjectForKey:@"episodeVideoID"];if(world)card[@"showLanguage"]=@YES;[items addObject:card];
            }copy[@"items"]=items;[out addObject:copy];
        }
        dispatch_async(dispatch_get_main_queue(),^{BOOL current=[self discoveryJobMatches:snapshot profile:profile];done(current?out:nil,current?nil:@"This profile has changed.");});
    }});
}
// Persistent Home feeds use current snapshots, never persisted readiness bits.
- (void)prepareHomeRail:(NSArray *)items row:(NSDictionary *)row done:(void(^)(NSArray *,NSString *))done {
    [self prepareHomeRail:items row:row retry:0 done:done];
}
- (void)prepareHomeRail:(NSArray *)items row:(NSDictionary *)row retry:(NSUInteger)retry done:(void(^)(NSArray *,NSString *))done {
    NSDictionary *snapshot=[self discoveryInputSnapshot],*ratings=[_discoveryRatings copy]?:@{};NSString *profile=[self.state[@"activeProfile"]copy];NSArray *input=[items copy],*priors=[self.discoveryHome[@"ratingPriors"]copy];
    dispatch_async(_recommendationQueue,^{@autoreleasepool{
        NSMutableArray *titles=[NSMutableArray new];for(NSDictionary *m in input)[titles addObject:[RWHomeDelivery titleMetadata:m]];NSDictionary *prepared=[RWDiscoverySnapshot prepareItems:titles snapshot:snapshot ratings:ratings now:NSDate.date.timeIntervalSince1970];NSMutableArray *out=[NSMutableArray new];BOOL world=[row[@"recipe"]isEqual:@"world"];NSSet *excluded=[RWRecommendationPolicy homeExcludedIDsForProfile:snapshot[@"profile"]];
        for(NSDictionary *m in prepared[@"items"])if((![row[@"recipe"]isEqual:@"category"]||[RWHomeCategoryPolicy matches:m category:row])&&([snapshot[@"profile"][@"maxAge"]integerValue]<0||[m[@"ageAllowed"]boolValue])&&![excluded containsObject:RWID(m)]&&[RWHomePreparation allows:m preferences:[RWDiscoveryMetadataPolicy preferences:snapshot[@"profile"][@"discoveryPreferences"]] restricted:[snapshot[@"profile"][@"maxAge"]integerValue]>=0 world:world hero:[row[@"recipe"]isEqual:@"hero"] priors:priors]){NSMutableDictionary *card=[m mutableCopy];[card removeObjectForKey:@"episodeVideoID"];if(world)card[@"showLanguage"]=@YES;[out addObject:card];}
        dispatch_async(dispatch_get_main_queue(),^{
            if(![self discoveryJobMatches:snapshot profile:profile]){done(nil,@"This profile has changed.");return;}
            NSSet *accepted=[NSSet setWithArray:[out valueForKey:@"id"]],*excluded=[RWRecommendationPolicy homeExcludedIDsForProfile:self.profile];BOOL raced=NO,traced=NO;
            for(NSDictionary *m in input){NSString *key=RWID(m);if([accepted containsObject:key])continue;
                NSDictionary *oldShow=snapshot[@"shows"][key],*show=[self canonicalShow:key],*oldMetadata=snapshot[@"metadata"][key],*metadata=[self.discoveryMetadata record:key];NSString *video=[self availabilityVideoID:m];NSDictionary *oldObservation=snapshot[@"profile"][@"sourceAvailability"][video],*observation=self.profile[@"sourceAvailability"][video];
                BOOL changed=oldShow!=show||(oldMetadata!=metadata&&![oldMetadata isEqual:metadata])||(oldObservation!=observation&&![oldObservation isEqual:observation]);
                BOOL liveAllowed=[self homeRailRecordAllowed:m row:row]&&![excluded containsObject:key];raced|=changed&&liveAllowed;
                NSDictionary *decision=nil;for(NSDictionary *v in prepared[@"items"])if([RWID(v)isEqual:key]){decision=v;break;}
                traced=YES;if(!self->_homeRailRejections)self->_homeRailRejections=[NSMutableArray new];
                [self->_homeRailRejections addObject:@{@"id":key,@"row":row[@"id"]?:@"",@"profile":profile,@"at":@(NSDate.date.timeIntervalSince1970),@"retry":@(retry),@"snapshot_admitted_age":@(decision!=nil),@"snapshot_video":decision[@"episodeVideoID"]?:@"",@"snapshot_state":decision[@"availability"][@"state"]?:@"age_or_audience",@"snapshot_episode_count":@([oldShow[@"videos"]count]),@"current_video":video?:@"",@"current_state":[self availability:m videoID:video][@"state"]?:@"unknown",@"current_episode_count":@([show[@"videos"]count]),@"current_allowed":@(liveAllowed),@"inputs_changed":@(changed)}];
                while(self->_homeRailRejections.count>32)[self->_homeRailRejections removeObjectAtIndex:0];
            }
            if(traced)[self report:@{@"home_rail_rejections":[self->_homeRailRejections copy]}];
            // A rejected stale snapshot must not delete a currently eligible
            // title. Re-evaluate once; repeated churn returns an error, leaving
            // membership intact. Cached reads still enforce today's live gate.
            if(raced){if(!retry)[self prepareHomeRail:items row:row retry:1 done:done];else done(nil,@"Home is updating. Try again.");return;}
            done(out,nil);
        });
    }});
}
- (void)rankHomeRail:(NSArray *)items row:(NSDictionary *)row excluding:(NSSet *)excluded available:(BOOL)available done:(void(^)(NSArray *))done {
    double began=NSProcessInfo.processInfo.systemUptime;NSDictionary *snapshot=[self discoveryInputSnapshot],*ratings=[_discoveryRatings copy]?:@{},*attempts=[_homeMetadataAttempts copy]?:@{};NSString *profile=[self.state[@"activeProfile"]copy];NSArray *input=[items copy];
    dispatch_async(_recommendationQueue,^{@autoreleasepool{double workerBegan=NSProcessInfo.processInfo.systemUptime,now=NSDate.date.timeIntervalSince1970;NSMutableArray *titles=[NSMutableArray new];for(NSDictionary *m in input)[titles addObject:[RWHomeDelivery titleMetadata:m]];
        NSDictionary *prepared=[RWDiscoverySnapshot prepare:titles snapshot:snapshot ratings:ratings now:now];NSArray *pool=prepared[@"items"];
        if(!available)pool=[RWHomeDelivery refreshable:[RWRecommendationPolicy homeRefreshCandidates:pool profile:prepared[@"profile"] now:now] observations:snapshot[@"profile"][@"sourceAvailability"] shows:snapshot[@"shows"] history:snapshot[@"profile"][@"history"] metadataAttempts:attempts quality:[snapshot[@"quality"]integerValue] now:now];
        NSArray *ranked=[RWHomeRailPolicy rank:pool row:row profile:prepared[@"profile"] excluding:excluded available:available now:now];double finished=NSProcessInfo.processInfo.systemUptime;dispatch_async(dispatch_get_main_queue(),^{[self traceHomeRailStage:@"rank" detail:@{@"row":row[@"id"]?:@"",@"available":@(available),@"input":@(input.count),@"output":@(ranked.count),@"queue_seconds":@(workerBegan-began),@"worker_seconds":@(finished-workerBegan),@"episodes":prepared[@"episode_cache"]?:@{}}];done([self discoveryJobMatches:snapshot profile:profile]?ranked:@[]);});}});
}
- (void)traceHomeRailStage:(NSString *)stage detail:(NSDictionary *)detail {
    if(!_homeRailEvents)_homeRailEvents=[NSMutableArray new];NSMutableDictionary *entry=[detail mutableCopy]?:[NSMutableDictionary new];entry[@"stage"]=stage;entry[@"uptime"]=@(NSProcessInfo.processInfo.systemUptime);entry[@"profile"]=self.state[@"activeProfile"]?:@"";
    [_homeRailEvents addObject:entry];while(_homeRailEvents.count>64)[_homeRailEvents removeObjectAtIndex:0];[self report:@{@"home_rail_stages":[_homeRailEvents copy]}];
}
- (void)verifyHomeRail:(NSArray *)targets index:(NSUInteger)index current:(BOOL(^)(void))current done:(void(^)(void))done {
    NSUInteger limit=MIN(targets.count,(NSUInteger)4);if(!current()||index>=limit){done();return;}
    __block NSUInteger remaining=MIN((NSUInteger)2,limit-index);void(^laneDone)(void)=^{if(remaining&&!--remaining)done();};
    [self verifyHomeRailLane:targets index:index current:current done:laneDone];
    if(limit-index>1)[self verifyHomeRailLane:targets index:index+1 current:current done:laneDone];
}
- (void)verifyHomeRailLane:(NSArray *)targets index:(NSUInteger)index current:(BOOL(^)(void))current done:(void(^)(void))done {
    if(!current()||index>=MIN(targets.count,(NSUInteger)4)){done();return;}
    // The automatic visit check and explicit rail continuation share the lane.
    if(_homeAvailabilityBusy){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/5),dispatch_get_main_queue(),^{[self verifyHomeRailLane:targets index:index current:current done:done];});return;}
    NSDictionary *meta=targets[index];[self traceHomeRailStage:@"target" detail:@{@"id":RWID(meta),@"index":@(index)}];void(^advance)(void)=^{[self traceHomeRailStage:@"target_done" detail:@{@"id":RWID(meta),@"index":@(index)}];[self verifyHomeRailLane:targets index:index+2 current:current done:done];};
    if(![self allowed:meta]||[self.profile[@"hidden"]containsObject:RWID(meta)]){advance();return;}
    void(^load)(NSDictionary *)=^(NSDictionary *full){if(!current()){done();return;}NSString *video=[self availabilityVideoID:full];if(!video.length||![self allowed:full]||[RWAvailability futureRelease:full now:NSDate.date.timeIntervalSince1970]){advance();return;}
        if(![RWHomeDelivery needsRefresh:@{@"availability":[self availability:full videoID:video]} now:NSDate.date.timeIntervalSince1970]){advance();return;}
        [self traceHomeRailStage:@"source" detail:@{@"id":RWID(full),@"video":video}];[self streams:full videoID:video foreground:NO done:^(id result,NSString *error){[self traceHomeRailStage:@"source_done" detail:@{@"id":RWID(full),@"failed":@(error!=nil)}];advance();}];
    };
    NSDictionary *canonical=[self canonicalShow:RWID(meta)];
    if([meta[@"type"]isEqual:@"series"]&&(![canonical[@"videos"]count]||([canonical[@"episodeIndexHistorical"]boolValue]&&![self availabilityVideoID:meta].length))){
        // The automatic visit and deliberate row continuation share the same
        // metadata cooldown, so failed indexes cannot monopolize every batch.
        double tried=[_homeMetadataAttempts[RWID(meta)]doubleValue],now=NSDate.date.timeIntervalSince1970;
        if(tried>0&&now>=tried&&now-tried<300){advance();return;}
        if(!_homeMetadataAttempts)_homeMetadataAttempts=[NSMutableDictionary new];_homeMetadataAttempts[RWID(meta)]=@(now);
        if(_homeMetadataAttempts.count>256){NSArray *old=[_homeMetadataAttempts keysSortedByValueUsingSelector:@selector(compare:)];[_homeMetadataAttempts removeObjectForKey:old.firstObject];}
        NSString *profile=[self.state[@"activeProfile"]copy];NSString *url=[NSString stringWithFormat:@"https://v3-cinemeta.strem.io/meta/series/%@.json",Esc(RWID(meta))];
        [self traceHomeRailStage:@"episode_metadata" detail:@{@"id":RWID(meta)}];[self JSON:url foreground:NO done:^(id result,NSString *error){NSDictionary *full=[result[@"meta"]isKindOfClass:NSDictionary.class]?result[@"meta"]:nil;if(!current()){done();return;}if(![RWID(full)isEqual:RWID(meta)]||![full[@"type"]isEqual:@"series"]){advance();return;}[self acceptShow:full profile:profile notify:NO];load(full);}];
    }else load(meta);
}
- (void)settleHomeRatingsUntil:(double)deadline items:(NSArray *)items current:(BOOL(^)(void))current done:(void(^)(void))done {
    if(!current()||!self.restricted||![self.ratings isResolvingItems:items]||NSProcessInfo.processInfo.systemUptime>=deadline){done();return;}
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/5),dispatch_get_main_queue(),^{[self settleHomeRatingsUntil:deadline items:items current:current done:done];});
}
- (void)settleHomeEvidenceUntil:(double)deadline ratings:(NSArray *)ratings metadata:(NSArray *)metadata current:(BOOL(^)(void))current done:(void(^)(void))done {
    BOOL pending=(self.restricted&&[self.ratings isResolvingItems:ratings])||[self.discoveryMetadata isResolvingItems:metadata];
    if(!current()||!pending||NSProcessInfo.processInfo.systemUptime>=deadline){done();return;}
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/5),dispatch_get_main_queue(),^{[self settleHomeEvidenceUntil:deadline ratings:ratings metadata:metadata current:current done:done];});
}
- (void)recheckHomeRail:(NSDictionary *)row excluding:(NSSet *)excluded current:(BOOL(^)(void))current done:(void(^)(NSArray *,NSString *))done {
    // Late metadata may make an acquired title eligible. This path only ranks
    // existing evidence: no rating lookup, provider page or availability probe.
    if(!current()){done(@[],@"Loading paused. Try again.");return;}
    [self rankHomeRail:[self discoveryPool] row:row excluding:excluded available:YES done:^(NSArray *ready){
        if(!current()){done(@[],@"Loading paused. Try again.");return;}done(ready,nil);
    }];
}
- (void)homeRailPage:(NSDictionary *)row cursor:(NSDictionary *)cursor excluding:(NSSet *)excluded current:(BOOL(^)(void))current done:(void(^)(NSArray *,NSDictionary *,BOOL,NSString *))done {
    [self homeRailPage:row cursor:cursor excluding:excluded current:current checkpoint:nil done:done];
}
- (void)homeRailPage:(NSDictionary *)row cursor:(NSDictionary *)cursor excluding:(NSSet *)excluded current:(BOOL(^)(void))current checkpoint:(void(^)(NSDictionary *,BOOL,void(^)(NSString *)))checkpoint done:(void(^)(NSArray *,NSDictionary *,BOOL,NSString *))done {
    // Revisit acquired metadata before paging the provider. Newly classified
    // series may already be local, even when the remote catalog is at its end.
    NSArray *ratingTargets=@[];if(self.restricted){NSDictionary *snapshot=[self discoveryInputSnapshot];NSMutableArray *pool=[NSMutableArray new];for(NSArray *group in snapshot[@"groups"])[pool addObjectsFromArray:group];
        NSArray *candidates=[RWHomeRailPolicy ratingCandidates:pool row:row excluding:excluded metadata:snapshot[@"metadata"] preferences:snapshot[@"profile"][@"discoveryPreferences"] rating:^NSDictionary *(NSString *key){return [self.ratings rating:key];} now:NSDate.date.timeIntervalSince1970];
        ratingTargets=candidates;[self report:@{@"home_rail_ratings":@{@"row":row[@"id"],@"ids":[candidates valueForKey:@"id"]}}];[self.ratings resolve:candidates interactive:YES];
    }
    [self settleHomeRatingsUntil:NSProcessInfo.processInfo.systemUptime+4 items:ratingTargets current:current done:^{
        if(!current()){done(nil,nil,YES,@"Loading paused. Try again.");return;}
        [self rankHomeRail:[self discoveryPool] row:row excluding:excluded available:YES done:^(NSArray *ready){
            if(!current()){done(nil,nil,YES,@"Loading paused. Try again.");return;}
            NSDictionary *next=[RWHomeRailPolicy cursorAfterLocalPage:cursor];
            // Shared cached discoveries cannot indefinitely replace this row's
            // own catalog. Honour its due turn even while local cards remain.
            if([RWHomeRailPolicy shouldBrowseBeforeCheckingLocal:row cursor:cursor restricted:self.restricted now:NSDate.date.timeIntervalSince1970]){[self traceHomeRailStage:@"catalog_turn" detail:@{@"row":row[@"id"]}];[self homeRailPage:row cursor:cursor excluding:excluded scans:3 current:current checkpoint:checkpoint done:done];return;}
            if(ready.count){done(ready,next,YES,nil);return;}
            [self rankHomeRail:[self discoveryPool] row:row excluding:excluded available:NO done:^(NSArray *targets){
                if(!current()){done(nil,nil,YES,@"Loading paused. Try again.");return;}
                if(!targets.count){[self homeRailPage:row cursor:cursor excluding:excluded scans:3 current:current checkpoint:checkpoint done:done];return;}
                [self verifyHomeRail:targets index:0 current:current done:^{if(!current()){done(nil,nil,YES,@"Loading paused. Try again.");return;}[self rankHomeRail:[self discoveryPool] row:row excluding:excluded available:YES done:^(NSArray *qualified){done(qualified,next,YES,nil);}];}];
            }];
        }];
    }];
}
- (void)homeRailPage:(NSDictionary *)row cursor:(NSDictionary *)cursor excluding:(NSSet *)excluded scans:(NSUInteger)scans current:(BOOL(^)(void))current checkpoint:(void(^)(NSDictionary *,BOOL,void(^)(NSString *)))checkpoint done:(void(^)(NSArray *,NSDictionary *,BOOL,NSString *))done {
    NSMutableDictionary *next=[cursor mutableCopy]?:[NSMutableDictionary new];next[@"page"]=@([cursor[@"page"]unsignedIntegerValue]+1);
    [self rankHomeRail:[self discoveryPool] row:row excluding:excluded available:YES done:^(NSArray *ready){
        if(!current()){done(nil,nil,YES,@"Loading paused. Try again.");return;}
        if(ready.count&&![RWHomeRailPolicy shouldBrowseBeforeCheckingLocal:row cursor:cursor restricted:self.restricted now:NSDate.date.timeIntervalSince1970]){done(ready,next,YES,nil);return;}
        // Featured and Popular catalogs have independent offsets. An old end
        // belongs only to its original catalog, never to the entire shelf.
        NSDictionary *page=[RWHomeRailPolicy catalogPage:row cursor:next restricted:self.restricted now:NSDate.date.timeIntervalSince1970],*request=page[@"request"];
        if(!request){done(@[],page[@"cursor"],NO,nil);return;}
        if([page[@"deferred"]boolValue]){done(@[],page[@"cursor"],YES,@"Catalogs are temporarily unavailable. Try again shortly.");return;}
        NSUInteger skip=[request[@"skip"]unsignedIntegerValue];
        [self traceHomeRailStage:@"catalog" detail:@{@"row":row[@"id"],@"key":request[@"key"],@"skip":@(skip)}];
        BOOL worldCatalog=[request[@"sort"]isEqual:@"World Cinema"];
        void(^received)(id,NSDictionary *,NSString *)=^(id result,NSDictionary *providerNext,NSString *error){
            if(!current()){done(nil,nil,YES,@"Loading paused. Try again.");return;}if(error||![result isKindOfClass:NSArray.class]){
                NSString *failure=error?:@"Couldn’t read this catalog. Try again.";double now=NSDate.date.timeIntervalSince1970;
                NSDictionary *deferred=[RWHomeRailPolicy deferCatalogPage:page now:now];
                [self traceHomeRailStage:@"catalog_failed" detail:@{@"row":row[@"id"],@"key":request[@"key"],@"skip":@(skip)}];
                void(^continueAfterFailure)(NSString *)=^(NSString *saveError){
                    if(!current()){done(nil,nil,YES,@"Loading paused. Try again.");return;}if(saveError){done(nil,nil,YES,saveError);return;}
                    // Persist the failed offset/cooldown, then use already
                    // qualified local cards instead of delaying them behind
                    // another provider. They still pass normal append gates.
                    if(ready.count){done(ready,deferred,YES,nil);return;}
                    NSDictionary *alternate=[RWHomeRailPolicy catalogPage:row cursor:deferred restricted:self.restricted now:NSDate.date.timeIntervalSince1970];
                    if(scans>1&&alternate[@"request"]&&![alternate[@"deferred"]boolValue]){
                        [self homeRailPage:row cursor:deferred excluding:excluded scans:scans-1 current:current checkpoint:checkpoint done:done];
                    }else done(@[],deferred,YES,failure);
                };
                // Save only the failed timestamp/next turn, never a consumed
                // offset. The existing three-read budget also counts errors.
                if(checkpoint)checkpoint(deferred,YES,continueAfterFailure);else continueAfterFailure(nil);return;
            }
            [self traceHomeRailStage:@"catalog_received" detail:@{@"row":row[@"id"],@"key":request[@"key"]}];NSArray *raw=result;if(raw.count>100){done(nil,nil,YES,@"This catalog page is too large. Try again.");return;}
            NSDictionary *advanced=worldCatalog?[RWHomeRailPolicy advanceWorldPage:page continuation:providerNext now:NSDate.date.timeIntervalSince1970]:[RWHomeRailPolicy advanceCatalogPage:page received:raw.count now:NSDate.date.timeIntervalSince1970];
            if(!advanced){done(nil,nil,YES,@"Invalid catalog continuation.");return;}
            BOOL more=[RWHomeRailPolicy catalogPage:row cursor:advanced restricted:self.restricted now:NSDate.date.timeIntervalSince1970][@"request"]!=nil;
            [self report:@{@"home_rail_catalog":@{@"row":row[@"id"],@"catalog":request[@"key"],@"skip":@(skip),@"received":@(raw.count),@"more_catalogs":@(more)}}];
            // The received metadata is acquired before its offset is saved.
            // Source/rating work may time out later without repeating this page.
            if(raw.count)[self acceptDiscoveryCandidates:raw];
            void(^continuePage)(NSString *)=^(NSString *saveError){
            if(!current()){done(nil,nil,YES,@"Loading paused. Try again.");return;}
            if(saveError){done(nil,nil,YES,saveError);return;}
            if(!raw.count){if(more&&scans>1)[self homeRailPage:row cursor:advanced excluding:excluded scans:scans-1 current:current checkpoint:checkpoint done:done];else done(@[],advanced,more,nil);return;}
            NSDictionary *metadata=[self.discoveryMetadata titleSnapshot];
            NSArray *ratingTargets=self.restricted?[RWHomeRailPolicy ratingCandidates:raw row:row excluding:excluded metadata:metadata preferences:self.profile[@"discoveryPreferences"] rating:^NSDictionary *(NSString *key){return [self.ratings rating:key];} now:NSDate.date.timeIntervalSince1970]:@[];
            NSArray *metadataTargets=self.restricted?@[]:[RWHomeRailPolicy metadataCandidates:raw row:row excluding:excluded metadata:metadata preferences:self.profile[@"discoveryPreferences"] now:NSDate.date.timeIntervalSince1970];
            if(ratingTargets.count)[self.ratings resolve:ratingTargets interactive:YES];
            if(metadataTargets.count)[self.discoveryMetadata prioritizeTitles:metadataTargets];
            [self.discoveryMetadata enqueue:raw];double evidenceBegan=NSProcessInfo.processInfo.systemUptime;
            [self settleHomeEvidenceUntil:evidenceBegan+8 ratings:ratingTargets metadata:metadataTargets current:current done:^{
            BOOL evidencePending=(self.restricted&&[self.ratings isResolvingItems:ratingTargets])||[self.discoveryMetadata isResolvingItems:metadataTargets];
            [self traceHomeRailStage:@"evidence" detail:@{@"row":row[@"id"],@"ratings":[ratingTargets valueForKey:@"id"],@"metadata":[metadataTargets valueForKey:@"id"],@"pending":@(evidencePending),@"seconds":@(NSProcessInfo.processInfo.systemUptime-evidenceBegan)}];
            if(!current()){done(nil,nil,YES,@"Loading paused. Try again.");return;}
            double enrichBegan=NSProcessInfo.processInfo.systemUptime;[self enrichDiscoveryItems:raw done:^(NSArray *enriched){[self traceHomeRailStage:@"enrich" detail:@{@"row":row[@"id"],@"seconds":@(NSProcessInfo.processInfo.systemUptime-enrichBegan),@"received":@(raw.count),@"prepared":@(enriched.count)}];if(!current()){done(nil,nil,YES,@"Loading paused. Try again.");return;}
                NSMutableArray *pool=[[self discoveryPool]mutableCopy];[pool addObjectsFromArray:enriched];if(pool.count>500)pool=[[pool subarrayWithRange:NSMakeRange(pool.count-500,500)]mutableCopy];
                [self rankHomeRail:raw row:row excluding:excluded available:NO done:^(NSArray *targets){
                    if(!current()){done(nil,nil,YES,@"Loading paused. Try again.");return;}
                    [self report:@{@"home_rail_check":@{@"row":row[@"id"],@"catalog":request[@"key"],@"skip":@(skip),@"received":@(raw.count),@"targets":@(MIN(4,targets.count))}}];
                    // At most three catalog reads, then one four-target source
                    // allowance. An empty or filtered page consumes a read.
                    // Pending classification is not an empty catalog. Keep its
                    // acquired page and let late evidence reach the same pool;
                    // do not consume more catalogs behind an unfinished lookup.
                    if(!targets.count&&!evidencePending&&more&&scans>1){[self homeRailPage:row cursor:advanced excluding:excluded scans:scans-1 current:current checkpoint:checkpoint done:done];return;}
                    [self verifyHomeRail:targets index:0 current:current done:^{if(!current()){done(nil,nil,YES,@"Loading paused. Try again.");return;}
                        [self rankHomeRail:pool row:row excluding:excluded available:YES done:^(NSArray *qualified){done(qualified,advanced,more,nil);}];
                    }];
                }];
            }];
            }];
            };
            if(checkpoint)checkpoint(advanced,more,continuePage);else continuePage(nil);
        };
        if(worldCatalog)[self.discoveryMetadata worldPage:request[@"continuation"]?:@{} owner:[@"home-world:" stringByAppendingString:self.state[@"activeProfile"]] done:^(NSArray *items,NSDictionary *next,NSString *error){received(items,next,error);}];
        else [self browse:request[@"type"] sort:request[@"sort"] genre:request[@"genre"] year:0 skip:skip foreground:NO done:^(id items,NSString *error){received(items,nil,error);}];
    }];
}
