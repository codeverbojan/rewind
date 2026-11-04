// Real decoder/end/button/dismiss/present/persistence path, with generated CC0
// clips in the strictly owned profile. No commercial episode download or seeded
// watch progress is used as a substitute for playback.
- (BOOL)exerciseHandoffStep:(NSString *)kind {
    RewindStore *store=[RewindStore shared];NSString *first=@"rw:handoff:1:24",*second=@"rw:handoff:2:1";
    if(!self.exerciseResumeOwned||![store.state[@"activeProfile"]isEqual:@"rw-device-resume-check"]||![RWDeviceExercise ownsResumeProfile:store.profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]])return NO;
    if([kind isEqual:@"handoff-play"]){
        if(self.presentedViewController)return NO;
        self.exerciseEpisodeShow=@{@"id":@"rw:handoff",@"name":@"Episode playback check",@"type":@"series",@"videos":@[
            @{@"id":first,@"season":@1,@"episode":@24,@"released":@"2000-01-01",@"title":@"Season finale"},
            @{@"id":second,@"season":@2,@"episode":@1,@"released":@"2001-01-01",@"title":@"Next season"}]};
        store.profile[@"sources"][first]=@{@"name":@"Generated CC0 test clip",@"url":@"asset:subtitle-check.mp4"};
        store.profile[@"sources"][second]=@{@"name":@"Generated CC0 test clip",@"url":@"asset:subtitle-check.mkv"};
        NSDictionary *meta=[RWTVPolicy episodeMeta:self.exerciseEpisodeShow[@"videos"][0] show:self.exerciseEpisodeShow];
        [self chooseSources:meta videoID:first restart:YES];self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;
        return self.exercisePlayer!=nil&&![[self.exercisePlayer deviceExerciseSnapshot][@"transient"]boolValue];
    }
    NSDictionary *state=[self.exercisePlayer deviceExerciseSnapshot];
    if([kind isEqual:@"handoff-await-end"]){
        if([state[@"exhausted"]boolValue]||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>100)return NO;
        if(![state[@"ended"]boolValue]){self.exerciseIndex--;return YES;}
        NSDictionary *record=[store record:first];
        BOOL ok=[state[@"video_id"]isEqual:first]&&[record[@"completed"]boolValue]&&[record[@"position"]doubleValue]>55&&[state[@"next_episode_visible"]boolValue]&&[state[@"next_episode_label"]isEqual:@"Next · S02 E01"];
        self.exerciseEpisodeReport=@{@"first_ended":state,@"first_record":record?:@{}};
        RWCapture(self.exercisePlayer.view,@"device-exercise-handoff-ended");return ok;
    }
    if([kind isEqual:@"handoff-next"]){self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;RewindPlayer *previous=self.exercisePlayer;BOOL ok=[previous deviceExerciseControl:@"next-episode"];NSMutableDictionary *report=[self.exerciseEpisodeReport mutableCopy];report[@"old_after_next"]=[previous deviceExerciseSnapshot];self.exerciseEpisodeReport=report;return ok;}
    if([kind isEqual:@"handoff-await-next"]){
        if([state[@"exhausted"]boolValue]||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>40)return NO;
        if(![state[@"video_id"]isEqual:second]||![state[@"media_verified"]boolValue]||![state[@"frame_visible"]boolValue]||[state[@"position"]doubleValue]<6){self.exerciseIndex--;return YES;}
        NSMutableDictionary *report=[self.exerciseEpisodeReport mutableCopy];report[@"handoff_seconds"]=@(NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted);report[@"second_playing"]=state;self.exerciseEpisodeReport=report;return YES;
    }
    if([kind isEqual:@"handoff-audit"]){
        BOOL ok=[state[@"video_id"]isEqual:second]&&![state[@"transient"]boolValue]&&![state[@"wants_play"]boolValue]&&![state[@"next_episode_visible"]boolValue]&&![state[@"next_episode_label"]length]&&[state[@"position"]doubleValue]>5&&[[store record:first][@"completed"]boolValue];
        RWCapture(self.exercisePlayer.view,@"device-exercise-handoff-second");return ok;
    }
    if([kind isEqual:@"handoff-record"]){
        NSDictionary *record=[store record:second];NSMutableDictionary *report=[self.exerciseEpisodeReport mutableCopy];report[@"second_record"]=record?:@{};report[@"first_record_after"]= [store record:first]?:@{};self.exerciseEpisodeReport=report;
        return [state[@"closing"]boolValue]&&[record[@"position"]doubleValue]>7&&![record[@"completed"]boolValue]&&[[store record:first][@"completed"]boolValue];
    }
    return NO;
}
