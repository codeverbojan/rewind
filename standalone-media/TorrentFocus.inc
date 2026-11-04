// All methods run on the engine queue. Limits belong to a single race and are
// restored before checkpointing/removing handles, on every exit path.
- (void)endDiscoveryFocus:(NSString *)reason now:(double)now {
    _focusTimerGeneration++;
    if(_focusTimer){dispatch_source_cancel(_focusTimer);_focusTimer=nil;}
    if(!_focusHash)return;
    for(auto &probe:_probes){auto &n=*probe;if(!n.focusControlled)continue;
        if(n.handle.is_valid())try{n.handle.set_download_limit(n.focusOriginalLimit);n.transfer=RWTransferWindow();n.transfer.observe(now,n.handle.status().total_payload_download);}catch(const std::exception &){}
        if(n.focusHeld){n.lastData=now;n.connectionBegan+=std::max(0.,now-_focusStarted);}
        n.focusHeld=false;n.focusControlled=false;
    }
    [_focusEvents addObject:@{@"event":@"ended",@"reason":reason,@"infoHash":_focusHash,@"seconds":@(std::max(0.,now-_focusStarted))}];_focusHash=nil;
}
- (void)holdProbeDuringFocus:(NativeTorrent *)n {
    if(!_focusHash||!n||[n->source[@"infoHash"]isEqual:_focusHash]||n->focusControlled)return;
    n->focusOriginalLimit=n->handle.download_limit();n->focusControlled=true;n->focusHeld=true;n->handle.set_download_limit(n->focusOriginalLimit>0?std::min(n->focusOriginalLimit,RWProbeHeldBytesPerSecond):RWProbeHeldBytesPerSecond);
}
- (void)updateDiscoveryFocus:(double)now {
    if(_preparing)return;
    if(_focusHash){BOOL present=NO;for(auto &n:_probes)if([n->source[@"infoHash"]isEqual:_focusHash])present=YES;
        if(!present||now-_focusStarted>=RWProbeFocusSeconds)[self endDiscoveryFocus:present?@"window_finished":@"candidate_removed" now:now];
        else for(NSDictionary *sample in _lastDiscovery[@"candidates"]){
            if(![sample[@"infoHash"]isEqual:_focusHash])continue;
            // This decision reads the previous poll. Use that observation's
            // age, not the newer wall clock, when judging the new allocation.
            double observed=std::max(0.,_raceStarted+[_lastDiscovery[@"elapsed"]doubleValue]-_focusStarted);
            if(RWProbeFocusUnproductive(observed,[sample[@"rate_sample_seconds"]doubleValue],[sample[@"measured_bytes_per_second"]doubleValue],[sample[@"required_bytes_per_second_estimate"]doubleValue],[_focusEvents.lastObject[@"previous_rate"]doubleValue]))[self endDiscoveryFocus:@"no_capacity_gain" now:now];
            break;
        }
        return;
    }
    NSArray *samples=_lastDiscovery[@"candidates"]?:@[];std::vector<RWFocusCandidate> inputs;
    for(NSDictionary *sample in samples){RWFocusCandidate p;p.valid=[sample[@"metadata"]boolValue]&&[sample[@"video_bytes"]longLongValue]>0&&! [sample[@"waiting_for_file_priorities"]boolValue];p.checking=[sample[@"local_checking"]boolValue];p.healthy=[sample[@"selectable"]boolValue];p.complete=[sample[@"video_complete"]boolValue];p.rate=[sample[@"measured_bytes_per_second"]doubleValue];p.required=[sample[@"required_bytes_per_second_estimate"]doubleValue];p.measured=[sample[@"rate_sample_seconds"]doubleValue];inputs.push_back(p);}
    int index=RWChooseProbeFocus(inputs,_preparing,_focusAttempted,RWDiscoveryLimitSeconds-(now-_raceStarted));if(index<0)return;
    NSString *chosen=samples[size_t(index)][@"infoHash"];NativeTorrent *focus=nullptr;for(auto &n:_probes)if([n->source[@"infoHash"]isEqual:chosen])focus=n.get();if(!focus)return;
    _focusAttempted=YES;_focusHash=chosen;_focusStarted=now;
    // Expiry must not depend on the UI's next discovery poll. A weak timer on
    // the existing engine queue never keeps an engine alive or affects a new
    // race after cancellation, selection or shutdown.
    NSUInteger ticket=++_focusTimerGeneration;__weak TorrentEngine *weak=self;
    _focusTimer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,MediaCleanupQueue());
    dispatch_source_set_timer(_focusTimer,dispatch_time(DISPATCH_TIME_NOW,(int64_t)(RWProbeFocusSeconds*NSEC_PER_SEC)),DISPATCH_TIME_FOREVER,NSEC_PER_MSEC);
    dispatch_source_set_event_handler(_focusTimer,^{
        TorrentEngine *engine=weak;if(!engine||engine->_focusTimerGeneration!=ticket||!engine->_focusHash)return;
        [engine endDiscoveryFocus:@"deadline" now:NSProcessInfo.processInfo.systemUptime];
    });
    dispatch_resume(_focusTimer);
    // The chosen connection's limit does not change. Its rolling window is
    // still valid (and below readiness at admission); discarding that measured
    // history adds another full observation period. Keep normal readiness and
    // rate smoothing. Restoring competitors still resets every window on exit.
    focus->focusOriginalLimit=focus->handle.download_limit();focus->focusControlled=true;
    for(auto &n:_probes)[self holdProbeDuringFocus:n.get()];
    if(!_focusEvents)_focusEvents=[NSMutableArray new];[_focusEvents addObject:@{@"event":@"started",@"infoHash":chosen,@"race_seconds":@(now-_raceStarted),@"previous_rate":samples[size_t(index)][@"measured_bytes_per_second"]?:@0,@"required_rate":samples[size_t(index)][@"required_bytes_per_second_estimate"]?:@0,@"held_limit":@(RWProbeHeldBytesPerSecond),@"window_seconds":@(RWProbeFocusSeconds)}];
}
