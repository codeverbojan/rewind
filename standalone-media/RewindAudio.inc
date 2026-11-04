// Snapshot the owning profile. A delayed menu callback must never write into
// whichever profile happens to be active later. Diagnostic players stay local.
- (void)captureAudioPreferences {
    RewindStore *store=[RewindStore shared];self.audioProfileID=[store.state[@"activeProfile"]copy];
    NSDictionary *profile=[store profile];self.audioProfileSnapshot=[NSMutableDictionary new];
    for(NSString *key in @[@"audioLanguage",@"audioSelections"]){id value=profile[key];if(value)self.audioProfileSnapshot[key]=[value copy];}
}
- (NSDictionary *)audioPreference {
    return [RWAudioPolicy preferenceInProfile:self.audioProfileSnapshot videoID:self.videoID mediaKey:[RWAudioPolicy mediaKey:self.source]];
}
- (void)rememberAudioChoice:(NSDictionary *)choice {
    RewindStore *store=[RewindStore shared];
    if(self.closing||!self.audioProfileID.length||![self.audioProfileID isEqual:store.state[@"activeProfile"]])return;
    NSDictionary *map=[RWAudioPolicy selectionsBySaving:choice mediaKey:[RWAudioPolicy mediaKey:self.source] videoID:self.videoID existing:self.audioProfileSnapshot[@"audioSelections"] now:NSDate.date.timeIntervalSince1970];
    if(!map)return;self.audioProfileSnapshot[@"audioSelections"]=map;
    if(!self.transient){[store profile][@"audioSelections"]=map;[store save];}
}
- (BOOL)selectNativeAudio:(NSDictionary *)choice remember:(BOOL)remember {
    if(self.closing||![self.audioChoices containsObject:choice])return NO;
    AVPlayerItemTrack *track=choice[@"track"];
    if(![self.player.currentItem.tracks containsObject:track]||![choice[@"descriptor"][@"compatible"]boolValue])return NO;
    for(AVPlayerItemTrack *other in self.player.currentItem.tracks)if([other.assetTrack.mediaType isEqual:AVMediaTypeAudio])other.enabled=other==track;
    if(!track.enabled)return NO;
    self.player.muted=NO;self.player.volume=1;
    self.audioSelection=@{@"track":choice[@"descriptor"],@"reason":remember?@"manual":@"automatic",@"message":@""};
    if(remember)[self rememberAudioChoice:choice[@"descriptor"]];return YES;
}
