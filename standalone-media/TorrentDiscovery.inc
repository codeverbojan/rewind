// All candidates share one libtorrent session, 40 connections and its disk cache.
- (NSDictionary *)selectedSource { return _selectedSource; }
- (void)startCandidates:(NSArray *)sources {[self startCandidates:sources preparing:NO];}
- (void)startPreparingCandidates:(NSArray *)sources {[self startCandidates:sources preparing:YES];}
- (void)startCandidates:(NSArray *)sources preparing:(BOOL)preparing {
    [self endDiscoveryFocus:@"new_race" now:NSProcessInfo.processInfo.systemUptime];_focusAttempted=NO;_focusHash=nil;_focusEvents=[NSMutableArray new];
    _preparing=preparing;_preparationPayloadAllowed=NO;_preparationStopped=NO;_preparationPayloadHash=nil;
    _preparationStarted=NSProcessInfo.processInfo.systemUptime;_preparationPayloadStarted=0;_preparationDiskChecked=0;
    _preparationPayload=_preparationAllocation=_preparationRetiredPayload=_preparationRetiredAllocation=0;
    [self cancelSubtitle];_raceGeneration++;for(NSURLSessionTask *task in _metadataTasks)[task cancel];
    _metadataTasks=[NSMutableArray new];
    if(_native->session){for(auto &probe:_probes){[self checkpoint:probe.get() seconds:.25];_native->session->remove_torrent(probe->handle);}if(_native->handle.is_valid()){[self checkpoint:_native seconds:.5];_native->session->remove_torrent(_native->handle);}}
    _probes.clear();auto session=_native->session;delete _native;_native=new NativeTorrent();_native->session=session;
    _raceQueue=[NSMutableArray new];_raceHashes=[NSMutableSet new];_raceFailures=[NSMutableArray new];_raceIndex=0;
    _pausedAt=0;_raceStarted=NSProcessInfo.processInfo.systemUptime;_discovering=YES;_selectedSource=nil;_lastDiscovery=nil;
    [self configurePeerRetryForPlayback:NO];
    [self appendCandidates:sources];[self fillDiscovery];
}
- (void)appendCandidates:(NSArray *)sources {
    if(!_discovering)return;
    RWAdmitSources(_raceQueue,_raceHashes,_raceIndex,sources);
    for(auto &probe:_probes){NSString *key=RWSourceCandidateKey(probe->source);
        for(NSDictionary *source in _raceQueue)if([RWSourceCandidateKey(source)isEqual:key]){
            NSDictionary *old=probe->source;probe->source=RWMergeSourceHints(old,source);
            if(!old[@"metadataURL"]&&probe->source[@"metadataURL"])[self fetchMetadataFor:probe->source handle:probe->handle];break;
        }
    }
}
- (void)fetchMetadataFor:(NSDictionary *)source handle:(lt::torrent_handle)handle {
    NSString *text=source[@"metadataURL"];if(![text isKindOfClass:NSString.class])return;
    NSURL *url=[NSURL URLWithString:text];
    if(![url.scheme isEqual:@"https"]||![url.host isEqual:@"yts.gg"]||![url.path hasPrefix:@"/torrent/download/"])return;
    NSUInteger generation=_raceGeneration;__weak TorrentEngine *weak=self;
    NSURLRequest *request=[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:6];
    NSURLSessionDataTask *task=[[NSURLSession sharedSession]dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        if(error||data.length==0||data.length>2*1024*1024||![response isKindOfClass:NSHTTPURLResponse.class]||[(NSHTTPURLResponse *)response statusCode]!=200)return;
        dispatch_async(MediaCleanupQueue(),^{
            TorrentEngine *engine=weak;if(!engine||engine->_raceGeneration!=generation||!engine->_native||!handle.is_valid())return;
            try{lt::error_code ec;lt::torrent_info info((const char *)data.bytes,int(data.length),ec);
                if(ec||info.info_hash()!=handle.info_hash())return;
                handle.set_metadata({info.metadata().get(),info.metadata_size()});
                for(auto &probe:engine->_probes)if(probe->handle==handle)probe->metadataSource="Hash-verified YTS torrent metadata";
            }catch(const std::exception &){}
        });
    }];[_metadataTasks addObject:task];[task resume];
}
- (void)fillDiscovery {
    if(!_discovering)return;
    while(_probes.size()<(_preparing?2:3)&&_raceIndex<_raceQueue.count){
        // Different files in one hash must share the session safely, never
        // race two handles that would overwrite the same piece priorities.
        NSUInteger next=_raceIndex;
        for(;next<_raceQueue.count;next++){
            NSString *hash=_raceQueue[next][@"infoHash"];bool active=false;
            for(const auto &probe:_probes)if([probe->source[@"infoHash"]isEqual:hash]){active=true;break;}
            if(!active)break;
        }
        if(next==_raceQueue.count)break;
        if(next!=_raceIndex)[_raceQueue exchangeObjectAtIndex:next withObjectAtIndex:_raceIndex];
        NSDictionary *source=_raceQueue[_raceIndex++];auto probe=std::unique_ptr<NativeTorrent>(new NativeTorrent());
        probe->session=_native->session;probe->probing=true;probe->source=source;
        NativeTorrent *owner=_native;_native=probe.get();NSString *error=nil;BOOL ok=NO;
        @try{ok=[self startMagnet:source[@"url"] fileIndex:[source[@"fileIdx"]isKindOfClass:NSNumber.class]?[source[@"fileIdx"]intValue]:-1 publicTest:([source[@"publicTest"]isKindOfClass:NSNumber.class]&&[source[@"publicTest"]boolValue]) error:&error];}
        @finally{_native=owner;}
        if(!owner->session)owner->session=probe->session;
        if(!ok){[_raceFailures addObject:@{@"infoHash":source[@"infoHash"],@"reason":error?:@"Invalid source"}];continue;}
        [self holdProbeDuringFocus:probe.get()];lt::torrent_handle handle=probe->handle;_probes.push_back(std::move(probe));[self fetchMetadataFor:source handle:handle];
    }
}
- (void)updateDurationProbe:(NativeTorrent *)probe {
    if(!probe||!probe->durationProbe)return;auto &n=*probe;auto &duration=*n.durationProbe;
    // Preparation may interpret its already downloaded prefix. It must never
    // request another piece (particularly a closing MP4 index), or do work for
    // an unadmitted/retired preparation. Handoff retains these verified bytes.
    if(_preparing&&(!_preparationPayloadAllowed||_preparationStopped||![_preparationPayloadHash isEqual:n.source[@"infoHash"]]))return;
    for(int step=0;step<4&&duration.state()==RWMediaDuration::Waiting;step++){
        uint64_t offset=duration.offset()+n.durationBytes.length;size_t needed=duration.length()-n.durationBytes.length;
        if(offset>=uint64_t(n.size)||!needed){duration.unavailable();break;}
        int piece=int((n.fileOffset+int64_t(offset))/n.info->piece_length());auto index=lt::piece_index_t(piece);
        if(_preparing&&(std::find(n.probePieces.begin(),n.probePieces.end(),piece)==n.probePieces.end()||!n.handle.have_piece(index)))break;
        if(std::find(n.probePieces.begin(),n.probePieces.end(),piece)==n.probePieces.end()){
            uint64_t cost=n.handle.have_piece(index)?0:uint64_t(n.info->piece_size(index));
            if(n.probeRequestedBytes>RWProbeTransferBudget||cost>RWProbeTransferBudget-n.probeRequestedBytes){duration.unavailable();break;}
            n.probeRequestedBytes+=cost;n.probePieces.push_back(piece);n.enabledProbePieces=int(n.probePieces.size());
            n.handle.piece_priority(index,lt::default_priority);if(cost)n.handle.set_piece_deadline(index,0);
        }
        NativeTorrent *owner=_native;_native=&n;NSData *bytes=nil;
        @try{bytes=[self readGlobal:n.fileOffset+int64_t(offset) available:n.size-int64_t(offset) length:needed];}@finally{_native=owner;}
        if(!bytes.length)break;[n.durationBytes appendData:bytes];
        if(n.durationBytes.length==duration.length()){
            duration.consume((const uint8_t *)n.durationBytes.bytes,n.durationBytes.length);[n.durationBytes setLength:0];
        }
    }
    if(duration.state()==RWMediaDuration::Known)n.containerDuration=duration.seconds();
}
- (NSDictionary *)discoverySnapshot {
    if(!_discovering)return _lastDiscovery?:@{};
    try {
    [self pollAlerts];double now=NSProcessInfo.processInfo.systemUptime;if(_preparing)[self updatePreparationBudget];[self updateDiscoveryFocus:now];
    NSMutableArray *live=[NSMutableArray new];int winner=-1;double best=-1;int totalPeers=0,totalRate=0;
    NSDictionary *transportLimits=_transportDiagnostics&&_native->session?RWPeerTransport::SessionLimits(*_native->session):@{};
    for(size_t i=0;i<_probes.size();){
        auto &n=*_probes[i];auto status=n.handle.status();
        int connectionLimit=RWProbeConnections::Target(_preparing,status.connections_limit,status.num_connections,status.connect_candidates);
        if(connectionLimit!=status.connections_limit)n.handle.set_max_connections(connectionLimit);
        NSDictionary *transport=_transportDiagnostics?RWPeerTransport::Capture(n.handle,transportLimits):@{};
        bool checking=status.state==lt::torrent_status::checking_files||status.state==lt::torrent_status::checking_resume_data;
        RWPeerEvidence::SetProbeTurnover(n.handle,!_preparing&&!checking&&!n.focusHeld&&status.has_metadata&&now-n.connectionBegan>=10&&status.connections_limit==13&&status.num_connections>=13&&status.connect_candidates>0&&status.total_payload_download==0);
        // File verification prevents announcements. Its time cannot also count
        // as an idle network, but it remains inside the overall discovery limit.
        if(checking){n.lastData=now;n.connectionBegan=now;
            if(status.progress!=n.lastCheckProgress){n.lastCheckProgress=status.progress;n.lastCheckProgressAt=now;}
        }
        if(status.num_peers>0&&n.firstPeer<0){n.firstPeer=now-n.started;n.lastData=now;}
        if(status.has_metadata&&!n.info){n.info=n.handle.torrent_file();NativeTorrent *owner=_native;_native=&n;
            @try{[self selectVideo];}@finally{_native=owner;}
            if(n.metadataSource=="waiting for peers")n.metadataSource="BitTorrent peer metadata exchange";
            n.lastData=now;
            n.metadataSeen=now-n.started;
        }
        if(n.prioritiesPending){NativeTorrent *owner=_native;_native=&n;@try{[self activateVideo];}@finally{_native=owner;}}
        // Keep the test supplied with work. Completing the original tiny
        // request must not turn an otherwise healthy peer into a zero-rate
        // sample. Preparation retains its separate, smaller prefix policy.
        status=n.handle.status();
        // Start the asynchronous verified header read as soon as its piece is
        // available. Waiting for the complete opening/rate test wastes a poll
        // and can reject a source using an inaccurate catalog runtime first.
        if(!checking&&!n.focusHeld&&!n.prioritiesPending&&n.info&&n.selected>=0&&n.error.empty()&&n.durationProbe)
            [self updateDurationProbe:&n];
        double duration=n.containerDuration>0?n.containerDuration:[n.source[@"durationHintSeconds"]doubleValue];
        double required=n.containerDuration>0?double(n.size)/n.containerDuration:RWRequiredStreamRate(uint64_t(std::max<int64_t>(0,n.size)),duration);
        int64_t outstanding=std::max<int64_t>(0,status.total_wanted-status.total_wanted_done);
        if(!_preparing&&!n.focusHeld&&!checking&&!n.prioritiesPending&&n.info&&n.selected>=0&&n.probeNextPiece>=0){
            int videoLast=int((n.fileOffset+n.size-1)/n.info->piece_length());
            std::vector<std::pair<lt::piece_index_t,lt::download_priority_t>> extra;
            uint64_t wanted=uint64_t(outstanding);
            while(n.probeNextPiece<=videoLast){
                int piece=n.probeNextPiece;
                if(n.handle.have_piece(lt::piece_index_t(piece))||std::find(n.probePieces.begin(),n.probePieces.end(),piece)!=n.probePieces.end()){n.probeNextPiece++;continue;}
                uint64_t bytes=uint64_t(n.info->piece_size(lt::piece_index_t(piece)));
                if(!RWProbeMayExtend(n.probeRequestedBytes,wanted,bytes,required))break;
                n.probeNextPiece++;n.probeRequestedBytes+=bytes;wanted+=bytes;
                n.probePieces.push_back(piece);extra.emplace_back(lt::piece_index_t(piece),lt::default_priority);
            }
            if(!extra.empty()){
                n.handle.prioritize_pieces(extra);
                for(const auto &piece:extra)n.handle.set_piece_deadline(piece.first,1000);
                n.enabledProbePieces=int(n.probePieces.size());
                // A deliberate idle interval is not evidence of a bad swarm.
                // Restart the sample once there is work again, preserving all
                // connections and cached bytes and the overall time limit.
                if(outstanding==0&&now-n.lastData>=3){n.transfer=RWTransferWindow();n.lastData=now;}
                status=n.handle.status();outstanding=std::max<int64_t>(0,status.total_wanted-status.total_wanted_done);
            }
        }
        if((status.total_payload_download>n.resumePayload||(checking&&n.lastCheckProgressAt>n.resumeSavedAt))&&now-n.resumeSavedAt>=5)[self requestResume:&n];
        if(status.total_payload_download>n.lastPayload){n.lastPayload=status.total_payload_download;n.lastData=now;if(n.firstPayload<0)n.firstPayload=now-n.started;}
        bool ready=n.info&&n.probeHeadCount>0;int64_t verified=0,openingTotal=0;size_t pIndex=0;
        for(int piece:n.probePieces){bool have=n.handle.have_piece(lt::piece_index_t(piece));int bytes=n.info->piece_size(lt::piece_index_t(piece));if(pIndex++<n.probeHeadCount){ready=ready&&have;openingTotal+=bytes;if(have)verified+=bytes;}}
        if(ready&&n.firstOpening<0)n.firstOpening=now-n.started;
        std::vector<int64_t> progress;if(ready&&n.selected>=0)n.handle.file_progress(progress,lt::torrent_handle::piece_granularity);
        bool complete=n.size>0&&n.selected>=0&&n.selected<int(progress.size())&&progress[n.selected]>=n.size;
        double elapsed=now-n.started;
        n.timing.observe(now,checking,n.focusHeld,status.has_metadata,status.num_peers>0,status.total_payload_download>0,ready);
        double rate=n.transfer.observe(now,status.total_payload_download);
        double measured=n.transfer.measuredSeconds();
        // Count opening blocks, including restored partial blocks, rather than
        // cumulative traffic (which can include duplicates or measurement data).
        int64_t received=verified;std::vector<lt::partial_piece_info> partial;
        if(n.info&&!ready){n.handle.get_download_queue(partial);
            for(const auto &piece:partial){auto end=n.probePieces.begin()+n.probeHeadCount;
                if(std::find(n.probePieces.begin(),end,int(piece.piece_index))==end||n.handle.have_piece(piece.piece_index))continue;
                for(int block=0;block<piece.blocks_in_piece;block++){
                    auto &b=piece.blocks[block];received+=b.state==lt::block_info::finished||b.state==lt::block_info::writing?b.block_size:b.bytes_progress;
                }
            }
        }
        uint64_t missing=uint64_t(std::max<int64_t>(0,openingTotal-received));
        if(n.info&&now-n.availabilityAt>=2){
            n.availabilityAt=now;n.openingAvailability=-1;std::vector<int> availability;n.handle.piece_availability(availability);
            for(size_t p=0;p<n.probeHeadCount;p++){int piece=n.probePieces[p];if(n.handle.have_piece(lt::piece_index_t(piece)))continue;
                if(piece>=0&&size_t(piece)<availability.size())n.openingAvailability=n.openingAvailability<0?availability[size_t(piece)]:std::min(n.openingAvailability,availability[size_t(piece)]);
            }
        }
        // status already includes the verified-piece bitfield. Read this one
        // snapshot rather than making a synchronous libtorrent call per piece.
        uint64_t verifiedVideo=ready?RWVerifiedPrefix(n.fileOffset,uint64_t(n.size),n.info->piece_length(),[&](int64_t piece){return piece>=0&&piece<status.pieces.size()&&status.pieces[lt::piece_index_t(int(piece))];}):0;
        double transferETA=RWStartupTransferETA(missing,verifiedVideo,required,rate);
        bool durationWaiting=n.durationProbe&&n.durationProbe->state()==RWMediaDuration::Waiting;
        uint64_t openingEnd=n.info&&n.probeHeadCount?uint64_t(std::max<int64_t>(0,(int64_t(n.probePieces[n.probeHeadCount-1])+1)*n.info->piece_length()-n.fileOffset)):0;
        // Finish interpreting the header already needed for playback. A known
        // catalog estimate remains a fallback if duration is elsewhere (e.g.
        // a tail moov); that optional lookup must not hold a healthy source.
        bool durationPending=durationWaiting&&(RWRequiredStreamRate(uint64_t(std::max<int64_t>(0,n.size)),[n.source[@"durationHintSeconds"]doubleValue])<=0||(!_preparing&&n.durationProbe->offset()<openingEnd));
        // Retained pre-focus history must not qualify on just the first
        // capacity spike after competitors are held. Observe that allocation
        // for at least the ordinary minimum two seconds as well.
        bool focusObserved=!_focusHash||![n.source[@"infoHash"]isEqual:_focusHash]||now-_focusStarted>=2;
        bool healthy=RWStreamingReady(ready,complete,status.num_peers,rate,required,measured,verifiedVideo)&&(!n.focusHeld||complete)&&(!durationPending||complete)&&(focusObserved||complete);
        double score=RWReadinessScore(healthy,complete,transferETA,rate,required,[n.source[@"score"]doubleValue]);
        double remaining=std::max(0.,RWDiscoveryLimitSeconds-(now-_raceStarted));
        bool rawCanFinish=RWCanFinishOpening(measured,rate,required,missing,remaining,now-n.lastData);
        // A focus changes the competing bandwidth allocation. Old observations
        // remain useful for readiness, but cannot reject that experiment before
        // the same four-second window used by its unproductive-focus policy.
        bool capacityObserved=!_focusHash||![_focusHash isEqual:n.source[@"infoHash"]]||now-_focusStarted>=RWProbeFocusObservationSeconds;
        // Focus already distinguishes a recovering rate from an unproductive
        // connection. Apply that same decision here, with the current sample,
        // instead of bypassing it through the ordinary slow-source branch.
        bool focusRateRejected=!_focusHash||![_focusHash isEqual:n.source[@"infoHash"]]||
            RWProbeFocusUnproductive(now-_focusStarted,measured,rate,required,[_focusEvents.lastObject[@"previous_rate"]doubleValue]);
        bool rateTooSlow=capacityObserved&&focusRateRejected&&!durationPending&&measured>=8&&rate>0&&required>0&&rate<required*.65;
        bool forecastLate=capacityObserved&&measured>=8&&rate>0&&double(missing)/rate>remaining;
        // A single noisy ETA must not discard our final healthy connection.
        // Alternatives retain ordinary queue/race scheduling. Four seconds is
        // one existing rate-estimation window, inside the unchanged100s limit.
        bool finalViable=_probes.size()==1&&_raceIndex>=_raceQueue.count&&!_preparing&&
            !checking&&!n.focusHeld&&!n.prioritiesPending&&n.openingAvailability>0&&
            measured>=8&&required>0&&rate>=required*1.25&&now-n.lastData<3;
        auto forecast=n.openingEstimate.observe(now,rawCanFinish,forecastLate,finalViable);
        bool canFinish=forecast.canFinish;
        bool expired=!_preparing&&!n.focusHeld&&(checking?RWLocalCheckExpired(elapsed,now-n.lastCheckProgressAt,remaining):RWProbeExpired(now-n.connectionBegan,status.has_metadata,status.num_peers,now-n.lastData,canFinish));
        bool tooSlow=!_preparing&&!n.focusHeld&&!complete&&!checking&&outstanding>0&&(rateTooSlow||forecast.lateConfirmed);
        if(status.errc)n.error=status.errc.message();
        if(!n.error.empty()||tooSlow||(score<0&&expired)){
            NSString *reason=!n.error.empty()?@(n.error.c_str()):tooSlow?@"Measured transfer is too slow for this video or its opening pieces":checking?@"Local cached-file verification exceeded the discovery window":@"No usable startup data before the discovery deadline";
            [_raceFailures addObject:@{@"infoHash":n.source[@"infoHash"],@"timing":ProbeTiming(n),@"peer_discovery":RWPeerEvidence::Snapshot(n.handle),@"transport":transport,@"fileIdx":n.source[@"fileIdx"]?:@(-1),@"filename":n.source[@"filename"]?:@"",@"failure_scope":n.fileIdentityFailure?@"file":@"swarm",@"reason":reason,@"local_checking":@(checking),@"torrent_progress":@(status.progress),@"network_elapsed":@(now-n.connectionBegan),@"resume_loaded":@(n.resumeLoaded),@"resume_pending":@(n.resumePending),@"resume_writes":@(n.resumeWrites),@"resume_error":@(n.resumeError.c_str()),@"opening_received_bytes":@(received),@"opening_missing_bytes":@(missing),@"opening_eta_seconds":@(rate>0?double(missing)/rate:-1),@"startup_transfer_eta_seconds":@(transferETA),@"verified_prefix_bytes":@(verifiedVideo),@"opening_piece_min_availability":@(n.openingAvailability),@"rate_sample_seconds":@(measured),@"probe_outstanding_bytes":@(outstanding),@"probe_requested_byte_bound":@(n.probeRequestedBytes),@"probe_transfer_budget":@(RWProbeTransferBudget),@"progress_extension":@(canFinish),@"opening_forecast_raw_can_finish":@(rawCanFinish),@"opening_forecast_raw_late":@(forecastLate),@"opening_forecast_final_viable":@(finalViable),@"opening_forecast_adverse_seconds":@(forecast.adverseSeconds),@"opening_forecast_good_age":@(forecast.goodAge),@"piece_bytes":@(n.info?n.info->piece_length():0),@"video_bytes":@(n.size),@"torrent_bytes":@(n.info?n.info->total_size():0),@"file_count":@(n.info?n.info->num_files():0),@"duration_seconds":@(duration),@"duration_basis":n.containerDuration>0?@"Verified container duration":required>0?@"Catalog runtime estimate":@"Unknown",@"duration_probe_state":!n.durationProbe?@"not_needed":n.durationProbe->state()==RWMediaDuration::Known?@"known":n.durationProbe->state()==RWMediaDuration::Waiting?@"waiting":@"unavailable",@"required_bytes_per_second_estimate":@(required),@"measured_bytes_per_second":@(rate),@"elapsed":@(elapsed),@"peers":@(status.num_peers),@"metadata":@(status.has_metadata),@"tracker_count":@(n.handle.trackers().size()),@"tracker_error":@(n.trackerError.c_str()),@"payload_bytes":@(status.total_payload_download)}];
            if(_preparing){_preparationRetiredPayload+=std::max<int64_t>(0,status.total_payload_download);uint64_t allocated=[RWMediaCache allocatedBytesAt:@(n.directory.c_str())];_preparationRetiredAllocation+=allocated>n.preparationAllocationBaseline?allocated-n.preparationAllocationBaseline:0;if([_preparationPayloadHash isEqual:n.source[@"infoHash"]])_preparationPayloadHash=nil;}
            if(n.focusControlled){n.handle.set_download_limit(n.focusOriginalLimit);n.focusControlled=false;n.focusHeld=false;}
            [self checkpoint:&n seconds:.25];n.session->remove_torrent(n.handle);_probes.erase(_probes.begin()+i);continue;
        }
        totalPeers+=status.num_peers;totalRate+=status.download_payload_rate;
        [live addObject:@{@"infoHash":n.source[@"infoHash"],@"fileIdx":n.source[@"fileIdx"]?:@(-1),@"timing":ProbeTiming(n),@"peer_discovery":RWPeerEvidence::Snapshot(n.handle),@"transport":transport,@"provider":n.source[@"provider"]?:@"Source",@"quality":n.source[@"resolution"]?:@0,@"seeders_hint":n.source[@"seeders"]?:@0,@"tracker_seeds":@(status.num_complete),@"tracker_leechers":@(status.num_incomplete),@"piece_bytes":@(n.info?n.info->piece_length():0),@"video_bytes":@(n.size),@"torrent_bytes":@(n.info?n.info->total_size():0),@"local_checking":@(checking),@"torrent_progress":@(status.progress),@"network_elapsed":@(now-n.connectionBegan),@"resume_loaded":@(n.resumeLoaded),@"resume_pending":@(n.resumePending),@"resume_writes":@(n.resumeWrites),@"resume_error":@(n.resumeError.c_str()),@"opening_received_bytes":@(received),@"opening_missing_bytes":@(missing),@"opening_eta_seconds":@(rate>0?double(missing)/rate:-1),@"startup_transfer_eta_seconds":@(transferETA),@"verified_prefix_bytes":@(verifiedVideo),@"opening_piece_min_availability":@(n.openingAvailability),@"rate_sample_seconds":@(measured),@"probe_outstanding_bytes":@(outstanding),@"probe_requested_byte_bound":@(n.probeRequestedBytes),@"probe_transfer_budget":@(RWProbeTransferBudget),@"progress_extension":@(canFinish),@"opening_forecast_raw_can_finish":@(rawCanFinish),@"opening_forecast_raw_late":@(forecastLate),@"opening_forecast_final_viable":@(finalViable),@"opening_forecast_adverse_seconds":@(forecast.adverseSeconds),@"opening_forecast_good_age":@(forecast.goodAge),@"duration_seconds":@(duration),@"duration_basis":n.containerDuration>0?@"Verified container duration":required>0?@"Catalog runtime estimate":@"Unknown",@"duration_probe_state":!n.durationProbe?@"not_needed":n.durationProbe->state()==RWMediaDuration::Known?@"known":n.durationProbe->state()==RWMediaDuration::Waiting?@"waiting":@"unavailable",@"required_bytes_per_second_estimate":@(required),@"measured_bytes_per_second":@(rate),@"stream_margin":@(required>0?rate/required:0),@"focus_held":@(n.focusHeld),@"download_limit":@(n.handle.download_limit()),@"health":complete?@"Complete verified download":healthy?(required>0?@"Streaming speed verified":@"Opening ready; bitrate unknown"):tooSlow?@"Too slow":checking?@"Checking local data":@"Measuring live connection",@"seeds_connected":@(status.num_seeds),@"peers":@(status.num_peers),@"known_peers":@(status.list_peers),@"tracker_count":@(n.handle.trackers().size()),@"tracker_peers":@(n.trackerPeers),@"tracker_error":@(n.trackerError.c_str()),@"dht_peers":@(n.dhtPeers),@"metadata":@(status.has_metadata),@"metadata_source":@(n.metadataSource.c_str()),@"preparation_storage_blocked":@(n.preparationPartfile),@"cache_at_start":@{@"metadata_available":@(n.metadataAtStart),@"resume_loaded":@(n.resumeLoaded),@"allocated_video_bytes":@(n.allocatedAtStart),@"allocated_cache_bytes":@(n.allocatedCacheAtStart),@"disk_data_requires_validation":@(n.allocatedCacheAtStart>0)},@"bytes_per_second":@(status.download_payload_rate),@"payload_bytes":@(status.total_payload_download),@"startup_verified_bytes":@(verified),@"ready":@(ready),@"selectable":@(score>=0),@"video_complete":@(complete),@"announcing_to_trackers":@(status.announcing_to_trackers),@"announcing_to_dht":@(status.announcing_to_dht),@"waiting_for_file_priorities":@(n.prioritiesPending),@"enabled_probe_pieces":@(n.enabledProbePieces),@"opening_piece_count":@(n.probeHeadCount),@"elapsed":@(elapsed),@"first_peer_seconds":@(n.firstPeer),@"metadata_seconds":@(n.metadataSeen),@"first_payload_seconds":@(n.firstPayload),@"opening_verified_seconds":@(n.firstOpening)}];
        if(score>best){best=score;winner=int(i);}i++;
    }
    if(winner>=0&&!_preparing){
        [self endDiscoveryFocus:@"winner" now:now];
        // Keep every handle mapped while checkpointing dispatches alerts,
        // including a pending resume write for the winning connection.
        for(size_t i=0;i<_probes.size();i++)if(int(i)!=winner)[self checkpoint:_probes[i].get() seconds:.25];
        auto selected=std::move(_probes[size_t(winner)]);_probes.erase(_probes.begin()+winner);
        for(auto &probe:_probes)_native->session->remove_torrent(probe->handle);_probes.clear();
        delete _native;_native=selected.release();_native->probing=false;
        // Preserve the winning connection and verified pieces; no second magnet start.
        // The decoder extends a bounded read window, retaining verified data
        // without enabling the whole movie just because its opening won.
        _native->playbackWindowActive=true;_native->playbackWindow.clear();_native->playbackPieces.clear();
        _native->handle.clear_piece_deadlines();_native->handle.set_max_connections(40);
        RWPeerEvidence::SetProbeTurnover(_native->handle,false);
        NSMutableDictionary *resolved=[_native->source mutableCopy];resolved[@"resolvedFileIdx"]=@(_native->selected);resolved[@"resolvedFilename"]=@(_native->name.c_str());_selectedSource=[resolved copy];_discovering=NO;for(NSURLSessionTask *task in _metadataTasks)[task cancel];
        [self configurePeerRetryForPlayback:YES];
        // The measured MKV startup seeks the closing index after its header.
        // Request that small range only for the winner, overlapping the header
        // parse instead of waiting for VLC to block on the tail later.
        if([[@(_native->name.c_str()) pathExtension].lowercaseString isEqual:@"mkv"])
            _native->startupPrefetch.begin(_native->fileOffset,_native->size,_native->info->piece_length(),now);
        [self prioritizeOffset:0 length:2*1024*1024];
    }else if((!_preparing&&now-_raceStarted>=RWDiscoveryLimitSeconds)||(_probes.empty()&&_raceIndex>=_raceQueue.count)){
        [self endDiscoveryFocus:@"exhausted" now:now];for(auto &probe:_probes){[self checkpoint:probe.get() seconds:.25];_native->session->remove_torrent(probe->handle);}_probes.clear();_discovering=NO;
        for(NSURLSessionTask *task in _metadataTasks)[task cancel];
    }else [self fillDiscovery];
    _lastDiscovery=@{@"peer_retry_settings":[self peerRetrySettings],@"focus":@{@"attempted":@(_focusAttempted),@"active":@(_focusHash!=nil),@"events":[_focusEvents copy]?:@[]},@"session_id":_sessionID?:@"",@"torrent_start_count":@(_torrentStartCount),@"active":@(_discovering),@"selected":@(_selectedSource!=nil),@"exhausted":@(!_discovering&&!_selectedSource),@"elapsed":@(now-_raceStarted),@"checked":@(_raceIndex),@"total":@(_raceQueue.count),@"source_queue_limit":@(RWSourceAdmissionLimit),@"waiting_sources":@(_raceQueue.count-_raceIndex),@"peers":@(totalPeers),@"bytes_per_second":@(totalRate),@"candidates":live,@"failures":[_raceFailures copy],@"max_parallel":@(_preparing?2:3),@"preparing":@(_preparing),@"prepared_ready":@(winner>=0),@"session_count":@1,@"dht_state_loaded":@(_dhtStateLoaded),@"opening_probe_bytes":@(RWProbeHeadBytes(UINT64_MAX))};
    return _lastDiscovery;
    }catch(const std::exception &error){
        [self endDiscoveryFocus:@"error" now:NSProcessInfo.processInfo.systemUptime];
        for(auto &probe:_probes)if(probe->handle.is_valid())_native->session->remove_torrent(probe->handle);_probes.clear();_discovering=NO;
        for(NSURLSessionTask *task in _metadataTasks)[task cancel];
        _lastDiscovery=@{@"active":@NO,@"selected":@NO,@"exhausted":@YES,@"error":@(error.what())};return _lastDiscovery;
    }
}
