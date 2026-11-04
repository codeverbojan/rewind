// Uses the existing metadata session, serial job queue and global network gate.
// No title-name matching, image decoding, or new background catalog sweep.
- (void)refreshArtwork:(NSDictionary *)meta {
    NSString *imdb=MID(meta),*key=[@"art:" stringByAppendingString:imdb];
    NSRange match=[imdb rangeOfString:@"^tt[0-9]{5,12}$" options:NSRegularExpressionSearch];
    if(_invalidated||![meta[@"type"]isEqual:@"series"]||match.location!=0||match.length!=imdb.length||_jobs.count>=24)return;
    double now=NSDate.date.timeIntervalSince1970;NSDictionary *art=MD([self record:imdb][@"artwork"]);
    double checked=[art[@"checkedAt"]respondsToSelector:@selector(doubleValue)]?[art[@"checkedAt"]doubleValue]:0;
    if([art[@"imdb"]isEqual:imdb]&&[art[@"provider"]isEqual:@"TVmaze"]&&checked>0&&checked<=now&&now-checked<7*86400)return;
    if([_failures[key]doubleValue]>now||[_active[@"key"]isEqual:key])return;
    for(NSDictionary *job in _jobs)if([job[@"key"]isEqual:key])return;
    [_jobs insertObject:@{@"kind":@"titleArtwork",@"key":key,@"imdb":imdb,@"foreground":@YES} atIndex:0];
    [self yieldBackgroundCredits];[self next];
}
- (NSString *)titleImageURL:(id)value {
    NSString *text=MT(value);NSURL *url=[NSURL URLWithString:text];
    return text.length<=2048&&[url.scheme isEqual:@"https"]&&[url.host isEqual:@"static.tvmaze.com"]&&[url.path hasPrefix:@"/uploads/images/"]&&!url.user&&!url.password?text:@"";
}
- (double)titleImageNumber:(id)value {return [value respondsToSelector:@selector(doubleValue)]?[value doubleValue]:0;}
- (void)finishTitleArtwork:(NSDictionary *)art job:(NSDictionary *)job error:(NSString *)error {
    if(_active!=job)return;
    NSString *imdb=job[@"imdb"];
    if(error.length||(!MA(art[@"background"]).count&&!MA(art[@"poster"]).count))_failures[job[@"key"]]=@(NSDate.date.timeIntervalSince1970+900);
    if([art[@"imdb"]isEqual:imdb]&&([MA(art[@"background"])count]||[MA(art[@"poster"])count])){
        NSMutableDictionary *record=[[self record:imdb]mutableCopy],*saved=[art mutableCopy];record[@"imdb"]=imdb;
        // A failed optional image request must remain retryable, without
        // discarding a useful exact-title poster or an older good backdrop.
        saved[@"checkedAt"]=error.length?@0:@(NSDate.date.timeIntervalSince1970);
        NSDictionary *old=MD(record[@"artwork"]);if(error.length&&!MA(saved[@"background"]).count&&[old[@"imdb"]isEqual:imdb]&&MA(old[@"background"]).count)saved[@"background"]=old[@"background"];
        record[@"artwork"]=saved;_cache[imdb]=[record copy];[self persist];
        [[NSNotificationCenter defaultCenter]postNotificationName:@"RWDiscoveryMetadataUpdated" object:self userInfo:@{@"id":imdb}];
    }
    _diagnostics=@{@"kind":@"titleArtwork",@"id":imdb,@"backgrounds":@(MA(art[@"background"]).count),@"posters":@(MA(art[@"poster"]).count),@"error":error?:@""};
    [self finish];
}
- (void)startTitleArtwork:(NSDictionary *)job generation:(NSUInteger)g {
    NSString *imdb=job[@"imdb"];NSMutableDictionary *art=[NSMutableDictionary new];
    __weak RWDiscoveryMetadata *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,8*NSEC_PER_SEC),dispatch_get_main_queue(),^{RWDiscoveryMetadata *s=weak;if(!s||s->_generation!=g||s->_active!=job||s->_paused)return;s->_generation++;[[RWMetadataBudget shared]cancel:s->_task];s->_task=nil;s->_responseData=nil;s->_responseDone=nil;[s finishTitleArtwork:art job:job error:@"Artwork refresh deadline"];} );
    [self fetch:[NSString stringWithFormat:@"https://api.tvmaze.com/lookup/shows?imdb=%@",imdb] generation:g done:^(NSDictionary *show,NSString *error){
        NSInteger showID=[show[@"id"]respondsToSelector:@selector(integerValue)]?[show[@"id"]integerValue]:0;
        if(![MD(show[@"externals"])[@"imdb"]isEqual:imdb]||showID<=0){[self finishTitleArtwork:art job:job error:error?:@"Artwork title identity unavailable"];return;}
        NSString *showURL=[NSString stringWithFormat:@"https://api.tvmaze.com/shows/%ld",(long)showID];
        [art addEntriesFromDictionary:@{@"provider":@"TVmaze",@"imdb":imdb,@"showID":@(showID),@"source":showURL}];
        NSString *poster=[self titleImageURL:MD(show[@"image"])[@"original"]];if(poster.length)art[@"poster"]=@[poster];
        [self fetch:[showURL stringByAppendingString:@"/images"] generation:g done:^(NSDictionary *response,NSString *imageError){
            NSMutableArray *backgrounds=[NSMutableArray new];NSArray *images=MA(response[@"images"]);
            for(NSDictionary *raw in [images subarrayWithRange:NSMakeRange(0,MIN((NSUInteger)64,images.count))]){
                NSDictionary *entry=MD(raw),*image=MD(MD(entry[@"resolutions"])[@"original"]);double width=[self titleImageNumber:image[@"width"]],height=[self titleImageNumber:image[@"height"]];
                NSString *url=[self titleImageURL:image[@"url"]];
                if(![entry[@"type"]isEqual:@"background"]||!url.length||!(width>=480&&height>=240&&width<=8192&&height<=8192&&width*height<=16000000&&width/height>=1.2&&width/height<=2.5))continue;
                if([backgrounds containsObject:url])continue;
                if([entry[@"main"]boolValue])[backgrounds insertObject:url atIndex:0];else [backgrounds addObject:url];
            }
            if(backgrounds.count){art[@"background"]=[backgrounds subarrayWithRange:NSMakeRange(0,MIN((NSUInteger)2,backgrounds.count))];art[@"backgroundKind"]=@"background";[self finishTitleArtwork:art job:job error:nil];return;}
            if(imageError.length){[self finishTitleArtwork:art job:job error:imageError];return;}
            // A first-episode still is preferable to another title's backdrop.
            // Verify its parent show, not merely a successful HTTP response.
            [self fetch:[showURL stringByAppendingString:@"/episodebynumber?season=1&number=1"] generation:g done:^(NSDictionary *episode,NSString *episodeError){
                BOOL exact=[MD(MD(episode[@"_links"])[@"show"])[@"href"]isEqual:showURL]&&[self titleImageNumber:episode[@"season"]]==1&&[self titleImageNumber:episode[@"number"]]==1;
                NSString *still=exact?[self titleImageURL:MD(episode[@"image"])[@"original"]]:@"";
                if(still.length){art[@"background"]=@[still];art[@"backgroundKind"]=@"episode";}
                [self finishTitleArtwork:art job:job error:episodeError?:(!exact?@"Artwork episode identity unavailable":nil)];
            }];
        }];
    }];
}
