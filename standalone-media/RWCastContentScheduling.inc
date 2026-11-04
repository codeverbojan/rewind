// One outstanding callback, weak ownership, at most one visible card per slice.
// A fresh 16ms delay after each slice yields instead of draining all UI work in
// one main-queue burst. No display link/timer survives an idle or hidden strip.
- (void)cancelContentPreparation {_contentGeneration++;_contentScheduled=NO;}
- (void)scheduleContentPreparation {
    if(_contentScheduled||![self canPrepareContent]||![self hasPendingVisibleContent])return;
    _contentScheduled=YES;NSUInteger generation=_contentGeneration;__weak RWCastStrip *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,16*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        RWCastStrip *strip=weak;if(!strip||strip->_contentGeneration!=generation)return;
        strip->_contentScheduled=NO;if(![strip canPrepareContent])return;
        [strip prepareNextVisibleContent];[strip scheduleContentPreparation];
    });
}
