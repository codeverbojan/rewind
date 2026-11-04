- (void)imdbIndexUpdated {
    [self report:@{@"imdb_index":self.imdbIndex.diagnostics?:@{},@"imdb_index_updated_at":@(NSDate.date.timeIntervalSince1970)}];
    [self refreshDiscovery];
}
- (NSDictionary *)discoveryMeta:(NSDictionary *)meta {
    meta=RWNormalizeMediaIdentity(meta,[self discoveryShows][RWID(meta)]);
    NSMutableDictionary *m=[([self.discoveryMetadata enrich:meta]?:meta)mutableCopy];NSDictionary *rating=_discoveryRatings[RWID(meta)];
    if(rating){m[@"imdbRating"]=[NSString stringWithFormat:@"%.1f",[rating[@"rating"]doubleValue]];m[@"imdbVotes"]=rating[@"votes"];}
    NSString *episode=[self availabilityVideoID:meta];m[@"availability"]=[self availability:meta videoID:episode];m[@"ageAllowed"]=@([self allowed:meta]);
    if([meta[@"type"]isEqual:@"series"]&&episode.length)m[@"episodeVideoID"]=episode;
    return m;
}
- (RWHomeValidation *)homeValidationWithFallback:(NSDictionary *)prepared {
    if(!_homePreparedMetadata.count&&!prepared.count)return nil;double began=NSProcessInfo.processInfo.systemUptime;
    // Validation stays on the owning main thread and does not retain this
    // live view. Do not recapture ranking groups/exposures for a synchronous
    // comparison; the worker's retained scope came from an isolated snapshot.
    NSDictionary *current=@{@"family":self.familyCatalog?:@[],@"shows":[self discoveryShows]?:@{},@"metadata":[self.discoveryMetadata titleSnapshot]?:@{},@"ageRatings":[self.ratings snapshot]?:@{},@"profile":self.profile,@"quality":@(self.quality),@"offline":_offlineEvidence?:@{},@"offlineAt":@(_offlineEvidenceAt)};
    RWHomeValidation *pass=[[RWHomeValidation alloc]initWithRanked:_homePreparedMetadata fallback:prepared snapshot:current ratings:_discoveryRatings profileID:self.state[@"activeProfile"] priors:self.discoveryHome[@"ratingPriors"] now:NSDate.date.timeIntervalSince1970];
    [[RWUIProbe shared]work:@"home_validation_context" started:began];return pass;
}
- (void)prepareHomeMetadata:(NSDictionary *)home requestedIDs:(NSSet *)requested previous:(NSDictionary *)previous done:(void(^)(NSDictionary *))done {
    // The controller permits one outstanding request. Reuse the existing serial
    // worker and do no provider/ratings lookup: this is only cached membership.
    double began=NSProcessInfo.processInfo.systemUptime;NSDictionary *plan=[RWHomeDeferredPreparation boundedPlan:home];
    NSDictionary *input=[self discoveryInputSnapshot],*ratings=[_discoveryRatings copy];NSString *profile=[self.state[@"activeProfile"]copy];NSSet *wanted=[requested copy];
    [[RWUIProbe shared]work:@"home_deferred_capture" started:began];
    dispatch_async(_recommendationQueue,^{@autoreleasepool{
        NSDictionary *result=[RWHomeDeferredPreparation prepare:plan requestedIDs:wanted previous:previous snapshot:input ratings:ratings profileID:profile now:NSDate.date.timeIntervalSince1970];
        dispatch_async(dispatch_get_main_queue(),^{done(result);});
    }});
}
- (NSArray *)discoveryPool {
    NSMutableArray *items=[NSMutableArray new];
    NSArray *groups=@[self.restricted?self.familyCatalog:@[],self.freshMovies?:@[],self.freshSeries?:@[],self.movies?:@[],self.series?:@[],self.discoveryCatalog?:@[],self.curatedMovies?:@[],self.curatedSeries?:@[],self.saved?:@[],[RWHomeDelivery retainedTitles:self.profile[@"sourceAvailability"]]];
    NSArray *pool=[RWDiscoveryCatalog balancedPool:groups limit:500 allows:^BOOL(NSDictionary *m){return [self allowed:m];}];
    for(NSDictionary *raw in pool){NSMutableDictionary *brief=[raw mutableCopy];[brief removeObjectForKey:@"videos"];[items addObject:brief];}
    return items;
}
- (NSDictionary *)discoveryCoverageDiagnostics {
    NSMutableArray *series=[NSMutableArray new],*world=[NSMutableArray new];NSDictionary *prefs=[RWDiscoveryMetadataPolicy preferences:self.profile[@"discoveryPreferences"]];
    for(NSDictionary *m in _discoveryPrepared){BOOL show=[m[@"type"]isEqual:@"series"],international=[m[@"type"]isEqual:@"movie"]&&[[RWDiscoveryMetadataPolicy languageGroup:m[@"discovery"]]isEqual:@"world"];if(!show&&!international)continue;
        NSMutableArray *out=show?series:world;if(out.count==100)continue;
        [out addObject:@{@"id":RWID(m),@"name":RWString(m[@"name"]),@"episode":RWString(m[@"episodeVideoID"]),@"language":[RWDiscoveryMetadataPolicy languageGroup:m[@"discovery"]]?:@"",@"availability":m[@"availability"]?:@{},@"ageAllowed":m[@"ageAllowed"]?:@NO,@"quality":@([RWRecommendationPolicy homeQualityEligible:m]),@"languageAllowed":@(self.restricted&&!international?YES:[RWDiscoveryMetadataPolicy permits:m preferences:prefs world:international]),@"rating":m[@"imdbRating"]?:@0,@"votes":m[@"imdbVotes"]?:@0}];
    }
    return @{@"prepared":@(_discoveryPrepared.count),@"series":series,@"world":world,@"profile":self.state[@"activeProfile"],@"preferences":prefs,@"episode_catalog":[self episodeCatalogDiagnostics]};
}
- (void)setDiscoveryPaused:(BOOL)paused {
    if(paused&&!_discoveryPaused)[self suspendHomeRefresh];
    [RWMetadataBudget shared].backgroundPaused=paused;if(_discoveryPaused==paused)return;_discoveryPaused=paused;self.discoveryMetadata.paused=paused;self.imdbIndex.paused=paused;
    if(paused){_homeGeneration++;_homeAvailabilityBusy=NO;_homePublicationRequested=NO;_discoveryGeneration++;_availabilityWatchGeneration++;_checkingAvailability=NO;}
    if(!paused)[self refreshDiscovery];
}
- (void)refreshDiscovery {
    if(!self.catalogReady||_discoveryScheduled||_discoveryPaused||(_homeAvailabilityBusy&&!_homePublicationRequested))return;_discoveryScheduled=YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/2),dispatch_get_main_queue(),^{
        self->_discoveryScheduled=NO;if(self->_discoveryPaused||(self->_homeAvailabilityBusy&&!self->_homePublicationRequested))return;self->_homePublicationRequested=NO;
        double captureBegan=NSProcessInfo.processInfo.systemUptime;NSUInteger generation=++self->_discoveryGeneration;NSString *profile=[self.state[@"activeProfile"]copy];NSDictionary *snapshot=[self discoveryInputSnapshot];
        double captureSeconds=NSProcessInfo.processInfo.systemUptime-captureBegan;
        dispatch_async(self->_recommendationQueue,^{@autoreleasepool{
        double poolBegan=NSProcessInfo.processInfo.systemUptime;NSArray *pool=[RWDiscoverySnapshot pool:snapshot];NSArray *ids=[RWDiscoverySnapshot ratingIDs:pool snapshot:snapshot includeSignals:YES now:NSDate.date.timeIntervalSince1970];
        double poolSeconds=NSProcessInfo.processInfo.systemUptime-poolBegan;
        dispatch_async(dispatch_get_main_queue(),^{
        if(generation!=self->_discoveryGeneration||![profile isEqual:self.state[@"activeProfile"]]||self->_discoveryPaused)return;
        [self.imdbIndex ratingsForIDs:ids done:^(NSDictionary *ratings){
            if(generation!=self->_discoveryGeneration||![profile isEqual:self.state[@"activeProfile"]]||self->_discoveryPaused)return;
            [self refreshOfflineEvidence:^{if(generation!=self->_discoveryGeneration||![profile isEqual:self.state[@"activeProfile"]]||self->_discoveryPaused)return;
            NSMutableDictionary *input=[snapshot mutableCopy];input[@"offline"]=[self->_offlineEvidence copy]?:@{};input[@"offlineAt"]=@(self->_offlineEvidenceAt);double now=NSDate.date.timeIntervalSince1970;NSInteger quality=self.quality;
            dispatch_async(self->_recommendationQueue,^{@autoreleasepool{
                NSDictionary *prepared=[RWDiscoverySnapshot prepare:pool snapshot:input ratings:ratings now:now];NSDictionary *context=prepared[@"profile"];NSInteger year=[[NSCalendar currentCalendar]component:NSCalendarUnitYear fromDate:[NSDate dateWithTimeIntervalSince1970:now]];
                NSDictionary *home=[RWRecommendationPolicy home:prepared[@"items"] profile:context year:year now:now];NSDictionary *cached=[RWHomeDelivery snapshot:home profile:context quality:quality now:now];
                NSDictionary *presentation=[RWHomePreparation prepare:home snapshot:input ratings:ratings profileID:profile now:now];
                dispatch_async(dispatch_get_main_queue(),^{
                if(generation!=self->_discoveryGeneration||![profile isEqual:self.state[@"activeProfile"]]||self->_discoveryPaused)return;
                double applyBegan=NSProcessInfo.processInfo.systemUptime;self->_discoveryRatings=[ratings mutableCopy];self->_discoveryPrepared=prepared[@"items"];self->_discoveryContext=context;self.discoveryHome=home;self->_homePreparedMetadata=presentation;[self cacheDiscoverySnapshot:cached profile:profile];
                [self report:@{@"home_preparation":@{@"entries":@([presentation[@"entries"]count]),@"worker_seconds":presentation[@"worker_seconds"],@"off_main":presentation[@"off_main"]}}];
                [self report:@{@"discovery_ranking":@{@"seconds":home[@"seconds"],@"capture_main_seconds":@(captureSeconds),@"pool_worker_seconds":@(poolSeconds),@"prepare_worker_seconds":prepared[@"seconds"],@"prepare_off_main":prepared[@"off_main"],@"apply_main_seconds":@(NSProcessInfo.processInfo.systemUptime-applyBegan),@"candidates":home[@"candidateCount"],@"interest_model":home[@"interestModel"]?:@{},@"rows":@([home[@"rows"]count]),@"hero":RWID(home[@"hero"]),@"metadata":self.discoveryMetadata.diagnostics,@"episode_cache":prepared[@"episode_cache"],@"ratings_ids":@(ids.count),@"profile_signals":@([context[@"liked"]count]+[context[@"saved"]count]+[context[@"history"]count])}}];[[NSNotificationCenter defaultCenter]postNotificationName:@"RWRecommendationsUpdated" object:self];if(self->_homeRefreshRequested)[self refreshHomeAvailability];
            });}});
            }];
        }];
        });}});
    });
}
- (NSDictionary *)discoveryInputSnapshot {
    // Collection membership is copied on its owning main thread. Catalog,
    // metadata and rating payloads are value records, replaced on refresh.
    // Copy mutable profile containers/records; workers never access the store.
    NSMutableDictionary *profile=[NSMutableDictionary new];
    for(NSString *key in @[@"maxAge",@"hidden",@"discoveryPreferences",@"liked",@"saved"])profile[key]=[self.profile[key]copy]?:@{};
    for(NSString *key in @[@"history",@"sourceAvailability",@"discoveryExposures"])profile[key]=[[NSDictionary alloc]initWithDictionary:self.profile[key]?:@{} copyItems:YES];
    NSArray *groups=@[self.restricted?([self.familyCatalog copy]?:@[]):@[],[self.freshMovies copy]?:@[],[self.freshSeries copy]?:@[],[self.movies copy]?:@[],[self.series copy]?:@[],[self.discoveryCatalog copy]?:@[],[self.curatedMovies copy]?:@[],[self.curatedSeries copy]?:@[],[self.saved copy]?:@[],[RWHomeDelivery retainedTitles:profile[@"sourceAvailability"]]];
    return @{@"groups":groups,@"family":[self.familyCatalog copy]?:@[],@"shows":[self discoveryShows]?:@{},@"metadata":[self.discoveryMetadata titleSnapshot]?:@{},@"ageRatings":[self.ratings snapshot]?:@{},@"profile":profile,@"quality":@(self.quality),@"offline":[_offlineEvidence copy]?:@{},@"offlineAt":@(_offlineEvidenceAt)};
}
- (void)noteDiscoveryExposure:(NSArray *)items {
    NSMutableDictionary *exposures=self.profile[@"discoveryExposures"];BOOL changed=NO;double now=NSDate.date.timeIntervalSince1970;
    for(NSDictionary *m in items){NSString *key=RWID(m);if(!key.length)continue;NSDictionary *old=exposures[key];if(now-[old[@"at"]doubleValue]<1800)continue;changed=YES;exposures[key]=@{@"at":@(now),@"count":@(MIN(1000,[old[@"count"]integerValue]+1))};}
    if(exposures.count>500){NSArray *keys=[exposures keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"at"]compare:b[@"at"]];}];for(NSUInteger i=0;i<keys.count-500;i++)[exposures removeObjectForKey:keys[i]];}if(changed)[self saveForReason:NSStringFromSelector(_cmd)];
}
- (void)cacheDiscoverySnapshot:(NSDictionary *)snapshot profile:(NSString *)profileID {
    if(!snapshot.count)return;_homeSnapshots[profileID]=snapshot;
    for(NSString *key in [_homeSnapshots allKeys])if(!self.state[@"profiles"][key])[_homeSnapshots removeObjectForKey:key];
    NSDictionary *all=@{@"profiles":[_homeSnapshots copy]};NSString *path=[RWDocuments()stringByAppendingPathComponent:@"discovery-home.json"];
    dispatch_async(_recommendationQueue,^{NSData *data=[NSJSONSerialization dataWithJSONObject:all options:0 error:nil];if(data.length<=6*1024*1024)[[RWAtomicWriter shared]write:data path:path];});
}
#include "RewindHomeSelection.inc"
#include "RewindHomeRefresh.inc"
#include "RewindDiscoveryJobs.inc"
#include "RewindUpcomingPreparation.inc"
- (void)mergeExploreRecords:(NSArray *)local remote:(NSArray *)remote query:(NSString *)query done:(void(^)(NSArray *))done {
    NSString *profile=[self.state[@"activeProfile"]copy];BOOL restricted=self.restricted;
    dispatch_async(_recommendationQueue,^{@autoreleasepool{NSArray *records=[RWEntitySearchPolicy merge:local remote:remote query:query profile:profile restricted:restricted];dispatch_async(dispatch_get_main_queue(),^{if([profile isEqual:self.state[@"activeProfile"]])done(records);});}});
}
- (void)entityHighlights:(NSArray *)items entity:(NSDictionary *)entity done:(void(^)(NSDictionary *))done {
    NSArray *allowed=[[self allowedItems:items]copy];NSString *profile=self.state[@"activeProfile"];NSDictionary *identity=[entity copy];
    dispatch_async(_recommendationQueue,^{@autoreleasepool{NSDictionary *highlights=[RWEntityDetailsPolicy highlights:allowed entity:identity now:NSDate.date.timeIntervalSince1970];dispatch_async(dispatch_get_main_queue(),^{if([profile isEqual:self.state[@"activeProfile"]])done(highlights);});}});
}
- (void)localCreditsForEntity:(NSDictionary *)entity done:(void(^)(NSArray *))done {
    NSString *field=[RWEntityCreditPolicy field:entity[@"creditRole"]],*identifier=RWString(entity[@"id"]);if(!field||!identifier.length){done(@[]);return;}
    NSDictionary *snapshot=[self discoveryInputSnapshot],*ratings=[_discoveryRatings copy]?:@{};NSString *profile=self.state[@"activeProfile"];
    dispatch_async(_recommendationQueue,^{@autoreleasepool{NSMutableArray *matches=[NSMutableArray new];
        for(NSDictionary *raw in [RWDiscoverySnapshot pool:snapshot]){NSDictionary *metadata=snapshot[@"metadata"][RWID(raw)]?:raw[@"discovery"];if(![RWDiscoveryMetadataPolicy allowsRetainedCredit:raw record:metadata])continue;BOOL match=NO;for(NSDictionary *ref in metadata[field])if([ref[@"id"]isEqual:identifier]){match=YES;break;}if(!match)continue;
            NSMutableDictionary *m=[raw mutableCopy];if(metadata)m[@"discovery"]=metadata;NSDictionary *rating=ratings[RWID(raw)];if(rating){m[@"imdbRating"]=rating[@"rating"];m[@"imdbVotes"]=rating[@"votes"];}[matches addObject:m];}
        dispatch_async(dispatch_get_main_queue(),^{done([profile isEqual:self.state[@"activeProfile"]]?[self allowedItems:matches]:@[]);});
    }});
}
- (void)exploreRecords:(NSString *)kind mood:(NSString *)mood query:(NSString *)query done:(void(^)(NSArray *))done {
    NSDictionary *snapshot=[self discoveryInputSnapshot],*ratings=[_discoveryRatings copy]?:@{},*entities=[self.discoveryMetadata entitySnapshot];NSString *profile=[self.state[@"activeProfile"]copy];
    dispatch_async(_recommendationQueue,^{@autoreleasepool{double began=NSProcessInfo.processInfo.systemUptime;NSMutableArray *titles=[NSMutableArray new];NSSet *hidden=[NSSet setWithArray:[snapshot[@"profile"][@"hidden"]isKindOfClass:NSArray.class]?snapshot[@"profile"][@"hidden"]:@[]];
        for(NSDictionary *raw in [RWDiscoverySnapshot pool:snapshot]){if([hidden containsObject:RWID(raw)])continue;NSMutableDictionary *m=[raw mutableCopy];NSDictionary *metadata=snapshot[@"metadata"][RWID(raw)],*rating=ratings[RWID(raw)];if(metadata)m[@"discovery"]=metadata;if(rating){m[@"imdbRating"]=rating[@"rating"];m[@"imdbVotes"]=rating[@"votes"];}[titles addObject:m];}
        NSArray *records=[RWExploreIndex records:titles kind:kind mood:mood query:query profile:profile preferences:snapshot[@"profile"][@"discoveryPreferences"] restricted:[snapshot[@"profile"][@"maxAge"]integerValue]>=0 entities:entities now:NSDate.date.timeIntervalSince1970];double elapsed=NSProcessInfo.processInfo.systemUptime-began;
        dispatch_async(dispatch_get_main_queue(),^{if(![profile isEqual:self.state[@"activeProfile"]]){done(@[]);return;}[self report:@{@"explore_index":@{@"worker_seconds":@(elapsed),@"titles":@(titles.count),@"records":@(records.count),@"local_scope":@YES}}];done(records);});
    }});
}
- (void)refreshOfflineEvidence:(void(^)(void))done {
    NSDictionary *history=[self.profile[@"history"]copy];NSString *profile=self.state[@"activeProfile"];NSInteger quality=self.quality;NSString *root=[RWDocuments()stringByAppendingPathComponent:@"Torrents"];
    dispatch_async(_recommendationQueue,^{@autoreleasepool{NSMutableDictionary *valid=[NSMutableDictionary new];NSUInteger count=0;
        for(NSString *videoID in history){if(++count>256)break;NSDictionary *source=history[videoID][@"source"],*proof=source[@"offlineCertificate"];if(![proof isKindOfClass:NSDictionary.class]||![source[@"verifiedWidth"]integerValue]||![[RWSourcePolicy evaluate:source quality:quality freeBytes:0][@"eligible"]boolValue])continue;NSString *hash=RWString(source[@"infoHash"]).lowercaseString;NSInteger file=[source[@"fileIdx"]isKindOfClass:NSNumber.class]?[source[@"fileIdx"]integerValue]:-1;if([RWOfflineMedia validate:proof root:root hash:hash fileIndex:file])valid[videoID]=@{@"at":proof[@"verifiedAt"]?:@0,@"quality":@(quality)};
        }
        dispatch_async(dispatch_get_main_queue(),^{if([profile isEqual:self.state[@"activeProfile"]]&&quality==self.quality){self->_offlineEvidence=valid;self->_offlineEvidenceAt=NSDate.date.timeIntervalSince1970;}done();});
    }});
}
- (void)invalidateOfflineEvidence {_offlineEvidence=@{};_offlineEvidenceAt=0;[self refreshDiscovery];}
- (void)acceptDiscoveryCandidates:(NSArray *)items {
    self.discoveryCatalog=[RWDiscoveryCatalog merge:items existing:self.discoveryCatalog limit:500];NSDictionary *snapshot=@{@"items":self.discoveryCatalog};dispatch_async(_recommendationQueue,^{NSData *data=[NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil];if(data.length<=4*1024*1024)[[RWAtomicWriter shared]write:data path:[RWDocuments()stringByAppendingPathComponent:@"discovery-candidates.json"]];});[self refreshDiscovery];
}
#include "RewindDiscoveryCandidates.inc"

#include "RewindHomeContinuation.inc"
