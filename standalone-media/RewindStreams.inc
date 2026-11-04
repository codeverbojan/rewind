- (NSString *)streamKey:(NSDictionary *)meta videoID:(NSString *)videoID {return [NSString stringWithFormat:@"%@:%ld:%@:%@:%@",self.state[@"activeProfile"],(long)self.quality,RWString(meta[@"type"]),videoID,[RWSourcePolicy capabilities][@"generation"]];}
- (NSArray *)cachedStreams:(NSDictionary *)meta videoID:(NSString *)videoID {if(![self allowed:meta])return @[];return [_sourceCache sourcesForKey:[self streamKey:meta videoID:videoID] now:NSProcessInfo.processInfo.systemUptime freshOnly:NO]?:@[];}
- (void)refreshStreams:(NSDictionary *)meta videoID:(NSString *)videoID done:(RWResult)done {[_sourceCache removeObjectForKey:[self streamKey:meta videoID:videoID]];[self streams:meta videoID:videoID done:done];}
- (void)streams:(NSDictionary *)meta videoID:(NSString *)videoID done:(RWResult)done {[self streams:meta videoID:videoID foreground:YES done:done];}
- (void)streams:(NSDictionary *)meta videoID:(NSString *)videoID foreground:(BOOL)foreground done:(RWResult)done {
    if(![self allowed:meta]){done(@[],@"This title is outside this profile’s age limit, or its rating is unavailable.");return;}
    // Only the small local/publisher set is captured on its owning thread.
    // Provider JSON arrives immutable from JSON: and is normalized off-main.
    NSMutableArray *all=[NSMutableArray new];
    if(foreground){
        for(id raw in @[[self profile][@"sources"][videoID]?:@{},meta[@"source"]?:@{},[self record:videoID][@"source"]?:@{}]){NSDictionary *s=[RWSourcePolicy normalize:raw provider:RWString(raw[@"provider"]).length?raw[@"provider"]:@"Saved source"];if(s)[all addObject:s];}
        for(NSDictionary *raw in self->_publisherSources[videoID]){NSDictionary *s=[RWSourcePolicy normalize:raw provider:@"Publisher"];if(s)[all addObject:s];}
    }
    NSString *type=RWString(meta[@"type"]),*measuredProfile=[self.state[@"activeProfile"]copy],*lookupID=NSUUID.UUID.UUIDString;NSInteger measuredQuality=self.quality;double lookupStarted=NSProcessInfo.processInfo.systemUptime;
    void(^measure)(NSDictionary *)=^(NSDictionary *details){
        if(!foreground)return;NSMutableDictionary *event=[details mutableCopy];
        [event addEntriesFromDictionary:@{@"lookup_id":lookupID,@"video_id":videoID,@"profile_id":measuredProfile,@"type":type,@"requested_quality":@(measuredQuality),@"foreground":@YES,@"duration_seconds":@(NSProcessInfo.processInfo.systemUptime-lookupStarted)}];
        [[NSNotificationCenter defaultCenter]postNotificationName:@"RWSourceLookupMeasured" object:self userInfo:[event copy]];
    };
    NSRegularExpression *identifier=[NSRegularExpression regularExpressionWithPattern:@"^tt[0-9]+(?::[0-9]+:[0-9]+)?$" options:0 error:nil];
    if(![@[@"movie",@"series"]containsObject:type]||![identifier firstMatchInString:videoID options:0 range:NSMakeRange(0,videoID.length)]){measure(@{@"origin":@"local",@"complete":@YES,@"count":@(all.count)});done(all,nil);return;}
    NSString *key=[self streamKey:meta videoID:videoID];NSArray *cache=foreground?[_sourceCache sourcesForKey:key now:NSProcessInfo.processInfo.systemUptime freshOnly:YES]:nil;
    if(cache){[all addObjectsFromArray:cache];measure(@{@"origin":@"fresh_cache",@"complete":@YES,@"count":@(all.count)});done([self withSourceExperience:all],nil);return;}
    NSArray *local=[RWSourceWork snapshot:all];if(!local){done(@[],@"Saved source information could not be read.");return;}
    if(!_sourceWork)_sourceWork=[RWSourceWork new];
    NSString *requestKey=foreground?key:[NSString stringWithFormat:@"background:%lu:%lu:%d:%@",(unsigned long)_homeGeneration,(unsigned long)_availabilityWatchGeneration,_homeAvailabilityVisible,key];
    [_streamRequests perform:requestKey start:^(RWLookupResult finish){
        NSString *profileID=[self.state[@"activeProfile"]copy];NSInteger lookupQuality=self.quality;NSDictionary *capabilities=[RWSourcePolicy capabilities];double began=NSProcessInfo.processInfo.systemUptime;
        NSUInteger homeGeneration=self->_homeGeneration,watchGeneration=self->_availabilityWatchGeneration;BOOL homeVisible=self->_homeAvailabilityVisible;
        BOOL(^valid)(void)=^BOOL{return [profileID isEqual:self.state[@"activeProfile"]]&&lookupQuality==self.quality&&[capabilities isEqual:[RWSourcePolicy capabilities]]&&[self allowed:meta]&&(foreground||(!self->_discoveryPaused&&homeGeneration==self->_homeGeneration&&watchGeneration==self->_availabilityWatchGeneration&&homeVisible==self->_homeAvailabilityVisible));};
        __block BOOL delivered=NO;__block NSUInteger completed=0,count=foreground&&[type isEqual:@"movie"]?2:1,revision=0,published=0;
        NSMutableArray *items=[NSMutableArray new];NSMutableDictionary *providerStatus=[NSMutableDictionary new];
        BOOL(^current)(void)=^BOOL{if(valid())return YES;if(!delivered){delivered=YES;finish(@[],@"Source request changed.");}return NO;};
        void(^accept)(NSArray *,NSString *,NSString *,NSDictionary *)=^(NSArray *batch,NSString *provider,NSString *error,NSDictionary *preparedAnalysis){
            if(!current())return;completed++;if(batch)[items addObjectsFromArray:batch];
            providerStatus[provider]=@{@"count":@(batch.count),@"error":error?:@"",@"seconds":@(NSProcessInfo.processInfo.systemUptime-began)};
            NSArray *combined=[local arrayByAddingObjectsFromArray:items],*remote=[items copy];NSDictionary *providers=[providerStatus copy];NSUInteger version=++revision,finished=completed,total=count;
            NSMutableArray *errors=[NSMutableArray new];for(NSDictionary *status in providers.allValues)if([status[@"error"]length])[errors addObject:status[@"error"]];NSString *lookupError=errors.count?[errors componentsJoinedByString:@"; "]:nil;
            void(^apply)(id,NSString *)=^(NSDictionary *analysis,NSString *workError){
                if(!current()||version<published)return;
                if(!analysis){if(!delivered){delivered=YES;finish(@[],workError?:@"Source processing failed.");}return;}published=version;
                double applyBegan=NSProcessInfo.processInfo.systemUptime;NSArray *eligible=analysis[@"eligible"];
                // Cache only remote inputs that this exact policy evaluation accepted.
                // A partial rejected list must not bypass the in-flight lookup,
                // and a completed negative list must not become a fresh hit.
                NSMutableArray *cacheable=[NSMutableArray new];
                for(NSNumber *inputIndex in analysis[@"eligible_input_indices"]){NSUInteger index=inputIndex.unsignedIntegerValue;if(index>=local.count&&index-local.count<remote.count)[cacheable addObject:remote[index-local.count]];}
                if(cacheable.count)[self->_sourceCache storeSources:cacheable forKey:key now:NSProcessInfo.processInfo.systemUptime];
                NSDictionary *observation=[RWAvailability observeAnalysis:analysis complete:finished==total error:lookupError quality:lookupQuality now:NSDate.date.timeIntervalSince1970];
                [self noteAvailability:meta videoID:videoID observation:observation complete:finished==total];
                [self report:@{@"source_provider":@"Torrentio + YTS",@"source_providers":providers,@"source_query":videoID,@"source_candidates":@(combined.count),@"source_rejections":analysis[@"rejections"],@"source_eligible":@(eligible.count),@"source_qualities":analysis[@"qualities"],@"source_error":eligible.count?@"":(error?:@""),@"source_work":self->_sourceWork.diagnostics}];
                [[RWUIProbe shared]work:@"source_processing" started:applyBegan];
                measure(@{@"origin":@"providers",@"providers":providers,@"complete":@(finished==total),@"count":@(combined.count),@"eligible":@(eligible.count)});
                if(delivered){[[NSNotificationCenter defaultCenter]postNotificationName:@"RWSourceResultsUpdated" object:self userInfo:@{@"videoID":videoID,@"type":type,@"profile":profileID,@"sources":[self withSourceExperience:combined]}];}
                else if((foreground&&eligible.count)||finished==total){delivered=YES;[self report:@{@"source_first_result_seconds":@(NSProcessInfo.processInfo.systemUptime-began),@"source_lookups_joined":@(self->_streamRequests.joinedCount),@"json_lookups_joined":@(self->_jsonRequests.joinedCount)}];finish([self withSourceExperience:combined],eligible.count?nil:lookupError);}
            };
            // Background primary has no local or earlier provider candidates;
            // reuse its one-pass analysis instead of evaluating the list again.
            if(preparedAnalysis&&!foreground&&finished==1&&!local.count)apply(preparedAnalysis,nil);
            else [self->_sourceWork submitForeground:foreground valid:valid task:^id{return [RWSourcePolicy analysis:combined quality:lookupQuality capabilities:capabilities];} done:apply];
        };
        void(^receiveYTS)(id,NSString *)=^(id result,NSString *error){
            if(!current())return;NSDictionary *response=[result isKindOfClass:NSDictionary.class]?result:@{};
            [self->_sourceWork submitForeground:foreground valid:valid task:^id{return [RWSourceWork snapshot:[RWSourcePolicy ytsSources:response imdbID:videoID]];} done:^(NSArray *batch,NSString *workError){if(!current())return;accept(batch?:@[],@"YTS",error?:workError,nil);}];
        };
        NSString *url=[NSString stringWithFormat:@"https://torrentio.strem.fun/stream/%@/%@.json",type,Esc(videoID)];
        [self JSON:url foreground:foreground done:^(id result,NSString *error){
            if(!current())return;NSArray *raw=[result[@"streams"]isKindOfClass:NSArray.class]?result[@"streams"]:@[];
            [self->_sourceWork submitForeground:foreground valid:valid task:^id{
                NSMutableArray *batch=[NSMutableArray new];for(NSUInteger i=0;i<MIN(raw.count,(NSUInteger)300);i++){NSDictionary *s=[RWSourcePolicy normalize:raw[i] provider:@"Torrentio"];if(s)[batch addObject:s];}
                NSArray *owned=[RWSourceWork snapshot:batch];if(!owned)return nil;return @{@"batch":owned,@"analysis":foreground?@{}:[RWSourcePolicy analysis:owned quality:lookupQuality capabilities:capabilities]};
            } done:^(NSDictionary *prepared,NSString *workError){
                if(!current())return;NSArray *batch=prepared[@"batch"]?:@[];NSDictionary *analysis=prepared[@"analysis"];
                if(!foreground&&[type isEqual:@"movie"]&&(!prepared||![analysis[@"eligible"]count])){
                    count=2;NSString *fallback=[NSString stringWithFormat:@"https://movies-api.accel.li/api/v2/list_movies.json?query_term=%@&limit=5",Esc(videoID)];[self JSON:fallback foreground:NO done:receiveYTS];
                }
                accept(batch,@"Torrentio",error?:workError,analysis.count?analysis:nil);
            }];
        }];
        if(foreground&&count==2){NSString *yts=[NSString stringWithFormat:@"https://movies-api.accel.li/api/v2/list_movies.json?query_term=%@&limit=5",Esc(videoID)];[self JSON:yts foreground:YES done:receiveYTS];}
        if(foreground)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,7*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            if(delivered||!current())return;measure(@{@"origin":@"delivery_deadline",@"providers":[providerStatus copy],@"complete":@NO});delivered=YES;NSArray *combined=[local arrayByAddingObjectsFromArray:items];finish([self withSourceExperience:combined],combined.count?nil:@"Source providers are taking too long. Please try again.");
        });
    } done:done];
}
