- (NSString *)homeFeedContext {
    RewindStore *store=[RewindStore shared];NSDictionary *prefs=[RWDiscoveryMetadataPolicy preferences:store.profile[@"discoveryPreferences"]];NSMutableArray *parts=[NSMutableArray arrayWithObjects:store.state[@"activeProfile"]?:@"",store.profile[@"maxAge"]?:@(-1),@(store.quality),@([self.homePlan[@"layoutVersion"]integerValue]>=229?229:[self.homePlan[@"layoutVersion"]integerValue]>=168?168:1),nil];for(NSString *key in [prefs.allKeys sortedArrayUsingSelector:@selector(compare:)])[parts addObject:@[key,prefs[key]]];NSData *data=[NSJSONSerialization dataWithJSONObject:parts options:0 error:nil];unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,digest);NSMutableString *key=[NSMutableString new];for(NSUInteger i=0;i<sizeof(digest);i++)[key appendFormat:@"%02x",digest[i]];return key;
}
- (BOOL)homeFeedsActive {
    return !self.reviewMode&&[self.page isEqual:@"Home"]&&([self.filter isEqual:@"All"]||![self hasBrowseFilters])&&!self.presentedViewController&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive&&[self.homeFeeds.scope isEqual:[self homeFeedContext]]&&NSProcessInfo.processInfo.systemUptime>=self.discoveryMemoryCooldown;
}
- (void)ensureHomeFeeds {
    if(self.homeFeeds||self.reviewMode)return;self.homeFeeds=[[RWHomeFeedCoordinator alloc]initWithFolder:[RWDocuments()stringByAppendingPathComponent:@"RewindFeeds"]];__weak RewindController *weak=self;
    self.homeFeeds.isActive=^BOOL{return [weak homeFeedsActive];};
    self.homeFeeds.hasMoreCatalogPages=^BOOL(NSDictionary *row,NSDictionary *cursor){return [RWHomeRailPolicy catalogPage:row cursor:cursor restricted:[RewindStore shared].restricted now:NSDate.date.timeIntervalSince1970][@"request"]!=nil;};
    self.homeFeeds.onChange=^{if([weak homeFeedsActive]){if([weak.homeView isInteracting]){weak.homeDiscoveryDeferred=YES;return;}[weak updateHomeList];}};
    self.homeFeeds.permitsRecord=^BOOL(NSDictionary *m,NSDictionary *row){return [[RewindStore shared]homeRailRecordAllowed:m row:row];};
    self.homeFeeds.prepareRecords=^(NSArray *items,NSDictionary *row,void(^done)(NSArray *,NSString *)){[[RewindStore shared]prepareHomeRail:items row:row done:done];};
    self.homeFeeds.fetchPageWithProgress=^(NSDictionary *row,NSDictionary *cursor,NSSet *excluded,BOOL(^current)(void),void(^checkpoint)(NSDictionary *,BOOL,void(^)(NSString *)),void(^done)(NSArray *,NSDictionary *,BOOL,NSString *)){[[RewindStore shared]homeRailPage:row cursor:cursor excluding:excluded current:current checkpoint:checkpoint done:done];};
    self.homeFeeds.recheckLocal=^(NSDictionary *row,NSSet *excluded,BOOL(^current)(void),void(^done)(NSArray *,NSString *)){[[RewindStore shared]recheckHomeRail:row excluding:excluded current:current done:done];};
}
- (void)homeFeedUserTouch {
    if([self homeFeedsActive])[self.homeFeeds sealOrganization:[self homeFeedContext] profile:[RewindStore shared].state[@"activeProfile"]];
}
- (void)prepareHomeFeedOpening:(NSDictionary *)hero {
    NSString *scope=[self homeFeedContext];
    if(![self.homeFeedOpeningScope isEqual:scope]){self.homeFeedOpeningScope=scope;self.homeFeedOpeningGeneration++;self.homeFeedOpeningBusy=NO;self.homeFeedOpeningFinished=NO;self.homeFeedOpeningRows=nil;}
    if(self.homeFeedOpeningFinished||self.homeFeedOpeningBusy||self.homeFeedOpeningRows)return;
    self.homeFeedOpeningBusy=YES;NSUInteger epoch=++self.homeFeedOpeningGeneration;
    NSMutableArray *rows=[NSMutableArray arrayWithObject:@{@"id":@"__hero",@"title":@"Featured",@"mediaType":@"hero",@"recipe":@"hero",@"items":hero?@[hero]:@[]}];
    for(NSDictionary *row in self.homePlan[@"rows"])if(row[@"mediaType"]&&![row[@"id"]isEqual:@"continue"]&&![row[@"id"]isEqual:@"up-next"]){if(rows.count==14)break;[rows addObject:row];}
    __weak RewindController *weak=self;
    [[RewindStore shared]prepareHomeFeedRows:rows done:^(NSArray *prepared,NSString *error){RewindController *owner=weak;if(!owner||owner.homeFeedOpeningGeneration!=epoch||![owner.homeFeedOpeningScope isEqual:scope])return;owner.homeFeedOpeningBusy=NO;
        if(error||![scope isEqual:[owner homeFeedContext]])return;owner.homeFeedOpeningRows=prepared;[owner applyPreparedHome];
    }];
}
- (NSArray *)continuingHomeRows:(NSArray *)rows excluding:(NSSet *)reserved hero:(NSDictionary *)hero {
    if(self.reviewMode||![RewindStore shared].discoveryHome[@"computedAt"])return rows;
    [self ensureHomeFeeds];[self prepareHomeFeedOpening:hero];NSMutableArray *seeds=[NSMutableArray new],*fixed=[NSMutableArray new];NSMutableSet *keys=[NSMutableSet new];
    [seeds addObject:@{@"id":@"__hero",@"title":@"Featured",@"mediaType":@"hero",@"recipe":@"hero",@"items":hero?@[hero]:@[]}];
    for(NSDictionary *row in rows){if([@[@"continue",@"up-next"]containsObject:row[@"id"]]){[fixed addObject:row];continue;}if([row[@"loading"]boolValue])continue;
        NSMutableDictionary *seed=[row mutableCopy];for(NSDictionary *recipe in self.homePlan[@"rows"])if([recipe[@"id"]isEqual:row[@"id"]]){for(NSString *key in @[@"mediaType",@"recipe",@"anchor",@"mood",@"anyGenres",@"allGenres",@"maxMinutes",@"providerGenre"])if(recipe[key])seed[key]=recipe[key];break;}
        NSMutableArray *items=[NSMutableArray new];for(NSDictionary *m in row[@"items"])if(![m[@"homePreparationPending"]boolValue])[items addObject:m];seed[@"items"]=items;
        if(!seed[@"mediaType"])continue;[seeds addObject:seed];[keys addObject:seed[@"id"]];
    }
    // Use complete prepared membership for the first organization transaction,
    // not the subset currently visible in the lazy collection views.
    if(self.homeFeedOpeningRows){[seeds removeAllObjects];[keys removeAllObjects];for(NSDictionary *row in self.homeFeedOpeningRows){[seeds addObject:row];[keys addObject:row[@"id"]];}}
    // A sparse row remains reachable on Home, including one with no currently
    // qualified title. Horizontal intent or its fallback starts real discovery.
    for(NSDictionary *row in @[@{@"id":@"for-you-movie",@"title":@"Films for you",@"mediaType":@"movie",@"recipe":@"for-you",@"items":@[]},@{@"id":@"for-you-series",@"title":@"Series for you",@"mediaType":@"series",@"recipe":@"for-you",@"items":@[]},@{@"id":@"world",@"title":@"World Cinema · Films",@"mediaType":@"movie",@"recipe":@"world",@"items":@[]}])if(![keys containsObject:row[@"id"]]&&(![row[@"id"]isEqual:@"world"]||[[RWDiscoveryMetadataPolicy preferences:[RewindStore shared].profile[@"discoveryPreferences"]][@"worldCinema"]boolValue]))[seeds addObject:row];
    [self.homeFeeds activate:[self homeFeedContext] profile:[RewindStore shared].state[@"activeProfile"] rows:seeds excluding:reserved settled:self.homeFeedOpeningFinished||self.homeFeedOpeningRows!=nil];
    if([self.homeFeeds.scope isEqual:self.homeFeedOpeningScope]&&[self.homeFeeds.diagnostics[@"storage"][@"opening"][@"settled"]boolValue]){self.homeFeedOpeningFinished=YES;self.homeFeedOpeningRows=nil;}
    if([self.homeFeeds.scope isEqual:[self homeFeedContext]]&&self.homeFeeds.rows.count){[fixed addObjectsFromArray:self.homeFeeds.rows];NSMutableArray *presented=[NSMutableArray new];for(NSDictionary *row in fixed){if(row[@"feed"]&&[(RWHomeRowFeed *)row[@"feed"]count]==0&&![row[@"loading"]boolValue])continue;NSString *type=[self.filter isEqual:@"All"]?nil:[self.filter isEqual:@"Series"]?@"series":@"movie";if(type&&row[@"mediaType"]&&![row[@"mediaType"]isEqual:type])continue;NSMutableDictionary *display=[row mutableCopy];if(type&&!row[@"mediaType"]){NSMutableArray *items=[NSMutableArray new];for(NSDictionary *m in row[@"items"])if([m[@"type"]isEqual:type])[items addObject:m];if(!items.count)continue;display[@"items"]=items;}display[@"title"]=[RWHomePresentation heading:row kids:[RewindStore shared].restricted];[presented addObject:display];}return presented;}return rows;
}
- (void)connectHomeFeedsView {
    __weak RewindController *weak=self;NSString *scope=[self homeFeedContext];
    self.homeView.onLoadMore=^(NSString *row,BOOL manual){[weak.homeFeeds loadMore:row manual:manual];};
    self.homeView.onAnchor=^(NSString *row,NSDictionary *anchor){if([weak.homeFeeds.scope isEqual:scope])[weak.homeFeeds rememberAnchor:anchor identifier:row];};
    self.homeView.restoreAnchor=^(NSString *row,void(^done)(NSUInteger,NSDictionary *)){[weak.homeFeeds anchorIndex:row done:done];};
}

- (BOOL)homeLeadAllowed:(NSDictionary *)meta {
    RewindStore *s=[RewindStore shared];NSDictionary *fresh=[s discoveryMeta:[RWHomeDelivery titleMetadata:meta]];return [s allowed:fresh]&&![[RWRecommendationPolicy homeExcludedIDsForProfile:s.profile]containsObject:RWID(fresh)]&&[RWHomePreparation allows:fresh preferences:[RWDiscoveryMetadataPolicy preferences:s.profile[@"discoveryPreferences"]] restricted:s.restricted world:NO hero:YES priors:s.discoveryHome[@"ratingPriors"]];
}
