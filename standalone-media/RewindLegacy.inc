- (double)playbackPosition{return self.legacy?(self.legacy.ended?self.legacy.duration:self.legacy.position):CMTimeGetSeconds(self.player.currentTime);}
- (double)playbackDuration{return self.legacy?self.legacy.duration:CMTimeGetSeconds(self.player.currentItem.duration);}
- (float)playbackRate{return self.legacy?self.legacy.rate:self.player.rate;}
- (BOOL)frameVisible{return self.legacy?self.legacy.frameVisible:self.video.readyForDisplay;}
- (void)playMedia{if(self.legacy)[self.legacy play];else[self.player play];}
- (void)pauseMedia{if(self.legacy)[self.legacy pause];else[self.player pause];}
- (void)prepareLegacy:(NSString *)file {
    if(self.legacy)return;
    [self.metrics markStage:@"player_preparing" uptime:NSProcessInfo.processInfo.systemUptime];
    [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayback error:nil];[[AVAudioSession sharedInstance]setActive:YES error:nil];
    self.legacy=[[RWLegacyPlayer alloc]initWithEngine:file?nil:self.engine size:[self.lastTorrentSnapshot[@"video_total_bytes"]longLongValue] file:file quality:self.quality diagnosticFont:self.deviceExerciseEnabled?self.exerciseLegacyFont:nil];
    self.legacy.audioPreference=[self audioPreference];
    self.legacy.startupTraceEnabled=self.deviceExerciseEnabled&&(self.transient||[self.exercisePersistenceProfile isEqual:@"rw-device-resume-check"]);
    __weak RewindPlayer *owner=self;__weak RWLegacyPlayer *backend=self.legacy;
    self.legacy.audioChoiceConfirmed=^(NSDictionary *track){if(owner.legacy!=backend||owner.closing)return;[owner rememberAudioChoice:track];};
    self.legacy.subtitleTraceEnabled=self.deviceExerciseEnabled&&((self.transient&&[@[@"rw:subtitle-mkv:preview",@"rw:font-captions:preview"]containsObject:self.videoID])||(!self.transient&&[self.exercisePersistenceProfile isEqual:@"rw-device-resume-check"]&&[self.videoID isEqual:@"rw:resume-mkv"]&&[self.source[@"url"]isEqual:@"asset:subtitle-check.mkv"]));
    self.legacy.surface.frame=self.view.bounds;[self.view insertSubview:self.legacy.surface belowSubview:self.loadingArt];
    [self.legacy poll];
}
- (void)pollLegacy {
    if(!self.legacy)return;[self.legacy poll];
    if(self.legacy.error){[[RewindStore shared]report:@{@"legacy_error":self.legacy.error,@"legacy_probe":self.legacy.probe?:@{},@"media_assessment":self.legacy.mediaRejectionAssessment?:@{}}];[self failSource:self.legacy.error assessment:self.legacy.mediaRejectionAssessment];return;}
    if(self.legacy.ready&&!self.mediaVerified){
        [self.metrics markStage:@"media_ready" uptime:NSProcessInfo.processInfo.systemUptime];
        self.mediaVerified=YES;self.lastProgress=NSProcessInfo.processInfo.systemUptime;
        NSMutableDictionary *source=[self.source mutableCopy];source[@"verifiedWidth"]=self.legacy.probe[@"width"];source[@"verifiedHeight"]=self.legacy.probe[@"height"];self.source=source;
        NSInteger q=[RWSourcePolicy resolutionForWidth:[source[@"verifiedWidth"]integerValue] height:[source[@"verifiedHeight"]integerValue]];
        [self.qualityButton setTitle:[NSString stringWithFormat:@"%ldp",(long)q] forState:UIControlStateNormal];
        [[RewindStore shared]report:@{@"legacy_probe":self.legacy.probe,@"player_ready":@YES,@"actual_quality":@(q)}];
    }
    if(self.legacy.ready&&self.legacy.duration>0&&self.legacy.seekable&&!self.resumed){self.resumed=YES;double start=self.resumePosition>0&&self.resumePosition<self.legacy.duration-10?self.resumePosition:0;[self.metrics setExpectedStartPosition:start];if(start>0)[self.legacy seek:start];if(!self.wantsPlay)[self.legacy pause];}
    self.audioSelection=self.legacy.audioSelection;
    NSDictionary *stats=[self.legacy metrics];
    if([self.videoID isEqual:@"rw:mkv-check:preview"]&&[stats[@"displayed_frames"]intValue]>30&&[stats[@"played_audio_buffers"]intValue]>5){
        [RWSourcePolicy setLegacyEnabled:YES];[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"RWLegacyQualified373"];
        [[RewindStore shared]report:@{@"legacy_local_test_passed":@YES,@"legacy_local_test_metrics":stats}];
    }
    if(self.legacy.ended&&self.wantsPlay)[self ended];
}
- (void)legacyTrackMenu:(BOOL)audio {
    if(!audio){[self chooseSubtitles];return;}
    self.lastInteraction=NSDate.date.timeIntervalSince1970;self.controls.alpha=1;
    NSArray *tracks=self.legacy.audioTracks;__weak RewindPlayer *weak=self;
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Audio" message:tracks.count?([self.legacy.audioSelection[@"message"]length]?self.legacy.audioSelection[@"message"]:nil):@"No alternate compatible tracks in this source" preferredStyle:UIAlertControllerStyleActionSheet];
    for(NSDictionary *track in tracks){NSString *label=[track[@"label"]stringByAppendingString:[track[@"runtime_id"]intValue]==self.legacy.selectedAudio?@" · Selected":@""];
        void(^action)(void)=^{[weak.legacy selectAudio:[track[@"runtime_id"]intValue]];};
        if(self.deviceExerciseEnabled)self.exerciseAudioActions[label]=[action copy];
        [a addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){action();}]];}
    [a addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=self.audioButton;a.popoverPresentationController.sourceRect=self.audioButton.bounds;[self presentViewController:a animated:YES completion:nil];
}
