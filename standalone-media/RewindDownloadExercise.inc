// Real Downloads controls over a uniquely owned generated cache file. No
// existing download is removed. Trim uses the same filesystem/policy in a
// separate owned directory, not the user's entire temporary cache.
- (NSString *)exerciseDownloadPath {
    NSDictionary *p=[RewindStore shared].state[@"profiles"][@"rw-device-resume-check"];
    NSString *hash=p[@"sources"][@"rw:download-owner"][@"hash"];
    if(![hash isKindOfClass:NSString.class]||hash.length!=40||![hash hasPrefix:@"d1090000"]||[hash rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"].invertedSet].location!=NSNotFound)return nil;
    return [[RWDocuments()stringByAppendingPathComponent:@"Torrents"]stringByAppendingPathComponent:hash];
}
- (NSDictionary *)exerciseDownloadSnapshot {
    RewindStore *s=RewindStore.shared;NSString *path=[self exerciseDownloadPath];NSDictionary *record=[s record:@"rw:download-check"];
    return @{@"profile":s.state[@"activeProfile"],@"page":self.page?:@"",@"busy":@(self.downloadsBusy||self.downloadsActionBusy),@"items":self.downloadsSnapshot[@"items"]?:@[],@"history":record?:@{},@"file_exists":@(path&&[NSFileManager.defaultManager fileExistsAtPath:path]),@"kept":@(path&&[s.state[@"keptDownloads"]containsObject:path.lastPathComponent]),@"trim":self.exerciseDownloadReport?:@{}};
}
- (BOOL)exerciseDownloadButton:(NSString *)title {
    NSMutableArray *queue=[self.downloadsList.visibleCells mutableCopy];
    while(queue.count){UIView *v=queue.lastObject;[queue removeLastObject];if([v isKindOfClass:RWButton.class]&&[[(RWButton *)v currentTitle]isEqual:title]&&!v.hidden&&[(RWButton *)v isEnabled]){[(RWButton *)v sendActionsForControlEvents:UIControlEventTouchUpInside];return YES;}[queue addObjectsFromArray:v.subviews];}return NO;
}
- (BOOL)exerciseDownloadStep:(NSString *)kind {
    RewindStore *s=RewindStore.shared;NSFileManager *fm=NSFileManager.defaultManager;
    if(!self.exerciseResumeOwned||![s.state[@"activeProfile"]isEqual:@"rw-device-resume-check"]||![RWDeviceExercise ownsResumeProfile:s.profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]])return NO;
    if([kind isEqual:@"download-prepare"]){
        [self stopPreview];[self.playbackPreparation cancel];[s setDiscoveryPaused:YES];
        NSString *hash=[@"d1090000" stringByAppendingString:[[self.exerciseRequest[@"run"]stringByReplacingOccurrencesOfString:@"-" withString:@""]lowercaseString]];
        NSString *path=[[RWDocuments()stringByAppendingPathComponent:@"Torrents"]stringByAppendingPathComponent:hash];if([fm fileExistsAtPath:path]||[s.state[@"keptDownloads"]containsObject:hash])return NO;
        NSDictionary *owner=@{@"hash":hash,@"run":self.exerciseRequest[@"run"]};s.profile[@"sources"][@"rw:download-owner"]=owner;
        if(![fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil])return NO;
        if(![owner writeToFile:[path stringByAppendingPathComponent:@"rewind-test-owner.plist"] atomically:YES])return NO;
        NSMutableData *payload=[NSMutableData dataWithLength:1024*1024];arc4random_buf(payload.mutableBytes,payload.length);if(![payload writeToFile:[path stringByAppendingPathComponent:@"generated-cache.bin"] atomically:YES])return NO;
        NSDictionary *meta=@{@"id":@"rw:download-check",@"name":@"Storage control check",@"type":@"movie"},*source=@{@"infoHash":hash,@"url":[@"magnet:?xt=urn:btih:" stringByAppendingString:hash],@"fileIdx":@0,@"downloadBytes":@(payload.length)};
        s.profile[@"history"][@"rw:download-check"]=@{@"videoID":@"rw:download-check",@"meta":meta,@"source":source,@"position":@80,@"duration":@600,@"updated":@(NSDate.date.timeIntervalSince1970)};[s save];self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;[self go:@"Downloads"];return YES;
    }
    NSDictionary *snap=[self exerciseDownloadSnapshot];
    if([kind isEqual:@"download-await"]||[kind isEqual:@"download-await-removed"]){if(NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>20)return NO;BOOL removed=[kind isEqual:@"download-await-removed"];if([snap[@"busy"]boolValue]||[snap[@"items"]count]!=(removed?0:1)||(!removed&&![self.downloadsScope isEqual:s.state[@"activeProfile"]]))self.exerciseIndex--;return YES;}
    if([kind isEqual:@"download-keep"]||[kind isEqual:@"download-unkeep"])return [self exerciseDownloadButton:[kind isEqual:@"download-keep"]?@"Keep":@"Kept"];
    if([kind isEqual:@"download-remove"]){BOOL ok=[self exerciseDownloadButton:@"Remove"];self.exerciseReminderSheet=(UIAlertController *)self.presentedViewController;return ok&&[self.presentedViewController.title isEqual:@"Remove download?"]&&self.exerciseDownloadRemoval!=nil;}
    if([kind isEqual:@"download-confirm"]){if(!self.exerciseDownloadRemoval||self.presentedViewController!=self.exerciseReminderSheet)return NO;void(^action)(void)=[self.exerciseDownloadRemoval copy];self.exerciseDownloadRemoval=nil;self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;[self dismissViewControllerAnimated:NO completion:action];return YES;}
    if([kind isEqual:@"download-trim"]){
        NSString *run=self.exerciseRequest[@"run"],*base=[[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"]stringByAppendingPathComponent:[@"storage-" stringByAppendingString:run]];if([fm fileExistsAtPath:base])return NO;
        self.exerciseDownloadReport=nil;self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;__weak RewindController *weak=self;TorrentEngine *queue=[TorrentEngine new];
        [queue perform:^(TorrentEngine *engine){NSDictionary *report=nil;BOOL ok=YES;@try{ok=[fm createDirectoryAtPath:base withIntermediateDirectories:YES attributes:nil error:nil];NSMutableData *data=[NSMutableData dataWithLength:256*1024];arc4random_buf(data.mutableBytes,data.length);
            for(NSString *name in @[@"temporary",@"kept"])ok=[data writeToFile:[base stringByAppendingPathComponent:name] atomically:YES]&&ok;
            NSDictionary *result=[RWMediaCache trimRoot:base pinned:[NSSet setWithObject:@"kept"] budget:0];ok=ok&&![fm fileExistsAtPath:[base stringByAppendingPathComponent:@"temporary"]]&&[fm fileExistsAtPath:[base stringByAppendingPathComponent:@"kept"]]&&[result[@"removed_entries"]intValue]==1&&[result[@"temporary_bytes"]longLongValue]==0&&[result[@"kept_bytes"]longLongValue]>0;
            NSMutableDictionary *r=[result mutableCopy];r[@"ok"]=@(ok);r[@"off_main"]=@(!NSThread.isMainThread);report=r;
        }@finally{[fm removeItemAtPath:base error:nil];}
            dispatch_async(dispatch_get_main_queue(),^{if([weak.exerciseRequest[@"run"]isEqual:run]){NSMutableDictionary *r=[report mutableCopy]?:[NSMutableDictionary new];r[@"fixture_removed"]=@(![fm fileExistsAtPath:base]);weak.exerciseDownloadReport=r;}});
        }];return YES;
    }
    if([kind isEqual:@"download-await-trim"]){if(NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>10)return NO;if(!self.exerciseDownloadReport)self.exerciseIndex--;return YES;}
    BOOL ok=[snap[@"page"]isEqual:@"Downloads"]&&[snap[@"history"][@"position"]intValue]==80&&[snap[@"history"][@"duration"]intValue]==600;
    if([kind isEqual:@"download-audit-initial"]||[kind isEqual:@"download-audit-kept"]||[kind isEqual:@"download-audit-unkept"]){BOOL kept=[kind isEqual:@"download-audit-kept"];NSDictionary *item=[snap[@"items"]firstObject];ok=ok&&[snap[@"items"]count]==1&&[snap[@"file_exists"]boolValue]&&[snap[@"kept"]boolValue]==kept&&[item[@"kept"]boolValue]==kept&&![item[@"offlineVerified"]boolValue];}
    else if([kind isEqual:@"download-audit-removed"])ok=ok&&![snap[@"items"]count]&&![snap[@"file_exists"]boolValue]&&![snap[@"kept"]boolValue];
    else if([kind isEqual:@"download-audit-trim"])ok=ok&&[self.exerciseDownloadReport[@"ok"]boolValue]&&[self.exerciseDownloadReport[@"fixture_removed"]boolValue]&&[self.exerciseDownloadReport[@"off_main"]boolValue];
    else return NO;
    RWCapture(self.view,[@"device-exercise-" stringByAppendingString:kind]);return ok;
}
- (void)finishDownloadExercise {
    RewindStore *s=RewindStore.shared;NSDictionary *profile=s.state[@"profiles"][@"rw-device-resume-check"];
    if(![RWDeviceExercise ownsResumeProfile:profile build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]])return;
    NSDictionary *owner=profile[@"sources"][@"rw:download-owner"];NSString *path=[self exerciseDownloadPath];
    if(path){NSDictionary *marker=[NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"rewind-test-owner.plist"]];if([marker isEqual:owner])[NSFileManager.defaultManager removeItemAtPath:path error:nil];
        if(![NSFileManager.defaultManager fileExistsAtPath:path]){NSMutableArray *pins=[s.state[@"keptDownloads"]mutableCopy];[pins removeObject:path.lastPathComponent];s.state[@"keptDownloads"]=pins;}}
    self.exerciseDownloadRemoval=nil;
}
