// Fixed public-film diagnostic. Observes connectivity; never changes radios.
// The independent USB harness owns/restores the short Wi-Fi interruption.
- (BOOL)exerciseNetworkStep:(NSString *)kind {
    NSDictionary *state=[self.exercisePlayer deviceExerciseSnapshot],*torrent=state[@"torrent"];
    if(![self.exerciseRequest[@"action"]isEqual:@"playback-reconnect"]||!self.exercisePlayer||![state[@"transient"]boolValue]||![state[@"video_id"]isEqual:@"rw:cosmos"]||[state[@"exhausted"]boolValue])return NO;
    struct sockaddr_in address={};address.sin_len=sizeof(address);address.sin_family=AF_INET;
    SCNetworkReachabilityRef reach=SCNetworkReachabilityCreateWithAddress(NULL,(const struct sockaddr *)&address);
    SCNetworkReachabilityFlags flags=0;BOOL observed=reach&&SCNetworkReachabilityGetFlags(reach,&flags);if(reach)CFRelease(reach);
    if(!observed)return NO;
    BOOL online=(flags&kSCNetworkReachabilityFlagsReachable)&&!(flags&kSCNetworkReachabilityFlagsConnectionRequired);
    if(!self.exerciseNetworkReport)self.exerciseNetworkReport=[NSMutableDictionary new];
    self.exerciseNetworkReport[@"reachable"]=@(online);self.exerciseNetworkReport[@"observed_at"]=@(NSDate.date.timeIntervalSince1970);
    if([kind isEqual:@"network-await-offline"]){
        if(online){self.exerciseIndex--;return YES;}
        if([torrent[@"video_complete"]boolValue]||![torrent[@"metadata"]boolValue]||![torrent[@"session_id"]length]||[state[@"duration"]doubleValue]<630)return NO;
        self.exerciseNetworkReport[@"before_seek"]=state;return YES;
    }
    NSDictionary *before=self.exerciseNetworkReport[@"before_seek"],*original=before[@"torrent"];
    if(!before||![original[@"session_id"]isEqual:torrent[@"session_id"]])return NO;
    if([kind isEqual:@"network-seek"]){
        if(online)return NO;
        self.exerciseNetworkReport[@"seek_at"]=@(NSDate.date.timeIntervalSince1970);
        return [self.exercisePlayer deviceExerciseControl:@"network-seek-600"];
    }
    if(![kind isEqual:@"network-await-recovery"])return NO;
    // Require a real uncached reader request, not merely an incomplete file.
    if(!online&&[torrent[@"requested_piece"]integerValue]>=0&&![torrent[@"requested_piece_verified"]boolValue]&&[torrent[@"wanted_bytes"]longLongValue]>[torrent[@"wanted_done_bytes"]longLongValue]&&!self.exerciseNetworkReport[@"missing_during_outage"])
        self.exerciseNetworkReport[@"missing_during_outage"]=state;
    BOOL recovered=online&&self.exerciseNetworkReport[@"missing_during_outage"]&&[state[@"position"]doubleValue]>=620&&[state[@"position"]doubleValue]<660&&[state[@"media_verified"]boolValue]&&[state[@"frame_visible"]boolValue]&&[state[@"wants_play"]boolValue]&&[torrent[@"video_verified_bytes"]longLongValue]>[original[@"video_verified_bytes"]longLongValue]&&[torrent[@"peer_payload_bytes"]longLongValue]>[original[@"peer_payload_bytes"]longLongValue];
    if(recovered){self.exerciseNetworkReport[@"recovered"]=state;self.exerciseNetworkReport[@"recovered_at"]=@(NSDate.date.timeIntervalSince1970);}
    else self.exerciseIndex--;
    return YES;
}
