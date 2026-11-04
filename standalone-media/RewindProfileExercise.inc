// Bounded foreground acceptance using existing UIKit controls. No preferences,
// age limits, history or saved titles are edited by this recipe.
- (NSArray *)exerciseVisiblePosters {
    NSMutableArray *queue=[NSMutableArray arrayWithObject:self.content],*posters=[NSMutableArray new];
    while(queue.count){UIView *view=queue.lastObject;[queue removeLastObject];[queue addObjectsFromArray:view.subviews];
        if(![view isKindOfClass:RWPoster.class]||!view.window||view.hidden||view.alpha<.01)continue;
        CGRect visible=[view convertRect:view.bounds toView:view.window];BOOL hidden=NO;
        for(UIView *parent=view.superview;parent;parent=parent.superview){hidden|=parent.hidden||parent.alpha<.01;if(parent.clipsToBounds||parent==view.window)visible=CGRectIntersection(visible,[parent convertRect:parent.bounds toView:view.window]);}
        if(!hidden&&!CGRectIsNull(visible)&&visible.size.width*visible.size.height>=view.bounds.size.width*view.bounds.size.height*.5)[posters addObject:view];
    }
    return [posters sortedArrayUsingComparator:^NSComparisonResult(UIView *a,UIView *b){CGRect x=[a convertRect:a.bounds toView:self.view],y=[b convertRect:b.bounds toView:self.view];CGFloat d=fabs(x.origin.y-y.origin.y)>1?x.origin.y-y.origin.y:x.origin.x-y.origin.x;return d<0?NSOrderedAscending:d>0?NSOrderedDescending:NSOrderedSame;}];
}
- (BOOL)exerciseAuditProfilePage:(BOOL)details {
    RewindStore *store=[RewindStore shared];NSMutableArray *titles=[NSMutableArray new],*records=[NSMutableArray new];
    for(RWPoster *poster in [self exerciseVisiblePosters])if(poster.meta)[titles addObject:poster.meta];
    NSDictionary *lead=details?self.detail:self.homeHeaderRecord[@"hero"];if(RWID(lead).length)[titles addObject:lead];
    NSInteger age=[store.profile[@"maxAge"]integerValue];NSUInteger denied=0,unknown=0,over=0;NSMutableSet *seen=[NSMutableSet new];
    for(NSDictionary *meta in titles){NSString *key=RWID(meta);if([seen containsObject:key])continue;[seen addObject:key];NSDictionary *rating=[store.ratings rating:key];
        NSNumber *minimum=[rating[@"minimumAge"]isKindOfClass:NSNumber.class]?rating[@"minimumAge"]:@(-1);
        BOOL allowed=[store allowed:meta];denied+=!allowed;unknown+=age>=0&&minimum.integerValue<0;over+=age>=0&&minimum.integerValue>age;
        [records addObject:@{@"id":key,@"type":meta[@"type"]?:@"",@"minimum_age":minimum,@"allowed":@(allowed),@"rating_source":rating[@"source"]?:@"",@"genres":meta[@"genres"]?:@[]}];
    }
    BOOL profile=[store.state[@"activeProfile"]isEqual:self.exerciseProfile]&&[self.navigationState[@"profile"]isEqual:self.exerciseProfile];
    BOOL context=details?([self.page isEqual:@"Details"]&&[RWID(self.detail)isEqual:self.exerciseDetailID]):([self.page isEqual:@"Home"]&&[self.homeViewContext[@"profile"]isEqual:self.exerciseProfile]&&[self.homeViewContext[@"age"]integerValue]==age);
    self.exerciseProfileAudit=@{@"age_limit":@(age),@"restricted":@(store.restricted),@"profile_matches":@(profile),@"context_matches":@(context),@"denied":@(denied),@"unknown_age":@(unknown),@"over_age":@(over),@"titles":records,@"anchor":[self.homeView viewportAnchor]?:@{},@"detail_id":details?RWID(self.detail):@""};
    return profile&&context&&records.count>0&&!denied&&!unknown&&!over;
}
// Keep at most two native frames until the animation has finished. Encoding
// PNGs during the movement previously blocked the main thread and distorted it.
- (BOOL)captureProfileMotionFrame:(NSString *)name {
    if(!self.view.window||self.exerciseProfileMotionImages.count>=2)return NO;
    UIGraphicsBeginImageContextWithOptions(self.view.bounds.size,YES,1);
    BOOL drawn=[self.view drawViewHierarchyInRect:self.view.bounds afterScreenUpdates:NO];
    UIImage *frame=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();
    if(!drawn||!frame)return NO;if(!self.exerciseProfileMotionImages)self.exerciseProfileMotionImages=[NSMutableDictionary new];self.exerciseProfileMotionImages[name]=frame;return YES;
}
- (BOOL)flushProfileMotionFrames {
    NSString *folder=[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"];
    [[NSFileManager defaultManager]createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];BOOL ok=YES;
    for(NSString *name in self.exerciseProfileMotionImages){NSData *png=UIImagePNGRepresentation(self.exerciseProfileMotionImages[name]);ok&=png.length>0&&[png writeToFile:[folder stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]] atomically:YES];}
    self.exerciseProfileMotionImages=nil;return ok;
}
- (BOOL)exerciseProfileStep:(NSDictionary *)step {
    NSString *kind=step[@"kind"];RewindStore *store=[RewindStore shared];
    if(!self.exerciseProfilePair){self.exerciseProfilePair=[RWDeviceExercise profilePairForState:store.state];if(!self.exerciseProfilePair)return NO;}
    if([kind isEqual:@"profile-motion-enable-full"]){
        [self go:@"Settings"];if([store.state[@"profileMotion"]isEqual:@"cinematic"])return YES;
        for(UIView *v in self.content.subviews)if([v isKindOfClass:RWButton.class]&&[v.accessibilityIdentifier isEqual:@"RWProfileMotion"]){[(RWButton *)v sendActionsForControlEvents:UIControlEventTouchUpInside];return [store.state[@"profileMotion"]isEqual:@"cinematic"]&&self.profileExperience.cinematic;}return NO;
    }
    if([kind isEqual:@"profile-motion-replay"]){[self.profileExperience replayIntroduction];return [self.page isEqual:@"Profiles"]&&[[self.profileExperience diagnostics][@"transition_active"]boolValue];}
    if([kind isEqual:@"profile-motion-brand-capture"]){self.exerciseProfileAudit=[self.profileExperience diagnostics];if(![self.exerciseProfileAudit[@"brand_visible"]boolValue])return NO;RWCapture(self.view,@"device-exercise-profile-brand");return YES;}
    if([kind isEqual:@"profile-motion-brand-done"]){self.exerciseProfileAudit=[self.profileExperience diagnostics];return ![self.exerciseProfileAudit[@"transition_active"]boolValue]&&![self.exerciseProfileAudit[@"reduce_motion"]boolValue]&&[self.exerciseProfileAudit[@"motion_samples"]unsignedIntegerValue]>3&&[self.exerciseProfileAudit[@"motion_max_scale"]doubleValue]>2;}
    if([kind isEqual:@"profile-motion-initial"]){self.exerciseProfileAudit=[self.profileExperience diagnostics];return [self.page isEqual:@"Profiles"]&&[self.exerciseProfileAudit[@"entrances"]integerValue]==1;}
    if([kind isEqual:@"profile-motion-silent"]){[self.profileExperience stop];self.profileExperience.soundEnabled=NO;self.exerciseProfileAudit=[self.profileExperience diagnostics];return ![self.exerciseProfileAudit[@"audio_active"]boolValue];}
    if([kind isEqual:@"profile-motion-cancel"]){
        NSDictionary *before=[self.profileExperience diagnostics];[self.profileExperience stop];self.exerciseProfileAudit=[self.profileExperience diagnostics];
        return ![before[@"sound_enabled"]boolValue]&&![before[@"sound_accepted"]boolValue]&&![self.exerciseProfileAudit[@"transition_active"]boolValue]&&![self.exerciseProfileAudit[@"audio_active"]boolValue];
    }
    if([kind isEqual:@"profile-motion-center"]){
        self.exerciseProfileAudit=[self.profileExperience diagnostics];BOOL visible=[self.exerciseProfileAudit[@"transition_active"]boolValue]&&[self.exerciseProfileAudit[@"background_ribbons"]unsignedIntegerValue]==(store.restricted?12:14);
        NSString *name=store.restricted?@"device-exercise-profile-center-kids":@"device-exercise-profile-center-main";
        return visible&&[self captureProfileMotionFrame:name];
    }
    if([kind isEqual:@"profile-motion-background"]){
        self.exerciseProfileAudit=[self.profileExperience diagnostics];
        BOOL visible=[self.exerciseProfileAudit[@"transition_active"]boolValue]&&[self.exerciseProfileAudit[@"background_ribbons"]unsignedIntegerValue]==(store.restricted?12:14);
        return visible&&[self captureProfileMotionFrame:store.restricted?@"device-exercise-profile-background-kids":@"device-exercise-profile-background-main"];
    }
    if([kind isEqual:@"profile-motion-settled"]){
        NSMutableDictionary *audit=[[self.profileExperience diagnostics]mutableCopy];BOOL context=[self.page isEqual:@"Home"]&&[self.homeViewContext[@"profile"]isEqual:store.state[@"activeProfile"]]&&[self.homeViewContext[@"age"]isEqual:store.profile[@"maxAge"]];
        NSUInteger denied=0;for(RWPoster *poster in [self exerciseVisiblePosters])if(![store allowed:poster.meta])denied++;
        audit[@"context_matches"]=@(context);audit[@"denied"]=@(denied);audit[@"age"]=store.profile[@"maxAge"];self.exerciseProfileAudit=audit;
        return context&&!denied&&![audit[@"transition_active"]boolValue]&&![audit[@"audio_active"]boolValue]&&[self flushProfileMotionFrames];
    }
    if([kind isEqual:@"profile-picker"]){self.exerciseProfileAudit=nil;[self go:@"Profiles"];return [self.page isEqual:@"Profiles"]&&!self.managingProfiles;}
    if([kind hasPrefix:@"profile-series-"]){
        if(!store.restricted||![self.page isEqual:@"Home"])return NO;
        NSArray *ids=@[@"tt7678620",@"tt0852863"]; // Actual Bluey / Phineas metadata, never seeded readiness.
        if([kind isEqual:@"profile-series-load"]){
            for(NSString *key in ids){NSDictionary *meta=nil;for(NSDictionary *m in [store discoveryPool])if([RWID(m)isEqual:key]){meta=m;break;}if(!meta||![store allowed:meta])return NO;[store details:meta done:^(id result,NSString *error){}];}
            self.exerciseProfileAudit=@{@"metadata_requests":ids};return YES;
        }
        if([kind isEqual:@"profile-series-evict"]){self.exerciseProfileAudit=[store evictEpisodeDetailsForDiagnostics:ids];return self.exerciseProfileAudit&&[self.exerciseProfileAudit[@"before"]isEqual:self.exerciseProfileAudit[@"after"]];}
        NSMutableArray *titles=[NSMutableArray new];BOOL valid=YES;
        for(NSString *key in ids){NSDictionary *canonical=[store canonicalShow:key];NSString *video=[store availabilityVideoID:@{@"id":key,@"type":@"series"}];BOOL compact=canonical[@"episodeIndexAt"]!=nil;valid&=compact&&video.length>0&&![store cachedShow:key];
            [titles addObject:@{@"id":key,@"videoID":video?:@"",@"compact":@(compact),@"full_cached":@([store cachedShow:key]!=nil),@"episodes":@([canonical[@"videos"]count]),@"received_at":canonical[@"episodeIndexAt"]?:@0}];}
        self.exerciseProfileAudit=@{@"series":titles,@"catalog":[store episodeCatalogDiagnostics]};return valid;
    }
    if([kind hasPrefix:@"profile-density-"]||[kind hasPrefix:@"profile-catalog-"]){
        if(([kind hasPrefix:@"profile-density-"]&&!store.restricted)||![self exerciseAuditProfilePage:NO])return NO;
        NSMutableDictionary *audit=[self.exerciseProfileAudit mutableCopy];NSMutableArray *rows=[NSMutableArray new];NSUInteger denied=0;
        for(NSDictionary *row in self.homeView.displayedRows){NSMutableArray *titles=[NSMutableArray new];for(NSDictionary *m in row[@"items"]){
            NSDictionary *rating=[store.ratings rating:RWID(m)],*availability=[store availability:m];BOOL allowed=[store allowed:m];denied+=!allowed;
            [titles addObject:@{@"id":RWID(m),@"name":RWString(m[@"name"]),@"type":RWString(m[@"type"]),@"allowed":@(allowed),@"minimum_age":rating[@"minimumAge"]?:@(-1),@"availability":availability?:@{},@"franchises":m[@"discovery"][@"franchises"]?:@[]}];
        }[rows addObject:@{@"id":row[@"id"]?:@"",@"title":row[@"title"]?:@"",@"items":titles}];}
        audit[@"displayed_rows"]=rows;audit[@"ranked_home"]=store.discoveryHome?:@{};audit[@"home_diagnostics"]=self.homeView.diagnostics?:@{};audit[@"all_rows_denied"]=@(denied);audit[@"episode_catalog"]=[store episodeCatalogDiagnostics];
        if([kind isEqual:@"profile-density-first"]||[kind isEqual:@"profile-catalog-main"])audit[@"coverage"]=[store discoveryCoverageDiagnostics];
        NSString *name=[@"device-exercise-" stringByAppendingString:kind];RWCapture(self.view,name);audit[@"capture"]=name;self.exerciseProfileAudit=audit;return rows.count>0&&!denied;
    }
    if([kind isEqual:@"profile-select-kids"]||[kind isEqual:@"profile-select-regular"]){
        BOOL kids=[kind isEqual:@"profile-select-kids"];BOOL originalKids=[store.state[@"profiles"][self.exerciseProfilePair[@"original"]][@"maxAge"]integerValue]>=0;
        return [self exerciseProfileStep:@{@"kind":kids==originalKids?@"profile-original":@"profile-other"}];
    }
    if([kind isEqual:@"profile-other"]||[kind isEqual:@"profile-original"]){
        if(![self.page isEqual:@"Profiles"]||self.managingProfiles)return NO;
        NSString *target=self.exerciseProfilePair[[kind isEqual:@"profile-other"]?@"other":@"original"],*identifier=[@"RWProfile:" stringByAppendingString:target];
        for(UIView *view in self.content.subviews)if([view isKindOfClass:RWButton.class]&&[view.accessibilityIdentifier isEqual:identifier]){
            self.exerciseProfile=target;self.exerciseProfileAudit=nil;[(RWButton *)view sendActionsForControlEvents:UIControlEventTouchUpInside];return [store.state[@"activeProfile"]isEqual:target]&&[self.page isEqual:@"Home"];
        }return NO;
    }
    if([kind hasPrefix:@"profile-capture-"]){
        NSString *suffix=[kind substringFromIndex:[@"profile-capture-" length]];
        if(![self.page isEqual:[suffix isEqual:@"picker"]?@"Profiles":[suffix isEqual:@"home"]?@"Home":@"Details"])return NO;
        NSString *name=[suffix isEqual:@"picker"]?@"device-exercise-profiles":[NSString stringWithFormat:@"device-exercise-%@-%@",store.restricted?@"kids":@"regular",suffix];
        NSString *path=[[RWDocuments()stringByAppendingPathComponent:@"RewindDiagnostics"]stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]];
        [[NSFileManager defaultManager]removeItemAtPath:path error:nil];[self.view layoutIfNeeded];RWCapture(self.view,name);return [[[NSFileManager defaultManager]attributesOfItemAtPath:path error:nil]fileSize]>0;
    }
    if([kind isEqual:@"profile-scroll-home"]){if(!self.homeView.window||![self.page isEqual:@"Home"])return NO;CGFloat maximum=MAX(0,self.homeView.contentSize.height-self.homeView.bounds.size.height);[self.homeView setContentOffset:CGPointMake(0,MIN(360,maximum)) animated:YES];return YES;}
    if([kind isEqual:@"profile-open-detail"]){
        if(![self.page isEqual:@"Home"])return NO;RWPoster *chosen=nil;
        for(RWPoster *poster in [self exerciseVisiblePosters]){NSDictionary *meta=poster.meta;if(meta[@"historyRecord"]||[meta[@"episodeVideoID"]length]||![store allowed:meta]||!poster.enabled)continue;if(!chosen)chosen=poster;if([meta[@"type"]isEqual:step[@"type"]]){chosen=poster;break;}}
        if(!chosen)return NO;self.exerciseHomeAnchor=[self.homeView viewportAnchor];self.exerciseDetailID=RWID(chosen.meta);self.exerciseProfileAudit=nil;
        [chosen sendActionsForControlEvents:UIControlEventTouchUpInside];return [self.page isEqual:@"Details"]&&[RWID(self.detail)isEqual:self.exerciseDetailID]&&!self.presentedViewController;
    }
    if([kind isEqual:@"profile-detail-back"]){
        if(![self.page isEqual:@"Details"])return NO;for(UIView *view in self.content.subviews)if([view isKindOfClass:RWButton.class]&&[[(RWButton *)view currentTitle]isEqual:@"Back"]){[(RWButton *)view sendActionsForControlEvents:UIControlEventTouchUpInside];return [self.page isEqual:@"Home"];}return NO;
    }
    if([kind isEqual:@"profile-audit-home"])return [self exerciseAuditProfilePage:NO];
    if([kind isEqual:@"profile-audit-detail"])return [self exerciseAuditProfilePage:YES];
    if([kind isEqual:@"profile-audit-return"]){BOOL page=[self exerciseAuditProfilePage:NO];NSDictionary *anchor=[self.homeView viewportAnchor];BOOL restored=[anchor[@"row"]isEqual:self.exerciseHomeAnchor[@"row"]]&&fabs([anchor[@"delta"]doubleValue]-[self.exerciseHomeAnchor[@"delta"]doubleValue])<=1.5;
        NSMutableDictionary *audit=[self.exerciseProfileAudit mutableCopy];audit[@"anchor_restored"]=@(restored);audit[@"expected_anchor"]=self.exerciseHomeAnchor?:@{};self.exerciseProfileAudit=audit;return page&&restored;}
    return NO;
}
