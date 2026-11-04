// Shared with the host lifecycle harness. Geometry and real scrolling still
// require device verification; no image I/O or decoding happens in this code.
- (void)cancelArtwork {
    _artGeneration++;_artScheduled=NO;
    [[RewindStore shared]cancelArtwork:_art];_artRequested=NO;_artAttempts=0;
}
- (void)loadArtwork {
    [self prepareContents];
    if(_artRequested||(_artComplete&&_art.image)||_artAttempts>=2||NSProcessInfo.processInfo.systemUptime<_retryAfter)return;
    _artRequested=YES;_artAttempts++;NSUInteger generation=_artGeneration;
    _placeholder.hidden=YES;_fallbackIcon.hidden=YES;
    __weak RWPoster *weak=self;
    [[RewindStore shared]artwork:_artURLs role:_landscape?@"backdrop":@"poster" identity:RWID(self.meta) into:_art completion:^(BOOL success){
        RWPoster *p=weak;if(!p||p->_artGeneration!=generation)return;
        p->_artComplete=success;p->_placeholder.hidden=success;p->_fallbackIcon.hidden=success;
        if(!success){p->_artRequested=NO;p->_retryAfter=NSProcessInfo.processInfo.systemUptime+10;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC),dispatch_get_main_queue(),^{RWPoster *current=weak;if(current&&current->_artGeneration==generation)[current loadArtworkIfVisible];});}
    }];
}
- (void)loadArtworkIfVisible {
    // Home owns a single visible-card construction budget across its shelves.
    // Artwork callbacks must not bypass that budget and build every new card.
    if(self.defersContents&&!self.contentsPrepared)return;
    if(_artRequested||(_artComplete&&_art.image)||![self artworkVisible])return;
    [self prepareContents];
    if(_artScheduled||_artAttempts>=2||NSProcessInfo.processInfo.systemUptime<_retryAfter)return;
    // Do not start work for every card crossed by a fling. A card that remains
    // visible for 120ms can load while the user continues scrolling slowly.
    // Stationary first paint and already-complete artwork incur no delay.
    if(![self artworkMoving]){[self loadArtwork];return;}
    _artScheduled=YES;NSUInteger generation=_artGeneration;__weak RWPoster *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,120*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        RWPoster *p=weak;if(!p||p->_artGeneration!=generation)return;p->_artScheduled=NO;
        if([p artworkVisible])[p loadArtwork];
    });
}
