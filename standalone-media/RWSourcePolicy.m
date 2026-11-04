#import "RWSourceIdentity.h"
#import "RWSourcePolicy.h"
#import "RWTrackerPolicy.h"
#include <math.h>

static NSString *Text(id value) { return [value isKindOfClass:NSString.class]?value:@""; }
static NSDictionary *Dict(id value) { return [value isKindOfClass:NSDictionary.class]?value:@{}; }
static NSArray *List(id value) { return [value isKindOfClass:NSArray.class]?value:@[]; }
static double Number(id value) { return [value isKindOfClass:NSNumber.class] && isfinite([value doubleValue])?[value doubleValue]:0; }
static BOOL Flag(id value) { return Number(value)!=0; }
static NSTextCheckingResult *Match(NSString *pattern, NSString *text) {
    // Source lists reuse the same patterns hundreds of times. Keep a bounded,
    // memory-pressure-aware cache; compiled expressions are immutable.
    static NSCache *expressions;static dispatch_once_t once;
    dispatch_once(&once,^{expressions=[NSCache new];expressions.countLimit=64;});
    NSRegularExpression *regex=[expressions objectForKey:pattern];
    if(!regex){regex=[NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];if(regex)[expressions setObject:regex forKey:pattern];}
    return [regex firstMatchInString:text options:0 range:NSMakeRange(0,text.length)];
}
static NSString *Group(NSString *pattern, NSString *text, NSUInteger index) {
    NSTextCheckingResult *m=Match(pattern,text); return m && m.numberOfRanges>index && [m rangeAtIndex:index].location!=NSNotFound?[text substringWithRange:[m rangeAtIndex:index]]:@"";
}
static NSString *Escape(NSString *text) {
    return [text stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"]];
}
static NSString *MagnetHash(NSString *url) {
    if(url.length>16384)return nil;
    NSURLComponents *parts=[NSURLComponents componentsWithString:url];NSString *hash=nil;
    for(NSURLQueryItem *item in parts.queryItems){
        if(![item.name isEqual:@"xt"]||![item.value hasPrefix:@"urn:btih:"])continue;
        NSString *value=[item.value substringFromIndex:9],*candidate=nil;
        if(Match(@"^[0-9a-f]{40}$",value))candidate=value.lowercaseString;
        else if(Match(@"^[a-z2-7]{32}$",value)){
            NSString *alphabet=@"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567",*upper=value.uppercaseString;
            uint32_t bits=0;NSUInteger count=0;NSMutableString *hex=[NSMutableString new];
            for(NSUInteger i=0;i<upper.length;i++){
                NSRange digit=[alphabet rangeOfString:[upper substringWithRange:NSMakeRange(i,1)]];
                if(digit.location==NSNotFound)return nil;
                bits=(bits<<5)|(uint32_t)digit.location;count+=5;
                if(count>=8){count-=8;[hex appendFormat:@"%02x",(unsigned)((bits>>count)&255)];}
            }
            candidate=hex;
        }
        if(!candidate||(hash&&![hash isEqual:candidate]))return nil;
        hash=candidate;
    }
    return hash;
}
static BOOL RWLegacyEnabled=NO;
static BOOL RWNativeSurroundEnabled=NO;
static NSUInteger RWCapabilitiesGeneration=0;
@interface RWSourcePolicy ()
+ (NSDictionary *)evaluate:(NSDictionary *)source quality:(NSInteger)quality freeBytes:(uint64_t)freeBytes capabilities:(NSDictionary *)capabilities;
+ (NSArray *)rankEvaluated:(NSArray *)sources;
@end
@implementation RWSourcePolicy
+ (void)setLegacyEnabled:(BOOL)enabled {__atomic_store_n(&RWLegacyEnabled,enabled,__ATOMIC_RELAXED);__atomic_add_fetch(&RWCapabilitiesGeneration,1,__ATOMIC_RELAXED);}
+ (BOOL)legacyEnabled {return __atomic_load_n(&RWLegacyEnabled,__ATOMIC_RELAXED);}
+ (void)setNativeSurroundEnabled:(BOOL)enabled {__atomic_store_n(&RWNativeSurroundEnabled,enabled,__ATOMIC_RELAXED);__atomic_add_fetch(&RWCapabilitiesGeneration,1,__ATOMIC_RELAXED);}
+ (BOOL)nativeSurroundEnabled {return __atomic_load_n(&RWNativeSurroundEnabled,__ATOMIC_RELAXED);}
+ (NSDictionary *)capabilities {return @{@"legacy":@([self legacyEnabled]),@"surround":@([self nativeSurroundEnabled]),@"generation":@(__atomic_load_n(&RWCapabilitiesGeneration,__ATOMIC_RELAXED))};}
+ (NSArray *)sources:(NSArray *)sources withMeta:(NSDictionary *)meta {
    return [self sources:sources withMeta:meta videoID:nil];
}
+ (NSArray *)sources:(NSArray *)sources withMeta:(NSDictionary *)meta videoID:(NSString *)videoID {
    // Cinemeta runtime is minutes; retain the original field for provenance.
    double minutes=Number(meta[@"runtime"]);NSString *runtime=Text(meta[@"runtime"]);
    if(!minutes)minutes=[Group(@"^\\s*([0-9]+(?:[.][0-9]+)?)\\s*(?:min|minutes?)?\\s*$",runtime,1)doubleValue];
    NSMutableArray *out=[NSMutableArray new];for(NSDictionary *raw in sources){NSMutableDictionary *s=[raw mutableCopy];
        [s removeObjectForKey:@"requestedVideoID"];
        if([videoID isKindOfClass:NSString.class]&&videoID.length<=64)s[@"requestedVideoID"]=videoID;
        if(minutes>=1&&minutes<=600){s[@"durationHintSeconds"]=@(minutes*60);s[@"durationBasis"]=@"Catalog runtime estimate";}
        [out addObject:s];}return out;
}
+ (NSDictionary *)normalize:(NSDictionary *)stream provider:(NSString *)provider {
    if (![stream isKindOfClass:NSDictionary.class]) return nil;
    NSString *hash=Text(stream[@"infoHash"]), *url=Text(stream[@"url"]); NSDictionary *hints=Dict(stream[@"behaviorHints"]);
    if(hash.length&&!Match(@"^[0-9a-f]{40}$",hash))return nil;
    BOOL suppliedMagnet=[[[NSURL URLWithString:url]scheme].lowercaseString isEqual:@"magnet"];
    if(suppliedMagnet){
        NSString *parsed=MagnetHash(url);
        if(!parsed||(hash.length&&![hash.lowercaseString isEqual:parsed]))return nil;
        hash=parsed;
        // Keep supplied tracker and peer parameters, including private lists.
        // Only canonicalize the scheme used by the engine's transport selector.
        url=[@"magnet:" stringByAppendingString:[url substringFromIndex:7]];
    }else if (hash.length) {
        NSMutableString *magnet=[NSMutableString stringWithFormat:@"magnet:?xt=urn:btih:%@",hash.lowercaseString];
        for (NSString *tracker in [RWTrackerPolicy URLsFromSourceEntries:List(stream[@"sources"]) allowHTTPS:[RWTrackerPolicy supportsHTTPS] limit:4])
            [magnet appendFormat:@"&tr=%@",Escape(tracker)];
        // These built-in public indexes omit sources for ordinary public magnets.
        // Never add public trackers to arbitrary imported/private tracker lists.
        if (!List(stream[@"sources"]).count && ([@[@"Torrentio",@"YTS"] containsObject:provider]))
            for (NSString *tracker in [RWTrackerPolicy publicFallbacks])
                [magnet appendFormat:@"&tr=%@",Escape(tracker)];
        url=magnet;
    }
    NSURL *u=[NSURL URLWithString:url]; if (![@[@"magnet",@"http",@"https",@"asset"] containsObject:u.scheme.lowercaseString]) return nil;
    if ([@[@"http",@"https"] containsObject:u.scheme.lowercaseString] && !u.host.length) return nil;
    NSMutableDictionary *s=[stream mutableCopy]; s[@"url"]=url; s[@"provider"]=provider?:@"Source";
    for(NSString *key in @[@"requestedVideoID",@"resolvedFileIdx",@"resolvedFilename",@"localMediaRejection",@"localSuccess",@"localFailure",@"previousFailureKind",@"previousSourceObservation",@"previousObservationAgeSeconds",@"verifiedWidth",@"verifiedHeight",@"verifiedPlayback",@"verifiedMediaRejectionApplied"])[s removeObjectForKey:key];
    if (hash.length) s[@"infoHash"]=hash.lowercaseString;
    if (stream[@"fileIdx"] && stream[@"fileIdx"]!=NSNull.null) {
        double index=Number(stream[@"fileIdx"]);
        if (![stream[@"fileIdx"] isKindOfClass:NSNumber.class] || index<0 || index!=floor(index) || index>10000) return nil;
        s[@"fileIdx"]=@((NSInteger)index);
    } else [s removeObjectForKey:@"fileIdx"];
    if (Text(hints[@"filename"]).length) s[@"filename"]=hints[@"filename"];
    NSString *detail=Text(stream[@"title"]); if (!detail.length) detail=Text(stream[@"detail"]);
    if (!detail.length) detail=Text(stream[@"description"]);
    if (!detail.length) detail=Text(stream[@"release"]);
    s[@"release"]=detail; s[@"label"]=Text(stream[@"name"]); s[@"group"]=Text(hints[@"bingeGroup"]).length?hints[@"bingeGroup"]:Text(stream[@"group"]);
    double bytes=Number(hints[@"videoSize"]); if (bytes<=0) bytes=Number(stream[@"sizeBytes"]);
    NSString *number=Group(@"([0-9]+(?:[.,][0-9]+)?)\\s*(GiB|MiB|GB|MB)\\b",detail,1);
    NSString *unit=Group(@"([0-9]+(?:[.,][0-9]+)?)\\s*(GiB|MiB|GB|MB)\\b",detail,2);
    if (bytes<=0 && number.length) bytes=[[number stringByReplacingOccurrencesOfString:@"," withString:@"."] doubleValue]*([unit.lowercaseString hasPrefix:@"g"]?1073741824.:1048576.);
    if (bytes>0 && bytes<1e15) s[@"sizeBytes"]=@((uint64_t)bytes);
    double seeds=Number(stream[@"seeders"]);
    if (seeds<=0) seeds=[Group(@"(?:\\x{1F464}|seeders?[: ]+)\\s*([0-9]+)",detail,1) doubleValue];
    s[@"seeders"]=@(MIN(1000000,MAX(0,seeds)));
    return s;
}
+ (NSArray *)ytsSources:(NSDictionary *)response imdbID:(NSString *)imdbID {
    NSMutableArray *result=[NSMutableArray new];
    for (id raw in List(Dict(response[@"data"])[@"movies"])) {
        NSDictionary *movie=Dict(raw);if(![Text(movie[@"imdb_code"])isEqual:imdbID])continue;
        for(id entry in List(movie[@"torrents"])) {
            NSDictionary *t=Dict(entry);NSString *hash=Text(t[@"hash"]),*kind=Text(t[@"type"]);
            NSString *origin=[kind isEqual:@"web"]?@"WEBRip":([kind isEqual:@"bluray"]?@"BluRay":kind);
            NSString *release=[NSString stringWithFormat:@"%@ %@ %@ %@ %@bit",Text(movie[@"title"]),Text(t[@"quality"]),origin,Text(t[@"video_codec"]),Text(t[@"bit_depth"])];
            NSMutableDictionary *s=[@{@"infoHash":hash,@"title":release,@"name":@"YTS",@"seeders":@(Number(t[@"seeds"])),@"sizeBytes":@(Number(t[@"size_bytes"])),@"audioChannelsHint":Text(t[@"audio_channels"])}mutableCopy];
            // Only the documented publisher endpoint; verify returned infohash too.
            if(Match(@"^[0-9a-f]{40}$",hash))s[@"metadataURL"]=[@"https://yts.gg/torrent/download/" stringByAppendingString:hash.uppercaseString];
            NSDictionary *normal=[self normalize:s provider:@"YTS"];if(normal)[result addObject:normal];
        }
    }return result;
}
+ (NSDictionary *)evaluate:(NSDictionary *)source quality:(NSInteger)quality freeBytes:(uint64_t)freeBytes {
    return [self evaluate:source quality:quality freeBytes:freeBytes capabilities:[self capabilities]];
}
+ (NSDictionary *)evaluate:(NSDictionary *)source quality:(NSInteger)quality freeBytes:(uint64_t)freeBytes capabilities:(NSDictionary *)capabilities {
    if (![source isKindOfClass:NSDictionary.class]) return nil;
    NSMutableDictionary *s=[source mutableCopy];[s removeObjectForKey:@"verifiedMediaRejectionApplied"];
    NSString *filename=Text(s[@"filename"]);
    NSString *text=[NSString stringWithFormat:@"%@ %@ %@ %@ %@",filename,Text(s[@"release"]),Text(s[@"label"]),Text(s[@"name"]),Text(s[@"group"])];
    NSString *reason=nil, *kind=nil;
    // Token boundaries avoid false matches such as the film title 'Cambridge'.
    if (Match(@"(?:^|[^a-z0-9])(?:hd[ ._-]?)?(?:cam(?:rip)?|ts|tc|telesync|telecine|scr|dvdscr|screener|workprint|wp)(?:$|[^a-z0-9])",text)) reason=@"Camera recording or unfinished release";
    if (Match(@"(?:^|[^a-z0-9])(?:2160p|4320p|4k|8k|uhd)(?:$|[^a-z0-9])",text)) reason=@"Above the 1080p limit";
    if (Match(@"(?:^|[^a-z0-9])(?:x[ ._-]?265|h[ ._-]?265|hevc|av1|vp9|hi10p|10[ ._-]?bit|hdr(?:10)?\\+?|dolby[ ._-]?vision|dv)(?:$|[^a-z0-9])",text)) reason=@"Unsupported video encoding on this iPad";
    NSString *extension=filename.pathExtension.lowercaseString;
    BOOL legacy=[capabilities[@"legacy"]boolValue]&&[extension isEqual:@"mkv"];
    if (extension.length && !legacy && ![@[@"mp4",@"m4v",@"mov"] containsObject:extension]) reason=@"Container needs a different media engine";
    if (Match(@"(?:^|[^a-z0-9])(?:sample|trailer)(?:$|[^a-z0-9])",filename.lastPathComponent) && !Flag(s[@"isPreview"])) reason=@"Sample or trailer instead of the film";
    if (Flag(s[@"publisherSource"])) kind=@"Publisher";
    else if (Match(@"(?:web[ ._-]?(?:dl|rip)|webrip)",text)) kind=@"Web";
    else if (Match(@"(?:blu[ ._-]?ray|b[dr][ ._-]?rip|brrip|bdrip)",text)) kind=@"Blu-ray";
    else if (Match(@"(?:dvd[ ._-]?rip|hdtv)",text)) kind=@"TV / DVD";
    if (!kind && !reason) reason=@"Release origin is not identified";
    NSInteger resolution=0;
    if (Match(@"(?:^|[^0-9])1080[pi]?(?:$|[^0-9])",text)) resolution=1080;
    else if (Match(@"(?:^|[^0-9])720p?(?:$|[^0-9])",text)) resolution=720;
    else {NSString *sd=Group(@"(?:^|[^0-9])(576|540|480|360|240)p?(?:$|[^0-9])",text,1);resolution=sd.integerValue;}
    if (Number(s[@"verifiedWidth"])>0 && Number(s[@"verifiedHeight"])>0) resolution=[self resolutionForWidth:Number(s[@"verifiedWidth"]) height:Number(s[@"verifiedHeight"])];
    // Unknown dimensions may be probed for a publisher source, never assumed 1080p.
    if (!resolution && !Flag(s[@"publisherSource"]) && !reason) reason=@"Resolution is not identified";
    if (quality>0 && resolution>0 && resolution!=quality && !reason) reason=@"Different quality than selected";
    double bytes=Number(s[@"sizeBytes"]);
    if (freeBytes>0 && bytes>0 && bytes+536870912.>freeBytes && !reason) reason=@"Not enough free storage";
    BOOL aac=Match(@"(?:^|[^a-z0-9])aac(?:$|[^a-z0-9]|[257][.]?[01])",text)!=nil;
    BOOL multichannel=Match(@"(?:aac|ac[ ._-]?3|ddp?)[ ._-]?(?:5[ .]1|7[ .]1)",text)!=nil||[Text(s[@"audioChannelsHint"])doubleValue]>2;
    if(!legacy&&multichannel&&![capabilities[@"surround"]boolValue]&&!reason)reason=@"Surround audio needs the local playback check";
    if(!legacy&&(Match(@"aac[ ._-]?7[ .]1",text)||[Text(s[@"audioChannelsHint"])doubleValue]>6)&&!reason)reason=@"This audio layout exceeds the tested six-channel limit";
    if (!legacy && !aac && Match(@"(?:^|[^a-z0-9])(?:ac[ ._-]?3|eac[ ._-]?3|dts(?:[ ._-]?hd)?|truehd|ddp?)(?:$|[^a-z0-9]|[257][ .]?[01])",text) && !reason) reason=@"No compatible audio track is identified";
    // Only the local store attaches this proof, after provider normalization.
    // Re-check identity, capability and the observed video facts before exclusion.
    NSDictionary *proof=Dict(s[@"localMediaRejection"]);
    NSString *hash=Text(s[@"infoHash"]);id file=s[@"fileIdx"];
    NSString *key=file&&[file isKindOfClass:NSNumber.class]?[NSString stringWithFormat:@"%@:%ld",hash.lowercaseString,(long)[file integerValue]]:@"";
    if(Match(@"^[0-9a-f]{40}$",hash)&&[file isKindOfClass:NSNumber.class]&&Number(file)>=0&&Number(file)==floor(Number(file))&&Number(file)<=10000&&[Text(proof[@"key"])isEqual:key]&&[Text(proof[@"capability"])isEqual:[self mediaCapabilityKey:capabilities]]){
        NSDictionary *assessment=[self mediaAssessment:Dict(proof[@"evidence"]) quality:0];
        if([assessment[@"status"]isEqual:@"incompatible"]&&[assessment[@"code"]isEqual:proof[@"code"]]){reason=assessment[@"reason"];s[@"verifiedMediaRejectionApplied"]=@YES;}
    }
    double seedHint=Number(s[@"seeders"]);
    // Auto favors viable, smaller native encodes. Live probes decide the winner.
    double score=(resolution==720?65:resolution==1080?30:20) + MIN(180,log10(1+MAX(0,seedHint))*70) + (aac?25:0) + (Flag(s[@"publisherSource"])?100:0);
    if([Text(s[@"audioChannelsHint"])isEqual:@"2.0"])score+=45;
    if(Match(@"aac[ ._-]?(?:5[ .]1|7[ .]1)",text)||[Text(s[@"audioChannelsHint"])doubleValue]>2)score-=90;
    if ([@[@"mp4",@"m4v",@"mov"]containsObject:extension])score+=75;
    if (Flag(s[@"verifiedPlayback"])) score+=90;
    if (Flag(s[@"localSuccess"]))score+=350;
    if (Flag(s[@"localFailure"]))score-=500;
    double seconds=Number(s[@"durationHintSeconds"]),required=seconds>=60&&seconds<=36000&&bytes>0?bytes/seconds:0;
    if(required>0){s[@"estimatedBytesPerSecond"]=@(required);score-=MIN(90,required/(1024.*1024.)*45);}
    else score-=MIN(45,bytes/1073741824.*12);
    s[@"resolution"]=@(resolution); s[@"sourceKind"]=kind?:@"Unknown";
    s[@"eligible"]=@(!reason); s[@"rejection"]=reason?:@""; s[@"score"]=@(score);
    s[@"needsMediaProbe"]=@YES;
    s[@"name"]=[NSString stringWithFormat:@"%@ · %@",resolution?[NSString stringWithFormat:@"%ldp",(long)resolution]:@"Automatic quality",kind?:@"Source"];
    return s;
}
+ (NSArray *)rank:(NSArray *)sources quality:(NSInteger)quality freeBytes:(uint64_t)freeBytes {
    NSDictionary *capabilities=[self capabilities];NSMutableArray *evaluated=[NSMutableArray new];for(id source in sources){NSDictionary *entry=[self evaluate:source quality:quality freeBytes:freeBytes capabilities:capabilities];if(entry)[evaluated addObject:entry];}return [self rankEvaluated:evaluated];
}
+ (NSArray *)rankEvaluated:(NSArray *)sources {
    NSMutableArray *accepted=[NSMutableArray new]; NSMutableDictionary *seen=[NSMutableDictionary new];
    for (id raw in sources) {
        if (![raw isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *s=raw; if (![s[@"eligible"] boolValue]) continue;
        NSString *key=RWSourceCandidateKey(s);
        NSNumber *index=seen[key];
        if(index){NSMutableDictionary *merged=[accepted[index.unsignedIntegerValue]mutableCopy];
            if([s[@"score"]doubleValue]>[merged[@"score"]doubleValue]){NSDictionary *old=merged;merged=[s mutableCopy];if(Text(old[@"metadataURL"]).length)merged[@"metadataURL"]=old[@"metadataURL"];}
            if(Text(s[@"metadataURL"]).length)merged[@"metadataURL"]=s[@"metadataURL"];
            accepted[index.unsignedIntegerValue]=merged;continue;}
        seen[key]=@(accepted.count);[accepted addObject:s];
    }
    return [accepted sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){ return [b[@"score"] compare:a[@"score"]]; }];
}
+ (NSDictionary *)analysis:(NSArray *)sources quality:(NSInteger)quality capabilities:(NSDictionary *)capabilities {
    NSMutableArray *eligibleInputIndices=[NSMutableArray new];NSUInteger inputIndex=0;
    NSMutableArray *evaluated=[NSMutableArray new],*automatic=[NSMutableArray new];NSMutableDictionary *rejections=[NSMutableDictionary new];NSUInteger compatible=0,camera=0;
    for(id source in sources){NSUInteger index=inputIndex++;NSDictionary *entry=[self evaluate:source quality:quality freeBytes:0 capabilities:capabilities];if(!entry)continue;if([entry[@"eligible"]boolValue])[eligibleInputIndices addObject:@(index)];[evaluated addObject:entry];compatible+=[entry[@"eligible"]boolValue];NSString *reason=entry[@"rejection"];if(reason.length)rejections[reason]=@([rejections[reason]unsignedIntegerValue]+1);camera+=[reason isEqual:@"Camera recording or unfinished release"];
        if(quality){NSDictionary *any=[self evaluate:source quality:0 freeBytes:0 capabilities:capabilities];if(any)[automatic addObject:any];}}
    NSArray *eligible=[self rankEvaluated:evaluated],*allQualities=quality?[self rankEvaluated:automatic]:eligible;NSMutableSet *values=[NSMutableSet new];for(NSDictionary *entry in allQualities)if([@[@480,@720,@1080]containsObject:entry[@"resolution"]])[values addObject:entry[@"resolution"]];
    return @{@"eligible_input_indices":[eligibleInputIndices copy],@"eligible":eligible,@"compatible":@(compatible),@"camera":@(camera),@"listings":@(sources.count),@"rejections":[rejections copy],@"qualities":[[values allObjects]sortedArrayUsingSelector:@selector(compare:)]};
}
+ (NSUInteger)nextIndexInSources:(NSArray *)sources startingAt:(NSUInteger)index excludingHashes:(NSSet *)hashes {
    while(index<sources.count){NSString *hash=Text(Dict(sources[index])[@"infoHash"]);if(!hash.length||![hashes containsObject:hash])break;index++;}return index;
}
+ (NSArray *)qualities:(NSArray *)sources {
    NSMutableSet *values=[NSMutableSet new];
    for (NSDictionary *s in [self rank:sources quality:0 freeBytes:0]) if ([@[@480,@720,@1080]containsObject:s[@"resolution"]]) [values addObject:s[@"resolution"]];
    return [[values allObjects] sortedArrayUsingSelector:@selector(compare:)];
}
+ (NSInteger)resolutionForWidth:(NSInteger)width height:(NSInteger)height {
    if (width>1920 || height>1080 || width<=0 || height<=0) return 0;
    // Standard encode widths also identify letterbox-cropped film rasters.
    // Never turn an ordinary 360p, 540p or 900p video into a higher quality label.
    if (width==1920 || height==1080) return 1080;
    if (width==1280 || height==720) return 720;
    if (width==1024 || height==576) return 576;
    if (width==960 || height==540) return 540;
    if (width==854 || width==848 || height==480) return 480;
    if (width==640 || height==360) return 360;
    if (width==426 || height==240) return 240;
    if (width==320 || height==180) return 180;
    return height;
}
// Bump this policy version when any decoder/limit change can invalidate a
// recorded video incompatibility. Runtime generation counters are not durable.
+ (NSString *)mediaCapabilityKey:(NSDictionary *)capabilities {
    return [NSString stringWithFormat:@"armv7-h264-1080-30-level41-v1:legacy%d:surround%d",[capabilities[@"legacy"]boolValue],[capabilities[@"surround"]boolValue]];
}
+ (NSDictionary *)mediaAssessment:(NSDictionary *)media quality:(NSInteger)quality {
    NSMutableDictionary *evidence=[NSMutableDictionary new];
    for(NSString *key in @[@"width",@"height",@"fps",@"profile",@"level"]){id n=media[key];if([n isKindOfClass:NSNumber.class]&&isfinite([n doubleValue]))evidence[key]=n;}
    NSString *codec=Text(media[@"videoCodec"]);if(codec.length<=16)evidence[@"videoCodec"]=codec;
    NSString *containerCodec=Text(media[@"containerVideoCodec"]);if(containerCodec.length&&containerCodec.length<=64)evidence[@"containerVideoCodec"]=containerCodec;
    NSInteger width=Number(media[@"width"]),height=Number(media[@"height"]),actual=[self resolutionForWidth:width height:height];
    double fps=Number(media[@"fps"]);NSInteger profile=Number(media[@"profile"]),level=Number(media[@"level"]);
    NSString *status=@"compatible",*code=@"compatible",*reason=@"";
    // A non-H264 track can be proven from its CodecID without parsing H264
    // dimensions. Do not let those absent fields mask a known incompatible codec.
    if(codec.length&&![codec isEqual:@"avc1"]){status=@"incompatible";code=@"codec_unsupported";reason=@"This video is not H.264.";}
    else if(width>1920||height>1080){status=@"incompatible";code=@"dimensions_exceeded";reason=@"The verified video dimensions exceed the 1080p limit.";}
    else if(!actual){status=@"unknown";code=@"dimensions_unknown";reason=@"The video dimensions could not be verified yet.";}
    else if(quality&&actual!=quality){status=@"policy";code=@"quality_mismatch";reason=@"The actual video quality differs from the selected quality.";}
    else if(!codec.length){status=@"unknown";code=@"codec_unknown";reason=@"The video codec could not be verified yet.";}
    else if(fps<=0){status=@"unknown";code=@"frame_rate_unknown";reason=@"The video frame rate could not be verified yet.";}
    else if(fps>30.1){status=@"incompatible";code=@"frame_rate_exceeded";reason=@"The verified video frame rate exceeds this iPad's limit.";}
    else if(profile<=0||level<=0){status=@"unknown";code=@"h264_parameters_unknown";reason=@"The H.264 profile or level could not be verified yet.";}
    else if(![@[@66,@77,@88,@100]containsObject:@(profile)]||level>41){status=@"incompatible";code=@"h264_unsupported";reason=@"The verified H.264 profile or level is unsupported.";}
    else if(!Flag(media[@"aacStereo"])&&!Flag(media[@"aacDownmix"])&&!Flag(media[@"legacyAudioDecodable"])){
        // Audio choices/capabilities may change; this is not a durable video ban.
        status=@"policy";code=@"audio_unavailable";reason=@"No compatible audio track was found for this player.";
    }
    return @{@"version":@1,@"status":status,@"code":code,@"reason":reason,@"evidence":[evidence copy],@"requested_quality":@(quality)};
}
+ (NSString *)mediaRejection:(NSDictionary *)media quality:(NSInteger)quality {
    NSDictionary *assessment=[self mediaAssessment:media quality:quality];return [assessment[@"status"]isEqual:@"compatible"]?nil:assessment[@"reason"];
}
@end
