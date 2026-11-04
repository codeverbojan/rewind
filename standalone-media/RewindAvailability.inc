- (BOOL)availabilityIdentity:(NSDictionary *)meta videoID:(NSString *)videoID {
    NSString *title=RWID(meta);if(!title.length||!videoID.length)return NO;
    if([meta[@"type"]isEqual:@"movie"])return [title isEqual:videoID];
    if(![meta[@"type"]isEqual:@"series"]||![videoID hasPrefix:[title stringByAppendingString:@":"]])return NO;
    NSArray *parts=[videoID componentsSeparatedByString:@":"];if(parts.count!=3)return NO;
    NSCharacterSet *notDigits=NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    return [parts[1]length]&&[parts[2]length]&&[parts[1]rangeOfCharacterFromSet:notDigits].location==NSNotFound&&[parts[2]rangeOfCharacterFromSet:notDigits].location==NSNotFound&&[parts[2]integerValue]>0;
}
- (NSString *)availabilityVideoID:(NSDictionary *)meta {
    if([meta[@"type"]isEqual:@"movie"])return RWID(meta);
    NSString *explicitValue=RWString(meta[@"episodeVideoID"]);if([self availabilityIdentity:meta videoID:explicitValue])return explicitValue;
    if(meta[@"season"]&&meta[@"episode"]){NSString *key=[NSString stringWithFormat:@"%@:%@:%@",RWID(meta),meta[@"season"],meta[@"episode"]];if([self availabilityIdentity:meta videoID:key])return key;}
    NSDictionary *full=[self canonicalShow:RWID(meta)]?:meta;
    return RWString([_discoveryEpisodes episode:nil show:full history:self.profile[@"history"] now:NSDate.date][@"id"]);
}
- (NSDictionary *)availability:(NSDictionary *)meta {return [self availability:meta videoID:[self availabilityVideoID:meta]];}
- (NSDictionary *)availability:(NSDictionary *)meta videoID:(NSString *)videoID {
    NSMutableDictionary *target=[meta mutableCopy];
    if([meta[@"type"]isEqual:@"series"]){NSDictionary *ep=[_discoveryEpisodes episode:videoID show:[self canonicalShow:RWID(meta)]?:meta history:self.profile[@"history"] now:NSDate.date];if(ep)target[@"released"]=ep[@"released"]?:@"";}
    NSDictionary *observation=[self availabilityIdentity:meta videoID:videoID]?self.profile[@"sourceAvailability"][videoID]:nil;
    NSDictionary *offline=_offlineEvidence[videoID];if(offline&&[offline[@"quality"]integerValue]==self.quality&&NSDate.date.timeIntervalSince1970-_offlineEvidenceAt<120){NSMutableDictionary *merged=[observation mutableCopy]?:[NSMutableDictionary new];merged[@"offline_valid"]=@YES;merged[@"offline_at"]=offline[@"at"];merged[@"quality"]=@(self.quality);merged[@"policy"]=@34;observation=merged;}
    return [RWAvailability presentation:target observation:observation quality:self.quality now:NSDate.date.timeIntervalSince1970];
}
- (NSString *)availabilitySourceKey:(NSDictionary *)source {
    NSString *key=[RWSourceExperience keyForSource:source];if(key.length)return key;
    NSString *url=RWString(source[@"url"]);return url.length?[@"url:" stringByAppendingString:Key(url)]:@"";
}
- (void)trimAvailability {
    NSMutableDictionary *entries=self.profile[@"sourceAvailability"];
    while(entries.count>256){NSString *oldest=nil;double oldestTime=DBL_MAX;for(NSString *key in entries){double t=MAX([entries[key][@"checked"]doubleValue],[entries[key][@"ready_at"]doubleValue]);if(t<oldestTime){oldest=key;oldestTime=t;}}if(!oldest)break;[entries removeObjectForKey:oldest];}
}
- (void)notePlayback:(NSDictionary *)meta videoID:(NSString *)videoID source:(NSDictionary *)source quality:(NSInteger)quality metrics:(NSDictionary *)metrics {
    if(![self allowed:meta]||![self availabilityIdentity:meta videoID:videoID]||![metrics[@"context"][@"profile_id"]isEqual:self.state[@"activeProfile"]])return;
    double watched=[metrics[@"playing_seconds_estimate"]doubleValue];NSDictionary *record=[self record:videoID];
    double old=[record[@"watchSession"]isEqual:metrics[@"session_id"]]?[record[@"watchSessionSeconds"]doubleValue]:0;
    if(watched<5||watched<=old||[source[@"verifiedWidth"]integerValue]<=0)return;
    NSString *key=[self availabilitySourceKey:source];if(!key.length)return;
    NSDictionary *before=[self availability:meta videoID:videoID];
    NSMutableDictionary *ready=[[RWAvailability ready:self.profile[@"sourceAvailability"][videoID] sourceKey:key quality:quality now:NSDate.date.timeIntervalSince1970]mutableCopy];
    ready[@"meta"]=[RWAvailabilityCache metadata:meta];
    self.profile[@"sourceAvailability"][videoID]=ready;[self trimAvailability];
    if(![before[@"hero_eligible"]boolValue])[[NSNotificationCenter defaultCenter]postNotificationName:@"RWAvailabilityUpdated" object:self userInfo:@{@"videoID":videoID}];
}
- (void)notePlaybackFailure:(NSDictionary *)meta videoID:(NSString *)videoID source:(NSDictionary *)source {
    if(![self allowed:meta]||![self availabilityIdentity:meta videoID:videoID])return;
    self.profile[@"sourceAvailability"][videoID]=[RWAvailability failed:self.profile[@"sourceAvailability"][videoID] sourceKey:source?[self availabilitySourceKey:source]:nil now:NSDate.date.timeIntervalSince1970];
    [self trimAvailability];[self saveForReason:NSStringFromSelector(_cmd)];[[NSNotificationCenter defaultCenter]postNotificationName:@"RWAvailabilityUpdated" object:self userInfo:@{@"videoID":videoID}];
}
- (BOOL)watchingAvailability:(NSDictionary *)meta {return self.profile[@"availabilityWatch"][RWID(meta)]!=nil;}
- (void)watchAvailability:(NSDictionary *)meta enabled:(BOOL)enabled {
    if(![self allowed:meta]||![@[@"movie",@"series"]containsObject:meta[@"type"]])return;NSString *key=RWID(meta);if(!key.length)return;
    if(enabled){
        if([self.profile[@"availabilityWatch"]count]>=32&&![self watchingAvailability:meta])return;
        NSMutableDictionary *brief=[meta mutableCopy];[brief removeObjectForKey:@"videos"];
        self.profile[@"availabilityWatch"][key]=@{@"meta":brief,@"videoID":[self availabilityVideoID:meta]?:@"",@"checked":@0,@"initialState":[self availability:meta][@"state"]?:@"unknown"};
        if(![self isSaved:meta])[self toggleSaved:meta];
        [UIApplication.sharedApplication registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeSound categories:nil]];
    }else{[self.profile[@"availabilityWatch"]removeObjectForKey:key];[self.profile[@"availabilityUpdates"]removeObjectForKey:key];}
    [self saveForReason:NSStringFromSelector(_cmd)];
}
- (void)noteAvailability:(NSDictionary *)meta videoID:(NSString *)videoID sources:(NSArray *)sources complete:(BOOL)complete error:(NSString *)error {
    [self noteAvailability:meta videoID:videoID observation:[RWAvailability observe:sources complete:complete error:error quality:self.quality now:NSDate.date.timeIntervalSince1970] complete:complete];
}
- (void)noteAvailability:(NSDictionary *)meta videoID:(NSString *)videoID observation:(NSDictionary *)observation complete:(BOOL)complete {
    if(![self availabilityIdentity:meta videoID:videoID]||![self allowed:meta])return;
    if([observation[@"quality"]integerValue]!=self.quality||[observation[@"policy"]integerValue]!=34)return;
    NSMutableDictionary *entries=self.profile[@"sourceAvailability"];NSDictionary *old=entries[videoID];
    NSMutableDictionary *fresh=[observation mutableCopy];
    if(!complete&&![fresh[@"state"]isEqual:@"candidates"])return;
    if([old[@"quality"]integerValue]==self.quality&&[old[@"policy"]integerValue]==34){for(NSString *key in @[@"ready_at",@"ready_source",@"failed_at",@"unready_at"])if(old[key])fresh[key]=old[key];}
    if([fresh[@"state"]isEqual:@"waiting"]){fresh[@"failed_at"]=fresh[@"checked"];[self.profile[@"availabilityUpdates"]removeObjectForKey:RWID(meta)];}
    // A failed refresh preserves the diagnostic record but cannot promote it.
    if([fresh[@"state"]isEqual:@"unknown"])fresh[@"failed_at"]=fresh[@"checked"];
    NSDictionary *brief=[RWAvailabilityCache metadata:meta];fresh[@"meta"]=brief;entries[videoID]=fresh;
    BOOL changed=![old[@"state"]isEqual:fresh[@"state"]]||[fresh[@"checked"]doubleValue]-[old[@"checked"]doubleValue]>120;NSString *title=RWID(meta);NSDictionary *watch=self.profile[@"availabilityWatch"][title];
    BOOL watchedTarget=watch&&(![watch[@"videoID"]length]||[watch[@"videoID"]isEqual:videoID]);
    NSString *notificationKey=[NSString stringWithFormat:@"%@:%ld:34",videoID,(long)self.quality];BOOL newlyAvailable=[RWAvailability newOptions:old after:fresh]||([fresh[@"state"]isEqual:@"candidates"]&&[@[@"upcoming",@"waiting"]containsObject:watch[@"initialState"]?:@""]);
    // A provider listing can arrive before release or during a failed-playback
    // cooldown. Notify only when the same current presentation policy permits
    // discovery; use the selected episode's release date for a series.
    BOOL promotable=watchedTarget&&newlyAvailable&&[[self availability:meta videoID:videoID][@"discovery_eligible"]boolValue];
    if(watchedTarget&&newlyAvailable&&promotable&&![watch[@"notifiedKey"]isEqual:notificationKey]){
        NSMutableDictionary *updated=[watch mutableCopy];updated[@"notifiedKey"]=notificationKey;self.profile[@"availabilityWatch"][title]=updated;
        self.profile[@"availabilityUpdates"][title]=brief;
        if([UIApplication.sharedApplication currentUserNotificationSettings].types&UIUserNotificationTypeAlert){UILocalNotification *n=[UILocalNotification new];n.alertBody=@"A title you follow has new playback options. Open Rewind to check.";n.userInfo=[RWReminderPolicy payload:@"availability" profile:self.state[@"activeProfile"] title:title video:videoID];[UIApplication.sharedApplication presentLocalNotificationNow:n];}
    }
    [self trimAvailability];[self saveForReason:@"noteAvailability:videoID:sources:complete:error:"];if(changed)[[NSNotificationCenter defaultCenter]postNotificationName:@"RWAvailabilityUpdated" object:self userInfo:@{@"videoID":videoID}];
}
- (NSArray *)availabilityUpdates {return [self allowedItems:[self.profile[@"availabilityUpdates"]allValues]];}
- (NSArray *)availabilityWaiting {
    NSMutableArray *out=[NSMutableArray new];for(NSDictionary *entry in [self.profile[@"availabilityWatch"]allValues]){NSDictionary *meta=entry[@"meta"];if([self allowed:meta]&&!self.profile[@"availabilityUpdates"][RWID(meta)])[out addObject:meta];}return out;
}
#include "RewindAvailabilityWatch.inc"
