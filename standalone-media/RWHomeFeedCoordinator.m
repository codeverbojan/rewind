#import "RWHomeFeedCoordinator.h"
@implementation RWHomeFeedCoordinator {
    RWHomeFeedStore *_store;NSString *_scope,*_seedSignature,*_error;NSMutableDictionary *_errors;NSMutableArray *_pending;
    RWHomeRowFeed *_active;NSUInteger _generation,_pages,_added;BOOL _activating,_heroLoading;NSDictionary *_hero;
    NSMutableSet *_paused;NSMutableDictionary *_attempts,*_attemptEnds;NSUInteger _emptyAdvances;
    NSMutableSet *_revisit;NSMutableDictionary *_revisitAfter;BOOL _revisitWake;
    NSDictionary *_deferredActivation;NSString *_excludedSignature;NSUInteger _deferredUpdates;
    NSMutableOrderedSet *_localDirty;NSMutableDictionary *_localAfter;BOOL _localWake,_checkingLocal;
    NSUInteger _localChecks,_localAdded,_catalogRevision,_requestSerial,_activationFailures,_catalogCheckpoints;double _activationRetryAfter;
}
- (instancetype)initWithFolder:(NSString *)folder {if((self=[super init])){_store=[[RWHomeFeedStore alloc]initWithFolder:folder];_errors=[NSMutableDictionary new];_pending=[NSMutableArray new];_revisit=[NSMutableSet new];_revisitAfter=[NSMutableDictionary new];__weak RWHomeFeedCoordinator *weak=self;
    _paused=[NSMutableSet new];_attempts=[NSMutableDictionary new];_attemptEnds=[NSMutableDictionary new];
    _localDirty=[NSMutableOrderedSet new];_localAfter=[NSMutableDictionary new];
    _store.permitsRecord=^BOOL(NSDictionary *m,NSDictionary *row){return !weak.permitsRecord||weak.permitsRecord(m,row);};
    _store.onChange=^{if(weak.onChange)weak.onChange();};
    _store.prepareRecords=^(NSArray *items,NSDictionary *row,void(^done)(NSArray *,NSString *)){if(weak.prepareRecords)weak.prepareRecords(items,row,done);else done(@[],@"Home is still getting ready.");};
}return self;}
- (NSString *)scope{return _scope;}
- (BOOL)canContinue:(RWHomeRowFeed *)row {
    if(row.more)return YES;
    if(self.hasMoreCatalogPages&&self.hasMoreCatalogPages(row.descriptor,row.cursor))return YES;
    if([_revisit containsObject:row.identifier]&&NSProcessInfo.processInfo.systemUptime>=[_revisitAfter[row.identifier]doubleValue])return YES;
    double ended=[row.cursor[@"exhaustedAt"]doubleValue];return ended>0&&NSDate.date.timeIntervalSince1970-ended>=21600;
}
- (void)catalogChanged {
    _catalogRevision++;if(_activating)return;BOOL immediate=NO;double delay=30,now=NSProcessInfo.processInfo.systemUptime;
    for(RWHomeRowFeed *row in _store.rows){
        if(row.more&&[_paused containsObject:row.identifier]&&self.recheckLocal)[_localDirty addObject:row.identifier];
        if(row.more||[row.identifier isEqual:@"__hero"])continue;[_revisit addObject:row.identifier];double left=[_revisitAfter[row.identifier]doubleValue]-now;if(left<=0)immediate=YES;else delay=MIN(delay,left);}
    if(immediate)[self changed];
    // Metadata often arrives in several callbacks. Coalesce these into one
    // wake and at most one local revisit per row per thirty seconds.
    if(!_revisitWake&&_revisit.count){_revisitWake=YES;NSUInteger epoch=_generation;__weak RWHomeFeedCoordinator *weak=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(MAX(1,delay)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{RWHomeFeedCoordinator *s=weak;if(!s||s->_generation!=epoch)return;s->_revisitWake=NO;if(s->_revisit.count)[s changed];});}
    if(self.isActive&&self.isActive())[self next];
}
- (NSArray *)rows {NSMutableArray *rows=[NSMutableArray new];for(RWHomeRowFeed *feed in _store.rows){if([feed.identifier isEqual:@"__hero"])continue;NSMutableDictionary *row=[feed.descriptor mutableCopy];row[@"feed"]=feed;row[@"landscape"]=@YES;row[@"items"]=@[];row[@"loading"]=@(feed==_active||[_pending containsObject:feed.identifier]);row[@"more"]=@([self canContinue:feed]);row[@"error"]=_errors[feed.identifier]?:_error?:@"";row[@"paused"]=@([_paused containsObject:feed.identifier]);row[@"cursor"]=feed.cursor[@"page"]?:@0;[rows addObject:row];}return rows;}
- (NSDictionary *)hero {RWHomeRowFeed *row=[self row:@"__hero"];if(!row.count)return nil;return [row cachedItem:0]?:_hero;}
- (void)loadHero {
    RWHomeRowFeed *row=[self row:@"__hero"];if(_heroLoading||!row.count||[row cachedItem:0])return;_heroLoading=YES;NSUInteger epoch=_generation;[row loadRange:NSMakeRange(0,1) done:^(NSString *error){if(epoch!=self->_generation)return;self->_heroLoading=NO;NSDictionary *m=[row cachedItem:0];if(!error&&m){self->_hero=m;[self changed];}}];
}
- (NSDictionary *)diagnostics {NSMutableArray *rows=[NSMutableArray new];for(RWHomeRowFeed *r in _store.rows)[rows addObject:@{@"id":r.identifier,@"count":@(r.count),@"cursor":r.cursor,@"anchor":r.anchor,@"error":_errors[r.identifier]?:@"",@"paused":@([_paused containsObject:r.identifier])}];return @{@"storage":_store.diagnostics,@"rows":rows,@"active":_active.identifier?:@"",@"pending":@(_pending.count),@"pages":@(_pages),@"empty_advances":@(_emptyAdvances),@"added":@(_added),@"catalog_checkpoints":@(_catalogCheckpoints),@"local_checks":@(_localChecks),@"local_added":@(_localAdded),@"local_pending":@(_localDirty.count),@"checking_local":@(_checkingLocal),@"activating":@(_activating),@"deferred_layout_updates":@(_deferredUpdates),@"layout_pending":@(_deferredActivation!=nil),@"error":_error?:@"",@"activation_failures":@(_activationFailures)};}
- (RWHomeRowFeed *)row:(NSString *)key {for(RWHomeRowFeed *row in _store.rows)if([row.identifier isEqual:key])return row;return nil;}
- (void)changed {if(self.onChange)self.onChange();}
- (void)sealOrganization:(NSString *)scope profile:(NSString *)profile {[_store sealOrganization:scope profile:profile];}
- (void)activate:(NSString *)scope profile:(NSString *)profile rows:(NSArray *)rows excluding:(NSSet *)excluded {
    [self activate:scope profile:profile rows:rows excluding:excluded settled:YES];
}
- (void)activate:(NSString *)scope profile:(NSString *)profile rows:(NSArray *)rows excluding:(NSSet *)excluded settled:(BOOL)settled {
    if(_activating&&[_scope isEqual:scope])return;
    // A cached recommendation must pass today's gate before it can refill a
    // shelf. Otherwise a rejected card can be repeatedly seeded and removed.
    // Sign the admitted identities so the same title can recover later.
    if(self.permitsRecord){NSMutableArray *admitted=[NSMutableArray new];for(NSDictionary *row in rows){
        if(![row isKindOfClass:NSDictionary.class]||![row[@"items"]isKindOfClass:NSArray.class]){[admitted addObject:row];continue;}
        NSMutableDictionary *copy=[row mutableCopy];NSMutableArray *items=[NSMutableArray new];for(id item in row[@"items"]){
            if(![item isKindOfClass:NSDictionary.class]||self.permitsRecord(item,row))[items addObject:item];
        }copy[@"items"]=items;[admitted addObject:copy];}rows=admitted;}
    NSMutableArray *keys=[NSMutableArray new];for(NSDictionary *row in rows){[keys addObject:row[@"id"]];NSUInteger target=[row[@"mediaType"]isEqual:@"hero"]?1:6;if([self row:row[@"id"]].count<target&&[row[@"items"]count])[keys addObject:[[row[@"items"]valueForKey:@"id"]componentsJoinedByString:@","]];}NSString *exclusions=[[excluded.allObjects sortedArrayUsingSelector:@selector(compare:)]componentsJoinedByString:@","];NSString *signature=[NSString stringWithFormat:@"%@|%@|%d",[keys componentsJoinedByString:@","],exclusions,settled];
    BOOL same=[_scope isEqual:scope];// Validation failures can complete synchronously. An onChange renderer
    // must not recursively retry the identical rejected batch. New seeds or
    // policy may retry immediately; unchanged failures wait for a later visit.
    if(same&&[_seedSignature isEqual:signature]&&(!_error||NSProcessInfo.processInfo.systemUptime<_activationRetryAfter)){_deferredActivation=nil;[self next];return;}
    // Metadata and recommendation callbacks can add/reorder seeds while the
    // visible shelf is loading. Keep that source request and queued shelves.
    // Only the latest layout is retained; profile/policy/exclusion changes
    // still invalidate immediately, and every appended card is revalidated.
    if(same&&(_active||_pending.count)&&[_excludedSignature isEqual:exclusions]){_deferredActivation=@{@"scope":scope,@"profile":profile,@"rows":[rows copy],@"excluded":[excluded copy],@"settled":@(settled)};_deferredUpdates++;return;}
    [self cancel];_scope=[scope copy];_seedSignature=signature;_excludedSignature=exclusions;_activating=YES;_error=nil;if(!same){[_paused removeAllObjects];[_attempts removeAllObjects];[_attemptEnds removeAllObjects];[_errors removeAllObjects];[_revisit removeAllObjects];[_revisitAfter removeAllObjects];[_localDirty removeAllObjects];[_localAfter removeAllObjects];_hero=nil;}NSUInteger epoch=_generation;
    [_store activate:scope profile:profile seedRows:rows excluding:excluded settled:settled done:^(NSString *error){if(epoch!=self->_generation)return;self->_activating=NO;self->_error=error;if(error){self->_activationFailures++;self->_activationRetryAfter=NSProcessInfo.processInfo.systemUptime+30;}else self->_activationRetryAfter=0;[self catalogChanged];[self changed];[self loadHero];[self next];}];
}
- (void)loadMore:(NSString *)identifier manual:(BOOL)manual {
    // The visible same-context rows remain usable during a short SQLite
    // layout commit. Queue end-scroll intent; next waits for that commit.
    RWHomeRowFeed *row=[self row:identifier];if(!row||![self canContinue:row]||(!manual&&(_errors[identifier]||[_paused containsObject:identifier]))||(!self.fetchPage&&!self.fetchPageWithProgress)||!self.isActive||!self.isActive())return;
    if(row==_active||[_pending containsObject:identifier])return;[_errors removeObjectForKey:identifier];[_paused removeObject:identifier];_attempts[identifier]=@0;[_attemptEnds removeObjectForKey:identifier];if(_pending.count<14)[_pending addObject:identifier];[self next];
}
- (void)next {
    if(_active||_activating)return;if(!self.isActive||!self.isActive()){[self cancel];return;}
    NSString *key=nil;BOOL local=NO;double now=NSProcessInfo.processInfo.systemUptime;
    if(_pending.count){key=_pending.firstObject;[_pending removeObjectAtIndex:0];}
    else{
        NSDictionary *next=_deferredActivation;_deferredActivation=nil;if(next){[self activate:next[@"scope"] profile:next[@"profile"] rows:next[@"rows"] excluding:next[@"excluded"] settled:[next[@"settled"]boolValue]];return;}
        double delay=30;
        for(NSString *candidate in [_localDirty.array copy]){RWHomeRowFeed *r=[self row:candidate];if(!self.recheckLocal||!r.more||![_paused containsObject:candidate]){[_localDirty removeObject:candidate];continue;}
            double left=[_localAfter[candidate]doubleValue]-now;if(left<=0){key=candidate;local=YES;[_localDirty removeObject:candidate];break;}delay=MIN(delay,left);}
        if(!key){
            // One wake for new enrichment, never a repeating poll. Local checks
            // cannot fetch pages or sources, and untouched shelves stay lazy.
            if(_localDirty.count&&!_localWake){_localWake=YES;NSUInteger epoch=_generation;__weak RWHomeFeedCoordinator *weak=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(MAX(.1,delay)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{RWHomeFeedCoordinator *s=weak;if(!s||s->_generation!=epoch)return;s->_localWake=NO;if(s.isActive&&s.isActive())[s next];});}return;
        }
    }
    RWHomeRowFeed *row=[self row:key];if(!row||![self canContinue:row]){[self next];return;}
    if(local){_localAfter[key]=@(now+30);_localChecks++;}else{[_revisit removeObject:key];_revisitAfter[key]=@(now+30);}
    // A gesture may skip one successful filtered-empty batch. Both batches
    // share the original 45-second deadline; each retains the existing provider
    // limits. No unchanged cursor, transport failure or metadata callback loops.
    if(!local){if(![_attempts[key]unsignedIntegerValue])_attemptEnds[key]=@(now+45);_attempts[key]=@([_attempts[key]unsignedIntegerValue]+1);}
    NSDictionary *startingCursor=[row.cursor copy];
    _active=row;_checkingLocal=local;NSUInteger epoch=_generation,request=++_requestSerial,revision=_catalogRevision;__block NSDictionary *cursor=[row.cursor copy];__weak RWHomeFeedCoordinator *weak=self;
    BOOL(^current)(void)=^BOOL{RWHomeFeedCoordinator *s=weak;return s&&s->_generation==epoch&&s->_requestSerial==request&&s->_active==row&&s.isActive&&s.isActive();};
    void(^finish)(NSString *)=^(NSString *error){RWHomeFeedCoordinator *s=weak;if(!s||s->_generation!=epoch||s->_requestSerial!=request||s->_active!=row)return;if(error)s->_errors[key]=error;s->_active=nil;s->_checkingLocal=NO;[s changed];[s next];};
    void(^pause)(void)=^{RWHomeFeedCoordinator *s=weak;if(!s||s->_generation!=epoch||s->_requestSerial!=request||s->_active!=row)return;
        if(local){[s->_localDirty addObject:key];finish(nil);}else finish(@"Loading paused. Try again.");};
    [self changed];
    // Bounds stalled providers even when a lower-layer callback never arrives.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((local?45:MAX(.001,[self->_attemptEnds[key]doubleValue]-now))*NSEC_PER_SEC)),dispatch_get_main_queue(),^{RWHomeFeedCoordinator *owner=weak;if(owner&&owner->_generation==epoch&&owner->_requestSerial==request&&owner->_active==row){owner->_generation++;owner->_revisitWake=NO;owner->_localWake=NO;owner->_active=nil;owner->_checkingLocal=NO;owner->_errors[key]=@"This check took too long. Try again.";[owner->_pending removeAllObjects];[owner changed];}});
    [_store assignedIDsExceptRemovedInRow:row.identifier done:^(NSSet *assigned,NSString *error){if(!current()){pause();return;}if(error){finish(error);return;}
        void(^accept)(NSArray *,NSDictionary *,BOOL,NSString *)=^(NSArray *items,NSDictionary *next,BOOL more,NSString *failure){
            if(!current()){pause();return;}if(failure){finish(failure);return;}
            if(local&&!items.count){finish(nil);return;}
            [self->_store append:items row:row expectedCursor:cursor nextCursor:next more:more done:^(NSUInteger added,NSString *writeError){
                if(epoch!=self->_generation||request!=self->_requestSerial||self->_active!=row)return;
                if(local){self->_localAdded+=added;if(added){[self->_errors removeObjectForKey:key];[self->_paused removeObject:key];}}
                else{self->_pages++;self->_added+=added;if(!writeError&&!added&&more&&self->_catalogRevision!=revision&&self.recheckLocal)[self->_localDirty addObject:key];}
                if(!local&&!writeError&&!added&&more){
                    BOOL advance=[self->_attempts[key]unsignedIntegerValue]<2&&![startingCursor isEqual:next]&&NSProcessInfo.processInfo.systemUptime<[self->_attemptEnds[key]doubleValue];
                    if(advance){self->_emptyAdvances++;[self->_pending insertObject:key atIndex:0];}
                    else [self->_paused addObject:key];
                }
                // A successful empty scan is quiet, not a network failure. A
                // later deliberate swipe or new qualifying local metadata can
                // resume it; real failures retain their explicit retry control.
                [self loadHero];finish(writeError);
            }];
        };
        if(local)self.recheckLocal(row.descriptor,assigned,current,^(NSArray *items,NSString *failure){accept(items,cursor,row.more,failure);});
        else if(self.fetchPageWithProgress)self.fetchPageWithProgress(row.descriptor,cursor,assigned,current,^(NSDictionary *checkpoint,BOOL more,void(^saved)(NSString *)){
            if(!current()){saved(@"Loading paused. Try again.");return;}
            [self->_store append:@[] row:row expectedCursor:cursor nextCursor:checkpoint more:more done:^(NSUInteger added,NSString *writeError){
                if(!current()){saved(@"Loading paused. Try again.");return;}
                if(!writeError){cursor=[checkpoint copy];self->_catalogCheckpoints++;}
                saved(writeError);
            }];
        },accept);
        else self.fetchPage(row.descriptor,cursor,assigned,current,accept);
    }];
}
- (void)rememberAnchor:(NSDictionary *)anchor identifier:(NSString *)identifier {RWHomeRowFeed *row=[self row:identifier];if(row&&anchor.count&&![_store.rows containsObject:row])return;if(row&&anchor.count)[_store saveAnchor:anchor row:row done:^(NSString *error){}];}
- (void)anchorIndex:(NSString *)identifier done:(void(^)(NSUInteger,NSDictionary *))done {RWHomeRowFeed *row=[self row:identifier];if(!row){done(NSNotFound,@{});return;}[_store anchorIndex:row done:^(NSUInteger index){done(index,row.anchor?:@{});}];}
- (void)cancel {if(_activating)_seedSignature=nil;_generation++;if(_active){if(_checkingLocal)[_localDirty addObject:_active.identifier];else _errors[_active.identifier]=@"Loading paused. Try again.";}_active=nil;_checkingLocal=NO;[_pending removeAllObjects];_deferredActivation=nil;_activating=NO;_heroLoading=NO;_revisitWake=NO;_localWake=NO;}
- (void)discardMemory {[self cancel];[_store discardMemory];}
@end
