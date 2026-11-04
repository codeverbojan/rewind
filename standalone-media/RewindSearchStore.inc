// Search has foreground priority in the shared metadata budget. Obsolete
// keystrokes cancel their own tasks without cancelling unrelated lookups.
- (NSArray *)localSearch:(NSString *)query {
    NSMutableArray *pool=[NSMutableArray new];
    for(NSArray *items in @[self.movies,self.series,self.freshMovies,self.freshSeries,self.familyCatalog,self.openFilms,self.saved])if(items)[pool addObjectsFromArray:items];
    for(NSDictionary *record in self.history){NSMutableDictionary *meta=[record[@"meta"]mutableCopy];if(meta[@"seriesName"])meta[@"name"]=meta[@"seriesName"];if(meta)[pool addObject:meta];}
    return [RWTVPolicy localMatches:[self allowedItems:pool] query:query];
}
- (NSURLSessionDataTask *)searchCatalog:(NSString *)type query:(NSString *)query done:(RWResult)done {
    return [self.catalogSearch searchType:type query:query done:done];
}
