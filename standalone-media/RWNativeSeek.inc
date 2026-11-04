// Shared by manual seeks and saved-position restoration. AVPlayer's currentTime
// can already show the target while its asynchronous seek still awaits data.
- (void)seekNative:(double)target {
    if(!self.player||self.closing||!isfinite(target))return;
    NSUInteger playback=self.playbackGeneration,seek=++self.nativeSeekGeneration;
    self.nativeSeekPending=YES;self.nativeSeekFinished=NO;self.nativeSeekTarget=target;
    self.nativeSeekStarted=NSProcessInfo.processInfo.systemUptime;self.nativeSeekCompleted=0;
    [self.metrics recordEvent:@"native_seek_started" values:@{@"target":@(target),@"seek":@(seek),@"wants_play":@(self.wantsPlay)} uptime:self.nativeSeekStarted];
    __weak RewindPlayer *weak=self;__weak AVPlayer *weakPlayer=self.player;
    [self.player seekToTime:CMTimeMakeWithSeconds(target,600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished){
        dispatch_async(dispatch_get_main_queue(),^{
            RewindPlayer *owner=weak;AVPlayer *player=weakPlayer;
            if(!owner||!player||owner.closing||owner.playbackGeneration!=playback||owner.nativeSeekGeneration!=seek||owner.player!=player)return;
            double now=NSProcessInfo.processInfo.systemUptime;
            owner.nativeSeekPending=NO;owner.nativeSeekFinished=finished;owner.nativeSeekCompleted=now;
            [owner.metrics recordEvent:@"native_seek_completed" values:@{@"target":@(target),@"seek":@(seek),@"finished":@(finished),@"seconds":@(now-owner.nativeSeekStarted),@"wants_play":@(owner.wantsPlay)} uptime:now];
            if(finished){owner.lastProgress=now;if(owner.wantsPlay)[player play];}
        });
    }];
}
