// A healthy seed must not be rejected because our own tiny probe finished
// before the minimum observation window. Poll at the iPad's one-second cadence.
if(const char *qualificationMode=getenv("REWIND_ENGINE_QUALIFICATION_MODE")){
    NSString *mode=@(qualificationMode);
    BOOL slow=[mode isEqual:@"slow"],cached=[mode isEqual:@"cached"];
    if(cached){
        NSString *metadata=[client stringByAppendingPathComponent:@"TorrentMetadata"];
        NSString *directory=[[client stringByAppendingPathComponent:@"Torrents"]stringByAppendingPathComponent:hex];
        for(NSString *path in @[metadata,directory])[[NSFileManager defaultManager]createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        std::vector<char> torrentBytes;lt::bencode(std::back_inserter(torrentBytes),builder.generate());
        check([[NSData dataWithBytes:torrentBytes.data() length:torrentBytes.size()]writeToFile:[metadata stringByAppendingPathComponent:[hex stringByAppendingPathExtension:@"torrent"]] atomically:YES],"Cached qualification metadata is saved");
        FILE *file=std::fopen([directory stringByAppendingPathComponent:@"fixture.mp4"].fileSystemRepresentation,"wb");
        if(!file)throw std::runtime_error("Cannot create qualification cache");
        bool wrote=true;for(int i=0;i<2;i++)if(std::fwrite(bytes.data(),1,bytes.size(),file)!=bytes.size())wrote=false;
        if(ftruncate(fileno(file),64LL*1024*1024)!=0)wrote=false;
        if(std::fclose(file)!=0)wrote=false;
        check(wrote,"Previously downloaded opening is materialized for the resume regression");
    }
    NSMutableDictionary *candidate=[source mutableCopy];
    candidate[@"durationHintSeconds"]=@(64.*1024*1024/(900*1024));
    EngineOwner owner{[TorrentEngine new]};TorrentEngine *engine=owner.engine;
    struct QualificationReadings {__strong NSDictionary *race=nil,*snapshot=nil;__strong NSData *read=nil;};
    QualificationReadings readings;QualificationReadings *v=&readings;
    double pressed=now();work(engine,^{[engine startCandidates:@[candidate]];});
    bool selected=false;double probePayload=0,maxRequested=0;
    while(now()-pressed<25){
        if(interrupted)throw std::runtime_error("Interrupted");
        work(engine,^{v->race=[engine discoverySnapshot];});
        for(NSDictionary *entry in v->race[@"candidates"]){probePayload=std::max(probePayload,[entry[@"payload_bytes"]doubleValue]);maxRequested=std::max(maxRequested,[entry[@"probe_requested_byte_bound"]doubleValue]);}
        selected=[v->race[@"selected"]boolValue];
        if(selected||[v->race[@"exhausted"]boolValue])break;
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }
    double qualified=now()-pressed;
    check(slow?!selected:selected,"Only the healthy seed qualifies; actual slow delivery is still rejected");
    check(maxRequested<=32.*1024*1024&&probePayload<=32.*1024*1024,"Qualification stays inside its whole-piece and payload budget");
    if(slow){
        NSDictionary *failure=[v->race[@"failures"]firstObject];
        check([failure[@"reason"]hasPrefix:@"Measured transfer is too slow"],"Slow seed fails on measured capacity, not a manufactured idle interval");
        check([failure[@"probe_outstanding_bytes"]longLongValue]>0,"A slow verdict is supported by pending requested bytes");
    }
    if(selected){
        bool readable=waitFor([&]{work(engine,^{[engine prioritizeOffset:0 length:65536];v->read=[engine readVerifiedBytesAt:0 length:65536];v->snapshot=[engine snapshot];});return v->read.length==65536;},5);
        check(readable&&((const char *)v->read.bytes)[0]=='R',"Qualification hands off verified data without restarting the source");
        check(qualified<12,"Healthy local source is not delayed by a false slow-source timeout");
    }
    NSDictionary *result=@{@"event":@"qualification_check",@"mode":mode,@"piece_mib":@(pieceMiB),@"checks":@(checks),@"failures":@(failures),@"selected":@(selected),@"qualification_seconds":@(qualified),@"probe_payload_bytes":@(probePayload),@"max_requested_bytes":@(maxRequested),@"required_bytes_per_second":@(900*1024),@"configured_limit_bytes_per_second":@(slow?128*1024:4*1024*1024),@"discovery":v->race?:@{},@"scope":@"Actual engine, generated loopback fixture; not physical iPad playback"};
    NSData *json=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];std::printf("%s\n",[[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding].UTF8String);std::fflush(stdout);
    return failures?1:0;
}
