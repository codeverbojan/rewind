// Recheck at activation, not just when the player was first constructed.
- (NSDictionary *)playbackAfter:(NSString *)videoID show:(NSDictionary *)show profileID:(NSString *)profileID {
    if(![profileID isEqual:self.state[@"activeProfile"]]||![self allowed:show]||[self.profile[@"hidden"]containsObject:RWID(show)])return nil;
    NSDictionary *episode=[RWTVPolicy episodeAfter:videoID show:show now:NSDate.date];
    if(!episode)return nil;
    return @{@"meta":[RWTVPolicy episodeMeta:episode show:show],@"videoID":episode[@"id"],@"season":episode[@"season"],@"episode":episode[@"episode"]};
}
- (void)remindEpisodes:(NSDictionary *)show enabled:(BOOL)enabled {
    if(![self allowed:show]||![show[@"type"]isEqual:@"series"])return;
    [self follow:show enabled:enabled];if(enabled){self.profile[@"episodeNotifications"]=@YES;[self saveForReason:NSStringFromSelector(_cmd)];[UIApplication.sharedApplication registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeSound categories:nil]];}
}
- (NSDictionary *)cachedShow:(NSString *)identifier {return _seriesCache[identifier];}
- (NSDictionary *)canonicalShow:(NSString *)identifier {return [self cachedShow:identifier]?:[_episodeCatalog show:identifier now:NSDate.date.timeIntervalSince1970];}
- (NSDictionary *)discoveryShows {return [_episodeCatalog showsByAddingDetails:_seriesCache now:NSDate.date.timeIntervalSince1970];}
- (NSDictionary *)episodeCatalogDiagnostics {return [_episodeCatalog diagnostics];}
- (void)removeEpisodeDetails:(NSString *)key {[_seriesCache removeObjectForKey:key];[_discoveryEpisodes invalidate:key];}
- (NSDictionary *)evictEpisodeDetailsForDiagnostics:(NSArray *)identifiers {
    // Called only by the bounded foreground recipe. Evict expendable metadata
    // through the same path used by the twelve-show capacity limit. No source,
    // profile, history or readiness observation is manufactured here.
    if(!identifiers.count||identifiers.count>4)return nil;
    double now=NSDate.date.timeIntervalSince1970;NSMutableDictionary *before=[NSMutableDictionary new],*after=[NSMutableDictionary new],*fullBefore=[NSMutableDictionary new];
    for(NSString *key in identifiers){NSDictionary *compact=[_episodeCatalog show:key now:now];if(!compact)return nil;fullBefore[key]=@(_seriesCache[key]!=nil);before[key]=[self availabilityVideoID:@{@"id":key,@"type":@"series"}]?:@"";}
    for(NSString *key in identifiers){[self removeEpisodeDetails:key];after[key]=[self availabilityVideoID:@{@"id":key,@"type":@"series"}]?:@"";}
    NSDictionary *snapshot=[_seriesCache copy];NSString *path=[RWDocuments()stringByAppendingPathComponent:@"rewind-series.json"];dispatch_async(_recommendationQueue,^{[[RWAtomicWriter shared]write:[NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil] path:path];});
    [[NSNotificationCenter defaultCenter]postNotificationName:@"RWSeriesCacheUpdated" object:self userInfo:@{@"diagnostic_eviction":identifiers}];
    return @{@"before":before,@"after":after,@"full_before":fullBefore,@"catalog":[_episodeCatalog diagnostics],@"full_count":@(_seriesCache.count)};
}
- (BOOL)following:(NSDictionary *)show {return self.profile[@"following"][RWID(show)]!=nil;}
- (void)follow:(NSDictionary *)show enabled:(BOOL)enabled {
    if(![self allowed:show]||![show[@"type"]isEqual:@"series"])return;NSString *key=RWID(show);
    if(!enabled){if(![self.profile[@"unfollowedShows"]containsObject:key])[self.profile[@"unfollowedShows"]addObject:key];[self.profile[@"following"]removeObjectForKey:key];[self.profile[@"episodeUpdates"]removeObjectForKey:key];[self saveForReason:NSStringFromSelector(_cmd)];return;}
    [self.profile[@"unfollowedShows"]removeObject:key];if([self following:show])return;
    NSDictionary *full=[self cachedShow:key]?:show;NSMutableDictionary *meta=[show mutableCopy];[meta removeObjectForKey:@"videos"];if(RWString(meta[@"seriesName"]).length)meta[@"name"]=meta[@"seriesName"];
    NSMutableArray *seen=[NSMutableArray new];for(NSDictionary *e in [RWTVPolicy episodes:full])if([RWTVPolicy released:e now:NSDate.date])[seen addObject:e[@"id"]];
    self.profile[@"following"][key]=@{@"meta":meta,@"seen":seen,@"checked":@0,@"started":@(NSDate.date.timeIntervalSince1970),@"baseline":@(full[@"videos"]!=nil)};[self saveForReason:NSStringFromSelector(_cmd)];
}
- (NSUInteger)acceptShow:(NSDictionary *)show profile:(NSString *)profileID notify:(BOOL)notify {
    if(![show[@"type"]isEqual:@"series"]||![show[@"videos"]isKindOfClass:NSArray.class])return 0;NSString *key=RWID(show);if(!key.length)return 0;
    show=[RWDiscoveryEpisodes immutableShow:show]?:show;[_episodeCatalog accept:show now:NSDate.date.timeIntervalSince1970];
    NSString *evicted=@"";[_discoveryEpisodes invalidate:key];_seriesCache[key]=show;if([_seriesCache count]>12){for(NSString *old in [_seriesCache allKeys])if(![old isEqual:key]){evicted=old;[self removeEpisodeDetails:old];break;}}
    NSDictionary *change=@{@"title":key,@"evicted":evicted,@"count":@(_seriesCache.count),@"at":@(NSDate.date.timeIntervalSince1970)};
    void(^publish)(void)=^{[self report:@{@"series_cache_update":change}];[[NSNotificationCenter defaultCenter]postNotificationName:@"RWSeriesCacheUpdated" object:self userInfo:change];};
    NSDictionary *episodeSnapshot=[_episodeCatalog snapshot];NSString *episodePath=[RWDocuments()stringByAppendingPathComponent:@"rewind-episode-catalog.json"];dispatch_async(_recommendationQueue,^{NSData *data=[NSJSONSerialization dataWithJSONObject:episodeSnapshot options:0 error:nil];[[RWAtomicWriter shared]write:data path:episodePath];});
    NSDictionary *showSnapshot=[_seriesCache copy];NSString *showPath=[RWDocuments()stringByAppendingPathComponent:@"rewind-series.json"];dispatch_async(_recommendationQueue,^{NSData *data=[NSJSONSerialization dataWithJSONObject:showSnapshot options:0 error:nil];[[RWAtomicWriter shared]write:data path:showPath];});
    NSMutableDictionary *profile=self.state[@"profiles"][profileID];NSDictionary *old=profile[@"following"][key];if(!old){publish();return 0;} // Cache-only changes still invalidate Home's episode decisions.
    NSDate *now=NSDate.date;NSArray *updates=[RWTVPolicy newEpisodes:show seen:[old[@"baseline"]boolValue]?old[@"seen"]:nil since:[NSDate dateWithTimeIntervalSince1970:MAX([old[@"started"]doubleValue],now.timeIntervalSince1970-30*86400)] now:now];
    NSMutableArray *seen=[NSMutableArray new];for(NSDictionary *ep in [RWTVPolicy episodes:show])if([RWTVPolicy released:ep now:now])[seen addObject:ep[@"id"]];
    NSMutableDictionary *entry=[old mutableCopy];entry[@"seen"]=seen;entry[@"checked"]=@(now.timeIntervalSince1970);entry[@"baseline"]=@YES;profile[@"following"][key]=entry;
    BOOL permitted=[RWRatingPolicy allows:[self.ratings rating:key] age:[profile[@"maxAge"]integerValue]]&&![profile[@"hidden"]containsObject:key];
    NSMutableArray *unwatched=[NSMutableArray new];for(NSDictionary *ep in updates)if(![profile[@"history"][ep[@"id"]][@"completed"]boolValue])[unwatched addObject:ep];updates=unwatched;
    if(updates.count&&permitted){NSDictionary *ep=updates.lastObject;if(![profile[@"history"][ep[@"id"]][@"completed"]boolValue])profile[@"episodeUpdates"][key]=@{@"episode":ep,@"detected":@(now.timeIntervalSince1970)};
        if(notify&&[profile[@"episodeNotifications"]boolValue]&&[profileID isEqual:self.state[@"activeProfile"]]&&([UIApplication.sharedApplication currentUserNotificationSettings].types&UIUserNotificationTypeAlert)){
            // Generic lock-screen text never exposes another profile's viewing history.
            UILocalNotification *n=[UILocalNotification new];n.alertBody=@"New episodes have aired. Open Rewind to check them.";n.soundName=UILocalNotificationDefaultSoundName;n.userInfo=[RWReminderPolicy payload:@"episode" profile:profileID title:key video:ep[@"id"]];[UIApplication.sharedApplication presentLocalNotificationNow:n];
        }
    }[self saveForReason:NSStringFromSelector(_cmd)];publish();return permitted?updates.count:0;
}
- (NSArray *)episodeUpdates {
    NSMutableArray *out=[NSMutableArray new];for(NSString *key in self.profile[@"episodeUpdates"]){NSDictionary *show=[self cachedShow:key]?:self.profile[@"following"][key][@"meta"];NSDictionary *ep=self.profile[@"episodeUpdates"][key][@"episode"];
        if(!show||![self allowed:show]||[self.profile[@"history"][ep[@"id"]][@"completed"]boolValue])continue;NSMutableDictionary *m=[show mutableCopy];[m removeObjectForKey:@"videos"];m[@"name"]=[NSString stringWithFormat:@"%@ · New S%ld E%ld",RWString(show[@"name"]),(long)[ep[@"season"]integerValue],(long)[ep[@"episode"]integerValue]];m[@"seriesName"]=RWString(show[@"name"]);[out addObject:m];
    }return out;
}
- (NSArray *)continuingHistory {return [RWTVPolicy continuingRecords:self.history];}
- (BOOL)markEpisode:(NSDictionary *)episode show:(NSDictionary *)show watched:(BOOL)watched {
    if(![show[@"type"]isEqual:@"series"]||![self allowed:show]||[self.profile[@"hidden"]containsObject:RWID(show)])return NO;
    NSDictionary *validated=nil;for(NSDictionary *candidate in [RWTVPolicy episodes:show])if([candidate[@"id"]isEqual:episode[@"id"]]){validated=candidate;break;}
    if(!validated||![RWTVPolicy released:validated now:NSDate.date])return NO;
    NSString *videoID=validated[@"id"];NSMutableDictionary *record=[[self record:videoID]mutableCopy]?:[NSMutableDictionary new];
    record[@"meta"]=[RWTVPolicy episodeMeta:validated show:show];record[@"videoID"]=videoID;record[@"completed"]=@(watched);record[@"position"]=@0;record[@"updated"]=@(NSDate.date.timeIntervalSince1970);record[@"progressOverride"]=watched?@"watched":@"unwatched";
    self.profile[@"history"][videoID]=record;self.profile[@"selectedSeasons"][RWID(show)]=validated[@"season"];
    if(watched&&[self.profile[@"episodeUpdates"][RWID(show)][@"episode"][@"id"]isEqual:videoID])[self.profile[@"episodeUpdates"]removeObjectForKey:RWID(show)];
    [_discoveryEpisodes invalidate:RWID(show)];[self follow:show enabled:YES];[self saveForReason:NSStringFromSelector(_cmd)];
    [[NSNotificationCenter defaultCenter]postNotificationName:@"RWEpisodesUpdated" object:self];return YES;
}
- (NSArray *)upNext {
    NSMutableArray *out=[NSMutableArray new];for(NSString *key in self.profile[@"following"]){NSDictionary *show=[self cachedShow:key];if(!show||![self allowed:show])continue;NSDictionary *ep=[_discoveryEpisodes episode:nil show:show history:self.profile[@"history"] now:NSDate.date];if(!ep)continue;NSDictionary *r=[self record:ep[@"id"]];if([r[@"position"]doubleValue]>3&&! [r[@"completed"]boolValue])continue;NSMutableDictionary *m=[[RWTVPolicy episodeMeta:ep show:show]mutableCopy];m[@"episodeVideoID"]=ep[@"id"];m[@"episodeCaption"]=[NSString stringWithFormat:@"Next · Season %@, Episode %@",ep[@"season"],ep[@"episode"]];[out addObject:m];}return out;
}
- (void)checkEpisodes:(void(^)(BOOL))done {[self checkEpisodesBackground:NO minimumInterval:3600 notify:YES done:done];}
- (void)checkEpisodesInBackground:(void(^)(BOOL))done {[self checkEpisodesBackground:YES minimumInterval:3600 notify:YES done:done];}
- (NSDictionary *)episodeCheckDiagnostics {return _lastEpisodeFetch?:@{};}
- (void)checkEpisodesForDiagnostics:(void(^)(void))done {
    // Exercise the production bounded background path while ordinary metadata
    // stays paused. No backdating user records and no notification side effects.
    BOOL wasPaused=RWMetadataBudget.shared.paused;RWMetadataBudget.shared.paused=YES;
    [self checkEpisodesBackground:YES minimumInterval:0 notify:NO done:^(BOOL changed){
        [self report:@{@"episode_diagnostic_metadata_paused":@(RWMetadataBudget.shared.paused)}];
        RWMetadataBudget.shared.paused=wasPaused||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive;if(done)done();
    }];
}
- (void)checkEpisodesBackground:(BOOL)background minimumInterval:(double)interval notify:(BOOL)notify done:(void(^)(BOOL))done {
    // An OS background-fetch window may replace a foreground request which
    // became suspended with ordinary discovery. Cancel it before taking over.
    if(_checkingEpisodes){if(background&&!_episodeFetcher.background)[_episodeFetcher cancel];else{done(NO);return;}}
    _checkingEpisodes=YES;NSString *profileID=self.state[@"activeProfile"];__block BOOL changed=NO;__weak RewindStore *weak=self;
    RWEpisodeFetcher *fetcher=[[RWEpisodeFetcher alloc]initWithSession:_episodeSession budget:RWMetadataBudget.shared];_episodeFetcher=fetcher;
    [fetcher startWhenReady:^BOOL{return weak.catalogReady;} identifiers:^NSArray *{
        if(![profileID isEqual:weak.state[@"activeProfile"]])return @[];NSMutableArray *ids=[NSMutableArray new];NSDictionary *following=weak.profile[@"following"];
        NSArray *keys=[following keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"checked"]compare:b[@"checked"]];}];
        for(NSString *key in keys){NSDictionary *f=following[key];if(NSDate.date.timeIntervalSince1970-[f[@"checked"]doubleValue]>interval&&[weak allowed:f[@"meta"]]&&![weak.profile[@"hidden"]containsObject:key]){[ids addObject:key];if(ids.count==4)break;}}return ids;
    } background:background timeout:20 accept:^(NSDictionary *show){if([profileID isEqual:weak.state[@"activeProfile"]])changed|=[weak acceptShow:show profile:profileID notify:notify]>0;} done:^(NSDictionary *metrics){RewindStore *store=weak;if(!store){done(NO);return;}store->_checkingEpisodes=NO;store->_episodeFetcher=nil;store->_lastEpisodeFetch=metrics;[store report:@{@"episode_fetch":metrics}];done(changed);[[NSNotificationCenter defaultCenter]postNotificationName:@"RWEpisodesUpdated" object:weak];}];
}
