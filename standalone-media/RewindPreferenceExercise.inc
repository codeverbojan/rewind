// Same HTTP locator, two content digests, normal menus and saved preferences.
// Only the UUID/build-owned parent and its already guarded companion may run.
- (BOOL)exerciseSubtitleRevisionStep:(NSString *)kind {
    NSString *action=self.exerciseRequest[@"action"];
    if(![action containsString:@"-revision-"]||!self.exerciseResumeOwned)return NO;
    RewindStore *store=RewindStore.shared;NSInteger build=[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue];
    NSString *key=store.state[@"activeProfile"];NSMutableDictionary *parent=store.state[@"profiles"][@"rw-device-resume-check"];
    BOOL primary=[key isEqual:@"rw-device-resume-check"]&&[RWDeviceExercise ownsResumeProfile:store.profile build:build];
    BOOL companion=[key isEqual:@"rw-device-audio-other"]&&[RWDeviceExercise ownsAudioCompanion:store.profile parent:parent build:build];
    if(!primary&&!companion)return NO;
    BOOL mkv=[action hasSuffix:@"-mkv"],changed=[action containsString:@"-changed-"]||[action containsString:@"-again-"];
    if([kind isEqual:@"prefs-revision-other"]||[kind isEqual:@"prefs-revision-primary"]){
        if(![action containsString:@"-profiles-"]||self.presentedViewController)return NO;
        NSString *target=@"rw-device-resume-check";
        if([kind isEqual:@"prefs-revision-other"]){
            if(!primary)return NO;target=@"rw-device-audio-other";
            if(!store.state[@"profiles"][target]){NSMutableDictionary *other=[RWProfiles make:@"Device audio other" age:-1];other[@"autoplayTrailers"]=@NO;other[@"sources"][@"rw:audio-owner"]=[parent[@"sources"][@"rw:resume-owner"]copy];store.state[@"profiles"][target]=other;}
            if(![RWDeviceExercise ownsAudioCompanion:store.state[@"profiles"][target] parent:parent build:build])return NO;
        }else if(!companion)return NO;
        self.exerciseProfile=target;[self selectProfile:target];[store setDiscoveryPaused:YES];return YES;
    }
    if([kind isEqual:@"prefs-revision-play"]){
        if(self.presentedViewController)return NO;[self stopPreview];[self.playbackPreparation cancel];[store setDiscoveryPaused:YES];
        NSString *video=mkv?@"rw:resume-mkv":@"rw:resume-native";
        RewindPlayer *player=[[RewindPlayer alloc]initWithMeta:@{@"id":video,@"type":@"movie",@"name":@"Caption content check"} videoID:video source:@{@"name":@"Generated CC0 clip",@"url":mkv?@"asset:subtitle-check.mkv":@"asset:subtitle-check.mp4"} resume:0];
        if(![player beginResumeExercise])return NO;self.exercisePlayer=player;self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;self.exercisePausedPosition=0;
        __weak RewindController *weak=self;player.onClose=^{[weak syncDiscoveryActivity];[weak render];};[self presentViewController:player animated:YES completion:nil];return YES;
    }
    NSDictionary *s=[self.exercisePlayer deviceExerciseSnapshot];
    if(!self.exercisePlayer||[s[@"transient"]boolValue]||![s[@"persistence_profile"]isEqual:key]||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>45)return NO;
    NSString *value=[[kind componentsSeparatedByString:@":"]lastObject];
    if([kind hasPrefix:@"prefs-revision-await:"]){
        BOOL ready=NO;
        if([value isEqual:@"picture"])ready=[s[@"media_verified"]boolValue]&&[s[@"frame_visible"]boolValue]&&[s[@"position"]doubleValue]>=2;
        else if([value isEqual:@"encoding"])ready=[s[@"subtitle_decode"][@"status"]isEqual:@"needs_encoding"];
        else if([value isEqual:@"ready"])ready=[s[@"subtitle_decode"][@"status"]isEqual:@"ok"];
        else if([value isEqual:@"seek"])ready=fabs([s[@"position"]doubleValue]-32)<.2;
        else if([value isEqual:@"advancing"])ready=[s[@"wants_play"]boolValue]&&[s[@"position"]doubleValue]>34;
        else if([value isEqual:@"closed"])ready=!self.presentedViewController;
        else return NO;
        if([s[@"exhausted"]boolValue])return NO;if(!ready)self.exerciseIndex--;return YES;
    }
    if([s[@"wants_play"]boolValue])return NO;
    if([kind isEqual:@"prefs-revision-add"])return [self.exercisePlayer deviceExerciseControl:@"subtitle-test-manual-link"];
    if([kind isEqual:@"prefs-revision-seek"])return [self.exercisePlayer deviceExerciseControl:@"subtitle-test-seek:32"];
    if([kind isEqual:@"prefs-revision-menu"])return [self.exercisePlayer deviceExerciseControl:@"subtitle-menu"];
    if([kind hasPrefix:@"prefs-revision-choice:"])return [self.exercisePlayer deviceExerciseControl:[@"subtitle-choice:" stringByAppendingString:value]];
    if(![kind hasPrefix:@"prefs-revision-audit:"])return NO;
    NSDictionary *p=store.profile,*adjustment=p[@"subtitleAdjustments"][s[@"subtitle_adjustment_key"]];BOOL ok=NO;
    if([value isEqual:@"empty-profile"])ok=companion&&![p[@"subtitleLinks"]count]&&![p[@"subtitleSelections"]count]&&![p[@"subtitleAdjustments"]count]&&![s[@"subtitle_content_digest"]length];
    else if([value isEqual:@"unadjusted"]||[value isEqual:@"changed-unadjusted"]){
        ok=[s[@"subtitle_decode"][@"status"]isEqual:@"needs_encoding"]&&![s[@"subtitle_cues"]intValue]&&![s[@"subtitle_text"]length]&&[s[@"subtitle_delay"]doubleValue]==0&&![adjustment count]&&[s[@"subtitle_content_digest"]length]==64&&[s[@"subtitle_transfer"][@"http_status"]intValue]==200;
        if([value isEqual:@"changed-unadjusted"])ok=ok&&[p[@"subtitleAdjustments"]count]==1;
    }else{
        NSString *encoding=changed?@"windows-1250":@"windows-1251",*text=changed?@"Nový začátek filmu":@"Начало фильма";
        double delay=(changed||companion)?-.5:.5;
        NSDictionary *choice=p[@"subtitleSelections"][s[@"video_id"]];
        ok=[s[@"subtitle_decode"][@"status"]isEqual:@"ok"]&&[s[@"subtitle_decode"][@"encoding"]isEqual:encoding]&&[adjustment[@"encoding"]isEqual:encoding]&&fabs([s[@"subtitle_delay"]doubleValue]-delay)<.01&&fabs([adjustment[@"delay"]doubleValue]-delay)<.01&&[s[@"subtitle_text"]isEqual:text]&&[s[@"subtitle_cues"]intValue]==3&&[s[@"subtitle_transfer"][@"http_status"]intValue]==200&&[choice[@"token"]isEqual:s[@"subtitle_identity"][@"token"]]&&[choice[@"enabled"]boolValue]&&[p[@"subtitleLinks"]count]==1;
        if([action containsString:@"-profiles-"]){
            NSDictionary *other=store.state[@"profiles"][@"rw-device-audio-other"];
            if(other){NSString *digest=s[@"subtitle_content_digest"],*identity=s[@"subtitle_adjustment_key"];ok=ok&&digest.length==64&&fabs([parent[@"subtitleAdjustments"][identity][@"delay"]doubleValue]-.5)<.01&&fabs([other[@"subtitleAdjustments"][identity][@"delay"]doubleValue]+.5)<.01;}
        }
    }
    RWCapture(self.exercisePlayer.view,[NSString stringWithFormat:@"device-exercise-%@-%@",action,[kind stringByReplacingOccurrencesOfString:@":" withString:@"-"]]);return ok;
}

