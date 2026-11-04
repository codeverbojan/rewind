// Real cached/network title and actor screens. No player or user-state mutations.
- (BOOL)exerciseContentBack {
    NSMutableArray *queue=[NSMutableArray arrayWithObject:self.content];while(queue.count){UIView *view=queue.firstObject;[queue removeObjectAtIndex:0];if([view isKindOfClass:RWButton.class]&&([[(RWButton *)view currentTitle]isEqual:@"Back"]||[view.accessibilityLabel isEqual:@"Back"])){[(RWButton *)view sendActionsForControlEvents:UIControlEventTouchUpInside];return YES;}[queue addObjectsFromArray:view.subviews];}return NO;
}
- (BOOL)exerciseCastCapture:(NSString *)name {
    NSString *path=[[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"]stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]];[[NSFileManager defaultManager]removeItemAtPath:path error:nil];[self.view layoutIfNeeded];RWCapture(self.view,name);return [[[NSFileManager defaultManager]attributesOfItemAtPath:path error:nil]fileSize]>0;
}
- (BOOL)exerciseCastStep:(NSString *)kind {
    if([kind isEqual:@"cast-open"]){NSDictionary *meta=[[RewindStore shared]cachedDetails:@{@"id":@"tt0435761",@"type":@"movie",@"name":@"Toy Story 3"}];if(![[RewindStore shared]allowed:meta])return NO;[self showDetails:meta];return [self.page isEqual:@"Details"]&&[RWID(self.detail)isEqual:@"tt0435761"];}
    if([kind isEqual:@"cast-audit-entity"]){
        NSDictionary *audit=@{@"id":RWID(self.entity),@"name":RWString(self.entity[@"name"]),@"biography_characters":@(RWString(self.entity[@"biography"]).length),@"facts":@([self.entity[@"facts"]count]),@"credits":@(self.entityFeed.count),@"scope_matches":@([self.entityFeed.context isEqual:[self currentEntityScope]]),@"error":self.entityError?:@""};
        [[RewindStore shared]report:@{@"actor_page_acceptance":audit}];
        BOOL rich=[RWID(self.entity)isEqual:@"Q1138602"]&&[audit[@"credits"]unsignedIntegerValue]>0&&[audit[@"scope_matches"]boolValue]&&([RewindStore shared].restricted||([audit[@"biography_characters"]unsignedIntegerValue]>40&&[audit[@"facts"]unsignedIntegerValue]>0));
        return [self.page isEqual:@"Entity"]&&[RWString(self.entity[@"name"])isEqual:self.exerciseCastPerson]&&rich&&[self exerciseCastCapture:@"device-exercise-cast-person"];
    }
    if([kind isEqual:@"cast-back"])return [self.page isEqual:@"Entity"]&&[self exerciseContentBack]&&[self.page isEqual:@"Details"];
    if([kind isEqual:@"cast-return-home"])return [self exerciseContentBack]&&[self.page isEqual:@"Home"];
    if(![self.page isEqual:@"Details"]||![RWID(self.detail)isEqual:@"tt0435761"]||!self.castStage.window)return NO;
    if([kind isEqual:@"cast-reveal"]){CGFloat y=MAX(0,MIN(self.castStage.frame.origin.y-24,MAX(0,self.content.contentSize.height-self.content.bounds.size.height)));[self.content setContentOffset:CGPointMake(0,y) animated:YES];return YES;}
    [self.castStage updateViewport];NSDictionary *state=self.castStage.diagnostics;NSArray *visible=state[@"visible"];
    if([kind isEqual:@"cast-capture-first"]){if([state[@"content_pending"]boolValue])return NO;self.exerciseCastFirstNames=[visible valueForKey:@"name"];return visible.count>0&&[state[@"people"]unsignedIntegerValue]>visible.count&&[state[@"created_cells"]unsignedIntegerValue]<[state[@"people"]unsignedIntegerValue]&&[state[@"visible_photos"]unsignedIntegerValue]>0&&[self exerciseCastCapture:@"device-exercise-cast-first"];}
    if([kind isEqual:@"cast-end"]){CGFloat end=[state[@"maximum_offset"]doubleValue];if(end<=0)return NO;[self.castStage.rail setContentOffset:CGPointMake(end,0) animated:YES];return YES;}
    if([kind isEqual:@"cast-capture-last"]){if([state[@"content_pending"]boolValue])return NO;self.exerciseCastOffset=[state[@"offset"]doubleValue];return fabs(self.exerciseCastOffset-[state[@"maximum_offset"]doubleValue])<=1&&![[visible valueForKey:@"name"]isEqual:self.exerciseCastFirstNames]&&[self exerciseCastCapture:@"device-exercise-cast-last"];}
    if([kind isEqual:@"cast-rerender"]){self.exerciseCastBefore=self.castStage;self.exerciseCastCreated=[state[@"created_cells"]unsignedIntegerValue];[self render];return YES;}
    if([kind isEqual:@"cast-audit-reuse"]){BOOL ok=self.castStage==self.exerciseCastBefore&&fabs([state[@"offset"]doubleValue]-self.exerciseCastOffset)<=1&&[state[@"created_cells"]unsignedIntegerValue]==self.exerciseCastCreated;self.exerciseCastBefore=nil;return ok;}
    if([kind isEqual:@"cast-open-person"]){NSString *name=visible.lastObject[@"name"];if(!name.length)return NO;NSString *identifier=[@"RWCastPerson:" stringByAppendingString:name];NSMutableArray *queue=[NSMutableArray arrayWithObject:self.castStage];while(queue.count){UIView *view=queue.firstObject;[queue removeObjectAtIndex:0];if([view isKindOfClass:RWButton.class]&&[view.accessibilityIdentifier isEqual:identifier]){self.exerciseCastPerson=name;[(RWButton *)view sendActionsForControlEvents:UIControlEventTouchUpInside];return [self.page isEqual:@"Entity"];}[queue addObjectsFromArray:view.subviews];}return NO;}
    if([kind isEqual:@"cast-audit-return"])return visible.count>0&&fabs([state[@"offset"]doubleValue]-self.exerciseCastOffset)<=1&&[[visible valueForKey:@"name"]containsObject:self.exerciseCastPerson]&&[self exerciseCastCapture:@"device-exercise-cast-return"];
    return NO;
}
