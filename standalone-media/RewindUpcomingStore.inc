// A global metadata cache, not user state. Only the visible Upcoming screen
// starts work; one request is in flight on the existing metadata lane.
// Visible discovery has foreground priority, never extra network slots.
- (void)setUpcomingVisible:(BOOL)visible {
    _upcomingVisible=visible;if(visible)[self refreshUpcoming];
}
- (void)retryUpcoming {if(self.upcomingBusy)return;_upcomingRetryAfter=0;if(!_upcomingRequests)_upcomingChecked=0;[self refreshUpcoming];}
- (NSUInteger)upcomingDays {return _upcomingDays;}
- (BOOL)upcomingHasMore {return _upcomingDays<28;}
- (void)loadMoreUpcoming {
    if(!_upcomingVisible||self.upcomingBusy||![self upcomingHasMore])return;
    if(_upcomingRequests){
        if(!self.upcomingError.length||_upcomingRequestIndex)return;
        // Pending film/series announcements must not block later schedule days.
        // A missing schedule query still needs recovery before its day advances.
        for(NSString *url in _upcomingFailures)if([[NSURL URLWithString:url].host isEqual:@"api.tvmaze.com"])return;
    }
    if(![_upcomingDay isEqual:[RWUpcomingPolicy day:NSDate.date]]||!_upcomingDays){[self refreshUpcoming];return;}
    _upcomingTargetDays=MIN(28,_upcomingDays+2);NSArray *requests=[RWUpcomingPolicy scheduleRequests:NSDate.date days:_upcomingTargetDays];_upcomingRequests=[requests subarrayWithRange:NSMakeRange(_upcomingDays*3,requests.count-_upcomingDays*3)];_upcomingRequestIndex=0;if(!_upcomingFailures)_upcomingFailures=[NSMutableDictionary new];_upcomingRetryAfter=0;[self refreshUpcoming];
}
- (void)refreshUpcoming {
    double now=NSDate.date.timeIntervalSince1970;
    if(!_upcomingVisible||!self.catalogReady||self.upcomingBusy||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive||now<_upcomingRetryAfter||(!_upcomingRequests&&_upcomingDays&&[_upcomingDay isEqual:[RWUpcomingPolicy day:NSDate.date]]&&now>=_upcomingChecked&&now-_upcomingChecked<86400))return;
    if(!_upcomingRequests){_upcomingDays=0;_upcomingChecked=0;_upcomingDay=[RWUpcomingPolicy day:NSDate.date];_upcomingTargetDays=2;_upcomingRequestIndex=0;_upcomingFailures=[NSMutableDictionary new];_upcomingTrace=[NSMutableArray new];
        NSArray *schedule=[RWUpcomingPolicy scheduleRequests:NSDate.date days:2],*releases=[RWUpcomingPolicy requests:NSDate.date];NSMutableArray *requests=[NSMutableArray new];
        // Publish today's episodes first, then films, tomorrow's episodes and
        // series announcements. Slow identity lookups cannot hide all schedules.
        [requests addObjectsFromArray:[schedule subarrayWithRange:NSMakeRange(0,3)]];[requests addObjectsFromArray:[releases subarrayWithRange:NSMakeRange(0,2)]];
        [requests addObjectsFromArray:[schedule subarrayWithRange:NSMakeRange(3,3)]];[requests addObjectsFromArray:[releases subarrayWithRange:NSMakeRange(2,2)]];_upcomingRequests=requests;
    }
    if(_upcomingRequestIndex>=_upcomingRequests.count){
        if(_upcomingFailures.count){BOOL scheduleMissing=NO;for(NSString *url in _upcomingFailures)if([[NSURL URLWithString:url].host isEqual:@"api.tvmaze.com"])scheduleMissing=YES;
            if(!scheduleMissing)_upcomingDays=_upcomingTargetDays;
            _upcomingRequests=[_upcomingFailures.allKeys sortedArrayUsingSelector:@selector(compare:)];_upcomingRequestIndex=0;_upcomingChecked=0;_upcomingRetryAfter=now+30;self.upcomingError=@"Some release information couldn’t refresh.";[self persistUpcoming];[self reportUpcoming:self.upcomingError];return;}
        _upcomingRequestIndex=0;_upcomingRequests=nil;_upcomingChecked=now;_upcomingDays=_upcomingTargetDays;[self persistUpcoming];[self reportUpcoming:nil];return;
    }
    self.upcomingBusy=YES;self.upcomingError=nil;[[NSNotificationCenter defaultCenter]postNotificationName:@"RWUpcomingUpdated" object:self];
    NSString *request=_upcomingRequests[_upcomingRequestIndex];[_upcomingFailures removeObjectForKey:request];_upcomingRequestBegan=NSProcessInfo.processInfo.systemUptime;
    [self JSON:request foreground:YES done:^(id data,NSString *error){
        if(error||data[@"error"]){[self finishUpcoming:nil error:error?:@"Release information is temporarily unavailable."];return;}
        if([[NSURL URLWithString:request].host isEqual:@"api.tvmaze.com"]){
            if(![data[@"episodes"]isKindOfClass:NSArray.class]){[self finishUpcoming:nil error:@"The episode schedule could not be read."];return;}
            dispatch_async(self->_recommendationQueue,^{@autoreleasepool{NSArray *items=[RWUpcomingPolicy scheduledTitles:data[@"episodes"] now:NSDate.date.timeIntervalSince1970 query:request];dispatch_async(dispatch_get_main_queue(),^{NSMutableArray *retained=[NSMutableArray new];for(NSDictionary *m in self.upcomingCatalog)if(![m[@"scheduledQuery"]isEqual:request])[retained addObject:m];self.upcomingCatalog=retained;[self finishUpcoming:items error:nil];});}});return;
        }
        NSMutableOrderedSet *ids=[NSMutableOrderedSet new];id rows=data[@"query"][@"search"];
        if(![rows isKindOfClass:NSArray.class]){[self finishUpcoming:nil error:@"Release information could not be read."];return;}
        for(id row in rows){if(![row isKindOfClass:NSDictionary.class])continue;NSString *key=RWString(row[@"title"]);if([key rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location==0)[ids addObject:key];if(ids.count==24)break;}
        if(!ids.count){[self finishUpcoming:@[] error:nil];return;}
        if(!self->_upcomingVisible){self.upcomingBusy=NO;return;}
        NSString *url=[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=claims%%7Clabels&languages=en%%7Cmul&ids=%@",Esc([ids.array componentsJoinedByString:@"|"])];
        [self JSON:url foreground:YES done:^(id response,NSString *error){
            if(error||![response[@"entities"]isKindOfClass:NSDictionary.class]){[self finishUpcoming:nil error:error?:@"Release information could not be verified."];return;}
            NSDictionary *entities=response[@"entities"];dispatch_async(self->_recommendationQueue,^{@autoreleasepool{NSArray *items=[RWUpcomingPolicy titles:entities now:NSDate.date.timeIntervalSince1970];dispatch_async(dispatch_get_main_queue(),^{NSMutableArray *retained=[NSMutableArray new];for(NSDictionary *m in self.upcomingCatalog)if(!entities[m[@"upcomingEntity"]?:@""])[retained addObject:m];self.upcomingCatalog=retained;[self finishUpcoming:items error:nil];});}});
        }];
    }];
}
- (void)persistUpcoming {
    NSDictionary *snapshot=@{@"schema":@(RWUpcomingCacheSchema),@"items":self.upcomingCatalog?:@[],@"checked":@(_upcomingChecked),@"days":@(_upcomingDays),@"day":_upcomingDay?:@""};dispatch_async(_recommendationQueue,^{NSData *data=[NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil];if(data.length<=RWUpcomingCacheBytes)[[RWAtomicWriter shared]write:data path:[RWDocuments()stringByAppendingPathComponent:@"rewind-upcoming.json"]];});
}
- (void)reportUpcoming:(NSString *)error {
    [self report:@{@"upcoming_catalog":@{@"items":@(self.upcomingCatalog.count),@"completed_queries":@(_upcomingRequestIndex),@"days":@(_upcomingDays),@"target_days":@(_upcomingTargetDays),@"error":error?:@"",@"checked":@(_upcomingChecked),@"day":_upcomingDay?:@"",@"failed_queries":@(_upcomingFailures.count),@"request_trace":[_upcomingTrace copy]?:@[],@"cache_schema":@(RWUpcomingCacheSchema),@"cache_byte_limit":@(RWUpcomingCacheBytes)}}];
    [[NSNotificationCenter defaultCenter]postNotificationName:@"RWUpcomingUpdated" object:self];if(!error)[self refreshUpcoming];
}
- (void)finishUpcoming:(NSArray *)items error:(NSString *)error {
    NSString *request=_upcomingRequestIndex<_upcomingRequests.count?_upcomingRequests[_upcomingRequestIndex]:@"";
    if(!_upcomingTrace)_upcomingTrace=[NSMutableArray new];if(_upcomingTrace.count==16)[_upcomingTrace removeObjectAtIndex:0];
    [_upcomingTrace addObject:@{@"url":request,@"seconds":@(MAX(0,NSProcessInfo.processInfo.systemUptime-_upcomingRequestBegan)),@"items":@(items.count),@"error":error?:@"",@"foreground":@YES}];
    self.upcomingError=nil;
    if(error){if(!_upcomingFailures)_upcomingFailures=[NSMutableDictionary new];_upcomingFailures[request]=error;self.upcomingBusy=NO;_upcomingRequestIndex++;[self reportUpcoming:nil];return;}
    // Selection, serialization sizing and sorting stay off the UI thread. The
    // serial request remains busy until its immutable result is committed.
    NSArray *existing=self.upcomingCatalog;dispatch_async(_recommendationQueue,^{@autoreleasepool{
        NSArray *merged=[RWUpcomingPolicy merge:existing incoming:items now:NSDate.date.timeIntervalSince1970];
        dispatch_async(dispatch_get_main_queue(),^{self.upcomingCatalog=merged;self.upcomingBusy=NO;self->_upcomingRequestIndex++;[self persistUpcoming];if(self.restricted)[self.ratings resolve:merged];[self reportUpcoming:nil];});
    }});
}
