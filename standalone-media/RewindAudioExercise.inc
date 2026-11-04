// Generated, multitrack CC0 fixtures. Normal audio menus/persistence operate
// only inside the existing guarded temporary profile; real profiles unchanged.
- (BOOL)exerciseAudioStep:(NSString *)kind {
    RewindStore *store=RewindStore.shared;BOOL mkv=[self.exerciseRequest[@"action"]hasSuffix:@"-mkv"];
    NSInteger build=[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue];NSString *key=store.state[@"activeProfile"];NSDictionary *parent=store.state[@"profiles"][@"rw-device-resume-check"];
    BOOL owned=[key isEqual:@"rw-device-resume-check"]&&[RWDeviceExercise ownsResumeProfile:store.profile build:build];
    owned=owned||([key isEqual:@"rw-device-audio-other"]&&[RWDeviceExercise ownsAudioCompanion:store.profile parent:parent build:build]);
    if(!self.exerciseResumeOwned||!owned)return NO;
    if([kind isEqual:@"audio-profile-other"]||[kind isEqual:@"audio-profile-primary"]){
        if(![self.exerciseRequest[@"action"]hasPrefix:@"audio-open-"]||self.presentedViewController)return NO;
        NSString *target=@"rw-device-resume-check";
        if([kind isEqual:@"audio-profile-other"]){
            target=@"rw-device-audio-other";if(![key isEqual:@"rw-device-resume-check"]||store.state[@"profiles"][target])return NO;
            NSMutableDictionary *other=[RWProfiles make:@"Device audio other" age:-1];other[@"autoplayTrailers"]=@NO;other[@"sources"][@"rw:audio-owner"]=[parent[@"sources"][@"rw:resume-owner"]copy];store.state[@"profiles"][target]=other;
        }else if(![key isEqual:@"rw-device-audio-other"])return NO;
        self.exerciseProfile=target;[self selectProfile:target];[store setDiscoveryPaused:YES];return YES;
    }
    if([kind isEqual:@"audio-play"]||[kind isEqual:@"audio-other-play"]||[kind isEqual:@"audio-fallback-play"]||[kind isEqual:@"audio-name-play"]){
        if(self.presentedViewController)return NO;[self stopPreview];[self.playbackPreparation cancel];[store setDiscoveryPaused:YES];
        NSString *identifier=[NSString stringWithFormat:@"rw:audio-%@%@",mkv?@"mkv":@"native",[kind isEqual:@"audio-other-play"]?@"-other":[kind isEqual:@"audio-fallback-play"]?@"-fallback":[kind isEqual:@"audio-name-play"]?@"-named":@""];
        NSDictionary *meta=@{@"id":identifier,@"type":@"movie",@"name":@"Audio selection check"};
        NSDictionary *source=@{@"name":@"Generated CC0 multitrack clip",@"url":[NSString stringWithFormat:@"asset:audio-%@.%@",[kind isEqual:@"audio-fallback-play"]?@"fallback":[kind isEqual:@"audio-name-play"]?@"named":@"check",mkv?@"mkv":@"mp4"]};
        RewindPlayer *player=[[RewindPlayer alloc]initWithMeta:meta videoID:identifier source:source resume:0];if(![player beginAudioExercise])return NO;if(self.exerciseRequest[@"legacy_font"]&&![player beginLegacyFontExercise:self.exerciseRequest[@"legacy_font"]])return NO;self.exercisePlayer=player;
        __weak RewindController *weak=self;player.onClose=^{[weak syncDiscoveryActivity];[weak render];};self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;self.exercisePausedPosition=0;
        [self presentViewController:player animated:YES completion:nil];return YES;
    }
    NSDictionary *state=[self.exercisePlayer deviceExerciseSnapshot],*selection=state[@"audio_selection"],*track=selection[@"track"];
    if([kind hasPrefix:@"audio-await-"]){
        if([state[@"exhausted"]boolValue]||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>35)return NO;
        NSString *want=[kind substringFromIndex:[@"audio-await-" length]],*language=([want isEqual:@"unknown"]||[want isEqual:@"named"])?@"":[want isEqual:@"pl"]?@"pl":[want isEqual:@"fr"]?@"fr":@"en",*role=[want isEqual:@"description"]?@"description":[want isEqual:@"commentary"]?@"commentary":@"main";
        BOOL ready=[state[@"media_verified"]boolValue]&&[state[@"frame_visible"]boolValue]&&[state[@"position"]doubleValue]>=2&&[track[@"language"]isEqual:language]&&[track[@"role"]isEqual:role];
        if([want isEqual:@"named"])ready=ready&&[track[@"language_hint"]isEqual:@"en"]&&[track[@"language_evidence"]isEqual:@"track_name"];
        if([want isEqual:@"en"])ready=ready&&[track[@"channels"]intValue]==6;
        if(!ready)self.exerciseIndex--;return YES;
    }
    if([kind hasPrefix:@"audio-audit-"]){
        NSString *audit=[kind substringFromIndex:[@"audio-audit-" length]];BOOL ok=![state[@"transient"]boolValue]&&[state[@"persistence_profile"]isEqual:key];
        if([audit isEqual:@"menu"]){NSArray *menu=state[@"menu_actions"];ok=ok&&[menu containsObject:@"French · Stereo"]&&[menu containsObject:@"English · 5.1 · Selected"]&&[menu containsObject:@"English · Commentary · Stereo"];}
        else if([audit isEqual:@"saved"]||[audit isEqual:@"reopened"]||[audit isEqual:@"return"]){NSDictionary *saved=store.profile[@"audioSelections"][state[@"video_id"]];ok=ok&&[track[@"language"]isEqual:@"fr"]&&[saved[@"token"]isEqual:track[@"token"]]&&[saved[@"media_key"]length]==64;if([audit isEqual:@"reopened"]||[audit isEqual:@"return"])ok=ok&&[selection[@"reason"]isEqual:@"saved_track"];}
        else if([audit isEqual:@"named"])ok=ok&&[track[@"language"]isEqual:@""]&&[track[@"language_hint"]isEqual:@"en"]&&[track[@"language_evidence"]isEqual:@"track_name"]&&[track[@"role"]isEqual:@"main"]&&[track[@"channels"]intValue]==6&&[selection[@"reason"]isEqual:@"preferred_language_name"];
        else if([audit isEqual:@"named-menu"])ok=ok&&[state[@"menu_actions"]containsObject:@"English (track name) · 5.1 · Selected"]&&[state[@"menu_actions"]containsObject:@"Polish · Stereo"];
        else if([audit isEqual:@"polish"]||[audit isEqual:@"polish-reopened"])ok=ok&&[track[@"language"]isEqual:@"pl"]&&[selection[@"reason"]isEqual:[audit isEqual:@"polish-reopened"]?@"saved_track":@"manual"]&&[store.profile[@"audioSelections"][state[@"video_id"]][@"token"]isEqual:track[@"token"]];
        else if([audit isEqual:@"fallback"])ok=ok&&![track[@"language"]length]&&[track[@"role"]isEqual:@"main"]&&[track[@"default"]boolValue]&&[selection[@"reason"]isEqual:@"fallback"]&&[selection[@"message"]hasPrefix:@"No compatible English main track identified."]&&[selection[@"message"]rangeOfString:@"Unknown language"].location!=NSNotFound;
        else if([audit isEqual:@"fallback-menu"]){NSArray *menu=state[@"menu_actions"];ok=ok&&[menu containsObject:@"Unknown language · 5.1 · Selected"]&&[menu containsObject:@"French · Stereo"]&&[menu containsObject:@"English · Audio description · Stereo"];}
        else if([audit isEqual:@"description"])ok=ok&&[track[@"language"]isEqual:@"en"]&&[track[@"role"]isEqual:@"description"]&&[store.profile[@"audioSelections"][state[@"video_id"]][@"role"]isEqual:@"description"];
        else if([audit isEqual:@"commentary"])ok=ok&&[track[@"role"]isEqual:@"commentary"]&&[store.profile[@"audioSelections"][state[@"video_id"]][@"role"]isEqual:@"commentary"];
        else if([audit isEqual:@"other"]||[audit isEqual:@"profile-default"])ok=ok&&[track[@"language"]isEqual:@"en"]&&[track[@"role"]isEqual:@"main"]&&!store.profile[@"audioSelections"][state[@"video_id"]];
        else return NO;
        RWCapture(self.exercisePlayer.presentedViewController?self.exercisePlayer.presentedViewController.view:self.exercisePlayer.view,[NSString stringWithFormat:@"device-exercise-%@-%@",self.exerciseRequest[@"action"],audit]);return ok;
    }
    return [self.exercisePlayer deviceExerciseControl:kind];
}
