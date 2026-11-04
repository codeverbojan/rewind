- (void)cancelEntitySearch {
    NSIndexSet *indices=[_jobs indexesOfObjectsPassingTest:^BOOL(NSDictionary *job,NSUInteger idx,BOOL *stop){return [job[@"kind"]isEqual:@"entitySearch"];}];[_jobs removeObjectsAtIndexes:indices];
    if([_active[@"kind"]isEqual:@"entitySearch"]){_searchCancelled++;[self recordEntitySearch:_active outcome:@"cancelled"];_generation++;[[RWMetadataBudget shared]cancel:_task];_task=nil;_responseData=nil;_responseDone=nil;_active=nil;}
    __weak RWDiscoveryMetadata *weak=self;dispatch_async(dispatch_get_main_queue(),^{[weak next];});
}
- (void)searchEntities:(NSString *)query kind:(NSString *)kind continuation:(NSDictionary *)continuation done:(void(^)(NSArray *,NSDictionary *,NSString *))done {
    [self cancelEntitySearch];query=[RWEntitySearchPolicy query:query];NSNumber *offset=MD(continuation)[@"offset"]?:@0;
    if(query.length<2||![@[@"People",@"Studios"]containsObject:kind]||![offset isKindOfClass:NSNumber.class]||offset.longLongValue<0||offset.longLongValue>10000||offset.doubleValue!=offset.longLongValue){done(@[],@{},@"Enter at least two characters to search names.");return;}
    NSString *key=[NSString stringWithFormat:@"%@:%@:%@",kind,query.lowercaseString,offset];NSDictionary *cached=_searchPages[key];
    if([cached[@"expires"]doubleValue]>NSDate.date.timeIntervalSince1970){_searchCacheHits++;[_searchPageOrder removeObject:key];[_searchPageOrder addObject:key];done(cached[@"items"],cached[@"next"],nil);return;}
    if(_jobs.count>=24){done(cached[@"items"]?:@[],cached[@"next"]?:continuation,@"Search is busy. Try again.");return;}
    // Typing takes priority over unfinished discovery work. Suspend, don't
    // discard, its callbacks; the existing generation fence cancels old reads.
    if(_active){_generation++;[[RWMetadataBudget shared]cancel:_task];_task=nil;_responseData=nil;_responseDone=nil;[_jobs insertObject:_active atIndex:0];_active=nil;}
    [_jobs insertObject:@{@"kind":@"entitySearch",@"query":query,@"scope":kind,@"offset":offset,@"key":key,@"done":[done copy]} atIndex:0];[self next];
}
- (void)finishEntitySearch:(NSDictionary *)job records:(NSArray *)items next:(NSDictionary *)next error:(NSString *)error {
    [self recordEntitySearch:job outcome:error?@"unavailable":@"success"];NSString *key=job[@"key"];NSDictionary *cached=_searchPages[key];
    if(!error){_searchPages[key]=@{@"items":items?:@[],@"next":next?:@{},@"expires":@(NSDate.date.timeIntervalSince1970+(items.count?600:60))};[_searchPageOrder removeObject:key];[_searchPageOrder addObject:key];while(_searchPageOrder.count>32){[_searchPages removeObjectForKey:_searchPageOrder.firstObject];[_searchPageOrder removeObjectAtIndex:0];}}
    if(!error)for(NSDictionary *record in items){NSString *key=[NSString stringWithFormat:@"%@:%@",record[@"id"],[record[@"type"]isEqual:@"studio"]?@"studio":@"person"];NSMutableDictionary *profile=[MD(_entities[key])mutableCopy];NSString *oldFile=MT(profile[@"imageFile"]);
        for(NSString *field in @[@"id",@"name",@"imageFile",@"imageRole",@"biography",@"kindLabel",@"entitySourceURL"]){NSString *value=MT(record[field]);if(!value.length||([field isEqual:@"biography"]&&MT(profile[@"biographySourceURL"]).length))continue;profile[field]=value;}
        if(oldFile.length&&![oldFile isEqual:profile[@"imageFile"]]){[profile removeObjectForKey:@"image"];[profile removeObjectForKey:@"sourceURL"];[profile removeObjectForKey:@"credit"];}profile[@"searchVerifiedAt"]=@(NSDate.date.timeIntervalSince1970);profile[@"at"]=profile[@"searchVerifiedAt"];profile[@"accessedAt"]=profile[@"at"];if(!MT(profile[@"image"]).length)profile[@"expires"]=@0;_entities[key]=[profile copy];[self persist];
    }
    void(^done)(NSArray *,NSDictionary *,NSString *)=job[@"done"];[self finish];done(error?cached[@"items"]?:@[]:items,error?cached[@"next"]?:@{}:next,error);
}
- (void)searchTypes:(NSArray *)ids generation:(NSUInteger)g done:(void(^)(NSDictionary *,NSString *))done {
    NSMutableDictionary *known=[NSMutableDictionary new];NSMutableArray *missing=[NSMutableArray new];double now=NSDate.date.timeIntervalSince1970;
    for(NSString *qid in ids){NSDictionary *record=_searchTypes[qid];if(record&&now-[record[@"at"]doubleValue]<7*86400){known[qid]=record;[_searchTypeOrder removeObject:qid];[_searchTypeOrder addObject:qid];}else [missing addObject:qid];}
    if(!missing.count){done(known,nil);return;}NSString *url=[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=claims&ids=%@",ME([missing componentsJoinedByString:@"|"])];
    [self fetch:url generation:g done:^(NSDictionary *json,NSString *error){if(error){done(known,error);return;}NSDictionary *entities=MD(json[@"entities"]);
        for(NSString *qid in missing){NSDictionary *entity=MD(entities[qid]);if(![entity[@"id"]isEqual:qid])continue;NSMutableArray *parents=[NSMutableArray new];for(id raw in MA(MD(entity[@"claims"])[@"P279"])){NSDictionary *claim=MD(raw);NSString *parent=MT(MD(MV(claim))[@"id"]);if([parent rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location!=0)continue;[parents addObject:@{@"mainsnak":@{@"datavalue":@{@"value":@{@"id":parent}}}}];if(parents.count==16)break;}
            NSDictionary *brief=@{@"id":qid,@"at":@(NSDate.date.timeIntervalSince1970),@"claims":@{@"P279":parents}};known[qid]=brief;self->_searchTypes[qid]=brief;[self->_searchTypeOrder removeObject:qid];[self->_searchTypeOrder addObject:qid];
        }while(self->_searchTypeOrder.count>128){[self->_searchTypes removeObjectForKey:self->_searchTypeOrder.firstObject];[self->_searchTypeOrder removeObjectAtIndex:0];}done(known,nil);
    }];
}
- (void)startEntitySearch:(NSDictionary *)job generation:(NSUInteger)g {
    _searchStarted++;
    __weak RWDiscoveryMetadata *weak=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC),dispatch_get_main_queue(),^{RWDiscoveryMetadata *s=weak;if(!s||g!=s->_generation||s->_active!=job||s->_paused)return;s->_generation++;[[RWMetadataBudget shared]cancel:s->_task];s->_task=nil;s->_responseDone=nil;s->_responseData=nil;[s finishEntitySearch:job records:@[] next:@{} error:@"Search took too long. Try again."];});
    NSString *url=[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbsearchentities&format=json&language=en&uselang=en&type=item&limit=8&continue=%@&search=%@",job[@"offset"],ME(job[@"query"])];
    [self fetch:url generation:g done:^(NSDictionary *response,NSString *error){
        if(error||![response[@"search"]isKindOfClass:NSArray.class]){[self finishEntitySearch:job records:@[] next:@{} error:error?:@"Search results could not be read. Try again."];return;}
        id offset=response[@"search-continue"];if(offset&&(![offset isKindOfClass:NSNumber.class]||[offset longLongValue]<=[job[@"offset"]longLongValue]||[offset longLongValue]>10000||[offset doubleValue]!=[offset longLongValue])){[self finishEntitySearch:job records:@[] next:@{} error:@"Search returned an invalid continuation. Try again."];return;}
        NSDictionary *next=offset?@{@"offset":offset}:@{};NSMutableArray *hits=[NSMutableArray new];NSMutableOrderedSet *ids=[NSMutableOrderedSet new];for(id raw in MA(response[@"search"])){NSDictionary *hit=MD(raw);NSString *qid=MT(hit[@"id"]);if([qid rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location!=0||[ids containsObject:qid])continue;[ids addObject:qid];[hits addObject:hit];if(ids.count==8)break;}
        if(!ids.count){[self finishEntitySearch:job records:@[] next:next error:nil];return;}
        NSString *entitiesURL=[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=claims%%7Clabels%%7Cdescriptions%%7Caliases&languages=en%%7Cmul&ids=%@",ME([ids.array componentsJoinedByString:@"|"])];
        [self fetch:entitiesURL generation:g done:^(NSDictionary *json,NSString *failure){NSDictionary *entities=MD(json[@"entities"]);if(failure||!entities.count){[self finishEntitySearch:job records:@[] next:@{} error:failure?:@"Search identities could not be verified."];return;}
            NSMutableArray *ordered=[NSMutableArray new];for(NSString *qid in ids)if([MD(entities[qid])[@"id"]isEqual:qid])[ordered addObject:entities[qid]];
            void(^complete)(NSDictionary *)=^(NSDictionary *types){NSArray *records=[RWEntitySearchPolicy records:hits entities:entities types:types kind:job[@"scope"] query:job[@"query"]];[self finishEntitySearch:job records:records next:next error:nil];};
            NSArray *refs=[RWEntitySearchPolicy references:ordered parents:NO];if(!refs.count){complete(@{});return;}
            [self searchTypes:refs generation:g done:^(NSDictionary *firstTypes,NSString *typeError){if(typeError){[self finishEntitySearch:job records:@[] next:@{} error:typeError];return;}NSMutableDictionary *types=[firstTypes mutableCopy];NSMutableArray *orderedTypes=[NSMutableArray new];for(NSString *key in [types.allKeys sortedArrayUsingSelector:@selector(compare:)])[orderedTypes addObject:types[key]];NSArray *parents=[RWEntitySearchPolicy references:orderedTypes parents:YES];NSMutableArray *missing=[NSMutableArray new];for(NSString *qid in parents)if(!types[qid])[missing addObject:qid];if(!missing.count){complete(types);return;}
                [self searchTypes:missing generation:g done:^(NSDictionary *secondTypes,NSString *parentError){if(parentError){[self finishEntitySearch:job records:@[] next:@{} error:parentError];return;}[types addEntriesFromDictionary:secondTypes];complete(types);}];
            }];
        }];
    }];
}
