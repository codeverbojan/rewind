// Foreground lab automation, explicitly armed by a short-lived USB request.
// Exercises normal controls and UIKit animated offsets, not synthetic touches.
#include "RWPlaybackAdmission.h"
- (void)consumeDeviceExercise {
    NSString *path=[RWDocuments()stringByAppendingPathComponent:@"rewind-device-exercise.request"];
    NSDictionary *attributes=[[NSFileManager defaultManager]attributesOfItemAtPath:path error:nil];if(!attributes)return;
    NSData *data=[attributes fileSize]<=4096?[NSData dataWithContentsOfFile:path]:nil;
    id request=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
    // A pending lab request needs an admission receipt even when a foreground
    // safeguard refuses it. Keep the request and every existing guard intact.
    NSString *run=[request isKindOfClass:NSDictionary.class]&&[request[@"run"]isKindOfClass:NSString.class]?request[@"run"]:@"";
    BOOL blocked=self.reviewMode||self.exerciseRequest||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive;
    [[RewindStore shared]report:@{@"device_exercise_admission":@{@"run":run.length<=64?run:@"",@"at":@(NSDate.date.timeIntervalSince1970),@"application_state":@(UIApplication.sharedApplication.applicationState),@"review":@(self.reviewMode),@"busy":@(self.exerciseRequest!=nil),@"window_attached":@(self.view.window!=nil),@"blocked":@(blocked)}}];
    if(blocked)return;
    [[NSFileManager defaultManager]removeItemAtPath:path error:nil];
    NSArray *steps=[RWDeviceExercise stepsForRequest:request build:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue] now:NSDate.date.timeIntervalSince1970];
    if(!steps||self.presentedViewController||(![request[@"action"]isEqual:@"close"]&&![@[@"Profiles",@"Home",@"Search"]containsObject:self.page])){[[RewindStore shared]report:@{@"device_exercise_rejected":@YES}];return;}
    self.profileExperience.diagnosticSampling=[@[@"profile-intro",@"profile-cinematic"]containsObject:request[@"action"]];
    self.exerciseRequest=request;self.exerciseSteps=steps;self.exerciseSamples=[NSMutableArray new];self.exerciseIndex=0;self.exerciseRailSettleIndex=0;self.exerciseRailSettleStarted=0;self.exerciseStarted=NSProcessInfo.processInfo.systemUptime;self.exerciseProfile=[RewindStore shared].state[@"activeProfile"];
    self.exercisePriorIdleTimer=UIApplication.sharedApplication.idleTimerDisabled;UIApplication.sharedApplication.idleTimerDisabled=YES;
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(cancelDeviceExercise) name:@"RWDeviceExerciseUserTouch" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(cancelDeviceExercise) name:UIApplicationWillResignActiveNotification object:nil];
    [RWUIProbe shared].deviceExerciseActive=YES;[[RWUIProbe shared]resetMeasurements];
    [self nextDeviceExerciseStep];
}
- (void)cancelDeviceExercise {if(self.exerciseRequest)[self finishDeviceExercise:@"cancelled_by_touch_or_background"];}
- (BOOL)exerciseTitlePlaybackStep:(NSString *)kind {
    RewindStore *store=RewindStore.shared;NSDictionary *test=[RWDeviceExercise playbackCase:self.exerciseRequest[@"playback_case"]];
    if(![self.exerciseRequest[@"action"]isEqual:@"playback-title"]||!test||store.restricted)return NO;
    if([kind isEqual:@"title-load"]){
        self.exercisePlaybackMeta=nil;self.exercisePlaybackMetadataError=nil;self.exercisePlaybackMetadataPending=YES;self.exercisePlaybackMetadataStarted=NSProcessInfo.processInfo.systemUptime;
        NSString *run=self.exerciseRequest[@"run"];__weak __typeof__(self) weak=self;
        [store details:test done:^(id value,NSString *error){dispatch_async(dispatch_get_main_queue(),^{
            if(![weak.exerciseRequest[@"run"]isEqual:run])return;
            weak.exercisePlaybackMetadataPending=NO;
            if(error.length||![value isKindOfClass:NSDictionary.class]||![RWID(value)isEqual:test[@"id"]]||![value[@"type"]isEqual:test[@"type"]]||![store allowed:value]){
                weak.exercisePlaybackMetadataError=error.length?error:@"Catalog identity or profile eligibility could not be verified";return;
            }
            NSDictionary *meta=value;
            if([test[@"type"]isEqual:@"series"]){
                NSDictionary *episode=nil;for(NSDictionary *candidate in [RWTVPolicy episodes:meta])if([candidate[@"id"]isEqual:test[@"video_id"]]){episode=candidate;break;}
                if(!episode||![RWTVPolicy released:episode now:NSDate.date]){weak.exercisePlaybackMetadataError=@"Exact released episode was not found in the catalog";return;}
                meta=[RWTVPolicy episodeMeta:episode show:meta];
            }
            weak.exercisePlaybackMeta=meta;
        });}];return YES;
    }
    if([kind isEqual:@"title-await"]){
        if(self.exercisePlaybackMetadataPending&&NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackMetadataStarted<30){self.exerciseIndex--;return YES;}
        if(!self.exercisePlaybackMeta){[store report:@{@"playback_case_metadata_error":self.exercisePlaybackMetadataError?:@"Catalog metadata deadline reached",@"playback_case":test}];return NO;}
        return YES;
    }
    if([kind hasPrefix:@"title-prepare"]){
        if(![self.exerciseRequest[@"prepare_check"]isEqual:@YES]||![test[@"type"]isEqual:@"movie"]||!self.exercisePlaybackMeta)return NO;
        if([kind isEqual:@"title-prepare"]){
            self.exercisePreparationReport=nil;self.exercisePreparationStarted=NSProcessInfo.processInfo.systemUptime;
            // Ordinary Details, including its real preview/payload arbitration.
            // Never inject candidates, stop the trailer or alter viewing history.
            [self showDetails:self.exercisePlaybackMeta];[self prepareCurrentTitle];return YES;
        }
        if(![kind isEqual:@"title-prepare-await"])return NO;
        NSDictionary *d=self.playbackPreparation.diagnostics?:@{},*p=d[@"preparation"]?:@{};
        NSDictionary *identity=[self preparationIdentity:self.exercisePlaybackMeta videoID:test[@"video_id"] resume:0];
        NSDictionary *header=[RWDeviceExercise preparedHeaderRead:d matchesIdentity:identity];BOOL ready=header!=nil;
        double elapsed=NSProcessInfo.processInfo.systemUptime-self.exercisePreparationStarted;
        double minimumDwell=[self.exerciseRequest[@"prepare_dwell"]doubleValue];
        double headerReady=[self.exercisePreparationReport[@"first_header_ready_seconds"]doubleValue];if(!self.exercisePreparationReport||headerReady<0)headerReady=ready?elapsed:-1;
        self.exercisePreparationReport=@{@"identity":d[@"identity"]?:@{},@"session_id":p[@"session_id"]?:@"",@"torrent_start_count":p[@"torrent_start_count"]?:@0,@"duration_reads":p[@"duration_reads"]?:@[],@"header_source":header[@"infoHash"]?:@"",@"payload_source":p[@"payload_source"]?:@"",@"payload_bytes":p[@"payload_bytes"]?:@0,@"payload_allowed":p[@"payload_allowed"]?:@NO,@"budget_stopped":p[@"budget_stopped"]?:@NO,@"preview_using_network":@(self.preview.usingVideoNetwork),@"handoff_ready":@(ready),@"prepared_ready":p[@"discovery"][@"prepared_ready"]?:@NO,@"detail_dwell_seconds":@(elapsed)};
        if(![self.page isEqual:@"Details"]||![RWID(self.detail)isEqual:test[@"id"]])return NO;
        NSMutableDictionary *preparationReport=[self.exercisePreparationReport mutableCopy];preparationReport[@"minimum_detail_dwell_seconds"]=@(minimumDwell);preparationReport[@"first_header_ready_seconds"]=@(headerReady);self.exercisePreparationReport=preparationReport;
        // Controlled user dwell is independent of readiness. Never extend the
        // existing20s admission deadline or bypass verified-header requirements.
        if(ready&&elapsed>=minimumDwell)return YES;if(elapsed>=20)return NO;self.exerciseIndex--;return YES;
    }
    if([kind hasPrefix:@"title-caption-"]){
        if(![self.exerciseRequest[@"caption_check"]isEqual:@YES])return NO;
        NSDictionary *state=[self.exercisePlayer deviceExerciseSnapshot];if(![state[@"transient"]boolValue]||![state[@"video_id"]isEqual:test[@"video_id"]]||[state[@"closing"]boolValue]||[state[@"exhausted"]boolValue])return NO;
        BOOL manual=[@[@"back-to-future-sidecar",@"severance-embedded"]containsObject:self.exerciseRequest[@"caption_choice"]?:@""];
        BOOL expectedCaption=[state[@"subtitle_identity"][@"token"]isEqual:state[@"real_captions"][@"selected"][@"token"]]&&(manual?([state[@"real_captions"][@"manual_unlabelled"]boolValue]&&[state[@"subtitle_identity"][@"language"]isEqual:@""]):[state[@"subtitle_identity"][@"language"]isEqual:@"en"]);
        if([kind isEqual:@"title-caption-startup"]){
            if(![self.exerciseRequest[@"caption_probe"]isEqual:@"severance-2648"]||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>90)return NO;
            if(![state[@"media_verified"]boolValue]||![state[@"frame_visible"]boolValue]||[state[@"position"]doubleValue]<3)self.exerciseIndex--;return YES;
        }
        if([kind hasPrefix:@"title-caption-known-"]){
            if(![self.exerciseRequest[@"caption_probe"]isEqual:@"severance-2648"]||!expectedCaption||![state[@"backend"]isEqual:@"mkv"])return NO;
            if([kind isEqual:@"title-caption-known-observe"]){
                NSDictionary *start=nil;for(NSDictionary *sample in self.exerciseSamples)if([sample[@"kind"]isEqual:@"title-caption-known-live"]&&[sample[@"ok"]boolValue])start=sample;
                if(!start||![state[@"wants_play"]boolValue]||NSProcessInfo.processInfo.systemUptime-self.exerciseStarted-[start[@"elapsed_seconds"]doubleValue]>150)return NO;
                if([state[@"position"]doubleValue]<[start[@"player"][@"position"]doubleValue]+120)self.exerciseIndex--;return YES;
            }
            if([kind isEqual:@"title-caption-known-presented"]){
                NSDictionary *trace=state[@"embedded_metrics"][@"presentation_trace"];if(!trace||NSProcessInfo.processInfo.systemUptime-[trace[@"began"]doubleValue]>8||[state[@"wants_play"]boolValue])return NO;
                NSUInteger complete=0;for(NSDictionary *frame in [trace[@"frames"]allValues]){if([frame[@"status"]hasPrefix:@"failed"])return NO;if([frame[@"status"]isEqual:@"complete"])complete++;}
                if(complete!=3){self.exerciseIndex--;return YES;}return fabs([state[@"position"]doubleValue]-2648.5)<.2;
            }
            if([kind isEqual:@"title-caption-known-capture"]||[kind isEqual:@"title-caption-known-live"]){
                BOOL live=[kind hasSuffix:@"-live"];double position=[state[@"position"]doubleValue];
                if(live){if(![state[@"wants_play"]boolValue]||position>2654.4||NSProcessInfo.processInfo.systemUptime-[state[@"real_captions"][@"seek_started"]doubleValue]>30)return NO;if(position<2652.3){self.exerciseIndex--;return YES;}}
                else if([state[@"wants_play"]boolValue]||fabs(position-2648.5)>.2)return NO;
                NSString *name=live?@"device-exercise-known-cue-live":@"device-exercise-known-cue-paused",*path=[[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"]stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]];
                [NSFileManager.defaultManager removeItemAtPath:path error:nil];RWCapture(self.exercisePlayer.view,name);return [[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil]fileSize]>0;
            }
            return [self.exercisePlayer deviceExerciseControl:kind];
        }
        if([kind isEqual:@"title-caption-menu"])return [self.exercisePlayer deviceExerciseControl:@"subtitle-menu"];
        if([kind isEqual:@"title-caption-off-choice"])return [self.exercisePlayer deviceExerciseControl:kind];
        if([kind isEqual:@"title-caption-ready"]){
            if(![state[@"subtitle_choice_pending"]boolValue]&&expectedCaption&&![state[@"menu"]length]&&([state[@"embedded_subtitle"]integerValue]>=0||[state[@"subtitle_cues"]integerValue]>0||[state[@"subtitle_identity"][@"kind"]isEqual:@"native"]))return YES;
            if(NSProcessInfo.processInfo.systemUptime-[state[@"real_captions"][@"choice_started"]doubleValue]>15)return NO;self.exerciseIndex--;return YES;
        }
        if([kind isEqual:@"title-caption-seek-await"]){
            NSDictionary *seek=state[@"real_captions"];if(NSProcessInfo.processInfo.systemUptime-[seek[@"seek_started"]doubleValue]>30)return NO;
            BOOL ready=[state[@"wants_play"]boolValue]&&![state[@"native_seek"][@"pending"]boolValue]&&[state[@"position"]doubleValue]>=[seek[@"target"]doubleValue]+3;
            if([state[@"backend"]isEqual:@"mkv"])ready=ready&&[state[@"embedded_metrics"][@"displayed_frames"]longLongValue]>[seek[@"displayed_before"]longLongValue]+12;
            if(!ready)self.exerciseIndex--;return YES;
        }
        if([kind isEqual:@"title-caption-off"]){if(NSProcessInfo.processInfo.systemUptime-[state[@"real_captions"][@"off_started"]doubleValue]>8)return NO;if([state[@"embedded_subtitle"]integerValue]!=-1||[state[@"subtitle_cues"]integerValue]||[state[@"subtitle_text"]length]||[state[@"menu"]length])self.exerciseIndex--;return YES;}
        if([kind hasPrefix:@"title-caption-capture:"]){
            NSString *stage=[[kind componentsSeparatedByString:@":"]lastObject];if(![@[@"start",@"middle",@"end",@"off"]containsObject:stage])return NO;
            if(![stage isEqual:@"off"]&&(!expectedCaption||![state[@"wants_play"]boolValue]))return NO;
            NSString *name=[@"device-exercise-title-captions-" stringByAppendingString:stage],*path=[[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"]stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]];
            [NSFileManager.defaultManager removeItemAtPath:path error:nil];RWCapture(self.exercisePlayer.view,name);return [[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil]fileSize]>0;
        }
        return [self.exercisePlayer deviceExerciseControl:kind];
    }
    if([kind isEqual:@"title-play"]){
        if(!self.exercisePlaybackMeta||![store allowed:self.exercisePlaybackMeta])return NO;
        [store report:@{@"playback_case":test,@"playback_case_metadata_error":@""}];
        [self chooseSources:self.exercisePlaybackMeta videoID:test[@"video_id"] restart:YES];
        if([self.presentedViewController isKindOfClass:RewindPlayer.class])self.exercisePlayer=(RewindPlayer *)self.presentedViewController;
        self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;
        return self.exercisePlayer&&[[self.exercisePlayer deviceExerciseSnapshot][@"transient"]boolValue]&&[[self.exercisePlayer deviceExerciseSnapshot][@"video_id"]isEqual:test[@"video_id"]];
    }
    return NO;
}
- (BOOL)exercisePressNavigation:(NSString *)label {
    for(UIView *view in self.sidebar.subviews)if([view isKindOfClass:RWButton.class]){
        RWButton *button=(RWButton *)view;
        if([button.accessibilityLabel isEqual:label]||[button.currentTitle isEqual:label]){[button sendActionsForControlEvents:UIControlEventTouchUpInside];return YES;}
    }return NO;
}
- (RWPosterCollection *)exerciseFirstRail:(RWHomeView *)home {
    NSMutableArray *queue=[NSMutableArray arrayWithArray:home.visibleCells?:@[]];
    while(queue.count){UIView *view=queue.firstObject;[queue removeObjectAtIndex:0];if([view isKindOfClass:RWPosterCollection.class])return (RWPosterCollection *)view;[queue addObjectsFromArray:view.subviews];}return nil;
}
- (BOOL)exerciseLoadingStep:(NSString *)kind {
    if([kind hasPrefix:@"capture-"]){
        NSString *name=[kind isEqual:@"capture-home"]?@"device-exercise-home":@"device-exercise-loading";
        if([kind isEqual:@"capture-loading"]&&!self.exerciseLoadingView.window)return NO;
        NSString *path=[[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"]stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]];
        [[NSFileManager defaultManager]removeItemAtPath:path error:nil];[self.view layoutIfNeeded];RWCapture(self.view,name);
        return [[[NSFileManager defaultManager]attributesOfItemAtPath:path error:nil]fileSize]>0;
    }
    if([kind isEqual:@"loading-preview"]){
        NSMutableArray *cards=[NSMutableArray new];for(NSDictionary *row in self.homePlan[@"rows"])for(NSDictionary *meta in row[@"items"])if(cards.count<6&&[[RewindStore shared]allowed:meta])[cards addObject:meta];
        if(cards.count<6)return NO;self.exerciseLoadingCards=cards;
        RWHomeView *view=[[RWHomeView alloc]initWithFrame:self.homeView.frame];view.backgroundColor=RWColor(0x0b0d12);view.userInteractionEnabled=NO;view.scope=@"loading-exercise";view.railOffsets=[NSMutableDictionary new];
        self.exerciseLoadingView=view;[self.content addSubview:view];[view updateRows:[RWHomePresentation initialLoadingRows] header:[self homeHeader:nil empty:NO]];[view layoutIfNeeded];
        return [[self exerciseFirstRail:view]numberOfItemsInSection:0]==5;
    }
    if([kind isEqual:@"loading-dismiss"]){[self.exerciseLoadingView removeFromSuperview];self.exerciseLoadingView=nil;self.exerciseLoadingCards=nil;return YES;}
    RWPosterCollection *rail=[self exerciseFirstRail:self.exerciseLoadingView];if(!rail)return NO;
    BOOL content=[kind isEqual:@"loading-content"],refresh=[kind isEqual:@"loading-refresh"],append=[kind isEqual:@"loading-append"],retry=[kind isEqual:@"loading-retry"],error=[kind isEqual:@"loading-error"];
    if(!content&&!refresh&&!append&&!retry&&!error&&![kind isEqual:@"loading-empty"])return NO;
    NSArray *items=content||refresh?[self.exerciseLoadingCards subarrayWithRange:NSMakeRange(0,3)]:append?self.exerciseLoadingCards:@[];
    [rail updateItems:items loading:refresh||retry more:NO error:error?@"Unavailable":nil cursor:0 automatic:NO];[rail layoutIfNeeded];
    NSUInteger expected=retry?5:items.count;return [rail numberOfItemsInSection:0]==expected&&rail.items.count==items.count;
}
#include "RewindProfileExercise.inc"
#include "RewindHomeFeedExercise.inc"
#include "RewindCastExercise.inc"
#include "RewindDiscoveryExercise.inc"
#include "RewindAvailabilityExercise.inc"
#include "RewindReminderExercise.inc"
#include "RewindNotificationExercise.inc"
#include "RewindLibraryExercise.inc"
#include "RewindSearchExercise.inc"
#include "RewindEntityNetworkExercise.inc"
#include "RewindEntityArtExercise.inc"
#include "RewindArtworkExercise.inc"
#include "RewindSubtitleExercise.inc"
#include "RewindAudioExercise.inc"
#include "RewindHTTPSubtitleExercise.inc"
#include "RewindResumeExercise.inc"
#include "RewindPreferenceExercise.inc"
#include "RewindDownloadExercise.inc"
#include "RewindEpisodeExercise.inc"
#include "RewindHandoffExercise.inc"
#include "RewindOfflineExercise.inc"
#include "RewindFeaturedExercise.inc"
#include "RewindFeedExercise.inc"
#include "RewindKidsExercise.inc"
#include "RewindKidsSurfacesExercise.inc"
#include "RewindNetworkExercise.inc"
#include "RewindRecoveryExercise.inc"
#include "RewindLifecycleExercise.inc"
- (void)nextDeviceExerciseStep {
    if(!self.exerciseRequest)return;
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive||(self.presentedViewController&&self.presentedViewController!=self.exercisePlayer&&self.presentedViewController!=self.exerciseReminderSheet&&self.presentedViewController!=self.exerciseOrientationProbe&&self.presentedViewController!=self.exerciseEntitySheet)||![[RewindStore shared].state[@"activeProfile"]isEqual:self.exerciseProfile]||NSProcessInfo.processInfo.systemUptime-self.exerciseStarted>([@[@"playback-long",@"playback-reconnect",@"playback-title",@"playback-controlled-mkv",@"playback-lifecycle"]containsObject:self.exerciseRequest[@"action"]]?330:180)){[self finishDeviceExercise:@"cancelled_context_or_timeout"];return;}
    if(self.exerciseIndex>=self.exerciseSteps.count){[self finishDeviceExercise:@"complete"];return;}
    NSDictionary *step=self.exerciseSteps[self.exerciseIndex++];NSString *kind=step[@"kind"];double began=NSProcessInfo.processInfo.systemUptime;BOOL ok=YES;NSDictionary *playerBefore=nil;
    [[RWUIProbe shared]wake];
    if([kind isEqual:@"font-start"]){ok=[self.exerciseRequest[@"action"]isEqual:@"font-lookup"]&&[self.page isEqual:@"Profiles"]&&!self.exerciseFontProbe;if(ok){self.exerciseFontProbe=[RWFontLookupProbe new];ok=[self.exerciseFontProbe start];}}
    else if([kind isEqual:@"font-await"]){NSDictionary *probe=[self.exerciseFontProbe snapshot];ok=[self.exerciseRequest[@"action"]isEqual:@"font-lookup"]&&probe!=nil&&began-self.exerciseStarted<40;if(ok&&[probe[@"worker_running"]boolValue])self.exerciseIndex--;else ok=ok&&[probe[@"status"]isEqual:@"complete"];}
    else if([kind isEqual:@"active-profile"]){if([self.page isEqual:@"Profiles"])[self selectProfile:self.exerciseProfile];else ok=[self exercisePressNavigation:@"Home"];}
    else if([kind isEqual:@"await-playback-catalog"]){
        RWCatalogAdmission admission=RWPlaybackCatalogAdmission([RewindStore shared].catalogReady,began-self.exerciseStarted);
        if(admission==RWCatalogExpired){[self finishDeviceExercise:@"failed_catalog_readiness_timeout"];return;}
        if(admission==RWCatalogWaiting)self.exerciseIndex--;
    }
    else if([kind isEqual:@"home"]||[kind isEqual:@"search"])ok=[self exercisePressNavigation:[kind isEqual:@"home"]?@"Home":@"Search"];
    else if([kind isEqual:@"home-audit-content"]){NSDictionary *state=self.homeView.diagnostics;ok=[self.page isEqual:@"Home"]&&self.homeView.window&&[state[@"visible_prepared_cards"]unsignedIntegerValue]>0&&![state[@"content_pending"]boolValue]&&![state[@"content_scheduled"]boolValue];}
    else if([kind hasPrefix:@"feed-"])ok=[self exerciseFeedStep:kind];
    else if([kind hasPrefix:@"network-"])ok=[self exerciseNetworkStep:kind];
    else if([kind hasPrefix:@"kids-surface-"])ok=[self exerciseKidsSurfacesStep:kind];
    else if([kind hasPrefix:@"kids-"])ok=[self exerciseKidsStep:kind];
    else if([kind hasPrefix:@"artstate-"])ok=[self exerciseArtworkStep:kind];
    else if([kind hasPrefix:@"entityart-"])ok=[self exerciseEntityArtStep:kind];
    else if([kind hasPrefix:@"entitynet-"])ok=[self exerciseEntityNetworkStep:kind];
    else if([kind hasPrefix:@"searchnet-"])ok=[self exerciseSearchNetworkStep:kind];
    else if([kind hasPrefix:@"library-"])ok=[self exerciseLibraryStep:kind];
    else if([kind hasPrefix:@"presentation-"])ok=[self exercisePresentationStep:kind];
    else if([kind hasPrefix:@"featured-"])ok=[self exerciseFeaturedStep:kind];
    else if([kind hasPrefix:@"offline-"])ok=[self exerciseOfflineStep:kind];
    else if([kind hasPrefix:@"handoff-"])ok=[self exerciseHandoffStep:kind];
    else if([kind hasPrefix:@"episode-"])ok=[self exerciseEpisodeStep:kind];
    else if([kind hasPrefix:@"download-"])ok=[self exerciseDownloadStep:kind];
    else if([kind hasPrefix:@"prefs-"])ok=[self exercisePreferenceStep:kind];
    else if([kind hasPrefix:@"resume-"])ok=[self exerciseResumeStep:kind];
    else if([kind hasPrefix:@"http-"])ok=[self exerciseHTTPSubtitleStep:kind];
    else if([kind hasPrefix:@"lifecycle-"])ok=[self exerciseLifecycleStep:kind];
    else if([kind hasPrefix:@"recovery-"])ok=[self exerciseRecoveryStep:kind];
    else if([kind hasPrefix:@"audio-"])ok=[self exerciseAudioStep:kind];
    else if([kind hasPrefix:@"subtitle-"])ok=[self exerciseSubtitleStep:kind];
    else if([kind hasPrefix:@"rail-"])ok=[self exerciseHomeRailStep:step];
    else if([kind hasPrefix:@"profile-"])ok=[self exerciseProfileStep:step];
    else if([kind hasPrefix:@"discover-"])ok=[self exerciseDiscoveryStep:kind];
    else if([kind hasPrefix:@"notification-"])ok=[self exerciseNotificationStep:kind];
    else if([kind hasPrefix:@"reminder-"])ok=[self exerciseReminderStep:kind];
    else if([kind hasPrefix:@"avail-"])ok=[self exerciseAvailabilityStep:kind];
    else if([kind hasPrefix:@"detail-"])ok=[self exerciseDetailStep:kind];
    else if([kind hasPrefix:@"cast-"])ok=[self exerciseCastStep:kind];
    else if([kind hasPrefix:@"capture-"]||[kind hasPrefix:@"loading-"])ok=[self exerciseLoadingStep:kind];
    else if([kind hasPrefix:@"title-"])ok=[self exerciseTitlePlaybackStep:kind];
    else if([kind isEqual:@"play-public"]){
        RewindStore *store=[RewindStore shared];NSString *testID=[self.exerciseRequest[@"action"]isEqual:@"playback-reconnect"]?@"rw:cosmos":@"tt3268458";NSDictionary *movie=nil;for(NSDictionary *candidate in store.openFilms)if([RWID(candidate)isEqual:testID]){movie=candidate;break;}
        if(store.restricted||!movie||![store allowed:movie])ok=NO;
        else{[self chooseSources:movie videoID:RWID(movie) restart:YES];if([self.presentedViewController isKindOfClass:RewindPlayer.class])self.exercisePlayer=(RewindPlayer *)self.presentedViewController;self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;ok=self.exercisePlayer!=nil&&[[self.exercisePlayer deviceExerciseSnapshot][@"transient"]boolValue];}
    }else if([kind isEqual:@"await-playback"]){
        NSDictionary *state=[self.exercisePlayer deviceExerciseSnapshot];
        if(!self.exercisePlayer||[state[@"exhausted"]boolValue]||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>([@[@"playback-long",@"playback-title"]containsObject:self.exerciseRequest[@"action"]]?300:160)){[self finishDeviceExercise:@"failed_player_unavailable_or_timeout"];return;}
        if(![state[@"media_verified"]boolValue]||![state[@"frame_visible"]boolValue]||[state[@"position"]doubleValue]<([@[@"playback-long",@"playback-title"]containsObject:self.exerciseRequest[@"action"]]?132:12))self.exerciseIndex--;
    }else if([kind isEqual:@"player-pause"]){playerBefore=[self.exercisePlayer deviceExerciseSnapshot];self.exercisePausedPosition=[playerBefore[@"position"]doubleValue];ok=[self.exercisePlayer deviceExerciseControl:@"pause"];
    }else if([kind isEqual:@"player-resume"]){playerBefore=[self.exercisePlayer deviceExerciseSnapshot];ok=[self.exercisePlayer deviceExerciseControl:@"resume"];
    }else if([kind isEqual:@"player-close"]){playerBefore=[self.exercisePlayer deviceExerciseSnapshot];ok=[playerBefore[@"position"]doubleValue]>self.exercisePausedPosition+1;ok=[self.exercisePlayer deviceExerciseControl:@"close"]&&ok;
    }else if([kind hasPrefix:@"scroll-"]){
        UIScrollView *target=self.homeView;
        if([kind isEqual:@"scroll-horizontal"]){target=nil;NSMutableArray *queue=[NSMutableArray arrayWithArray:self.homeView.visibleCells?:@[]];while(queue.count){UIView *view=queue.lastObject;[queue removeLastObject];if([view isKindOfClass:RWPosterCollection.class]&&[(RWPosterCollection *)view horizontal]&&[(UIScrollView *)view contentSize].width>view.bounds.size.width){target=(UIScrollView *)view;break;}[queue addObjectsFromArray:view.subviews];}}
        if(!target||!target.window)ok=NO;else {BOOL horizontal=[kind isEqual:@"scroll-horizontal"];if(horizontal)[target.delegate scrollViewWillBeginDragging:target];CGFloat maximum=MAX(0,horizontal?target.contentSize.width-target.bounds.size.width:target.contentSize.height-target.bounds.size.height);CGPoint offset=target.contentOffset;if(horizontal)offset.x=maximum*[step[@"fraction"]doubleValue];else offset.y=maximum*[step[@"fraction"]doubleValue];[target setContentOffset:offset animated:YES];}
    }else if([kind isEqual:@"close"]){[self stopPreview];[self.playbackPreparation cancel];[[RewindStore shared]save];[self finishDeviceExercise:@"closed_after_state_flush"];[[RWAtomicWriter shared]whenIdle:^{exit(0);}];return;}
    else ok=NO;
    struct task_basic_info memory;mach_msg_type_number_t count=TASK_BASIC_INFO_COUNT;BOOL hasMemory=task_info(mach_task_self(),TASK_BASIC_INFO,(task_info_t)&memory,&count)==KERN_SUCCESS;
    [self.exerciseSamples addObject:@{@"step":@(self.exerciseIndex),@"kind":kind,@"ok":@(ok),@"screen":self.page?:@"",@"handler_seconds":@(NSProcessInfo.processInfo.systemUptime-began),@"elapsed_seconds":@(NSProcessInfo.processInfo.systemUptime-self.exerciseStarted),@"resident_bytes":@(hasMemory?memory.resident_size:0),@"home":[self.homeView diagnostics]?:@{},@"player":[self.exercisePlayer deviceExerciseSnapshot]?:@{}}];
    if([self.exerciseRequest[@"action"]isEqual:@"related-quality"]&&[self.page isEqual:@"Home"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"home_availability"]=[self exerciseAvailabilitySnapshot];self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"network-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"network"]=[self.exerciseNetworkReport copy]?:@{};self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"lifecycle-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"lifecycle"]=[RWSourceWork snapshot:self.exerciseLifecycleReport]?:@{};self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"resume-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"resume_record"]=self.exerciseResumeRecord?:@{};self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"offline-"]||[kind hasPrefix:@"featured-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"offline"]=self.exerciseDownloadReport?:@{};self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"kids-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"kids"]=self.exerciseKidsReport?:@{};self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"artstate-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"artwork_state"]=[self exerciseArtworkSnapshot];self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"entityart-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"entity_art"]=[self exerciseEntityArtSnapshot];self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"entitynet-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"entity_network"]=[self exerciseEntityNetworkSnapshot];self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"searchnet-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"search_network"]=[self exerciseSearchNetworkSnapshot];self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"library-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"library"]=[self exerciseLibrarySnapshot];self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"presentation-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"presentation"]=self.exercisePresentationReport?:@{};self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"handoff-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"handoff"]=self.exerciseEpisodeReport?:@{};self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"episode-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"episodes"]=[self exerciseEpisodeSnapshot];self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind isEqual:@"subtitle-timing-audit"]||[kind isEqual:@"recovery-clock-audit"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"subtitle_timing_evidence"]=[self.exercisePlayer subtitleTimingEvidence]?:@{};self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"audio-audit-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];NSDictionary *profiles=RewindStore.shared.state[@"profiles"];sample[@"audio_preferences"]=@{@"active":RewindStore.shared.state[@"activeProfile"],@"primary":profiles[@"rw-device-resume-check"][@"audioSelections"]?:@{},@"companion":profiles[@"rw-device-audio-other"][@"audioSelections"]?:@{}};self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"download-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"downloads"]=[self exerciseDownloadSnapshot];self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"feed-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"feed"]=[self exerciseFeedSnapshot];self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if(playerBefore){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"player_before"]=playerBefore;self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([@[@"profile-intro",@"profile-cinematic"]containsObject:self.exerciseRequest[@"action"]]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"profile_motion"]=[self.profileExperience diagnostics];self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if(self.exerciseProfileAudit){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"profile_audit"]=self.exerciseProfileAudit;self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"discover-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"discovery"]=[self exerciseDiscoverySnapshot];self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"detail-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"detail_audit"]=[self exerciseDetailSnapshot];self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"notification-"]||[kind hasPrefix:@"reminder-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"reminder_audit"]=self.exerciseReminderReport?:@{};self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"avail-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"availability_audit"]=[self exerciseAvailabilitySnapshot];self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind hasPrefix:@"cast-"]){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"cast_strip"]=self.castStage.diagnostics?:@{};sample[@"cast_person"]=self.exerciseCastPerson?:@"";if([kind isEqual:@"cast-audit-entity"])sample[@"actor_page"]=@{@"id":RWID(self.entity),@"name":RWString(self.entity[@"name"]),@"biography_characters":@(RWString(self.entity[@"biography"]).length),@"facts":@([self.entity[@"facts"]count]),@"credits":@(self.entityFeed.count),@"scope_matches":@([self.entityFeed.context isEqual:[self currentEntityScope]])};self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if([kind isEqual:@"profile-open-detail"]&&[self.detailOpenTraces.lastObject[@"entered_uptime"]doubleValue]>=began){NSMutableDictionary *sample=[self.exerciseSamples.lastObject mutableCopy];sample[@"detail_open_trace"]=self.detailOpenTraces.lastObject;self.exerciseSamples[self.exerciseSamples.count-1]=sample;}
    if(!ok){[self finishDeviceExercise:@"failed_missing_control_or_scroll_view"];return;}
    [self performSelector:@selector(nextDeviceExerciseStep) withObject:nil afterDelay:[step[@"wait"]doubleValue]];
}
- (void)finishDeviceExercise:(NSString *)status {
    if(!self.exerciseRequest)return;
    if([self.exerciseRequest[@"prepare_check"]isEqual:@YES]){
        NSDictionary *identity=self.playbackPreparation.diagnostics[@"identity"],*test=[RWDeviceExercise playbackCase:self.exerciseRequest[@"playback_case"]];
        if([identity[@"video_id"]isEqual:test[@"video_id"]]&&[identity[@"profile_id"]isEqual:self.exerciseProfile])[self.playbackPreparation cancel];
    }
    if(self.exerciseEntitySheet&&self.presentedViewController==self.exerciseEntitySheet)[self dismissViewControllerAnimated:NO completion:nil];self.exerciseEntitySheet=nil;
    [self finishArtworkExercise];
    [self finishPresentationExercise];
    [self.exerciseDetailPhotoFixture cancelArtwork];[self.exerciseDetailPhotoFixture removeFromSuperview];self.exerciseDetailPhotoFixture=nil;
    [self.exerciseLoadingView removeFromSuperview];self.exerciseLoadingView=nil;self.exerciseLoadingCards=nil;
    if(self.exercisePlayer&&![[self.exercisePlayer deviceExerciseSnapshot][@"closing"]boolValue])[self.exercisePlayer deviceExerciseControl:@"close"];
    [self.exerciseFeedFixture removeFromSuperview];self.exerciseFeedFixture.onLoadMore=nil;self.exerciseFeedFixture=nil;self.exerciseFeedFixtureCards=nil;
    self.exerciseEntityActions=nil;self.exerciseArtInitial=nil;self.exerciseArtTarget=nil;[self finishEntityNetworkExercise];[self finishSearchNetworkExercise];[self finishLibraryExercise];[self finishNotificationExercise:status];[self finishKidsSurfacesExercise];[self finishKidsExercise];[self finishOfflineExercise];[self finishDownloadExercise];[self finishResumeExercise:status];self.exerciseEpisodeActions=nil;self.exerciseEpisodeShow=nil;self.exerciseEpisodeTargets=nil;self.exerciseEpisodeReport=nil;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(nextDeviceExerciseStep) object:nil];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:@"RWDeviceExerciseUserTouch" object:nil];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    UIApplication.sharedApplication.idleTimerDisabled=self.exercisePriorIdleTimer;[RWUIProbe shared].deviceExerciseActive=NO;
    // Restore the starting profile after an internal recipe failure only while
    // we still own the foreground context. A real touch/background/context
    // cancellation must leave the user's current choice alone.
    self.exerciseProfileMotionImages=nil;
    BOOL profileRecipe=[@[@"profiles-details",@"profile-intro",@"profile-cinematic",@"kids-density",@"kids-series",@"kids-series-reopen",@"home-anchors",@"home-rails",@"home-rails-kids",@"home-series",@"home-series-kids",@"home-theme-series",@"home-theme-series-kids",@"home-categories",@"home-categories-landscape",@"home-world",@"home-world-kids",@"availability-layout"]containsObject:self.exerciseRequest[@"action"]];
    NSString *original=self.exerciseProfilePair[@"original"];
    if(profileRecipe&&original&&[status hasPrefix:@"failed_"]&&!self.presentedViewController&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive&&[[RewindStore shared].state[@"activeProfile"]isEqual:self.exerciseProfile]){
        [self selectProfile:original];
    }
    BOOL restored=original&&[[RewindStore shared].state[@"activeProfile"]isEqual:original];
    // Restore a failed read-only browsing recipe to Home so save/close remains
    // available; never override a real touch or background cancellation.
    if(self.exerciseReminderSheet&&self.presentedViewController==self.exerciseReminderSheet)[self dismissViewControllerAnimated:NO completion:nil];self.exerciseReminderSheet=nil;
    if([@[@"presentation",@"availability",@"detail-pages",@"detail-pages-landscape",@"reminders",@"feed-lists",@"feed-entity",@"feed-retry",@"feed-discovery"]containsObject:self.exerciseRequest[@"action"]]&&[status hasPrefix:@"failed_"]&&!self.presentedViewController&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive)[self exercisePressNavigation:@"Home"];
    NSDictionary *fontProbe=[self.exerciseFontProbe snapshot]?:@{};[self.exerciseFontProbe cancel];self.exerciseFontProbe=nil;
    NSDictionary *record=@{@"font_lookup":fontProbe,@"title_preparation":self.exercisePreparationReport?:@{},@"playback_case":[RWDeviceExercise playbackCase:self.exerciseRequest[@"playback_case"]]?:@{},@"run":self.exerciseRequest[@"run"],@"status":status,@"build":NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"],@"seconds":@(NSProcessInfo.processInfo.systemUptime-self.exerciseStarted),@"steps":[self.exerciseSamples copy],@"metrics":[[RWUIProbe shared]measurementSnapshot],@"profile_recipe":@(profileRecipe),@"original_profile_restored":@(restored),@"measurement":@"Visible foreground UIKit controls and animated programmatic scrolling. No synthesized touch/drag/deceleration; callback gaps do not prove actual rendered frames. RSS is process resident memory, not a plateau guarantee."};
    NSString *folder=[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"];
    [[NSFileManager defaultManager]createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data=[NSJSONSerialization dataWithJSONObject:record options:0 error:nil];[[RWAtomicWriter shared]write:data path:[folder stringByAppendingPathComponent:@"device-exercise.json"]];
    self.profileExperience.diagnosticSampling=NO;
    self.exerciseLifecycleReport=nil;self.exerciseLifetimeProbe=nil;self.exerciseRecoveryReport=nil;self.exercisePreparationReport=nil;self.exercisePreparationStarted=0;self.exercisePlaybackMeta=nil;self.exercisePlaybackMetadataError=nil;self.exercisePlaybackMetadataPending=NO;self.exerciseNetworkReport=nil;self.exerciseHTTPStage=nil;self.exerciseResumeRecord=nil;self.exercisePlayer=nil;self.exerciseRequest=nil;self.exerciseSteps=nil;self.exerciseSamples=nil;self.exerciseProfile=nil;self.exerciseProfilePair=nil;self.exerciseProfileAudit=nil;self.exerciseHomeAnchor=nil;self.exerciseDetailID=nil;self.exerciseCastBefore=nil;self.exerciseCastFirstNames=nil;self.exerciseCastPerson=nil;self.exerciseRemoteAbsent=NO;
    if(self.exerciseReminderSheet&&self.presentedViewController==self.exerciseReminderSheet)[self dismissViewControllerAnimated:NO completion:nil];self.exerciseReminderSheet=nil;self.exerciseReminderReport=nil;
    self.exerciseAvailabilityTarget=nil;[[RewindStore shared]report:@{@"device_exercise_status":status}];
}

#include "RewindDetailExercise.inc"
#include "RewindPresentationExercise.inc"
