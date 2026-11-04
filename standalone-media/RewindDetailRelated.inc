- (void)requestRelatedTitles {
    if(self.reviewMode||![self.page isEqual:@"Details"]||!RWID(self.detail).length)return;RewindStore *s=[RewindStore shared];NSDictionary *meta=[s.discoveryMetadata enrich:self.detail];NSString *key=[NSString stringWithFormat:@"%@:%@:%@",s.state[@"activeProfile"],RWID(meta),meta[@"discovery"][@"revision"]?:@0];if([self.relatedKey isEqual:key])return;self.relatedKey=key;NSUInteger generation=++self.relatedGeneration;__weak RewindController *weak=self;
    [s relatedTitles:meta done:^(NSArray *items){if(generation!=weak.relatedGeneration||![weak.page isEqual:@"Details"]||![weak.relatedKey isEqual:key])return;BOOL changed=![weak.relatedTitles isEqual:items];weak.relatedTitles=items;if(changed)[weak requestDetailRender];}];
}
// A richer details response changes the ranking input while a job may be pending.
- (void)acceptDetailResult:(NSDictionary *)result profile:(NSString *)profileID identifier:(NSString *)identifier {
    RewindStore *store=[RewindStore shared];
    if(![profileID isEqual:store.state[@"activeProfile"]]||![self.page isEqual:@"Details"]||![RWID(self.detail)isEqual:identifier]||!result||[self.detail isEqual:result])return;
    self.detail=[store discoveryMeta:result];self.relatedKey=nil;
    [self requestRelatedTitles];
    [self requestDetailRender];
}
