// Bounded real transport exercise. Only an owned temporary profile and metadata
// instance use the fixed USB loopback endpoint; normal app remains standalone.
- (NSDictionary *)exerciseEntityNetworkSnapshot {
    NSMutableDictionary *s=[[self exerciseDiscoverySnapshot]mutableCopy];s[@"network"]=[RewindStore shared].discoveryMetadata.entitySearchDiagnostics;s[@"message"]=self.exploreMessage.text?:@"";s[@"feed"]=[self.feedGrid continuationDiagnostics]?:@{};s[@"input"]=self.exploreSearch.text?:@"";return s;
}
- (BOOL)exerciseEntityNetworkStep:(NSString *)kind {
    RewindStore *s=RewindStore.shared;NSInteger build=[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue];
    if(!self.exerciseResumeOwned||![RWDeviceExercise ownsResumeProfile:s.profile build:build])return NO;
    if([kind isEqual:@"entitynet-prepare"]){
        if(self.exerciseOriginalEntityMetadata)return NO;
        if(!s.catalogReady){if(NSProcessInfo.processInfo.systemUptime-self.exerciseStarted>20)return NO;self.exerciseIndex--;return YES;}
        [s setDiscoveryPaused:YES];self.exerciseOriginalEntityMetadata=s.discoveryMetadata;
        NSDictionary *cached=@{@"titles":s.discoveryMetadata.titleSnapshot,@"entities":s.discoveryMetadata.entitySnapshot};
        s.discoveryMetadata=[[RWExerciseEntityMetadata alloc]initWithPath:@"" cached:cached seed:@{}];[self go:@"Search"];return [self exerciseDiscoveryButton:@"People"];
    }
    NSDictionary *queries=@{@"slow":@"Christopher Nolan",@"fast":@"Anne Hathaway",@"cached":@"Anne Hathaway",@"failure":@"Anne",@"empty":@"Missing identity check",@"studio-slow":@"Warner",@"studio":@"Pixar",@"exit":@"Warner Bros"};
    if([kind hasPrefix:@"entitynet-query-"]){NSString *q=queries[[kind substringFromIndex:16]];self.exerciseEntityStarted=NSProcessInfo.processInfo.systemUptime;return q&&[self exerciseDiscoveryQuery:q];}
    if([kind isEqual:@"entitynet-await-response"]){NSDictionary *d=s.discoveryMetadata.entitySearchDiagnostics;BOOL found=[d[@"active"]boolValue]&&[d[@"query"]isEqual:self.exploreSearch.text]&&[d[@"response_received"]boolValue];if(!found){if(NSProcessInfo.processInfo.systemUptime-self.exerciseEntityStarted>12)return NO;self.exerciseIndex--;}return YES;}
    if([kind isEqual:@"entitynet-await"]){BOOL done=[self.exploreQuery isEqual:self.exploreSearch.text]&&self.exploreRemoteStarted&&!self.exploreRemoteBusy&&!self.exploreBusy;if(!done){if(NSProcessInfo.processInfo.systemUptime-self.exerciseEntityStarted>15)return NO;self.exerciseIndex--;}return YES;}
    if([kind isEqual:@"entitynet-studios"]){[self go:@"Search"];return [self exerciseDiscoveryButton:@"Studios"];}
    if([kind isEqual:@"entitynet-home"]){[self go:@"Home"];return YES;}
    if([kind isEqual:@"entitynet-footer"]){
        [self.feedGrid layoutIfNeeded];[self.feedGrid setContentOffset:CGPointMake(0,MAX(0,self.feedGrid.contentSize.height-self.feedGrid.bounds.size.height)) animated:NO];[self.feedGrid layoutIfNeeded];self.exerciseExploreOffset=self.feedGrid.contentOffset.y;return YES;
    }
    if([kind isEqual:@"entitynet-top"]){[self.feedGrid setContentOffset:CGPointZero animated:NO];[self.feedGrid layoutIfNeeded];return YES;}
    if([kind isEqual:@"entitynet-retry"]){
        [self.feedGrid layoutIfNeeded];self.exerciseEntityStarted=NSProcessInfo.processInfo.systemUptime;
        for(UIView *footer in [self.feedGrid visibleSupplementaryViewsOfKind:UICollectionElementKindSectionFooter])for(UIView *v in footer.subviews)if([v isKindOfClass:RWButton.class]&&[[(RWButton *)v currentTitle]isEqual:@"Try again"]&&!v.hidden){[(RWButton *)v sendActionsForControlEvents:UIControlEventTouchUpInside];return YES;}return NO;
    }
    if(![kind hasPrefix:@"entitynet-audit-"])return NO;NSString *label=[kind substringFromIndex:16];NSDictionary *snap=[self exerciseEntityNetworkSnapshot],*network=snap[@"network"];NSArray *ids=[snap[@"visible"]valueForKey:@"id"];BOOL ok=![network[@"active"]boolValue]&&![snap[@"busy"]boolValue];
    if([@[@"fast",@"late",@"cached",@"retry"]containsObject:label]){
        ok=ok&&[self.page isEqual:@"Explore"]&&[self.exploreKind isEqual:@"People"]&&[ids containsObject:@"Q36301"]&&![ids containsObject:@"Q25191"]&&!self.exploreError.length;
        if(![label isEqual:@"retry"])ok=ok&&[self.exploreQuery isEqual:@"Anne Hathaway"];
        if([label isEqual:@"fast"]){self.exerciseEntityRequests=[network[@"started"]unsignedIntegerValue];ok=ok&&[network[@"cancelled"]integerValue]==1;}
        if([label isEqual:@"cached"])ok=ok&&[network[@"cache_hits"]integerValue]==1&&[network[@"started"]unsignedIntegerValue]==self.exerciseEntityRequests;
        if([label isEqual:@"retry"])ok=ok&&[self.exploreQuery isEqual:@"Anne"]&&[snap[@"feed"][@"manual_requests"]integerValue]==1;
    }else if([label isEqual:@"failure"]){ok=ok&&self.exploreError.length&&[ids containsObject:@"Q36301"]&&[snap[@"message"]isEqual:@"Your existing matches remain available"];}
    else if([label isEqual:@"footer"]){BOOL retry=NO;for(NSDictionary *footer in snap[@"feed"][@"footers"])retry|=[footer[@"button"]isEqual:@"Try again"];ok=ok&&self.exploreError.length&&retry;}
    else if([label isEqual:@"retry-footer"]){ok=ok&&!self.exploreError.length&&[snap[@"feed"][@"manual_requests"]integerValue]==1&&fabs(self.feedGrid.contentOffset.y-self.exerciseExploreOffset)<=1;}
    else if([label isEqual:@"empty"]){ok=ok&&self.exploreError.length&&!self.exploreFeed.count&&[snap[@"message"]isEqual:@"Online search is unavailable. Try again."];}
    else if([label isEqual:@"studio"]||[label isEqual:@"studio-late"]){ok=ok&&[self.page isEqual:@"Explore"]&&[self.exploreKind isEqual:@"Studios"]&&[self.exploreQuery isEqual:@"Pixar"]&&[ids containsObject:@"Q127552"]&&[network[@"cancelled"]integerValue]==2&&!self.exploreError.length;}
    else if([label isEqual:@"exit"]){ok=ok&&[self.page isEqual:@"Home"]&&[network[@"cancelled"]integerValue]==3;}
    else ok=NO;
    if([@[@"fast",@"failure",@"footer",@"empty",@"studio"]containsObject:label])ok=[self exerciseCastCapture:[@"device-exercise-" stringByAppendingString:kind]]&&ok;return ok;
}
- (void)finishEntityNetworkExercise {
    if(!self.exerciseOriginalEntityMetadata)return;[self.searchTimer invalidate];[self resetExplore];RewindStore *s=RewindStore.shared;[s setDiscoveryPaused:YES];[s.discoveryMetadata invalidate];s.discoveryMetadata=self.exerciseOriginalEntityMetadata;self.exerciseOriginalEntityMetadata=nil;
}
