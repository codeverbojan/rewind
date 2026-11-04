// All player backends share subtitle choices. Preview/USB exercises keep their
// preference changes local to this player, just like their viewing position.
- (NSArray *)providedSubtitles {
    NSMutableArray *files=[[RWSubtitles providedBySource:self.source meta:self.meta allowBundled:self.deviceExerciseEnabled]mutableCopy];NSDictionary *saved=[self savedSubtitleFile];
    if(saved){NSIndexSet *duplicates=[files indexesOfObjectsPassingTest:^BOOL(NSDictionary *file,NSUInteger index,BOOL *stop){return [file[@"url"]isEqual:saved[@"url"]];}];[files removeObjectsAtIndexes:duplicates];[files insertObject:saved atIndex:0];}return files;
}
- (NSArray *)subtitleChoices {
    NSMutableArray *out=[NSMutableArray new];
    for(NSDictionary *raw in self.legacy.subtitleTracks){NSDictionary *d=raw[@"descriptor"]?:[RWSubtitlePolicy descriptor:@{@"name":raw[@"name"]?:@"",@"language":raw[@"language"]?:@"",@"stable":@NO} kind:@"mkv" locator:raw[@"id"]];if(d)[out addObject:@{@"descriptor":d,@"raw":raw,@"kind":@"mkv",@"label":raw[@"name"]?:@"Subtitle track"}];if(out.count>=128)return out;}
    for(AVMediaSelectionOption *option in self.captionGroup.options)if(option.playable){
        NSDictionary *d=[RWSubtitlePolicy descriptor:@{@"name":option.displayName?:@"",@"language":option.extendedLanguageTag?:[option.locale objectForKey:NSLocaleLanguageCode]?:@"",@"forced":@([option hasMediaCharacteristic:AVMediaCharacteristicContainsOnlyForcedSubtitles]),@"sdh":@([option hasMediaCharacteristic:AVMediaCharacteristicTranscribesSpokenDialogForAccessibility]||[option hasMediaCharacteristic:AVMediaCharacteristicDescribesMusicAndSoundForAccessibility])} kind:@"native" locator:option.propertyList];
        if(d)[out addObject:@{@"descriptor":d,@"option":option,@"kind":@"native",@"label":option.displayName?:@"Subtitle track"}];if(out.count>=128)return out;
    }
    for(NSDictionary *file in self.torrentSubtitleFiles){NSString *match=[RWSubtitlePolicy sidecarMatch:file videoID:self.videoID source:self.source];if([match isEqual:@"conflict"])continue;
        NSDictionary *d=[RWSubtitlePolicy descriptor:file kind:@"torrent" locator:@[file[@"index"]?:@(-1),file[@"path"]?:file[@"filename"]?:@"",file[@"size"]?:@0]];
        if(d)[out addObject:@{@"descriptor":d,@"raw":file,@"kind":@"torrent",@"match":match,@"label":file[@"name"]?:@"Subtitle file"}];if(out.count>=128)return out;
    }
    for(NSDictionary *file in [self providedSubtitles]){NSDictionary *d=[RWSubtitlePolicy descriptor:file kind:@"external" locator:file[@"url"]];
        if(d)[out addObject:@{@"descriptor":d,@"raw":file,@"kind":@"external",@"match":@"provided",@"label":file[@"name"]?:@"Provided subtitles"}];if(out.count>=128)return out;
    }return out;
}
- (void)selectSubtitleChoice:(NSDictionary *)choice manual:(BOOL)manual {
    if(![self subtitleOwnerCurrent]||!choice[@"descriptor"])return;NSString *kind=choice[@"kind"];
    [self clearSubtitles];self.subtitleDescriptor=choice[@"descriptor"];self.subtitleSelectionManual=manual;self.subtitleAutomatic=!manual;self.subtitleName=choice[@"label"];self.subtitleAddedFile=[choice[@"raw"][@"added"]boolValue]?choice[@"raw"]:nil;
    [self setSubtitlePreference:@"subtitlesEnabled" value:@YES];
    if([kind isEqual:@"torrent"]){[self beginSubtitleFile:choice[@"raw"]];return;}
    if([kind isEqual:@"external"]){[self loadSubtitles:choice[@"raw"][@"url"]];return;}
    self.subtitleDelay=[kind isEqual:@"mkv"]?[[self subtitleAdjustment][@"delay"]doubleValue]:0;
    self.subtitlePendingChoice=choice;self.subtitleChoiceStarted=NSProcessInfo.processInfo.systemUptime;
    if([kind isEqual:@"mkv"]){[self.legacy selectSubtitle:[choice[@"raw"][@"id"]intValue]];[self.legacy setSubtitleDelay:self.subtitleDelay];}
    else [self.player.currentItem selectMediaOption:choice[@"option"] inMediaSelectionGroup:self.captionGroup];
    [self confirmSubtitleChoice];
}
- (void)confirmSubtitleChoice {
    NSDictionary *choice=self.subtitlePendingChoice;if(!choice||![self subtitleOwnerCurrent])return;
    BOOL selected=[choice[@"kind"]isEqual:@"mkv"]?self.legacy.selectedSubtitle==[choice[@"raw"][@"id"]intValue]:[[self.player.currentItem.currentMediaSelection selectedMediaOptionInMediaSelectionGroup:self.captionGroup]isEqual:choice[@"option"]];
    if(selected){self.subtitlePendingChoice=nil;[self.captions setTitle:@"Subtitles" forState:UIControlStateNormal];if(self.subtitleSelectionManual)[self rememberSubtitleChoice:YES];}
    else if(NSProcessInfo.processInfo.systemUptime-self.subtitleChoiceStarted>5){BOOL manual=self.subtitleSelectionManual;[self clearSubtitles];if(manual)RWAlert(self,@"Subtitles unavailable",@"The player could not select this subtitle track.");}
}
- (void)addSubtitleAction:(UIAlertController *)sheet title:(NSString *)title work:(void(^)(void))work {
    __weak RewindPlayer *weak=self;void(^action)(void)=^{if(!weak||![weak subtitleOwnerCurrent])return;weak.automaticSubtitlesTried=YES;work();};
    if(self.deviceExerciseEnabled)self.exerciseSubtitleActions[title]=[action copy];
    [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *unused){action();}]];
}
- (void)beginSubtitleFile:(NSDictionary *)file {
    self.subtitlePending=YES;self.subtitleStarted=NSProcessInfo.processInfo.systemUptime;self.subtitleName=RWString(file[@"name"]);[self.captions setTitle:@"Loading…" forState:UIControlStateNormal];
    self.subtitleFormat=[(RWString(file[@"filename"]).length?RWString(file[@"filename"]):RWString(file[@"name"])) pathExtension].lowercaseString;
    NSUInteger generation=self.subtitleGeneration;__weak RewindPlayer *weak=self;
    [self.engine perform:^(TorrentEngine *engine){BOOL ok=[engine beginSubtitle:[file[@"index"]integerValue]];dispatch_async(dispatch_get_main_queue(),^{if(![weak subtitleOwnerCurrent]||weak.subtitleGeneration!=generation)return;if(!ok)[weak clearSubtitles];});}];
}
- (void)selectLegacySubtitle:(NSDictionary *)track {
    for(NSDictionary *choice in [self subtitleChoices])if([choice[@"kind"]isEqual:@"mkv"]&&[choice[@"raw"]isEqual:track]){[self selectSubtitleChoice:choice manual:YES];return;}
}
- (void)selectPreferredSubtitles {
    [self clearSubtitles];NSDictionary *preference=[self subtitlePreference];[self subtitlePreferences][@"subtitlesEnabled"]=preference[@"enabled"];
    NSDictionary *choice=[RWSubtitlePolicy select:[self subtitleChoices] preference:preference];if(choice)[self selectSubtitleChoice:choice manual:NO];
}
- (void)chooseSubtitles {
    self.lastInteraction=NSDate.date.timeIntervalSince1970;self.controls.alpha=1;__weak RewindPlayer *weak=self;
    if(self.deviceExerciseEnabled)self.exerciseSubtitleActions=[NSMutableDictionary new];
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Subtitles" message:self.subtitleName.length?[NSString stringWithFormat:@"Selected: %@",self.subtitleName]:@"Choose a language for this source" preferredStyle:UIAlertControllerStyleActionSheet];
    [self addSubtitleAction:a title:@"Off" work:^{[weak setSubtitlesEnabled:NO];[weak clearSubtitles];}];
    NSArray *choices=[self subtitleChoices];for(NSDictionary *choice in choices)[self addSubtitleAction:a title:choice[@"label"] work:^{[weak selectSubtitleChoice:choice manual:YES];}];
    if(self.subtitleData.length&&![self.subtitleFormat isEqual:@"vtt"]&&![self.subtitleDecode[@"format"]isEqual:@"vtt"]){
        if([self.subtitleDecode[@"status"]isEqual:@"needs_encoding"])a.message=@"Choose a text encoding to display this subtitle file correctly.";
        [self addSubtitleAction:a title:@"Text encoding…" work:^{[weak subtitleEncoding];}];
    }
    // Only offer adjustments this subtitle renderer can apply. Native embedded
    // captions do not use our overlay clock or font; do not show inert controls.
    if(self.cues.count||self.subtitlePending)[self addSubtitleAction:a title:@"Size and timing…" work:^{[weak subtitleSettings];}];
    else if(self.legacy&&self.legacy.selectedSubtitle>=0)[self addSubtitleAction:a title:@"Timing…" work:^{[weak subtitleSettings];}];
    if(!choices.count)a.message=(self.legacy||self.mediaSelectionLoaded)?@"No matching subtitles in this source. You can add an SRT or VTT link.":@"Subtitle tracks are still loading.";
    [self addSubtitleAction:a title:@"Add subtitle link…" work:^{
        UIAlertController *input=[UIAlertController alertControllerWithTitle:@"Subtitle link" message:@"A direct SRT or VTT address" preferredStyle:UIAlertControllerStyleAlert];[input addTextFieldWithConfigurationHandler:^(UITextField *f){f.keyboardType=UIKeyboardTypeURL;f.autocapitalizationType=UITextAutocapitalizationTypeNone;}];
        [input addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[input addAction:[UIAlertAction actionWithTitle:@"Load" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){if(![weak addSubtitleURL:input.textFields[0].text])RWAlert(weak,@"Subtitle link",@"Enter a direct HTTP or HTTPS subtitle address without a username or password.");}]];[weak presentViewController:input animated:YES completion:nil];
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=self.captions;a.popoverPresentationController.sourceRect=self.captions.bounds;[self presentViewController:a animated:YES completion:nil];
}
- (BOOL)addSubtitleURL:(NSString *)url {
    if(![self subtitleOwnerCurrent])return NO;NSDictionary *file=[RWSubtitlePolicy manualFileForURL:url];if(!file)return NO;
    NSDictionary *d=[RWSubtitlePolicy descriptor:file kind:@"external" locator:file[@"url"]];if(!d)return NO;
    self.automaticSubtitlesTried=YES;
    [self selectSubtitleChoice:@{@"kind":@"external",@"descriptor":d,@"raw":file,@"label":file[@"name"]} manual:YES];return YES;
}
- (void)clearSubtitles {[self clearSubtitleChoices:YES];}
- (void)clearSubtitleChoices:(BOOL)clearEmbedded {
    [self.subtitleTicker invalidate];self.subtitleTicker=nil;self.subtitleGeneration++;[self.subtitleTask cancel];self.subtitleTask=nil;[self.engine cancelSubtitle];self.subtitlePending=NO;self.subtitleAutomatic=NO;self.cues=nil;self.subtitleName=nil;self.subtitleLabel.text=@"";[self layoutSubtitle];
    [self.subtitleParseTask cancel];self.subtitleParseTask=nil;self.subtitleData=nil;self.subtitleDecode=nil;self.subtitleFormat=nil;
    self.subtitleDescriptor=nil;self.subtitleAddedFile=nil;self.subtitleContentDigest=nil;self.subtitlePendingChoice=nil;self.subtitleSelectionManual=NO;self.subtitleEncodingChoice=@"auto";self.subtitleDelay=0;[self.legacy setSubtitleDelay:0];
    if(self.captionGroup)[self.player.currentItem selectMediaOption:nil inMediaSelectionGroup:self.captionGroup];if(clearEmbedded)[self.legacy selectSubtitle:-1];[self.captions setTitle:@"Subtitles" forState:UIControlStateNormal];
}
- (BOOL)shouldRefreshExternalSubtitles {
    return self.cues.count&&self.wantsPlay&&!self.closing&&!self.exhausted&&self.mediaVerified&&!self.seeking&&!self.nativeSeekPending&&[self playbackRate]>0&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive;
}
- (void)syncSubtitleRefresh {
    if(![self shouldRefreshExternalSubtitles]){[self.subtitleTicker invalidate];self.subtitleTicker=nil;return;}
    if(self.subtitleTicker.running)return;
    __weak RewindPlayer *weak=self;
    self.subtitleTicker=[[RWSubtitleTicker alloc]initWithStep:^BOOL{
        RewindPlayer *owner=weak;if(!owner||![owner shouldRefreshExternalSubtitles])return NO;
        [owner refreshSubtitleText];return YES;
    } interval:self.legacy?.05:.1];
}
- (void)refreshSubtitleText {
    double position=self.legacy&&[self shouldRefreshExternalSubtitles]?self.legacy.subtitlePosition:[self playbackPosition];
    // VLC exposes the destination clock before a buffered seek presents it.
    // Keep live text off the old picture; paused captions remain inspectable.
    BOOL buffering=self.wantsPlay&&self.legacy.captionBuffering;
    NSString *text=!buffering&&isfinite(position)?[RWSubtitles textIn:self.cues at:position-self.subtitleDelay]:@"";
    if(![self.subtitleLabel.text isEqual:text]){self.subtitleLabel.text=text;[self.exerciseSubtitleTiming recordAssignment:text position:position];}[self layoutSubtitle];[self syncSubtitleRefresh];
}
- (void)subtitleSettings {
    BOOL overlay=self.cues.count||self.subtitlePending;__weak RewindPlayer *weak=self;
    if(self.deviceExerciseEnabled)self.exerciseSubtitleActions=[NSMutableDictionary new];
    UIAlertController *a=[UIAlertController alertControllerWithTitle:overlay?@"Subtitle size and timing":@"Subtitle timing" message:[NSString stringWithFormat:@"Timing for this subtitle: %+.1f seconds\n\nAdjust when every line is early or late. If the difference grows as you watch, choose another subtitle file.",self.subtitleDelay] preferredStyle:UIAlertControllerStyleActionSheet];
    if(overlay){NSArray *names=@[@"Small",@"Medium",@"Large"],*sizes=@[@20,@24,@28];
        for(NSUInteger i=0;i<names.count;i++){NSNumber *size=sizes[i];[self addSubtitleAction:a title:names[i] work:^{weak.subtitleLabel.font=[UIFont systemFontOfSize:size.doubleValue weight:UIFontWeightSemibold];[weak setSubtitlePreference:@"subtitleSize" value:size];[weak layoutSubtitle];}];}
    }
    for(NSNumber *shift in @[@(-.5),@.5,@0]){NSString *label=shift.doubleValue<0?@"Show 0.5 seconds earlier":shift.doubleValue>0?@"Show 0.5 seconds later":@"Reset timing";
        [self addSubtitleAction:a title:label work:^{weak.subtitleDelay=shift.doubleValue?MAX(-10,MIN(10,weak.subtitleDelay+shift.doubleValue)):0;[weak.legacy setSubtitleDelay:weak.subtitleDelay];[weak refreshSubtitleText];[weak rememberSubtitleAdjustment];}];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=self.captions;a.popoverPresentationController.sourceRect=self.captions.bounds;[self presentViewController:a animated:YES completion:nil];
}
- (void)installSubtitleData:(NSData *)data {
    self.subtitlePending=NO;self.subtitleData=data.length<=2*1024*1024?data:nil;[self decodeSubtitleEncoding:@"auto"];
}
- (void)subtitleEncoding {
    if(!self.subtitleData.length)return;__weak RewindPlayer *weak=self;
    if(self.deviceExerciseEnabled)self.exerciseSubtitleActions=[NSMutableDictionary new];
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Subtitle text" message:@"Choose the language group if letters look wrong." preferredStyle:UIAlertControllerStyleActionSheet];
    for(NSDictionary *option in [RWSubtitles encodingOptions])[self addSubtitleAction:sheet title:option[@"name"] work:^{weak.subtitleAutomatic=NO;weak.subtitleSelectionManual=YES;[weak decodeSubtitleEncoding:option[@"id"]];}];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];sheet.popoverPresentationController.sourceView=self.captions;sheet.popoverPresentationController.sourceRect=self.captions.bounds;[self presentViewController:sheet animated:YES completion:nil];
}
- (void)decodeSubtitleEncoding:(NSString *)encoding {
    [self.subtitleParseTask cancel];self.cues=nil;self.subtitleDecode=nil;[self refreshSubtitleText];[self.captions setTitle:@"Loading…" forState:UIControlStateNormal];
    static NSOperationQueue *queue;static dispatch_once_t once;dispatch_once(&once,^{queue=[NSOperationQueue new];queue.maxConcurrentOperationCount=1;queue.name=@"org.local.rewind.subtitles";queue.qualityOfService=NSQualityOfServiceUtility;});
    NSData *data=self.subtitleData;NSString *format=self.subtitleFormat,*videoID=self.videoID,*media=[self subtitleMediaKey],*oldDigest=self.subtitleContentDigest;NSDictionary *profile=[[self subtitlePreferences]copy],*descriptor=self.subtitleDescriptor;double oldDelay=self.subtitleDelay;
    NSUInteger generation=self.subtitleGeneration;__weak RewindPlayer *weak=self;
    NSBlockOperation *operation=[NSBlockOperation new];__weak NSBlockOperation *weakOperation=operation;
    [operation addExecutionBlock:^{NSBlockOperation *task=weakOperation;if(!task||task.cancelled)return;
        NSString *digest=[RWSubtitlePolicy digest:data],*key=[RWSubtitlePolicy adjustmentKey:descriptor videoID:videoID mediaKey:media contentDigest:digest];NSDictionary *adjustment=[RWSubtitlePolicy adjustment:profile key:key];
        NSString *selected=[encoding isEqual:@"auto"]?(adjustment[@"encoding"]?:@"auto"):encoding;double delay=[oldDigest isEqual:digest]?oldDelay:[adjustment[@"delay"]doubleValue];
        NSDictionary *result=[RWSubtitles parse:data format:format encoding:selected cancelled:^BOOL{return task.cancelled;}];
        dispatch_async(dispatch_get_main_queue(),^{if(!weak||![weak subtitleOwnerCurrent]||task.cancelled||weak.subtitleGeneration!=generation||weak.subtitleParseTask!=task)return;weak.subtitleParseTask=nil;weak.subtitleContentDigest=digest;weak.subtitleEncodingChoice=selected;weak.subtitleDelay=delay;
            NSMutableDictionary *metrics=[result mutableCopy];[metrics removeObjectForKey:@"cues"];metrics[@"cue_count"]=@([result[@"cues"]count]);weak.subtitleDecode=metrics;
            if([result[@"status"]isEqual:@"ok"]){[weak applySubtitleCues:result[@"cues"]];if(weak.subtitleSelectionManual){[weak rememberSubtitleChoice:YES];[weak rememberSubtitleAdjustment];[weak rememberSubtitleFile];}}
            else{[weak.captions setTitle:@"Subtitles" forState:UIControlStateNormal];if([result[@"status"]isEqual:@"needs_encoding"]){if(!weak.subtitleAutomatic)[weak subtitleEncoding];}
                else if(!weak.subtitleAutomatic)RWAlert(weak,@"Subtitles unavailable",result[@"error"]?:@"This file could not be read.");}
        });
    }];self.subtitleParseTask=operation;[queue addOperation:operation];
}
- (void)applySubtitleCues:(NSArray *)cues {
    if(cues.count){self.cues=cues;[self refreshSubtitleText];[self.captions setTitle:@"Subtitles" forState:UIControlStateNormal];}
    else{[self.captions setTitle:@"Subtitles" forState:UIControlStateNormal];self.subtitleName=nil;if(!self.subtitleAutomatic)RWAlert(self,@"Subtitles unavailable",@"This file did not contain readable subtitle timings.");}
}
- (void)loadSubtitles:(NSString *)url {
    self.subtitleFormat=[NSURL URLWithString:url].path.pathExtension.lowercaseString;
    if(self.deviceExerciseEnabled&&[RWSubtitles isBundledSubtitle:url]){[self installSubtitleData:[NSData dataWithContentsOfFile:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:[@"Rewind/" stringByAppendingString:[url substringFromIndex:6]]]]];return;}
    __weak RewindPlayer *weak=self;NSUInteger generation=++self.subtitleGeneration;self.subtitleTransfer=@{};[self.captions setTitle:@"Loading…" forState:UIControlStateNormal];
    self.subtitleTask=[[RWSubtitleDownload alloc]initWithURL:[NSURL URLWithString:url] completion:^(NSData *data,NSString *error,NSDictionary *metrics){
        if(![weak subtitleOwnerCurrent]||weak.subtitleGeneration!=generation)return;weak.subtitleTask=nil;weak.subtitleTransfer=metrics;
        [[RewindStore shared]report:@{@"subtitle_transfer":metrics}];
        if(error){[weak.captions setTitle:@"Subtitles" forState:UIControlStateNormal];weak.subtitleName=nil;if(!weak.subtitleAutomatic)RWAlert(weak,@"Subtitles unavailable",error);return;}
        [weak installSubtitleData:data];
    }];
}
