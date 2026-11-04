// Capture the event's own monotonic timestamp on VLC's worker. No dispatch to
// the main queue, where UI work would make the anchor late.
static const libvlc_event_type_t RWCaptionClockEvents[]={libvlc_MediaPlayerTimeChanged,libvlc_MediaPlayerPlaying,libvlc_MediaPlayerPaused,libvlc_MediaPlayerStopped,libvlc_MediaPlayerEndReached,libvlc_MediaPlayerEncounteredError,libvlc_MediaPlayerBuffering,libvlc_MediaPlayerOpening};
static void RWCaptionClockEvent(const libvlc_event_t *event,void *opaque) {
    @autoreleasepool{
        RWCaptionClock *clock=(__bridge RWCaptionClock *)opaque;
        if(event->type==libvlc_MediaPlayerTimeChanged)[clock sample:event->u.media_player_time_changed.new_time/1000. uptime:NSProcessInfo.processInfo.systemUptime];
        else if(event->type==libvlc_MediaPlayerBuffering)[clock setBuffering:!isfinite(event->u.media_player_buffering.new_cache)||event->u.media_player_buffering.new_cache<100];
        else [clock setRunning:event->type==libvlc_MediaPlayerPlaying];
    }
}
static BOOL RWAttachCaptionClock(libvlc_media_player_t *player,RWCaptionClock *clock) {
    libvlc_event_manager_t *manager=libvlc_media_player_event_manager(player);
    size_t count=sizeof(RWCaptionClockEvents)/sizeof(RWCaptionClockEvents[0]);
    for(size_t i=0;i<count;i++)if(libvlc_event_attach(manager,RWCaptionClockEvents[i],RWCaptionClockEvent,(__bridge void *)clock)!=0){
        for(size_t j=0;j<i;j++)libvlc_event_detach(manager,RWCaptionClockEvents[j],RWCaptionClockEvent,(__bridge void *)clock);return NO;
    }return YES;
}
static void RWDetachCaptionClock(libvlc_media_player_t *player,RWCaptionClock *clock) {
    for(libvlc_event_type_t event:RWCaptionClockEvents)libvlc_event_detach(libvlc_media_player_event_manager(player),event,RWCaptionClockEvent,(__bridge void *)clock);
}
