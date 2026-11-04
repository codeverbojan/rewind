// Disposable profiles, never real user history or ratings. The boundaries
// recipe uses marked non-media files; kids-playback uses the real Sintel film.
- (BOOL)exerciseKidsFilmStep:(NSString *)kind {
    RewindStore *s=RewindStore.shared;NSString *key=@"tt1727587",*run=self.exerciseRequest[@"run"];NSInteger build=[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue];
    if(![self.exerciseRequest[@"action"]isEqual:@"kids-playback"])return NO;
    if([kind isEqual:@"kids-film-prepare"]){
        if(s.state[@"profiles"][@"rw-device-kids-0"]||s.state[@"profiles"][@"rw-device-kids-12"]||[s.state[@"profiles"]count]>4)return NO;
        NSDictionary *movie=nil;for(NSDictionary *m in s.familyCatalog)if([RWID(m)isEqual:key]){movie=m;break;}
        NSDictionary *rating=[s.ratings rating:key];if(!movie||![rating[@"label"]isEqual:@"PG"]||[rating[@"minimumAge"]integerValue]!=10)return NO;
        self.exerciseKidsMetas=@[movie];self.exerciseResumeRecord=nil;self.exerciseKidsReport=nil;
        for(NSNumber *age in @[@0,@12]){NSMutableDictionary *p=[RWProfiles make:@"Device Kids check" age:age.integerValue];p[@"autoplayTrailers"]=@NO;
            p[@"sources"][@"rw:kids-owner"]=@{@"protocol":@1,@"build":@(build),@"original":s.state[@"activeProfile"],@"run":run,@"age":age};
            s.state[@"profiles"][[NSString stringWithFormat:@"rw-device-kids-%@",age]]=p;
        }[s save];return YES;
    }
    if(![RWDeviceExercise ownsKidsProfile:s.profile build:build run:run]||self.exerciseKidsMetas.count!=1)return NO;
    NSDictionary *movie=self.exerciseKidsMetas.firstObject,*player=[self.exercisePlayer deviceExerciseSnapshot],*record=[s record:key];
    if([kind isEqual:@"kids-film-denied"]){
        if(![s.profile[@"maxAge"]isEqual:@0]||[s allowed:movie])return NO;
        NSUInteger generation=self.sourceGeneration;[self chooseSources:movie videoID:key restart:NO];
        BOOL ok=!self.presentedViewController&&generation==self.sourceGeneration&&![s.profile[@"history"]count]&&![s.profile[@"saved"]count];
        self.exerciseKidsReport=@{@"kind":kind,@"passed":@(ok),@"age":@0,@"no_player":@(!self.presentedViewController),@"empty_history":@(![s.profile[@"history"]count]),@"generation_unchanged":@(generation==self.sourceGeneration)};return ok;
    }
    if(![s.profile[@"maxAge"]isEqual:@12]||![s allowed:movie])return NO;
    if([kind isEqual:@"kids-film-details"]){if(self.presentedViewController)return NO;[self showDetails:movie];return [self.page isEqual:@"Details"]&&[RWID(self.detail)isEqual:key];}
    if([kind isEqual:@"kids-film-play"]){
        if(![RWID(self.detail)isEqual:key])return NO;
        NSString *label=self.exerciseResumeRecord?@"Resume":@"Play";
        NSMutableArray *queue=[NSMutableArray arrayWithObject:self.content];BOOL pressed=NO;
        while(queue.count){UIView *view=queue.lastObject;[queue removeLastObject];if([view isKindOfClass:RWButton.class]&&[[(RWButton *)view currentTitle]isEqual:label]){[(RWButton *)view sendActionsForControlEvents:UIControlEventTouchUpInside];pressed=YES;break;}[queue addObjectsFromArray:view.subviews];}
        self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;
        return pressed&&self.exercisePlayer&&self.presentedViewController==self.exercisePlayer&&![[self.exercisePlayer deviceExerciseSnapshot][@"transient"]boolValue];
    }
    if([kind isEqual:@"kids-film-await"]){
        if(!self.exercisePlayer||[player[@"exhausted"]boolValue]||NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>65)return NO;
        double target=self.exerciseResumeRecord?[self.exerciseResumeRecord[@"position"]doubleValue]+5:18;
        if(![player[@"media_verified"]boolValue]||![player[@"frame_visible"]boolValue]||[player[@"position"]doubleValue]<target)self.exerciseIndex--;return YES;
    }
    if([kind isEqual:@"kids-film-audit"]){
        BOOL resumed=self.exerciseResumeRecord!=nil;
        NSDictionary *source=record[@"source"];BOOL realFilm=[source[@"infoHash"]isEqual:@"08ada5a7a6183aae1e09d831df6748d566095a10"]||(!source[@"infoHash"]&&[source[@"url"]isEqual:@"https://webtorrent.io/torrents/Sintel/Sintel.mp4"]);
        BOOL ok=![player[@"transient"]boolValue]&&[player[@"persistence_profile"]isEqual:@"rw-device-kids-12"]&&[player[@"video_id"]isEqual:key]&&![player[@"wants_play"]boolValue]&&[player[@"media_verified"]boolValue]&&[player[@"frame_visible"]boolValue]&&[player[@"audio_track_count"]integerValue]>0&&fabs([player[@"position"]doubleValue]-self.exercisePausedPosition)<.3&&fabs([record[@"position"]doubleValue]-[player[@"position"]doubleValue])<.4&&realFilm&&[player[@"duration"]doubleValue]>880&&[player[@"duration"]doubleValue]<900;
        if(resumed)ok=ok&&fabs([player[@"requested_position"]doubleValue]-[self.exerciseResumeRecord[@"position"]doubleValue])<.01;
        NSString *name=resumed?@"device-exercise-kids-film-resumed":@"device-exercise-kids-film-initial";RWCapture(self.exercisePlayer.view,name);
        self.exerciseKidsReport=@{@"kind":kind,@"passed":@(ok),@"age":@12,@"resumed":@(resumed),@"record":record?:@{},@"player":player?:@{},@"rating":[s.ratings rating:key]?:@{},@"capture":[name stringByAppendingString:@".png"]};return ok;
    }
    if([kind isEqual:@"kids-film-record"]){
        BOOL ok=[player[@"closing"]boolValue]&&!self.presentedViewController&&[record[@"position"]doubleValue]>self.exercisePausedPosition+1&&[record[@"watchSeconds"]doubleValue]>0;
        self.exerciseResumeRecord=record;self.exerciseKidsReport=@{@"kind":kind,@"passed":@(ok),@"age":@12,@"record":record?:@{}};return ok;
    }return NO;
}
- (NSString *)exerciseKidsHash:(NSUInteger)index {
    return [[NSString stringWithFormat:@"d117000%lu",(unsigned long)index]stringByAppendingString:[[self.exerciseRequest[@"run"]stringByReplacingOccurrencesOfString:@"-" withString:@""]lowercaseString]];
}
- (NSArray *)exerciseKidsTitleAudit:(NSArray *)metas {
    RewindStore *s=RewindStore.shared;NSMutableArray *out=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(NSDictionary *m in metas){NSString *key=RWID(m);if(!key.length||[seen containsObject:key])continue;[seen addObject:key];NSDictionary *rating=[s.ratings rating:key];
        [out addObject:@{@"id":key,@"name":RWString(m[@"name"]),@"allowed":@([s allowed:m]),@"minimum_age":rating[@"minimumAge"]?:@(-1)}];}
    return out;
}
- (BOOL)exerciseKidsPublish:(NSString *)kind titles:(NSArray *)metas expected:(NSInteger)expected {
    RewindStore *s=RewindStore.shared;NSArray *titles=[self exerciseKidsTitleAudit:metas];BOOL ok=titles.count>0;
    if(expected>=0)ok=titles.count==(NSUInteger)expected;
    for(NSDictionary *entry in titles)if(![entry[@"allowed"]boolValue]||[entry[@"minimum_age"]integerValue]<0||[entry[@"minimum_age"]integerValue]>[s.profile[@"maxAge"]integerValue])ok=NO;
    NSMutableDictionary *report=[@{@"kind":kind,@"profile":s.state[@"activeProfile"],@"age":s.profile[@"maxAge"],@"page":self.page?:@"",@"titles":titles,@"passed":@(ok),@"entity_id":RWID(self.entity),@"remote_entity_search":@(self.exploreRemoteStarted)}mutableCopy];
    NSString *capture=[NSString stringWithFormat:@"device-exercise-%@-%@-%@",kind,s.profile[@"maxAge"],self.exerciseKidsKind?:@"library"];
    report[@"capture"]=[capture stringByAppendingString:@".png"];self.exerciseKidsReport=report;RWCapture(self.view,capture);return ok;
}
- (BOOL)exerciseKidsStep:(NSString *)kind {
    if([kind hasPrefix:@"kids-film-"])return [self exerciseKidsFilmStep:kind];
    RewindStore *s=RewindStore.shared;NSFileManager *fm=NSFileManager.defaultManager;NSInteger build=[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue];NSString *run=self.exerciseRequest[@"run"];
    if([kind isEqual:@"kids-prepare"]){
        self.exerciseKidsReport=nil;
        if(s.state[@"profiles"][@"rw-device-kids-0"]||s.state[@"profiles"][@"rw-device-kids-12"]||[s.state[@"profiles"]count]>4)return NO;
        NSMutableArray *metas=[NSMutableArray new];for(NSString *identifier in @[@"tt0114709",@"tt0126029"]){NSDictionary *found=nil;for(NSDictionary *m in s.familyCatalog)if([RWID(m)isEqual:identifier]){found=m;break;}if(!found)return NO;[metas addObject:found];}
        if([[s.ratings rating:@"tt0114709"][@"minimumAge"]integerValue]!=0||[[s.ratings rating:@"tt0126029"][@"minimumAge"]integerValue]!=10)return NO;
        [metas addObject:@{@"id":@"rw:kids-unrated",@"name":@"Unrated boundary fixture",@"type":@"movie",@"genres":@[@"Family"]}];self.exerciseKidsMetas=metas;
        NSString *original=s.state[@"activeProfile"],*root=[RWDocuments()stringByAppendingPathComponent:@"Torrents"];
        for(NSUInteger i=0;i<metas.count;i++)if([fm fileExistsAtPath:[root stringByAppendingPathComponent:[self exerciseKidsHash:i]]])return NO;
        for(NSNumber *age in @[@0,@12]){NSMutableDictionary *p=[RWProfiles make:@"Device Kids check" age:age.integerValue];p[@"autoplayTrailers"]=@NO;p[@"saved"]=[metas mutableCopy];
            p[@"sources"][@"rw:kids-owner"]=@{@"protocol":@1,@"build":@(build),@"original":original,@"run":run,@"age":age};
            for(NSUInteger i=0;i<metas.count;i++){NSDictionary *m=metas[i];NSString *hash=[self exerciseKidsHash:i];p[@"history"][RWID(m)]=@{@"videoID":RWID(m),@"meta":m,@"position":@(20+i*10),@"duration":@600,@"updated":@(NSDate.date.timeIntervalSince1970),@"source":@{@"infoHash":hash,@"url":[@"magnet:?xt=urn:btih:" stringByAppendingString:hash],@"fileIdx":@0,@"downloadBytes":@4}};}
            s.state[@"profiles"][[NSString stringWithFormat:@"rw-device-kids-%@",age]]=p;
        }
        for(NSUInteger i=0;i<metas.count;i++){NSString *hash=[self exerciseKidsHash:i],*path=[root stringByAppendingPathComponent:hash];NSDictionary *owner=@{@"run":run,@"build":@(build),@"hash":hash};
            if(![fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]||![owner writeToFile:[path stringByAppendingPathComponent:@"rewind-kids-owner.plist"] atomically:YES]||![[NSData dataWithBytes:"test" length:4]writeToFile:[path stringByAppendingPathComponent:@"fixture.bin"] atomically:YES])return NO;
        }[s save];return YES;
    }
    if([kind hasPrefix:@"kids-select-"]){NSString *key=[@"rw-device-kids-" stringByAppendingString:[kind substringFromIndex:12]];
        if(![RWDeviceExercise ownsKidsProfile:s.state[@"profiles"][key] build:build run:run])return NO;
        self.exerciseProfile=key;self.exerciseKidsKind=nil;[self selectProfile:key];return [s.state[@"activeProfile"]isEqual:key];
    }
    if(![RWDeviceExercise ownsKidsProfile:s.profile build:build run:run])return NO;
    NSInteger expected=[s.profile[@"maxAge"]integerValue]==0?1:2;
    if([kind isEqual:@"kids-list"])return [self exercisePressNavigation:@"My List"];
    if([kind isEqual:@"kids-downloads"]){self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;[self go:@"Downloads"];return YES;}
    if([kind isEqual:@"kids-await-downloads"]){if(NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>20)return NO;if(self.downloadsBusy||[self.downloadsSnapshot[@"items"]count]!=(NSUInteger)expected)self.exerciseIndex--;return YES;}
    if([kind isEqual:@"kids-search-title"]||[kind isEqual:@"kids-search-clear"]){
        [self exercisePressNavigation:@"Search"];self.search.text=[kind isEqual:@"kids-search-title"]?@"Shrek":@"";[self searchBar:self.search textDidChange:self.search.text];self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;return [self.page isEqual:@"Search"];
    }
    if([kind isEqual:@"kids-audit-home"]){NSMutableArray *titles=[[self.homeView visibleMetadata]mutableCopy]?:[NSMutableArray new];NSDictionary *hero=self.homeHeaderRecord[@"hero"];if(hero)[titles addObject:hero];return [self.page isEqual:@"Home"]&&[self exerciseKidsPublish:kind titles:titles expected:-1];}
    if([kind isEqual:@"kids-audit-list"]){NSMutableArray *titles=[NSMutableArray new];for(RWPoster *poster in [self exerciseVisiblePosters])if(poster.meta)[titles addObject:poster.meta];return [self.page isEqual:@"My List"]&&[self exerciseKidsPublish:kind titles:titles expected:expected];}
    if([kind isEqual:@"kids-audit-downloads"]){NSMutableArray *titles=[NSMutableArray new];for(NSDictionary *item in self.downloadsSnapshot[@"items"]){if([item[@"offlineVerified"]boolValue])return NO;[titles addObject:item[@"meta"]];}return [self exerciseKidsPublish:kind titles:titles expected:expected];}
    if([kind isEqual:@"kids-audit-search"]){BOOL shrek=NO;for(NSDictionary *m in self.feedGrid.items)if([RWID(m)isEqual:@"tt0126029"])shrek=YES;BOOL wanted=expected==2;
        if(wanted&&!shrek&&NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted<15){self.exerciseIndex--;return YES;}
        BOOL ok=[self exerciseKidsPublish:kind titles:self.feedGrid.items expected:wanted?-1:0];return ok&&shrek==wanted;
    }
    if([kind isEqual:@"kids-denied-actions"]){
        NSArray *denied=expected==1?@[self.exerciseKidsMetas[1],self.exerciseKidsMetas[2]]:@[self.exerciseKidsMetas[2]];NSArray *saved=[s.profile[@"saved"]copy];NSDictionary *history=[s.profile[@"history"]copy];NSUInteger sources=self.sourceGeneration;
        for(NSDictionary *m in denied){if([s allowed:m])return NO;[self chooseSources:m videoID:RWID(m) restart:YES];[self play:m videoID:RWID(m) source:@{@"url":@"asset:subtitle-check.mp4"} resume:0];[s toggleSaved:m];}
        if([self.presentedViewController isKindOfClass:RewindPlayer.class]){self.exercisePlayer=(RewindPlayer *)self.presentedViewController;[self.exercisePlayer beginDeviceExercise];}
        BOOL ok=!self.presentedViewController&&self.sourceGeneration==sources&&[saved isEqual:s.profile[@"saved"]]&&[history isEqual:s.profile[@"history"]];
        self.exerciseKidsReport=@{@"kind":kind,@"age":s.profile[@"maxAge"],@"denied_count":@(denied.count),@"no_player":@(!self.presentedViewController),@"source_generation_unchanged":@(self.sourceGeneration==sources),@"profile_choices_unchanged":@(ok),@"passed":@(ok)};return ok;
    }
    if([kind hasPrefix:@"kids-explore-"]){self.exerciseKidsKind=[kind substringFromIndex:13];self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;return [self exerciseDiscoveryButton:self.exerciseKidsKind]&&[self.page isEqual:@"Explore"];}
    if([kind isEqual:@"kids-await-explore"]||[kind isEqual:@"kids-await-destination"]){
        BOOL entity=[kind isEqual:@"kids-await-destination"]&&![self.exerciseKidsKind isEqual:@"Moods"];
        BOOL ready=entity?self.entityFeed.count>0&&!self.entitySelecting:[self exerciseDiscoveryCards].count>0&&!self.exploreBusy;
        if(!ready){if(NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>25)return NO;self.exerciseIndex--;}return YES;
    }
    if([kind isEqual:@"kids-open-explore"]){RWPoster *card=[self exerciseDiscoveryCards].firstObject;if(!card)return NO;self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;[card sendActionsForControlEvents:UIControlEventTouchUpInside];return [self.page isEqual:[self.exerciseKidsKind isEqual:@"Moods"]?@"Explore":@"Entity"];}
    if([kind isEqual:@"kids-audit-explore"]||[kind isEqual:@"kids-audit-destination"]){
        NSMutableArray *titles=[NSMutableArray new];BOOL entities=[kind isEqual:@"kids-audit-explore"];
        if(entities){for(RWPoster *card in [self exerciseDiscoveryCards]){if(![card.meta[@"profileID"]isEqual:s.state[@"activeProfile"]]||![card.meta[@"knownFor"]count])return NO;[titles addObjectsFromArray:card.meta[@"knownFor"]];}}
        else if([self.page isEqual:@"Entity"]){if(![self.entityFeed.context isEqual:[self currentEntityScope]])return NO;for(NSString *field in @[@"knownFor",@"recent",@"rated"])[titles addObjectsFromArray:self.entityHighlights[field]?:@[]];[titles addObjectsFromArray:[self.feedGrid visibleMetadata]];}
        else [titles addObjectsFromArray:[self.feedGrid visibleMetadata]];
        return !self.exploreRemoteStarted&&[self exerciseKidsPublish:kind titles:titles expected:-1];
    }
    return NO;
}
- (void)finishKidsExercise {
    if(![@[@"kids-boundaries",@"kids-playback",@"kids-surfaces"]containsObject:self.exerciseRequest[@"action"]])return;
    RewindStore *s=RewindStore.shared;NSString *run=self.exerciseRequest[@"run"];NSInteger build=[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue];NSFileManager *fm=NSFileManager.defaultManager;
    for(NSString *key in @[@"rw-device-kids-0",@"rw-device-kids-12"]){NSDictionary *profile=s.state[@"profiles"][key];if(![RWDeviceExercise ownsKidsProfile:profile build:build run:run])continue;NSString *original=profile[@"sources"][@"rw:kids-owner"][@"original"];
        if([s.state[@"activeProfile"]isEqual:key]&&s.state[@"profiles"][original]){self.exerciseProfile=original;[self selectProfile:original];}
        if(![s.state[@"activeProfile"]isEqual:key])[s.state[@"profiles"]removeObjectForKey:key];
    }
    for(NSUInteger i=0;i<3;i++){NSString *hash=[self exerciseKidsHash:i],*path=[[RWDocuments()stringByAppendingPathComponent:@"Torrents"]stringByAppendingPathComponent:hash];NSDictionary *marker=[NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"rewind-kids-owner.plist"]];
        if([marker isEqual:@{@"run":run,@"build":@(build),@"hash":hash}])[fm removeItemAtPath:path error:nil];
    }[s save];self.exerciseKidsMetas=nil;self.exerciseKidsKind=nil;
}
