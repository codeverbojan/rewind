// Restart acceptance uses normal persistence, exclusively in an owned test
// profile. The two requests are separated by a verified process exit on Mac.
- (BOOL)exerciseResumeStep:(NSString *)kind {
    RewindStore *store=[RewindStore shared];NSString *key=@"rw-device-resume-check";
    NSString *action=self.exerciseRequest[@"action"];
    BOOL torrent=[action hasSuffix:@"-torrent"],audio=[action hasPrefix:@"audio-"];
    BOOL preferences=[action hasPrefix:@"preferences-"],reopen=[action hasPrefix:@"resume-open-"]||[action hasPrefix:@"preferences-open-"]||[action hasPrefix:@"audio-open-"],mkv=[action hasSuffix:@"-mkv"];
    NSString *videoID=audio?(mkv?@"rw:audio-mkv":@"rw:audio-native"):torrent?@"rw:resume-torrent":mkv?@"rw:resume-mkv":@"rw:resume-native";
    NSInteger build=[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue];
    if([kind isEqual:@"resume-cleanup"]){
        if(![RWDeviceExercise ownsResumeProfile:store.state[@"profiles"][key] build:build])return NO;
        self.exerciseResumeOwned=YES;return YES;
    }
    if([kind isEqual:@"resume-prepare"]){
        if(self.presentedViewController)return NO;
        NSMutableDictionary *profiles=store.state[@"profiles"];
        if(!reopen){
            if(profiles[key])return NO;
            NSMutableDictionary *profile=[RWProfiles make:@"Device resume check" age:-1];profile[@"autoplayTrailers"]=@NO;
            profile[@"sources"][@"rw:resume-owner"]=@{@"protocol":@1,@"build":@(build),@"original":store.state[@"activeProfile"],@"run":self.exerciseRequest[@"run"]};profiles[key]=profile;
        }
        if(![RWDeviceExercise ownsResumeProfile:profiles[key] build:build])return NO;
        self.exerciseResumeOwned=YES;
        NSDictionary *record=profiles[key][@"history"][videoID];
        if(reopen){
            if(!record||[record[@"completed"]boolValue]||[record[@"position"]doubleValue]<(audio?1:15)||[record[@"position"]doubleValue]>40)return NO;
            if(audio&&(![record[@"source"][@"url"]isEqual:mkv?@"asset:audio-check.mkv":@"asset:audio-check.mp4"]||[profiles[key][@"audioSelections"][videoID][@"token"]length]!=64))return NO;
        }
        self.exerciseResumeRecord=record?:@{};
        self.exerciseProfile=key;[self selectProfile:key];[store setDiscoveryPaused:YES];return YES;
    }
    if(!self.exerciseResumeOwned||![store.state[@"activeProfile"]isEqual:key]||![RWDeviceExercise ownsResumeProfile:store.profile build:build])return NO;
    if([kind isEqual:@"resume-play"]){
        if(torrent&&!store.catalogReady){if(NSProcessInfo.processInfo.systemUptime-self.exerciseStarted>20)return NO;self.exerciseIndex--;return YES;}
        if(self.presentedViewController)return NO;
        [self stopPreview];[self.playbackPreparation cancel];[store setDiscoveryPaused:YES];
        NSDictionary *meta=@{@"id":videoID,@"type":@"movie",@"name":@"Resume check"};
        NSMutableDictionary *source=[@{@"name":@"Generated CC0 test clip",@"url":mkv?@"asset:subtitle-check.mkv":@"asset:subtitle-check.mp4"}mutableCopy];
        if(torrent){
            NSDictionary *catalog=nil;for(NSDictionary *movie in store.openFilms)if([RWID(movie)isEqual:@"rw:cosmos"]){catalog=movie;break;}
            if(!catalog)return NO;source=[catalog[@"source"]mutableCopy];source[@"infoHash"]=@"c9e15763f722f23e98a29decdfae341b98d53056";
            if(![RWDeviceExercise isResumeTorrentSource:source])return NO;
            NSMutableDictionary *movie=[catalog mutableCopy];movie[@"id"]=videoID;[movie removeObjectForKey:@"subtitles"];meta=movie;
            if(reopen){if(![RWDeviceExercise isResumeTorrentSource:self.exerciseResumeRecord[@"source"]])return NO;source=[self.exerciseResumeRecord[@"source"]mutableCopy];}
        }
        if(preferences&&[action rangeOfString:@"-link-"].location==NSNotFound)source[@"subtitles"]=@[@{@"name":@"English · Text file",@"lang":@"en",@"url":@"asset:subtitle-check.en.srt"}];
        if(reopen&&![self.exerciseResumeRecord[@"source"][@"url"]isEqual:source[@"url"]])return NO;
        double position=reopen?[self.exerciseResumeRecord[@"position"]doubleValue]:0;
        RewindPlayer *player=[[RewindPlayer alloc]initWithMeta:meta videoID:videoID source:source resume:position];
        if(![player beginResumeExercise])return NO;self.exercisePlayer=player;
        __weak RewindController *weak=self;player.onClose=^{[weak syncDiscoveryActivity];[weak render];};self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;
        [self presentViewController:player animated:YES completion:nil];return YES;
    }
    NSDictionary *state=[self.exercisePlayer deviceExerciseSnapshot];
    if([kind isEqual:@"resume-await"]){
        if([state[@"exhausted"]boolValue]||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>(torrent?145:40))return NO;
        double target=reopen?[self.exerciseResumeRecord[@"position"]doubleValue]+3:18;
        if(![state[@"media_verified"]boolValue]||![state[@"frame_visible"]boolValue]||[state[@"position"]doubleValue]<target)self.exerciseIndex--;return YES;
    }
    NSDictionary *record=[store record:videoID];
    if([kind isEqual:@"resume-audit"]){
        double position=[state[@"position"]doubleValue];
        BOOL ok=![state[@"transient"]boolValue]&&[state[@"persistence_profile"]isEqual:key]&&[state[@"resumed"]boolValue]&&![state[@"wants_play"]boolValue]&&[state[@"media_verified"]boolValue]&&[state[@"frame_visible"]boolValue]&&fabs([record[@"position"]doubleValue]-position)<.4&&![record[@"completed"]boolValue];
        if(torrent)ok=ok&&[state[@"torrent"][@"metadata"]boolValue]&&[state[@"torrent"][@"video_verified_bytes"]longLongValue]>0;
        if(reopen)ok=ok&&fabs([state[@"requested_position"]doubleValue]-[self.exerciseResumeRecord[@"position"]doubleValue])<.01&&position>=[state[@"requested_position"]doubleValue]+2;
        RWCapture(self.exercisePlayer.view,[NSString stringWithFormat:@"device-exercise-%@",action]);return ok;
    }
    if([kind isEqual:@"resume-record"]){
        BOOL ok=[state[@"closing"]boolValue]&&[record[@"position"]doubleValue]>=20&&[record[@"position"]doubleValue]<45&&![record[@"completed"]boolValue];self.exerciseResumeRecord=record;return ok;
    }
    return NO;
}
- (void)finishResumeExercise:(NSString *)status {
    if(!self.exerciseResumeOwned)return;
    RewindStore *store=[RewindStore shared];NSString *key=@"rw-device-resume-check";NSDictionary *profile=store.state[@"profiles"][key];
    if(![RWDeviceExercise ownsResumeProfile:profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]])return;
    NSString *original=profile[@"sources"][@"rw:resume-owner"][@"original"];
    BOOL companion=[RWDeviceExercise ownsAudioCompanion:store.state[@"profiles"][@"rw-device-audio-other"] parent:profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]];
    if(([store.state[@"activeProfile"]isEqual:key]||(companion&&[store.state[@"activeProfile"]isEqual:@"rw-device-audio-other"]))&&store.state[@"profiles"][original]){self.exerciseProfile=original;[self selectProfile:original];}
    if(companion&&![store.state[@"activeProfile"]isEqual:@"rw-device-audio-other"])[store.state[@"profiles"]removeObjectForKey:@"rw-device-audio-other"];
    BOOL keep=[status isEqual:@"complete"]&&([self.exerciseRequest[@"action"]hasPrefix:@"resume-save-"]||[self.exerciseRequest[@"action"]hasPrefix:@"preferences-save-"]||[self.exerciseRequest[@"action"]hasPrefix:@"audio-save-"]||[self.exerciseRequest[@"action"]isEqual:@"notification-schedule"]||([self.exerciseRequest[@"action"]containsString:@"-revision-"]&&![self.exerciseRequest[@"action"]containsString:@"-profiles-"]));
    if(!keep&&![store.state[@"activeProfile"]isEqual:key])[store.state[@"profiles"]removeObjectForKey:key];
    [store save];self.exerciseResumeOwned=NO;
}
