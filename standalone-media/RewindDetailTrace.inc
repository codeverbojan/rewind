// One synchronous opening only. No timer, worker, user-state edits or provider work.
// Nested render/prepare samples overlap their enclosing open.render sample.
- (void)recordDetailOpenStage:(NSString *)stage started:(double)started {
    if(self.detailOpenStages)self.detailOpenStages[stage]=@(MAX(0,NSProcessInfo.processInfo.systemUptime-started));
}
- (void)finishDetailOpenTrace:(NSDictionary *)meta entered:(double)entered cached:(BOOL)cached {
    NSDictionary *trace=@{@"id":RWID(meta),@"type":meta[@"type"]?:@"",@"age_limit":[RewindStore shared].profile[@"maxAge"]?:@(-1),@"entered_uptime":@(entered),@"seconds":@(NSProcessInfo.processInfo.systemUptime-entered),@"cached_details":@(cached),@"stages":[self.detailOpenStages copy]?:@{}};
    self.detailOpenStages=nil;if(self.reviewMode)return;
    if(!self.detailOpenTraces)self.detailOpenTraces=[NSMutableArray new];[self.detailOpenTraces addObject:trace];while(self.detailOpenTraces.count>16)[self.detailOpenTraces removeObjectAtIndex:0];
    [[RewindStore shared]report:@{@"detail_open_traces":[self.detailOpenTraces copy]}];
}
