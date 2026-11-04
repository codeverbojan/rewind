// Runs on the existing serial metadata service and shared network budget.
- (void)resolvePerson:(NSDictionary *)person done:(void(^)(NSDictionary *,NSString *))done {
    NSDictionary *ref=[RWCast personReference:person];if(!ref){done(nil,@"No verified provider identity for this person yet.");return;}
    NSString *key=[NSString stringWithFormat:@"person:%@:%@",ref[@"property"],ref[@"value"]];double now=NSDate.date.timeIntervalSince1970;
    NSDictionary *cached=MD(_personLinks[key]);if([cached[@"property"]isEqual:ref[@"property"]]&&[cached[@"value"]isEqual:ref[@"value"]]&&[MT(cached[@"id"])rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location==0&&[cached[@"expires"]doubleValue]>now){done(cached,nil);return;}
    NSMutableArray *waiters=_personWaiters[key];if(waiters){if(waiters.count<8)[waiters addObject:[done copy]];else done(nil,@"Person lookup is busy.");return;}
    if(_jobs.count>=24||[_failures[key]doubleValue]>now){done(nil,@"Person details are temporarily unavailable. Try again later.");return;}
    _personWaiters[key]=[NSMutableArray arrayWithObject:[done copy]];
    [_jobs insertObject:@{@"kind":@"personIdentity",@"reference":ref,@"key":key,@"done":@YES} atIndex:0];[self yieldBackgroundCredits];[self next];
}
- (void)finishPersonIdentity:(NSDictionary *)record job:(NSDictionary *)job error:(NSString *)error {
    NSString *key=job[@"key"];double now=NSDate.date.timeIntervalSince1970;
    if(record){NSMutableDictionary *saved=[record mutableCopy];saved[@"at"]=@(now);saved[@"expires"]=@(now+7*86400);_personLinks[key]=[saved copy];[self persist];}
    else _failures[key]=@(now+60);
    NSArray *callbacks=[_personWaiters[key]copy];[_personWaiters removeObjectForKey:key];
    for(void(^callback)(NSDictionary *,NSString *) in callbacks)callback(record,error);[self finish];
}
- (void)startPersonIdentity:(NSDictionary *)job generation:(NSUInteger)g {
    __weak RWDiscoveryMetadata *weak=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC),dispatch_get_main_queue(),^{RWDiscoveryMetadata *service=weak;if(!service||g!=service->_generation||service->_active!=job||service->_paused)return;service->_generation++;[[RWMetadataBudget shared]cancel:service->_task];service->_task=nil;service->_responseData=nil;service->_responseDone=nil;[service finishPersonIdentity:nil job:job error:@"Person lookup timed out. Try again later."];});
    NSDictionary *ref=job[@"reference"];NSString *query=[NSString stringWithFormat:@"haswbstatement:%@=%@",ref[@"property"],ref[@"value"]];
    [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=query&list=search&format=json&srnamespace=0&srprop=&srlimit=3&srsearch=%@",ME(query)] generation:g done:^(NSDictionary *json,NSString *error){
        NSMutableOrderedSet *ids=[NSMutableOrderedSet new];for(NSDictionary *row in MA(MD(json[@"query"])[@"search"])){NSString *qid=MT(row[@"title"]);if([qid rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location==0)[ids addObject:qid];}
        if(error||!ids.count||ids.count>3||MD(json[@"continue"]).count||[MD(MD(json[@"query"])[@"searchinfo"])[@"totalhits"]unsignedIntegerValue]>3){[self finishPersonIdentity:nil job:job error:error?:@"Person identity is missing or ambiguous."];return;}
        [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=claims%%7Clabels&languages=en&ids=%@",ME([ids.array componentsJoinedByString:@"|"])] generation:g done:^(NSDictionary *entities,NSString *failure){
            NSMutableArray *matches=[NSMutableArray new];for(NSString *qid in ids){NSDictionary *raw=MD(MD(entities[@"entities"])[qid]);if(![raw[@"id"]isEqual:qid])continue;NSDictionary *person=[RWCast canonicalPerson:raw reference:ref];if(person)[matches addObject:person];}
            [self finishPersonIdentity:!failure&&matches.count==1?matches[0]:nil job:job error:failure?:matches.count==1?nil:@"Person identity is missing or ambiguous."];
        }];
    }];
}
