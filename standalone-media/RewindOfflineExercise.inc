// Generated complete torrent data, verified by the real engine from disk.
// Host removes only this marked fixture after a confirmed app process exit.
- (BOOL)exerciseOfflineStep:(NSString *)kind {
    RewindStore *s=RewindStore.shared;NSString *hash=@"c0ed8c16ade445c7121456d816e11be210abe43c",*videoID=@"rw:offline-check";
    NSString *root=[RWDocuments()stringByAppendingPathComponent:@"Torrents"],*path=[root stringByAppendingPathComponent:hash];NSFileManager *fm=NSFileManager.defaultManager;
    if(!self.exerciseResumeOwned||![s.state[@"activeProfile"]isEqual:@"rw-device-resume-check"]||![RWDeviceExercise ownsResumeProfile:s.profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]])return NO;
    if([kind isEqual:@"offline-prepare"]){
        NSString *metadata=[[RWDocuments()stringByAppendingPathComponent:@"TorrentMetadata"]stringByAppendingPathComponent:[hash stringByAppendingPathExtension:@"torrent"]];
        if([fm fileExistsAtPath:path]||[fm fileExistsAtPath:metadata]||[s.state[@"keptDownloads"]containsObject:hash]||s.state[@"sourceExperience"][[hash stringByAppendingString:@":0"]])return NO;self.exerciseDownloadReport=nil;
        NSDictionary *owner=@{@"hash":hash,@"run":self.exerciseRequest[@"run"],@"build":NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]};s.profile[@"sources"][@"rw:offline-owner"]=owner;
        if(![fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]||![owner writeToFile:[path stringByAppendingPathComponent:@"rewind-offline-owner.plist"] atomically:YES])return NO;
        NSString *clip=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Rewind/subtitle-check.mp4"];
        if(![fm copyItemAtPath:clip toPath:[path stringByAppendingPathComponent:@"rewind-offline-114.mp4"] error:nil])return NO;
        // This is our generated clip, so its origin is known. Keep that
        // provenance when normal offline eligibility rechecks the saved source.
        s.profile[@"sources"][videoID]=@{@"name":@"Generated complete download",@"publisherSource":@YES,@"infoHash":hash,@"url":[@"magnet:?xt=urn:btih:" stringByAppendingString:hash],@"fileIdx":@0};return YES;
    }
    if([kind isEqual:@"offline-play"]){
        [self chooseSources:@{@"id":videoID,@"name":@"Kept download playback check",@"type":@"movie"} videoID:videoID restart:YES];self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;return self.exercisePlayer!=nil;
    }
    NSDictionary *state=[self.exercisePlayer deviceExerciseSnapshot],*record=[s record:videoID];
    if([kind isEqual:@"offline-try-remove"]){
        if(![state[@"video_id"]isEqual:videoID]||[state[@"closing"]boolValue]||![state[@"torrent"][@"video_complete"]boolValue])return NO;
        NSDictionary *marker=[NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"rewind-offline-owner.plist"]];NSString *run=self.exerciseRequest[@"run"];
        if(![marker[@"run"]isEqual:run]||![marker[@"hash"]isEqual:hash])return NO;
        self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;__weak RewindController *weak=self;
        [TorrentEngine removeDownload:hash done:^(BOOL removed){
            if(![weak.exerciseRequest[@"run"]isEqual:run])return;
            NSMutableDictionary *report=[weak.exerciseDownloadReport mutableCopy]?:[NSMutableDictionary new];
            report[@"active_removal"]=@{@"complete":@YES,@"removed":@(removed),@"file_exists":@([fm fileExistsAtPath:[path stringByAppendingPathComponent:@"rewind-offline-114.mp4"]])};weak.exerciseDownloadReport=report;
        }];return YES;
    }
    if([kind isEqual:@"offline-await-remove"]){
        NSDictionary *attempt=self.exerciseDownloadReport[@"active_removal"];
        if(!attempt){if(NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>10)return NO;self.exerciseIndex--;return YES;}
        return [attempt[@"complete"]boolValue]&&![attempt[@"removed"]boolValue]&&[attempt[@"file_exists"]boolValue];
    }
    if([kind isEqual:@"offline-await"]||[kind isEqual:@"offline-await-resume"]){
        if([state[@"exhausted"]boolValue]||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>55)return NO;
        double target=[kind isEqual:@"offline-await-resume"]?[self.exerciseResumeRecord[@"position"]doubleValue]+3:6;
        if(![state[@"media_verified"]boolValue]||![state[@"frame_visible"]boolValue]||[state[@"position"]doubleValue]<target||![state[@"torrent"][@"video_complete"]boolValue]||![state[@"torrent"][@"offline_certificate"]count])self.exerciseIndex--;return YES;
    }
    if([kind isEqual:@"offline-keep"])return [self.exercisePlayer deviceExerciseControl:@"keep-download"];
    if([kind isEqual:@"offline-audit"]||[kind isEqual:@"offline-audit-resume"]){
        BOOL reopen=[kind isEqual:@"offline-audit-resume"];
        NSMutableDictionary *report=[self.exerciseDownloadReport mutableCopy]?:[NSMutableDictionary new];report[reopen?@"resumed_player":@"initial_player"]=state;report[reopen?@"resumed_record":@"initial_record"]=record?:@{};self.exerciseDownloadReport=report;
        RWCapture(self.exercisePlayer.view,reopen?@"device-exercise-offline-resumed":@"device-exercise-offline-initial");
        return ![state[@"transient"]boolValue]&&![state[@"wants_play"]boolValue]&&[state[@"video_id"]isEqual:videoID]&&[s.state[@"keptDownloads"]containsObject:hash]&&[record[@"source"][@"offlineCertificate"]count]>0&&[state[@"torrent"][@"peer_payload_bytes"]longLongValue]==0&&(!reopen||fabs([state[@"requested_position"]doubleValue]-[self.exerciseResumeRecord[@"position"]doubleValue])<.01);
    }
    if([kind isEqual:@"offline-downloads"]){if(self.presentedViewController)return NO;self.exerciseResumeRecord=record;self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;[self go:@"Downloads"];return YES;}
    if([kind isEqual:@"offline-await-list"]){
        if(NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>20)return NO;
        if(self.downloadsBusy||[self.downloadsSnapshot[@"items"]count]!=1){self.exerciseIndex--;return YES;}
        NSDictionary *item=self.downloadsSnapshot[@"items"][0];NSMutableDictionary *report=[self.exerciseDownloadReport mutableCopy];report[@"download_item"]=item;self.exerciseDownloadReport=report;
        RWCapture(self.view,@"device-exercise-offline-downloads");return [item[@"kept"]boolValue]&&[item[@"offlineVerified"]boolValue]&&[item[@"hash"]isEqual:hash];
    }
    if([kind isEqual:@"offline-resume"]){self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;return [self exerciseDownloadButton:@"Resume"];}
    if([kind isEqual:@"offline-record"]){NSMutableDictionary *report=[self.exerciseDownloadReport mutableCopy];report[@"final_record"]=record?:@{};self.exerciseDownloadReport=report;return [state[@"closing"]boolValue]&&[record[@"position"]doubleValue]>[self.exerciseResumeRecord[@"position"]doubleValue]+4&&![record[@"completed"]boolValue];}
    return NO;
}
- (void)finishOfflineExercise {
    if(![@[@"download-playback",@"featured-ready"]containsObject:self.exerciseRequest[@"action"]])return;
    RewindStore *s=RewindStore.shared;NSDictionary *p=s.state[@"profiles"][@"rw-device-resume-check"];
    if(![RWDeviceExercise ownsResumeProfile:p build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]])return;
    NSDictionary *owner=p[@"sources"][@"rw:offline-owner"];NSString *hash=@"c0ed8c16ade445c7121456d816e11be210abe43c";
    NSString *path=[[[RWDocuments()stringByAppendingPathComponent:@"Torrents"]stringByAppendingPathComponent:hash]stringByAppendingPathComponent:@"rewind-offline-owner.plist"];
    if([owner[@"hash"]isEqual:hash]&&[owner[@"run"]isEqual:self.exerciseRequest[@"run"]]&&[[NSDictionary dictionaryWithContentsOfFile:path]isEqual:owner]){NSMutableArray *pins=[s.state[@"keptDownloads"]mutableCopy];[pins removeObject:hash];s.state[@"keptDownloads"]=pins;NSMutableDictionary *experience=[s.state[@"sourceExperience"]mutableCopy];[experience removeObjectForKey:[hash stringByAppendingString:@":0"]];if(experience)s.state[@"sourceExperience"]=experience;}
}
