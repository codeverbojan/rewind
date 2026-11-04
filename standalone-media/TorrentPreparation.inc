// Engine-queue-only preparation. Metadata probes share one session; only one
// selected prefix can request payload. No decoder or closing-index read exists
// in this phase, so sparse storage cannot grow a file by seeking to its tail.
- (void)setPreparationPayloadAllowed:(BOOL)allowed {
    if(!_preparing)return;_preparationPayloadAllowed=allowed;[self updatePreparationBudget];
}
- (BOOL)preparationPrefixFinished:(NativeTorrent *)probe {
    if(!probe||!probe->info||probe->selected<0||probe->prioritiesPending||!probe->error.empty()||probe->probePieces.empty())return NO;
    auto &n=*probe;
    for(int p:n.probePieces)if(!n.handle.have_piece(lt::piece_index_t(p)))return NO;
    // Let the bounded verified reader finish interpreting this prefix. A
    // closing index outside it remains optional until the normal Play path.
    if(!n.durationProbe)return NO;
    if(n.durationProbe->state()!=RWMediaDuration::Waiting)return YES;
    uint64_t offset=n.durationProbe->offset()+n.durationBytes.length;
    if(offset>=uint64_t(n.size))return NO;
    int piece=int((n.fileOffset+int64_t(offset))/n.info->piece_length());
    return std::find(n.probePieces.begin(),n.probePieces.end(),piece)==n.probePieces.end();
}
- (void)updatePreparationBudget {
    if(!_preparing||!_native)return;
    double now=NSProcessInfo.processInfo.systemUptime;
    _preparationPayload=_preparationRetiredPayload;
    for(auto &probe:_probes)_preparationPayload+=std::max<int64_t>(0,probe->handle.status().total_payload_download);
    if(now-_preparationDiskChecked>=1){
        _preparationDiskChecked=now;_preparationAllocation=_preparationRetiredAllocation;
        for(auto &probe:_probes){uint64_t allocated=[RWMediaCache allocatedBytesAt:@(probe->directory.c_str())];
            if(allocated>probe->preparationAllocationBaseline)_preparationAllocation+=allocated-probe->preparationAllocationBaseline;
        }
        NSString *documents=EngineDocuments();
        uint64_t free=[[[NSFileManager defaultManager]attributesOfFileSystemForPath:documents error:nil][NSFileSystemFreeSize]unsignedLongLongValue];
        double elapsed=_preparationPayloadStarted>0?now-_preparationPayloadStarted:0;
        if(!RWPreparationMayTransfer(_preparationPayload,_preparationAllocation,free,elapsed,RWPreparationByteBudget))_preparationStopped=YES;
    }
    if(_preparationPayloadHash)for(auto &probe:_probes){auto &n=*probe;
        if([_preparationPayloadHash isEqual:n.source[@"infoHash"]]&&[self preparationPrefixFinished:&n]){
            // All requested pieces are complete, so releasing this owner does
            // not leave a second payload transfer outstanding. Keep its handle,
            // parsed header and verified cache for a later same-engine handoff.
            n.preparationPrefixFinished=true;n.handle.set_flags(lt::torrent_flags::upload_mode);_preparationPayloadHash=nil;break;
        }
    }
    if(_preparationPayloadAllowed&&!_preparationStopped&&!_preparationPayloadHash){
        double best=-1;NativeTorrent *choice=nullptr;
        for(auto &probe:_probes){auto &n=*probe;if(!n.info||n.selected<0||!n.error.empty()||n.preparationPartfile||n.preparationPrefixFinished)continue;
            auto status=n.handle.status();if(status.num_peers<=0||status.state==lt::torrent_status::checking_files||status.state==lt::torrent_status::checking_resume_data)continue;
            auto plan=RWPrepareOpening(n.fileOffset,n.size,n.info->piece_length(),RWPreparationByteBudget-_preparationPayload);
            if(!plan.allowed)continue;
            uint64_t missing=0;int available=INT_MAX;std::vector<int> counts;n.handle.piece_availability(counts);
            for(int p=plan.first;p<=plan.last;p++)if(!n.handle.have_piece(lt::piece_index_t(p))){missing+=n.info->piece_size(lt::piece_index_t(p));if(p<int(counts.size()))available=std::min(available,counts[size_t(p)]);}
            if(available==0)continue;
            double score=1000000./(1.+double(missing)/(1024*1024))+std::max(0.,std::min(500.,[n.source[@"score"]doubleValue]));
            if(score>best){best=score;choice=&n;}
        }
        if(choice)_preparationPayloadHash=choice->source[@"infoHash"];
    }
    for(auto &probe:_probes){auto &n=*probe;
        bool transfer=_preparationPayloadAllowed&&!_preparationStopped&&[_preparationPayloadHash isEqual:n.source[@"infoHash"]]&&!n.prioritiesPending;
        if(transfer)n.handle.unset_flags(lt::torrent_flags::upload_mode);else n.handle.set_flags(lt::torrent_flags::upload_mode);
    }
}
- (NSDictionary *)preparationSnapshot {
    NSMutableArray *durationReads=[NSMutableArray new];
    for(const auto &probe:_probes){if(durationReads.count>=2)break;auto &n=*probe;
        NSMutableArray *pieces=[NSMutableArray new];for(const auto &entry:n.readsByPiece){if(pieces.count>=64)break;[pieces addObject:@(entry.first)];}
        [durationReads addObject:@{@"infoHash":n.source[@"infoHash"]?:@"",@"duration_seconds":@(n.containerDuration),@"prefix_finished":@(n.preparationPrefixFinished),@"header_bytes_returned":@(n.deliveredReadBytes),@"verified_read_bytes":@(n.verifiedReadBytes),@"verified_piece_indices":pieces,@"duration_headers":@(n.durationProbe?n.durationProbe->headers():0),@"duration_state":!n.durationProbe?@"absent":n.durationProbe->state()==RWMediaDuration::Known?@"known":n.durationProbe->state()==RWMediaDuration::Waiting?@"waiting":@"unavailable"}];
    }
    return @{@"session_id":_sessionID?:@"",@"torrent_start_count":@(_torrentStartCount),@"active":@(_preparing),@"elapsed_seconds":@(_preparationStarted>0?NSProcessInfo.processInfo.systemUptime-_preparationStarted:0),@"payload_bytes":@(_preparationPayload),@"allocated_growth_bytes":@(_preparationAllocation),@"payload_budget_bytes":@(RWPreparationByteBudget),@"payload_allowed":@(_preparationPayloadAllowed),@"budget_stopped":@(_preparationStopped),@"payload_source":_preparationPayloadHash?:@"",@"metadata_probe_limit":@2,@"payload_probe_limit":@1,@"duration_reads":durationReads,@"discovery":_lastDiscovery?:@{}};
}
- (BOOL)adoptPreparation {
    if(!_preparing||!_native||!_native->session||!_discovering)return NO;
    _preparing=NO;double now=NSProcessInfo.processInfo.systemUptime;_raceStarted=now;_pausedAt=0;
    _native->session->resume();
    for(auto &probe:_probes){auto &n=*probe;n.connectionBegan=now;n.lastData=now;n.lastCheckProgressAt=now;
        // Recompute the measurement piece if the bounded prefix is now cached.
        // The torrent handle, connections, metadata and verified pieces remain.
        if(n.info&&n.selected>=0){n.prioritiesPending=true;n.probePieces.clear();n.probeHeadCount=0;}
    }
    [self fillDiscovery];return YES;
}
