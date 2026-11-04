// Value snapshots cross queues; live store and UI access stays on main.
- (BOOL)discoveryJobMatches:(NSDictionary *)snapshot profile:(NSString *)profile {
    return [profile isEqual:self.state[@"activeProfile"]]&&[RWDiscoverySnapshot matches:snapshot profile:self.profile quality:self.quality];
}
- (void)cancelRelatedTitles {[_relatedWork cancel];_relatedWork=nil;}
- (void)runDiscoveryItems:(NSArray *)input relatedTo:(NSDictionary *)target done:(void(^)(NSArray *))done {
    double began=NSProcessInfo.processInfo.systemUptime,captureBegan=began;NSDictionary *snapshot=[self discoveryInputSnapshot];NSString *profile=[self.state[@"activeProfile"]copy];NSDictionary *current=[target copy];
    NSArray *given=[input copy];if(given.count>500)given=[given subarrayWithRange:NSMakeRange(0,500)];
    NSOperation *request=nil;if(current){[self cancelRelatedTitles];_relatedWork=[NSBlockOperation blockOperationWithBlock:^{}];request=_relatedWork;}
    double captureSeconds=NSProcessInfo.processInfo.systemUptime-captureBegan;
    dispatch_async(_recommendationQueue,^{@autoreleasepool{
        if(request.cancelled){dispatch_async(dispatch_get_main_queue(),^{done(@[]);});return;}
        double poolBegan=NSProcessInfo.processInfo.systemUptime;NSMutableArray *items=[NSMutableArray new];
        for(NSDictionary *m in current?[RWDiscoverySnapshot pool:snapshot]:given)if(!current||[m[@"type"]isEqual:current[@"type"]])[items addObject:m];
        NSArray *ratingInput=current?[items arrayByAddingObject:current]:items;
        NSArray *ids=[RWDiscoverySnapshot ratingIDs:ratingInput snapshot:snapshot includeSignals:current!=nil now:NSDate.date.timeIntervalSince1970];
        double poolSeconds=NSProcessInfo.processInfo.systemUptime-poolBegan;
        dispatch_async(dispatch_get_main_queue(),^{
            if(request.cancelled||![self discoveryJobMatches:snapshot profile:profile]){done(@[]);return;}
            [self.imdbIndex ratingsForIDs:ids done:^(NSDictionary *ratings){
                if(request.cancelled||![self discoveryJobMatches:snapshot profile:profile]){done(@[]);return;}
                [self->_discoveryRatings addEntriesFromDictionary:ratings];if(self->_discoveryRatings.count>700)self->_discoveryRatings=[ratings mutableCopy];
                dispatch_async(self->_recommendationQueue,^{@autoreleasepool{
                    if(request.cancelled){dispatch_async(dispatch_get_main_queue(),^{done(@[]);});return;}
                    double now=NSDate.date.timeIntervalSince1970;NSDictionary *prepared=current?[RWDiscoverySnapshot prepare:items snapshot:snapshot ratings:ratings now:now]:[RWDiscoverySnapshot prepareItems:items snapshot:snapshot ratings:ratings now:now];
                    NSArray *result=prepared[@"items"];double rankSeconds=0;
                    if(current&&!request.cancelled){NSArray *anchors=[RWDiscoverySnapshot prepareItems:@[current] snapshot:snapshot ratings:ratings now:now][@"items"];NSDictionary *meta=anchors.firstObject;
                        double rankBegan=NSProcessInfo.processInfo.systemUptime;BOOL world=[[RWDiscoveryMetadataPolicy languageGroup:meta[@"discovery"]]isEqual:@"world"];
                        result=meta?[RWRecommendationPolicy related:result current:meta profile:prepared[@"profile"] world:world now:now limit:12]:@[];rankSeconds=NSProcessInfo.processInfo.systemUptime-rankBegan;
                    }
                    double elapsed=NSProcessInfo.processInfo.systemUptime-began;
                    dispatch_async(dispatch_get_main_queue(),^{
                        if(request.cancelled||![self discoveryJobMatches:snapshot profile:profile]){done(@[]);return;}
                        double applyBegan=NSProcessInfo.processInfo.systemUptime;NSArray *visible=self.restricted?[self allowedItems:result]:result;
                        [self report:@{@"discovery_job":@{@"kind":current?@"related":@"enrich",@"anchor_id":current[@"id"]?:@"",@"result_count":@(visible.count),@"capture_main_seconds":@(captureSeconds),@"pool_worker_seconds":@(poolSeconds),@"prepare_worker_seconds":prepared[@"seconds"],@"rank_worker_seconds":@(rankSeconds),@"worker_off_main":prepared[@"off_main"],@"apply_main_seconds":@(NSProcessInfo.processInfo.systemUptime-applyBegan),@"job_seconds":@(elapsed),@"prepared":@([prepared[@"items"]count]),@"ratings_ids":@(ids.count),@"signals":@([prepared[@"profile"][@"liked"]count]+[prepared[@"profile"][@"saved"]count]+[prepared[@"profile"][@"history"]count])}}];done(visible);
                    });
                }});
            }];
        });
    }});
}
- (void)enrichDiscoveryItems:(NSArray *)items done:(void(^)(NSArray *))done {[self runDiscoveryItems:items?:@[] relatedTo:nil done:done];}
- (void)relatedTitles:(NSDictionary *)meta done:(void(^)(NSArray *))done {[self runDiscoveryItems:nil relatedTo:meta done:done];}
