// Generated CC0 clip through the production native/MKV players and shared
// subtitle action handlers. No history, preferences or source-health fixtures.
- (BOOL)exerciseSubtitleStep:(NSString *)kind {
    BOOL mkv=[self.exerciseRequest[@"action"]hasSuffix:@"-mkv"];BOOL layout=[@[@"subtitles-layout-native",@"subtitles-layout-mkv",@"subtitles-layout-native-landscape"]containsObject:self.exerciseRequest[@"action"]];
    BOOL frameClock=[self.exerciseRequest[@"action"]isEqual:@"subtitles-frames-mkv"];
    BOOL timing=[@[@"subtitles-timing-native",@"subtitles-timing-mkv",@"subtitles-frames-mkv"]containsObject:self.exerciseRequest[@"action"]];
    BOOL fontCaptions=[self.exerciseRequest[@"action"]isEqual:@"subtitles-font-mkv"];
    if([kind isEqual:@"subtitle-play"]){
        RewindStore *store=[RewindStore shared];if(store.restricted||self.presentedViewController)return NO;
        [self stopPreview];[self.playbackPreparation cancel];[store setDiscoveryPaused:YES];
        NSString *identifier=fontCaptions?@"rw:font-captions":mkv?@"rw:subtitle-mkv":@"rw:subtitle-native";
        NSDictionary *meta=@{@"id":identifier,@"type":@"movie",@"name":@"Subtitle check"};
        NSDictionary *source=@{@"name":@"Generated CC0 test clip",@"url":mkv?@"asset:subtitle-check.mkv":@"asset:subtitle-check.mp4",@"subtitles":@[@{@"name":@"English · Text file",@"lang":@"en",@"url":@"asset:subtitle-check.en.srt"}]};
        if([self.exerciseRequest[@"action"]isEqual:@"subtitles-text"]){
            NSMutableArray *files=[NSMutableArray new];for(NSString *name in @[@"unicode",@"cyrillic",@"central",@"overlap"])[files addObject:@{@"name":name,@"lang":@"und",@"url":[NSString stringWithFormat:@"asset:subtitle-text-%@.%@",name,[name isEqual:@"overlap"]?@"vtt":@"srt"]}];
            source=@{@"name":@"Generated CC0 test clip",@"url":@"asset:subtitle-check.mp4",@"subtitles":files};
        }
        if(timing)source=@{@"name":@"Original timing fixture",@"url":mkv?@"asset:subtitle-check.mkv":@"asset:subtitle-check.mp4",@"subtitles":@[@{@"name":@"Timing sample",@"lang":@"und",@"url":@"asset:subtitle-timing.srt"}]};
        if(frameClock)source=@{@"name":@"Authored frame-code clip",@"url":@"asset:subtitle-frame-clock.mkv",@"subtitles":@[@{@"name":@"Timing sample",@"lang":@"und",@"url":@"asset:subtitle-timing.srt"}]};
        if(layout){NSMutableArray *files=[NSMutableArray new];for(NSString *name in @[@"short",@"long",@"international",@"rtl"])[files addObject:@{@"name":name,@"lang":@"und",@"url":[NSString stringWithFormat:@"asset:subtitle-layout-%@.srt",name]}];source=@{@"name":@"Generated CC0 layout clip",@"url":mkv?@"asset:subtitle-check.mkv":@"asset:subtitle-check.mp4",@"subtitles":files};}
        if(fontCaptions)source=@{@"name":@"Generated CC0 font samples",@"url":@"asset:subtitle-font-check.mkv"};
        RewindPlayer *player=[[RewindPlayer alloc]initWithMeta:meta videoID:[identifier stringByAppendingString:@":preview"] source:source resume:0];[player beginSubtitleExercise];if(self.exerciseRequest[@"legacy_font"]&&![player beginLegacyFontExercise:self.exerciseRequest[@"legacy_font"]])return NO;if(layout&&![player beginSubtitleLayoutOrientation:self.exerciseTargetOrientation])return NO;self.exercisePlayer=player;
        __weak RewindController *weak=self;player.onClose=^{[weak syncDiscoveryActivity];[weak render];};self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;self.exercisePausedPosition=0;
        [self presentViewController:player animated:YES completion:nil];return [[player deviceExerciseSnapshot][@"transient"]boolValue];
    }
    if([kind isEqual:@"subtitle-layout-await-close"]){
        if(!layout||![[self.exercisePlayer deviceExerciseSnapshot][@"closing"]boolValue]||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>140)return NO;
        if(self.presentedViewController){if(self.presentedViewController!=self.exercisePlayer)return NO;self.exerciseIndex--;}return YES;
    }
    NSDictionary *state=[self.exercisePlayer deviceExerciseSnapshot];if(!state||![state[@"transient"]boolValue]||[state[@"closing"]boolValue])return NO;
    if([kind isEqual:@"subtitle-await"]){
        if([state[@"exhausted"]boolValue]||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>35)return NO;
        if(![state[@"media_verified"]boolValue]||![state[@"frame_visible"]boolValue]||[state[@"position"]doubleValue]<3)self.exerciseIndex--;return YES;
    }
    if([kind hasPrefix:@"subtitle-font-"]){
        if(!fontCaptions||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>100)return NO;
        if([kind isEqual:@"subtitle-font-off"])return [state[@"embedded_subtitle"]intValue]==-1&&![state[@"subtitle_enabled"]boolValue];
        NSInteger index=[[[kind componentsSeparatedByString:@":"]lastObject]integerValue];if(index<1||index>5)return NO;
        double target=5+(index-1)*12,position=[state[@"position"]doubleValue];
        if(![state[@"media_verified"]boolValue]||![state[@"frame_visible"]boolValue]||[state[@"embedded_subtitle"]intValue]<0)return NO;
        if([kind hasPrefix:@"subtitle-font-await:"]){if(![state[@"wants_play"]boolValue]||position>target+3)return NO;if(position<target)self.exerciseIndex--;return YES;}
        if(![kind hasPrefix:@"subtitle-font-audit:"]||[state[@"wants_play"]boolValue]||position<target-.5||position>target+3)return NO;
        NSDictionary *frame=state[@"subtitle_frames"][[NSString stringWithFormat:@"font-%ld",(long)index]];
        NSString *expected=self.exerciseRequest[@"legacy_font"]?:@"HelveticaNeue";
        return [frame[@"status"]isEqual:@"complete"]&&[state[@"embedded_metrics"][@"startup_font"]isEqual:expected];
    }
    if([kind hasPrefix:@"subtitle-clock-"]){
        if(!frameClock||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>90)return NO;
        NSDictionary *clock=state[@"embedded_metrics"][@"caption_clock"];
        double raw=[state[@"position"]doubleValue],caption=[state[@"subtitle_position"]doubleValue];
        NSString *value=[[kind componentsSeparatedByString:@":"]lastObject];
        if([kind hasPrefix:@"subtitle-clock-seek:"]){
            if([state[@"wants_play"]boolValue]||![@[@"12",@"6"]containsObject:value])return NO;
            return [self.exercisePlayer deviceExerciseControl:kind];
        }
        if([kind isEqual:@"subtitle-clock-await:running"]){
            if(![state[@"wants_play"]boolValue])return NO;
            if(![clock[@"coherent"]boolValue]){self.exerciseIndex--;return YES;}
            return [clock[@"requested"]boolValue]&&[clock[@"running"]boolValue]&&![clock[@"buffering"]boolValue]&&caption>=raw&&caption<=raw+.301&&[clock[@"estimates"]integerValue]>0;
        }
        if([kind hasPrefix:@"subtitle-clock-await:"]){
            if([state[@"wants_play"]boolValue]||![@[@"12",@"6"]containsObject:value])return NO;
            if(fabs(raw-value.doubleValue)>.05){self.exerciseIndex--;return YES;}
            return fabs(caption-raw)<.001&&![clock[@"coherent"]boolValue];
        }
        if([kind hasPrefix:@"subtitle-clock-audit:"])return ![state[@"wants_play"]boolValue]&&![state[@"subtitle_refresh_active"]boolValue]&&![clock[@"requested"]boolValue]&&![clock[@"coherent"]boolValue]&&fabs(raw-caption)<.001&&fabs(raw-self.exercisePausedPosition)<.1;
        return NO;
    }
    if([kind hasPrefix:@"subtitle-timing-"]){
        if(!timing||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>100)return NO;
        if([kind isEqual:@"subtitle-timing-decoded"]){if([state[@"wants_play"]boolValue])return NO;if(![state[@"subtitle_decode"][@"status"]isEqual:@"ok"])self.exerciseIndex--;return YES;}
        if([kind isEqual:@"subtitle-timing-load-await"]){NSString *status=state[@"subtitle_load"][@"status"];if([status isEqual:@"running"]){self.exerciseIndex--;return YES;}return [status isEqual:@"complete"]&&[state[@"subtitle_load"][@"checks"]integerValue]==10000&&![state[@"subtitle_load"][@"failures"]integerValue];}
        if([kind isEqual:@"subtitle-timing-await"]){if(![state[@"wants_play"]boolValue]||![state[@"subtitle_timing"][@"status"]isEqual:@"running"])return NO;if([state[@"position"]doubleValue]<23.8)self.exerciseIndex--;return YES;}
        if([kind isEqual:@"subtitle-timing-audit"]){if(![self.exercisePlayer deviceExerciseControl:@"subtitle-timing-stop"])return NO;NSDictionary *d=[self.exercisePlayer subtitleTimingEvidence][@"timing"];return [d[@"status"]isEqual:@"completed"]&&[d[@"samples"]integerValue]>200&&[state[@"subtitle_cues"]integerValue]==24;}
        if([kind isEqual:@"subtitle-timing-off"])return ![state[@"subtitle_text"]length]&&![state[@"subtitle_cues"]integerValue]&&[state[@"subtitle_layout"][@"hidden"]boolValue];
        return [self.exercisePlayer deviceExerciseControl:kind];
    }
    if([kind hasPrefix:@"subtitle-layout-"]){
        if(!layout||[state[@"wants_play"]boolValue]||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>140)return NO;
        if([kind isEqual:@"subtitle-layout-toggle"])return [self.exercisePlayer deviceExerciseControl:kind];
        if([kind isEqual:@"subtitle-layout-await"]){if(![state[@"subtitle_decode"][@"status"]isEqual:@"ok"]||![state[@"subtitle_text"]length])self.exerciseIndex--;return YES;}
        if(![kind hasPrefix:@"subtitle-layout-audit:"])return NO;
        NSArray *parts=[kind componentsSeparatedByString:@":"];if(parts.count!=4)return NO;
        NSDictionary *d=state[@"subtitle_layout"];NSArray *frame=d[@"frame"],*screen=state[@"player_size"];
        BOOL off=[parts[2]isEqual:@"off"],hidden=[parts[3]isEqual:@"hidden"],portrait=[parts[1]isEqual:@"portrait"];
        BOOL ok=portrait?([screen[1]doubleValue]>[screen[0]doubleValue]):([screen[0]doubleValue]>[screen[1]doubleValue]);
        if(off)ok=ok&&[d[@"hidden"]boolValue]&&![state[@"subtitle_text"]length]&&![state[@"subtitle_enabled"]boolValue];
        else{CGFloat size=[parts[3]isEqual:@"Small"]?20:[parts[3]isEqual:@"Medium"]?24:28;
            ok=ok&&[state[@"subtitle_decode"][@"status"]isEqual:@"ok"]&&[state[@"subtitle_name"]isEqual:parts[2]]&&!self.exercisePlayer.presentedViewController&&![d[@"hidden"]boolValue]&&![d[@"truncated"]boolValue]&&fabs([d[@"font"]doubleValue]-size)<.01;
            ok=ok&&[frame[0]doubleValue]>=32&&[frame[0]doubleValue]+[frame[2]doubleValue]<=[screen[0]doubleValue]-31&&[frame[1]doubleValue]>=64&&[frame[1]doubleValue]+[frame[3]doubleValue]<=[screen[1]doubleValue]-(hidden?31:204);
            ok=ok&&(hidden?([state[@"controls_alpha"]doubleValue]<.01):([state[@"controls_alpha"]doubleValue]>.99));
        }
        NSString *capture=[@"device-exercise-" stringByAppendingString:[kind stringByReplacingOccurrencesOfString:@":" withString:@"-"]],*path=[[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"]stringByAppendingPathComponent:[capture stringByAppendingPathExtension:@"png"]];
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];RWCapture(self.exercisePlayer.view,capture);return ok&&[[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil]fileSize]>0;
    }
    if([kind hasPrefix:@"subtitle-text-"]){
        if(![self.exerciseRequest[@"action"]isEqual:@"subtitles-text"]||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>90)return NO;
        if([kind isEqual:@"subtitle-text-await:advancing"]){if(![state[@"wants_play"]boolValue])return NO;if([state[@"position"]doubleValue]<12)self.exerciseIndex--;return YES;}
        if([state[@"wants_play"]boolValue])return NO;
        NSString *name=[[kind componentsSeparatedByString:@":"]lastObject];NSDictionary *decode=state[@"subtitle_decode"];
        if([kind hasPrefix:@"subtitle-text-seek:"])return [self.exercisePlayer deviceExerciseControl:kind];
        if([kind hasPrefix:@"subtitle-text-await:"]){BOOL ready=[name isEqual:@"encoding"]?[state[@"menu"]isEqual:@"Subtitle text"]:[decode[@"status"]isEqual:@"ok"];if(!ready)self.exerciseIndex--;return YES;}
        if(![kind hasPrefix:@"subtitle-text-audit:"])return NO;BOOL ok=YES;
        if([name isEqual:@"encoding"])ok=[decode[@"status"]isEqual:@"needs_encoding"]&&![state[@"subtitle_text"]length]&&[state[@"menu_actions"]containsObject:@"Cyrillic"];
        else if([name isEqual:@"off"])ok=![state[@"subtitle_text"]length]&&![state[@"subtitle_cues"]integerValue]&&![state[@"subtitle_enabled"]boolValue];
        else{NSDictionary *expected=@{@"unicode":@"Café — Привет & friends",@"cyrillic":@"Привет мир",@"central":@"Příliš žluťoučký",@"overlap":@"Long & steady\nShort line",@"older":@"Long & steady"};ok=[decode[@"status"]isEqual:@"ok"]&&[state[@"subtitle_text"]isEqual:expected[name]];}
        RWCapture(self.exercisePlayer.presentedViewController?self.exercisePlayer.presentedViewController.view:self.exercisePlayer.view,[@"device-exercise-subtitles-text-" stringByAppendingString:name]);return ok;
    }
    if([kind hasPrefix:@"subtitle-frame:"]){
        NSString *label=[kind substringFromIndex:[@"subtitle-frame:" length]];
        if(!mkv||![self.exercisePlayer deviceExerciseControl:kind])return NO;
        NSDictionary *capture=[self.exercisePlayer deviceExerciseSnapshot][@"subtitle_frames"][label];
        if([capture[@"status"]isEqual:@"pending"]){if(NSProcessInfo.processInfo.systemUptime-[capture[@"started"]doubleValue]>8)return NO;self.exerciseIndex--;return YES;}
        return [capture[@"status"]isEqual:@"complete"]&&![capture[@"wants_play"]boolValue]&&fabs([capture[@"position_before"]doubleValue]-[capture[@"position_after"]doubleValue])<.05;
    }
    if(![kind hasPrefix:@"subtitle-audit-"])return [self.exercisePlayer deviceExerciseControl:kind];
    NSString *captureAudit=[kind substringFromIndex:[@"subtitle-audit-" length]],*audit=captureAudit;if([audit hasSuffix:@"-settled"])audit=[audit substringToIndex:audit.length-[@"-settled" length]];NSRange sample=[audit rangeOfString:@"-sample"];if(sample.location!=NSNotFound)audit=[audit substringToIndex:sample.location];BOOL ok=YES;NSArray *menu=state[@"menu_actions"];
    if([audit isEqual:@"menu"]){ok=[state[@"menu"]isEqual:@"Subtitles"]&&[menu containsObject:@"Off"]&&[menu containsObject:@"English · Text file"]&&[menu containsObject:@"Add subtitle link…"];if(mkv)ok=ok&&[state[@"embedded_tracks"]count]>=2;}
    else if([@[@"embedded",@"embedded-delay",@"embedded-french",@"embedded-return"]containsObject:audit]){ok=mkv&&[state[@"embedded_subtitle"]intValue]>=0&&![state[@"subtitle_cues"]integerValue]&&[RWSubtitles language:state[@"subtitle_name"] matches:[audit isEqual:@"embedded-french"]?@"fr":@"en"];if([audit isEqual:@"embedded-delay"])ok=ok&&fabs([state[@"embedded_delay"]doubleValue]-.5)<.01;}
    else if([audit isEqual:@"settings"])ok=[state[@"menu"]isEqual:@"Subtitle size and timing"]&&[menu containsObject:@"Large"]&&[menu containsObject:@"Reset timing"];
    else if([audit isEqual:@"font"])ok=fabs([state[@"subtitle_font"]doubleValue]-28)<.01;
    else if([audit isEqual:@"off"]||[audit isEqual:@"embedded-off"])ok=![state[@"subtitle_text"]length]&&![state[@"subtitle_cues"]integerValue]&&[state[@"embedded_subtitle"]intValue]==-1&&![state[@"subtitle_enabled"]boolValue];
    else if([@[@"first",@"second",@"delay"]containsObject:audit]){NSString *text=[audit isEqual:@"second"]?@"English subtitle: second passage":@"English subtitle: first passage";ok=[state[@"subtitle_text"]isEqual:text]&&[state[@"subtitle_cues"]integerValue]==2&&[state[@"embedded_subtitle"]intValue]==-1;if([audit isEqual:@"delay"])ok=ok&&fabs([state[@"subtitle_delay"]doubleValue]-.5)<.01;}
    else return NO;
    UIView *view=self.exercisePlayer.presentedViewController?self.exercisePlayer.presentedViewController.view:self.exercisePlayer.view;
    NSString *name=[NSString stringWithFormat:@"device-exercise-%@-%@",self.exerciseRequest[@"action"],captureAudit];NSString *path=[[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"]stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]];
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];[view layoutIfNeeded];[self.exercisePlayer deviceExerciseControl:[@"subtitle-capture:begin/" stringByAppendingString:captureAudit]];RWCapture(view,name);[self.exercisePlayer deviceExerciseControl:[@"subtitle-capture:end/" stringByAppendingString:captureAudit]];return ok&&[[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil]fileSize]>0;
}
