// Positive Home acceptance using an owned generated download, verified by the
// production torrent engine. No fabricated readiness or real-profile edits.
- (BOOL)exerciseFeaturedButton:(NSString *)title {
    NSMutableArray *views=[NSMutableArray arrayWithObject:self.homeView.tableHeaderView?:[UIView new]];
    while(views.count){UIView *view=views.lastObject;[views removeLastObject];
        if([view isKindOfClass:RWButton.class]&&[[(RWButton *)view currentTitle]isEqual:title]){[(RWButton *)view sendActionsForControlEvents:UIControlEventTouchUpInside];return YES;}
        [views addObjectsFromArray:view.subviews];
    }return NO;
}
- (BOOL)exerciseFeaturedStep:(NSString *)kind {
    RewindStore *s=RewindStore.shared;NSString *video=@"rw:offline-check";
    if(![self.exerciseRequest[@"action"]isEqual:@"featured-ready"]||!self.exerciseResumeOwned||![s.state[@"activeProfile"]isEqual:@"rw-device-resume-check"]||![RWDeviceExercise ownsResumeProfile:s.profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]])return NO;
    NSDictionary *player=[self.exercisePlayer deviceExerciseSnapshot];double now=NSProcessInfo.processInfo.systemUptime;
    NSMutableDictionary *report=[self.exerciseDownloadReport mutableCopy]?:[NSMutableDictionary new];
    if([kind isEqual:@"featured-buffer-stop"]){
        if(![player[@"torrent"][@"video_complete"]boolValue])return NO;
        if([player[@"native_seek"][@"buffered_ahead"]doubleValue]<5){if(now-self.exercisePlaybackStarted>35)return NO;self.exerciseIndex--;return YES;}
        report[@"buffer_before"]=player;self.exerciseDownloadReport=report;self.exercisePlaybackStarted=now;
        return [self.exercisePlayer deviceExerciseControl:@"fixture-native-buffer-stop"];
    }
    if([kind isEqual:@"featured-buffer-await"]){
        NSDictionary *before=report[@"buffer_before"];
        BOOL advanced=[player[@"position"]doubleValue]>[before[@"position"]doubleValue]+2;
        BOOL requested=[player[@"native_seek"][@"buffer_resume_requests"]unsignedIntegerValue]>[before[@"native_seek"][@"buffer_resume_requests"]unsignedIntegerValue];
        if(!advanced||!requested){if(now-self.exercisePlaybackStarted>12)return NO;self.exerciseIndex--;return YES;}
        report[@"buffer_recovered"]=player;self.exerciseDownloadReport=report;return [player[@"wants_play"]boolValue]&&[player[@"native_seek"][@"rate"]doubleValue]>0;
    }
    if([kind isEqual:@"featured-pause-audit"]){
        report[@"paused"]=player;self.exerciseDownloadReport=report;
        return ![player[@"wants_play"]boolValue]&&[player[@"native_seek"][@"rate"]doubleValue]==0&&fabs([player[@"position"]doubleValue]-self.exercisePausedPosition)<.3;
    }
    if([kind isEqual:@"featured-prepare"]){
        NSDictionary *old=[s record:video];if(self.presentedViewController||![player[@"closing"]boolValue]||![old[@"source"][@"offlineCertificate"]count]||![s.state[@"keptDownloads"]containsObject:old[@"source"][@"infoHash"]])return NO;
        // Model an unwatched saved download ONLY in this owned profile. Keep
        // its real certificate and measured watch seconds; never write a fake
        // source observation or rating to make it eligible.
        NSMutableDictionary *record=[old mutableCopy],*meta=[old[@"meta"]mutableCopy];
        meta[@"name"]=@"Colour and sound";meta[@"description"]=@"A short film of moving colours and musical tones.";meta[@"runtime"]=@"1 min";
        record[@"meta"]=meta;record[@"position"]=@0;record[@"completed"]=@NO;s.profile[@"history"][video]=record;
        NSMutableDictionary *prefs=[s.profile[@"discoveryPreferences"]mutableCopy];prefs[@"languageMode"]=@"all";prefs[@"excludeBollywood"]=@NO;s.profile[@"discoveryPreferences"]=prefs;
        if(![s isSaved:meta])[s toggleSaved:meta];[s save];
        report[@"unwatched_record"]=record;report[@"ranking_requested_at"]=@(NSDate.date.timeIntervalSince1970);self.exerciseDownloadReport=report;self.exercisePlaybackStarted=now;
        [self go:@"Search"];[s invalidateOfflineEvidence];[s setDiscoveryPaused:NO];[s refreshDiscovery];return YES;
    }
    if([kind isEqual:@"featured-await-ranking"]){
        NSDictionary *hero=s.discoveryHome[@"hero"];
        NSDictionary *availability=hero.count?[s availability:hero]:@{};
        report[@"ranking_observation"]=@{@"computed_at":s.discoveryHome[@"computedAt"]?:@0,@"hero_id":RWID(hero),@"availability":availability};self.exerciseDownloadReport=report;
        if(now-self.exercisePlaybackStarted>35)return NO;
        if([s.discoveryHome[@"computedAt"]doubleValue]<[report[@"ranking_requested_at"]doubleValue]||![RWID(hero)isEqual:video]||![availability[@"state"]isEqual:@"offline"]){self.exerciseIndex--;return YES;}
        report[@"ranked_hero"]=hero;self.exerciseDownloadReport=report;self.exercisePlaybackStarted=now;return YES;
    }
    if([kind isEqual:@"featured-await-home"]){
        if(now-self.exercisePlaybackStarted>25)return NO;
        if(![self.page isEqual:@"Home"]||![RWID(self.homeHeaderRecord[@"hero"])isEqual:video]||!self.homeView.tableHeaderView.window){self.exerciseIndex--;return YES;}return YES;
    }
    if([kind isEqual:@"featured-audit"]){
        NSDictionary *snapshot=[self exerciseAvailabilitySnapshot],*hero=snapshot[@"hero"];
        report[@"home"]=snapshot;self.exerciseDownloadReport=report;
        if(![hero[@"id"]isEqual:video]||![hero[@"availability"][@"hero_eligible"]boolValue]||![hero[@"availability"][@"state"]isEqual:@"offline"])return NO;
        for(NSDictionary *row in snapshot[@"rows"])for(NSDictionary *card in row[@"cards"])if([card[@"id"]isEqual:video])return NO;
        return [self exerciseCastCapture:@"device-exercise-featured-ready"];
    }
    if([kind isEqual:@"featured-details"])return [self exerciseFeaturedButton:@"Details"]&&[self.page isEqual:@"Details"]&&[RWID(self.detail)isEqual:video];
    if([kind isEqual:@"featured-back"]){self.exercisePlaybackStarted=now;return [self exerciseContentBack]&&[self.page isEqual:@"Home"];}
    if([kind isEqual:@"featured-play"]){self.exercisePlaybackStarted=now;return [self exerciseFeaturedButton:@"Play"]&&self.presentedViewController==self.exercisePlayer&&![[self.exercisePlayer deviceExerciseSnapshot][@"closing"]boolValue];}
    if([kind isEqual:@"featured-play-audit"]){report[@"hero_player"]=player;self.exerciseDownloadReport=report;return [player[@"video_id"]isEqual:video]&&[player[@"media_verified"]boolValue]&&[player[@"frame_visible"]boolValue]&&[player[@"position"]doubleValue]>=6&&[player[@"torrent"][@"video_complete"]boolValue]&&[player[@"torrent"][@"peer_payload_bytes"]longLongValue]==0;}
    return NO;
}
