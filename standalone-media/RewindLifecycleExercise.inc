// Six alternating torrent-backed player cycles, one app process. Cache is kept
// between cycles under the normal policy; only this UUID's two fixtures removed.
- (NSDictionary *)lifecycleCacheInventory {
    NSMutableDictionary *out=[NSMutableDictionary new];NSFileManager *fm=NSFileManager.defaultManager;
    for(NSString *backend in @[@"native",@"mkv"]){
        NSString *hash=[RWDeviceExercise lifecycleSource:backend][@"infoHash"],*root=[[RWDocuments()stringByAppendingPathComponent:@"Torrents"]stringByAppendingPathComponent:hash];
        uint64_t logical=0,allocated=0;NSUInteger count=0;
        NSDirectoryEnumerator *walk=[fm enumeratorAtPath:root];NSString *name=nil;
        while((name=[walk nextObject])){if(++count>32||name.pathComponents.count>4)return nil;struct stat st;if(lstat([root stringByAppendingPathComponent:name].fileSystemRepresentation,&st)!=0||S_ISLNK(st.st_mode)||(!S_ISDIR(st.st_mode)&&!S_ISREG(st.st_mode)))return nil;
            if(S_ISREG(st.st_mode)){logical+=st.st_size;allocated+=(uint64_t)st.st_blocks*512;}}
        out[backend]=@{@"logical_bytes":@(logical),@"allocated_bytes":@(allocated),@"entries":@(count)};
    }return out;
}
- (void)reportLifecyclePhase:(NSString *)phase {
    self.exerciseLifecycleReport[@"phase"]=phase;self.exerciseLifecycleReport[@"at"]=@(NSProcessInfo.processInfo.systemUptime);
    [[RewindStore shared]report:@{@"lifecycle_check":[RWSourceWork snapshot:self.exerciseLifecycleReport]?:@{}}];
}
- (BOOL)exerciseLifecycleStep:(NSString *)kind {
    if(![self.exerciseRequest[@"action"]isEqual:@"playback-lifecycle"]||RewindStore.shared.restricted)return NO;
    NSFileManager *fm=NSFileManager.defaultManager;double now=NSProcessInfo.processInfo.systemUptime;
    NSString *root=[RWDocuments()stringByAppendingPathComponent:@"TorrentMetadata"],*ownerPath=[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics/lifecycle-owner.plist"];
    NSMutableArray *hashes=[NSMutableArray new];NSMutableDictionary *metadata=[NSMutableDictionary new];
    for(NSString *backend in @[@"native",@"mkv"]){NSString *hash=[RWDeviceExercise lifecycleSource:backend][@"infoHash"];[hashes addObject:hash];NSData *bytes=[NSData dataWithContentsOfFile:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:[NSString stringWithFormat:@"Rewind/lifecycle-%@-278.torrent",backend]]];if(bytes.length!=1518)return NO;metadata[hash]=bytes;}
    NSDictionary *owner=@{@"run":self.exerciseRequest[@"run"],@"build":NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"],@"hashes":hashes};
    if([kind isEqual:@"lifecycle-prepare"]){
        if(self.presentedViewController||[fm fileExistsAtPath:ownerPath])return NO;
        for(NSString *hash in hashes)if([fm fileExistsAtPath:[root stringByAppendingPathComponent:[hash stringByAppendingString:@".torrent"]]]||[fm fileExistsAtPath:[[RWDocuments()stringByAppendingPathComponent:@"Torrents"]stringByAppendingPathComponent:hash]])return NO;
        [fm createDirectoryAtPath:ownerPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];[fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
        if(![owner writeToFile:ownerPath atomically:YES])return NO;
        for(NSString *hash in hashes)if(![metadata[hash]writeToFile:[root stringByAppendingPathComponent:[hash stringByAppendingString:@".torrent"]]atomically:YES])return NO;
        self.exerciseLifecycleReport=[@{@"run":self.exerciseRequest[@"run"],@"cycle":@0,@"prepared_at":@(now),@"cache_initial":[self lifecycleCacheInventory]?:@{}}mutableCopy];[self reportLifecyclePhase:@"prepared"];return YES;
    }
    if(![[NSDictionary dictionaryWithContentsOfFile:ownerPath]isEqual:owner]&&![self.exerciseLifecycleReport[@"cleanup"]boolValue])return NO;
    if([kind hasPrefix:@"lifecycle-play:"]){
        NSString *backend=[[kind componentsSeparatedByString:@":"]lastObject];NSUInteger cycle=[self.exerciseLifecycleReport[@"cycle"]unsignedIntegerValue];
        if(cycle>=6||![backend isEqual:cycle%2?@"mkv":@"native"]||self.presentedViewController||self.exercisePlayer)return NO;
        [self stopPreview];[self.playbackPreparation cancel];[RewindStore.shared setDiscoveryPaused:YES];
        if([TorrentEngine activeSessionCount]!=0)return NO;
        NSDictionary *inventory=[self lifecycleCacheInventory];if(!inventory)return NO;
        self.exerciseLifecycleReport=[@{@"run":self.exerciseRequest[@"run"],@"cycle":@(cycle+1),@"backend":backend,@"started":@(now),@"cache_before":inventory}mutableCopy];
        NSString *video=[NSString stringWithFormat:@"rw:lifecycle-%@:preview",backend];RewindPlayer *player=[[RewindPlayer alloc]initWithMeta:@{@"id":video,@"type":@"movie",@"name":@"Torrent lifecycle check"} videoID:video source:[RWDeviceExercise lifecycleSource:backend] resume:0];
        if(![player beginLifecycleExercise:backend])return NO;self.exercisePlayer=player;self.exercisePlaybackStarted=now;self.exerciseLifetimeProbe=nil;
        __weak RewindController *weak=self;player.onClose=^{[weak syncDiscoveryActivity];[weak render];};[self presentViewController:player animated:YES completion:nil];[self reportLifecyclePhase:@"starting"];return YES;
    }
    if([kind isEqual:@"lifecycle-cleanup"]){
        if(self.presentedViewController||self.exercisePlayer||[TorrentEngine activeSessionCount]||[self.exerciseLifecycleReport[@"cycle"]intValue]!=6)return NO;
        self.exerciseLifecycleReport[@"cleanup_started"]=@(now);self.exerciseLifecycleReport[@"cleanup_remaining"]=@2;self.exerciseLifecycleReport[@"cleanup_failed"]=@NO;
        NSString *run=self.exerciseRequest[@"run"];__weak RewindController *weak=self;
        for(NSString *hash in hashes)[TorrentEngine removeDownload:hash done:^(BOOL removed){
            if(![weak.exerciseRequest[@"run"]isEqual:run]||![[NSDictionary dictionaryWithContentsOfFile:ownerPath]isEqual:owner])return;
            NSString *path=[root stringByAppendingPathComponent:[hash stringByAppendingString:@".torrent"]],*cache=[[RWDocuments()stringByAppendingPathComponent:@"Torrents"]stringByAppendingPathComponent:hash];
            BOOL ok=(removed||![fm fileExistsAtPath:cache])&&[[NSData dataWithContentsOfFile:path]isEqual:metadata[hash]]&&[fm removeItemAtPath:path error:nil];
            if(!ok)weak.exerciseLifecycleReport[@"cleanup_failed"]=@YES;
            NSInteger left=[weak.exerciseLifecycleReport[@"cleanup_remaining"]integerValue]-1;weak.exerciseLifecycleReport[@"cleanup_remaining"]=@(left);
            if(!left){BOOL done=![weak.exerciseLifecycleReport[@"cleanup_failed"]boolValue]&&[fm removeItemAtPath:ownerPath error:nil];weak.exerciseLifecycleReport[@"cleanup"]=@(done);[weak reportLifecyclePhase:done?@"cleaned":@"cleanup_failed"];}
        }];return YES;
    }
    if([kind isEqual:@"lifecycle-cleanup-await"]){if([self.exerciseLifecycleReport[@"cleanup_remaining"]integerValue]){if(now-[self.exerciseLifecycleReport[@"cleanup_started"]doubleValue]>8)return NO;self.exerciseIndex--;return YES;}return [self.exerciseLifecycleReport[@"cleanup"]boolValue];}
    NSDictionary *state=[self.exercisePlayer deviceExerciseSnapshot]?:@{},*transport=[self.exercisePlayer deviceExerciseTransportSnapshot]?:@{};NSString *backend=self.exerciseLifecycleReport[@"backend"];
    if([kind isEqual:@"lifecycle-dismissed"]){
        if(now-[self.exerciseLifecycleReport[@"close_started"]doubleValue]>8||![state[@"closing"]boolValue])return NO;
        if(self.presentedViewController){self.exerciseIndex--;return YES;}self.exercisePlayer=nil;return YES;
    }
    if([kind isEqual:@"lifecycle-released"]){
        if(self.exercisePlayer||self.presentedViewController||!self.exerciseLifetimeProbe)return NO;
        NSDictionary *objects=self.exerciseLifetimeProbe.snapshot;NSUInteger remaining=0;for(NSNumber *n in objects.allValues)remaining+=n.unsignedIntegerValue;
        if(remaining||[TorrentEngine activeSessionCount]){if(now-[self.exerciseLifecycleReport[@"close_started"]doubleValue]>8)return NO;self.exerciseIndex--;return YES;}
        NSDictionary *inventory=[self lifecycleCacheInventory];if(!inventory)return NO;
        self.exerciseLifecycleReport[@"released_objects"]=objects;self.exerciseLifecycleReport[@"active_sessions_after"]=@([TorrentEngine activeSessionCount]);self.exerciseLifecycleReport[@"release_seconds"]=@(now-[self.exerciseLifecycleReport[@"close_started"]doubleValue]);self.exerciseLifecycleReport[@"cache_after"]=inventory;
        [self reportLifecyclePhase:@"released"];return YES;
    }
    if(![state[@"transient"]boolValue]||[state[@"closing"]boolValue]||[state[@"exhausted"]boolValue])return NO;
    if([kind isEqual:@"lifecycle-ready"]){
        if(now-self.exercisePlaybackStarted>45)return NO;
        if(![state[@"media_verified"]boolValue]||![state[@"frame_visible"]boolValue]||[state[@"position"]doubleValue]<5){self.exerciseIndex--;return YES;}
        if(![state[@"backend"]isEqual:backend]||[TorrentEngine activeSessionCount]!=1)return NO;
        self.exerciseLifetimeProbe=[self.exercisePlayer deviceExerciseLifetimeProbe];NSDictionary *objects=self.exerciseLifetimeProbe.snapshot;
        NSArray *expected=[backend isEqual:@"mkv"]?@[@"player",@"engine",@"legacy_player"]:@[@"player",@"engine",@"loader",@"native_player"];
        if(objects.count!=expected.count)return NO;for(NSString *key in expected)if([objects[key]intValue]!=1)return NO;
        self.exerciseLifecycleReport[@"initial_objects"]=objects;self.exerciseLifecycleReport[@"startup_seconds"]=transport[@"metrics"][@"first_advancing_playback_seconds"]?:@(-1);[self reportLifecyclePhase:@"playing"];return YES;
    }
    if([kind isEqual:@"lifecycle-pause"])return [self.exercisePlayer deviceExerciseControl:@"pause"];
    if([kind isEqual:@"lifecycle-seek"]){self.exerciseLifecycleReport[@"seek_started"]=@(now);return [self.exercisePlayer deviceExerciseControl:@"lifecycle-seek:30"];}
    if([kind isEqual:@"lifecycle-resume"])return [self.exercisePlayer deviceExerciseControl:@"resume"];
    if([kind isEqual:@"lifecycle-advancing"]){
        if(now-[self.exerciseLifecycleReport[@"seek_started"]doubleValue]>25)return NO;
        if([state[@"native_seek"][@"pending"]boolValue]||[state[@"position"]doubleValue]<33||![state[@"wants_play"]boolValue]){self.exerciseIndex--;return YES;}return [state[@"position"]doubleValue]<50;
    }
    if([kind isEqual:@"lifecycle-menu"])return [self.exercisePlayer deviceExerciseControl:@"subtitle-menu"];
    if([kind isEqual:@"lifecycle-captions"]){self.exerciseLifecycleReport[@"caption_started"]=@(now);return [self.exercisePlayer deviceExerciseControl:@"subtitle-choice:English · Text file"];}
    if([kind isEqual:@"lifecycle-caption-ready"]){
        if(now-[self.exerciseLifecycleReport[@"caption_started"]doubleValue]>10)return NO;
        if(![state[@"subtitle_text"]isEqual:@"English subtitle: second passage"]){self.exerciseIndex--;return YES;}
        self.exerciseLifecycleReport[@"observe_started"]=@(now);self.exerciseLifecycleReport[@"observe_position"]=state[@"position"];self.exerciseLifecycleReport[@"observe_stalls"]=transport[@"metrics"][@"stall_events"]?:@0;self.exerciseLifecycleReport[@"observe_frames"]=state[@"embedded_metrics"][@"displayed_frames"]?:@0;
        RWCapture(self.exercisePlayer.view,[NSString stringWithFormat:@"device-exercise-lifecycle-%@",self.exerciseLifecycleReport[@"cycle"]]);return YES;
    }
    if([kind isEqual:@"lifecycle-observe"]){
        double elapsed=now-[self.exerciseLifecycleReport[@"observe_started"]doubleValue];if(elapsed>30||![state[@"wants_play"]boolValue])return NO;
        if(elapsed<20||[state[@"position"]doubleValue]-[self.exerciseLifecycleReport[@"observe_position"]doubleValue]<19.5){self.exerciseIndex--;return YES;}
        if([transport[@"metrics"][@"stall_events"]integerValue]!=[self.exerciseLifecycleReport[@"observe_stalls"]integerValue])return NO;
        if([backend isEqual:@"mkv"]&&[state[@"embedded_metrics"][@"displayed_frames"]integerValue]-[self.exerciseLifecycleReport[@"observe_frames"]integerValue]<400)return NO;
        self.exerciseLifecycleReport[@"observed_seconds"]=@(elapsed);self.exerciseLifecycleReport[@"observed_position_end"]=state[@"position"];return YES;
    }
    if([kind isEqual:@"lifecycle-close"]){
        NSDictionary *metrics=transport[@"metrics"]?:@{},*loader=transport[@"loader"]?:@{};NSMutableDictionary *sample=[NSMutableDictionary new];
        for(NSString *key in @[@"session_id",@"first_advancing_playback_seconds",@"stall_events",@"playing_seconds_estimate",@"peak_resident_bytes"])if(metrics[key])sample[key]=metrics[key];
        NSMutableDictionary *reads=[NSMutableDictionary new];for(NSString *key in @[@"active_count",@"started_requests",@"cancelled_requests",@"bytes_delivered",@"max_reads_per_pump",@"max_read_bytes_per_pump"])if(loader[key])reads[key]=loader[key];
        self.exerciseLifecycleReport[@"metrics"]=sample;self.exerciseLifecycleReport[@"loader"]=reads;self.exerciseLifecycleReport[@"close_started"]=@(now);[self reportLifecyclePhase:@"closing"];return [self.exercisePlayer deviceExerciseControl:@"close"];
    }
    return NO;
}
