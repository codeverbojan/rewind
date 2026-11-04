// Fixed URLs for a temporary USB-forwarded fixture and Blender's public HTTPS
// subtitles. No arbitrary command/URL is accepted from a diagnostic request.
- (BOOL)exerciseHTTPSubtitleStep:(NSString *)kind {
    if([kind isEqual:@"http-play"]){
        RewindStore *store=[RewindStore shared];if(store.restricted||self.presentedViewController)return NO;
        [self stopPreview];[self.playbackPreparation cancel];[store setDiscoveryPaused:YES];
        NSMutableArray *files=[NSMutableArray new];
        for(NSString *name in @[@"srt",@"vtt",@"redirect",@"headers",@"chunked",@"gzip",@"missing",@"loop",@"malformed",@"slow"])[files addObject:@{@"name":name,@"lang":@"und",@"url":[@"http://127.0.0.1:18882/" stringByAppendingString:name]}];
        [files addObject:@{@"name":@"https",@"lang":@"und",@"url":@"https://download.blender.org/demo/movies/ToS/subtitles/TOS-en.srt"}];
        NSDictionary *meta=@{@"id":@"rw:subtitle-http",@"type":@"movie",@"name":@"Downloaded subtitle check"};
        RewindPlayer *player=[[RewindPlayer alloc]initWithMeta:meta videoID:@"rw:subtitle-http:preview" source:@{@"name":@"Generated CC0 test clip",@"url":@"asset:subtitle-check.mp4",@"subtitles":files} resume:0];
        [player beginSubtitleExercise];self.exercisePlayer=player;self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;
        __weak RewindController *weak=self;player.onClose=^{[weak syncDiscoveryActivity];[weak render];};[self presentViewController:player animated:YES completion:nil];return YES;
    }
    if([kind isEqual:@"http-dismiss-error"])return [self.exercisePlayer deviceExerciseControl:@"subtitle-dismiss-error"];
    NSDictionary *state=[self.exercisePlayer deviceExerciseSnapshot];if(![state[@"transient"]boolValue]||[state[@"closing"]boolValue])return NO;
    NSDictionary *transfer=state[@"subtitle_transfer"];
    if([kind hasPrefix:@"http-await-"]){
        if(![self.exerciseHTTPStage isEqual:kind]){self.exerciseHTTPStage=kind;self.exerciseHTTPStarted=NSProcessInfo.processInfo.systemUptime;}
        if(NSProcessInfo.processInfo.systemUptime-self.exerciseHTTPStarted>24)return NO;
        if(!transfer.count||([transfer[@"ok"]boolValue]&&![state[@"subtitle_cues"]integerValue]&&![state[@"menu"]isEqual:@"Subtitles unavailable"]))self.exerciseIndex--;return YES;
    }
    if(![kind hasPrefix:@"http-audit-"])return NO;
    NSString *name=[kind substringFromIndex:[@"http-audit-" length]];BOOL ok=![state[@"wants_play"]boolValue]&&[state[@"media_verified"]boolValue]&&[state[@"frame_visible"]boolValue]&&![state[@"keep_visible"]boolValue];
    if([name isEqual:@"off"])ok=ok&&![state[@"subtitle_cues"]integerValue]&&![state[@"subtitle_text"]length]&&![state[@"subtitle_enabled"]boolValue]&&![state[@"menu"]length];
    else {
        ok=ok&&transfer.count&&[transfer[@"peak_buffer_bytes"]unsignedIntegerValue]<=2*1024*1024;
        if([@[@"srt",@"redirect"]containsObject:name])ok=ok&&[transfer[@"ok"]boolValue]&&[state[@"subtitle_text"]isEqual:@"Downloaded English"]&&[state[@"subtitle_cues"]integerValue]==1;
        else if([@[@"vtt",@"replacement"]containsObject:name])ok=ok&&[transfer[@"ok"]boolValue]&&[state[@"subtitle_text"]isEqual:@"Sous-titre français"]&&[state[@"subtitle_cues"]integerValue]==1;
        else if([name isEqual:@"https"])ok=ok&&[transfer[@"ok"]boolValue]&&[transfer[@"bytes"]integerValue]==4764&&[state[@"subtitle_cues"]integerValue]>20;
        else {ok=ok&&[state[@"menu"]isEqual:@"Subtitles unavailable"]&&![state[@"subtitle_cues"]integerValue]&&![state[@"subtitle_text"]length];if(![name isEqual:@"malformed"])ok=ok&&![transfer[@"ok"]boolValue];}
        if([name isEqual:@"headers"])ok=ok&&[transfer[@"peak_buffer_bytes"]integerValue]==0;
        if([name isEqual:@"loop"])ok=ok&&[transfer[@"redirects"]integerValue]==4;
        if([name isEqual:@"redirect"])ok=ok&&[transfer[@"redirects"]integerValue]==1;
    }
    if([@[@"srt",@"vtt",@"replacement",@"off",@"headers",@"https"]containsObject:name])RWCapture(self.exercisePlayer.presentedViewController?self.exercisePlayer.presentedViewController.view:self.exercisePlayer.view,[@"device-exercise-http-" stringByAppendingString:name]);
    return ok;
}
