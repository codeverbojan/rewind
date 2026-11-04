// Real foreground UIKit rotation. No private orientation API, synthetic device
// sensor value, rotation-lock change or offscreen review controller.
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if([@[@"presentation",@"library-browse",@"entity-art",@"availability-layout",@"home-categories-landscape",@"detail-pages-landscape",@"subtitles-layout-native",@"subtitles-layout-mkv",@"subtitles-layout-native-landscape"]containsObject:self.exerciseRequest[@"action"]]&&self.exerciseOrientationMask)return self.exerciseOrientationMask;
    return [super supportedInterfaceOrientations];
}
- (BOOL)exerciseRequestOrientation:(UIInterfaceOrientation)orientation {
    if(![@[@"presentation",@"library-browse",@"entity-art",@"availability-layout",@"home-categories-landscape",@"detail-pages-landscape",@"subtitles-layout-native",@"subtitles-layout-mkv",@"subtitles-layout-native-landscape"]containsObject:self.exerciseRequest[@"action"]]||self.presentedViewController||![RewindStore shared].profile||([RewindStore shared].restricted&&![self.exerciseRequest[@"action"]isEqual:@"home-categories-landscape"]))return NO;
    if(![@[@(UIInterfaceOrientationPortrait),@(UIInterfaceOrientationLandscapeLeft),@(UIInterfaceOrientationLandscapeRight)]containsObject:@(orientation)])return NO;
    if(!self.exerciseOriginalOrientation)self.exerciseOriginalOrientation=UIApplication.sharedApplication.statusBarOrientation;
    self.exerciseTargetOrientation=orientation;self.exerciseOrientationMask=(UIInterfaceOrientationMask)(1UL<<orientation);
    self.exerciseOrientationDeadline=NSProcessInfo.processInfo.systemUptime+8;
    RWOrientationProbe *probe=[RWOrientationProbe new];probe.target=orientation;probe.modalPresentationStyle=UIModalPresentationFullScreen;self.exerciseOrientationProbe=probe;
    NSString *run=self.exerciseRequest[@"run"];__weak RewindController *weak=self;
    [self presentViewController:probe animated:NO completion:^{
        if(weak.presentedViewController!=probe)return;
        [weak dismissViewControllerAnimated:NO completion:^{
            if(weak.exerciseOrientationProbe==probe)weak.exerciseOrientationProbe=nil;
            if([weak.exerciseRequest[@"run"]isEqual:run])[weak.view setNeedsLayout];
        }];
    }];
    return YES;
}
- (NSDictionary *)exercisePresentationSnapshot {
    CGSize root=self.view.bounds.size,window=self.view.window.bounds.size;
    return @{@"orientation":@(UIApplication.sharedApplication.statusBarOrientation),@"original_orientation":@(self.exerciseOriginalOrientation),@"target_orientation":@(self.exerciseTargetOrientation),@"root_width":@(root.width),@"root_height":@(root.height),@"window_width":@(window.width),@"window_height":@(window.height),@"foreground":@(UIApplication.sharedApplication.applicationState==UIApplicationStateActive),@"root_is_key_window":@(self.view.window.isKeyWindow&&self.view.window.rootViewController==self),@"modal_present":@(self.presentedViewController!=nil),@"review_mode":@(self.reviewMode),@"detail":[self exerciseDetailSnapshot],@"trailer":self.preview.diagnostics?:@{},@"lookup":[[RewindStore shared]trailerDiagnostics]?:@{},@"cast":self.castStage.diagnostics?:@{}};
}
- (BOOL)exercisePresentationStep:(NSString *)kind {
    BOOL ok=YES;
    if([kind isEqual:@"presentation-portrait"])ok=[self exerciseRequestOrientation:UIInterfaceOrientationPortrait];
    else if([kind isEqual:@"presentation-landscape"])ok=[self exerciseRequestOrientation:UIInterfaceOrientationLandscapeLeft];
    else if([kind isEqual:@"presentation-restore"])ok=[self exerciseRequestOrientation:self.exerciseOriginalOrientation];
    else if([kind isEqual:@"presentation-await-orientation"]){
        BOOL portrait=UIInterfaceOrientationIsPortrait(self.exerciseTargetOrientation);CGSize size=self.view.bounds.size;
        BOOL ready=!self.presentedViewController&&!self.exerciseOrientationProbe&&UIApplication.sharedApplication.statusBarOrientation==self.exerciseTargetOrientation&&(portrait?size.height>size.width:size.width>size.height);
        if(!ready){if(NSProcessInfo.processInfo.systemUptime<self.exerciseOrientationDeadline)self.exerciseIndex--;else ok=NO;}
    }else if([kind isEqual:@"presentation-top"]){[self.content setContentOffset:CGPointZero animated:NO];[self loadVisiblePosters];}
    else if([kind hasPrefix:@"presentation-audit-"]){
        NSString *label=[kind substringFromIndex:[@"presentation-audit-" length]];
        NSDictionary *snapshot=[self exercisePresentationSnapshot];
        ok=[snapshot[@"foreground"]boolValue]&&[snapshot[@"root_is_key_window"]boolValue]&&![snapshot[@"review_mode"]boolValue]&&![snapshot[@"modal_present"]boolValue]&&[snapshot[@"orientation"]isEqual:snapshot[@"target_orientation"]];
        if([label isEqual:@"restored"])ok=ok&&[snapshot[@"orientation"]isEqual:snapshot[@"original_orientation"]];
        else {ok=ok&&[self.page isEqual:@"Details"]&&[RWID(self.detail)isEqual:self.exerciseDetailID];NSDictionary *h=self.detailHeader.diagnostics;ok=ok&&[h[@"image_present"]boolValue];}
        ok=[self exerciseCastCapture:[@"device-exercise-" stringByAppendingString:kind]]&&ok;
    }else ok=NO;
    self.exercisePresentationReport=[self exercisePresentationSnapshot];return ok;
}
- (void)finishPresentationExercise {
    if(![@[@"presentation",@"library-browse",@"entity-art",@"availability-layout",@"home-categories-landscape",@"detail-pages-landscape",@"subtitles-layout-native",@"subtitles-layout-mkv",@"subtitles-layout-native-landscape"]containsObject:self.exerciseRequest[@"action"]])return;
    // The recipe explicitly restores and verifies its original orientation on
    // success. On cancellation, release only our modal/mask; the user's current
    // sensor/rotation-lock policy remains authoritative.
    self.exerciseOrientationMask=0;
    if(self.exerciseOrientationProbe&&self.presentedViewController==self.exerciseOrientationProbe)[self dismissViewControllerAnimated:NO completion:nil];
    self.exerciseOrientationProbe=nil;self.exerciseOriginalOrientation=UIInterfaceOrientationUnknown;self.exerciseTargetOrientation=UIInterfaceOrientationUnknown;self.exercisePresentationReport=nil;
    [UIViewController attemptRotationToDeviceOrientation];
}
