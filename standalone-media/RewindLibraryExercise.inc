// Larger owned library through normal saved/download inventory and UIKit paths.
// Four-byte files test listing only; no fake offline certificates or playback.
- (NSString *)exerciseLibraryHash:(NSUInteger)index {return [[NSString stringWithFormat:@"%08lx",(unsigned long)(0xf4000000+index)]stringByAppendingString:[[self.exerciseRequest[@"run"]stringByReplacingOccurrencesOfString:@"-" withString:@""]lowercaseString]];}
- (NSDictionary *)exerciseLibrarySnapshot {
    RewindStore *s=RewindStore.shared;NSMutableArray *images=[NSMutableArray new];NSMutableDictionary *ages=[NSMutableDictionary new];for(NSDictionary *m in self.exerciseLibraryMetas){NSNumber *age=[s.ratings rating:RWID(m)][@"minimumAge"];if(age)ages[RWID(m)]=age;}
    double targetDelta=0;BOOL targetFound=NO;for(NSUInteger i=0;i<self.feedGrid.items.count;i++)if([RWID(self.feedGrid.items[i])isEqual:self.exerciseLibraryAnchor[@"id"]]){UICollectionViewLayoutAttributes *a=[self.feedGrid layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:i inSection:0]];if(a){targetFound=YES;targetDelta=self.feedGrid.contentOffset.y-a.frame.origin.y;}break;}
    for(RWPoster *poster in [self exerciseVisiblePosters])if(poster.meta)[images addObject:@{@"id":RWID(poster.meta),@"contents_prepared":@(poster.contentsPrepared)}];
    return @{@"profile":s.state[@"activeProfile"],@"page":self.page?:@"",@"age":s.profile[@"maxAge"],@"saved_ids":[s.saved valueForKey:@"id"]?:@[],@"grid":self.feedGrid.continuationDiagnostics?:@{},@"anchor":self.feedGrid.positionAnchor?:@{},@"expected_anchor":self.exerciseLibraryAnchor?:@{},@"images":images,@"ratings":ages,@"denied_title":RWID(self.exerciseLibraryMetas.firstObject),@"target_found":@(targetFound),@"target_delta":@(targetDelta),@"downloads":self.downloadsSnapshot[@"items"]?:@[],@"download_count":@([self.downloadsSnapshot[@"items"]count]),@"download_offset":@(self.downloadsList.contentOffset.y),@"expected_offset":@(self.exerciseLibraryOffset),@"width":@(self.view.bounds.size.width),@"height":@(self.view.bounds.size.height),@"orientation":@(UIApplication.sharedApplication.statusBarOrientation),@"original_orientation":@(self.exerciseOriginalOrientation)};
}
- (BOOL)exerciseLibraryStep:(NSString *)kind {
    RewindStore *s=RewindStore.shared;NSString *owned=@"rw-device-resume-check",*kids=@"rw-device-kids-12",*run=self.exerciseRequest[@"run"];NSInteger build=[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue];
    NSDictionary *profile=s.state[@"profiles"][owned];if(!self.exerciseResumeOwned||![RWDeviceExercise ownsResumeProfile:profile build:build])return NO;
    if([kind isEqual:@"library-prepare"]){
        if(!s.catalogReady){if(NSProcessInfo.processInfo.systemUptime-self.exerciseStarted>20)return NO;self.exerciseIndex--;return YES;}
        if(s.state[@"profiles"][kids])return NO;NSMutableArray *items=[NSMutableArray new],*pool=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
        NSMutableArray *catalog=[NSMutableArray arrayWithArray:s.movies?:@[]];[catalog addObjectsFromArray:s.series?:@[]];NSDictionary *adult=nil;
        for(NSDictionary *m in catalog)if([[s.ratings rating:RWID(m)][@"minimumAge"]integerValue]>12){adult=m;break;}
        if(!adult){self.exerciseLibraryReport=@{@"fixture_error":@"No currently rated adult title in catalog"};return NO;}[pool addObject:adult];[pool addObjectsFromArray:s.familyCatalog?:@[]];[pool addObjectsFromArray:catalog];
        for(NSDictionary *m in pool){NSString *key=RWID(m);if(!key.length||[seen containsObject:key]||![@[@"movie",@"series"]containsObject:m[@"type"]?:@""])continue;[seen addObject:key];NSMutableDictionary *brief=[m mutableCopy];[brief removeObjectForKey:@"videos"];[items addObject:brief];if(items.count==47)break;}
        if(items.count<47)return NO;[items addObject:@{@"id":@"rw:library-unrated",@"type":@"movie",@"name":@"Unrated library check"}];self.exerciseLibraryMetas=items;
        NSString *original=profile[@"sources"][@"rw:resume-owner"][@"original"];NSMutableDictionary *child=[RWProfiles make:@"Device Kids check" age:12];child[@"autoplayTrailers"]=@NO;child[@"saved"]=[items mutableCopy];child[@"sources"][@"rw:kids-owner"]=@{@"protocol":@1,@"build":@(build),@"original":original,@"run":run,@"age":@12};s.state[@"profiles"][kids]=child;s.profile[@"saved"]=[items mutableCopy];
        NSFileManager *fm=NSFileManager.defaultManager;NSString *root=[RWDocuments()stringByAppendingPathComponent:@"Torrents"];
        for(NSUInteger i=0;i<24;i++){NSString *hash=[self exerciseLibraryHash:i],*path=[root stringByAppendingPathComponent:hash];if([fm fileExistsAtPath:path]||[s.state[@"keptDownloads"]containsObject:hash])return NO;
            NSDictionary *owner=@{@"run":run,@"build":@(build),@"hash":hash};
            if(![fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]||![owner writeToFile:[path stringByAppendingPathComponent:@"rewind-library-owner.plist"] atomically:YES]||![[NSData dataWithBytes:"test" length:4]writeToFile:[path stringByAppendingPathComponent:@"fixture.bin"] atomically:YES])return NO;
            NSDictionary *m=items[i],*record=@{@"videoID":RWID(m),@"meta":m,@"position":@20,@"duration":@600,@"updated":@(NSDate.date.timeIntervalSince1970-i),@"source":@{@"infoHash":hash,@"url":[@"magnet:?xt=urn:btih:" stringByAppendingString:hash],@"fileIdx":@0,@"downloadBytes":@4}};
            s.profile[@"history"][RWID(m)]=record;child[@"history"][RWID(m)]=record;
        }[s save];return YES;
    }
    if([kind isEqual:@"library-list"])return [self exercisePressNavigation:@"My List"];
    if([kind isEqual:@"library-scroll"]){if(self.feedGrid.items.count!=48)return NO;[self.feedGrid scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:20 inSection:0] atScrollPosition:UICollectionViewScrollPositionTop animated:NO];[self loadVisiblePosters];return YES;}
    if([kind isEqual:@"library-open"]){NSString *key=self.exerciseLibraryAnchor[@"id"];for(NSDictionary *m in s.saved)if([RWID(m)isEqual:key]){self.feedGrid.onSelect(m);return [self.page isEqual:@"Details"];}return NO;}
    if([kind isEqual:@"library-back"]){[self destinationBack];return [self.page isEqual:@"My List"];}
    if([kind isEqual:@"library-remove-before"]){if(![s.state[@"activeProfile"]isEqual:owned])return NO;NSDictionary *first=s.saved.firstObject;if([RWID(first)isEqual:self.exerciseLibraryAnchor[@"id"]])return NO;[s toggleSaved:first];[self render];return YES;}
    if([kind isEqual:@"library-end"]){[self.feedGrid setContentOffset:CGPointMake(0,MAX(0,self.feedGrid.contentSize.height-self.feedGrid.bounds.size.height)) animated:NO];[self loadVisiblePosters];return YES;}
    if([kind isEqual:@"library-downloads"]){[self go:@"Downloads"];self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;return YES;}
    if([kind isEqual:@"library-await-downloads"]){if(self.downloadsBusy||!self.downloadsSnapshot){if(NSProcessInfo.processInfo.systemUptime-self.exercisePlaybackStarted>20)return NO;self.exerciseIndex--;}return YES;}
    if([kind isEqual:@"library-download-scroll"]){[self.downloadsList setContentOffset:CGPointMake(0,1900) animated:NO];[self.downloadsList loadVisibleArtwork];self.exerciseLibraryOffset=self.downloadsList.contentOffset.y;return self.exerciseLibraryOffset>1000;}
    if([kind isEqual:@"library-refresh"]){[self refreshDownloads];self.exercisePlaybackStarted=NSProcessInfo.processInfo.systemUptime;return YES;}
    if([kind isEqual:@"library-empty"]){if(![s.state[@"activeProfile"]isEqual:owned])return NO;s.profile[@"saved"]=[NSMutableArray new];[self go:@"My List"];[s save];return YES;}
    if([kind isEqual:@"library-kids"]){if(![RWDeviceExercise ownsKidsProfile:s.state[@"profiles"][kids] build:build run:run])return NO;self.exerciseProfile=kids;[self selectProfile:kids];return YES;}
    if([kind isEqual:@"library-adult"]){self.exerciseProfile=owned;[self selectProfile:owned];return YES;}
    if([kind hasPrefix:@"library-audit-"]){
        NSString *label=[kind substringFromIndex:14];if([label isEqual:@"landscape"])self.exerciseLibraryAnchor=self.feedGrid.positionAnchor;NSDictionary *snap=[self exerciseLibrarySnapshot];self.exerciseLibraryReport=snap;BOOL ok=YES;
        if([@[@"landscape",@"rotation",@"back",@"removal"]containsObject:label]){NSString *key=self.exerciseLibraryAnchor[@"id"];BOOL visible=NO;for(NSDictionary *m in self.feedGrid.visibleMetadata)visible|=[RWID(m)isEqual:key];ok=[self.page isEqual:@"My List"]&&visible&&self.feedGrid.items.count==([label isEqual:@"removal"]?47:48);if([label isEqual:@"landscape"])ok=ok&&[self.exerciseLibraryAnchor[@"index"]integerValue]>=15;if([label isEqual:@"rotation"])ok=ok&&self.view.bounds.size.width==768;}
        else if([label isEqual:@"end"]){ok=self.feedGrid.items.count==47;BOOL found=NO;for(NSDictionary *m in self.feedGrid.visibleMetadata)found|=[RWID(m)isEqual:@"rw:library-unrated"];ok=ok&&found;}
        else if([@[@"downloads",@"refresh"]containsObject:label])ok=[self.page isEqual:@"Downloads"]&&[snap[@"download_count"]integerValue]==24&&fabs([snap[@"download_offset"]doubleValue]-self.exerciseLibraryOffset)<1;
        else if([label isEqual:@"empty"])ok=[self.page isEqual:@"My List"]&&!self.feedGrid&&!s.saved.count;
        else if([label hasPrefix:@"kids"]){NSArray *metas=[label isEqual:@"kids-list"]?s.saved:[self.downloadsSnapshot[@"items"]valueForKey:@"meta"];ok=[s.state[@"activeProfile"]isEqual:kids]&&metas.count>=12;
            for(NSDictionary *m in metas){NSNumber *age=[s.ratings rating:RWID(m)][@"minimumAge"];if(!age||age.integerValue>12||[RWID(m)isEqual:RWID(self.exerciseLibraryMetas.firstObject)]||[RWID(m)isEqual:@"rw:library-unrated"])ok=NO;}
            ok=ok&&metas.count<([label isEqual:@"kids-list"]?48:24);
        }else if([label isEqual:@"restored"])ok=UIApplication.sharedApplication.statusBarOrientation==self.exerciseOriginalOrientation;
        else ok=NO;
        if([@[@"landscape",@"rotation",@"end",@"downloads",@"empty",@"kids-list",@"kids-downloads"]containsObject:label])ok=[self exerciseCastCapture:[@"device-exercise-" stringByAppendingString:kind]]&&ok;
        return ok;
    }return NO;
}
- (void)finishLibraryExercise {
    if(![self.exerciseRequest[@"action"]isEqual:@"library-browse"])return;RewindStore *s=RewindStore.shared;NSString *run=self.exerciseRequest[@"run"];NSInteger build=[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue];NSFileManager *fm=NSFileManager.defaultManager;
    NSString *kids=@"rw-device-kids-12";NSDictionary *p=s.state[@"profiles"][kids];if([RWDeviceExercise ownsKidsProfile:p build:build run:run]){NSString *original=p[@"sources"][@"rw:kids-owner"][@"original"];if([s.state[@"activeProfile"]isEqual:kids]){self.exerciseProfile=original;[self selectProfile:original];}if(![s.state[@"activeProfile"]isEqual:kids])[s.state[@"profiles"]removeObjectForKey:kids];}
    for(NSUInteger i=0;i<24;i++){NSString *hash=[self exerciseLibraryHash:i],*path=[[RWDocuments()stringByAppendingPathComponent:@"Torrents"]stringByAppendingPathComponent:hash];if([[NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"rewind-library-owner.plist"]]isEqual:@{@"run":run,@"build":@(build),@"hash":hash}])[fm removeItemAtPath:path error:nil];}
    [s save];self.exerciseLibraryMetas=nil;self.exerciseLibraryAnchor=nil;self.exerciseLibraryReport=nil;
}