// Normal persisted settings in the owned diagnostic profile. The Mac closes
// the process between save and open; ordinary profiles are audited unchanged.
- (BOOL)exerciseSubtitleLinkStep:(NSString *)kind {
    NSDictionary *state=[self.exercisePlayer deviceExerciseSnapshot],*p=RewindStore.shared.profile;
    if([self.exerciseRequest[@"action"]rangeOfString:@"-link-"].location==NSNotFound||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>90||[state[@"transient"]boolValue]||![state[@"persistence_profile"]isEqual:@"rw-device-resume-check"]||[state[@"wants_play"]boolValue])return NO;
    if([kind isEqual:@"prefs-link-add"])return [self.exercisePlayer deviceExerciseControl:@"subtitle-test-manual-link"];
    NSString *value=[[kind componentsSeparatedByString:@":"]lastObject];
    if([kind isEqual:@"prefs-link-presented"]){
        if(![self.exerciseRequest[@"action"]isEqual:@"preferences-open-link-mkv"])return NO;
        NSDictionary *trace=state[@"embedded_metrics"][@"presentation_trace"],*frames=trace[@"frames"];
        if(NSProcessInfo.processInfo.systemUptime-[trace[@"began"]doubleValue]>8)return NO;
        NSUInteger completed=0;for(NSDictionary *frame in frames.allValues){if([frame[@"status"]hasPrefix:@"failed"])return NO;if([frame[@"status"]isEqual:@"complete"])completed++;}
        if(completed!=3){self.exerciseIndex--;return YES;}return fabs([state[@"position"]doubleValue]-52)<.2;
    }
    if([kind hasPrefix:@"prefs-link-frame:"]){
        if(![self.exerciseRequest[@"action"]isEqual:@"preferences-open-link-mkv"]||![self.exercisePlayer deviceExerciseControl:[@"subtitle-frame:" stringByAppendingString:value]])return NO;
        NSDictionary *frame=[self.exercisePlayer deviceExerciseSnapshot][@"subtitle_frames"][value];
        if([frame[@"status"]isEqual:@"pending"]){if(NSProcessInfo.processInfo.systemUptime-[frame[@"started"]doubleValue]>8)return NO;self.exerciseIndex--;return YES;}
        return [frame[@"status"]isEqual:@"complete"]&&![frame[@"wants_play"]boolValue]&&fabs([frame[@"position_before"]doubleValue]-52)<.2&&fabs([frame[@"position_after"]doubleValue]-[frame[@"position_before"]doubleValue])<.05;
    }
    if([kind hasPrefix:@"prefs-link-seek:"])return [self.exercisePlayer deviceExerciseControl:[@"subtitle-test-seek:" stringByAppendingString:value]];
    if([kind hasPrefix:@"prefs-link-await:"]){BOOL ready=[value isEqual:@"encoding"]?([state[@"menu"]isEqual:@"Subtitle text"]&&[state[@"subtitle_decode"][@"status"]isEqual:@"needs_encoding"]):[state[@"subtitle_decode"][@"status"]isEqual:@"ok"];
        if([@[@"2",@"32",@"52"]containsObject:value])ready=ready&&fabs([state[@"position"]doubleValue]-value.doubleValue)<.2;
        if(!ready)self.exerciseIndex--;return YES;}
    if(![kind hasPrefix:@"prefs-audit-link-"])return NO;
    NSDictionary *descriptor=state[@"subtitle_identity"],*choice=p[@"subtitleSelections"][state[@"video_id"]],*adjustment=p[@"subtitleAdjustments"][state[@"subtitle_adjustment_key"]];
    double time=[state[@"position"]doubleValue];NSString *expected=time<20.5?@"Начало фильма":time<40.5?@"Середина фильма":@"Конец фильма";
    BOOL ok=[state[@"subtitle_text"]isEqual:expected]&&[state[@"subtitle_cues"]intValue]==3&&[descriptor[@"language"]isEqual:@"ru"]&&[descriptor[@"forced"]boolValue]&&[descriptor[@"sdh"]boolValue]&&[choice[@"token"]isEqual:descriptor[@"token"]]&&[choice[@"enabled"]boolValue]&&fabs([state[@"subtitle_delay"]doubleValue]-.5)<.01&&[state[@"subtitle_decode"][@"encoding"]isEqual:@"windows-1251"]&&[adjustment[@"encoding"]isEqual:@"windows-1251"]&&fabs([adjustment[@"delay"]doubleValue]-.5)<.01&&[p[@"subtitleLinks"]count]==1&&[state[@"subtitle_transfer"][@"http_status"]intValue]==200;
    RWCapture(self.exercisePlayer.view,[NSString stringWithFormat:@"device-exercise-%@-%@",self.exerciseRequest[@"action"],kind]);return ok;
}
- (BOOL)exercisePreferenceStep:(NSString *)kind {
    if([kind hasPrefix:@"prefs-revision-"])return [self exerciseSubtitleRevisionStep:kind];
    RewindStore *store=RewindStore.shared;
    if(!self.exerciseResumeOwned||![store.state[@"activeProfile"]isEqual:@"rw-device-resume-check"]||!self.exercisePlayer)return NO;
    if([kind hasPrefix:@"prefs-link-"]||[kind hasPrefix:@"prefs-audit-link-"])return [self exerciseSubtitleLinkStep:kind];
    if([kind isEqual:@"prefs-menu"])return [self.exercisePlayer deviceExerciseControl:@"subtitle-menu"];
    if([kind hasPrefix:@"prefs-choice:"])return [self.exercisePlayer deviceExerciseControl:[@"subtitle-choice:" stringByAppendingString:[kind substringFromIndex:13]]];
    NSDictionary *state=[self.exercisePlayer deviceExerciseSnapshot],*p=store.profile;
    NSDictionary *choice=p[@"subtitleSelections"][state[@"video_id"]],*adjustments=p[@"subtitleAdjustments"];
    BOOL saved=[p[@"subtitleSize"]intValue]==28&&[p[@"subtitleDelay"]doubleValue]==0&&[p[@"subtitleLanguage"]isEqual:@"en"]&&[p[@"subtitlesEnabled"]boolValue]&&adjustments.count==1;
    NSDictionary *overlay=adjustments.allValues.firstObject;
    saved=saved&&fabs([overlay[@"delay"]doubleValue]-.5)<.01&&[overlay[@"encoding"]isEqual:@"auto"];
    BOOL rendered=fabs([state[@"subtitle_font"]doubleValue]-28)<.01;
    BOOL off=[kind isEqual:@"prefs-audit-off"]||[kind isEqual:@"prefs-audit-restored"];
    BOOL ok=saved&&rendered&&![state[@"transient"]boolValue]&&[state[@"persistence_profile"]isEqual:store.state[@"activeProfile"]]&&![state[@"wants_play"]boolValue];
    if(off)ok=ok&&choice&&! [choice[@"enabled"]boolValue]&&![state[@"subtitle_enabled"]boolValue]&&![state[@"subtitle_text"]length]&&![state[@"subtitle_cues"]intValue]&&[state[@"embedded_subtitle"]intValue]==-1&&[state[@"subtitle_delay"]doubleValue]==0;
    else if([kind isEqual:@"prefs-audit-embedded"])ok=ok&&[choice[@"enabled"]boolValue]&&[state[@"subtitle_identity"][@"stable"]boolValue]&&[choice[@"token"]isEqual:state[@"subtitle_identity"][@"token"]]&&[state[@"embedded_subtitle"]intValue]>=0&&[state[@"embedded_delay"]doubleValue]==0&&[state[@"subtitle_delay"]doubleValue]==0&&!adjustments[state[@"subtitle_adjustment_key"]];
    else if([@[@"prefs-audit-settings",@"prefs-audit-overlay",@"prefs-audit-overlay-return"]containsObject:kind])ok=ok&&[choice[@"enabled"]boolValue]&&[choice[@"token"]isEqual:state[@"subtitle_identity"][@"token"]]&&[state[@"subtitle_cues"]intValue]==2&&[state[@"subtitle_text"]hasPrefix:@"English subtitle:"]&&fabs([state[@"subtitle_delay"]doubleValue]-.5)<.01&&[adjustments[state[@"subtitle_adjustment_key"]]isEqual:overlay];
    else return NO;
    RWCapture(self.exercisePlayer.view,[NSString stringWithFormat:@"device-exercise-%@-%@",self.exerciseRequest[@"action"],kind]);return ok;
}
