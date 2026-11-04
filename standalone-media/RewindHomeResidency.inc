// One detached All/Home viewport, never a stack of cached screens. Its rows are
// revalidated before reattachment; profile or geometry changes discard it.
- (NSDictionary *)currentHomeContext {
    RewindStore *store=[RewindStore shared];
    return @{@"profile":store.state[@"activeProfile"]?:@"",
             @"age":store.profile[@"maxAge"]?:@(-1),
             @"preferences":[RWDiscoveryMetadataPolicy preferences:store.profile[@"discoveryPreferences"]]};
}
- (void)discardParkedHome {
    self.parkedHomeView=nil;self.parkedHomeContext=nil;
}
- (void)parkCurrentHome {
    NSDictionary *context=[self currentHomeContext];
    // A discarded Home still has a browsing position. Metadata can change its
    // leading title after the last scroll callback, so save the current cells
    // before teardown, including profile selection and typed destinations.
    if(self.reviewMode||[self.page isEqual:@"Profiles"]||NSProcessInfo.processInfo.systemUptime<self.discoveryMemoryCooldown){if(!self.reviewMode)[self.homeView saveVisibleAnchors];[self discardParkedHome];return;}
    if(self.parkedHomeView&&![self.parkedHomeContext isEqual:context])[self discardParkedHome];
    if(!self.homeView||![self.content.accessibilityIdentifier isEqual:@"HomeAll"]){[self.homeView saveVisibleAnchors];return;}
    // A same-screen rebuild means its size or context changed. Do not retain
    // that obsolete view or a second Home view alongside its replacement.
    [self discardParkedHome];
    if(([self.page isEqual:@"Home"]&&[self.filter isEqual:@"All"])||![self.homeViewContext isEqual:context]){[self.homeView saveVisibleAnchors];return;}
    self.parkedHomeView=self.homeView;self.parkedHomeContext=self.homeViewContext;
    [self.parkedHomeView parkForReuse];
}
- (BOOL)restoreParkedHome {
    if(![self.filter isEqual:@"All"]||!self.parkedHomeView)return NO;
    double began=NSProcessInfo.processInfo.systemUptime;
    RWHomeView *view=self.parkedHomeView;NSDictionary *context=[self currentHomeContext];
    BOOL allowed=!self.reviewMode&&[self.parkedHomeContext isEqual:context]&&CGSizeEqualToSize(view.frame.size,self.content.bounds.size)&&NSProcessInfo.processInfo.systemUptime>=self.discoveryMemoryCooldown;
    [self discardParkedHome];if(!allowed)return NO;
    self.homeView=view;self.homeScope=view.scope;self.homeViewContext=context;self.homeHeaderRecord=nil;
    // Live age/hidden/availability/preferences and viewing progress are applied
    // while detached. UIKit cannot display stale cards, even for one frame.
    [self updateHomeList];
    self.content.scrollEnabled=NO;self.content.contentSize=self.content.bounds.size;
    [self.content addSubview:view];[view loadVisibleArtwork];[self recordVisibleDiscovery];
    if(!self.reviewMode)[[RewindStore shared]report:@{@"home_view":view.diagnostics,@"home_reactivated":@YES,@"home_reactivation_seconds":@(NSProcessInfo.processInfo.systemUptime-began)}];
    return YES;
}
