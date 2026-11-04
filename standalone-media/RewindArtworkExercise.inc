// Explicit USB-armed fixture: real detail header, store binding, image cache,
// NSURLSession and iOS image decoder. No alternate renderer or normal app server.
- (NSString *)exerciseArtworkURL:(NSString *)name {
    return [NSString stringWithFormat:@"http://127.0.0.1:18882/art/%@/%@",self.exerciseRequest[@"run"],name];
}
- (NSDictionary *)exerciseArtworkSnapshot {
    NSMutableDictionary *d=[self.exerciseArtworkReport mutableCopy]?:[NSMutableDictionary new];
    d[@"header"]=self.exerciseArtworkHeader.diagnostics?:@{};
    d[@"mounted"]=@(self.exerciseArtworkHeader.window==self.view.window&&self.view.window!=nil);
    d[@"foreground"]=@(UIApplication.sharedApplication.applicationState==UIApplicationStateActive);
    d[@"phase"]=self.exerciseArtworkPhase?:@"";return d;
}
- (void)exerciseArtworkMeta:(NSString *)identifier background:(NSString *)background poster:(NSString *)poster {
    NSMutableDictionary *m=[@{@"id":identifier,@"name":@"The End of Oak Street",@"type":@"movie",@"releaseInfo":@"2026",@"genres":@[@"Mystery",@"Science Fiction"]}mutableCopy];
    if(background)m[@"background"]=[self exerciseArtworkURL:background];if(poster)m[@"poster"]=[self exerciseArtworkURL:poster];
    [self.exerciseArtworkHeader updateMeta:m rating:@{} width:self.exerciseArtworkStage.bounds.size.width];
    self.exerciseArtworkReport[@"cleared_synchronously"]=@(![self.exerciseArtworkHeader.diagnostics[@"image_present"]boolValue]);
    self.exerciseArtworkReport[@"expected_identity"]=identifier;
    self.exerciseArtworkDeadline=NSProcessInfo.processInfo.systemUptime+18;
}
- (BOOL)exerciseArtworkStep:(NSString *)kind {
    RewindStore *store=[RewindStore shared];
    if(![self.exerciseRequest[@"action"]isEqual:@"artwork-states"]||!self.exerciseResumeOwned||![store.state[@"activeProfile"]isEqual:@"rw-device-resume-check"])return NO;
    if([kind isEqual:@"artstate-prepare"]){
        if(self.exerciseArtworkStage||self.presentedViewController)return NO;
        [self stopPreview];[self.playbackPreparation cancel];[store setDiscoveryPaused:YES];
        self.exerciseArtworkReport=[NSMutableDictionary new];
        UIView *stage=[[UIView alloc]initWithFrame:self.content.frame];stage.backgroundColor=RWColor(0x0e1116);self.exerciseArtworkStage=stage;[self.view addSubview:stage];
        RWDetailHeader *header=[[RWDetailHeader alloc]initWithScope:@"artwork-fixture"];self.exerciseArtworkHeader=header;[stage addSubview:header];
        UIImageView *seed=[[UIImageView alloc]initWithFrame:CGRectMake(0,0,188,266)];self.exerciseArtworkSeed=seed;seed.hidden=YES;[stage addSubview:seed];
        NSString *url=[self exerciseArtworkURL:@"corrupt"],*folder=[NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES)[0]stringByAppendingPathComponent:@"RewindImages"];
        NSData *data=[url dataUsingEncoding:NSUTF8StringEncoding];unsigned char hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,hash);NSMutableString *key=[NSMutableString new];for(NSUInteger i=0;i<sizeof(hash);i++)[key appendFormat:@"%02x",hash[i]];
        NSString *path=[folder stringByAppendingPathComponent:key];if([[NSFileManager defaultManager]fileExistsAtPath:path])return NO;
        BOOL seeded=[[@"intentionally corrupt owned fixture" dataUsingEncoding:NSUTF8StringEncoding]writeToFile:path atomically:YES];self.exerciseArtworkReport[@"corrupt_seeded"]=@(seeded);self.exerciseArtworkReport[@"cache_folder"]=folder;
        [store artwork:@[[self exerciseArtworkURL:@"poster"]] role:@"poster" identity:@"rw:art-first" into:seed completion:nil];self.exerciseArtworkPhase=@"seed";self.exerciseArtworkDeadline=NSProcessInfo.processInfo.systemUptime+18;return seeded;
    }
    if(!self.exerciseArtworkStage.window)return NO;
    if([kind isEqual:@"artstate-await"]){
        NSDictionary *h=self.exerciseArtworkHeader.diagnostics;BOOL ready=[self.exerciseArtworkPhase isEqual:@"seed"]?self.exerciseArtworkSeed.image!=nil:[h[@"image_present"]boolValue]&&([self.exerciseArtworkPhase isEqual:@"wide"]||[self.exerciseArtworkPhase isEqual:@"corrupt"]?[h[@"bitmap_width"]doubleValue]>[h[@"bitmap_height"]doubleValue]:[h[@"bitmap_height"]doubleValue]>[h[@"bitmap_width"]doubleValue]);
        if(!ready){if(NSProcessInfo.processInfo.systemUptime>self.exerciseArtworkDeadline)return NO;self.exerciseIndex--;}return YES;
    }
    if([kind isEqual:@"artstate-preview"]){self.exerciseArtworkPhase=@"wide";[self exerciseArtworkMeta:@"rw:art-first" background:@"generic" poster:@"poster"];return YES;}
    if([kind isEqual:@"artstate-same-title"]){UIImageView *art=(UIImageView *)self.exerciseArtworkHeader.stage.subviews.firstObject;UIImage *before=art.image;CGRect frame=self.exerciseArtworkStage.frame;frame.size.width-=32;self.exerciseArtworkStage.frame=frame;[self.exerciseArtworkHeader updateMeta:@{@"id":@"rw:art-first",@"name":@"The End of Oak Street",@"type":@"movie",@"background":[self exerciseArtworkURL:@"generic"],@"poster":[self exerciseArtworkURL:@"poster"]} rating:@{} width:self.exerciseArtworkStage.bounds.size.width];self.exerciseArtworkReport[@"same_title_pixels_retained"]=@(art.image==before&&before!=nil);return [self.exerciseArtworkReport[@"same_title_pixels_retained"]boolValue];}
    if([kind isEqual:@"artstate-same-url-new-title"]){[self exerciseArtworkMeta:@"rw:art-second" background:@"generic" poster:@"poster"];return [self.exerciseArtworkReport[@"cleared_synchronously"]boolValue];}
    if([kind isEqual:@"artstate-old-request"]){self.exerciseArtworkPhase=@"old";[self exerciseArtworkMeta:@"rw:art-old" background:@"old" poster:nil];return [self.exerciseArtworkReport[@"cleared_synchronously"]boolValue];}
    if([kind isEqual:@"artstate-reuse"]){self.exerciseArtworkPhase=@"poster";[self exerciseArtworkMeta:@"rw:art-new" background:nil poster:@"poster"];return [self.exerciseArtworkReport[@"cleared_synchronously"]boolValue];}
    if([kind isEqual:@"artstate-no-url"]){self.exerciseArtworkPhase=@"empty";[self exerciseArtworkMeta:@"rw:art-empty" background:nil poster:nil];return [self.exerciseArtworkReport[@"cleared_synchronously"]boolValue];}
    if([kind isEqual:@"artstate-corrupt"]){self.exerciseArtworkPhase=@"corrupt";[self exerciseArtworkMeta:@"rw:art-corrupt" background:@"corrupt" poster:nil];return YES;}
    if([kind isEqual:@"artstate-missing"]){self.exerciseArtworkPhase=@"poster";[self exerciseArtworkMeta:@"rw:art-missing" background:@"missing" poster:@"poster"];return YES;}
    if([kind hasPrefix:@"artstate-audit-"]){
        NSString *label=[kind substringFromIndex:[@"artstate-audit-" length]];NSDictionary *h=self.exerciseArtworkHeader.diagnostics;BOOL present=[h[@"image_present"]boolValue],portrait=[h[@"bitmap_height"]doubleValue]>[h[@"bitmap_width"]doubleValue];
        BOOL empty=[label isEqual:@"empty"],wide=[label isEqual:@"wide"]||[label isEqual:@"corrupt"],fit=[label isEqual:@"preview"]||[label isEqual:@"reused"]||[label isEqual:@"late"]||[label isEqual:@"missing"];
        BOOL ok=[h[@"identity"]isEqual:self.exerciseArtworkReport[@"expected_identity"]]&&(empty?!present:present)&&(!wide||(!portrait&&[h[@"bitmap_width"]doubleValue]>=MIN(1280,[h[@"media_width"]doubleValue]*.8)))&&(!fit||(portrait&&[h[@"image_mode"]integerValue]==UIViewContentModeCenter));
        return [self exerciseCastCapture:[@"device-exercise-" stringByAppendingString:kind]]&&ok;
    }
    return NO;
}
- (void)finishArtworkExercise {
    if(!self.exerciseArtworkStage)return;
    RewindStore *store=[RewindStore shared];[store cancelArtwork:self.exerciseArtworkSeed];for(UIView *v in self.exerciseArtworkHeader.stage.subviews)if([v isKindOfClass:UIImageView.class])[store cancelArtwork:(UIImageView *)v];
    [self.exerciseArtworkStage removeFromSuperview];self.exerciseArtworkStage=nil;self.exerciseArtworkHeader=nil;self.exerciseArtworkSeed=nil;self.exerciseArtworkReport=nil;self.exerciseArtworkPhase=nil;
}
