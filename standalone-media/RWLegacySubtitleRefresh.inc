// Opt-in bounded diagnostics. All mutation is on the main thread; the event
// time may be captured on VLC's worker to distinguish dispatch delay.
- (BOOL)subtitleTraceEnabled {return _subtitleTraceEnabled;}
- (void)setSubtitleTraceEnabled:(BOOL)enabled {_subtitleTraceEnabled=enabled;if(!enabled)_subtitleTrace=nil;}
- (void)recordSubtitleEvent:(NSString *)event track:(int)track at:(double)eventTime {
    if(!_subtitleTraceEnabled||_stopped)return;
    double now=NSProcessInfo.processInfo.systemUptime;if(!_subtitleTrace)_subtitleTrace=[NSMutableArray new];
    if(_subtitleTrace.count>=32)[_subtitleTrace removeObjectAtIndex:0];
    [_subtitleTrace addObject:@{@"event":event,@"at":@(eventTime>0?eventTime:now),@"observed":@(now),@"track":@(track),@"selected":@(_player?libvlc_video_get_spu(_player):-1),@"position_ms":@(_player?libvlc_media_player_get_time(_player):-1),@"wants_play":@(_wantPlay)}];
}
// A successful set_spu only queues the switch. Refresh after ESSelected so
// the subtitle decoder exists before the paused seek is demuxed.
- (void)selectSubtitle:(int)identifier {
    if(_stopped||!_player)return;
    [self recordSubtitleEvent:@"selection-request" track:identifier at:0];
    if(libvlc_video_get_spu(_player)==identifier){[self schedulePausedSubtitleRefresh];return;}
    _subtitleRefreshTrack=identifier;_subtitleRefreshAwaitingSelection=_subtitleEventsAttached;
    if(libvlc_video_set_spu(_player,identifier)!=0){_subtitleRefreshAwaitingSelection=NO;[self recordSubtitleEvent:@"selection-error" track:identifier at:0];return;}
    [self recordSubtitleEvent:@"selection-queued" track:identifier at:0];
    if(!_subtitleRefreshAwaitingSelection)[self schedulePausedSubtitleRefresh];
}
- (void)selectedSubtitleDidChange:(int)identifier {
    if(_stopped||!_player||!_subtitleRefreshAwaitingSelection||identifier!=_subtitleRefreshTrack)return;
    _subtitleRefreshAwaitingSelection=NO;[self schedulePausedSubtitleRefresh];
}
// Track changes while paused need a fresh decoded frame. Coalesce the
// clear/select/delay sequence into one seek to the current position; never
// resume playback or run after the player closes.
- (void)schedulePausedSubtitleRefresh {
    if(_subtitleRefreshAwaitingSelection||_subtitleRefreshScheduled||_stopped||_wantPlay||!_player||!libvlc_media_player_is_seekable(_player))return;
    _subtitleRefreshScheduled=YES;__weak RWLegacyPlayer *weak=self;
    [self recordSubtitleEvent:@"refresh-queued" track:libvlc_video_get_spu(_player) at:0];
    dispatch_async(dispatch_get_main_queue(),^{RWLegacyPlayer *view=weak;if(!view)return;view->_subtitleRefreshScheduled=NO;
        if(view->_subtitleRefreshAwaitingSelection||view->_stopped||view->_wantPlay||!view->_player||!libvlc_media_player_is_seekable(view->_player))return;
        libvlc_time_t position=libvlc_media_player_get_time(view->_player);if(position<0)return;
        view->_subtitleRefreshes++;[view recordSubtitleEvent:@"refresh-issued" track:libvlc_video_get_spu(view->_player) at:0];libvlc_media_player_set_time(view->_player,position);
    });
}
