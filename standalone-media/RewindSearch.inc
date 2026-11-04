- (void)cancelSearchRequests {
    for(NSURLSessionTask *task in self.searchTasks)[[RewindStore shared].catalogSearch cancel:task];[self.searchTasks removeAllObjects];self.searchPending=0;
}
- (void)searchBar:(UISearchBar*)searchBar textDidChange:(NSString*)text {
    if(searchBar==self.exploreSearch&&[self.page isEqual:@"Explore"]){[[RewindStore shared].discoveryMetadata cancelEntitySearch];[self.exploreFeed cancelPages];self.exploreRemoteBusy=NO;self.exploreGeneration++;self.exploreQuery=text;[self.searchTimer invalidate];self.exploreBusy=YES;[self updateExploreGrid];self.searchTimer=[NSTimer scheduledTimerWithTimeInterval:.28 target:self selector:@selector(runExploreSearch) userInfo:nil repeats:NO];return;}
    self.searchGeneration++;[self.searchTimer invalidate];[self cancelSearchRequests];
    self.searchInputAt=NSProcessInfo.processInfo.systemUptime;self.searchBegan=0;self.searchFirstResult=-1;self.searchFirstRendered=-1;self.searchProviderTimes=[NSMutableDictionary new];
    if(!text.length)self.searchResults=@[];self.feedGrid.contentOffset=CGPointZero;self.searchMessage=text.length?@"Searching…":nil;self.searchVisibleLimit=24;self.searchPending=text.length?2:0;[self updateSearchResults];
    self.searchTimer=[NSTimer scheduledTimerWithTimeInterval:.28 target:self selector:@selector(runSearch)userInfo:nil repeats:NO];
}
- (void)searchBarSearchButtonClicked:(UISearchBar*)searchBar {if(searchBar==self.exploreSearch&&[self.page isEqual:@"Explore"]){[self.searchTimer invalidate];[searchBar resignFirstResponder];[self fetchExplore];return;}[self.searchTimer invalidate];[searchBar resignFirstResponder];self.searchInputAt=NSProcessInfo.processInfo.systemUptime;self.searchFirstRendered=-1;[self runSearch];}
- (void)runSearch {
    if(![self.page isEqual:@"Search"])return;[self cancelSearchRequests];
    NSString *query=[self.search.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];NSInteger generation=++self.searchGeneration;
    self.searchVisibleLimit=24;self.searchBegan=NSProcessInfo.processInfo.systemUptime;self.searchFirstResult=-1;self.searchProviderTimes=[NSMutableDictionary new];if(self.searchInputAt<=0){self.searchInputAt=self.searchBegan;self.searchFirstRendered=-1;}
    if(!query.length){self.searchResults=@[];self.searchMessage=nil;[self updateSearchResults];return;}
    RewindStore *store=[RewindStore shared];NSString *profile=store.state[@"activeProfile"];
    self.searchResultsQuery=query;self.searchResults=[store localSearch:query];if(self.searchResults.count)self.searchFirstResult=NSProcessInfo.processInfo.systemUptime-self.searchBegan;
    self.searchMessage=self.searchResults.count?@"More matches loading…":@"Searching…";self.searchPending=2;self.searchTasks=[NSMutableArray new];[self updateSearchResults];
    __weak RewindController *weak=self;__block NSString *lastError=nil;
    for(NSString *type in @[@"movie",@"series"]){
        NSURLSessionDataTask *task=[store searchCatalog:type query:query done:^(id items,NSString *error){
            if(!weak||weak.searchGeneration!=generation||![weak.page isEqual:@"Search"]||![profile isEqual:store.state[@"activeProfile"]])return;
            if(weak.searchPending)weak.searchPending--;if(error)lastError=error;
            weak.searchProviderTimes[type]=@(NSProcessInfo.processInfo.systemUptime-weak.searchBegan);
            weak.searchResults=[RWTVPolicy search:[weak.searchResults arrayByAddingObjectsFromArray:items?:@[]] query:query];
            if(store.restricted)[store.ratings resolve:items?:@[]];
            NSUInteger count=[store allowedItems:weak.searchResults].count;
            if(count&&weak.searchFirstResult<0)weak.searchFirstResult=NSProcessInfo.processInfo.systemUptime-weak.searchBegan;
            weak.searchMessage=count?[NSString stringWithFormat:@"%lu %@%@",(unsigned long)count,count==1?@"match":@"matches",weak.searchPending?@" · updating…":lastError?@" · some online results unavailable":@""]:(weak.searchPending?@"Searching…":lastError?:@"No matches. Try a different title.");
            [weak updateSearchResults];
        }];if(task)[self.searchTasks addObject:task];
    }
}
- (void)updateSearchResults {
    if(![self.page isEqual:@"Search"]||!self.searchResultsView)return;double began=NSProcessInfo.processInfo.systemUptime;
    NSString *query=[self.search.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];RewindStore *store=[RewindStore shared];
    NSArray *items=[store allowedItems:query.length?self.searchResults:[self recommendations]];
    NSString *message=self.searchMessage?:@"EXPLORE";
    if(query.length&&store.restricted&&!items.count&&!self.searchPending)message=store.ratings.busy?@"Checking age ratings…":@"No rated matches for this profile";
    self.searchMessageLabel.text=message;
    NSArray *shown=items;
    self.searchExploreBar.hidden=query.length>0;
    CGFloat top=query.length?257:334,height=MAX(100,self.content.bounds.size.height-top);
    self.feedGrid.frame=CGRectMake(0,top,[self width],height);
    [self.feedGrid updateItems:items loading:self.searchPending>0 more:NO error:nil cursor:items.count automatic:NO];
    self.content.contentSize=self.content.bounds.size;
    [self.feedGrid loadVisibleArtwork];
    if(!self.reviewMode&&query.length&&self.searchInputAt>0&&[query isEqual:self.searchResultsQuery]){
        double now=NSProcessInfo.processInfo.systemUptime;
        if(items.count&&self.searchFirstRendered<0){self.searchFirstRendered=now-self.searchInputAt;[[RWUIProbe shared]transition:@"search_results_from_input_display_callback" started:self.searchInputAt];}
        if(items.count&&self.searchFirstResult<0&&self.searchBegan>0)self.searchFirstResult=now-self.searchBegan;
        NSMutableArray *top=[NSMutableArray new];for(NSDictionary *m in shown){[top addObject:@{@"id":RWID(m),@"name":RWString(m[@"name"]),@"type":RWString(m[@"type"])}];if(top.count==3)break;}
        [store report:@{@"search_metrics":@{@"query":query,@"first_result_seconds":@(self.searchFirstResult),@"first_render_from_input_seconds":@(self.searchFirstRendered),@"debounce_seconds":@(self.searchBegan>0?self.searchBegan-self.searchInputAt:0),@"elapsed_seconds":@(self.searchBegan>0?now-self.searchBegan:0),@"provider_seconds":[self.searchProviderTimes copy]?:@{},@"pending":@(self.searchPending),@"visible_results":@(items.count),@"keyboard_active":@(self.search.isFirstResponder),@"profile_age":store.profile[@"maxAge"],@"top_results":top}}];
    }
    if(!self.reviewMode)[store report:@{@"search_render_seconds":@(NSProcessInfo.processInfo.systemUptime-began),@"search_rendered_posters":@(self.feedGrid.visibleCells.count),@"search_total_results":@(shown.count)}];
}
