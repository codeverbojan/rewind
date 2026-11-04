// Player source lifecycle: one libtorrent session, bounded retries, verified media.
- (void)adoptPreparedEngine {
    self.engine=self.preparedEngine;self.preparedEngine=nil;double now=NSProcessInfo.processInfo.systemUptime;
    self.startupBegan=self.attemptStarted=self.lastProgress=self.lastDownloadProgress=now;self.lastPosition=-1;
    self.wantsPlay=YES;self.discovering=YES;self.refreshing=NO;_motion.reset(now);
    [self.metrics setContext:@{@"preparation":self.preparationReport?:@{}}];
    [self.metrics markStage:@"discovery_started" uptime:now];
    NSArray *ranked=[self.ranked copy];NSUInteger generation=self.playbackGeneration;__weak RewindPlayer *weak=self;
    BOOL transportDiagnostics=self.deviceExerciseEnabled&&self.transient;
    [self.engine perform:^(TorrentEngine *engine){
        [engine setTransportDiagnosticsEnabled:transportDiagnostics];
        BOOL adopted=[engine adoptPreparation];if(adopted)[engine appendCandidates:ranked];
        dispatch_async(dispatch_get_main_queue(),^{
            if(!weak||weak.closing||weak.playbackGeneration!=generation)return;
            [weak.metrics recordEvent:@"preparation_handoff" values:@{@"adopted":@(adopted)} uptime:NSProcessInfo.processInfo.systemUptime];
            if(adopted)[weak.metrics markStage:@"preparation_adopted" uptime:NSProcessInfo.processInfo.systemUptime];
            else{weak.discovering=NO;[weak startNextSource];}
        });
    }];
    if(self.automaticSources)[self lookupSources:NO];[self updatePlayback];
}
- (instancetype)initWithMeta:(NSDictionary *)meta videoID:(NSString *)videoID candidates:(NSArray *)candidates quality:(NSInteger)quality resume:(double)resume {
    if((self=[self initWithMeta:meta videoID:videoID source:@{} resume:resume])){self.automaticSources=YES;self.candidates=[RWSourcePolicy sources:[[RewindStore shared]withSourceExperience:candidates] withMeta:meta videoID:videoID];self.quality=quality;self.ranked=[RWSourcePolicy rank:self.candidates quality:quality freeBytes:0];}return self;
}
- (void)stopCurrentSource {
    [self clearSubtitles];self.playbackGeneration++;self.nativeSeekPending=NO;_nativeBufferRecovery=RWNativeBufferRecovery();self.enginePollPending=NO;self.captionGroup=nil;self.mediaSelectionLoaded=NO;self.verifyingMedia=NO;self.torrentSubtitleFiles=nil;self.audioChoices=nil;self.audioSelection=nil;[self pauseMedia];
    if(self.observer){[self.player removeTimeObserver:self.observer];self.observer=nil;}
    if(self.observed){[self.player.currentItem removeObserver:self forKeyPath:@"status"];self.observed=NO;}
    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem];
    [self.legacy stop];self.legacy=nil;
    self.video.player=nil;[self.loader stop];self.loader=nil;self.player=nil;[self.engine pause];self.mediaVerified=NO;self.hasStartedPlayback=NO;self.resumed=NO;
}
- (void)showUnavailable:(NSString *)message {
    if(!self.transient)[[RewindStore shared]notePlaybackFailure:self.meta videoID:self.videoID source:nil];
    [self stopCurrentSource];self.exhausted=YES;self.discovering=NO;self.refreshing=NO;self.wantsPlay=NO;[self.engine pause];[self.spinner stopAnimating];self.controls.alpha=1;
    self.loadingTitle.text=@"No ready source right now";self.loadingDetail.text=message;self.retryButton.hidden=NO;
    self.statusLabel.text=@"Choose another quality or try again";[self updatePlayback];
    [self.metrics recordEvent:@"playback_unavailable" values:@{@"reason":message?:@"",@"candidate_count":@(self.candidates.count),@"eligible_count":@(self.ranked.count)} uptime:NSProcessInfo.processInfo.systemUptime];
    [[RewindStore shared]report:@{@"playback_attempts":self.attempts,@"playback_exhausted":@YES,@"player_ready":@NO,@"playback_failure_reason":message?:@""}];
}
- (void)startNextSource {
    if(self.closing)return;[self.metrics setExpectedStartPosition:self.resumePosition];self.refreshing=NO;double now=NSProcessInfo.processInfo.systemUptime;if(!self.startupBegan)self.startupBegan=now;
    NSArray *remaining=[self remainingSources];
    if(!remaining.count&&self.sourceLookupPending&&self.attempts.count<5&&now-self.startupBegan<RWStartupLimitSeconds){self.refreshing=YES;self.discovering=NO;self.loadingTitle.text=@"Checking available sources";self.loadingDetail.text=@"Looking for another connection…";[self.spinner startAnimating];return;}
    if(!remaining.count||self.attempts.count>=5||now-self.startupBegan>=RWStartupLimitSeconds){[self showUnavailable:@"No compatible source became ready. Try again shortly or choose another quality."];return;}
    _motion.reset(now);self.automaticSubtitlesTried=NO;self.recordedGoodSource=NO;self.lastTorrentSnapshot=nil;self.source=remaining[0];self.attemptStarted=self.lastProgress=self.lastDownloadProgress=now;self.lastPosition=-1;self.lastPayload=0;self.wantsPlay=YES;self.exhausted=NO;self.retryButton.hidden=YES;
    self.controls.alpha=1;self.statusLabel.text=@"Selecting a live connection";self.loadingTitle.text=@"Finding a fast source";self.loadingDetail.text=@"Checking available sources automatically…";[self.spinner startAnimating];
    [self.qualityButton setTitle:self.quality?[NSString stringWithFormat:@"%ldp",(long)self.quality]:@"Auto" forState:UIControlStateNormal];
    [[RewindStore shared]report:@{@"player_ready":@NO,@"playback_exhausted":@NO,@"selected_quality":@(self.quality),@"playback_attempts":self.attempts}];
    NSString *url=RWString(self.source[@"url"]);
    if([url hasPrefix:@"magnet:"]){
        [self.metrics markStage:@"discovery_started" uptime:now];
        if(!self.engine)self.engine=[TorrentEngine new];self.discovering=YES;BOOL transportDiagnostics=self.deviceExerciseEnabled&&self.transient;[self.engine perform:^(TorrentEngine *engine){[engine setTransportDiagnosticsEnabled:transportDiagnostics];[engine startCandidates:remaining];}];
    }else{
        self.discovering=NO;[self.metrics beginAttemptAtUptime:now];
        NSDictionary *identity=@{@"transport":[url hasPrefix:@"asset:"]?@"bundled":@"direct",@"provider":self.source[@"provider"]?:@"",@"quality":@(self.quality)};
        [self.metrics setContext:@{@"selected_source":identity}];[self.metrics recordEvent:@"source_selected" values:identity uptime:now];
        NSURL *u=[url hasPrefix:@"asset:"]?[NSURL fileURLWithPath:[[[NSBundle mainBundle]resourcePath]stringByAppendingPathComponent:[@"Rewind/" stringByAppendingString:[url substringFromIndex:6]]]]:[NSURL URLWithString:url];
        if([u.pathExtension.lowercaseString isEqual:@"mkv"]){[self prepareLegacy:u.isFileURL?u.path:u.absoluteString];return;}
        if(u)[self prepareItem:[AVPlayerItem playerItemWithURL:u]];else [self failSource:@"This source has no playable address."];
    }
    [self updatePlayback];
}
- (void)sourceResultsUpdated:(NSNotification *)note {
    if(self.closing||!self.automaticSources||![note.userInfo[@"videoID"]isEqual:self.videoID]||![note.userInfo[@"type"]isEqual:self.meta[@"type"]]||![note.userInfo[@"profile"]isEqual:[RewindStore shared].state[@"activeProfile"]])return;
    [self acceptSourceResults:note.userInfo[@"sources"] error:nil];
}
- (void)sourceLookupMeasured:(NSNotification *)note {
    if(self.closing||!self.automaticSources)return;
    [self.metrics recordLookupObservation:note.userInfo quality:self.quality uptime:NSProcessInfo.processInfo.systemUptime];
}
- (void)acceptSourceResults:(NSArray *)sources error:(NSString *)error {
    self.candidates=[RWSourcePolicy sources:[[RewindStore shared]withSourceExperience:sources?:@[]] withMeta:self.meta videoID:self.videoID];NSDictionary *disk=[[NSFileManager defaultManager]attributesOfFileSystemForPath:RWDocuments() error:nil];
    self.ranked=[RWSourcePolicy rank:self.candidates quality:self.quality freeBytes:[disk[NSFileSystemFreeSize]unsignedLongLongValue]];
    NSArray *remaining=[self remainingSources];
    NSMutableDictionary *reasons=[NSMutableDictionary new];NSMutableArray *excluded=[NSMutableArray new];NSUInteger exclusionCount=0;
    for(NSDictionary *source in self.candidates){NSDictionary *evaluation=[RWSourcePolicy evaluate:source quality:self.quality freeBytes:0];NSString *reason=evaluation[@"rejection"];if(reason.length)reasons[reason]=@([reasons[reason]integerValue]+1);
        if([evaluation[@"verifiedMediaRejectionApplied"]boolValue]){exclusionCount++;if(excluded.count<16){NSDictionary *proof=source[@"localMediaRejection"];[excluded addObject:@{@"key":proof[@"key"],@"code":proof[@"code"],@"observed_at":proof[@"at"]}];}}
    }
    [self.metrics recordEvent:@"source_policy_evaluated" values:@{@"candidates":@(self.candidates.count),@"eligible":@(self.ranked.count),@"local_media_exclusion_count":@(exclusionCount),@"local_media_exclusions":excluded,@"exclusion_record_limit":@16} uptime:NSProcessInfo.processInfo.systemUptime];
    [[RewindStore shared]report:@{@"source_query":self.videoID?:@"",@"source_candidates":@(self.candidates.count),@"source_eligible":@(self.ranked.count),@"source_rejections":reasons,@"source_error":error?:@""}];
    [self.metrics recordEvent:@"source_candidates_evaluated" values:@{@"total":@(self.candidates.count),@"eligible":@(self.ranked.count),@"rejections":reasons} uptime:NSProcessInfo.processInfo.systemUptime];
    RWSourceUpdate action=RWSourceUpdateDecision(remaining.count>0,self.discovering,self.refreshing,self.exhausted,self.player!=nil||self.legacy!=nil,NSProcessInfo.processInfo.systemUptime-self.startupBegan,int(self.attempts.count));
    if(action==RWSourceUpdate::Append)[self.engine perform:^(TorrentEngine *engine){[engine appendCandidates:remaining];}];
    else if(action==RWSourceUpdate::Start)[self startNextSource];
    else if(action==RWSourceUpdate::Unavailable)[self showUnavailable:error?:@"No untried compatible source became available. Try another quality or try again later."];
}
- (void)lookupSources:(BOOL)force {
    self.sourceLookupPending=YES;NSUInteger generation=++self.sourceLookupGeneration;__weak RewindPlayer *weak=self;
    NSString *profile=[RewindStore shared].state[@"activeProfile"];double lookupBegan=NSProcessInfo.processInfo.systemUptime;
    [self.metrics markStage:@"sources_requested" uptime:NSProcessInfo.processInfo.systemUptime];
    RWResult done=^(id result,NSString *error){
        if(!weak||weak.closing||weak.sourceLookupGeneration!=generation||![profile isEqual:[RewindStore shared].state[@"activeProfile"]])return;
        weak.sourceLookupPending=NO;[weak.metrics markStage:@"sources_ready" uptime:NSProcessInfo.processInfo.systemUptime];
        [weak.metrics recordEvent:@"source_lookup_completed" values:@{@"duration_seconds":@(NSProcessInfo.processInfo.systemUptime-lookupBegan),@"candidate_count":@([result count]),@"error":error?:@""} uptime:NSProcessInfo.processInfo.systemUptime];
        [[RewindStore shared]report:@{@"source_refresh_count":@([result count]),@"source_refresh_error":error?:@""}];
        [weak acceptSourceResults:result error:error];
    };
    // streams reuses a recent completed lookup or joins an in-flight request.
    // Saved history alone must never suppress this search for alternatives.
    if(force)[[RewindStore shared]refreshStreams:self.meta videoID:self.videoID done:done];
    else [[RewindStore shared]streams:self.meta videoID:self.videoID done:done];
}
- (void)retrySources {
    if(self.closing)return;[self stopCurrentSource];self.discovering=NO;self.refreshing=YES;self.exhausted=NO;self.retryButton.hidden=YES;self.loadingTitle.text=@"Refreshing available sources";self.loadingDetail.text=@"Checking providers again…";[self.spinner startAnimating];
    self.startupBegan=NSProcessInfo.processInfo.systemUptime;[self.attempts removeAllObjects];[self.triedSources removeAllObjects];[self.deadSwarms removeAllObjects];
    [self lookupSources:YES];
}
- (void)failSource:(NSString *)reason {[self failSource:reason assessment:nil];}
- (void)failSource:(NSString *)reason assessment:(NSDictionary *)assessment {
    if(self.closing||self.exhausted)return;
    if(self.hasStartedPlayback){double position=[self playbackPosition];if(isfinite(position))self.resumePosition=position;[self persist];self.startupBegan=NSProcessInfo.processInfo.systemUptime;}
    if(!self.transient)[[RewindStore shared]notePlaybackFailure:self.meta videoID:self.videoID source:self.source];
    [self.metrics recordEvent:@"source_failed" values:@{@"info_hash":self.source[@"infoHash"]?:@"",@"file_index":self.source[@"fileIdx"]?:@(-1),@"reason":reason?:@"",@"attempt_seconds":@(NSProcessInfo.processInfo.systemUptime-self.attemptStarted)} uptime:NSProcessInfo.processInfo.systemUptime];
    NSMutableDictionary *failure=[self.source mutableCopy];failure[@"reason"]=reason?:@"Playback failed";if(!self.exerciseRecovery)[self.metrics recordSourceOutcome:[[RewindStore shared]sourceFailed:failure mediaAssessment:assessment] engine:self.lastTorrentSnapshot[@"session_id"] uptime:NSProcessInfo.processInfo.systemUptime];
    [self.triedSources addObject:[self sourceKey:self.source]];
    [self.attempts addObject:@{@"source":RWString(self.source[@"name"]),@"infoHash":self.source[@"infoHash"]?:@"",@"reason":reason?:@"Unknown playback error",@"elapsed":@(NSProcessInfo.processInfo.systemUptime-self.attemptStarted)}];
    [self stopCurrentSource];[self startNextSource];
}
- (void)loadPlaybackProperties:(AVPlayerItem *)item {
    if(self.verifyingMedia)return;if(item.tracks.count>128){[self failSource:@"This source has too many media tracks."];return;}self.verifyingMedia=YES;
    [self.metrics markStage:@"media_ready" uptime:NSProcessInfo.processInfo.systemUptime];
    NSUInteger generation=self.playbackGeneration;__weak RewindPlayer *weak=self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
        dispatch_group_t group=dispatch_group_create();NSMutableArray *plans=[NSMutableArray new];
        for(AVPlayerItemTrack *itemTrack in item.tracks){AVAssetTrack *track=itemTrack.assetTrack;
            BOOL video=[track.mediaType isEqual:AVMediaTypeVideo],audio=[track.mediaType isEqual:AVMediaTypeAudio];if(!video&&!audio)continue;
            NSArray *keys=video?@[@"formatDescriptions",@"nominalFrameRate"]:@[@"formatDescriptions",@"playable",@"extendedLanguageTag",@"languageCode",@"commonMetadata",@"metadata"];
            [plans addObject:@{@"track":track,@"keys":keys}];dispatch_group_enter(group);
            [track loadValuesAsynchronouslyForKeys:keys completionHandler:^{dispatch_group_leave(group);}];
        }
        dispatch_group_notify(group,dispatch_get_main_queue(),^{
            if(weak.closing||weak.exhausted||weak.playbackGeneration!=generation||weak.player.currentItem!=item)return;weak.verifyingMedia=NO;
            for(NSDictionary *plan in plans)for(NSString *key in plan[@"keys"]){
                if(![@[@"extendedLanguageTag",@"languageCode",@"commonMetadata",@"metadata"]containsObject:key]&&[plan[@"track"]statusOfValueForKey:key error:nil]!=AVKeyValueStatusLoaded){[weak failSource:@"The source's audio or video information could not be loaded."];return;}
            }
            [weak verifyAndPlay:item];
        });
    });
}
- (void)verifyAndPlay:(AVPlayerItem *)item {
    [self.metrics markStage:@"media_properties_ready" uptime:NSProcessInfo.processInfo.systemUptime];
    NSMutableDictionary *media=[NSMutableDictionary new];AVPlayerItemTrack *audio=nil;UInt32 audioChannels=0;NSMutableArray *choices=[NSMutableArray new],*descriptors=[NSMutableArray new];
    BOOL downmix=[RWSourcePolicy nativeSurroundEnabled]||[self.videoID isEqual:@"rw:surround-check:preview"];
    for(AVPlayerItemTrack *track in item.tracks){
        AVAssetTrack *asset=track.assetTrack;
        for(id raw in asset.formatDescriptions){CMFormatDescriptionRef description=(__bridge CMFormatDescriptionRef)raw;FourCharCode codec=CMFormatDescriptionGetMediaSubType(description);
            if([asset.mediaType isEqual:AVMediaTypeVideo]){
                CMVideoDimensions dimensions=CMVideoFormatDescriptionGetDimensions(description);media[@"width"]=@(dimensions.width);media[@"height"]=@(dimensions.height);media[@"fps"]=@(asset.nominalFrameRate);
                media[@"videoCodec"]=codec=='avc1'?@"avc1":@"unsupported";
                NSDictionary *atoms=(__bridge NSDictionary *)CMFormatDescriptionGetExtension(description,kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms);
                NSData *avcc=[atoms isKindOfClass:NSDictionary.class]?atoms[@"avcC"]:nil;
                if([avcc isKindOfClass:NSData.class]&&avcc.length>=4){const uint8_t *b=(const uint8_t *)avcc.bytes;media[@"profile"]=@(b[1]);media[@"level"]=@(b[3]);}
            }else if([asset.mediaType isEqual:AVMediaTypeAudio]){
                const AudioStreamBasicDescription *asbd=CMAudioFormatDescriptionGetStreamBasicDescription(description);
                if(codec=='aac '&&asset.playable&&asbd&&asbd->mChannelsPerFrame>0&&asbd->mChannelsPerFrame<=(downmix?6:2)&&isfinite(asbd->mSampleRate)&&asbd->mSampleRate>0&&asbd->mSampleRate<=48000&&(asbd->mFormatFlags==0||asbd->mFormatFlags==2)){
                    NSString *code=[asset statusOfValueForKey:@"extendedLanguageTag" error:nil]==AVKeyValueStatusLoaded?asset.extendedLanguageTag:nil,*name=@"";if(!code.length&&[asset statusOfValueForKey:@"languageCode" error:nil]==AVKeyValueStatusLoaded)code=asset.languageCode;
                    for(AVMetadataItem *metadata in [asset statusOfValueForKey:@"commonMetadata" error:nil]==AVKeyValueStatusLoaded?asset.commonMetadata:@[])if([metadata.commonKey isEqual:AVMetadataCommonKeyTitle]){name=metadata.stringValue?:@"";break;}
                    NSMutableArray *extra=[NSMutableArray new];NSArray *metadata=[asset statusOfValueForKey:@"metadata" error:nil]==AVKeyValueStatusLoaded?asset.metadata:@[];
                    if(metadata.count<=128)for(AVMetadataItem *m in metadata){id value=m.value;if(([value isKindOfClass:NSData.class]&&[value length]<=2048)||([value isKindOfClass:NSString.class]&&[value length]<=512))[extra addObject:@{@"space":m.keySpace?:@"",@"key":m.key?:@"",@"common":m.commonKey?:@"",@"value":value}];}
                    NSDictionary *labels=[RWAudioPolicy nativeMetadata:extra];if([labels[@"name"]length])name=labels[@"name"];
                    // One descriptor per AVAssetTrack even when it advertises
                    // multiple equivalent format descriptions.
                    if(![choices filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *c,NSDictionary *bindings){return c[@"track"]==track;}]].count){
                        [choices addObject:@{@"track":track,@"id":@(asset.trackID)}];
                        [descriptors addObject:@{@"id":@(asset.trackID),@"name":name,@"language":code?:@"",@"codec":@"AAC",@"channels":@(asbd->mChannelsPerFrame),@"compatible":@YES,@"default":@(track.enabled),@"commentary":labels[@"commentary"]?:@NO,@"description":@([labels[@"description"]boolValue]||[asset hasMediaCharacteristic:AVMediaCharacteristicDescribesVideoForAccessibility]),@"auxiliary":@([labels[@"auxiliary"]boolValue]||[asset hasMediaCharacteristic:AVMediaCharacteristicIsAuxiliaryContent])}];
                    }

                }
            }
        }
    }
    NSArray *normalized=[RWAudioPolicy tracks:descriptors];NSMutableArray *supported=[NSMutableArray new];
    for(NSDictionary *choice in choices)for(NSDictionary *descriptor in normalized)if([choice[@"id"]isEqual:descriptor[@"id"]]){[supported addObject:@{@"track":choice[@"track"],@"descriptor":descriptor}];break;}
    self.audioChoices=supported;self.audioSelection=[RWAudioPolicy selection:normalized preference:[self audioPreference]];
    for(NSDictionary *choice in supported)if([choice[@"descriptor"][@"token"]isEqual:self.audioSelection[@"track"][@"token"]]){audio=choice[@"track"];audioChannels=[choice[@"descriptor"][@"channels"]unsignedIntValue];break;}
    media[@"audioSelection"]=self.audioSelection;media[@"aacStereo"]=@(audio!=nil&&audioChannels<=2);media[@"aacDownmix"]=@(audio!=nil&&audioChannels>2&&downmix);media[@"audioChannels"]=@(audioChannels);media[@"outputChannels"]=@([AVAudioSession sharedInstance].outputNumberOfChannels);NSDictionary *assessment=[RWSourcePolicy mediaAssessment:media quality:self.quality?:[self.source[@"resolution"]integerValue]];NSString *reason=[assessment[@"status"]isEqual:@"compatible"]?nil:assessment[@"reason"];
    [[RewindStore shared]report:@{@"media_probe":media,@"media_rejection":reason?:@"",@"media_assessment":assessment}];
    if(reason){[self failSource:reason assessment:assessment];return;}
    for(AVPlayerItemTrack *track in item.tracks)if([track.assetTrack.mediaType isEqual:AVMediaTypeAudio])track.enabled=track==audio;
    self.mediaVerified=YES;self.automaticSegments=nil;
    if(!self.transient){__weak RewindPlayer *weak=self;NSUInteger generation=self.playbackGeneration;[[RewindStore shared]segments:self.meta videoID:self.videoID duration:CMTimeGetSeconds(item.duration) done:^(id segments,NSString *error){if(weak.closing||weak.playbackGeneration!=generation)return;weak.automaticSegments=segments;[[RewindStore shared]report:@{@"automatic_skip_segments":@([segments count])}];}];}
    self.loadingPanel.hidden=YES;[self.spinner stopAnimating];[self.view setNeedsLayout];self.lastProgress=NSProcessInfo.processInfo.systemUptime;
    NSMutableDictionary *source=[self.source mutableCopy];source[@"verifiedWidth"]=media[@"width"];source[@"verifiedHeight"]=media[@"height"];self.source=source;
    NSInteger resolution=[RWSourcePolicy resolutionForWidth:[media[@"width"]integerValue] height:[media[@"height"]integerValue]];
    [self.qualityButton setTitle:[NSString stringWithFormat:self.quality?@"%ldp":@"Auto · %ldp",(long)resolution] forState:UIControlStateNormal];
    [[RewindStore shared]report:@{@"player_ready":@YES,@"actual_quality":@(resolution)}];
    if(!self.resumed){self.resumed=YES;double duration=CMTimeGetSeconds(item.duration),start=self.resumePosition;if(isfinite(duration)&&start>=duration-10)start=0;[self.metrics setExpectedStartPosition:start];
        if(start>0)[self seekNative:start];
        else if(self.wantsPlay)[self.player play];
    }
}
- (void)choosePlaybackQuality {
    self.lastInteraction=[NSDate date].timeIntervalSince1970;__weak RewindPlayer *weak=self;
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Video quality" message:@"Available source labels are checked against the actual video before playback. Changing quality may buffer; your position is kept." preferredStyle:UIAlertControllerStyleActionSheet];
    NSMutableArray *qualities=[NSMutableArray arrayWithObject:@0];[qualities addObjectsFromArray:[RWSourcePolicy qualities:self.candidates]];
    for(NSNumber *q in qualities){NSString *title=q.integerValue?[NSString stringWithFormat:@"%@p",q]:@"Auto · up to 1080p";
        [a addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            if(weak.quality==q.integerValue)return;
            if(weak.mediaVerified){double position=[weak playbackPosition];if(isfinite(position))weak.resumePosition=position;[weak persist];}
            [weak stopCurrentSource];weak.quality=q.integerValue;weak.candidates=[[RewindStore shared]withSourceExperience:weak.candidates];weak.ranked=[RWSourcePolicy rank:weak.candidates quality:weak.quality freeBytes:0];weak.candidateIndex=0;[weak.attempts removeAllObjects];[weak.deadSwarms removeAllObjects];[weak.triedSources removeAllObjects];weak.startupBegan=NSProcessInfo.processInfo.systemUptime;[weak startNextSource];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=self.qualityButton;a.popoverPresentationController.sourceRect=self.qualityButton.bounds;[self presentViewController:a animated:YES completion:nil];
}

- (void)memoryWarningReceived {self.memoryWarnings++;}
- (void)collectMetrics {
    mach_task_basic_info_data_t info={};mach_msg_type_number_t count=MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t status=task_info(mach_task_self(),MACH_TASK_BASIC_INFO,(task_info_t)&info,&count);
    NSDictionary *disk=[[NSFileManager defaultManager]attributesOfFileSystemForPath:RWDocuments() error:nil];
    NSMutableDictionary *sample=[@{@"free_disk_bytes":disk[NSFileSystemFreeSize]?:@0,@"memory_warnings":@(self.memoryWarnings),@"player_rate":@([self playbackRate]),@"buffer_empty":@(self.player.currentItem.playbackBufferEmpty),@"frame_visible":@([self frameVisible]),@"spinner_visible":@(self.spinner.isAnimating),@"subtitle_name":self.subtitleName?:@"",@"subtitle_cues":@(self.cues.count)}mutableCopy];
    if(status==KERN_SUCCESS)sample[@"resident_bytes"]=@(info.resident_size);
    if(self.lastTorrentSnapshot){NSMutableDictionary *transfer=[NSMutableDictionary new];
        for(NSString *key in @[@"verified_read_bytes",@"verified_read_pieces",@"verified_read_hash_seconds",@"read_delivered_bytes",@"read_cache_hits",@"read_cache_evictions",@"verified_reads_by_piece",@"read_piece_count_limit",@"unlisted_piece_reads",@"session_id",@"compact_piece_storage",@"allocated_cache_bytes",@"allocated_video_bytes",@"peer_payload_bytes",@"download_bytes_per_second",@"requested_video_offset",@"requested_piece",@"requested_piece_finished_blocks",@"requested_piece_writing_blocks",@"requested_piece_pending_blocks",@"peers_with_requested_piece",@"playback_wanted_byte_bound",@"wanted_bytes",@"wanted_done_bytes",@"resume_pending"])
            if(self.lastTorrentSnapshot[key])transfer[key]=self.lastTorrentSnapshot[key];sample[@"transfer"]=transfer;
    }
    NSDictionary *loaderMetrics=self.loader.diagnostics;if(loaderMetrics)sample[@"native_loader"]=loaderMetrics;
    sample[@"controls"]=[self controlsDiagnostics];
    sample[@"max_ui_tick_gap_seconds"]=@(self.maxUITickGap);sample[@"engine_poll_seconds"]=@(self.lastEnginePoll);
    if(self.legacy)sample[@"legacy"]=[self.legacy metrics];
    sample[@"native_seek"]=[self nativeSeekSnapshot];[self.metrics recordResources:sample];[[RewindStore shared]report:@{@"playback_session_id":self.metrics.sessionID,@"playback_metrics":[self.metrics snapshot]}];
    double now=NSProcessInfo.processInfo.systemUptime;if(now-self.lastMetricFile>=30){self.lastMetricFile=now;[self saveMetricSamples];}
}
- (void)saveMetricSamples {
    if(!self.metrics)return;
    NSString *folder=[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"];
    NSDictionary *report=@{@"videoID":self.videoID?:@"",@"title":RWString(self.meta[@"name"]),@"summary":[self.metrics snapshot],@"samples":[self.metrics samples]};
    NSData *data=[NSJSONSerialization dataWithJSONObject:report options:0 error:nil];[[RWAtomicWriter shared]write:data path:[folder stringByAppendingPathComponent:@"playback-metrics.json"]];
    if(self.closing){NSUInteger slot=[NSUserDefaults.standardUserDefaults integerForKey:@"RWDiagnosticSessionSlot"]%8;
        [[RWAtomicWriter shared]write:data path:[folder stringByAppendingPathComponent:[NSString stringWithFormat:@"playback-session-%lu.json",(unsigned long)slot]]];
        [NSUserDefaults.standardUserDefaults setInteger:(slot+1)%8 forKey:@"RWDiagnosticSessionSlot"];
    }
}
