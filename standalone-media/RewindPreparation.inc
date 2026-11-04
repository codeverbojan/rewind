- (NSDictionary *)preparationIdentity:(NSDictionary *)meta videoID:(NSString *)videoID resume:(double)resume {
    RewindStore *s=[RewindStore shared];return @{@"profile_id":s.state[@"activeProfile"]?:@"",@"type":meta[@"type"]?:@"",@"video_id":videoID?:@"",@"quality":@(s.quality),@"resume_position_seconds":@(resume)};
}
- (void)prepareCurrentTitle {
    double detailStage=NSProcessInfo.processInfo.systemUptime;RewindStore *s=[RewindStore shared];
    // The explicit episode UI recipe seeds progress only. Keep its detail
    // visits from downloading episode payloads or generating source evidence.
    if([@[@"library-browse",@"notification-routing",@"notification-schedule",@"notification-open-probe",@"presentation",@"episode-progress",@"feed-lists",@"feed-entity",@"feed-retry",@"feed-discovery",@"kids-boundaries",@"kids-surfaces",@"featured-ready"]containsObject:self.exerciseRequest[@"action"]]){[self.playbackPreparation cancel];return;}
    if(self.reviewMode||![self.page isEqual:@"Details"]||[self.presentedViewController isKindOfClass:RewindPlayer.class]||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive||![s allowed:self.detail]){[self.playbackPreparation cancel];return;}
    NSDictionary *meta=self.detail;NSString *videoID=RWID(meta);
    if([meta[@"type"]isEqual:@"series"]){NSDictionary *next=[self detailPlaybackEpisode:meta];
        if(!next){[self.playbackPreparation cancel];return;}videoID=RWString(next[@"id"]);meta=[RWTVPolicy episodeMeta:next show:meta];
    }
    [self recordDetailOpenStage:@"prepare.episode" started:detailStage];detailStage=NSProcessInfo.processInfo.systemUptime;
    NSDictionary *record=[s record:videoID];double resume=[record[@"completed"]boolValue]?0:[record[@"position"]doubleValue];
    NSDictionary *identity=[self preparationIdentity:meta videoID:videoID resume:resume];
    if(self.playbackPreparation&&![self.playbackPreparation canPrepareIdentity:identity])return;
    NSDictionary *current=self.playbackPreparation.diagnostics[@"identity"];BOOL same=YES;
    for(NSString *key in @[@"profile_id",@"type",@"video_id",@"quality"])if(![identity[key]isEqual:current[key]])same=NO;
    [self recordDetailOpenStage:@"prepare.identity" started:detailStage];detailStage=NSProcessInfo.processInfo.systemUptime;
    if(same){[self.playbackPreparation beginWithIdentity:identity candidates:@[] pinned:[NSSet setWithArray:s.state[@"keptDownloads"]?:@[]]];return;}
    if(!self.playbackPreparation){self.playbackPreparation=[RWPlaybackPreparation new];__weak RewindController *weak=self;
        self.playbackPreparation.allowsPayload=^BOOL{return weak&&[weak.page isEqual:@"Details"]&&!weak.presentedViewController&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive&&!weak.preview.usingVideoNetwork;};
    }
    [self recordDetailOpenStage:@"prepare.coordinator" started:detailStage];detailStage=NSProcessInfo.processInfo.systemUptime;
    NSArray *cached=[RWSourcePolicy sources:[s withSourceExperience:[s cachedStreams:meta videoID:videoID]] withMeta:meta videoID:videoID];
    [self recordDetailOpenStage:@"prepare.cached_sources" started:detailStage];detailStage=NSProcessInfo.processInfo.systemUptime;
    cached=[RWSourcePolicy rank:cached quality:s.quality freeBytes:0];
    [self recordDetailOpenStage:@"prepare.rank_sources" started:detailStage];detailStage=NSProcessInfo.processInfo.systemUptime;
    BOOL fresh=[self.playbackPreparation beginWithIdentity:identity candidates:cached pinned:[NSSet setWithArray:s.state[@"keptDownloads"]?:@[]]];
    [self recordDetailOpenStage:@"prepare.begin" started:detailStage];detailStage=NSProcessInfo.processInfo.systemUptime;
    if(!fresh)return;
    __weak RewindController *weak=self;NSDictionary *requestedMeta=meta;
    [s streams:meta videoID:videoID done:^(id sources,NSString *error){
        if(![identity[@"profile_id"]isEqual:s.state[@"activeProfile"]]||![s allowed:requestedMeta])return;
        NSArray *ranked=[RWSourcePolicy rank:[RWSourcePolicy sources:[s withSourceExperience:sources?:@[]] withMeta:requestedMeta videoID:identity[@"video_id"]] quality:[identity[@"quality"]integerValue] freeBytes:0];
        [weak.playbackPreparation appendCandidates:ranked identity:identity];
    }];
    [self recordDetailOpenStage:@"prepare.request_sources" started:detailStage];
}

- (void)preparationSourcesUpdated:(NSNotification *)note {
    NSDictionary *identity=self.playbackPreparation.diagnostics[@"identity"];RewindStore *s=[RewindStore shared];
    if(![self.page isEqual:@"Details"]||![identity[@"video_id"]isEqual:note.userInfo[@"videoID"]]||![identity[@"profile_id"]isEqual:note.userInfo[@"profile"]]||![identity[@"type"]isEqual:note.userInfo[@"type"]]||![s allowed:self.detail])return;
    NSDictionary *meta=self.detail;
    if([meta[@"type"]isEqual:@"series"])for(NSDictionary *episode in [RWTVPolicy episodes:meta])if([episode[@"id"]isEqual:identity[@"video_id"]]){meta=[RWTVPolicy episodeMeta:episode show:meta];break;}
    NSArray *ranked=[RWSourcePolicy rank:[RWSourcePolicy sources:[s withSourceExperience:note.userInfo[@"sources"]?:@[]] withMeta:meta videoID:identity[@"video_id"]] quality:[identity[@"quality"]integerValue] freeBytes:0];
    [self.playbackPreparation appendCandidates:ranked identity:identity];
}
