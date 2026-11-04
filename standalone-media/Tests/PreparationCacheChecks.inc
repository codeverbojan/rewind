// Same production engine and isolated seed as the handoff test. Only generated
// bytes are cached; a successful hash check, rather than file size, proves reuse.
if(const char *cacheMode=getenv("REWIND_ENGINE_CACHE_MODE")){
    NSString *mode=@(cacheMode);BOOL partial=[mode isEqual:@"partial"],complete=[mode isEqual:@"complete"],cancel=[mode isEqual:@"cancel"];
    if(![@[@"metadata",@"partial",@"complete",@"cancel"]containsObject:mode])throw std::runtime_error("Invalid cache mode");
    NSString *metadata=[client stringByAppendingPathComponent:@"TorrentMetadata"];
    NSString *directory=[[client stringByAppendingPathComponent:@"Torrents"]stringByAppendingPathComponent:hex];
    for(NSString *path in @[metadata,directory])[[NSFileManager defaultManager]createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    std::vector<char> torrentBytes;lt::bencode(std::back_inserter(torrentBytes),builder.generate());
    check([[NSData dataWithBytes:torrentBytes.data() length:torrentBytes.size()]writeToFile:[metadata stringByAppendingPathComponent:[hex stringByAppendingPathExtension:@"torrent"]] atomically:YES],"Saved metadata fixture is written");
    if(partial||complete){
        NSString *path=[directory stringByAppendingPathComponent:@"fixture.mp4"];
        FILE *file=std::fopen(path.fileSystemRepresentation,"wb");if(!file)throw std::runtime_error("Cannot create cache fixture");
        bool wrote=true;for(int i=0;i<(complete?pieceCount:2);i++)if(std::fwrite(bytes.data(),1,bytes.size(),file)!=bytes.size())wrote=false;
        if(ftruncate(fileno(file),64LL*1024*1024)!=0)wrote=false;
        if(std::fclose(file)!=0)wrote=false;
        check(wrote,"Cache fixture writes verified prefix/full file with correct logical size");
    }
    NSDictionary *candidate=source;
    if(complete){
        seed.pause();NSMutableDictionary *offline=[source mutableCopy];
        offline[@"url"]=[NSString stringWithFormat:@"magnet:?xt=urn:btih:%@",hex];candidate=offline;
    }
    EngineOwner owner{[TorrentEngine new]};TorrentEngine *engine=owner.engine;
    struct CacheReadings{__strong NSDictionary *race=nil,*prep=nil,*snapshot=nil,*initial=nil;__strong NSData *read=nil;};
    CacheReadings readings;CacheReadings *v=&readings;
    auto poll=[&]{work(engine,^{v->race=[engine discoverySnapshot];v->prep=[engine preparationSnapshot];});};
    work(engine,^{[engine startPreparingCandidates:@[candidate]];});
    bool metadataReady=waitFor([&]{poll();NSDictionary *first=[v->race[@"candidates"]firstObject];
        if([first[@"metadata"]boolValue]&&![first[@"local_checking"]boolValue]){v->initial=first;return true;}return false;},10);
    check(metadataReady,"Saved metadata and existing files finish initial verification");
    check([v->initial[@"cache_at_start"][@"metadata_available"]boolValue],"Engine recognizes hash-verified cached metadata");
    check([v->prep[@"payload_bytes"]longLongValue]==0,"Saved-cache inspection does not request speculative payload");
    if(partial||complete)check([v->initial[@"cache_at_start"][@"allocated_video_bytes"]longLongValue]>0,"Existing video allocation is reported separately from network payload");
    if(cancel){
        work(engine,^{[engine setPreparationPayloadAllowed:YES];});
        bool ready=waitFor([&]{poll();return [v->race[@"prepared_ready"]boolValue];},25);
        check(ready,"Cancelled preparation first acquires a verified bounded opening");
        work(engine,^{[engine shutdown];});
        check([[NSFileManager defaultManager]fileExistsAtPath:[directory stringByAppendingPathComponent:@"rewind.resume"]],"Cancellation checkpoints reusable progress");
        owner.engine=[TorrentEngine new];engine=owner.engine;
        work(engine,^{[engine startPreparingCandidates:@[candidate]];});
        check(waitFor([&]{poll();NSDictionary *first=[v->race[@"candidates"]firstObject];
            return [first[@"metadata"]boolValue]&&![first[@"local_checking"]boolValue];},10),"A new engine reopens the cancelled preparation cache");
        NSDictionary *reopened=[v->race[@"candidates"]firstObject];
        check([reopened[@"cache_at_start"][@"resume_loaded"]boolValue],"Reopened preparation restores bounded resume data");
    }
    __block BOOL adopted=NO;double pressed=now();work(engine,^{adopted=[engine adoptPreparation];});
    check(adopted,"Play adopts a prepared engine with saved cache state");
    bool selected=waitFor([&]{poll();return [v->race[@"selected"]boolValue];},35);
    check(selected,"Saved-cache candidate qualifies without an unnecessary restart");
    bool readable=false;
    if(selected)readable=waitFor([&]{work(engine,^{[engine prioritizeOffset:0 length:65536];v->read=[engine readVerifiedBytesAt:0 length:65536];v->snapshot=[engine snapshot];});return v->read.length==65536;},5);
    check(readable&&((const char *)v->read.bytes)[0]=='R',"Player reads validated fixture bytes from the selected cache");
    if(complete){
        check([v->snapshot[@"peer_payload_bytes"]longLongValue]==0,"A complete verified cache plays without downloading payload");
        check([v->race[@"peers"]integerValue]==0,"Offline complete-cache qualification requires no peers or seed-count hint");
    }
    // libtorrent reports every piece wanted for an already-complete seed;
    // none of those bytes require transfer. Check the outstanding request bound.
    long long outstanding=MAX(0,[v->snapshot[@"wanted_bytes"]longLongValue]-[v->snapshot[@"wanted_done_bytes"]longLongValue]);
    check(outstanding<=[v->snapshot[@"playback_wanted_byte_bound"]longLongValue],"Outstanding wanted bytes respect the decoder read-window budget");
    if(complete)check(outstanding==0,"Complete cached data creates no outstanding transfer requests");
    NSDictionary *result=@{@"event":@"cache_check",@"mode":mode,@"piece_mib":@(pieceMiB),@"checks":@(checks),@"failures":@(failures),@"tap_to_readable_seconds":@(now()-pressed),@"payload_bytes":v->snapshot[@"peer_payload_bytes"]?:@0,@"cache_at_start":v->initial[@"cache_at_start"]?:@{},@"scope":@"Generated host fixture; not a physical iPad filesystem or decoder test"};
    NSData *json=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];std::printf("%s\n",[[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding].UTF8String);std::fflush(stdout);
    if(failures){NSData *debug=[NSJSONSerialization dataWithJSONObject:v->race?:@{} options:0 error:nil];std::fprintf(stderr,"Cache diagnostic: %s\n",[[NSString alloc]initWithData:debug encoding:NSUTF8StringEncoding].UTF8String);}
    return failures?1:0;
}
