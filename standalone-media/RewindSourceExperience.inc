// Actual persistence boundary: the returned receipt describes the exact write,
// independently of whichever live probe records survived the race.
- (NSDictionary *)sourceSucceeded:(NSDictionary *)source {
    return [self recordSourceExperience:source success:YES assessment:nil];
}
- (NSDictionary *)sourceFailed:(NSDictionary *)source {
    return [self sourceFailed:source mediaAssessment:nil];
}
- (NSDictionary *)sourceFailed:(NSDictionary *)source mediaAssessment:(NSDictionary *)assessment {
    return [self recordSourceExperience:source success:NO assessment:assessment];
}
- (NSDictionary *)recordSourceExperience:(NSDictionary *)source success:(BOOL)success assessment:(NSDictionary *)assessment {
    NSString *key=[RWSourceExperience keyForSource:source];if(!key)return nil;
    NSMutableDictionary *history=[self.state[@"sourceExperience"]isKindOfClass:NSDictionary.class]?[self.state[@"sourceExperience"]mutableCopy]:[NSMutableDictionary new];
    NSSet *previous=[NSSet setWithArray:history.allKeys];double now=NSDate.date.timeIntervalSince1970;
    NSDictionary *record=[RWSourceExperience record:history[key] source:source success:success assessment:assessment capability:[RWSourcePolicy mediaCapabilityKey:[RWSourcePolicy capabilities]] now:now];
    history[key]=record;[RWSourceExperience trim:history];self.state[@"sourceExperience"]=history;[self saveForReason:NSStringFromSelector(_cmd)];
    NSMutableSet *removed=[previous mutableCopy];[removed minusSet:[NSSet setWithArray:history.allKeys]];
    // No provider URL, tracker address, error prose, credentials or filename.
    NSMutableDictionary *saved=[NSMutableDictionary new];
    for(NSString *field in @[@"version",@"updated",@"success",@"failure",@"success_count",@"failure_count",@"failure_kind",@"samples",@"media_incompatibility",@"last_media_code"])if(record[field])saved[field]=record[field];
    return @{@"key":key,@"success":@(success),@"at":@(now),@"record":[saved copy],@"trimmed_keys":[removed.allObjects sortedArrayUsingSelector:@selector(compare:)]};
}
- (NSArray *)withSourceExperience:(NSArray *)sources {
    NSMutableArray *out=[NSMutableArray new];double now=NSDate.date.timeIntervalSince1970;
    NSString *capability=[RWSourcePolicy mediaCapabilityKey:[RWSourcePolicy capabilities]];
    for(NSDictionary *source in sources){NSString *key=[RWSourceExperience keyForSource:source];NSDictionary *r=key?self.state[@"sourceExperience"][key]:nil;
        [out addObject:[RWSourceExperience sourceForRanking:source record:r capability:capability now:now]];
    }return out;
}
