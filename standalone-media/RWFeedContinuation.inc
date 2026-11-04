- (BOOL)nearContinuationEnd {
    double viewport=self.horizontal?self.bounds.size.width:self.bounds.size.height,extent=self.horizontal?self.contentSize.width:self.contentSize.height,offset=self.horizontal?self.contentOffset.x:self.contentOffset.y;
    return (!self.horizontal||_horizontalIntent)&&isfinite(viewport)&&viewport>0&&isfinite(extent)&&extent>=0&&isfinite(offset)&&extent-offset<=viewport*(self.horizontal?1.6:2.0);
}
- (void)retryContinuationFromGesture {
    // A new deliberate swipe can retry once. Layout, metadata publications
    // and deceleration cannot turn a failed row into an automatic retry loop.
    if(!self.horizontal||_horizontalRequestCommitted||_loading||_updating||!_more||(!_error.length&&!self.continuationPaused)||_rangeError.length||!self.window||!self.onLoadMore||![self nearContinuationEnd])return;
    _horizontalRequestCommitted=YES;_manualRequests++;self.onLoadMore(YES);
}
- (void)considerMore {
    if((self.horizontal&&_horizontalRequestCommitted)||self.continuationPaused||_updating||_requestScheduled||_loading||!_more||_error.length||_rangeError.length||!_automatic||!self.onLoadMore||!self.window)return;
    if(![self nearContinuationEnd])return;
    NSString *token=[NSString stringWithFormat:@"%lu:%lu",(unsigned long)_cursor,(unsigned long)[self recordCount]];if([token isEqual:_lastAutoToken])return;
    _requestScheduled=YES;NSUInteger generation=_loadGeneration;__weak RWPosterCollection *weak=self;
    dispatch_async(dispatch_get_main_queue(),^{RWPosterCollection *view=weak;if(!view)return;view->_requestScheduled=NO;
        NSString *current=[NSString stringWithFormat:@"%lu:%lu",(unsigned long)view->_cursor,(unsigned long)[view recordCount]];
        if(generation!=view->_loadGeneration||![token isEqual:current]){[view considerMore];return;}
        if((!view.horizontal||!view->_horizontalRequestCommitted)&&!view.continuationPaused&&view.window&&[view nearContinuationEnd]&&!view->_updating&&!view->_loading&&view->_more&&!view->_error.length&&!view->_rangeError.length&&view->_automatic&&![token isEqual:view->_lastAutoToken]&&view.onLoadMore){
            // Commit only when the request is actually delivered. A refresh,
            // temporary detach or loading transition must not consume it.
            view->_lastAutoToken=token;if(view.horizontal)view->_horizontalRequestCommitted=YES;view->_automaticRequests++;view.onLoadMore(NO);
        }
    });
}
