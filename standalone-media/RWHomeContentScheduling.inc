// One Home-owned slice across all shelves, not one timer per cell or shelf.
// Re-evaluate current visible cells at execution; never capture a stale title.
- (void)cancelContentPreparation {_contentGeneration++;_contentScheduled=NO;_contentStarted=0;}
- (void)scheduleContentPreparation {
    // willDisplay/configure can run before UIKit publishes the new cell in
    // visibleCells. Always defer one notification until layout has completed.
    if(_contentScheduled||![self canPrepareContent])return;
    if(!_contentStarted)_contentStarted=NSProcessInfo.processInfo.systemUptime;
    _contentScheduled=YES;NSUInteger generation=_contentGeneration;__weak RWHomeView *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,16*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        RWHomeView *view=weak;if(!view||view->_contentGeneration!=generation)return;
        view->_contentScheduled=NO;if(![view canPrepareContent]){[view cancelContentPreparation];return;}
        if(![view hasPendingVisibleContent]){view->_contentStarted=0;return;}
        [view prepareNextVisibleContent];
        if(![view hasPendingVisibleContent]&&view->_contentStarted>0){[[RWUIProbe shared]work:@"home_content_settle" started:view->_contentStarted];view->_contentStarted=0;}
        if([view hasPendingVisibleContent])[view scheduleContentPreparation];
    });
}
