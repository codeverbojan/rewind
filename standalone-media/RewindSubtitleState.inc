// Capture ownership before presenting the player. Never redirect a delayed
// subtitle action into whichever profile has become active in the meantime.
- (void)captureSubtitlePreferences {
    RewindStore *store=RewindStore.shared;self.subtitleProfileID=[store.state[@"activeProfile"]copy];self.subtitleProfileSnapshot=[NSMutableDictionary new];
    for(NSString *key in @[@"subtitleLanguage",@"subtitlesEnabled",@"subtitleSize",@"subtitleForced",@"subtitleSDH",@"subtitleSelections",@"subtitleAdjustments",@"subtitleLinks"]){id value=[store profile][key];if(value)self.subtitleProfileSnapshot[key]=[value copy];}
    // Old profile-wide delay has no release identity. Preserve its stored value
    // for compatibility, but do not apply it to unrelated future subtitles.
}
- (NSMutableDictionary *)subtitlePreferences {return self.transientSubtitlePreferences?:self.subtitleProfileSnapshot;}
- (BOOL)subtitleOwnerCurrent {return !self.closing&&self.subtitleProfileID.length&&[self.subtitleProfileID isEqual:[RewindStore shared].state[@"activeProfile"]];}
- (void)setSubtitlePreference:(NSString *)key value:(id)value {
    if(![self subtitleOwnerCurrent]||![@[@"subtitleLanguage",@"subtitlesEnabled",@"subtitleSize",@"subtitleForced",@"subtitleSDH"]containsObject:key])return;
    [self subtitlePreferences][key]=value;
    // Size is a display preference. Enabled/language/role decisions in this
    // player are saved with the title below, not written as global overrides.
    if(!self.transient&&[key isEqual:@"subtitleSize"]){[[RewindStore shared]profile][key]=value;[[RewindStore shared]save];}
}
- (NSString *)subtitleMediaKey {return [RWSubtitlePolicy mediaKey:self.source bundleBuild:[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]description]?:@""];}
- (NSDictionary *)subtitlePreference {return [RWSubtitlePolicy preference:[self subtitlePreferences] videoID:self.videoID mediaKey:[self subtitleMediaKey]];}
- (void)saveSubtitleMap:(NSDictionary *)map field:(NSString *)field {
    if(!map||![self subtitleOwnerCurrent])return;[self subtitlePreferences][field]=map;
    if(!self.transient){[[RewindStore shared]profile][field]=map;[[RewindStore shared]save];}
}
- (void)rememberSubtitleChoice:(BOOL)enabled {
    if(![self subtitleOwnerCurrent])return;
    NSDictionary *map=[RWSubtitlePolicy saveChoice:self.subtitleDescriptor enabled:enabled videoID:self.videoID mediaKey:[self subtitleMediaKey] existing:[self subtitlePreferences][@"subtitleSelections"] now:NSDate.date.timeIntervalSince1970];[self saveSubtitleMap:map field:@"subtitleSelections"];
}
- (NSString *)subtitleAdjustmentKey {return [RWSubtitlePolicy adjustmentKey:self.subtitleDescriptor videoID:self.videoID mediaKey:[self subtitleMediaKey] contentDigest:self.subtitleContentDigest];}
- (NSDictionary *)subtitleAdjustment {return [RWSubtitlePolicy adjustment:[self subtitlePreferences] key:[self subtitleAdjustmentKey]];}
- (void)rememberSubtitleAdjustment {
    if(![self subtitleOwnerCurrent])return;NSDictionary *adjustment=@{@"delay":@(self.subtitleDelay),@"encoding":self.subtitleEncodingChoice?:@"auto"};
    NSDictionary *map=[RWSubtitlePolicy saveAdjustment:adjustment key:[self subtitleAdjustmentKey] existing:[self subtitlePreferences][@"subtitleAdjustments"] now:NSDate.date.timeIntervalSince1970];[self saveSubtitleMap:map field:@"subtitleAdjustments"];
}
- (void)setSubtitlesEnabled:(BOOL)enabled {[self setSubtitlePreference:@"subtitlesEnabled" value:@(enabled)];if(!enabled)[self rememberSubtitleChoice:NO];}

- (NSDictionary *)savedSubtitleFile {return [RWSubtitlePolicy manualFileInProfile:[self subtitlePreferences] videoID:self.videoID mediaKey:[self subtitleMediaKey]];}
- (void)rememberSubtitleFile {
    if(![self subtitleOwnerCurrent]||!self.subtitleAddedFile)return;
    NSDictionary *map=[RWSubtitlePolicy saveManualFile:self.subtitleAddedFile videoID:self.videoID mediaKey:[self subtitleMediaKey] existing:[self subtitlePreferences][@"subtitleLinks"] now:NSDate.date.timeIntervalSince1970];
    [self saveSubtitleMap:map field:@"subtitleLinks"];
}
