// Real NSURLSession traffic to one temporary USB-loopback provider fixture.
// Uses normal search input/cancellation and only an owned temporary profile.
- (NSDictionary *)exerciseSearchNetworkSnapshot {
    NSMutableArray *ids=[NSMutableArray new],*states=[NSMutableArray new];for(NSDictionary *m in self.searchResults?:@[])[ids addObject:RWID(m)];for(NSURLSessionTask *task in self.exerciseSearchOldTasks)[states addObject:@(task.state)];
    return @{@"page":self.page?:@"",@"query":self.search.text?:@"",@"result_query":self.searchResultsQuery?:@"",@"pending":@(self.searchPending),@"ids":ids,@"message":self.searchMessage?:@"",@"old_task_states":states,@"network":[RewindStore shared].catalogSearch.diagnostics,@"profile":[RewindStore shared].state[@"activeProfile"]};
}
- (BOOL)exerciseSearchNetworkStep:(NSString *)kind {
    RewindStore *s=RewindStore.shared;NSInteger build=[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue];
    if(!self.exerciseResumeOwned||![RWDeviceExercise ownsResumeProfile:s.profile build:build])return NO;
    if([kind isEqual:@"searchnet-prepare"]){
        if(self.exerciseOriginalCatalogSearch)return NO;if(!s.catalogReady){if(NSProcessInfo.processInfo.systemUptime-self.exerciseStarted>20)return NO;self.exerciseIndex--;return YES;}NSDictionary *sintel=nil;for(NSDictionary *m in s.openFilms)if([RWString(m[@"name"])isEqual:@"Sintel"]){sintel=m;break;}if(!sintel)return NO;
        s.profile[@"saved"]=[NSMutableArray arrayWithObject:sintel];self.exerciseSearchLocalID=RWID(sintel);[s save];self.exerciseOriginalCatalogSearch=s.catalogSearch;s.catalogSearch=[RWExerciseCatalogSearch new];[self go:@"Search"];return YES;
    }
    NSDictionary *queries=@{@"slow":@"Cosmos Laundromat",@"fast":@"Sintel",@"cached":@"Sintel",@"offline":@"Sintel",@"header":@"Header size check",@"chunk":@"Chunk size check",@"gzip":@"Compressed size check",@"exit":@"Closing check"};
    if([kind hasPrefix:@"searchnet-query-"]){NSString *mode=[kind substringFromIndex:16],*query=queries[mode];if(!query||![self.page isEqual:@"Search"])return NO;
        if([mode isEqual:@"fast"]||[mode isEqual:@"exit"])self.exerciseSearchOldTasks=[self.searchTasks copy];if([mode isEqual:@"offline"])[s.catalogSearch clearCache];
        self.search.text=query;[self searchBar:self.search textDidChange:query];self.exerciseSearchStarted=NSProcessInfo.processInfo.systemUptime;return YES;
    }
    if([kind isEqual:@"searchnet-await-slow"]||[kind isEqual:@"searchnet-await-exit"]){
        BOOL seen=NO;for(NSDictionary *job in s.catalogSearch.diagnostics[@"active"])seen|=[job[@"response_received"]boolValue]&&[job[@"query"]isEqual:self.search.text];if(!seen){if(NSProcessInfo.processInfo.systemUptime-self.exerciseSearchStarted>12)return NO;self.exerciseIndex--;}else self.exerciseSearchOldTasks=[self.searchTasks copy];return YES;
    }
    if([kind isEqual:@"searchnet-await"]){if(self.searchPending||!self.searchBegan){if(NSProcessInfo.processInfo.systemUptime-self.exerciseSearchStarted>15)return NO;self.exerciseIndex--;}return YES;}
    if([kind isEqual:@"searchnet-home"]){[self go:@"Home"];return YES;}
    if(![kind hasPrefix:@"searchnet-audit-"])return NO;NSString *label=[kind substringFromIndex:16];NSDictionary *snap=[self exerciseSearchNetworkSnapshot],*network=snap[@"network"];BOOL ok=![snap[@"pending"]integerValue]&&![network[@"active"]count];
    if([@[@"fast",@"late",@"cached",@"offline"]containsObject:label]){
        ok=ok&&[self.page isEqual:@"Search"]&&[self.searchResultsQuery isEqual:@"Sintel"]&&[snap[@"ids"]containsObject:self.exerciseSearchLocalID]&&![snap[@"ids"]containsObject:@"rw:cosmos"]&&![snap[@"ids"]containsObject:@"tt1727587"];
        if([label isEqual:@"fast"]){self.exerciseSearchIDs=snap[@"ids"];self.exerciseSearchRequests=[network[@"started"]unsignedIntegerValue];ok=ok&&[network[@"cancelled"]unsignedIntegerValue]==2;}
        if([@[@"late",@"cached"]containsObject:label])ok=ok&&[snap[@"ids"]isEqual:self.exerciseSearchIDs];
        if([label isEqual:@"cached"])ok=ok&&[network[@"started"]unsignedIntegerValue]==self.exerciseSearchRequests&&[network[@"cache_hits"]unsignedIntegerValue]==2;
        if([label isEqual:@"offline"])ok=ok&&[snap[@"message"]rangeOfString:@"unavailable"].location!=NSNotFound;
        if(![label isEqual:@"offline"])for(NSNumber *state in snap[@"old_task_states"])ok=ok&&state.integerValue==NSURLSessionTaskStateCompleted;
    }else if([@[@"header",@"chunk",@"gzip"]containsObject:label]){
        NSUInteger found=0;for(NSDictionary *event in network[@"events"])if([event[@"query"]isEqual:queries[label]]){found++;ok=ok&&[event[@"outcome"]isEqual:@"unavailable"]&&[event[@"http"]integerValue]==200&&[event[@"peak_buffer_bytes"]unsignedIntegerValue]<=5*1024*1024;if([label isEqual:@"header"])ok=ok&&[event[@"peak_buffer_bytes"]unsignedIntegerValue]==0;}
        ok=ok&&found==2&&!self.searchResults.count&&[snap[@"message"]isEqual:@"Online search is unavailable. Try again."];
    }else if([label isEqual:@"exit"]){ok=ok&&[self.page isEqual:@"Home"]&&[network[@"cancelled"]unsignedIntegerValue]==4;for(NSNumber *state in snap[@"old_task_states"])ok=ok&&state.integerValue==NSURLSessionTaskStateCompleted;}
    else ok=NO;
    if([@[@"fast",@"offline",@"header"]containsObject:label])ok=[self exerciseCastCapture:[@"device-exercise-" stringByAppendingString:kind]]&&ok;return ok;
}
- (void)finishSearchNetworkExercise {
    if(!self.exerciseOriginalCatalogSearch)return;[self.searchTimer invalidate];[self cancelSearchRequests];RewindStore *s=RewindStore.shared;[s.catalogSearch invalidate];s.catalogSearch=self.exerciseOriginalCatalogSearch;self.exerciseOriginalCatalogSearch=nil;self.exerciseSearchOldTasks=nil;self.exerciseSearchIDs=nil;self.exerciseSearchLocalID=nil;
}
