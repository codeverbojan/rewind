// Actual production torrent/legacy player, armed only by a bounded USB recipe.
// The host owns the private loopback seed and its fixed eight-second interruption.
- (void)reportRecoveryPhase:(NSString *)phase player:(NSDictionary *)player {
    double now=NSProcessInfo.processInfo.systemUptime;
    if(![self.exerciseRecoveryReport[@"phase"]isEqual:phase])self.exerciseRecoveryReport[@"phase_started"]=@(now);
    self.exerciseRecoveryReport[@"phase"]=phase;self.exerciseRecoveryReport[@"at"]=@(now);
    NSDictionary *legacy=player[@"embedded_metrics"]?:@{};
    self.exerciseRecoveryReport[@"player"]=@{@"position":player[@"position"]?:@0,@"backend":player[@"backend"]?:@"",@"read_wait_ms":legacy[@"read_wait_ms"]?:@0,@"read_bytes":legacy[@"read_bytes"]?:@0,@"displayed_frames":legacy[@"displayed_frames"]?:@0,@"seeks":legacy[@"seeks"]?:@0};
    [[RewindStore shared]report:@{@"recovery_check":[self.exerciseRecoveryReport copy]}];
}
- (BOOL)exerciseRecoveryStep:(NSString *)kind {
    if(![self.exerciseRequest[@"action"]isEqual:@"playback-controlled-mkv"]||RewindStore.shared.restricted)return NO;
    NSFileManager *fm=NSFileManager.defaultManager;NSString *hash=[RWDeviceExercise recoverySource][@"infoHash"];
    NSString *folder=[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"];
    NSString *ownerPath=[folder stringByAppendingPathComponent:@"recovery-owner.plist"];
    NSString *metadata=[[RWDocuments()stringByAppendingPathComponent:@"TorrentMetadata"]stringByAppendingPathComponent:[hash stringByAppendingPathExtension:@"torrent"]];
    NSString *cache=[[RWDocuments()stringByAppendingPathComponent:@"Torrents"]stringByAppendingPathComponent:hash];
    NSDictionary *owner=@{@"run":self.exerciseRequest[@"run"],@"build":NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"],@"info_hash":hash};
    NSData *bundled=[NSData dataWithContentsOfFile:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Rewind/recovery-275.torrent"]];
    double now=NSProcessInfo.processInfo.systemUptime;
    if([kind isEqual:@"recovery-prepare"]){
        if(self.presentedViewController||bundled.length!=1517||[fm attributesOfItemAtPath:ownerPath error:nil]||[fm attributesOfItemAtPath:metadata error:nil]||[fm attributesOfItemAtPath:cache error:nil])return NO;
        [fm createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
        [fm createDirectoryAtPath:metadata.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        if(![owner writeToFile:ownerPath atomically:YES]||![bundled writeToFile:metadata atomically:YES])return NO;
        self.exerciseRecoveryReport=[@{@"run":self.exerciseRequest[@"run"],@"info_hash":hash,@"started":@(now),@"cold_cache":@YES}mutableCopy];
        [self reportRecoveryPhase:@"prepared" player:nil];return YES;
    }
    if(![[NSDictionary dictionaryWithContentsOfFile:ownerPath]isEqual:owner]&&![self.exerciseRecoveryReport[@"cleanup"]boolValue])return NO;
    if([kind isEqual:@"recovery-play"]){
        if(self.presentedViewController||![[NSData dataWithContentsOfFile:metadata]isEqual:bundled])return NO;
        [self stopPreview];[self.playbackPreparation cancel];[RewindStore.shared setDiscoveryPaused:YES];
        NSDictionary *meta=@{@"id":@"rw:recovery-mkv",@"type":@"movie",@"name":@"MKV recovery check"};
        RewindPlayer *player=[[RewindPlayer alloc]initWithMeta:meta videoID:@"rw:recovery-mkv:preview" source:[RWDeviceExercise recoverySource] resume:0];
        if(![player beginRecoveryExercise])return NO;self.exercisePlayer=player;
        __weak RewindController *weak=self;player.onClose=^{[weak syncDiscoveryActivity];[weak render];};
        self.exercisePlaybackStarted=now;[self presentViewController:player animated:YES completion:nil];[self reportRecoveryPhase:@"starting" player:nil];return YES;
    }
    NSDictionary *state=[self.exercisePlayer deviceExerciseSnapshot]?:@{};NSDictionary *legacy=state[@"embedded_metrics"]?:@{};
    if([kind isEqual:@"recovery-dismissed"]){
        if(![state[@"closing"]boolValue]||now-[self.exerciseRecoveryReport[@"close_started"]doubleValue]>8)return NO;
        if(self.presentedViewController){self.exerciseIndex--;return YES;}
        self.exercisePlayer=nil;[self reportRecoveryPhase:@"closed" player:state];return YES;
    }
    if([kind isEqual:@"recovery-cleanup"]){
        if(self.presentedViewController||self.exercisePlayer)return NO;
        self.exerciseRecoveryReport[@"cleanup_pending"]=@YES;self.exerciseRecoveryReport[@"cleanup_started"]=@(now);
        __weak RewindController *weak=self;NSString *run=self.exerciseRequest[@"run"];
        [TorrentEngine removeDownload:hash done:^(BOOL removed){
            if(![weak.exerciseRequest[@"run"]isEqual:run]||![[NSDictionary dictionaryWithContentsOfFile:ownerPath]isEqual:owner])return;
            BOOL gone=![fm attributesOfItemAtPath:cache error:nil];
            BOOL ownedMetadata=[[NSData dataWithContentsOfFile:metadata]isEqual:bundled];
            BOOL ok=(removed||gone)&&ownedMetadata&&[fm removeItemAtPath:metadata error:nil];
            if(ok)ok=[fm removeItemAtPath:ownerPath error:nil];
            weak.exerciseRecoveryReport[@"cleanup"]=@(ok);weak.exerciseRecoveryReport[@"cleanup_pending"]=@NO;
            [weak reportRecoveryPhase:ok?@"cleaned":@"cleanup_failed" player:nil];
        }];return YES;
    }
    if([kind isEqual:@"recovery-cleanup-await"]){
        if([self.exerciseRecoveryReport[@"cleanup_pending"]boolValue]){if(now-[self.exerciseRecoveryReport[@"cleanup_started"]doubleValue]>8)return NO;self.exerciseIndex--;return YES;}
        return [self.exerciseRecoveryReport[@"cleanup"]boolValue];
    }
    if(![state[@"transient"]boolValue]||[state[@"closing"]boolValue]||[state[@"exhausted"]boolValue])return NO;
    if([kind isEqual:@"recovery-initial"]){
        if(now-self.exercisePlaybackStarted>45)return NO;
        if(![state[@"media_verified"]boolValue]||![state[@"frame_visible"]boolValue]||[state[@"position"]doubleValue]<5){self.exerciseIndex--;return YES;}
        if(![state[@"backend"]isEqual:@"mkv"]||[legacy[@"read_bytes"]longLongValue]<=0)return NO;
        self.exerciseRecoveryReport[@"initial_frames"]=legacy[@"displayed_frames"]?:@0;
        [self reportRecoveryPhase:@"initial_ready" player:state];return YES;
    }
    if([kind isEqual:@"recovery-caption-observe"])return [self.exercisePlayer deviceExerciseControl:kind];
    if([kind isEqual:@"recovery-caption-pending"]){
        self.exerciseRecoveryReport[@"caption_requested_position"]=state[@"position"];
        return ![state[@"subtitle_cues"]unsignedIntegerValue]&&![state[@"subtitle_text"]length]&&[state[@"wants_play"]boolValue];
    }
    if([kind isEqual:@"recovery-arm-outage"]){[self reportRecoveryPhase:@"ready_for_outage" player:state];return YES;}
    if([kind isEqual:@"recovery-clock-audit"]){
        NSDictionary *clock=legacy[@"caption_clock"];
        if(![clock[@"coherent"]boolValue]||[clock[@"buffering"]boolValue]||![state[@"subtitle_refresh_active"]boolValue])return NO;
        BOOL ok=[self.exercisePlayer deviceExerciseControl:kind];if(ok)RWCapture(self.exercisePlayer.view,@"device-exercise-recovery-recovered");return ok;
    }
    if([kind isEqual:@"recovery-caption-off"])return [self.exercisePlayer deviceExerciseControl:@"subtitle-choice:Off"];
    if([kind isEqual:@"recovery-caption-off-audit"])return ![state[@"subtitle_refresh_active"]boolValue]&&![state[@"subtitle_text"]length]&&[state[@"subtitle_layout"][@"hidden"]boolValue];
    if([kind isEqual:@"recovery-gate"]){
        if(now-[self.exerciseRecoveryReport[@"phase_started"]doubleValue]>20)return NO;
        NSString *path=[folder stringByAppendingPathComponent:@"recovery-control.json"];
        NSDictionary *attrs=[fm attributesOfItemAtPath:path error:nil];NSData *bytes=attrs&&[attrs fileSize]<=1024?[NSData dataWithContentsOfFile:path]:nil;
        id gate=bytes?[NSJSONSerialization JSONObjectWithData:bytes options:0 error:nil]:nil;
        if(![gate isKindOfClass:NSDictionary.class]||![gate[@"run"]isEqual:self.exerciseRequest[@"run"]]||![gate[@"phase"]isEqual:@"outage"]){self.exerciseIndex--;return YES;}
        [fm removeItemAtPath:path error:nil];return YES;
    }
    if([kind isEqual:@"recovery-seek-far"]){
        self.exerciseRecoveryReport[@"seek_started"]=@(now);
        BOOL ok=[self.exercisePlayer deviceExerciseControl:@"recovery-seek:150"];
        [self reportRecoveryPhase:@"waiting_for_missing_data" player:state];return ok;
    }
    if([kind isEqual:@"recovery-blocked"]){
        if(now-[self.exerciseRecoveryReport[@"seek_started"]doubleValue]>12)return NO;
        if([legacy[@"read_wait_ms"]integerValue]<1000){self.exerciseIndex--;return YES;}
        self.exerciseRecoveryReport[@"blocked_read_wait_ms"]=legacy[@"read_wait_ms"];
        RWCapture(self.exercisePlayer.view,@"device-exercise-recovery-blocked");
        [self reportRecoveryPhase:@"blocked" player:state];return YES;
    }
    if([kind isEqual:@"recovery-recovered"]){
        if(now-[self.exerciseRecoveryReport[@"seek_started"]doubleValue]>45)return NO;
        BOOL recovered=[state[@"position"]doubleValue]>=153&&[state[@"frame_visible"]boolValue]&&[legacy[@"read_wait_ms"]integerValue]==0&&[legacy[@"displayed_frames"]integerValue]>[self.exerciseRecoveryReport[@"initial_frames"]integerValue]+10;
        if(!recovered){self.exerciseIndex--;return YES;}
        self.exerciseRecoveryReport[@"recovery_seconds"]=@(now-[self.exerciseRecoveryReport[@"seek_started"]doubleValue]);[self reportRecoveryPhase:@"recovered" player:state];return YES;
    }
    if([kind isEqual:@"recovery-pause"])return [self.exercisePlayer deviceExerciseControl:@"pause"];
    if([kind isEqual:@"recovery-seek-back"]){self.exerciseRecoveryReport[@"back_started"]=@(now);self.exerciseRecoveryReport[@"back_frames"]=legacy[@"displayed_frames"]?:@0;return [self.exercisePlayer deviceExerciseControl:@"recovery-seek:30"];}
    if([kind isEqual:@"recovery-paused-ready"]){
        if(now-[self.exerciseRecoveryReport[@"back_started"]doubleValue]>8||[state[@"wants_play"]boolValue])return NO;
        BOOL ready=fabs([state[@"position"]doubleValue]-30)<.05&&[state[@"subtitle_text"]isEqual:@"Recovery caption 030"]&&[legacy[@"displayed_frames"]integerValue]>[self.exerciseRecoveryReport[@"back_frames"]integerValue];
        if(!ready){self.exerciseIndex--;return YES;}
        RWCapture(self.exercisePlayer.view,@"device-exercise-recovery-paused");return YES;
    }
    if([kind isEqual:@"recovery-resume"])return [self.exercisePlayer deviceExerciseControl:@"resume"];
    if([kind isEqual:@"recovery-backward"]){
        if(now-[self.exerciseRecoveryReport[@"back_started"]doubleValue]>25)return NO;
        if([state[@"position"]doubleValue]<33||[state[@"position"]doubleValue]>55||[legacy[@"read_wait_ms"]integerValue]>0){self.exerciseIndex--;return YES;}
        self.exerciseRecoveryReport[@"caption_started"]=@(now);self.exerciseRecoveryReport[@"sustain_started"]=@(now);self.exerciseRecoveryReport[@"sustain_position"]=state[@"position"];self.exerciseRecoveryReport[@"sustain_frames"]=legacy[@"displayed_frames"];[self reportRecoveryPhase:@"backward_playing" player:state];return YES;
    }
    if([kind isEqual:@"recovery-menu"])return [self.exercisePlayer deviceExerciseControl:@"subtitle-menu"];
    if([kind isEqual:@"recovery-captions"]){self.exerciseRecoveryReport[@"caption_started"]=@(now);return [self.exercisePlayer deviceExerciseControl:@"subtitle-choice:Recovery captions"];}
    if([kind isEqual:@"recovery-caption-ready"]){
        if(now-[self.exerciseRecoveryReport[@"caption_started"]doubleValue]>10)return NO;
        if(![state[@"subtitle_decode"][@"status"]isEqual:@"ok"]||![state[@"subtitle_text"]length]||![legacy[@"caption_clock"][@"coherent"]boolValue]){self.exerciseIndex--;return YES;}
        if([state[@"subtitle_cues"]unsignedIntegerValue]!=180||![state[@"subtitle_name"]isEqual:@"Recovery captions"])return NO;
        self.exerciseRecoveryReport[@"caption_text"]=state[@"subtitle_text"];RWCapture(self.exercisePlayer.view,@"device-exercise-recovery-mkv");return YES;
    }
    if([kind isEqual:@"recovery-sustain"]){
        double elapsed=now-[self.exerciseRecoveryReport[@"sustain_started"]doubleValue];
        if(elapsed>135||![state[@"wants_play"]boolValue])return NO;
        if(elapsed<120||[state[@"position"]doubleValue]-[self.exerciseRecoveryReport[@"sustain_position"]doubleValue]<119.5){self.exerciseIndex--;return YES;}
        if([legacy[@"displayed_frames"]integerValue]-[self.exerciseRecoveryReport[@"sustain_frames"]integerValue]<2000)return NO;
        self.exerciseRecoveryReport[@"sustain_seconds"]=@(elapsed);self.exerciseRecoveryReport[@"sustain_end_position"]=state[@"position"];self.exerciseRecoveryReport[@"sustain_end_frames"]=legacy[@"displayed_frames"];return YES;
    }
    if([kind isEqual:@"recovery-close"]){self.exerciseRecoveryReport[@"close_started"]=@(now);[self reportRecoveryPhase:@"closing" player:state];return [self.exercisePlayer deviceExerciseControl:@"close"];}
    return NO;
}
