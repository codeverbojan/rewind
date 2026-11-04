// Automatic followed-title checks share Home's four slots. Elsewhere they
// remain a two-title background pass, invalidated when Home/playback takes over.
- (BOOL)setHomeAvailabilityVisible:(BOOL)visible {return [self setHomeAvailabilityVisible:visible mediaType:nil];}
- (BOOL)setHomeAvailabilityVisible:(BOOL)visible mediaType:(NSString *)mediaType {
    NSString *type=visible&&[@[@"movie",@"series"]containsObject:mediaType?:@""]?mediaType:nil;
    if(_homeAvailabilityVisible==visible&&(_homeAvailabilityType==type||[_homeAvailabilityType isEqual:type]))return NO;
    [self clearHomeRefreshBatch];_homeAvailabilityVisible=visible;_homeAvailabilityType=[type copy];
    _availabilityWatchGeneration++;_checkingAvailability=NO;
    // An explicit destination change owns a new bounded visit. Late work from
    // the previous destination must not publish or start a fallback request.
    _homeGeneration++;_homeAvailabilityBusy=NO;_homePublicationRequested=NO;_homeRefreshRequested=NO;
    return YES;
}
- (NSArray *)availabilityWatchTargets {
    NSMutableArray *targets=[NSMutableArray new];NSDictionary *watch=self.profile[@"availabilityWatch"]?:@{};double now=NSDate.date.timeIntervalSince1970;
    NSArray *keys=[watch keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"checked"]?:@0 compare:b[@"checked"]?:@0];}];
    for(NSString *key in keys){NSDictionary *entry=watch[key],*meta=entry[@"meta"];double checked=[entry[@"checked"]doubleValue];
        if([meta isKindOfClass:NSDictionary.class]&&(!_homeAvailabilityVisible||!_homeAvailabilityType.length||[meta[@"type"]isEqual:_homeAvailabilityType])&&RWID(meta).length&&(checked<=0||now<checked||now-checked>=3600||[entry[@"quality"]integerValue]!=self.quality)&&[self allowed:meta]&&![self.profile[@"hidden"]containsObject:RWID(meta)]){[targets addObject:meta];if(targets.count==2)break;}}
    return targets;
}
- (void)recordAvailabilityWatchCheck:(NSDictionary *)meta videoID:(NSString *)videoID {
    NSString *key=RWID(meta);NSDictionary *current=self.profile[@"availabilityWatch"][key];if(!current||![self allowed:meta])return;
    NSMutableDictionary *entry=[current mutableCopy];entry[@"checked"]=@(NSDate.date.timeIntervalSince1970);entry[@"quality"]=@(self.quality);entry[@"videoID"]=videoID?:@"";
    self.profile[@"availabilityWatch"][key]=entry;[self saveForReason:NSStringFromSelector(_cmd)];
}
- (BOOL)availabilityWatchActive:(NSString *)profile quality:(NSInteger)quality generation:(NSUInteger)generation {
    return generation==_availabilityWatchGeneration&&!_homeAvailabilityVisible&&!_discoveryPaused&&[profile isEqual:self.state[@"activeProfile"]]&&quality==self.quality&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive;
}
- (void)checkAvailabilityTargets:(NSArray *)targets index:(NSUInteger)index profile:(NSString *)profile quality:(NSInteger)quality generation:(NSUInteger)generation {
    if(generation!=_availabilityWatchGeneration)return;
    if(index>=MIN(targets.count,(NSUInteger)2)||![self availabilityWatchActive:profile quality:quality generation:generation]){_checkingAvailability=NO;return;}
    NSDictionary *meta=targets[index];
    void(^advance)(void)=^{[self checkAvailabilityTargets:targets index:index+1 profile:profile quality:quality generation:generation];};
    if(![self allowed:meta]||![self watchingAvailability:meta]||[self.profile[@"hidden"]containsObject:RWID(meta)]){advance();return;}
    void(^check)(NSDictionary *)=^(NSDictionary *full){
        if(![self availabilityWatchActive:profile quality:quality generation:generation]){if(generation==self->_availabilityWatchGeneration)self->_checkingAvailability=NO;return;}
        if(![self watchingAvailability:meta]||![self allowed:full]){advance();return;}
        NSString *videoID=[self availabilityVideoID:full];
        void(^complete)(void)=^{if(![self availabilityWatchActive:profile quality:quality generation:generation])return;[self recordAvailabilityWatchCheck:full videoID:videoID];advance();};
        if(!videoID.length||[RWAvailability futureRelease:full now:NSDate.date.timeIntervalSince1970]){complete();return;}
        [self streams:full videoID:videoID foreground:NO done:^(id sources,NSString *error){complete();}];
    };
    if([meta[@"type"]isEqual:@"series"]&&![[self cachedShow:RWID(meta)][@"videos"]count]){
        NSString *url=[NSString stringWithFormat:@"https://v3-cinemeta.strem.io/meta/series/%@.json",Esc(RWID(meta))];
        [self JSON:url foreground:NO done:^(id result,NSString *error){
            if(![self availabilityWatchActive:profile quality:quality generation:generation])return;
            NSDictionary *full=[result[@"meta"]isKindOfClass:NSDictionary.class]?result[@"meta"]:nil;
            if(![RWID(full)isEqual:RWID(meta)]||![full[@"type"]isEqual:@"series"])full=nil;
            if(full)[self acceptShow:full profile:profile notify:NO];check(full?:meta);
        }];
    }else check(meta);
}
- (void)checkAvailability {
    if(!self.catalogReady||_checkingAvailability||_homeAvailabilityVisible||_discoveryPaused||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    NSArray *targets=[self availabilityWatchTargets];if(!targets.count)return;
    _checkingAvailability=YES;NSUInteger generation=++_availabilityWatchGeneration;
    [self checkAvailabilityTargets:targets index:0 profile:self.state[@"activeProfile"] quality:self.quality generation:generation];
}
