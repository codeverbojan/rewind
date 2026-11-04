// Real Search -> discovery -> entity/mood controls. No catalog fixtures or
// state deletion; screenshot/metadata evidence distinguishes artwork coverage
// from successful navigation.
- (NSArray *)exerciseDiscoveryCards {
    NSMutableArray *cards=[NSMutableArray new];NSArray *paths=[self.feedGrid.indexPathsForVisibleItems sortedArrayUsingSelector:@selector(compare:)];
    for(NSIndexPath *path in paths){UICollectionViewCell *cell=[self.feedGrid cellForItemAtIndexPath:path];NSMutableArray *queue=[NSMutableArray arrayWithArray:cell.contentView.subviews?:@[]];
        while(queue.count){UIView *v=queue.firstObject;[queue removeObjectAtIndex:0];if([v isKindOfClass:RWPoster.class]){[cards addObject:v];break;}[queue addObjectsFromArray:v.subviews];}}
    return cards;
}
- (BOOL)exerciseDiscoveryButton:(NSString *)title {
    NSMutableArray *queue=[NSMutableArray arrayWithObject:self.content];while(queue.count){UIView *v=queue.firstObject;[queue removeObjectAtIndex:0];if([v isKindOfClass:RWButton.class]&&[[(RWButton *)v currentTitle]isEqual:title]){[(RWButton *)v sendActionsForControlEvents:UIControlEventTouchUpInside];return YES;}[queue addObjectsFromArray:v.subviews];}return NO;
}
- (NSDictionary *)exerciseDiscoverySnapshot {
    RewindStore *s=[RewindStore shared];NSMutableArray *cards=[NSMutableArray new];
    for(RWPoster *card in [self exerciseDiscoveryCards]){
        if([card isKindOfClass:RWEntityCard.class]){NSMutableDictionary *entry=[[(RWEntityCard *)card diagnostics]mutableCopy];CGRect bounds=[card convertRect:card.bounds toView:self.feedGrid];CGRect shown=CGRectIntersection(bounds,self.feedGrid.bounds);entry[@"visible_fraction"]=@(CGRectIsNull(shown)?0:(shown.size.width*shown.size.height)/MAX(1,bounds.size.width*bounds.size.height));[cards addObject:entry];}
        else [cards addObject:@{@"id":RWID(card.meta),@"name":RWString(card.meta[@"name"]),@"type":RWString(card.meta[@"type"]),@"allowed":@([s allowed:card.meta]),@"audience_allowed":@([RWDiscoveryMetadataPolicy recommendationAudienceAllows:card.meta preferences:s.profile[@"discoveryPreferences"] restricted:s.restricted])}];
    }
    return @{@"page":self.page?:@"",@"kind":self.exploreKind?:@"",@"query":self.exploreQuery?:@"",@"mood":self.exploreMood?:@"",@"type_filter":self.exploreType?:@"",@"profile":s.state[@"activeProfile"],@"restricted":@(s.restricted),@"visible":cards,@"count":@([self.page isEqual:@"Entity"]?self.entityFeed.count:self.exploreFeed.count),@"offset":@(self.feedGrid.contentOffset.y),@"error":[self.page isEqual:@"Entity"]?self.entityError?:@"":self.exploreError?:@"",@"busy":@([self.page isEqual:@"Entity"]?(self.entityBusy||self.entitySelecting):(self.exploreBusy||self.exploreRemoteBusy)),@"remote_started":@(self.exploreRemoteStarted),@"remote_target_was_absent":@(self.exerciseRemoteAbsent),@"entity":@{@"id":RWID(self.entity),@"role":self.entity[@"creditRole"]?:@"",@"image_role":self.entity[@"imageRole"]?:@"",@"image_url_available":@(RWString(self.entity[@"image"]).length>0),@"biography_characters":@(RWString(self.entity[@"biography"]).length),@"facts":@([self.entity[@"facts"]count]),@"scope_matches":@([self.entityFeed.context isEqual:[self currentEntityScope]])}};
}
- (BOOL)exerciseDiscoveryQuery:(NSString *)query {
    if(![self.page isEqual:@"Explore"]||!self.exploreSearch.window)return NO;
    self.exploreSearch.text=query;[self searchBar:self.exploreSearch textDidChange:query];return YES;
}
- (BOOL)exerciseDiscoveryOpen:(NSString *)identifier {
    for(RWPoster *card in [self exerciseDiscoveryCards])if([RWID(card.meta)isEqual:identifier]){self.exerciseExploreOffset=self.feedGrid.contentOffset.y;[card sendActionsForControlEvents:UIControlEventTouchUpInside];return YES;}return NO;
}
- (BOOL)exerciseDiscoveryStep:(NSString *)kind {
    if([kind isEqual:@"discover-people"])return [self.page isEqual:@"Search"]&&[self exerciseDiscoveryButton:@"People"]&&[self.page isEqual:@"Explore"];
    if([kind isEqual:@"discover-studios"])return [self.page isEqual:@"Search"]&&[self exerciseDiscoveryButton:@"Studios"]&&[self.page isEqual:@"Explore"];
    if([kind isEqual:@"discover-moods"])return [self.page isEqual:@"Search"]&&[self exerciseDiscoveryButton:@"Moods"]&&[self.page isEqual:@"Explore"];
    if([kind isEqual:@"discover-query-remote"]){BOOL found=NO;for(NSDictionary *record in [RewindStore shared].discoveryMetadata.titleSnapshot.allValues)for(NSString *field in @[@"cast",@"directors"])for(NSDictionary *ref in record[field])if([ref[@"id"]isEqual:@"Q229990"])found=YES;self.exerciseRemoteAbsent=!found;return [self exerciseDiscoveryQuery:@"Agnes Varda"];}
    if([kind isEqual:@"discover-query-person"])return [self exerciseDiscoveryQuery:@"Christopher Nolan"];
    if([kind isEqual:@"discover-query-studio"])return [self exerciseDiscoveryQuery:@"Pixar"];
    if([kind isEqual:@"discover-open-person"])return [self exerciseDiscoveryOpen:@"Q25191"]&&[self.page isEqual:@"Entity"];
    if([kind isEqual:@"discover-open-studio"])return [self exerciseDiscoveryOpen:@"Q127552"]&&[self.page isEqual:@"Entity"];
    if([kind isEqual:@"discover-open-mood"])return [self exerciseDiscoveryOpen:@"mood:Epic adventures"]&&[self.page isEqual:@"Explore"]&&[self.exploreMood isEqual:@"Epic adventures"];
    if([kind isEqual:@"discover-shows"]){NSMutableArray *queue=[NSMutableArray arrayWithObject:self.content];while(queue.count){UIView *v=queue.firstObject;[queue removeObjectAtIndex:0];if([v isKindOfClass:UISegmentedControl.class]){UISegmentedControl *tabs=(UISegmentedControl *)v;if(tabs.numberOfSegments==2&&[[tabs titleForSegmentAtIndex:1]isEqual:@"Shows"]){tabs.selectedSegmentIndex=1;[tabs sendActionsForControlEvents:UIControlEventValueChanged];return YES;}}[queue addObjectsFromArray:v.subviews];}return NO;}
    if([kind isEqual:@"discover-back"])return [self exerciseContentBack];
    if(![kind hasPrefix:@"discover-audit-"])return NO;
    NSDictionary *audit=[self exerciseDiscoverySnapshot];NSArray *cards=audit[@"visible"];NSString *target=[kind substringFromIndex:[@"discover-audit-" length]];BOOL ok=YES;
    if([@[@"person-page",@"studio-page"]containsObject:target]){NSDictionary *entity=audit[@"entity"];ok=[self.page isEqual:@"Entity"]&&[entity[@"id"]isEqual:[target isEqual:@"person-page"]?@"Q25191":@"Q127552"]&&[entity[@"scope_matches"]boolValue]&&[audit[@"count"]unsignedIntegerValue]>0&&[entity[@"biography_characters"]unsignedIntegerValue]>40;}
    else if([target isEqual:@"person-return"]||[target isEqual:@"studio-return"])ok=[self.page isEqual:@"Explore"]&&[self.exploreQuery isEqual:[target isEqual:@"person-return"]?@"Christopher Nolan":@"Pixar"]&&fabs(self.feedGrid.contentOffset.y-self.exerciseExploreOffset)<=1;
    else if([@[@"remote",@"person",@"studio"]containsObject:target]){NSString *expected=[target isEqual:@"remote"]?@"Q229990":[target isEqual:@"person"]?@"Q25191":@"Q127552";ok=[self.page isEqual:@"Explore"]&&[cards.firstObject[@"id"]isEqual:expected];if([target isEqual:@"remote"])ok=ok&&self.exploreRemoteStarted&&self.exerciseRemoteAbsent;}
    else if([target isEqual:@"films"]||[target isEqual:@"shows"]){NSString *type=[target isEqual:@"films"]?@"movie":@"series";ok=cards.count>0&&[self.exploreMood isEqual:@"Epic adventures"];for(NSDictionary *card in cards)if(![card[@"type"]isEqual:type]||![card[@"allowed"]boolValue]||(!self.exploreQuery.length&&![card[@"audience_allowed"]boolValue]))ok=NO;}
    else {NSString *type=[target isEqual:@"people"]?@"person":[target isEqual:@"studios"]?@"studio":@"mood";NSMutableSet *ids=[NSMutableSet new];ok=cards.count>=2;for(NSDictionary *card in cards){if(![card[@"type"]isEqual:type]||![card[@"profile"]isEqual:audit[@"profile"]]||[ids containsObject:card[@"id"]]||![card[@"known_for"]count])ok=NO;[ids addObject:card[@"id"]];}}
    BOOL captured=[self exerciseCastCapture:[@"device-exercise-discovery-" stringByAppendingString:target]];return ok&&captured;
}
