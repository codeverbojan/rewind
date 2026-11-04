- (void)resetExplore {
    [[RewindStore shared].discoveryMetadata cancelEntitySearch];self.exploreGeneration++;[self.exploreFeed park];self.exploreFeed=nil;self.exploreBusy=NO;self.exploreError=nil;self.exploreQuery=@"";self.exploreType=@"Films";self.exploreScope=nil;self.exploreCursor=@{};self.exploreRemoteStarted=NO;self.exploreRemoteMore=NO;self.exploreRemoteBusy=NO;self.exploreLocalRecords=@[];self.exploreEmptyPages=0;
}
- (NSString *)currentExploreScope {return [NSString stringWithFormat:@"%@:%@:%@",[RewindStore shared].state[@"activeProfile"],self.exploreKind,self.exploreMood?:@""];}
- (BOOL)canSearchEntities {return !self.reviewMode&&![RewindStore shared].restricted&&!self.exploreMood.length&&[@[@"People",@"Studios"]containsObject:self.exploreKind]&&[RWEntitySearchPolicy query:self.exploreQuery].length>=2;}
- (void)openExplore:(NSString *)kind {[self pushDestination];[self resetExplore];self.exploreKind=kind;self.exploreMood=nil;[self go:@"Explore"];[self fetchExplore];}
- (void)fetchExplore {
    if(![self.page isEqual:@"Explore"])return;[[RewindStore shared].discoveryMetadata cancelEntitySearch];[self.exploreFeed cancelPages];NSUInteger generation=++self.exploreGeneration;NSString *profile=[RewindStore shared].state[@"activeProfile"],*scope=[self currentExploreScope];self.exploreBusy=YES;self.exploreError=nil;self.exploreCursor=@{};self.exploreRemoteStarted=NO;self.exploreRemoteMore=NO;self.exploreRemoteBusy=NO;self.exploreEmptyPages=0;self.exploreLocalRecords=@[];[self updateExploreGrid];
    NSString *folder=[NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES)[0]stringByAppendingPathComponent:@"RewindFeeds"],*context=[scope stringByAppendingFormat:@":%@",self.exploreQuery?:@""];BOOL resume=self.exploreFeed&&!self.exploreFeed.pagesComplete&&[self.exploreFeed.context isEqual:context];RWFeedStore *feed=self.exploreFeed?:[[RWFeedStore alloc]initWithFolder:folder context:context];__weak RewindController *weak=self;
    [[RewindStore shared]exploreRecords:self.exploreKind mood:self.exploreMood query:self.exploreQuery done:^(NSArray *records){
        if(!weak||generation!=weak.exploreGeneration||![weak.page isEqual:@"Explore"]||![profile isEqual:[RewindStore shared].state[@"activeProfile"]]){if(feed!=weak.exploreFeed)[feed close:nil];return;}
        weak.exploreLocalRecords=records.count<=64?records:@[];NSString *type=weak.exploreMood.length?([weak.exploreType isEqual:@"Shows"]?@"series":@"movie"):nil;__block BOOL published=resume;
        void(^progress)(NSUInteger,NSString *,BOOL)=^(NSUInteger added,NSString *error,BOOL finished){
            if(generation!=weak.exploreGeneration||![scope isEqual:[weak currentExploreScope]]){if(feed!=weak.exploreFeed)[feed close:nil];return;}
            weak.exploreBusy=!finished;weak.exploreError=error;if(!error||feed.count){weak.exploreFeed=feed;if(!published&&!error){weak.feedGrid.contentOffset=CGPointZero;published=YES;}}else if(feed!=weak.exploreFeed)[feed close:nil];[weak updateExploreGrid];
            if(finished&&!error&&[weak canSearchEntities]){weak.exploreRemoteMore=YES;[weak loadExploreRemote];}else if(finished)weak.exploreLocalRecords=@[];
        };if(resume)[feed appendPages:records progress:progress];else [feed replacePages:records context:context type:type progress:progress];
    }];
}
- (void)loadExploreRemote {
    if(![self.page isEqual:@"Explore"]||self.exploreBusy||self.exploreRemoteBusy||![self canSearchEntities]||(!self.exploreRemoteMore&&!self.exploreError.length))return;
    self.exploreRemoteBusy=YES;self.exploreRemoteStarted=YES;self.exploreError=nil;NSUInteger generation=self.exploreGeneration;NSString *scope=[self currentExploreScope],*query=[self.exploreQuery copy];RWFeedStore *feed=self.exploreFeed;NSDictionary *cursor=self.exploreCursor;BOOL first=!cursor.count;__weak RewindController *weak=self;[self syncDiscoveryActivity];[self updateExploreGrid];
    [[RewindStore shared].discoveryMetadata searchEntities:query kind:self.exploreKind continuation:cursor done:^(NSArray *remote,NSDictionary *next,NSString *error){
        if(generation!=weak.exploreGeneration||![weak.page isEqual:@"Explore"]||![scope isEqual:[weak currentExploreScope]]||![query isEqual:weak.exploreQuery]||[RewindStore shared].restricted)return;
        if(error&&!remote.count){weak.exploreRemoteBusy=NO;weak.exploreError=error;[weak updateExploreGrid];return;}
        BOOL reorder=first&&feed.count==weak.exploreLocalRecords.count&&feed.count<=64&&weak.feedGrid.contentOffset.y<=20&&!weak.feedGrid.dragging&&!weak.feedGrid.decelerating;
        void(^merge)(NSArray *)=^(NSArray *local){[[RewindStore shared]mergeExploreRecords:local remote:remote query:query done:^(NSArray *records){
            if(generation!=weak.exploreGeneration||feed!=weak.exploreFeed||![weak.page isEqual:@"Explore"])return;
            void(^finish)(NSUInteger,NSString *)=^(NSUInteger added,NSString *writeError){if(generation!=weak.exploreGeneration||feed!=weak.exploreFeed)return;weak.exploreRemoteBusy=NO;weak.exploreError=writeError?:error;if(!writeError)weak.exploreLocalRecords=@[];if(!writeError){weak.exploreCursor=next;weak.exploreRemoteMore=next.count>0;weak.exploreEmptyPages=remote.count?0:weak.exploreEmptyPages+1;}[weak updateExploreGrid];[[RewindStore shared]report:@{@"entity_search":@{@"kind":weak.exploreKind,@"offset":cursor[@"offset"]?:@0,@"verified":@(remote.count),@"displayed":@(feed.count),@"more":@(weak.exploreRemoteMore),@"error":writeError?:@""}}];};
            if(reorder&&!weak.feedGrid.dragging&&!weak.feedGrid.decelerating&&weak.feedGrid.contentOffset.y<=20){[feed replacePages:records context:feed.context type:nil progress:^(NSUInteger added,NSString *writeError,BOOL finished){if(finished)finish(added,writeError);}];}else [feed append:records done:finish];
        }];};
        if(reorder)merge(weak.exploreLocalRecords);else [feed recordsForIDs:[remote valueForKey:@"id"] done:^(NSArray *local,NSString *readError){if(generation!=weak.exploreGeneration||feed!=weak.exploreFeed||![weak.page isEqual:@"Explore"])return;if(readError){weak.exploreRemoteBusy=NO;weak.exploreError=readError;[weak updateExploreGrid];return;}merge(local);}];
    }];
}
- (void)runExploreSearch {[self fetchExplore];}
- (void)updateExploreGrid {
    if(![self.page isEqual:@"Explore"]||!self.feedGrid)return;BOOL busy=self.exploreBusy||self.exploreRemoteBusy,remote=self.exploreRemoteStarted;
    self.exploreMessage.text=busy?@"Finding matches…":self.exploreError.length?(self.exploreFeed.count?@"Your existing matches remain available":@"Online search is unavailable. Try again."):self.exploreFeed.count?[NSString stringWithFormat:@"%lu %@%@",(unsigned long)self.exploreFeed.count,self.exploreMood.length?([self.exploreType isEqual:@"Shows"]?@"shows":@"films"):(self.exploreFeed.count==1?([self.exploreKind isEqual:@"Studios"]?@"studio":@"person"):[self.exploreKind lowercaseString]),remote?@"":[RewindStore shared].restricted?@" · age-checked credits":@" · from your discoveries"]:remote?@"No verified matches. Try another name.":@"No matches in your current discoveries";
    BOOL more=remote&&self.exploreRemoteMore,automatic=self.exploreEmptyPages<3;
    if(self.exploreFeed)[self.feedGrid updateFeed:self.exploreFeed loading:busy more:more error:(self.exploreError.length?@"Couldn’t update results. Try again.":nil) cursor:[self.exploreCursor[@"offset"]unsignedIntegerValue] automatic:automatic];else [self.feedGrid updateItems:@[] loading:busy more:more error:(self.exploreError.length?@"Couldn’t update results. Try again.":nil) cursor:0 automatic:automatic];
}
