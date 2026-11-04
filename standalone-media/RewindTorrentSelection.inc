#import "RWSourceIdentity.h"
// Shared production source selection; host facade tests exercise this exact code.
- (NSString *)sourceKey:(NSDictionary *)source {return RWSourceCandidateKey(source);}
- (NSArray *)remainingSources {
    NSMutableArray *remaining=[NSMutableArray new];
    for(NSDictionary *source in self.ranked)if(![self.triedSources containsObject:[self sourceKey:source]]&&![self.deadSwarms containsObject:RWString(source[@"infoHash"])])[remaining addObject:source];
    return remaining;
}
- (void)consumeRace:(NSDictionary *)race snapshot:(NSDictionary *)snapshot selected:(NSDictionary *)selected {
    double now=NSProcessInfo.processInfo.systemUptime;
    if(race){[self.metrics recordDiscovery:race uptime:now];[[RewindStore shared]report:@{@"discovery":race}];
        for(NSDictionary *failure in race[@"failures"]){
            if([failure[@"failure_scope"]isEqual:@"file"]){[self.triedSources addObject:[self sourceKey:failure]];continue;}
            NSString *hash=RWString(failure[@"infoHash"]);if(hash.length&&![self.deadSwarms containsObject:hash]){[self.deadSwarms addObject:hash];if(!self.exerciseRecovery&&![failure[@"local_checking"]boolValue])[self.metrics recordSourceOutcome:[[RewindStore shared]sourceFailed:failure] engine:race[@"session_id"] uptime:now];}
        }
        self.loadingTitle.text=@"Connecting to your film";
        self.loadingDetail.text=[race[@"bytes_per_second"]intValue]>0?@"Getting the opening scene ready…":@"Looking for a connection that can play smoothly…";
        if([race[@"selected"]boolValue]){self.discovering=NO;self.source=selected;
            [self.metrics markStage:@"source_selected" uptime:NSProcessInfo.processInfo.systemUptime];
            NSDictionary *identity=@{@"info_hash":self.source[@"infoHash"]?:@"",@"file_index":self.source[@"fileIdx"]?:@(-1),@"resolved_file_index":self.source[@"resolvedFileIdx"]?:@(-1),@"resolved_filename":self.source[@"resolvedFilename"]?:@"",@"requested_video_id":self.source[@"requestedVideoID"]?:@"",@"provider":self.source[@"provider"]?:@"",@"quality":@(self.quality)};
            NSMutableDictionary *selection=[identity mutableCopy];
            for(NSDictionary *candidate in race[@"candidates"])if([candidate[@"infoHash"]isEqual:self.source[@"infoHash"]]){selection[@"probe_at_selection"]=candidate;NSMutableDictionary *enriched=[self.source mutableCopy];for(NSString *key in @[@"measured_bytes_per_second",@"required_bytes_per_second_estimate",@"video_bytes",@"piece_bytes"])if(candidate[key])enriched[key]=candidate[key];self.source=enriched;break;}
            [self.metrics setContext:@{@"selected_source":[selection copy]}];
            [self.metrics recordEvent:@"source_selected" values:selection uptime:now];
            [self.keepButton setTitle:[[RewindStore shared].state[@"keptDownloads"]containsObject:RWString(self.source[@"infoHash"])]?@"Download kept":@"Keep download" forState:UIControlStateNormal];self.attemptStarted=now;self.lastDownloadProgress=now;self.lastPayload=0;[self.metrics beginAttemptAtUptime:now];
            [[RewindStore shared]report:@{@"selected_source":@{@"provider":self.source[@"provider"]?:@"Source",@"infoHash":self.source[@"infoHash"]?:@"",@"name":self.source[@"name"]?:@"",@"filename":self.source[@"filename"]?:@""}}];
        }else if([race[@"exhausted"]boolValue]){
            // Torrent exhaustion says nothing about untried HTTPS sources.
            // Keep the existing retry/deadline budgets in startNextSource.
            NSArray *remaining=[self remainingSources];NSUInteger direct=0;for(NSDictionary *candidate in remaining)if([@[@"http",@"https"]containsObject:[NSURL URLWithString:RWString(candidate[@"url"])].scheme])direct++;
            [self.metrics recordEvent:@"torrent_discovery_exhausted" values:@{@"remaining_sources":@(remaining.count),@"remaining_direct":@(direct),@"lookup_pending":@(self.sourceLookupPending)} uptime:now];
            self.discovering=NO;[self.engine pause];[self startNextSource];return;
        }
        else{[self updatePlayback];return;}
    }
    if(snapshot){self.lastTorrentSnapshot=snapshot;[[RewindStore shared]report:@{@"torrent":snapshot}];
        NSString *error=RWString(snapshot[@"error"]);if(error.length){[self failSource:error];return;}
        int64_t bytes=[snapshot[@"peer_payload_bytes"]longLongValue];if(bytes>self.lastPayload){self.lastPayload=bytes;self.lastDownloadProgress=now;}
        if([snapshot[@"video_total_bytes"]longLongValue]>0){
            if(!self.player&&!self.legacy&&[RWString(snapshot[@"video_name"]).pathExtension.lowercaseString isEqual:@"mkv"])[self prepareLegacy:nil];
            if(!self.player&&!self.legacy){self.loader=[[TorrentLoader alloc]initWithEngine:self.engine name:snapshot[@"video_name"] size:[snapshot[@"video_total_bytes"]longLongValue]];[self prepareItem:[self.loader playerItem]];}
            self.statusLabel.text=[snapshot[@"video_complete"]boolValue]?@"Downloaded":@"";
            self.loadingTitle.text=@"Preparing your film";self.loadingDetail.text=@"Checking picture and sound…";
        }
    }
}
