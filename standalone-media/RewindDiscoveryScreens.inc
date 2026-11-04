// Native discovery destinations. Missing promoted-card membership is prepared
// on the bounded store worker; the UI draws only validated records or skeletons.
#include "RewindHomeDeferred.inc"
#include "RewindHomeFeeds.inc"
- (void)syncDiscoveryActivity {
    if(self.reviewMode)return;BOOL previewLookup=[self.previewSession.state isEqual:@"lookup"];BOOL idle=!self.presentedViewController&&![self.page isEqual:@"Profiles"]&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive&&!previewLookup&&!self.preview.usingVideoNetwork&&NSProcessInfo.processInfo.systemUptime>=self.discoveryMemoryCooldown;
    BOOL home=[self.page isEqual:@"Home"]&&([self.filter isEqual:@"All"]||![self hasBrowseFilters]);
    NSString *mediaType=[self.filter isEqual:@"Movies"]?@"movie":[self.filter isEqual:@"Series"]?@"series":nil;
    if([[RewindStore shared]setHomeAvailabilityVisible:home mediaType:mediaType]&&home)self.homeRefreshStarted=NO;
    if(!idle||!home)[self.homeFeeds cancel];
    [[RewindStore shared]setDiscoveryPaused:!idle];
    [[RewindStore shared]setUpcomingVisible:idle&&[self.page isEqual:@"Upcoming"]];
}
- (void)pushDestination {
    [self.homeView saveVisibleAnchors];
    if([self.page isEqual:@"Entity"]){[self rememberEntityRail];[[RewindStore shared].discoveryMetadata cancelCredits:self.entity[@"id"] role:self.entity[@"creditRole"]];self.entityGeneration++;self.entityBusy=NO;}
    if(!self.destinationStack)self.destinationStack=[NSMutableArray new];
    [self.destinationStack addObject:@{@"page":self.page?:@"Home",@"filter":self.filter?:@"All",@"offset":@(self.content.contentOffset.y),@"feedOffset":@(self.feedGrid.contentOffset.y),@"listAnchor":[self.page isEqual:@"My List"]?([self.feedGrid positionAnchor]?:@{}):@{},@"homeOffset":@(self.homeView.contentOffset.y),@"upcomingOffset":@(self.upcomingList.contentOffset.y),@"upcomingKind":self.upcomingKind?:@"movie",@"upcomingMode":self.upcomingMode?:@"Coming soon",@"detail":self.detail?:@{},@"detailNavigation":[self detailNavigationSnapshot],@"season":@(self.season),@"entity":self.entity?:@{},@"entityItems":self.entityItems?:@[],@"entityHighlights":self.entityHighlights?:@{},@"entityHighlightPool":self.entityHighlightPool?:@[],@"entityHighlightMode":self.entityHighlightMode?:@"knownFor",@"entityHighlightOffsets":[self.entityHighlightOffsets copy]?:@{},@"entityBioExpanded":@(self.entityBioExpanded),@"entityDetailRequested":self.entityDetailRequested?:@"",@"entityFeed":self.entityFeed?:NSNull.null,@"entityFeedPrepared":@(self.entityFeedPrepared),@"entityCursor":self.entityCursor?:@{},@"entityPending":self.entityPendingRatings?:@[],@"entityEmpty":@(self.entityEmptyPages),@"entityType":self.entityType?:@"All",@"entitySort":self.entitySort?:@"Year",@"entityOffset":@(self.entityOffset),@"entityPageOffset":@(self.entityPageOffset),@"exploreFeed":self.exploreFeed?:NSNull.null,@"exploreCursor":self.exploreCursor?:@{},@"exploreRemoteStarted":@(self.exploreRemoteStarted),@"exploreRemoteMore":@(self.exploreRemoteMore),@"exploreRemoteInterrupted":@(self.exploreRemoteBusy),@"exploreEmptyPages":@(self.exploreEmptyPages),@"exploreQuery":self.exploreQuery?:@"",@"exploreType":self.exploreType?:@"Films",@"entityMore":@(self.entityMore),@"exploreKind":self.exploreKind?:@"Moods",@"mood":self.exploreMood?:@""}];
    [self.exploreFeed park];self.exploreGeneration++;self.exploreBusy=NO;[self.entityFeed park];[self.browseFeed park];
    if(self.destinationStack.count>12)[self.destinationStack removeObjectAtIndex:0];
}
- (void)destinationBack {
    NSDictionary *prior=self.destinationStack.lastObject;if(!prior){[self go:@"Home"];return;}[self.destinationStack removeLastObject];
    self.entityGeneration++;self.entitySelectionGeneration++;self.entityBusy=NO;self.entitySelecting=NO;self.entityFeedPrepared=[prior[@"entityFeedPrepared"]boolValue];self.entityFeed=[prior[@"entityFeed"]isKindOfClass:RWFeedStore.class]?prior[@"entityFeed"]:nil;self.entityCursor=prior[@"entityCursor"];self.entityPendingRatings=prior[@"entityPending"];self.entityEmptyPages=[prior[@"entityEmpty"]unsignedIntegerValue];self.entity=prior[@"entity"];self.entityItems=prior[@"entityItems"];self.entityHighlights=prior[@"entityHighlights"];self.entityHighlightPool=prior[@"entityHighlightPool"];self.entityHighlightMode=prior[@"entityHighlightMode"];self.entityBioExpanded=[prior[@"entityBioExpanded"]boolValue];self.entityDetailRequested=nil;self.entityHighlightGeneration++;self.entityHighlightBusy=NO;self.entityHighlightPending=@[];self.entityHighlightOffsets=[prior[@"entityHighlightOffsets"]mutableCopy]?:[NSMutableDictionary new];self.entityType=prior[@"entityType"];self.entitySort=prior[@"entitySort"];self.entityOffset=[prior[@"entityOffset"]unsignedIntegerValue];self.entityPageOffset=[prior[@"entityPageOffset"]unsignedIntegerValue];self.exploreGeneration++;self.exploreBusy=NO;self.exploreError=[prior[@"exploreRemoteInterrupted"]boolValue]?@"Search paused. Try again to continue.":nil;self.exploreCursor=prior[@"exploreCursor"]?:@{};self.exploreRemoteStarted=[prior[@"exploreRemoteStarted"]boolValue];self.exploreRemoteMore=[prior[@"exploreRemoteMore"]boolValue];self.exploreRemoteBusy=NO;self.exploreLocalRecords=@[];self.exploreEmptyPages=[prior[@"exploreEmptyPages"]unsignedIntegerValue];self.exploreFeed=[prior[@"exploreFeed"]isKindOfClass:RWFeedStore.class]?prior[@"exploreFeed"]:nil;self.exploreQuery=prior[@"exploreQuery"];self.exploreType=prior[@"exploreType"];self.entityMore=[prior[@"entityMore"]boolValue];self.exploreKind=prior[@"exploreKind"];self.exploreMood=prior[@"mood"];self.detail=prior[@"detail"];[self restoreDetailNavigation:prior[@"detailNavigation"]];self.season=[prior[@"season"]integerValue];self.filter=prior[@"filter"];if([prior[@"page"]isEqual:@"Upcoming"]){self.upcomingKind=prior[@"upcomingKind"];self.upcomingMode=prior[@"upcomingMode"];}self.upcomingRestoreOffset=[prior[@"page"]isEqual:@"Upcoming"]?prior[@"upcomingOffset"]:nil;[self go:prior[@"page"]];self.content.contentOffset=CGPointMake(0,MIN([prior[@"offset"]doubleValue],MAX(0,self.content.contentSize.height-self.content.bounds.size.height)));[self.feedGrid layoutIfNeeded];self.feedGrid.contentOffset=CGPointMake(0,MIN([prior[@"feedOffset"]doubleValue],MAX(0,self.feedGrid.contentSize.height-self.feedGrid.bounds.size.height)));[self.homeView layoutIfNeeded];self.homeView.contentOffset=CGPointMake(0,MIN([prior[@"homeOffset"]doubleValue],MAX(0,self.homeView.contentSize.height-self.homeView.bounds.size.height)));[self.upcomingList layoutIfNeeded];self.upcomingList.contentOffset=CGPointMake(0,MIN([prior[@"upcomingOffset"]doubleValue],MAX(0,self.upcomingList.contentSize.height-self.upcomingList.bounds.size.height)));if([self.page isEqual:@"My List"]&&[prior[@"listAnchor"]count])[self.feedGrid restorePositionAnchor:prior[@"listAnchor"]];if([self.page isEqual:@"Explore"]&&(!self.exploreFeed||!self.exploreFeed.pagesComplete||![self.exploreFeed.context isEqual:[[self currentExploreScope]stringByAppendingFormat:@":%@",self.exploreQuery?:@""]]))[self fetchExplore];
}
- (void)discoveryUpdated {
    [self.homeFeeds catalogChanged];
    if(self.reviewMode||self.presentedViewController)return;
    if([self.page isEqual:@"Home"]){
        if([self.homeView isInteracting]){self.homeDiscoveryDeferred=YES;return;}self.homeDiscoveryDeferred=NO;
        double began=NSProcessInfo.processInfo.systemUptime;
        [self beginHomePreparationPass];
        self.homeExcludedIDs=[RWRecommendationPolicy homeExcludedIDsForProfile:[RewindStore shared].profile];
        // Remove newly ineligible cards before applying row capacity. Keeping
        // hidden expired cards here could fill a rail with invisible entries.
        NSMutableDictionary *eligibility=[NSMutableDictionary new];BOOL(^allows)(NSDictionary *,NSString *,BOOL)=^BOOL(NSDictionary *m,NSString *row,BOOL hero){NSString *key=[NSString stringWithFormat:@"%@:%@:%d",RWID(m),row,hero];NSNumber *cached=eligibility[key];if(!cached){NSDictionary *ready=[self homeTitleForDisplay:m];cached=@(ready?[self homePreparedTitleAllowed:ready world:[row isEqual:@"world"] hero:hero]:[[RewindStore shared]allowed:m]&&![self.homeExcludedIDs containsObject:RWID(m)]&&[RWRecommendationPolicy homePendingEligible:m now:NSDate.date.timeIntervalSince1970]);eligibility[key]=cached;}return cached.boolValue;};
        NSDictionary *before=[RWDiscoveryCatalog filterHome:[RWHomePresentation normalizedHome:self.homePlan] allows:allows],*incoming=[RWDiscoveryCatalog filterHome:[RWHomePresentation normalizedHome:[RewindStore shared].discoveryHome] allows:allows];
        NSDictionary *merged=[RWDiscoveryCatalog mergeHome:before incoming:incoming];BOOL changed=![[RWHomeDelivery displaySignature:merged]isEqual:[RWHomeDelivery displaySignature:self.homePlan]];self.homePlan=merged;if(changed)[self scheduleCatalogRender];
        [self finishHomePreparationPass];[[RWUIProbe shared]work:@"home_merge" started:began];
    }else if([self.page isEqual:@"Details"]){NSDictionary *enriched=[[RewindStore shared]discoveryMeta:self.detail];if(![enriched isEqual:self.detail]){self.detail=enriched;[self requestDetailRender];}[self requestRelatedTitles];}
}
- (BOOL)homeTitleAllowed:(NSDictionary *)meta world:(BOOL)world hero:(BOOL)hero {
    self.homeExcludedIDs=[RWRecommendationPolicy homeExcludedIDsForProfile:[RewindStore shared].profile];
    return [self homePreparedTitleAllowed:[[RewindStore shared]discoveryMeta:[RWHomeDelivery titleMetadata:meta]] world:world hero:hero];
}
- (NSDictionary *)homeTitleForDisplay:(NSDictionary *)meta {
    NSDictionary *entry=[self.homeValidation entryForTitle:meta now:NSDate.date.timeIntervalSince1970];
    if(entry)return entry[@"meta"];
    if(self.reviewMode)return [[RewindStore shared]discoveryMeta:[RWHomeDelivery titleMetadata:meta]];
    if(RWID(meta).length)self.homeDeferredNeeded=YES;return nil;
}
- (BOOL)homePreparedTitleAllowed:(NSDictionary *)m world:(BOOL)world hero:(BOOL)hero {
    RewindStore *s=[RewindStore shared];if(!RWID(m).length||![s allowed:m]||[self.homeExcludedIDs containsObject:RWID(m)])return NO;
    if(self.homeValidation){NSDictionary *entry=[self.homeValidation entryForPreparedMetadata:m now:NSDate.date.timeIntervalSince1970];
        if(entry)return [entry[hero?@"hero":world?@"world":@"regular"]boolValue];
        self.homeDeferredNeeded=YES;return NO; // Deadline crossed; never display expired membership.
    }
    return [RWHomePreparation allows:m preferences:[RWDiscoveryMetadataPolicy preferences:s.profile[@"discoveryPreferences"]] restricted:s.restricted world:world hero:hero priors:s.discoveryHome[@"ratingPriors"]];
}
- (NSArray *)promotedItems:(NSArray *)items type:(NSString *)type world:(BOOL)world {
    RewindStore *s=[RewindStore shared];NSMutableArray *out=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];NSSet *hidden=[NSSet setWithArray:s.profile[@"hidden"]?:@[]];
    for(NSDictionary *m in items){NSString *key=RWID(m);if([self.displayedIDs containsObject:key]||[seen containsObject:key]||[hidden containsObject:key]||(type.length&&![m[@"type"]isEqual:type]))continue;
        double began=NSProcessInfo.processInfo.systemUptime;NSDictionary *prepared=[self homeTitleForDisplay:m];self.homePromotedMetadataSeconds+=NSProcessInfo.processInfo.systemUptime-began;
        if(!prepared){if(![RWRecommendationPolicy homePendingEligible:m now:NSDate.date.timeIntervalSince1970])continue;NSMutableDictionary *pending=[[RWHomeDelivery titleMetadata:m]mutableCopy];pending[@"homePreparationPending"]=@YES;[seen addObject:key];[out addObject:pending];if(out.count==12)break;continue;}
        began=NSProcessInfo.processInfo.systemUptime;BOOL allowed=[self homePreparedTitleAllowed:prepared world:world hero:NO];self.homePromotedPolicySeconds+=NSProcessInfo.processInfo.systemUptime-began;
        if(!allowed)continue;[seen addObject:key];[out addObject:prepared];if(out.count==12)break;
    }return out;
}
- (UIView *)homeHeader:(NSDictionary *)hero empty:(BOOL)empty {
    RewindStore *s=[RewindStore shared];CGFloat w=[self width];__weak RewindController *weak=self;
    UIView *header=[[UIView alloc]initWithFrame:CGRectMake(0,0,w,hero.count?396:144)];
    if(!hero.count){
        UILabel *greeting=RWLabel(![self.filter isEqual:@"All"]?self.filter:s.restricted?[@"Hello, " stringByAppendingString:RWString(s.profile[@"name"])]:@"Find your next great story.",32,UIFontWeightBold,RWColor(0xf5f2eb));greeting.frame=CGRectMake(32,32,w-64,47);[header addSubview:greeting];
        UILabel *caption=RWLabel(s.restricted?@"Stories within your age limit.":@"Familiar favourites. Unexpected discoveries.",14,UIFontWeightRegular,RWColor(0xa6b0bd));caption.frame=CGRectMake(33,84,w-66,24);[header addSubview:caption];
        if(empty){header.frame=CGRectMake(0,0,w,320);caption.text=@"Search for a favourite while we check new discoveries.";RWButton *search=[RWButton text:@"Explore titles" action:^{[weak go:@"Search"];}];[search appearance:YES];[search icon:@"search"];search.frame=CGRectMake(32,156,210,48);[header addSubview:search];}return header;
    }
    UIView *stage=[[UIView alloc]initWithFrame:CGRectMake(0,18,w,350)];stage.backgroundColor=RWColor(0x111925);stage.clipsToBounds=YES;stage.accessibilityIdentifier=@"RWHomeHero";[header addSubview:stage];
    UIImageView *art=[[UIImageView alloc]initWithFrame:CGRectMake(w*.22,0,w*.78,350)];art.contentMode=UIViewContentModeScaleAspectFill;art.clipsToBounds=YES;[stage addSubview:art];[s artwork:[RWArtworkPolicy URLsForMeta:hero landscape:YES] role:@"hero" identity:RWID(hero) into:art completion:nil];
    UIView *shade=[[UIView alloc]initWithFrame:stage.bounds];RWShade(shade,YES);[stage addSubview:shade];
    UILabel *eyebrow=RWLabel(@"YOUR NEXT GREAT WATCH",11,UIFontWeightBold,RWColor(0xffac91));RWTracking(eyebrow,1.6);eyebrow.frame=CGRectMake(33,24,400,20);[stage addSubview:eyebrow];
    UILabel *name=RWLabel(RWString(hero[@"name"]),w>900?42:36,UIFontWeightBold,RWColor(0xf8f5ee));name.numberOfLines=2;name.frame=CGRectMake(30,58,w*.65,98);[stage addSubview:name];
    UILabel *facts=RWLabel([self factsFor:hero],13,UIFontWeightMedium,RWColor(0xc5cdd8));facts.frame=CGRectMake(33,164,w-66,24);[stage addSubview:facts];
    UILabel *synopsis=RWLabel(RWString(hero[@"description"]),15,UIFontWeightRegular,RWColor(0xc1cad5));synopsis.numberOfLines=2;synopsis.frame=CGRectMake(33,201,MIN(600,w-90),44);[stage addSubview:synopsis];
    RWButton *play=[RWButton text:@"Play" action:^{if(![weak homeLeadAllowed:hero]){[weak showDetails:hero];return;}NSString *videoID=[s availabilityVideoID:hero];if(videoID.length)[weak chooseSources:hero videoID:videoID restart:NO];else[weak showDetails:hero];}];[play appearance:YES];[play icon:@"play"];play.frame=CGRectMake(32,274,150,48);[stage addSubview:play];
    RWButton *info=[RWButton text:@"Details" action:^{[weak showDetails:hero];}];[info appearance:NO];[info icon:@"info"];info.frame=CGRectMake(194,274,145,48);[stage addSubview:info];return header;
}
- (void)addHomeRow:(NSMutableArray *)rows identity:(NSString *)identity title:(NSString *)title items:(NSArray *)items landscape:(BOOL)landscape minimum:(NSUInteger)minimum {
    RewindStore *s=[RewindStore shared];NSArray *cards=[RWDiscoveryCatalog uniqueVisible:[s allowedItems:items] excluding:self.displayedIDs hidden:s.profile[@"hidden"] limit:12];if(cards.count<minimum)return;
    for(NSDictionary *m in cards)[self.displayedIDs addObject:RWID(m)];[rows addObject:@{@"id":identity,@"title":title?:@"",@"items":cards,@"landscape":@(landscape)}];
}
- (void)updateHomeList {
    // Also cover direct refresh callers; keep hidden shelves off the playback
    // main thread. Normal dismissal rebuilds them from the latest store state.
    if([self.presentedViewController isKindOfClass:RewindPlayer.class])return;
    double prepareBegan=NSProcessInfo.processInfo.systemUptime;
    [self beginHomePreparationPass];
    self.homePromotedMetadataSeconds=0;self.homePromotedPolicySeconds=0;
    self.homeExcludedIDs=[RWRecommendationPolicy homeExcludedIDsForProfile:[RewindStore shared].profile];
    RewindStore *s=[RewindStore shared];BOOL all=[self.filter isEqual:@"All"];NSString *type=all?nil:[self.filter isEqual:@"Series"]?@"series":@"movie";self.homePlan=[RWHomePresentation normalizedHome:self.homePlan?:s.discoveryHome];
    self.displayedIDs=[NSMutableSet new];NSDictionary *hero=[self homeTitleForDisplay:self.homePlan[@"hero"]];
    if(![self homePreparedTitleAllowed:hero world:NO hero:YES])hero=nil;
    if(hero)[self.displayedIDs addObject:RWID(hero)];NSMutableArray *rows=[NSMutableArray new],*continuing=[NSMutableArray new];
    double sectionBegan=NSProcessInfo.processInfo.systemUptime;
    for(NSDictionary *r in s.continuingHistory){NSMutableDictionary *m=[[s discoveryMeta:r[@"meta"]]mutableCopy];m[@"historyRecord"]=r;[continuing addObject:m];}
    [self addHomeRow:rows identity:@"continue" title:@"Continue watching" items:continuing landscape:YES minimum:1];
    [[RWUIProbe shared]work:@"home_rows_history" started:sectionBegan];sectionBegan=NSProcessInfo.processInfo.systemUptime;
    [self addHomeRow:rows identity:@"up-next" title:@"Your next episode" items:s.upNext landscape:YES minimum:1];
    [[RWUIProbe shared]work:@"home_rows_up_next" started:sectionBegan];sectionBegan=NSProcessInfo.processInfo.systemUptime;
    NSMutableSet *homeReserved=[self.displayedIDs mutableCopy];if(hero)[homeReserved removeObject:RWID(hero)];[homeReserved unionSet:self.homeExcludedIDs];
    for(NSDictionary *row in self.homePlan[@"rows"]){BOOL world=[row[@"id"]isEqual:@"world"];NSArray *items=[self promotedItems:row[@"items"] type:row[@"mediaType"] world:world];NSMutableArray *cards=[NSMutableArray new];for(NSDictionary *m in items){NSMutableDictionary *card=[m mutableCopy];if(world)card[@"showLanguage"]=@YES;[card removeObjectForKey:@"episodeVideoID"];[cards addObject:card];}
        [self addHomeRow:rows identity:row[@"id"] title:row[@"title"] items:cards landscape:YES minimum:MAX(1,[row[@"minimumCount"]unsignedIntegerValue])];
    }
    rows=[[self continuingHomeRows:rows excluding:homeReserved hero:hero]mutableCopy];
    rows=[[RWHomePresentation rows:rows mediaType:type]mutableCopy];
    if(!self.reviewMode&&[self.homeFeeds.scope isEqual:[self homeFeedContext]]){NSDictionary *savedHero=self.homeFeeds.hero;hero=savedHero&&[self homeLeadAllowed:savedHero]?savedHero:nil;}
    if(type.length&&![hero[@"type"]isEqual:type])hero=nil;
    [[RWUIProbe shared]work:@"home_rows_promoted" started:sectionBegan];sectionBegan=NSProcessInfo.processInfo.systemUptime;
    [[RWUIProbe shared]work:@"home_promoted_metadata" started:sectionBegan-self.homePromotedMetadataSeconds];
    [[RWUIProbe shared]work:@"home_promoted_policy" started:NSProcessInfo.processInfo.systemUptime-self.homePromotedPolicySeconds];
    // Keep real cached rows during refreshes. Only a genuinely empty first
    // load gets skeletons, and only for a bounded initial preparation window.
    if(!rows.count&&!s.discoveryHome[@"computedAt"]&&NSProcessInfo.processInfo.systemUptime<self.homeInitialLoadingUntil)
        [rows addObjectsFromArray:[RWHomePresentation initialLoadingRows]];
    NSDictionary *record=@{@"destination":self.filter?:@"All",@"hero":hero?:@{},@"empty":@(!rows.count),@"profile":s.profile[@"name"]?:@"",@"kids":@(s.restricted)};UIView *header=self.homeView.tableHeaderView;
    if(![record isEqual:self.homeHeaderRecord]||!header){self.homeHeaderRecord=record;header=[self homeHeader:hero empty:!rows.count];}
    [[RWUIProbe shared]work:@"home_rows_header" started:sectionBegan];
    [[RWUIProbe shared]work:@"home_rows_prepare" started:prepareBegan];double applyBegan=NSProcessInfo.processInfo.systemUptime;
    [self.homeView updateRows:rows header:header];[[RWUIProbe shared]work:@"home_rows_apply" started:applyBegan];[self recordVisibleDiscovery];[self syncDiscoveryActivity];
    if(!self.reviewMode)[s report:@{@"home_view":self.homeView.diagnostics,@"home_continuation":self.homeFeeds.diagnostics?:@{}}];
    if(!self.homeRefreshStarted&&!self.reviewMode&&s.discoveryHome[@"computedAt"]){self.homeRefreshStarted=YES;[s refreshHomeAvailability];}
    [self finishHomePreparationPass];
}
- (void)homeInitialLoadingExpired {
    if(![self.page isEqual:@"Home"]||!self.homeView||![[self.homeView diagnostics][@"initial_loading"]boolValue]||NSProcessInfo.processInfo.systemUptime<self.homeInitialLoadingUntil)return;
    if([self.homeView isInteracting]){[self performSelector:@selector(homeInitialLoadingExpired) withObject:nil afterDelay:.25];return;}
    [self updateHomeList];
}
- (void)discoveryHomePage {
    if([self restoreParkedHome])return;
    CGFloat top=0;__weak RewindController *weak=self;
    self.homeScope=[NSString stringWithFormat:@"%@:%@",[RewindStore shared].state[@"activeProfile"],self.filter];self.homeHeaderRecord=nil;
    self.homeViewContext=[self currentHomeContext];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(homeInitialLoadingExpired) object:nil];
    self.homeInitialLoadingUntil=[RewindStore shared].discoveryHome[@"computedAt"]?0:NSProcessInfo.processInfo.systemUptime+10;
    if(self.homeInitialLoadingUntil)[self performSelector:@selector(homeInitialLoadingExpired) withObject:nil afterDelay:10];
    self.homeView=[[RWHomeView alloc]initWithFrame:CGRectMake(0,top,[self width],MAX(100,self.content.bounds.size.height-top))];self.homeView.scope=self.homeScope;self.homeView.reviewMode=self.reviewMode;
    [self connectHomeFeedsView];
    if(!self.railOffsets)self.railOffsets=[NSMutableDictionary new];self.homeView.railOffsets=self.railOffsets;
    self.homeView.onSelect=^(NSDictionary *meta){NSDictionary *r=meta[@"historyRecord"];if(r)[weak chooseSources:r[@"meta"] videoID:r[@"videoID"] restart:NO];else if(RWString(meta[@"episodeVideoID"]).length)[weak chooseSources:meta videoID:meta[@"episodeVideoID"] restart:NO];else[weak showDetails:meta];};
    self.homeView.onViewport=^{[weak scheduleHomeViewportPreparation];[weak recordVisibleDiscovery];if(weak.homeDiscoveryDeferred&&![weak.homeView isInteracting])[weak discoveryUpdated];};[self.content addSubview:self.homeView];self.content.scrollEnabled=NO;self.content.contentSize=self.content.bounds.size;[self updateHomeList];
    if(!self.reviewMode)[[RewindStore shared]report:@{@"home_reactivated":@NO}];
}
- (void)profileMenu:(UIView *)anchor {
    __weak RewindController *weak=self;RewindStore *s=[RewindStore shared];UIAlertController *menu=[UIAlertController alertControllerWithTitle:RWString(s.profile[@"name"]) message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for(NSString *page in s.restricted?@[@"Profiles",@"Downloads"]:@[@"Profiles",@"Downloads",@"Preferences",@"Settings"]){NSString *title=[page isEqual:@"Profiles"]?@"Switch profile":[page isEqual:@"Preferences"]?@"Discovery preferences":page;[menu addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[weak go:page];}]];}
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];menu.popoverPresentationController.sourceView=anchor;menu.popoverPresentationController.sourceRect=anchor.bounds;[self presentViewController:menu animated:YES completion:nil];
}
- (void)setDiscoveryPreference:(NSString *)key value:(id)value {
    RewindStore *s=[RewindStore shared];NSMutableDictionary *prefs=[[RWDiscoveryMetadataPolicy preferences:s.profile[@"discoveryPreferences"]]mutableCopy];prefs[key]=value;s.profile[@"discoveryPreferences"]=prefs;self.homePlan=nil;[s save];[s refreshDiscovery];[self render];
}
- (void)preferencesPage {
    RewindStore *s=[RewindStore shared];if(s.restricted){[self heading:@"Kids discovery" subtitle:@"This profile follows its age limit."];return;}__weak RewindController *weak=self;NSDictionary *p=[RWDiscoveryMetadataPolicy preferences:s.profile[@"discoveryPreferences"]];CGFloat w=[self width];
    [self heading:@"Make room for your taste." subtitle:[NSString stringWithFormat:@"Recommendations for %@. Search always includes all titles.",RWString(s.profile[@"name"])]];
    NSArray *rows=@[@[@"recommendationAudience",@"Recommendation audience",[p[@"recommendationAudience"]isEqual:@"all_ages"]?@"All ages":@"For grown-ups"],@[@"languageMode",@"Main recommendations",[p[@"languageMode"]isEqual:@"all"]?@"All languages":@"English first"],@[@"worldCinema",@"World Cinema",[p[@"worldCinema"]boolValue]?@"A separate shelf":@"Off"],@[@"excludeBollywood",@"Bollywood recommendations",[p[@"excludeBollywood"]boolValue]?@"Excluded":@"Included"]];CGFloat y=150;
    for(NSArray *row in rows){[self label:row[1] x:33 y:y width:w-330 size:18 weight:UIFontWeightSemibold color:0xf5f2eb];NSString *key=row[0];[self button:row[2] x:w-290 y:y-8 width:258 primary:NO action:^{id value=[key isEqual:@"recommendationAudience"]?([p[key]isEqual:@"all_ages"]?@"grown_up":@"all_ages"):[key isEqual:@"languageMode"]?([p[key]isEqual:@"all"]?@"english_first":@"all"):@(![p[key]boolValue]);[weak setDiscoveryPreference:key value:value];}];y+=90;}
    [self label:@"World Cinema quality" x:33 y:y width:w-330 size:18 weight:UIFontWeightSemibold color:0xf5f2eb];
    [self button:[NSString stringWithFormat:@"IMDb %.1f+",[p[@"worldMinRating"]doubleValue]] x:w-290 y:y-8 width:258 primary:NO action:^{UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"World Cinema" message:@"Titles also need enough votes for a reliable score." preferredStyle:UIAlertControllerStyleActionSheet];for(NSNumber *rating in @[@7,@7.5,@8,@8.5]) [menu addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"IMDb %.1f+",rating.doubleValue] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[weak setDiscoveryPreference:@"worldMinRating" value:rating];}]];[menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];menu.popoverPresentationController.sourceView=weak.view;menu.popoverPresentationController.sourceRect=CGRectMake(w/2,y,1,1);[weak presentViewController:menu animated:YES completion:nil];}];y+=85;
    UILabel *note=[self label:@"Likes, saved titles and meaningful viewing shape your suggestions. Short playback tests and connection failures do not. Language and industry come from verified title metadata; a country alone is never treated as a measure of quality." x:33 y:y width:w-66 size:15 weight:UIFontWeightRegular color:0xa9b3bf];note.numberOfLines=0;[note sizeToFit];self.content.contentSize=CGSizeMake(w,CGRectGetMaxY(note.frame)+50);
}
- (void)upcomingPage {
    RewindStore *s=[RewindStore shared];CGFloat w=[self width];__weak RewindController *weak=self;if(!self.upcomingMode)self.upcomingMode=@"Coming soon";
    self.upcomingScope=s.state[@"activeProfile"];
    [self label:@"Upcoming" x:32 y:12 width:240 size:32 weight:UIFontWeightBold color:0xf5f2eb];
    UISegmentedControl *tabs=[[UISegmentedControl alloc]initWithItems:@[@"Coming soon",@"Waiting",@"Following"]];tabs.frame=CGRectMake(w-454,10,422,44);tabs.tintColor=RWColor(0xff9275);tabs.selectedSegmentIndex=[@[@"Coming soon",@"Waiting",@"Following"]indexOfObject:self.upcomingMode];[tabs addTarget:self action:@selector(upcomingTabChanged:) forControlEvents:UIControlEventValueChanged];[self.content addSubview:tabs];
    UISegmentedControl *kind=[[UISegmentedControl alloc]initWithItems:@[@"Films",@"New episodes"]];kind.accessibilityIdentifier=@"UpcomingKind";kind.frame=CGRectMake(32,66,280,44);kind.tintColor=RWColor(0xb8c2d0);kind.selectedSegmentIndex=[self.upcomingKind isEqual:@"series"]?1:0;kind.hidden=![self.upcomingMode isEqual:@"Coming soon"];[kind addTarget:self action:@selector(upcomingKindChanged:) forControlEvents:UIControlEventValueChanged];[self.content addSubview:kind];
    [self label:@"Follow what’s next. Watch when it’s ready." x:340 y:76 width:w-372 size:13 weight:UIFontWeightRegular color:0x929faf];
    self.upcomingList=[[RWAvailabilityList alloc]initWithFrame:CGRectMake(0,122,w,MAX(100,self.content.bounds.size.height-122))];self.upcomingList.reviewMode=self.reviewMode;self.upcomingList.onSelect=^(NSDictionary *m){[weak showDetails:m];};
    self.upcomingList.onFollow=^(NSDictionary *m,UIView *anchor){[weak upcomingReminder:m anchor:anchor];};[self.content addSubview:self.upcomingList];self.content.scrollEnabled=NO;self.content.contentSize=self.content.bounds.size;[self updateUpcomingList];
}
- (void)upcomingReminder:(NSDictionary *)meta anchor:(UIView *)anchor {
    RewindStore *s=[RewindStore shared];if(![s allowed:meta])return;NSDictionary *policy=[RWReminderPolicy presentation:meta mode:self.upcomingMode following:[s following:meta] watching:[s watchingAvailability:meta] alerts:[s.profile[@"episodeNotifications"]boolValue]];
    if([policy[@"kind"]isEqual:@"availability"]){[s watchAvailability:meta enabled:[policy[@"enable"]boolValue]];[self updateUpcomingList];return;}
    if([policy[@"kind"]isEqual:@"episode"]){[s remindEpisodes:meta enabled:[policy[@"enable"]boolValue]];[self updateUpcomingList];return;}
    __weak RewindController *weak=self;NSString *scope=s.state[@"activeProfile"];BOOL episodeOn=[s following:meta]&&[s.profile[@"episodeNotifications"]boolValue],availabilityOn=[s watchingAvailability:meta];
    UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"Reminders" message:RWString(meta[@"name"]) preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:episodeOn?@"Turn off episode reminders":@"Enable episode reminders" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){if(![scope isEqual:s.state[@"activeProfile"]]||![s allowed:meta])return;[s remindEpisodes:meta enabled:!episodeOn];[weak updateUpcomingList];}]];
    [menu addAction:[UIAlertAction actionWithTitle:availabilityOn?@"Stop availability reminder":@"Watch for playback availability" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){if(![scope isEqual:s.state[@"activeProfile"]]||![s allowed:meta])return;[s watchAvailability:meta enabled:!availabilityOn];[weak updateUpcomingList];}]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];menu.popoverPresentationController.sourceView=anchor?:self.view;menu.popoverPresentationController.sourceRect=anchor?anchor.bounds:CGRectMake([self width]/2,200,1,1);[self presentViewController:menu animated:YES completion:nil];
}
- (void)applyUpcomingItems:(NSArray *)items {
    RewindStore *s=[RewindStore shared];
    BOOL coming=[self.upcomingMode isEqual:@"Coming soon"],episodes=[self.upcomingKind isEqual:@"series"];NSMutableArray *visible=[NSMutableArray new];for(NSDictionary *m in items)if(!coming||[m[@"type"]isEqual:episodes?@"series":@"movie"])[visible addObject:m];
    for(UIView *v in self.content.subviews)if([v.accessibilityIdentifier isEqual:@"UpcomingKind"])v.hidden=!coming;
    self.upcomingList.reminderMode=self.upcomingMode;self.upcomingList.separatesWorldCinema=coming;self.upcomingList.hasMore=coming&&episodes&&[s upcomingHasMore];self.upcomingList.scheduleDays=coming&&episodes?[s upcomingDays]:0;self.upcomingList.onMore=^{[s loadMoreUpcoming];};[self.upcomingList updateItems:visible];[self.upcomingList setLoading:s.upcomingBusy error:s.upcomingError retry:^{[[RewindStore shared]retryUpcoming];}];
    if(self.upcomingRestoreOffset&&(items.count||!s.upcomingBusy)){[self.upcomingList layoutIfNeeded];self.upcomingList.contentOffset=CGPointMake(0,MIN(self.upcomingRestoreOffset.doubleValue,MAX(0,self.upcomingList.contentSize.height-self.upcomingList.bounds.size.height)));self.upcomingRestoreOffset=nil;}
    if(visible.count){self.upcomingList.backgroundView=nil;return;}
    UILabel *empty=RWLabel(s.upcomingBusy?@"Finding upcoming releases…":[self.upcomingMode isEqual:@"Following"]?@"Choose Remind me on a movie or show to follow it.":@"Newly announced and unavailable titles will appear here.",16,UIFontWeightRegular,RWColor(0xaeb8c5));empty.numberOfLines=3;empty.textAlignment=NSTextAlignmentCenter;self.upcomingList.backgroundView=empty;
}
- (void)updateUpcomingList {
    if(![self.page isEqual:@"Upcoming"]||!self.upcomingList)return;
    if(self.upcomingPreparing){self.upcomingPrepareAgain=YES;return;}self.upcomingPreparing=YES;self.upcomingPrepareAgain=NO;
    RewindStore *s=[RewindStore shared];NSString *profile=[s.state[@"activeProfile"]copy],*mode=[self.upcomingMode copy];RWAvailabilityList *list=self.upcomingList;
    if(!list.items.count)[list setLoading:YES error:nil retry:nil];__weak RewindController *weak=self;
    [s prepareUpcomingMode:mode done:^(NSArray *items,NSString *error){RewindController *owner=weak;if(!owner)return;owner.upcomingPreparing=NO;
        BOOL current=[owner.page isEqual:@"Upcoming"]&&owner.upcomingList==list&&[owner.upcomingMode isEqual:mode]&&[profile isEqual:s.state[@"activeProfile"]];
        if(current&&!error){double began=NSProcessInfo.processInfo.systemUptime;[owner applyUpcomingItems:[s allowedItems:items]];[owner recordDiscoveryTiming:@"upcoming_prepare_apply" seconds:NSProcessInfo.processInfo.systemUptime-began];}
        if([owner.page isEqual:@"Upcoming"]&&(owner.upcomingPrepareAgain||!current||error))[owner updateUpcomingList];
    }];
}
- (void)upcomingUpdated {if([self.page isEqual:@"Upcoming"]&&self.upcomingList&&!self.reviewMode)[self updateUpcomingList];}
- (void)upcomingKindChanged:(UISegmentedControl *)tabs {self.upcomingKind=tabs.selectedSegmentIndex==1?@"series":@"movie";self.upcomingRestoreOffset=nil;[self.upcomingList updateItems:@[]];self.upcomingList.contentOffset=CGPointZero;[self updateUpcomingList];}
- (void)upcomingTabChanged:(UISegmentedControl *)tabs {self.upcomingPageOffset=0;self.upcomingRestoreOffset=nil;[self.upcomingList updateItems:@[]];self.upcomingMode=@[@"Coming soon",@"Waiting",@"Following"][tabs.selectedSegmentIndex];self.upcomingList.contentOffset=CGPointZero;[self updateUpcomingList];}
- (void)recordDiscoveryTiming:(NSString *)kind seconds:(double)seconds {
    if(self.reviewMode||!isfinite(seconds)||seconds<0)return;if(!self.discoveryTimings)self.discoveryTimings=[NSMutableArray new];
    mach_task_basic_info_data_t info={};mach_msg_type_number_t count=MACH_TASK_BASIC_INFO_COUNT;BOOL memory=task_info(mach_task_self(),MACH_TASK_BASIC_INFO,(task_info_t)&info,&count)==KERN_SUCCESS;
    NSDictionary *sample=@{@"kind":kind,@"page":self.page?:@"",@"seconds":@(seconds),@"width":@([self width]),@"posters":@(self.posters.count),@"home_view":self.homeView.diagnostics?:@{},@"feed_visible_cells":@(self.feedGrid.visibleCells.count),@"upcoming_visible_cells":@(self.upcomingList.visibleCells.count),@"profile_age":[RewindStore shared].profile[@"maxAge"]?:@(-1),@"resident_bytes":@(memory?info.resident_size:0),@"at":@(NSDate.date.timeIntervalSince1970)};[self.discoveryTimings addObject:sample];if(self.discoveryTimings.count>100)[self.discoveryTimings removeObjectAtIndex:0];
    NSMutableArray *home=[NSMutableArray new];for(NSDictionary *entry in self.discoveryTimings)if([entry[@"kind"]isEqual:@"navigation"]&&[entry[@"page"]isEqual:@"Home"])[home addObject:entry[@"seconds"]];[home sortUsingSelector:@selector(compare:)];
    [[RewindStore shared]report:@{@"discovery_ui_metrics":@{@"samples":[self.discoveryTimings copy],@"home_navigation_count":@(home.count),@"home_navigation_p95_seconds":home.count?home[(NSUInteger)ceil(home.count*.95)-1]:@(-1),@"measurement":@"Native view construction and navigation; artwork network completion is separate"}}];
}
