- (void)cancelDiscoveryCandidates {
    _candidateGeneration++;_candidateBusy=NO;[self.discoveryMetadata cancelCreditRequestsForOwner:_candidateOwner];_candidateOwner=nil;self.imdbIndex.paused=_discoveryPaused;
}
- (void)refreshDiscoveryCandidates {
    if(_discoveryPaused||_candidateBusy)return;double now=NSDate.date.timeIntervalSince1970,at=[self.profile[@"discoveryFetch"][@"at"]doubleValue];if(at>0&&now>=at&&now-at<3600)return;NSMutableArray *anchors=[NSMutableArray new];
    for(NSDictionary *m in self.discoveryHome[@"interestAnchors"])if([self allowed:m])[anchors addObject:[self.discoveryMetadata enrich:m]];
    if(!anchors.count)for(NSDictionary *signal in [RWRecommendationSignals select:self.profile now:now allows:^BOOL(NSDictionary *m){return [self allowed:m];}]){[anchors addObject:[self.discoveryMetadata enrich:signal[@"meta"]]];if(anchors.count==6)break;}
    NSInteger year=[[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian]component:NSCalendarUnitYear fromDate:NSDate.date];
    NSDictionary *plan=[RWDiscoveryCandidatePolicy plan:anchors state:self.profile[@"discoveryFetch"] restricted:self.restricted now:now year:year];if(!plan)return;
    _candidateBusy=YES;NSUInteger generation=++_candidateGeneration;NSString *profile=[self.state[@"activeProfile"]copy];_candidateOwner=[@"discovery:" stringByAppendingString:profile];
    NSDictionary *preferences=[self.profile[@"discoveryPreferences"]copy]?:@{};NSArray *hidden=[self.profile[@"hidden"]copy]?:@[];NSInteger age=[self.profile[@"maxAge"]integerValue];
    self.profile[@"discoveryFetch"]=plan[@"state"];[self saveForReason:NSStringFromSelector(_cmd)];self.imdbIndex.paused=YES;double began=NSProcessInfo.processInfo.systemUptime;
    void(^completed)(NSArray *,NSDictionary *,NSString *)=^(NSArray *items,NSDictionary *next,NSString *error){
        if(generation!=self->_candidateGeneration)return;self->_candidateBusy=NO;self->_candidateOwner=nil;self.imdbIndex.paused=self->_discoveryPaused;
        if(![profile isEqual:self.state[@"activeProfile"]]||age!=[self.profile[@"maxAge"]integerValue]||![preferences isEqual:self.profile[@"discoveryPreferences"]?:@{}]||![hidden isEqual:self.profile[@"hidden"]?:@[]])return;
        self.profile[@"discoveryFetch"]=[RWDiscoveryCandidatePolicy finish:plan next:next error:error now:NSDate.date.timeIntervalSince1970];[self saveForReason:NSStringFromSelector(_cmd)];
        NSArray *accepted=error?@[]:[plan[@"kind"]isEqual:@"credits"]?[RWDiscoveryCandidatePolicy verifiedItems:items plan:plan]:items?:@[];
        [self report:@{@"discovery_candidates":@{@"kind":plan[@"kind"],@"role":plan[@"role"]?:@"",@"type":plan[@"type"],@"received":@(items.count),@"accepted":@(accepted.count),@"seconds":@(NSProcessInfo.processInfo.systemUptime-began),@"continued":@(next.count>0),@"failed":@(error.length>0)}}];
        NSMutableDictionary *byProfile=[self->_diagnostics[@"discovery_candidates_by_profile"]mutableCopy]?:[NSMutableDictionary new];
        NSMutableDictionary *receipt=[self->_diagnostics[@"discovery_candidates"]mutableCopy];receipt[@"profile"]=profile;receipt[@"at"]=@(NSDate.date.timeIntervalSince1970);receipt[@"entity"]=plan[@"entity"]?:@"";receipt[@"next"]=next?:@{};byProfile[profile]=receipt;
        if(byProfile.count>8){NSArray *keys=[byProfile keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"at"]compare:b[@"at"]];}];[byProfile removeObjectForKey:keys.firstObject];}
        [self report:@{@"discovery_candidates_by_profile":byProfile}];
        if(!accepted.count)return;[self acceptDiscoveryCandidates:accepted];if(self.restricted)[self.ratings resolve:accepted];if(!self->_discoveryPaused)[self.discoveryMetadata enqueue:accepted];
    };
    if([plan[@"kind"]isEqual:@"credits"])[self.discoveryMetadata creditPage:plan[@"entity"] role:plan[@"role"] continuation:plan[@"continuation"] owner:_candidateOwner foreground:NO done:completed];
    else [self browse:plan[@"type"] sort:plan[@"sort"] genre:[plan[@"genre"]length]?plan[@"genre"]:nil year:[plan[@"year"]integerValue] skip:0 foreground:NO done:^(id items,NSString *error){completed([items isKindOfClass:NSArray.class]?items:nil,@{},error);}];
}
