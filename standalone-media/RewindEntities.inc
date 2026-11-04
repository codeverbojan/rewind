#include "RewindDetailRelated.inc"
- (void)recordVisibleDiscovery {
    if(self.reviewMode||![self.page isEqual:@"Home"]||self.content.dragging||self.content.decelerating||[self.homeView isInteracting])return;NSMutableArray *visible=[[self.homeView visibleMetadata]mutableCopy]?:[NSMutableArray new];CGRect viewport=CGRectMake(0,84,[self width],self.view.bounds.size.height-84);
    NSDictionary *hero=self.homeHeaderRecord[@"hero"];UIView *header=self.homeView.tableHeaderView;if(hero.count&&header.window){CGRect frame=[header convertRect:header.bounds toView:self.view],shown=CGRectIntersection(frame,viewport);if(!CGRectIsNull(shown)&&shown.size.height>=header.bounds.size.height*.5)[visible addObject:hero];}
    for(RWPoster *p in self.posters){CGRect frame=[p convertRect:p.bounds toView:self.view],intersection=CGRectIntersection(frame,viewport);if(!CGRectIsNull(intersection)&&intersection.size.width*intersection.size.height>=frame.size.width*frame.size.height*.5)[visible addObject:p.meta];}if(visible.count)[[RewindStore shared]noteDiscoveryExposure:visible];
}
- (void)openPerson:(NSDictionary *)person {
    RewindStore *s=[RewindStore shared];NSDictionary *origin=self.detail;NSMutableDictionary *entity=[person mutableCopy];NSString *qid=[RWCast knownPersonID:person titleCredits:[s discoveryMeta:origin][@"discovery"][@"cast"]];
    entity[@"id"]=qid;entity[@"creditRole"]=@"cast";entity[@"origin"]=origin;[self openEntity:entity];
}
- (void)resetEntityFeed {
    [[RewindStore shared].discoveryMetadata cancelCredits:self.entity[@"id"] role:self.entity[@"creditRole"]];[self.entityFeed park];self.entityFocusCredits=NO;self.entityFeedPrepared=NO;self.entityCreditsAnchor=0;
    self.entityGeneration++;self.entitySelectionGeneration++;self.entityBusy=NO;self.entitySelecting=NO;self.entityFeed=nil;self.entityCursor=@{};self.entityPendingRatings=@[];self.entityEmptyPages=0;self.entityItems=@[];self.entityHighlights=@{};self.entityHighlightPool=@[];self.entityHighlightPending=@[];self.entityHighlightBusy=NO;self.entityHighlightOffsets=[NSMutableDictionary new];self.entityHighlightMode=@"knownFor";self.entityBioExpanded=NO;self.entityDetailRequested=nil;self.entityHighlightGeneration++;
}
- (void)openEntity:(NSDictionary *)entity {[self loadEntity:entity push:YES];}
- (void)loadEntity:(NSDictionary *)entity push:(BOOL)push {[self loadEntity:entity push:push preserveFilters:NO];}
- (void)loadEntity:(NSDictionary *)entity push:(BOOL)push preserveFilters:(BOOL)preserve {
    NSString *type=preserve?self.entityType:@"All",*sort=preserve?self.entitySort:@"Year";BOOL expanded=preserve&&self.entityBioExpanded;
    if(push)[self pushDestination];[self resetEntityFeed];self.entity=entity;self.entityType=type?:@"All";self.entitySort=sort?:@"Year";self.entityBioExpanded=expanded;self.entityFocusCredits=preserve;self.entityOffset=0;self.entityPageOffset=0;self.entityError=nil;self.entityMore=YES;
    NSString *folder=[NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES)[0]stringByAppendingPathComponent:@"RewindFeeds"];
    self.entityFeed=[[RWFeedStore alloc]initWithFolder:folder context:[self currentEntityScope]];self.entitySelecting=YES;[self go:@"Entity"];[self prepareEntityFeed];
}
- (void)prepareEntityFeed {
    if(!self.entityFeed||![self.page isEqual:@"Entity"])return;if(![RewindStore shared].catalogReady){self.entitySelecting=YES;[self updateEntityGrid];return;}self.entitySelecting=YES;self.entityError=nil;[self updateEntityGrid];
    RWFeedStore *feed=self.entityFeed;NSDictionary *entity=self.entity;NSUInteger generation=++self.entityGeneration;__weak RewindController *weak=self;
    [feed selectType:[self.entityType isEqual:@"All"]?nil:[self.entityType isEqual:@"Shows"]?@"series":@"movie" sort:self.entitySort done:^(NSString *error){if(generation!=weak.entityGeneration||feed!=weak.entityFeed)return;
        if(error){weak.entitySelecting=NO;weak.entityError=error;[weak updateEntityGrid];return;}
        // Seed the representative-work rail from verified retained credits too.
        // The bounded in-memory discovery pool may have forgotten this entity.
        NSUInteger cachedCount=MIN((NSUInteger)24,feed.count);
        // Publish retained records before waiting for local enrichment or the network.
        if(cachedCount)[weak updateEntityGrid];
        if(cachedCount)[feed loadRange:NSMakeRange(0,cachedCount) done:^(NSString *readError){if(readError||feed!=weak.entityFeed||![weak.page isEqual:@"Entity"])return;NSMutableArray *cached=[NSMutableArray new];for(NSUInteger i=0;i<cachedCount;i++){NSDictionary *m=[feed cachedItem:i];if(m)[cached addObject:m];}[weak acceptEntityHighlights:cached];}];
        [[RewindStore shared]localCreditsForEntity:entity done:^(NSArray *items){if(generation!=weak.entityGeneration||feed!=weak.entityFeed)return;
            [feed append:items done:^(NSUInteger added,NSString *error){if(generation!=weak.entityGeneration||feed!=weak.entityFeed)return;weak.entitySelecting=NO;weak.entityFeedPrepared=!error.length;weak.entityError=error;[weak acceptEntityHighlights:items];[weak updateEntityGrid];if(!error)[weak loadEntityCredits];}];
        }];
    }];
}
- (void)updateEntityGrid {
    if(![self.page isEqual:@"Entity"]||!self.feedGrid)return;
    self.feedGrid.emptyMessage=[RewindStore shared].restricted?@"No matching credits within this profile’s age limit.":[NSString stringWithFormat:@"No %@ found for this view.",[[RWEntityCreditPolicy heading:self.entity[@"creditRole"]]lowercaseString]];
    if(self.reviewMode){NSMutableArray *items=[NSMutableArray new];for(NSDictionary *m in [[RewindStore shared]allowedItems:self.entityItems])if([self.entityType isEqual:@"All"]||[m[@"type"]isEqual:[self.entityType isEqual:@"Shows"]?@"series":@"movie"])[items addObject:m];[self.feedGrid updateItems:[RWDiscoveryCatalog sortCredits:items byRating:[self.entitySort isEqual:@"Rating"]] loading:NO more:NO error:nil cursor:0 automatic:NO];return;}
    if(self.entityFeed)[self.feedGrid updateFeed:self.entityFeed loading:self.entityBusy||self.entitySelecting more:self.entityMore error:self.entityError cursor:[self.entityCursor[@"sroffset"]unsignedIntegerValue] automatic:self.entityEmptyPages<3];
    [[RewindStore shared]report:@{@"entity_loading":@{@"id":RWID(self.entity),@"role":self.entity[@"creditRole"]?:@"",@"type":self.entityType?:@"All",@"busy":@(self.entityBusy),@"selecting":@(self.entitySelecting),@"count":@(self.entityFeed.count),@"more":@(self.entityMore),@"error":self.entityError?:@"",@"metadata":[RewindStore shared].discoveryMetadata.diagnostics?:@{},@"at":@(NSDate.date.timeIntervalSince1970)}}];
    if(self.entityFocusCredits&&!self.entitySelecting){self.entityFocusCredits=NO;[self.feedGrid layoutIfNeeded];self.feedGrid.contentOffset=CGPointMake(0,MIN(self.entityCreditsAnchor,MAX(0,self.feedGrid.contentSize.height-self.feedGrid.bounds.size.height)));}
}
- (void)selectEntityCredits {
    if(self.reviewMode){[self updateEntityGrid];return;}if(!self.entityFeedPrepared){[self prepareEntityFeed];return;}NSUInteger generation=++self.entitySelectionGeneration;self.entitySelecting=YES;self.entityEmptyPages=0;self.entityError=nil;self.feedGrid.contentOffset=CGPointMake(0,MAX(0,self.feedGrid.headerView.bounds.size.height-130));[self updateEntityGrid];RWFeedStore *feed=self.entityFeed;__weak RewindController *weak=self;
    [feed selectType:[self.entityType isEqual:@"All"]?nil:[self.entityType isEqual:@"Shows"]?@"series":@"movie" sort:self.entitySort done:^(NSString *error){if(generation!=weak.entitySelectionGeneration||feed!=weak.entityFeed)return;weak.entitySelecting=NO;weak.entityError=error;[weak updateEntityGrid];}];
}
- (NSArray *)localEntityCredits:(NSDictionary *)entity {
    NSString *field=[RWEntityCreditPolicy field:entity[@"creditRole"]];NSMutableArray *out=[NSMutableArray new];if(!field||!RWString(entity[@"id"]).length)return out;
    RewindStore *s=[RewindStore shared];for(NSDictionary *raw in [s discoveryPool]){NSDictionary *m=[s discoveryMeta:raw];for(NSDictionary *ref in m[@"discovery"][field])if([ref[@"id"]isEqual:entity[@"id"]]){[out addObject:m];break;}}return out;
}
- (void)loadEntityCredits {
    if(self.entityBusy||self.entitySelecting||self.reviewMode||!self.entityFeed||![self.page isEqual:@"Entity"]||(!self.entityMore&&!self.entityError.length))return;
    if(!self.entityFeedPrepared){[self prepareEntityFeed];return;}self.entityBusy=YES;self.entityError=nil;NSUInteger generation=++self.entityGeneration;RewindStore *s=[RewindStore shared];NSString *profile=s.state[@"activeProfile"];RWFeedStore *feed=self.entityFeed;__weak RewindController *weak=self;[self syncDiscoveryActivity];[self updateEntityGrid];
    if(!RWString(self.entity[@"id"]).length){
        void(^resolved)(NSDictionary *,NSString *)=^(NSDictionary *record,NSString *error){
            if(generation!=weak.entityGeneration||feed!=weak.entityFeed||![weak.page isEqual:@"Entity"]||![profile isEqual:s.state[@"activeProfile"]])return;
            weak.entityBusy=NO;NSString *qid=RWString(record[@"id"]);
            if([qid rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location==0){NSMutableDictionary *entity=[weak.entity mutableCopy];entity[@"id"]=qid;entity[@"type"]=@"person";
                // Recreate the feed/header with the canonical scope, rather than
                // appending into the shared empty-ID feed from the loading page.
                [weak loadEntity:entity push:NO preserveFilters:YES];weak.entityFocusCredits=NO;
            }else{weak.entityError=error?:@"Verified filmography is not available for this person yet.";weak.entityMore=NO;[weak updateEntityGrid];}
        };
        NSDictionary *origin=self.entity[@"origin"],*person=self.entity;
        void(^titleFallback)(NSString *)=^(NSString *identityError){
            if(generation!=weak.entityGeneration||feed!=weak.entityFeed||![weak.page isEqual:@"Entity"]||![profile isEqual:s.state[@"activeProfile"]])return;
            if(!origin){resolved(nil,identityError?:@"No verified credits identity is available yet.");return;}
            [s.discoveryMetadata resolve:origin done:^(NSDictionary *record,NSString *error){NSString *qid=[RWCast knownPersonID:person titleCredits:record[@"cast"]];resolved(qid.length?@{@"id":qid}:nil,error?:identityError);}];
        };
        if([RWCast personReference:person])[s.discoveryMetadata resolvePerson:person done:^(NSDictionary *record,NSString *error){if(record)resolved(record,nil);else titleFallback(error);}];else titleFallback(nil);
        return;
    }
    [self requestEntityDetails];
    [s.discoveryMetadata creditPage:self.entity[@"id"] role:self.entity[@"creditRole"] continuation:self.entityCursor done:^(NSArray *items,NSDictionary *next,NSString *error){if(generation!=weak.entityGeneration||![weak.page isEqual:@"Entity"]||![profile isEqual:s.state[@"activeProfile"]])return;
        if(error){weak.entityBusy=NO;weak.entityError=error;[weak updateEntityGrid];return;}[s.ratings resolve:items];[s acceptDiscoveryCandidates:items];
        if(s.restricted){NSMutableArray *pending=[weak.entityPendingRatings mutableCopy]?:[NSMutableArray new];for(NSDictionary *m in items)if(![s allowed:m])[pending addObject:m];if(pending.count>64)[pending removeObjectsInRange:NSMakeRange(0,pending.count-64)];weak.entityPendingRatings=pending;}
        [s enrichDiscoveryItems:items done:^(NSArray *enriched){if(generation!=weak.entityGeneration||feed!=weak.entityFeed||![profile isEqual:s.state[@"activeProfile"]])return;
            [feed append:enriched done:^(NSUInteger added,NSString *writeError){if(generation!=weak.entityGeneration||feed!=weak.entityFeed||![profile isEqual:s.state[@"activeProfile"]])return;weak.entityBusy=NO;weak.entityError=writeError;
                if(!writeError){weak.entityCursor=next;weak.entityOffset=[next[@"sroffset"]unsignedIntegerValue];weak.entityMore=next.count>0;weak.entityEmptyPages=added?0:weak.entityEmptyPages+1;[weak acceptEntityHighlights:enriched];}[weak updateEntityGrid];[weak appendNewlyRatedEntity];[s report:@{@"entity_feed":feed.diagnostics}];
            }];
        }];
    }];
}
- (void)appendNewlyRatedEntity {
    if(self.entityBusy||self.entitySelecting||!self.entityFeedPrepared||!self.entityFeed||!self.entityPendingRatings.count||![self.page isEqual:@"Entity"])return;RewindStore *s=[RewindStore shared];NSArray *allowed=[s allowedItems:self.entityPendingRatings];if(!allowed.count)return;
    RWFeedStore *feed=self.entityFeed;NSUInteger generation=self.entityGeneration;self.entityBusy=YES;__weak RewindController *weak=self;
    [s enrichDiscoveryItems:allowed done:^(NSArray *items){if(generation!=weak.entityGeneration||feed!=weak.entityFeed)return;[feed append:items done:^(NSUInteger added,NSString *error){if(generation!=weak.entityGeneration||feed!=weak.entityFeed)return;weak.entityBusy=NO;weak.entityError=error;if(!error){NSMutableArray *pending=[weak.entityPendingRatings mutableCopy];[pending removeObjectsInArray:allowed];weak.entityPendingRatings=pending;[weak acceptEntityHighlights:items];}[weak updateEntityGrid];}];}];
}
#include "RewindEntityHeader.inc"
- (CGFloat)creativeCredits:(NSDictionary *)meta y:(CGFloat)y {
    RewindStore *store=[RewindStore shared];NSDictionary *record=[store discoveryMeta:meta][@"discovery"];CGFloat w=[self width];__weak RewindController *weak=self;
    for(NSArray *pair in @[@[@"directors",@"Directed by",@"director"],@[@"studios",@"Production companies",@"studio"]]){
        NSMutableArray *cards=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
        for(NSDictionary *ref in record[pair[0]]){NSString *identifier=RWID(ref);if(!RWString(ref[@"name"]).length||[identifier rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location!=0||[seen containsObject:identifier])continue;[seen addObject:identifier];
            NSMutableDictionary *entity=[ref mutableCopy];entity[@"type"]=[pair[2]isEqual:@"studio"]?@"studio":@"person";entity[@"creditRole"]=pair[2];entity[@"roles"]=@[pair[2]];entity[@"profileID"]=store.state[@"activeProfile"];entity[@"verifiedEntity"]=@YES;
            entity[@"knownFor"]=@[@{@"id":RWID(meta),@"type":meta[@"type"]?:@"movie",@"name":RWString(meta[@"name"])}];[cards addObject:entity];if(cards.count==12)break;
        }if(!cards.count)continue;
        [self label:pair[1] x:33 y:y width:w-66 size:23 weight:UIFontWeightSemibold color:0xf5f2eb];y+=44;
        RWPosterCollection *rail=[[RWPosterCollection alloc]initWithFrame:CGRectMake(0,y,w,116)];rail.horizontal=YES;rail.entityCards=YES;rail.compactEntityCards=YES;rail.reviewMode=self.reviewMode;
        NSString *key=[NSString stringWithFormat:@"RWcredits:%@:%@:%@",store.state[@"activeProfile"],RWID(meta),pair[2]];rail.accessibilityIdentifier=key;NSNumber *saved=self.railOffsets[key];
        rail.onSelect=^(NSDictionary *entity){[weak openEntity:entity];};rail.onScroll=^(CGPoint offset){if(!weak||weak.reviewMode)return;if(!weak.railOffsets)weak.railOffsets=[NSMutableDictionary new];if(weak.railOffsets.count>=128&&!weak.railOffsets[key])[weak.railOffsets removeObjectForKey:weak.railOffsets.allKeys.firstObject];weak.railOffsets[key]=@(offset.x);};
        rail.onScrollSettled=^{[weak applyPendingDetails];};[self.content addSubview:rail];[self.posterRails addObject:rail];[rail updateItems:cards loading:NO more:NO error:nil cursor:0 automatic:NO];[rail layoutIfNeeded];if(saved)rail.contentOffset=CGPointMake(MAX(0,MIN(saved.doubleValue,MAX(0,rail.contentSize.width-w))),0);y+=136;
    }return y;
}
#include "RewindEntitySearch.inc"
- (void)exploreTypeChanged:(UISegmentedControl *)control {
    self.exploreType=control.selectedSegmentIndex?@"Shows":@"Films";if(self.exploreBusy){[self.searchTimer invalidate];[self fetchExplore];return;}RWFeedStore *feed=self.exploreFeed;if(!feed)return;NSUInteger generation=++self.exploreGeneration;self.exploreBusy=YES;self.exploreError=nil;self.feedGrid.contentOffset=CGPointZero;[self updateExploreGrid];__weak RewindController *weak=self;
    [feed selectType:control.selectedSegmentIndex?@"series":@"movie" sort:nil done:^(NSString *error){if(generation!=weak.exploreGeneration||feed!=weak.exploreFeed)return;weak.exploreBusy=NO;weak.exploreError=error;[weak updateExploreGrid];}];
}
- (void)explorePage {
    CGFloat w=[self width];__weak RewindController *weak=self;RWButton *back=[self button:@"Back" x:24 y:0 width:100 primary:NO action:^{[weak destinationBack];}];[back icon:@"arrow-left"];back.backgroundColor=UIColor.clearColor;back.layer.borderWidth=0;
    [self label:self.exploreMood.length?self.exploreMood:self.exploreKind x:32 y:64 width:w-64 size:34 weight:UIFontWeightBold color:0xf5f2eb];
    [self label:self.exploreMood.length?[RWExploreIndex moodDescription:self.exploreMood]:[self.exploreKind isEqual:@"Moods"]?@"Find the feeling for your next watch.":[self.exploreKind isEqual:@"Studios"]?@"Discover the companies behind well-rated films and shows.":@"Discover the people behind well-rated films and shows." x:33 y:116 width:w-66 size:14 weight:UIFontWeightRegular color:0xa9b4c2];
    self.exploreScope=[self currentExploreScope];self.exploreSearch=[[UISearchBar alloc]initWithFrame:CGRectMake(24,151,w-48,52)];self.exploreSearch.searchBarStyle=UISearchBarStyleMinimal;self.exploreSearch.barStyle=UIBarStyleBlack;self.exploreSearch.tintColor=RWColor(0xff997e);self.exploreSearch.delegate=self;self.exploreSearch.placeholder=self.exploreMood.length?@"Find a title in this mood":[NSString stringWithFormat:@"Find %@",[self.exploreKind lowercaseString]];self.exploreSearch.text=self.exploreQuery;[self.content addSubview:self.exploreSearch];
    CGFloat top=255;if(self.exploreMood.length){UISegmentedControl *types=[[UISegmentedControl alloc]initWithItems:@[@"Films",@"Shows"]];types.selectedSegmentIndex=[self.exploreType isEqual:@"Shows"]?1:0;types.tintColor=RWColor(0xff997e);types.frame=CGRectMake(32,215,220,44);[types addTarget:self action:@selector(exploreTypeChanged:) forControlEvents:UIControlEventValueChanged];[self.content addSubview:types];top=311;}
    self.exploreMessage=[self label:@"" x:33 y:top-35 width:w-66 size:12 weight:UIFontWeightRegular color:0x929faf];
    self.feedGrid=[[RWPosterCollection alloc]initWithFrame:CGRectMake(0,top,w,MAX(100,self.content.bounds.size.height-top))];self.feedGrid.entityCards=!self.exploreMood.length;self.feedGrid.reviewMode=self.reviewMode;
    self.feedGrid.onSelect=^(NSDictionary *record){if([record[@"type"]isEqual:@"mood"]){[weak pushDestination];[weak resetExplore];weak.exploreKind=@"Moods";weak.exploreMood=record[@"name"];[weak go:@"Explore"];[weak fetchExplore];}else if([@[@"person",@"studio"]containsObject:record[@"type"]])[weak openEntity:record];else [weak showDetails:record];};
    self.feedGrid.onLoadMore=^(BOOL manual){if(weak.exploreRemoteStarted){weak.exploreEmptyPages=0;[weak loadExploreRemote];}else [weak fetchExplore];};[self.content addSubview:self.feedGrid];self.content.scrollEnabled=NO;self.content.contentSize=self.content.bounds.size;[self updateExploreGrid];
}
