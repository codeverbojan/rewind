- (void)renderCastPeople:(NSArray *)people {
    if(!self.castStage)return;double began=NSProcessInfo.processInfo.systemUptime;
    BOOL changed=[self.castStage updatePeople:people];[self.castStage updateViewport];
    [[RWUIProbe shared]work:changed?@"cast_model_update":@"cast_model_reuse" started:began];[self recordDetailOpenStage:changed?@"cast.update":@"cast.reuse" started:began];
}
- (CGFloat)castFor:(NSDictionary *)meta y:(CGFloat)y {
    NSArray *cast=[meta[@"cast"]isKindOfClass:NSArray.class]?meta[@"cast"]:@[];if(!cast.count)return y;
    [self label:@"Cast" x:33 y:y width:[self width]-66 size:23 weight:UIFontWeightSemibold color:0xf5f2eb];y+=44;
    NSString *scope=[self currentPreviewKey],*offsetKey=[@"RWcast:" stringByAppendingString:scope];
    if(![self.castStage.scope isEqual:scope]){
        self.castStage=[[RWCastStrip alloc]initWithScope:scope];__weak RewindController *weak=self;
        self.castStage.onSelect=^(NSDictionary *person){if([weak.page isEqual:@"Details"]&&[[weak currentPreviewKey]isEqual:scope])[weak openPerson:person];};
        self.castStage.onOffset=^(CGFloat offset){if(!weak||weak.reviewMode||![[weak currentPreviewKey]isEqual:scope])return;if(!weak.railOffsets)weak.railOffsets=[NSMutableDictionary new];if(weak.railOffsets.count>=128&&!weak.railOffsets[offsetKey])[weak.railOffsets removeObjectForKey:weak.railOffsets.allKeys.firstObject];weak.railOffsets[offsetKey]=@(MAX(0,offset));};
        if(self.railOffsets[offsetKey])[self.castStage restoreOffset:[self.railOffsets[offsetKey]doubleValue]];
    }
    self.castStage.frame=CGRectMake(0,y,[self width],246);[self.content addSubview:self.castStage];
    if(!self.castService)self.castService=[[RWCast alloc]initWithCache:[RWDocuments()stringByAppendingPathComponent:@"cast-cache.json"]];
    NSArray *people=[self.castService cached:meta];if(!people.count){NSMutableArray *names=[NSMutableArray new];for(id raw in cast){NSString *name=[self names:@[raw]];if(name.length)[names addObject:@{@"name":name}];if(names.count==12)break;}people=names;}
    [self renderCastPeople:people];return y+270;
}
- (void)loadVisibleCastPhotos {
    [self.castStage updateViewport];double now=NSProcessInfo.processInfo.systemUptime;
    if(!self.reviewMode&&self.castStage.window&&now-self.lastCastReport>1){self.lastCastReport=now;[[RewindStore shared]report:@{@"cast_strip":self.castStage.diagnostics}];}
}
- (void)loadVisibleCast {
    [self loadVisibleCastPhotos];if(self.reviewMode||!self.castStage.window||![self.page isEqual:@"Details"]||self.presentedViewController)return;
    CGRect r=[self.castStage convertRect:self.castStage.bounds toView:self.view];if(!CGRectIntersectsRect(r,CGRectInset(self.view.bounds,0,-200)))return;
    NSString *key=[self currentPreviewKey];if([self.castRequestKey isEqual:key])return;self.castRequestKey=key;NSDictionary *meta=self.detail;__weak RewindController *weak=self;double began=NSProcessInfo.processInfo.systemUptime;
    [self.castService resolve:meta done:^(NSArray *people){if(![weak.castRequestKey isEqual:key]||![weak.page isEqual:@"Details"])return;
        if(people.count)[weak renderCastPeople:people];
        [[RewindStore shared]report:@{@"cast_lookup":@{@"id":RWID(meta),@"people":@(people.count),@"photos":@([[people filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *p,NSDictionary *b){return RWString(p[@"image"]).length>0;}]]count]),@"seconds":@(NSProcessInfo.processInfo.systemUptime-began),@"failure":weak.castService.lastFailure?:@{}}}];
    }];
}
