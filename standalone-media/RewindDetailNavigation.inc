// Preserve the populated detail layout while a person/company page is open.
// Revalidate on Back; retaining rows prevents a shorter page clamping the offset.
- (NSDictionary *)detailNavigationSnapshot {
    if(![self.page isEqual:@"Details"])return @{};
    NSArray *titles=self.relatedTitles?:@[];
    return @{@"profile":[RewindStore shared].state[@"activeProfile"]?:@"",@"title":RWID(self.detail),@"tab":self.detailTab?:@"Episodes",@"related":[titles subarrayWithRange:NSMakeRange(0,MIN((NSUInteger)24,titles.count))]};
}
- (void)restoreDetailNavigation:(NSDictionary *)saved {
    self.relatedGeneration++;self.relatedKey=nil;self.relatedTitles=@[];self.detailTab=@"Episodes";
    RewindStore *store=[RewindStore shared];
    if(![saved isKindOfClass:NSDictionary.class]||![saved[@"profile"]isEqual:store.state[@"activeProfile"]]||![saved[@"title"]isEqual:RWID(self.detail)])return;
    if([@[@"Episodes",@"About",@"More like this"]containsObject:saved[@"tab"]?:@""])self.detailTab=saved[@"tab"];
    NSMutableArray *titles=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(NSDictionary *meta in [saved[@"related"]isKindOfClass:NSArray.class]?saved[@"related"]:@[]){
        NSString *identifier=RWID(meta);if(!identifier.length||[identifier isEqual:RWID(self.detail)]||[seen containsObject:identifier]||![meta[@"type"]isEqual:self.detail[@"type"]]||[store.profile[@"hidden"]containsObject:identifier]||![store allowed:meta])continue;
        [seen addObject:identifier];[titles addObject:meta];if(titles.count==24)break;
    }
    self.relatedTitles=titles;
}
