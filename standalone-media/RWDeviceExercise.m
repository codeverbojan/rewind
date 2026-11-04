#import "RWDeviceExercise.h"
#include <math.h>
@implementation RWDeviceExercise
+ (BOOL)preparedHeader:(id)diagnostics matchesIdentity:(id)identity {
    return [self preparedHeaderRead:diagnostics matchesIdentity:identity]!=nil;
}
+ (NSDictionary *)preparedHeaderRead:(id)diagnostics matchesIdentity:(id)identity {
    // Diagnostic admission only. A cached prefix may require no new payload,
    // so it cannot establish sustained streaming capacity before Play. The
    // normal player must still qualify the adopted source after handoff.
    if(![diagnostics isKindOfClass:NSDictionary.class]||![identity isKindOfClass:NSDictionary.class])return nil;
    NSDictionary *actual=diagnostics[@"identity"],*p=diagnostics[@"preparation"];
    if(![actual isKindOfClass:NSDictionary.class]||![p isKindOfClass:NSDictionary.class]||![diagnostics[@"engine_created"]isEqual:@YES])return nil;
    for(NSString *key in @[@"profile_id",@"type",@"video_id",@"quality"])if(!identity[key]||![identity[key]isEqual:actual[key]])return nil;
    NSString *owner=p[@"payload_source"];NSArray *reads=p[@"duration_reads"];
    if(![owner isKindOfClass:NSString.class]||(owner.length&&owner.length!=40)||![reads isKindOfClass:NSArray.class]||reads.count>2)return nil;
    for(id raw in reads){if(![raw isKindOfClass:NSDictionary.class])continue;NSDictionary *r=raw;
        NSString *hash=r[@"infoHash"];BOOL identityValid=[hash isKindOfClass:NSString.class]&&hash.length==40&&[hash rangeOfString:@"\\A[0-9a-f]{40}\\z" options:NSRegularExpressionSearch].location!=NSNotFound;
        // A completed prefix stays useful after its payload slot moves to another
        // candidate. Report the header's source independently from the live owner.
        if(identityValid&&([hash isEqual:owner]||[r[@"prefix_finished"]isEqual:@YES])&&[r[@"header_bytes_returned"]isKindOfClass:NSNumber.class]&&[r[@"verified_read_bytes"]isKindOfClass:NSNumber.class]&&[r[@"header_bytes_returned"]unsignedLongLongValue]>0&&[r[@"header_bytes_returned"]unsignedLongLongValue]<=4096&&[r[@"verified_read_bytes"]unsignedLongLongValue]>0)return r;
    }return nil;
}
+ (NSDictionary *)playbackCase:(NSString *)key {
    if(![key isKindOfClass:NSString.class])return nil;
    NSDictionary *cases=@{
        @"tenzing":@[@"tt6262770",@"movie",@"Tenzing",@"tt6262770"],
        @"just-play-dead":@[@"tt36948232",@"movie",@"Just Play Dead",@"tt36948232"],
        @"matrix":@[@"tt0133093",@"movie",@"The Matrix",@"tt0133093"],
        @"back-to-future":@[@"tt0088763",@"movie",@"Back to the Future",@"tt0088763"],
        @"two-half-early":@[@"tt0369179",@"series",@"Two and a Half Men",@"tt0369179:1:1"],
        @"two-half-late":@[@"tt0369179",@"series",@"Two and a Half Men",@"tt0369179:12:1"],
        @"breaking-bad":@[@"tt0903747",@"series",@"Breaking Bad",@"tt0903747:1:1"],
        @"severance":@[@"tt11280740",@"series",@"Severance",@"tt11280740:2:1"]};
    NSArray *entry=cases[key];return entry?@{@"id":entry[0],@"type":entry[1],@"name":entry[2],@"video_id":entry[3]}:nil;
}
// Explicit manual-menu diagnostics for the unlabelled sidecar observed in255
// and the exact und/und embedded track independently verified in275.
// This never changes production automatic language selection or chooses a source.
+ (BOOL)isManualCaptionChoice:(id)choice source:(id)source videoID:(NSString *)videoID {
    if(![choice isKindOfClass:NSDictionary.class]||![source isKindOfClass:NSDictionary.class])return NO;
    NSDictionary *raw=choice[@"raw"],*descriptor=choice[@"descriptor"];
    if(![raw isKindOfClass:NSDictionary.class]||![descriptor isKindOfClass:NSDictionary.class])return NO;
    if([videoID isEqual:@"tt11280740:2:1"]){
        id runtime=raw[@"id"];BOOL runtimeValid=[runtime isKindOfClass:NSNumber.class]&&CFGetTypeID((__bridge CFTypeRef)runtime)!=CFBooleanGetTypeID()&&[runtime doubleValue]==[runtime integerValue]&&[runtime integerValue]>=0&&[runtime integerValue]<128;
        return [source[@"infoHash"]isEqual:@"e492a2eec786b2bb983766f77563f6ac629c30d8"]&&[source[@"resolvedFileIdx"]isEqual:@0]&&[source[@"resolvedFilename"]isEqual:@"Severance.S02E01.720p.ATVP.WEB-DL.x264-MIKE.mkv"]&&
            [choice[@"kind"]isEqual:@"mkv"]&&[descriptor[@"kind"]isEqual:@"mkv"]&&[descriptor[@"language"]isEqual:@""]&&[descriptor[@"stable"]isEqual:@YES]&&[descriptor[@"token"]isEqual:@"71d60df02dca598b9f15abecc943f051a108b6c74c0e253717032bb58afee33f"]&&
            runtimeValid&&[raw[@"mapping"]isEqual:@"complete_order_and_metadata"]&&[raw[@"descriptor"]isEqual:descriptor]&&[raw[@"language"]isEqual:@""];
    }
    if(![videoID isEqual:@"tt0088763"])return NO;
    return [source[@"infoHash"]isEqual:@"0ce7772b55bef2da98c49aa1df608debbb20670f"]&&[source[@"resolvedFileIdx"]isEqual:@0]&&[source[@"resolvedFilename"]isEqual:@"Back.to.the.Future.1985.720p.BrRip.x264.YIFY.mp4"]&&
        [choice[@"kind"]isEqual:@"torrent"]&&[choice[@"match"]isEqual:@"release_filename"]&&[descriptor[@"language"]isEqual:@""]&&[descriptor[@"kind"]isEqual:@"torrent"]&&[descriptor[@"stable"]isEqual:@YES]&&[descriptor[@"token"]isKindOfClass:NSString.class]&&[descriptor[@"token"]length]==64&&
        [raw[@"index"]isEqual:@2]&&[raw[@"size"]isEqual:@125647]&&[raw[@"filename"]isEqual:@"Back.to.the.Future.1985.720p.BrRip.x264.YIFY.srt"];
}
+ (BOOL)ownsKidsProfile:(id)profile build:(NSInteger)build run:(NSString *)run {
    if(![run isKindOfClass:NSString.class]||![[NSUUID alloc]initWithUUIDString:run]||![profile isKindOfClass:NSDictionary.class]||![profile[@"name"]isEqual:@"Device Kids check"]||![@[@0,@12]containsObject:profile[@"maxAge"]]||![profile[@"sources"]isKindOfClass:NSDictionary.class])return NO;
    id owner=profile[@"sources"][@"rw:kids-owner"];
    return [owner isKindOfClass:NSDictionary.class]&&[owner[@"build"]isEqual:@(build)]&&[owner[@"protocol"]isEqual:@1]&&[owner[@"age"]isEqual:profile[@"maxAge"]]&&[owner[@"run"]isEqual:run]&&[[NSUUID alloc]initWithUUIDString:run]&&[owner[@"original"]isKindOfClass:NSString.class]&&[owner[@"original"]length]&&![owner[@"original"]hasPrefix:@"rw-device-kids-"];
}
+ (BOOL)isOfflineExerciseSource:(id)source {
    return [source isKindOfClass:NSDictionary.class]&&[source[@"infoHash"]isEqual:@"c0ed8c16ade445c7121456d816e11be210abe43c"]&&[source[@"url"]isEqual:@"magnet:?xt=urn:btih:c0ed8c16ade445c7121456d816e11be210abe43c"]&&[source[@"fileIdx"]isEqual:@0];
}
+ (BOOL)isEpisodeExerciseSource:(id)source videoID:(NSString *)videoID {
    NSString *url=[videoID isEqual:@"rw:handoff:1:24"]?@"asset:subtitle-check.mp4":[videoID isEqual:@"rw:handoff:2:1"]?@"asset:subtitle-check.mkv":nil;
    return url&&[source isKindOfClass:NSDictionary.class]&&[source[@"url"]isEqual:url]&&!source[@"infoHash"];
}
+ (BOOL)isResumeTorrentSource:(id)source {
    return [source isKindOfClass:NSDictionary.class]&&[source[@"infoHash"]isEqual:@"c9e15763f722f23e98a29decdfae341b98d53056"]&&[source[@"publicTest"]isEqual:@YES]&&[source[@"url"]isEqual:@"magnet:?xt=urn:btih:c9e15763f722f23e98a29decdfae341b98d53056&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce"];
}
+ (BOOL)ownsResumeProfile:(id)profile build:(NSInteger)build {
    if(![profile isKindOfClass:NSDictionary.class]||![profile[@"name"]isEqual:@"Device resume check"]||![profile[@"maxAge"]isEqual:@(-1)]||![profile[@"sources"]isKindOfClass:NSDictionary.class])return NO;
    id owner=profile[@"sources"][@"rw:resume-owner"];
    return [owner isKindOfClass:NSDictionary.class]&&[owner[@"build"]isEqual:@(build)]&&[owner[@"protocol"]isEqual:@1]&&[owner[@"original"]isKindOfClass:NSString.class]&&[owner[@"original"]length]&&![owner[@"original"]isEqual:@"rw-device-resume-check"]&&[owner[@"run"]isKindOfClass:NSString.class]&&[[NSUUID alloc]initWithUUIDString:owner[@"run"]]!=nil;
}
+ (BOOL)ownsAudioCompanion:(id)profile parent:(id)parent build:(NSInteger)build {
    if(![self ownsResumeProfile:parent build:build]||![profile isKindOfClass:NSDictionary.class]||![profile[@"name"]isEqual:@"Device audio other"]||![profile[@"maxAge"]isEqual:@(-1)]||![profile[@"sources"]isKindOfClass:NSDictionary.class])return NO;
    id owner=profile[@"sources"][@"rw:audio-owner"];
    return [owner isKindOfClass:NSDictionary.class]&&[owner isEqual:parent[@"sources"][@"rw:resume-owner"]];
}
+ (NSDictionary *)profilePairForState:(NSDictionary *)state {
    if(![state isKindOfClass:NSDictionary.class]||![state[@"profiles"]isKindOfClass:NSDictionary.class]||![state[@"activeProfile"]isKindOfClass:NSString.class])return nil;
    NSDictionary *profiles=state[@"profiles"];NSString *original=state[@"activeProfile"];
    if(![profiles[original]isKindOfClass:NSDictionary.class]||![profiles[original][@"maxAge"]isKindOfClass:NSNumber.class])return nil;
    NSInteger age=[profiles[original][@"maxAge"]integerValue];if(age< -1||age>18)return nil;
    for(NSString *key in [[profiles allKeys]sortedArrayUsingSelector:@selector(compare:)]){
        NSDictionary *profile=profiles[key];if(![profile isKindOfClass:NSDictionary.class]||![profile[@"maxAge"]isKindOfClass:NSNumber.class])continue;
        NSInteger otherAge=[profile[@"maxAge"]integerValue];if(otherAge< -1||otherAge>18||(otherAge>=0)==(age>=0))continue;
        return @{@"original":original,@"other":key};
    }return nil;
}
+ (NSDictionary *)lifecycleSource:(NSString *)backend {
    if([backend isEqual:@"native"])return @{@"url":@"magnet:?xt=urn:btih:aa0277067ef623bdd72e5d696a82df1d24bd79bb",@"infoHash":@"aa0277067ef623bdd72e5d696a82df1d24bd79bb",@"fileIdx":@0,@"filename":@"rewind-lifecycle.mp4",@"name":@"Generated CC0 lifecycle check",@"provider":@"Owned USB test seed",@"durationHintSeconds":@180.021,@"subtitles":@[@{@"name":@"English · Text file",@"lang":@"en",@"url":@"asset:subtitle-check.en.srt"}]};
    if([backend isEqual:@"mkv"])return @{@"url":@"magnet:?xt=urn:btih:b10bb409226d4b9b9cf0ae6bdffa405682d61d40",@"infoHash":@"b10bb409226d4b9b9cf0ae6bdffa405682d61d40",@"fileIdx":@0,@"filename":@"rewind-lifecycle.mkv",@"name":@"Generated CC0 lifecycle check",@"provider":@"Owned USB test seed",@"durationHintSeconds":@180.021,@"subtitles":@[@{@"name":@"English · Text file",@"lang":@"en",@"url":@"asset:subtitle-check.en.srt"}]};
    return nil;
}
+ (BOOL)isLifecycleSource:(id)source backend:(NSString *)backend {
    NSDictionary *known=[self lifecycleSource:backend];if(!known||![source isKindOfClass:NSDictionary.class])return NO;
    for(NSString *key in @[@"url",@"infoHash",@"fileIdx",@"filename"])if(![source[key]isEqual:known[key]])return NO;
    return [source[@"fileIdx"]isKindOfClass:NSNumber.class]&&CFGetTypeID((__bridge CFTypeRef)source[@"fileIdx"])!=CFBooleanGetTypeID();
}
+ (NSDictionary *)recoverySource {
    return @{@"url":@"magnet:?xt=urn:btih:2cd5fed76d9df5aa2959e705b51907dbe533ef38",@"infoHash":@"2cd5fed76d9df5aa2959e705b51907dbe533ef38",@"fileIdx":@0,@"filename":@"rewind-recovery.mkv",@"name":@"Generated CC0 recovery check",@"provider":@"Owned USB test seed",@"durationHintSeconds":@180.021,@"subtitles":@[@{@"name":@"Recovery captions",@"lang":@"en",@"url":@"http://127.0.0.1:18884/recovery-captions.srt"}]};
}
+ (BOOL)isRecoverySource:(id)source {
    if(![source isKindOfClass:NSDictionary.class])return NO;
    NSDictionary *known=[self recoverySource];
    return [source[@"infoHash"]isEqual:known[@"infoHash"]]&&[source[@"url"]isEqual:known[@"url"]]&&[source[@"fileIdx"]isKindOfClass:NSNumber.class]&&[source[@"fileIdx"]isEqual:@0]&&[source[@"filename"]isEqual:known[@"filename"]];
}
+ (NSArray *)stepsForRequest:(id)request build:(NSInteger)build now:(double)now {
    if(![request isKindOfClass:NSDictionary.class])return nil;
    for(NSString *key in @[@"protocol",@"expected_build",@"expires"])
        if(![request[key]isKindOfClass:NSNumber.class])return nil;
    if([request[@"protocol"]integerValue]!=1||[request[@"expected_build"]integerValue]!=build)return nil;
    double expires=[request[@"expires"]doubleValue];
    if(!isfinite(expires)||expires<now||expires>now+300)return nil;
    NSString *run=request[@"run"];if(![run isKindOfClass:NSString.class]||![[NSUUID alloc]initWithUUIDString:run])return nil;
    NSString *action=request[@"action"];
    if([action isEqual:@"font-lookup"]){if(build<288||request[@"legacy_font"]||request[@"playback_case"]||request[@"caption_check"])return nil;return @[@{@"kind":@"font-start",@"wait":@.1},@{@"kind":@"font-await",@"wait":@.25}];}
    if(request[@"legacy_font"]){
        BOOL allowed=[@[@"default",@"Arial"]containsObject:request[@"legacy_font"]]||(build>=289&&[request[@"legacy_font"]isEqual:@"HelveticaNeue"]);
        BOOL fontCaptions=build>=290&&[action isEqual:@"subtitles-font-mkv"];
        if(build<287||!allowed||(!fontCaptions&&![@[@"audio-mkv",@"subtitles-mkv"]containsObject:action]))return nil;
    }
    if([action isEqual:@"subtitles-font-mkv"]){
        if(build<290||request[@"playback_case"]||request[@"caption_check"]||request[@"prepare_check"]||request[@"caption_choice"]||request[@"caption_probe"])return nil;
        if(request[@"legacy_font"]&&![request[@"legacy_font"]isEqual:@"default"]&&![request[@"legacy_font"]isEqual:@"HelveticaNeue"])return nil;
        NSMutableArray *steps=[NSMutableArray arrayWithArray:@[@{@"kind":@"active-profile",@"wait":@4},@{@"kind":@"subtitle-play",@"wait":@1},@{@"kind":@"subtitle-await",@"wait":@1},@{@"kind":@"player-pause",@"wait":@.3},@{@"kind":@"subtitle-menu",@"wait":@.3},@{@"kind":@"subtitle-choice:embedded-font-sample",@"wait":@.3}]];
        for(NSInteger index=1;index<=5;index++){
            [steps addObjectsFromArray:@[@{@"kind":@"player-resume",@"wait":@.1},@{@"kind":[NSString stringWithFormat:@"subtitle-font-await:%ld",(long)index],@"wait":@.2},@{@"kind":@"player-pause",@"wait":@.3},@{@"kind":[NSString stringWithFormat:@"subtitle-frame:font-%ld",(long)index],@"wait":@.2},@{@"kind":[NSString stringWithFormat:@"subtitle-font-audit:%ld",(long)index],@"wait":@.1}]];
        }
        [steps addObjectsFromArray:@[@{@"kind":@"subtitle-menu",@"wait":@.3},@{@"kind":@"subtitle-choice:Off",@"wait":@.3},@{@"kind":@"subtitle-font-off",@"wait":@.2},@{@"kind":@"player-resume",@"wait":@2},@{@"kind":@"player-close",@"wait":@1},@{@"kind":@"home",@"wait":@.5}]];return steps;
    }
    if(request[@"prepare_dwell"]&&(![request[@"prepare_check"]isEqual:@YES]||![@[@0,@12]containsObject:request[@"prepare_dwell"]]))return nil;
    if(request[@"prepare_check"]&&(![action isEqual:@"playback-title"]||![request[@"prepare_check"]isEqual:@YES]||request[@"caption_check"]||![[self playbackCase:request[@"playback_case"]][@"type"]isEqual:@"movie"]))return nil;
    if(request[@"caption_choice"]&&![action isEqual:@"playback-title"])return nil;
    if(request[@"caption_probe"]&&(![request[@"caption_probe"]isEqual:@"severance-2648"]||![action isEqual:@"playback-title"]||![request[@"playback_case"]isEqual:@"severance"]||![request[@"caption_check"]isEqual:@YES]||![request[@"caption_choice"]isEqual:@"severance-embedded"]))return nil;
    if([action isEqual:@"playback-title"]){
        if(![self playbackCase:request[@"playback_case"]])return nil;
        if(request[@"caption_check"]&&![request[@"caption_check"]isEqual:@YES])return nil;
        BOOL manual=request[@"caption_choice"]!=nil;
        BOOL sidecar=[request[@"caption_choice"]isEqual:@"back-to-future-sidecar"]&&[request[@"playback_case"]isEqual:@"back-to-future"];
        BOOL embedded=[request[@"caption_choice"]isEqual:@"severance-embedded"]&&[request[@"playback_case"]isEqual:@"severance"];
        if(manual&&(![request[@"caption_check"]isEqual:@YES]||(!sidecar&&!embedded)))return nil;
        if(request[@"caption_probe"]){
            NSMutableArray *steps=[NSMutableArray new];void(^add)(NSString *,double)=^(NSString *kind,double wait){[steps addObject:@{@"kind":kind,@"wait":@(wait)}];};
            // A short known-cue investigation, not the sustained-playback recipe.
            // First approach the area normally, then inspect a paused interior
            // frame and a later live cue. Source selection remains ordinary.
            for(NSString *kind in @[@"active-profile",@"await-playback-catalog",@"title-load",@"title-await",@"title-play",@"title-caption-startup",@"player-pause",@"title-caption-menu",@"title-caption-manual",@"title-caption-ready",@"title-caption-known-approach",@"player-resume",@"title-caption-seek-await",@"player-pause",@"title-caption-known-seek",@"title-caption-known-presented",@"title-caption-known-capture",@"player-resume",@"title-caption-known-live",@"title-caption-known-observe",@"player-pause",@"title-caption-menu",@"title-caption-off-choice",@"title-caption-off",@"title-caption-capture:off"])add(kind,.3);
            add(@"player-resume",5);add(@"player-close",1);add(@"home",1);return steps;
        }
        if([request[@"caption_check"]isEqual:@YES]){
            NSMutableArray *steps=[NSMutableArray new];void(^add)(NSString *,double)=^(NSString *kind,double wait){[steps addObject:@{@"kind":kind,@"wait":@(wait)}];};
            for(NSString *kind in @[@"active-profile",@"await-playback-catalog",@"title-load",@"title-await",@"title-play",@"await-playback",@"player-pause",@"title-caption-menu",manual?@"title-caption-manual":@"title-caption-english",@"title-caption-ready"])add(kind,.5);
            if(sidecar)add(@"title-caption-export",.3);
            add(@"player-resume",6);add(@"title-caption-capture:start",.3);
            for(NSString *stage in @[@"middle",@"end"]){add(@"player-pause",.5);add([@"title-caption-seek:" stringByAppendingString:stage],.3);add(@"player-resume",.5);add(@"title-caption-seek-await",.5);add([@"title-caption-capture:" stringByAppendingString:stage],.5);}
            for(NSString *kind in @[@"player-pause",@"title-caption-menu",@"title-caption-off-choice",@"title-caption-off",@"title-caption-capture:off"])add(kind,.5);
            add(@"player-resume",5);add(@"player-close",1);add(@"home",1);return steps;
        }
        NSMutableArray *recipe=[@[@{@"kind":@"active-profile",@"wait":@0.5},@{@"kind":@"await-playback-catalog",@"wait":@0.5},
            @{@"kind":@"title-load",@"wait":@0.5},@{@"kind":@"title-await",@"wait":@0.5},@{@"kind":@"title-play",@"wait":@1},
            @{@"kind":@"await-playback",@"wait":@1},@{@"kind":@"player-pause",@"wait":@1},@{@"kind":@"player-resume",@"wait":@5},
            @{@"kind":@"player-close",@"wait":@1},@{@"kind":@"home",@"wait":@1}]mutableCopy];
        if([request[@"prepare_check"]isEqual:@YES]){
            [recipe insertObject:@{@"kind":@"title-prepare",@"wait":@0.5} atIndex:4];
            [recipe insertObject:@{@"kind":@"title-prepare-await",@"wait":@0.5} atIndex:5];
        }return recipe;
    }
    if([action isEqual:@"playback-lifecycle"]){
        NSMutableArray *steps=[NSMutableArray new];void(^add)(NSString *,double)=^(NSString *kind,double wait){[steps addObject:@{@"kind":kind,@"wait":@(wait)}];};
        add(@"active-profile",.5);add(@"lifecycle-prepare",.5);
        for(NSUInteger cycle=0;cycle<6;cycle++){
            add(cycle%2?@"lifecycle-play:mkv":@"lifecycle-play:native",.5);
            for(NSString *kind in @[@"lifecycle-ready",@"lifecycle-pause",@"lifecycle-seek",@"lifecycle-resume",@"lifecycle-advancing",@"lifecycle-menu",@"lifecycle-captions",@"lifecycle-caption-ready",@"lifecycle-observe",@"lifecycle-close",@"lifecycle-dismissed",@"lifecycle-released"])add(kind,[kind isEqual:@"lifecycle-observe"]?1:.3);
        }
        add(@"lifecycle-cleanup",.3);add(@"lifecycle-cleanup-await",.3);add(@"home",.5);return steps;
    }
    if([action isEqual:@"playback-controlled-mkv"]){
        for(NSString *key in request)if(![@[@"protocol",@"expected_build",@"expires",@"run",@"action"]containsObject:key])return nil;
        NSMutableArray *steps=[NSMutableArray new];
        for(NSString *kind in @[@"active-profile",@"recovery-prepare",@"recovery-play",@"recovery-initial",@"recovery-caption-observe",@"recovery-menu",@"recovery-captions",@"recovery-caption-pending",@"recovery-caption-ready",@"recovery-arm-outage",@"recovery-gate",@"recovery-seek-far",@"recovery-blocked",@"recovery-recovered",@"recovery-clock-audit",@"recovery-pause",@"recovery-seek-back",@"recovery-paused-ready",@"recovery-resume",@"recovery-backward",@"recovery-caption-ready",@"recovery-sustain",@"recovery-menu",@"recovery-caption-off",@"recovery-caption-off-audit",@"recovery-close",@"recovery-dismissed",@"recovery-cleanup",@"recovery-cleanup-await",@"home"])[steps addObject:@{@"kind":kind,@"wait":@([kind isEqual:@"recovery-sustain"]?1:0.5)}];
        return steps;
    }
    if([action isEqual:@"close"])return @[@{@"kind":@"close",@"wait":@0}];
    if([action isEqual:@"kids-surfaces"])return @[
        @{@"kind":@"active-profile",@"wait":@1},
        @{@"kind":@"kids-surface-prepare",@"wait":@0.2},
        @{@"kind":@"kids-select-0",@"wait":@1},
        @{@"kind":@"kids-surface-upcoming",@"wait":@1},
        @{@"kind":@"kids-surface-audit-coming-initial",@"wait":@0.2},
        @{@"kind":@"kids-surface-arrive",@"wait":@0.4},
        @{@"kind":@"kids-surface-audit-coming-arrived",@"wait":@0.2},
        @{@"kind":@"kids-surface-waiting",@"wait":@0.3},
        @{@"kind":@"kids-surface-audit-waiting-0",@"wait":@0.2},
        @{@"kind":@"kids-surface-following",@"wait":@0.3},
        @{@"kind":@"kids-surface-audit-following-0",@"wait":@0.2},
        @{@"kind":@"kids-surface-open-followed",@"wait":@0.4},
        @{@"kind":@"kids-surface-audit-followed-detail",@"wait":@0.2},
        @{@"kind":@"kids-surface-back",@"wait":@0.3},
        @{@"kind":@"kids-surface-audit-following-return",@"wait":@0.2},
        @{@"kind":@"kids-surface-film",@"wait":@1},
        @{@"kind":@"kids-surface-await-related",@"wait":@0.3},
        @{@"kind":@"kids-surface-related-scroll",@"wait":@1},
        @{@"kind":@"kids-surface-audit-film-related",@"wait":@0.2},
        @{@"kind":@"kids-surface-revoke-related",@"wait":@0.7},
        @{@"kind":@"kids-surface-await-related",@"wait":@0.3},
        @{@"kind":@"kids-surface-related-scroll",@"wait":@0.4},
        @{@"kind":@"kids-surface-audit-related-revoked",@"wait":@0.2},
        @{@"kind":@"kids-surface-open-related",@"wait":@0.5},
        @{@"kind":@"kids-surface-audit-related-destination",@"wait":@0.2},
        @{@"kind":@"kids-surface-detail-revoke",@"wait":@0.5},
        @{@"kind":@"kids-surface-audit-detail-blocked",@"wait":@0.2},
        @{@"kind":@"kids-select-12",@"wait":@1},
        @{@"kind":@"kids-surface-audit-switched",@"wait":@0.2},
        @{@"kind":@"kids-surface-upcoming",@"wait":@0.5},
        @{@"kind":@"kids-surface-audit-coming-12",@"wait":@0.2},
        @{@"kind":@"kids-surface-revoke",@"wait":@0.4},
        @{@"kind":@"kids-surface-audit-coming-revoked",@"wait":@0.2},
        @{@"kind":@"kids-surface-waiting",@"wait":@0.3},
        @{@"kind":@"kids-surface-audit-waiting-12",@"wait":@0.2},
        @{@"kind":@"kids-surface-following",@"wait":@0.3},
        @{@"kind":@"kids-surface-audit-following-12",@"wait":@0.2},
        @{@"kind":@"kids-surface-series",@"wait":@1},
        @{@"kind":@"kids-surface-related-tab",@"wait":@0.5},
        @{@"kind":@"kids-surface-await-related",@"wait":@0.3},
        @{@"kind":@"kids-surface-related-scroll",@"wait":@1},
        @{@"kind":@"kids-surface-audit-series-related",@"wait":@0.2},
        @{@"kind":@"kids-select-0",@"wait":@1},
        @{@"kind":@"kids-surface-audit-switched-back",@"wait":@0.2}];
    if([action isEqual:@"artwork-states"])return @[
        @{@"kind":@"active-profile",@"wait":@1},
        @{@"kind":@"resume-prepare",@"wait":@1},
        @{@"kind":@"artstate-prepare",@"wait":@0.3},
        @{@"kind":@"artstate-await",@"wait":@0.2},
        @{@"kind":@"artstate-preview",@"wait":@0.6},
        @{@"kind":@"artstate-audit-preview",@"wait":@0.2},
        @{@"kind":@"artstate-await",@"wait":@0.2},
        @{@"kind":@"artstate-audit-wide",@"wait":@0.2},
        @{@"kind":@"artstate-same-title",@"wait":@0.3},
        @{@"kind":@"artstate-same-url-new-title",@"wait":@0.3},
        @{@"kind":@"artstate-old-request",@"wait":@0.8},
        @{@"kind":@"artstate-reuse",@"wait":@0.3},
        @{@"kind":@"artstate-await",@"wait":@0.2},
        @{@"kind":@"artstate-audit-reused",@"wait":@4.0},
        @{@"kind":@"artstate-audit-late",@"wait":@0.2},
        @{@"kind":@"artstate-no-url",@"wait":@0.2},
        @{@"kind":@"artstate-audit-empty",@"wait":@0.2},
        @{@"kind":@"artstate-corrupt",@"wait":@0.2},
        @{@"kind":@"artstate-await",@"wait":@0.2},
        @{@"kind":@"artstate-audit-corrupt",@"wait":@0.2},
        @{@"kind":@"artstate-missing",@"wait":@0.2},
        @{@"kind":@"artstate-await",@"wait":@0.2},
        @{@"kind":@"artstate-audit-missing",@"wait":@0.2}];
    if([action isEqual:@"entity-art"])return @[
        @{@"kind":@"active-profile",@"wait":@1},
        @{@"kind":@"resume-prepare",@"wait":@1},
        @{@"kind":@"presentation-landscape",@"wait":@0.3},
        @{@"kind":@"presentation-await-orientation",@"wait":@0.3},
        @{@"kind":@"entityart-prepare",@"wait":@0.3},
        @{@"kind":@"entityart-query-anne",@"wait":@0.3},
        @{@"kind":@"entityart-await-card",@"wait":@0.4},
        @{@"kind":@"entityart-audit-anne-card",@"wait":@0.3},
        @{@"kind":@"entityart-open",@"wait":@0.3},
        @{@"kind":@"entityart-await-page",@"wait":@0.4},
        @{@"kind":@"entityart-audit-anne-page-landscape",@"wait":@0.3},
        @{@"kind":@"presentation-portrait",@"wait":@0.3},
        @{@"kind":@"presentation-await-orientation",@"wait":@0.3},
        @{@"kind":@"entityart-await-page",@"wait":@0.4},
        @{@"kind":@"entityart-audit-anne-page-portrait",@"wait":@0.4},
        @{@"kind":@"entityart-filter-Films",@"wait":@0.3},@{@"kind":@"entityart-await-filter",@"wait":@0.6},
        @{@"kind":@"entityart-filter-Shows",@"wait":@0.3},@{@"kind":@"entityart-await-filter",@"wait":@0.6},
        @{@"kind":@"entityart-filter-All",@"wait":@0.3},@{@"kind":@"entityart-await-filter",@"wait":@0.6},
        @{@"kind":@"entityart-menu-sort",@"wait":@0.3},@{@"kind":@"entityart-choice-Rating",@"wait":@0.3},@{@"kind":@"entityart-await-filter",@"wait":@0.6},
        @{@"kind":@"entityart-menu-sort",@"wait":@0.3},@{@"kind":@"entityart-choice-Year",@"wait":@0.3},@{@"kind":@"entityart-await-filter",@"wait":@0.6},
        @{@"kind":@"entityart-top",@"wait":@0.3},
        @{@"kind":@"entityart-menu-highlights",@"wait":@0.3},@{@"kind":@"entityart-choice-recent",@"wait":@0.3},@{@"kind":@"entityart-await-page",@"wait":@0.3},@{@"kind":@"entityart-check-recent",@"wait":@0.3},
        @{@"kind":@"entityart-menu-highlights",@"wait":@0.3},@{@"kind":@"entityart-choice-knownFor",@"wait":@0.3},@{@"kind":@"entityart-await-page",@"wait":@0.3},
        @{@"kind":@"presentation-landscape",@"wait":@0.3},
        @{@"kind":@"presentation-await-orientation",@"wait":@0.3},
        @{@"kind":@"entityart-back",@"wait":@0.5},
        @{@"kind":@"entityart-query-nolan",@"wait":@0.3},
        @{@"kind":@"entityart-await-card",@"wait":@0.4},
        @{@"kind":@"entityart-audit-nolan-card",@"wait":@0.3},
        @{@"kind":@"entityart-open",@"wait":@0.3},@{@"kind":@"entityart-await-page",@"wait":@0.4},
        @{@"kind":@"entityart-audit-nolan-page-landscape",@"wait":@0.3},
        @{@"kind":@"presentation-portrait",@"wait":@0.3},@{@"kind":@"presentation-await-orientation",@"wait":@0.3},
        @{@"kind":@"entityart-await-page",@"wait":@0.4},@{@"kind":@"entityart-audit-nolan-page-portrait",@"wait":@0.3},
        @{@"kind":@"entityart-menu-role",@"wait":@0.3},@{@"kind":@"entityart-choice-cast",@"wait":@0.3},@{@"kind":@"entityart-check-cast",@"wait":@0.5},
        @{@"kind":@"entityart-menu-role",@"wait":@0.3},@{@"kind":@"entityart-choice-director",@"wait":@0.3},@{@"kind":@"entityart-top",@"wait":@0.3},@{@"kind":@"entityart-await-page",@"wait":@0.3},
        @{@"kind":@"presentation-landscape",@"wait":@0.3},@{@"kind":@"presentation-await-orientation",@"wait":@0.3},@{@"kind":@"entityart-back",@"wait":@0.4},
        @{@"kind":@"entityart-query-pixar",@"wait":@0.3},
        @{@"kind":@"entityart-await-card",@"wait":@0.4},
        @{@"kind":@"entityart-audit-pixar-card",@"wait":@0.3},
        @{@"kind":@"entityart-open",@"wait":@0.3},
        @{@"kind":@"entityart-await-page",@"wait":@0.4},
        @{@"kind":@"entityart-audit-pixar-page-landscape",@"wait":@0.3},
        @{@"kind":@"presentation-portrait",@"wait":@0.3},
        @{@"kind":@"presentation-await-orientation",@"wait":@0.3},
        @{@"kind":@"entityart-await-page",@"wait":@0.4},
        @{@"kind":@"entityart-audit-pixar-page-portrait",@"wait":@0.4},
        @{@"kind":@"presentation-landscape",@"wait":@0.3},
        @{@"kind":@"presentation-await-orientation",@"wait":@0.3},
        @{@"kind":@"entityart-back",@"wait":@0.5},
        @{@"kind":@"entityart-banijay",@"wait":@0.3},@{@"kind":@"entityart-company-proof",@"wait":@0.4},
        @{@"kind":@"entityart-filter-Shows",@"wait":@0.3},@{@"kind":@"entityart-await-filter",@"wait":@0.6},
        @{@"kind":@"entityart-filter-All",@"wait":@0.3},@{@"kind":@"entityart-await-filter",@"wait":@0.6},
        @{@"kind":@"entityart-home",@"wait":@0.3},
        @{@"kind":@"presentation-restore",@"wait":@0.3},
        @{@"kind":@"presentation-await-orientation",@"wait":@0.3},
        @{@"kind":@"presentation-audit-restored",@"wait":@0.2}];
    if([action isEqual:@"entity-network"])return @[
        @{@"kind":@"active-profile",@"wait":@1},
        @{@"kind":@"resume-prepare",@"wait":@1},
        @{@"kind":@"entitynet-prepare",@"wait":@0.5},
        @{@"kind":@"entitynet-query-slow",@"wait":@0.1},
        @{@"kind":@"entitynet-await-response",@"wait":@0.2},
        @{@"kind":@"entitynet-query-fast",@"wait":@0.1},
        @{@"kind":@"entitynet-await",@"wait":@0.2},
        @{@"kind":@"entitynet-audit-fast",@"wait":@4.5},
        @{@"kind":@"entitynet-audit-late",@"wait":@0.2},
        @{@"kind":@"entitynet-query-cached",@"wait":@0.1},
        @{@"kind":@"entitynet-await",@"wait":@0.2},
        @{@"kind":@"entitynet-audit-cached",@"wait":@0.2},
        @{@"kind":@"entitynet-query-failure",@"wait":@0.1},
        @{@"kind":@"entitynet-await",@"wait":@0.2},
        @{@"kind":@"entitynet-audit-failure",@"wait":@0.2},
        @{@"kind":@"entitynet-footer",@"wait":@0.4},
        @{@"kind":@"entitynet-audit-footer",@"wait":@0.2},
        @{@"kind":@"entitynet-retry",@"wait":@0.3},
        @{@"kind":@"entitynet-await",@"wait":@0.2},
        @{@"kind":@"entitynet-audit-retry-footer",@"wait":@0.2},
        @{@"kind":@"entitynet-top",@"wait":@0.4},
        @{@"kind":@"entitynet-audit-retry",@"wait":@0.2},
        @{@"kind":@"entitynet-query-empty",@"wait":@0.1},
        @{@"kind":@"entitynet-await",@"wait":@0.2},
        @{@"kind":@"entitynet-audit-empty",@"wait":@0.2},
        @{@"kind":@"entitynet-studios",@"wait":@0.5},
        @{@"kind":@"entitynet-query-studio-slow",@"wait":@0.1},
        @{@"kind":@"entitynet-await-response",@"wait":@0.2},
        @{@"kind":@"entitynet-query-studio",@"wait":@0.1},
        @{@"kind":@"entitynet-await",@"wait":@0.2},
        @{@"kind":@"entitynet-audit-studio",@"wait":@4.5},
        @{@"kind":@"entitynet-audit-studio-late",@"wait":@0.2},
        @{@"kind":@"entitynet-query-exit",@"wait":@0.1},
        @{@"kind":@"entitynet-await-response",@"wait":@0.2},
        @{@"kind":@"entitynet-home",@"wait":@4.5},
        @{@"kind":@"entitynet-audit-exit",@"wait":@0.2}];
    if([action isEqual:@"search-network"])return @[
        @{@"kind":@"active-profile",@"wait":@1},
        @{@"kind":@"resume-prepare",@"wait":@1},
        @{@"kind":@"searchnet-prepare",@"wait":@0.3},
        @{@"kind":@"searchnet-query-slow",@"wait":@0.1},
        @{@"kind":@"searchnet-await-slow",@"wait":@0.1},
        @{@"kind":@"searchnet-query-fast",@"wait":@0.3},
        @{@"kind":@"searchnet-await",@"wait":@0.2},
        @{@"kind":@"searchnet-audit-fast",@"wait":@4.5},
        @{@"kind":@"searchnet-audit-late",@"wait":@0.2},
        @{@"kind":@"searchnet-query-cached",@"wait":@0.3},
        @{@"kind":@"searchnet-await",@"wait":@0.2},
        @{@"kind":@"searchnet-audit-cached",@"wait":@0.2},
        @{@"kind":@"searchnet-query-offline",@"wait":@0.3},
        @{@"kind":@"searchnet-await",@"wait":@0.2},
        @{@"kind":@"searchnet-audit-offline",@"wait":@0.2},
        @{@"kind":@"searchnet-query-header",@"wait":@0.3},
        @{@"kind":@"searchnet-await",@"wait":@0.2},
        @{@"kind":@"searchnet-audit-header",@"wait":@0.2},
        @{@"kind":@"searchnet-query-chunk",@"wait":@0.3},
        @{@"kind":@"searchnet-await",@"wait":@0.2},
        @{@"kind":@"searchnet-audit-chunk",@"wait":@0.2},
        @{@"kind":@"searchnet-query-gzip",@"wait":@0.3},
        @{@"kind":@"searchnet-await",@"wait":@0.2},
        @{@"kind":@"searchnet-audit-gzip",@"wait":@0.2},
        @{@"kind":@"searchnet-query-exit",@"wait":@0.1},
        @{@"kind":@"searchnet-await-exit",@"wait":@0.1},
        @{@"kind":@"searchnet-home",@"wait":@4.5},
        @{@"kind":@"searchnet-audit-exit",@"wait":@0.2}];
    if([action isEqual:@"library-browse"])return @[
        @{@"kind":@"active-profile",@"wait":@1},
        @{@"kind":@"resume-prepare",@"wait":@1},
        @{@"kind":@"library-prepare",@"wait":@0.3},
        @{@"kind":@"presentation-landscape",@"wait":@0.3},
        @{@"kind":@"presentation-await-orientation",@"wait":@0.3},
        @{@"kind":@"library-list",@"wait":@1},
        @{@"kind":@"library-scroll",@"wait":@2},
        @{@"kind":@"library-audit-landscape",@"wait":@0.2},
        @{@"kind":@"presentation-portrait",@"wait":@0.3},
        @{@"kind":@"presentation-await-orientation",@"wait":@0.3},
        @{@"kind":@"library-audit-rotation",@"wait":@0.5},
        @{@"kind":@"library-open",@"wait":@1},
        @{@"kind":@"library-back",@"wait":@1},
        @{@"kind":@"library-audit-back",@"wait":@0.2},
        @{@"kind":@"library-remove-before",@"wait":@0.5},
        @{@"kind":@"library-audit-removal",@"wait":@0.2},
        @{@"kind":@"library-end",@"wait":@1},
        @{@"kind":@"library-audit-end",@"wait":@0.2},
        @{@"kind":@"library-downloads",@"wait":@0.3},
        @{@"kind":@"library-await-downloads",@"wait":@0.5},
        @{@"kind":@"library-download-scroll",@"wait":@2},
        @{@"kind":@"library-audit-downloads",@"wait":@0.2},
        @{@"kind":@"library-refresh",@"wait":@0.3},
        @{@"kind":@"library-await-downloads",@"wait":@0.5},
        @{@"kind":@"library-audit-refresh",@"wait":@0.2},
        @{@"kind":@"library-empty",@"wait":@0.3},
        @{@"kind":@"library-audit-empty",@"wait":@0.2},
        @{@"kind":@"library-kids",@"wait":@1},
        @{@"kind":@"library-list",@"wait":@1},
        @{@"kind":@"library-audit-kids-list",@"wait":@0.2},
        @{@"kind":@"library-downloads",@"wait":@0.3},
        @{@"kind":@"library-await-downloads",@"wait":@0.5},
        @{@"kind":@"library-audit-kids-downloads",@"wait":@0.2},
        @{@"kind":@"library-adult",@"wait":@0.5},
        @{@"kind":@"presentation-restore",@"wait":@0.3},
        @{@"kind":@"presentation-await-orientation",@"wait":@0.3},
        @{@"kind":@"library-audit-restored",@"wait":@0.2},
        @{@"kind":@"home",@"wait":@0.3}];
    if([action isEqual:@"notification-routing"])return @[
        @{@"kind":@"active-profile",@"wait":@1},@{@"kind":@"resume-prepare",@"wait":@1},@{@"kind":@"notification-prepare",@"wait":@0.3},
        @{@"kind":@"notification-foreground",@"wait":@1},@{@"kind":@"notification-audit-foreground",@"wait":@0.2},
        @{@"kind":@"notification-open",@"wait":@3},@{@"kind":@"notification-audit-episode",@"wait":@0.2},@{@"kind":@"home",@"wait":@0.3},
        @{@"kind":@"notification-duplicate",@"wait":@0.3},@{@"kind":@"notification-audit-noop",@"wait":@0.2},
        @{@"kind":@"notification-availability",@"wait":@1},@{@"kind":@"notification-audit-availability",@"wait":@0.2},@{@"kind":@"home",@"wait":@0.3},
        @{@"kind":@"notification-other-profile",@"wait":@1},@{@"kind":@"notification-audit-profile",@"wait":@0.2},
        @{@"kind":@"notification-owner",@"wait":@1},@{@"kind":@"notification-audit-owner",@"wait":@0.2},@{@"kind":@"home",@"wait":@0.3},
        @{@"kind":@"notification-modal",@"wait":@0.3},@{@"kind":@"notification-audit-deferred",@"wait":@0.2},@{@"kind":@"reminder-dismiss",@"wait":@1},
        @{@"kind":@"notification-audit-after-modal",@"wait":@0.2},@{@"kind":@"home",@"wait":@0.3},
        @{@"kind":@"notification-hidden",@"wait":@0.3},@{@"kind":@"notification-audit-ignored",@"wait":@0.2},@{@"kind":@"notification-reset",@"wait":@0.3},
        @{@"kind":@"notification-legacy",@"wait":@1},@{@"kind":@"notification-audit-legacy",@"wait":@0.2},@{@"kind":@"home",@"wait":@0.3}];
    if([action isEqual:@"notification-schedule"])return @[@{@"kind":@"active-profile",@"wait":@1},@{@"kind":@"resume-prepare",@"wait":@1},@{@"kind":@"notification-prepare",@"wait":@0.3},@{@"kind":@"notification-schedule",@"wait":@0.3}];
    if([action isEqual:@"notification-open-probe"])return @[@{@"kind":@"notification-probe-open",@"wait":@3},@{@"kind":@"notification-audit-delivery",@"wait":@0.3},@{@"kind":@"home",@"wait":@0.3}];
    if([action isEqual:@"presentation"])return @[
        @{@"kind":@"active-profile",@"wait":@2},@{@"kind":@"presentation-portrait",@"wait":@0.5},@{@"kind":@"presentation-await-orientation",@"wait":@0.5},
        @{@"kind":@"detail-open-oak",@"wait":@12},@{@"kind":@"presentation-audit-oak-portrait",@"wait":@0.3},
        @{@"kind":@"detail-open-interstellar",@"wait":@15},@{@"kind":@"presentation-audit-interstellar-portrait",@"wait":@0.3},
        @{@"kind":@"detail-open-series",@"wait":@15},@{@"kind":@"presentation-audit-series-portrait",@"wait":@0.3},
        @{@"kind":@"detail-scroll-episodes",@"wait":@5},@{@"kind":@"presentation-audit-episodes-portrait",@"wait":@0.3},
        @{@"kind":@"presentation-top",@"wait":@0.5},@{@"kind":@"presentation-landscape",@"wait":@0.5},@{@"kind":@"presentation-await-orientation",@"wait":@10},
        @{@"kind":@"presentation-audit-series-landscape",@"wait":@0.3},@{@"kind":@"home",@"wait":@0.5},
        @{@"kind":@"presentation-restore",@"wait":@0.5},@{@"kind":@"presentation-await-orientation",@"wait":@0.5},@{@"kind":@"presentation-audit-restored",@"wait":@0.3}];
    if([action isEqual:@"kids-playback"])return @[
        @{@"kind":@"kids-film-prepare",@"wait":@0.5},@{@"kind":@"kids-select-0",@"wait":@1},@{@"kind":@"kids-film-denied",@"wait":@0.3},
        @{@"kind":@"kids-select-12",@"wait":@1},@{@"kind":@"kids-film-details",@"wait":@3},@{@"kind":@"kids-film-play",@"wait":@1},@{@"kind":@"kids-film-await",@"wait":@1},
        @{@"kind":@"player-pause",@"wait":@2},@{@"kind":@"kids-film-audit",@"wait":@0.3},@{@"kind":@"player-resume",@"wait":@3},@{@"kind":@"player-close",@"wait":@1},@{@"kind":@"kids-film-record",@"wait":@0.3},
        @{@"kind":@"kids-select-0",@"wait":@1},@{@"kind":@"kids-film-denied",@"wait":@0.3},@{@"kind":@"kids-select-12",@"wait":@1},
        @{@"kind":@"kids-film-details",@"wait":@2},@{@"kind":@"kids-film-play",@"wait":@1},@{@"kind":@"kids-film-await",@"wait":@1},
        @{@"kind":@"player-pause",@"wait":@2},@{@"kind":@"kids-film-audit",@"wait":@0.3},@{@"kind":@"player-resume",@"wait":@3},@{@"kind":@"player-close",@"wait":@1},@{@"kind":@"kids-film-record",@"wait":@0.3}];
    if([action isEqual:@"kids-boundaries"]){
        NSMutableArray *steps=[NSMutableArray arrayWithObject:@{@"kind":@"kids-prepare",@"wait":@0.3}];
        for(NSString *age in @[@"0",@"12"])[steps addObjectsFromArray:@[
            @{@"kind":[@"kids-select-" stringByAppendingString:age],@"wait":@3},@{@"kind":@"kids-audit-home",@"wait":@0.3},
            @{@"kind":@"kids-list",@"wait":@1},@{@"kind":@"kids-audit-list",@"wait":@0.3},
            @{@"kind":@"kids-downloads",@"wait":@1},@{@"kind":@"kids-await-downloads",@"wait":@0.5},@{@"kind":@"kids-audit-downloads",@"wait":@0.3},
            @{@"kind":@"kids-search-title",@"wait":@1},@{@"kind":@"kids-audit-search",@"wait":@0.3},@{@"kind":@"kids-denied-actions",@"wait":@0.3}]];
        for(NSString *kind in @[@"People",@"Studios",@"Moods"])[steps addObjectsFromArray:@[
            @{@"kind":@"kids-search-clear",@"wait":@0.5},@{@"kind":[@"kids-explore-" stringByAppendingString:kind],@"wait":@1},
            @{@"kind":@"kids-await-explore",@"wait":@1},@{@"kind":@"kids-audit-explore",@"wait":@0.3},
            @{@"kind":@"kids-open-explore",@"wait":@1},@{@"kind":@"kids-await-destination",@"wait":@1},@{@"kind":@"kids-audit-destination",@"wait":@0.3}]];
        return steps;
    }
    if([@[@"resume-save-native",@"resume-open-native",@"resume-save-mkv",@"resume-open-mkv",@"resume-save-torrent",@"resume-open-torrent"]containsObject:action])return @[
        @{@"kind":@"resume-prepare",@"wait":@0.5},@{@"kind":@"resume-play",@"wait":@1},@{@"kind":@"resume-await",@"wait":@1},
        @{@"kind":@"player-pause",@"wait":@0.5},@{@"kind":@"resume-audit",@"wait":@0.3},@{@"kind":@"player-resume",@"wait":@2},@{@"kind":@"player-close",@"wait":@1},@{@"kind":@"resume-record",@"wait":@0.3}];
    if([@[@"preferences-save-revision-native",@"preferences-save-revision-mkv",@"preferences-open-revision-changed-native",@"preferences-open-revision-changed-mkv",@"preferences-open-revision-again-native",@"preferences-open-revision-again-mkv",@"preferences-open-revision-restored-native",@"preferences-open-revision-restored-mkv",@"preferences-open-revision-profiles-native",@"preferences-open-revision-profiles-mkv"]containsObject:action]){
        BOOL initial=[action hasPrefix:@"preferences-save-"],changed=[action containsString:@"-changed-"],profiles=[action containsString:@"-profiles-"];
        NSMutableArray *steps=[NSMutableArray array];
        void(^add)(NSString *)=^(NSString *kind){[steps addObject:@{@"kind":kind,@"wait":@.3}];};
        void(^play)(void)=^{add(@"prefs-revision-play");add(@"prefs-revision-await:picture");add(@"player-pause");};
        void(^timing)(NSString *)=^(NSString *choice){add(@"prefs-revision-menu");add(@"prefs-revision-choice:Size and timing…");add([@"prefs-revision-choice:" stringByAppendingString:choice]);};
        void(^close)(void)=^{add(@"prefs-revision-seek");add(@"prefs-revision-await:seek");add(@"player-resume");add(@"prefs-revision-await:advancing");add(@"player-close");add(@"prefs-revision-await:closed");};
        add(@"resume-prepare");play();
        if(initial){add(@"prefs-revision-add");add(@"prefs-revision-await:encoding");add(@"prefs-revision-audit:unadjusted");add(@"prefs-revision-choice:Cyrillic");add(@"prefs-revision-await:ready");timing(@"Show 0.5 seconds later");}
        else if(changed){add(@"prefs-revision-await:encoding");add(@"prefs-revision-audit:changed-unadjusted");add(@"prefs-revision-menu");add(@"prefs-revision-choice:Text encoding…");add(@"prefs-revision-choice:Central European");add(@"prefs-revision-await:ready");timing(@"Show 0.5 seconds earlier");}
        else add(@"prefs-revision-await:ready");
        add(@"prefs-revision-audit:saved");close();
        if(profiles){
            add(@"prefs-revision-other");play();add(@"prefs-revision-audit:empty-profile");add(@"prefs-revision-add");add(@"prefs-revision-await:encoding");add(@"prefs-revision-audit:unadjusted");add(@"prefs-revision-choice:Cyrillic");add(@"prefs-revision-await:ready");
            timing(@"Show 0.5 seconds earlier");add(@"prefs-revision-audit:companion");close();
            add(@"prefs-revision-primary");play();add(@"prefs-revision-await:ready");add(@"prefs-revision-audit:primary-return");close();
            add(@"prefs-revision-other");play();add(@"prefs-revision-await:ready");add(@"prefs-revision-audit:companion-return");close();add(@"prefs-revision-primary");
        }return steps;
    }
    if([@[@"preferences-save-link-native",@"preferences-open-link-native",@"preferences-save-link-mkv",@"preferences-open-link-mkv"]containsObject:action]){
        NSMutableArray *steps=[NSMutableArray arrayWithArray:@[@{@"kind":@"resume-prepare",@"wait":@0.5},@{@"kind":@"resume-play",@"wait":@1},@{@"kind":@"resume-await",@"wait":@1},@{@"kind":@"player-pause",@"wait":@0.5}]];
        if([action hasPrefix:@"preferences-save-"])[steps addObjectsFromArray:@[
            @{@"kind":@"prefs-link-add",@"wait":@0.3},@{@"kind":@"prefs-link-await:encoding",@"wait":@0.3},@{@"kind":@"prefs-choice:Cyrillic",@"wait":@0.3},@{@"kind":@"prefs-link-await:ready",@"wait":@0.3},
            @{@"kind":@"prefs-menu",@"wait":@0.3},@{@"kind":@"prefs-choice:Size and timing…",@"wait":@0.3},@{@"kind":@"prefs-choice:Show 0.5 seconds later",@"wait":@0.3},@{@"kind":@"prefs-audit-link-saved",@"wait":@0.3}]];
        else{
            [steps addObjectsFromArray:@[@{@"kind":@"prefs-link-await:ready",@"wait":@0.3},@{@"kind":@"prefs-audit-link-restored",@"wait":@0.3}]];
            for(NSString *position in @[@"2",@"32",@"52"])[steps addObjectsFromArray:@[@{@"kind":[@"prefs-link-seek:" stringByAppendingString:position],@"wait":@0.3},@{@"kind":[@"prefs-link-await:" stringByAppendingString:position],@"wait":@0.3},@{@"kind":[@"prefs-audit-link-" stringByAppendingString:position],@"wait":@0.3}]];
            // Preserve the original2/32/52 timing first. Snapshot export may
            // request a redraw, so retain UIKit before/after and delayed evidence.
            if([action isEqual:@"preferences-open-link-mkv"])[steps addObjectsFromArray:@[
                @{@"kind":@"prefs-link-presented",@"wait":@0.2},@{@"kind":@"prefs-link-frame:seek-52",@"wait":@0.2},@{@"kind":@"prefs-audit-link-52-after-snapshot",@"wait":@2},
                @{@"kind":@"prefs-audit-link-52-delayed",@"wait":@0.2},@{@"kind":@"prefs-link-frame:seek-52-delayed",@"wait":@0.2}]];
            [steps addObjectsFromArray:@[@{@"kind":@"prefs-link-seek:32",@"wait":@0.3},@{@"kind":@"prefs-link-await:32",@"wait":@0.3}]];
        }
        [steps addObjectsFromArray:@[@{@"kind":@"player-resume",@"wait":@2},@{@"kind":@"player-close",@"wait":@1},@{@"kind":@"resume-record",@"wait":@0.3}]];return steps;
    }
    if([@[@"preferences-save-native",@"preferences-open-native",@"preferences-save-mkv",@"preferences-open-mkv"]containsObject:action]){
        NSMutableArray *steps=[NSMutableArray arrayWithArray:@[@{@"kind":@"resume-prepare",@"wait":@0.5},@{@"kind":@"resume-play",@"wait":@1},@{@"kind":@"resume-await",@"wait":@1},@{@"kind":@"player-pause",@"wait":@0.5}]];
        BOOL save=[action hasPrefix:@"preferences-save-"];
        if(!save)[steps addObject:@{@"kind":@"prefs-audit-restored",@"wait":@0.3}];
        [steps addObjectsFromArray:@[@{@"kind":@"prefs-menu",@"wait":@0.3},@{@"kind":@"prefs-choice:English · Text file",@"wait":@0.7}]];
        if(save)[steps addObjectsFromArray:@[
            @{@"kind":@"prefs-menu",@"wait":@0.3},@{@"kind":@"prefs-choice:Size and timing…",@"wait":@0.3},@{@"kind":@"prefs-choice:Large",@"wait":@0.3},
            @{@"kind":@"prefs-menu",@"wait":@0.3},@{@"kind":@"prefs-choice:Size and timing…",@"wait":@0.3},@{@"kind":@"prefs-choice:Show 0.5 seconds later",@"wait":@0.3},
            @{@"kind":@"prefs-audit-settings",@"wait":@0.3},@{@"kind":@"prefs-menu",@"wait":@0.3},@{@"kind":@"prefs-choice:Off",@"wait":@0.3},@{@"kind":@"prefs-audit-off",@"wait":@0.3}]];
        else{
            [steps addObject:@{@"kind":@"prefs-audit-overlay",@"wait":@0.3}];
            if([action hasSuffix:@"-mkv"])[steps addObjectsFromArray:@[@{@"kind":@"prefs-menu",@"wait":@0.3},@{@"kind":@"prefs-choice:embedded-English",@"wait":@1.5},@{@"kind":@"prefs-audit-embedded",@"wait":@0.3},@{@"kind":@"prefs-menu",@"wait":@0.3},@{@"kind":@"prefs-choice:English · Text file",@"wait":@0.7},@{@"kind":@"prefs-audit-overlay-return",@"wait":@0.3}]];
        }
        [steps addObjectsFromArray:@[@{@"kind":@"player-resume",@"wait":@2},@{@"kind":@"player-close",@"wait":@1},@{@"kind":@"resume-record",@"wait":@0.3}]];return steps;
    }
    if([action isEqual:@"download-controls"])return @[
        @{@"kind":@"resume-prepare",@"wait":@0.5},@{@"kind":@"download-prepare",@"wait":@1},@{@"kind":@"download-await",@"wait":@0.5},
        @{@"kind":@"download-audit-initial",@"wait":@0.3},@{@"kind":@"download-keep",@"wait":@0.4},@{@"kind":@"download-audit-kept",@"wait":@0.3},
        @{@"kind":@"download-unkeep",@"wait":@0.4},@{@"kind":@"download-audit-unkept",@"wait":@0.3},@{@"kind":@"download-keep",@"wait":@0.3},
        @{@"kind":@"download-remove",@"wait":@0.4},@{@"kind":@"download-confirm",@"wait":@0.7},@{@"kind":@"download-await-removed",@"wait":@0.5},@{@"kind":@"download-audit-removed",@"wait":@0.3},
        @{@"kind":@"download-trim",@"wait":@0.5},@{@"kind":@"download-await-trim",@"wait":@0.3},@{@"kind":@"download-audit-trim",@"wait":@0.3}];
    if([action isEqual:@"featured-ready"])return @[
        @{@"kind":@"resume-prepare",@"wait":@0.5},@{@"kind":@"offline-prepare",@"wait":@0.3},@{@"kind":@"offline-play",@"wait":@1},@{@"kind":@"offline-await",@"wait":@1},
        @{@"kind":@"featured-buffer-stop",@"wait":@1},@{@"kind":@"featured-buffer-await",@"wait":@1},@{@"kind":@"player-pause",@"wait":@3},@{@"kind":@"featured-pause-audit",@"wait":@0.3},
        @{@"kind":@"offline-keep",@"wait":@0.3},@{@"kind":@"offline-audit",@"wait":@0.3},@{@"kind":@"player-resume",@"wait":@2},@{@"kind":@"player-close",@"wait":@1},
        @{@"kind":@"featured-prepare",@"wait":@1},@{@"kind":@"featured-await-ranking",@"wait":@1},@{@"kind":@"search",@"wait":@0.5},@{@"kind":@"home",@"wait":@1},@{@"kind":@"featured-await-home",@"wait":@1},@{@"kind":@"featured-audit",@"wait":@0.3},@{@"kind":@"featured-details",@"wait":@1},@{@"kind":@"featured-back",@"wait":@1},@{@"kind":@"featured-await-home",@"wait":@1},
        @{@"kind":@"featured-play",@"wait":@1},@{@"kind":@"offline-await",@"wait":@1},@{@"kind":@"player-pause",@"wait":@0.5},@{@"kind":@"featured-play-audit",@"wait":@0.3},@{@"kind":@"player-resume",@"wait":@2},@{@"kind":@"player-close",@"wait":@1}];
    if([action isEqual:@"download-playback"])return @[
        @{@"kind":@"resume-prepare",@"wait":@0.5},@{@"kind":@"offline-prepare",@"wait":@0.3},@{@"kind":@"offline-play",@"wait":@1},@{@"kind":@"offline-await",@"wait":@1},
        @{@"kind":@"player-pause",@"wait":@0.5},@{@"kind":@"offline-try-remove",@"wait":@0.2},@{@"kind":@"offline-await-remove",@"wait":@0.2},@{@"kind":@"offline-keep",@"wait":@0.3},@{@"kind":@"offline-audit",@"wait":@0.3},@{@"kind":@"player-resume",@"wait":@2},@{@"kind":@"player-close",@"wait":@1},
        @{@"kind":@"offline-downloads",@"wait":@1},@{@"kind":@"offline-await-list",@"wait":@0.5},@{@"kind":@"offline-resume",@"wait":@1},@{@"kind":@"offline-await-resume",@"wait":@1},
        @{@"kind":@"player-pause",@"wait":@0.5},@{@"kind":@"offline-audit-resume",@"wait":@0.3},@{@"kind":@"player-resume",@"wait":@2},@{@"kind":@"player-close",@"wait":@1},@{@"kind":@"offline-record",@"wait":@0.3}];
    if([action isEqual:@"episode-handoff"])return @[
        @{@"kind":@"resume-prepare",@"wait":@0.5},@{@"kind":@"handoff-play",@"wait":@1},@{@"kind":@"handoff-await-end",@"wait":@1},
        @{@"kind":@"handoff-next",@"wait":@1},@{@"kind":@"handoff-await-next",@"wait":@1},@{@"kind":@"player-pause",@"wait":@0.5},
        @{@"kind":@"handoff-audit",@"wait":@0.3},@{@"kind":@"player-resume",@"wait":@2},@{@"kind":@"player-close",@"wait":@1},@{@"kind":@"handoff-record",@"wait":@0.3}];
    if([action isEqual:@"resume-cleanup"])return @[@{@"kind":@"resume-cleanup",@"wait":@0.3}];
    if([action isEqual:@"feed-discovery"])return @[
        @{@"kind":@"active-profile",@"wait":@3},
        @{@"kind":@"feed-open-studio",@"wait":@1},@{@"kind":@"feed-await-start",@"wait":@1},
        @{@"kind":@"feed-scroll-end",@"wait":@1},@{@"kind":@"feed-await-page",@"wait":@1},@{@"kind":@"feed-audit-page",@"wait":@0.4},
        @{@"kind":@"feed-open-title",@"wait":@2},@{@"kind":@"feed-back",@"wait":@1},@{@"kind":@"feed-audit-return",@"wait":@0.4},
        @{@"kind":@"search",@"wait":@1},@{@"kind":@"discover-studios",@"wait":@3},
        @{@"kind":@"feed-query-first",@"wait":@0.6},@{@"kind":@"feed-query-final",@"wait":@1},
        @{@"kind":@"feed-await-query",@"wait":@1},@{@"kind":@"feed-audit-query",@"wait":@2},
        @{@"kind":@"search",@"wait":@1},@{@"kind":@"discover-moods",@"wait":@3},@{@"kind":@"discover-open-mood",@"wait":@1},
        @{@"kind":@"feed-mood-await",@"wait":@1},@{@"kind":@"feed-mood-scroll",@"wait":@1},@{@"kind":@"feed-mood-audit",@"wait":@0.4},
        @{@"kind":@"feed-open-title",@"wait":@2},@{@"kind":@"feed-back",@"wait":@1},@{@"kind":@"feed-audit-return",@"wait":@0.4},
        @{@"kind":@"discover-shows",@"wait":@1},@{@"kind":@"feed-mood-await",@"wait":@1},@{@"kind":@"feed-mood-scroll",@"wait":@1},@{@"kind":@"feed-mood-audit",@"wait":@0.4},
        @{@"kind":@"home",@"wait":@1}];
    if([@[@"feed-lists",@"feed-entity",@"feed-retry"]containsObject:action]){
        NSMutableArray *steps=[NSMutableArray arrayWithObject:@{@"kind":@"active-profile",@"wait":@3}];
        NSArray *catalogs=[action isEqual:@"feed-lists"]?@[@"movies",@"series",@"entity"]:[action isEqual:@"feed-entity"]?@[@"entity"]:@[];
        for(NSString *catalog in catalogs)[steps addObjectsFromArray:@[
            @{@"kind":[@"feed-open-" stringByAppendingString:catalog],@"wait":@1},
            @{@"kind":@"feed-await-start",@"wait":@1},@{@"kind":@"feed-scroll-end",@"wait":@1},
            @{@"kind":@"feed-await-page",@"wait":@1},@{@"kind":@"feed-audit-page",@"wait":@0.4},
            @{@"kind":@"feed-open-title",@"wait":@2},@{@"kind":@"feed-back",@"wait":@1},
            @{@"kind":@"feed-audit-return",@"wait":@0.4}]];
        [steps addObject:@{@"kind":@"home",@"wait":@1}];
        if(![action isEqual:@"feed-entity"])[steps addObjectsFromArray:@[
            @{@"kind":@"feed-fixture",@"wait":@1},@{@"kind":@"feed-fixture-error",@"wait":@0.4},
            @{@"kind":@"feed-fixture-retry",@"wait":@1},@{@"kind":@"feed-fixture-appended",@"wait":@0.3},
            @{@"kind":@"feed-fixture-end",@"wait":@0.3},@{@"kind":@"feed-fixture-dismiss",@"wait":@0.3},
            @{@"kind":@"home",@"wait":@1}]];
        return steps;
    }
    if([action isEqual:@"episode-progress"])return @[
        @{@"kind":@"resume-prepare",@"wait":@2},
        @{@"kind":@"episode-prepare",@"wait":@2},
        @{@"kind":@"episode-audit-home-resume",@"wait":@0.6},
        @{@"kind":@"episode-open",@"wait":@2},
        @{@"kind":@"episode-scroll-last",@"wait":@0.6},
        @{@"kind":@"episode-audit-resume",@"wait":@0.6},
        @{@"kind":@"episode-menu-watched",@"wait":@0.6},
        @{@"kind":@"episode-choice:Mark as watched",@"wait":@0.6},
        @{@"kind":@"episode-audit-next",@"wait":@0.6},
        @{@"kind":@"home",@"wait":@2},
        @{@"kind":@"episode-audit-home-next",@"wait":@0.6},
        @{@"kind":@"episode-open",@"wait":@2},
        @{@"kind":@"episode-menu-season",@"wait":@0.6},
        @{@"kind":@"episode-choice:Season 2",@"wait":@0.6},
        @{@"kind":@"episode-scroll-season",@"wait":@0.6},
        @{@"kind":@"episode-audit-season",@"wait":@0.6},
        @{@"kind":@"episode-other-profile",@"wait":@2},
        @{@"kind":@"episode-return-profile",@"wait":@2},
        @{@"kind":@"episode-open",@"wait":@2},
        @{@"kind":@"episode-scroll-season",@"wait":@0.6},
        @{@"kind":@"episode-audit-season",@"wait":@0.6},
        @{@"kind":@"episode-menu-season",@"wait":@0.6},
        @{@"kind":@"episode-choice:Season 1",@"wait":@0.6},
        @{@"kind":@"episode-scroll-last",@"wait":@0.6},
        @{@"kind":@"episode-menu-unwatched",@"wait":@0.6},
        @{@"kind":@"episode-choice:Mark as unwatched",@"wait":@0.6},
        @{@"kind":@"episode-audit-unwatched",@"wait":@0.6},
        @{@"kind":@"home",@"wait":@2}];
    if([@[@"audio-name-native",@"audio-name-mkv"]containsObject:action])return @[
        @{@"kind":@"resume-prepare",@"wait":@.5},@{@"kind":@"audio-name-play",@"wait":@.5},@{@"kind":@"audio-await-named",@"wait":@.5},@{@"kind":@"audio-audit-named",@"wait":@.3},
        @{@"kind":@"audio-menu",@"wait":@.5},@{@"kind":@"audio-audit-named-menu",@"wait":@.3},@{@"kind":@"audio-choice:Polish · Stereo",@"wait":@.5},@{@"kind":@"audio-await-pl",@"wait":@.5},@{@"kind":@"audio-audit-polish",@"wait":@.3},@{@"kind":@"player-close",@"wait":@1},
        @{@"kind":@"audio-name-play",@"wait":@.5},@{@"kind":@"audio-await-pl",@"wait":@.5},@{@"kind":@"audio-audit-polish-reopened",@"wait":@.3},@{@"kind":@"player-pause",@"wait":@.5},@{@"kind":@"player-resume",@"wait":@2},@{@"kind":@"player-close",@"wait":@1}];
    if([@[@"audio-save-native",@"audio-open-native",@"audio-save-mkv",@"audio-open-mkv"]containsObject:action]){
        BOOL save=[action hasPrefix:@"audio-save-"];NSMutableArray *steps=[NSMutableArray arrayWithArray:@[@{@"kind":@"resume-prepare",@"wait":@0.5},@{@"kind":@"audio-play",@"wait":@0.5},@{@"kind":save?@"audio-await-en":@"audio-await-fr",@"wait":@0.5}]];
        if(save)[steps addObjectsFromArray:@[@{@"kind":@"audio-menu",@"wait":@0.5},@{@"kind":@"audio-audit-menu",@"wait":@0.3},@{@"kind":@"audio-choice:French · Stereo",@"wait":@0.5},@{@"kind":@"audio-await-fr",@"wait":@0.5},@{@"kind":@"audio-audit-saved",@"wait":@0.3},@{@"kind":@"player-close",@"wait":@1}]];
        else [steps addObjectsFromArray:@[
            @{@"kind":@"audio-audit-reopened",@"wait":@0.3},@{@"kind":@"player-close",@"wait":@1},
            @{@"kind":@"audio-profile-other",@"wait":@0.5},@{@"kind":@"audio-play",@"wait":@0.5},@{@"kind":@"audio-await-en",@"wait":@0.5},@{@"kind":@"audio-audit-profile-default",@"wait":@0.3},
            @{@"kind":@"audio-menu",@"wait":@0.5},@{@"kind":@"audio-choice:English · Commentary · Stereo",@"wait":@0.5},@{@"kind":@"audio-await-commentary",@"wait":@0.5},@{@"kind":@"audio-audit-commentary",@"wait":@0.3},@{@"kind":@"player-close",@"wait":@1},
            @{@"kind":@"audio-profile-primary",@"wait":@0.5},@{@"kind":@"audio-play",@"wait":@0.5},@{@"kind":@"audio-await-fr",@"wait":@0.5},@{@"kind":@"audio-audit-return",@"wait":@0.3},@{@"kind":@"player-close",@"wait":@1},
            @{@"kind":@"audio-fallback-play",@"wait":@0.5},@{@"kind":@"audio-await-unknown",@"wait":@0.5},@{@"kind":@"audio-audit-fallback",@"wait":@0.3},@{@"kind":@"audio-menu",@"wait":@0.5},@{@"kind":@"audio-audit-fallback-menu",@"wait":@0.3},@{@"kind":@"audio-choice:English · Audio description · Stereo",@"wait":@0.5},@{@"kind":@"audio-await-description",@"wait":@0.5},@{@"kind":@"audio-audit-description",@"wait":@0.3},@{@"kind":@"player-pause",@"wait":@0.5},@{@"kind":@"player-resume",@"wait":@2},@{@"kind":@"player-close",@"wait":@1}]];
        return steps;
    }
    if([@[@"audio-native",@"audio-mkv"]containsObject:action])return @[
        @{@"kind":@"active-profile",@"wait":@0.5},@{@"kind":@"resume-prepare",@"wait":@0.5},@{@"kind":@"audio-play",@"wait":@0.5},@{@"kind":@"audio-await-en",@"wait":@0.5},
        @{@"kind":@"audio-menu",@"wait":@0.5},@{@"kind":@"audio-audit-menu",@"wait":@0.3},@{@"kind":@"audio-choice:French · Stereo",@"wait":@0.5},@{@"kind":@"audio-await-fr",@"wait":@0.5},@{@"kind":@"audio-audit-saved",@"wait":@0.3},@{@"kind":@"player-close",@"wait":@1},
        @{@"kind":@"audio-play",@"wait":@0.5},@{@"kind":@"audio-await-fr",@"wait":@0.5},@{@"kind":@"audio-audit-reopened",@"wait":@0.3},@{@"kind":@"audio-menu",@"wait":@0.5},@{@"kind":@"audio-choice:English · Commentary · Stereo",@"wait":@0.5},@{@"kind":@"audio-await-commentary",@"wait":@0.5},@{@"kind":@"audio-audit-commentary",@"wait":@0.3},@{@"kind":@"player-close",@"wait":@1},
        @{@"kind":@"audio-other-play",@"wait":@0.5},@{@"kind":@"audio-await-en",@"wait":@0.5},@{@"kind":@"audio-audit-other",@"wait":@0.3},@{@"kind":@"player-pause",@"wait":@1},@{@"kind":@"player-resume",@"wait":@3},@{@"kind":@"player-close",@"wait":@1},@{@"kind":@"home",@"wait":@0.5}];
    if([action isEqual:@"subtitles-frames-mkv"]){
        if(build<293)return nil;
        NSMutableArray *steps=[NSMutableArray new];for(NSString *kind in @[@"active-profile",@"subtitle-play",@"subtitle-await",@"player-pause",@"subtitle-menu",@"subtitle-choice:Timing sample",@"subtitle-timing-decoded",@"subtitle-timing-start",@"player-resume",@"subtitle-timing-await",@"subtitle-timing-audit",@"player-pause",@"subtitle-menu",@"subtitle-choice:Off",@"subtitle-timing-off"])[steps addObject:@{@"kind":kind,@"wait":@.3}];
        if(build>=294){
            NSUInteger pause=[[steps valueForKey:@"kind"]indexOfObject:@"subtitle-timing-audit"]+2;
            NSArray *checks=@[@"subtitle-clock-audit:paused",@"subtitle-clock-audit:paused-stable",@"subtitle-clock-seek:12",@"subtitle-clock-await:12",@"player-resume",@"subtitle-clock-await:running",@"player-pause",@"subtitle-clock-seek:6",@"subtitle-clock-await:6",@"player-resume",@"subtitle-clock-await:running",@"player-pause"];
            for(NSString *kind in checks){double wait=[kind isEqual:@"subtitle-clock-audit:paused"]?2:[kind isEqual:@"player-resume"]?1:.3;[steps insertObject:@{@"kind":kind,@"wait":@(wait)} atIndex:pause++];}
        }
        [steps addObjectsFromArray:@[@{@"kind":@"player-resume",@"wait":@3},@{@"kind":@"player-close",@"wait":@1}]];return steps;
    }
    if([@[@"subtitles-timing-native",@"subtitles-timing-mkv"]containsObject:action]){
        NSMutableArray *steps=[NSMutableArray new];for(NSString *kind in @[@"active-profile",@"subtitle-play",@"subtitle-await",@"player-pause",@"subtitle-menu",@"subtitle-choice:Timing sample",@"subtitle-timing-decoded",@"subtitle-timing-load",@"subtitle-timing-load-await",@"subtitle-timing-start",@"player-resume",@"subtitle-timing-await",@"subtitle-timing-audit",@"player-pause",@"subtitle-menu",@"subtitle-choice:Off",@"subtitle-timing-off"])[steps addObject:@{@"kind":kind,@"wait":@.3}];
        [steps addObjectsFromArray:@[@{@"kind":@"player-resume",@"wait":@3},@{@"kind":@"player-close",@"wait":@1}]];return steps;
    }
    if([@[@"subtitles-layout-native",@"subtitles-layout-mkv",@"subtitles-layout-native-landscape"]containsObject:action]){
        NSMutableArray *steps=[NSMutableArray new];void(^add)(NSString *)=^(NSString *kind){[steps addObject:@{@"kind":kind,@"wait":@.3}];};add(@"active-profile");
        for(NSString *orientation in ([action hasSuffix:@"-landscape"]?@[@"landscape"]:@[@"portrait",@"landscape"])){
            add([@"presentation-" stringByAppendingString:orientation]);add(@"presentation-await-orientation");add(@"subtitle-play");add(@"subtitle-await");add(@"player-pause");
            for(NSString *name in @[@"short",@"long",@"international",@"rtl"]){
                add(@"subtitle-menu");add([@"subtitle-choice:" stringByAppendingString:name]);add(@"subtitle-layout-await");
                for(NSString *size in @[@"Small",@"Medium",@"Large"]){add(@"subtitle-menu");add(@"subtitle-choice:Size and timing…");add([@"subtitle-choice:" stringByAppendingString:size]);add([NSString stringWithFormat:@"subtitle-layout-audit:%@:%@:%@",orientation,name,size]);}
            }
            add(@"subtitle-layout-toggle");add([@"subtitle-layout-audit:" stringByAppendingFormat:@"%@:rtl:hidden",orientation]);add(@"subtitle-layout-toggle");
            add(@"subtitle-menu");add(@"subtitle-choice:Off");add([@"subtitle-layout-audit:" stringByAppendingFormat:@"%@:off:Large",orientation]);
            [steps addObject:@{@"kind":@"player-resume",@"wait":@3}];add(@"player-close");add(@"subtitle-layout-await-close");
        }
        add(@"presentation-restore");add(@"presentation-await-orientation");add(@"presentation-audit-restored");return steps;
    }
    if([action isEqual:@"subtitles-text"]){
        NSMutableArray *steps=[NSMutableArray arrayWithArray:@[@{@"kind":@"active-profile",@"wait":@2},@{@"kind":@"subtitle-play",@"wait":@1},@{@"kind":@"subtitle-await",@"wait":@.5},@{@"kind":@"player-pause",@"wait":@.3}]];
        void(^add)(NSString *)=^(NSString *kind){[steps addObject:@{@"kind":kind,@"wait":@.3}];};
        for(NSString *name in @[@"unicode",@"cyrillic",@"central",@"overlap"]){
            add(@"subtitle-menu");add([@"subtitle-choice:" stringByAppendingString:name]);
            if([@[@"cyrillic",@"central"]containsObject:name]){add(@"subtitle-text-await:encoding");add(@"subtitle-text-audit:encoding");add([name isEqual:@"cyrillic"]?@"subtitle-choice:Cyrillic":@"subtitle-choice:Central European");}
            if([name isEqual:@"overlap"])add(@"subtitle-text-seek:6");
            add(@"subtitle-text-await:decoded");add([@"subtitle-text-audit:" stringByAppendingString:name]);
        }
        add(@"subtitle-text-seek:10");add(@"subtitle-text-audit:older");add(@"subtitle-menu");add(@"subtitle-choice:Off");add(@"subtitle-text-audit:off");add(@"player-resume");add(@"subtitle-text-await:advancing");add(@"player-close");add(@"home");return steps;
    }
    if([action isEqual:@"subtitles-http"]){
        NSMutableArray *steps=[NSMutableArray arrayWithArray:@[@{@"kind":@"active-profile",@"wait":@4},@{@"kind":@"http-play",@"wait":@1},@{@"kind":@"subtitle-await",@"wait":@1},@{@"kind":@"player-pause",@"wait":@0.5}]];
        for(NSString *name in @[@"srt",@"vtt",@"redirect",@"headers",@"chunked",@"gzip",@"missing",@"loop",@"malformed",@"https"]){
            [steps addObjectsFromArray:@[@{@"kind":@"subtitle-menu",@"wait":@0.5},@{@"kind":[@"subtitle-choice:" stringByAppendingString:name],@"wait":@0.5},@{@"kind":[@"http-await-" stringByAppendingString:name],@"wait":@0.5},@{@"kind":[@"http-audit-" stringByAppendingString:name],@"wait":@0.3}]];
            if([@[@"headers",@"chunked",@"gzip",@"missing",@"loop",@"malformed"]containsObject:name])[steps addObject:@{@"kind":@"http-dismiss-error",@"wait":@0.3}];
        }
        [steps addObjectsFromArray:@[@{@"kind":@"subtitle-menu",@"wait":@0.5},@{@"kind":@"subtitle-choice:slow",@"wait":@0.15},@{@"kind":@"subtitle-menu",@"wait":@0.5},@{@"kind":@"subtitle-choice:vtt",@"wait":@0.5},@{@"kind":@"http-await-replacement",@"wait":@4},@{@"kind":@"http-audit-replacement",@"wait":@0.3},@{@"kind":@"subtitle-menu",@"wait":@0.5},@{@"kind":@"subtitle-choice:slow",@"wait":@0.15},@{@"kind":@"subtitle-menu",@"wait":@0.5},@{@"kind":@"subtitle-choice:Off",@"wait":@4},@{@"kind":@"http-audit-off",@"wait":@0.3},@{@"kind":@"player-resume",@"wait":@2},@{@"kind":@"player-close",@"wait":@1},@{@"kind":@"home",@"wait":@0.5}]];return steps;
    }
    if([@[@"subtitles-native",@"subtitles-mkv"]containsObject:action]){
        NSMutableArray *steps=[NSMutableArray arrayWithArray:@[@{@"kind":@"active-profile",@"wait":@4},@{@"kind":@"subtitle-play",@"wait":@1},@{@"kind":@"subtitle-await",@"wait":@1},@{@"kind":@"player-pause",@"wait":@0.5},@{@"kind":@"subtitle-menu",@"wait":@0.5},@{@"kind":@"subtitle-audit-menu",@"wait":@0.3}]];
        if([action isEqual:@"subtitles-mkv"])[steps addObjectsFromArray:@[@{@"kind":@"subtitle-choice:embedded-English",@"wait":@0.5},@{@"kind":@"subtitle-audit-embedded",@"wait":@3},@{@"kind":@"subtitle-audit-embedded-settled",@"wait":@0.3},@{@"kind":@"subtitle-menu",@"wait":@0.5},@{@"kind":@"subtitle-choice:embedded-French",@"wait":@0.5},@{@"kind":@"subtitle-audit-embedded-french",@"wait":@0.1},@{@"kind":@"subtitle-audit-embedded-french-sample1",@"wait":@0.3},@{@"kind":@"subtitle-audit-embedded-french-sample2",@"wait":@0.5},@{@"kind":@"subtitle-audit-embedded-french-sample3",@"wait":@1.5},@{@"kind":@"subtitle-audit-embedded-french-settled",@"wait":@0.3},@{@"kind":@"subtitle-menu",@"wait":@0.5},@{@"kind":@"subtitle-choice:Off",@"wait":@0.5},@{@"kind":@"subtitle-audit-embedded-off",@"wait":@0.1},@{@"kind":@"subtitle-audit-embedded-off-sample1",@"wait":@0.3},@{@"kind":@"subtitle-audit-embedded-off-sample2",@"wait":@0.5},@{@"kind":@"subtitle-audit-embedded-off-sample3",@"wait":@1.5},@{@"kind":@"subtitle-audit-embedded-off-settled",@"wait":@0.3},@{@"kind":@"subtitle-menu",@"wait":@0.5},@{@"kind":@"subtitle-choice:embedded-English",@"wait":@0.5},@{@"kind":@"subtitle-audit-embedded-return",@"wait":@0.3},@{@"kind":@"subtitle-menu",@"wait":@0.5},@{@"kind":@"subtitle-choice:Timing…",@"wait":@0.5},@{@"kind":@"subtitle-choice:Show 0.5 seconds later",@"wait":@0.5},@{@"kind":@"subtitle-audit-embedded-delay",@"wait":@0.3}]];
        [steps addObjectsFromArray:@[@{@"kind":@"subtitle-menu",@"wait":@0.5},@{@"kind":@"subtitle-choice:English · Text file",@"wait":@1},@{@"kind":@"subtitle-audit-first",@"wait":@0.3},@{@"kind":@"subtitle-menu",@"wait":@0.5},@{@"kind":@"subtitle-choice:Size and timing…",@"wait":@0.5},@{@"kind":@"subtitle-audit-settings",@"wait":@0.3},@{@"kind":@"subtitle-choice:Large",@"wait":@0.5},@{@"kind":@"subtitle-audit-font",@"wait":@0.3},@{@"kind":@"subtitle-menu",@"wait":@0.5},@{@"kind":@"subtitle-choice:Size and timing…",@"wait":@0.5},@{@"kind":@"subtitle-choice:Reset timing",@"wait":@0.5},@{@"kind":@"subtitle-seek-boundary",@"wait":@1},@{@"kind":@"subtitle-audit-second",@"wait":@0.3},@{@"kind":@"subtitle-menu",@"wait":@0.5},@{@"kind":@"subtitle-choice:Size and timing…",@"wait":@0.5},@{@"kind":@"subtitle-choice:Show 0.5 seconds later",@"wait":@0.5},@{@"kind":@"subtitle-audit-delay",@"wait":@0.3},@{@"kind":@"subtitle-menu",@"wait":@0.5},@{@"kind":@"subtitle-choice:Off",@"wait":@0.5},@{@"kind":@"subtitle-audit-off",@"wait":@0.3},@{@"kind":@"player-resume",@"wait":@2},@{@"kind":@"player-close",@"wait":@1},@{@"kind":@"home",@"wait":@0.5}]];
        if([action isEqual:@"subtitles-mkv"]){NSMutableArray *observed=[NSMutableArray new];for(NSDictionary *step in steps){[observed addObject:step];NSString *kind=step[@"kind"];if([@[@"subtitle-audit-embedded-settled",@"subtitle-audit-embedded-french-settled",@"subtitle-audit-embedded-off-settled",@"subtitle-audit-embedded-return",@"subtitle-audit-embedded-delay"]containsObject:kind])[observed addObject:@{@"kind":[@"subtitle-frame:" stringByAppendingString:[kind substringFromIndex:[@"subtitle-audit-" length]]],@"wait":@.2}];}return observed;}
        return steps;
    }
    if([action isEqual:@"related-quality"])return @[
        @{@"kind":@"active-profile",@"wait":@8},
        @{@"kind":@"detail-open-interstellar",@"wait":@10},@{@"kind":@"detail-scroll-related",@"wait":@5},@{@"kind":@"detail-audit-related-interstellar",@"wait":@0.3},@{@"kind":@"home",@"wait":@1},
        @{@"kind":@"detail-open-series",@"wait":@12},@{@"kind":@"detail-related-tab",@"wait":@2},@{@"kind":@"detail-scroll-related",@"wait":@5},@{@"kind":@"detail-audit-related-severance",@"wait":@0.3},@{@"kind":@"home",@"wait":@1},
        @{@"kind":@"detail-open-dory",@"wait":@10},@{@"kind":@"detail-scroll-related",@"wait":@5},@{@"kind":@"detail-audit-related-dory",@"wait":@0.3},@{@"kind":@"home",@"wait":@1},
        @{@"kind":@"detail-open-matrix",@"wait":@10},@{@"kind":@"detail-scroll-related",@"wait":@5},@{@"kind":@"detail-audit-related-matrix",@"wait":@0.3},@{@"kind":@"home",@"wait":@1}];
    if([action isEqual:@"title-artwork"])return @[
        @{@"kind":@"active-profile",@"wait":@3},
        @{@"kind":@"detail-open-nature",@"wait":@20},
        @{@"kind":@"detail-stop-preview",@"wait":@12},
        @{@"kind":@"detail-audit-nature-artwork",@"wait":@0.3},
        @{@"kind":@"home",@"wait":@1},
        @{@"kind":@"detail-open-breakingbad",@"wait":@20},
        @{@"kind":@"detail-stop-preview",@"wait":@12},
        @{@"kind":@"detail-audit-breakingbad-artwork",@"wait":@0.3},
        @{@"kind":@"home",@"wait":@1}];
    if([action isEqual:@"detail-pages-landscape"]){
        NSMutableDictionary *base=[request mutableCopy];base[@"action"]=@"detail-pages";NSMutableArray *steps=[[self stepsForRequest:base build:build now:now]mutableCopy];
        [steps insertObjects:@[@{@"kind":@"presentation-landscape",@"wait":@.3},@{@"kind":@"presentation-await-orientation",@"wait":@.3}] atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1,2)]];
        [steps addObjectsFromArray:@[@{@"kind":@"presentation-restore",@"wait":@.3},@{@"kind":@"presentation-await-orientation",@"wait":@.3},@{@"kind":@"presentation-audit-restored",@"wait":@.3}]];return steps;
    }
    if([action isEqual:@"detail-pages"])return @[
        @{@"kind":@"active-profile",@"wait":@8},
        @{@"kind":@"detail-open-oak",@"wait":@12},
        @{@"kind":@"detail-audit-oak",@"wait":@0.3},
        @{@"kind":@"detail-scroll-director",@"wait":@8},
        @{@"kind":@"detail-audit-director",@"wait":@0.3},
        @{@"kind":@"detail-photo-fixture",@"wait":@4},@{@"kind":@"detail-audit-artwork-repaired",@"wait":@0.3},@{@"kind":@"detail-remove-photo-fixture",@"wait":@0.1},
        @{@"kind":@"detail-open-director",@"wait":@10},
        @{@"kind":@"detail-audit-director-page",@"wait":@0.3},
        @{@"kind":@"detail-back",@"wait":@1},
        @{@"kind":@"detail-audit-return",@"wait":@0.3},
        @{@"kind":@"detail-scroll-studio",@"wait":@8},
        @{@"kind":@"detail-audit-studio",@"wait":@0.3},
        @{@"kind":@"detail-rerender",@"wait":@1},
        @{@"kind":@"detail-audit-reuse",@"wait":@0.3},
        @{@"kind":@"home",@"wait":@1},
        @{@"kind":@"detail-open-interstellar",@"wait":@10},
        @{@"kind":@"detail-audit-interstellar",@"wait":@0.3},
        @{@"kind":@"detail-scroll-related",@"wait":@5},@{@"kind":@"detail-audit-related-movie",@"wait":@0.3},
        @{@"kind":@"home",@"wait":@1},
        @{@"kind":@"detail-open-series",@"wait":@12},
        @{@"kind":@"detail-audit-series",@"wait":@0.3},
        @{@"kind":@"detail-scroll-episodes",@"wait":@4},
        @{@"kind":@"detail-audit-episodes",@"wait":@0.3},
        @{@"kind":@"detail-related-tab",@"wait":@2},@{@"kind":@"detail-scroll-related",@"wait":@5},@{@"kind":@"detail-audit-related-series",@"wait":@0.3},
        @{@"kind":@"home",@"wait":@1}];
    if([action isEqual:@"reminders"])return @[
        @{@"kind":@"active-profile",@"wait":@8},
        @{@"kind":@"avail-upcoming",@"wait":@30},@{@"kind":@"avail-audit-coming",@"wait":@0.3},
        @{@"kind":@"avail-episodes",@"wait":@4},@{@"kind":@"avail-audit-coming-episodes",@"wait":@0.3},
        @{@"kind":@"avail-scroll-coming",@"wait":@12},@{@"kind":@"avail-audit-coming-lower",@"wait":@0.3},
        @{@"kind":@"avail-following",@"wait":@1},
        @{@"kind":@"reminder-open",@"wait":@0.6},@{@"kind":@"reminder-audit-menu",@"wait":@0.3},
        @{@"kind":@"reminder-dismiss",@"wait":@0.5},
        @{@"kind":@"reminder-fetch",@"wait":@21},@{@"kind":@"reminder-audit-fetch",@"wait":@0.3},
        @{@"kind":@"reminder-notify",@"wait":@1},@{@"kind":@"reminder-audit-notify",@"wait":@0.3},
        @{@"kind":@"home",@"wait":@1}];
    if([action isEqual:@"availability-layout"])return @[
        @{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-select-regular",@"wait":@8},
        @{@"kind":@"presentation-portrait",@"wait":@.3},@{@"kind":@"presentation-await-orientation",@"wait":@.5},
        @{@"kind":@"avail-upcoming",@"wait":@4},@{@"kind":@"avail-audit-coming-portrait",@"wait":@.3},
        @{@"kind":@"presentation-landscape",@"wait":@.3},@{@"kind":@"presentation-await-orientation",@"wait":@3},
        @{@"kind":@"avail-audit-coming-landscape",@"wait":@.3},
        @{@"kind":@"avail-episodes",@"wait":@4},@{@"kind":@"avail-audit-coming-episodes-landscape",@"wait":@.3},
        @{@"kind":@"presentation-portrait",@"wait":@.3},@{@"kind":@"presentation-await-orientation",@"wait":@3},
        @{@"kind":@"avail-audit-coming-episodes-portrait",@"wait":@.3},
        @{@"kind":@"presentation-restore",@"wait":@.3},@{@"kind":@"presentation-await-orientation",@"wait":@.5},
        @{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-original",@"wait":@2},@{@"kind":@"profile-picker",@"wait":@.2}];
    if([action isEqual:@"availability"]||[action isEqual:@"availability-refresh"])return @[
        @{@"kind":@"active-profile",@"wait":@8},@{@"kind":@"avail-audit-home",@"wait":@0.3},
        @{@"kind":@"scroll-vertical",@"fraction":@0.7,@"wait":@2},@{@"kind":@"avail-audit-home-lower",@"wait":@0.3},
        @{@"kind":[action isEqual:@"availability-refresh"]?@"avail-upcoming-refresh":@"avail-upcoming",@"wait":@30},@{@"kind":@"avail-audit-coming",@"wait":@0.3},
        @{@"kind":@"avail-episodes",@"wait":@4},@{@"kind":@"avail-audit-coming-episodes",@"wait":@0.3},
        @{@"kind":@"avail-scroll-coming",@"wait":@12},@{@"kind":@"avail-audit-coming-lower",@"wait":@0.3},
        @{@"kind":@"avail-waiting",@"wait":@2},@{@"kind":@"avail-audit-waiting",@"wait":@0.3},
        @{@"kind":@"avail-following",@"wait":@2},@{@"kind":@"avail-audit-following",@"wait":@0.3},
        @{@"kind":@"avail-open-followed",@"wait":@6},@{@"kind":@"avail-audit-detail",@"wait":@0.3},
        @{@"kind":@"avail-back",@"wait":@1},@{@"kind":@"avail-audit-return",@"wait":@0.3},
        @{@"kind":@"home",@"wait":@2},@{@"kind":@"avail-audit-home-return",@"wait":@0.3}];
    if([action isEqual:@"discovery"])return @[
        @{@"kind":@"active-profile",@"wait":@8},
        @{@"kind":@"search",@"wait":@1},
        @{@"kind":@"discover-people",@"wait":@12},
        @{@"kind":@"discover-audit-people",@"wait":@0.3},
        @{@"kind":@"discover-query-remote",@"wait":@10},
        @{@"kind":@"discover-audit-remote",@"wait":@0.3},
        @{@"kind":@"discover-query-person",@"wait":@10},
        @{@"kind":@"discover-audit-person",@"wait":@0.3},
        @{@"kind":@"discover-open-person",@"wait":@16},
        @{@"kind":@"discover-audit-person-page",@"wait":@0.3},
        @{@"kind":@"discover-back",@"wait":@2},
        @{@"kind":@"discover-audit-person-return",@"wait":@0.3},
        @{@"kind":@"discover-back",@"wait":@1},
        @{@"kind":@"discover-studios",@"wait":@12},
        @{@"kind":@"discover-audit-studios",@"wait":@0.3},
        @{@"kind":@"discover-query-studio",@"wait":@10},
        @{@"kind":@"discover-audit-studio",@"wait":@0.3},
        @{@"kind":@"discover-open-studio",@"wait":@16},
        @{@"kind":@"discover-audit-studio-page",@"wait":@0.3},
        @{@"kind":@"discover-back",@"wait":@2},
        @{@"kind":@"discover-audit-studio-return",@"wait":@0.3},
        @{@"kind":@"discover-back",@"wait":@1},
        @{@"kind":@"discover-moods",@"wait":@5},
        @{@"kind":@"discover-audit-moods",@"wait":@0.3},
        @{@"kind":@"discover-open-mood",@"wait":@6},
        @{@"kind":@"discover-audit-films",@"wait":@0.3},
        @{@"kind":@"discover-shows",@"wait":@3},
        @{@"kind":@"discover-audit-shows",@"wait":@0.3},
        @{@"kind":@"discover-back",@"wait":@1},
        @{@"kind":@"discover-back",@"wait":@1},
        @{@"kind":@"home",@"wait":@0.5}];
    if([action isEqual:@"cast-scroll"])return @[
        @{@"kind":@"active-profile",@"wait":@8},@{@"kind":@"cast-open",@"wait":@8},
        @{@"kind":@"cast-reveal",@"wait":@2},@{@"kind":@"cast-capture-first",@"wait":@0.4},
        @{@"kind":@"cast-end",@"wait":@1.2},@{@"kind":@"cast-capture-last",@"wait":@0.4},
        @{@"kind":@"cast-rerender",@"wait":@0.8},@{@"kind":@"cast-audit-reuse",@"wait":@0.3},
        @{@"kind":@"cast-open-person",@"wait":@25},@{@"kind":@"cast-audit-entity",@"wait":@0.3},
        @{@"kind":@"cast-back",@"wait":@1.5},@{@"kind":@"cast-audit-return",@"wait":@0.4},
        @{@"kind":@"cast-open-person",@"wait":@3},@{@"kind":@"cast-audit-entity",@"wait":@0.3},
        @{@"kind":@"cast-back",@"wait":@1.5},@{@"kind":@"cast-audit-return",@"wait":@0.4},
        @{@"kind":@"cast-return-home",@"wait":@0.4}];
    if([action isEqual:@"profile-cinematic"]){
        NSMutableDictionary *base=[request mutableCopy];base[@"action"]=@"profile-intro";NSMutableArray *steps=[[self stepsForRequest:base build:build now:now]mutableCopy];
        NSArray *extra=@[@{@"kind":@"profile-motion-enable-full",@"wait":@.2},@{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-motion-replay",@"wait":@.4},@{@"kind":@"profile-motion-brand-capture",@"wait":@1.6},@{@"kind":@"profile-motion-brand-done",@"wait":@.1}];
        [steps insertObjects:extra atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(2,extra.count)]];for(NSUInteger i=0;i<steps.count;i++)if([steps[i][@"kind"]isEqual:@"profile-original"]&&[steps[i][@"wait"]doubleValue]>1)steps[i]=@{@"kind":@"profile-original",@"wait":@3.1};return steps;
    }
    if([action isEqual:@"profile-intro"])return @[
        @{@"kind":@"profile-motion-initial",@"wait":@1.4},
        @{@"kind":@"profile-capture-picker",@"wait":@.1},
        @{@"kind":@"profile-other",@"wait":@.76},
        @{@"kind":@"profile-motion-center",@"wait":@.65},
        @{@"kind":@"profile-motion-background",@"wait":@1.25},
        @{@"kind":@"profile-motion-settled",@"wait":@.1},
        @{@"kind":@"profile-capture-home",@"wait":@.1},
        @{@"kind":@"profile-picker",@"wait":@.25},
        @{@"kind":@"profile-original",@"wait":@.76},
        @{@"kind":@"profile-motion-center",@"wait":@.65},
        @{@"kind":@"profile-motion-background",@"wait":@1.25},
        @{@"kind":@"profile-motion-settled",@"wait":@.1},
        @{@"kind":@"profile-capture-home",@"wait":@.1},
        @{@"kind":@"profile-picker",@"wait":@.25},
        @{@"kind":@"profile-motion-silent",@"wait":@.1},
        @{@"kind":@"profile-other",@"wait":@.01},
        @{@"kind":@"profile-motion-cancel",@"wait":@.1},
        @{@"kind":@"profile-picker",@"wait":@.25},
        @{@"kind":@"profile-original",@"wait":@3.1},
        @{@"kind":@"profile-motion-settled",@"wait":@.1},
        @{@"kind":@"profile-picker",@"wait":@.25}];
    if([@[@"home-categories",@"home-categories-landscape"]containsObject:action]){
        NSMutableArray *steps=[NSMutableArray new];
        for(NSString *profile in @[@"profile-select-regular",@"profile-select-kids"]){
            [steps addObjectsFromArray:@[@{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":profile,@"wait":@8}]];
            if([action isEqual:@"home-categories-landscape"]&&[profile isEqual:@"profile-select-regular"])[steps addObjectsFromArray:@[@{@"kind":@"presentation-landscape",@"wait":@.3},@{@"kind":@"presentation-await-orientation",@"wait":@.3}]];
            for(NSString *destination in @[@"Home",@"Movies",@"Series"]){[steps addObjectsFromArray:@[@{@"kind":@"rail-destination",@"destination":destination,@"wait":@4},@{@"kind":@"rail-categories-ready",@"wait":@1},@{@"kind":@"rail-categories-audit",@"label":@"upper",@"wait":@.3},@{@"kind":@"rail-categories-lower",@"wait":@3},@{@"kind":@"rail-categories-audit",@"label":@"lower",@"wait":@.3},@{@"kind":@"rail-categories-settle-artwork",@"wait":@.4},@{@"kind":@"rail-categories-audit",@"label":@"settled",@"wait":@.3}]];}
        }
        [steps addObjectsFromArray:@[@{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-original",@"wait":@2}]];
        if([action isEqual:@"home-categories-landscape"])[steps addObjectsFromArray:@[@{@"kind":@"presentation-restore",@"wait":@.3},@{@"kind":@"presentation-await-orientation",@"wait":@.3},@{@"kind":@"presentation-audit-restored",@"wait":@.3}]];
        [steps addObject:@{@"kind":@"profile-picker",@"wait":@.2}];return steps;
    }
    if([action isEqual:@"home-anchors"]){return @[@{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-select-regular",@"wait":@5},@{@"kind":@"rail-ready",@"row":@"for-you-movie",@"wait":@.5},@{@"kind":@"rail-audit",@"row":@"for-you-movie",@"label":@"before",@"wait":@.2},@{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-select-kids",@"wait":@3},@{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-select-regular",@"wait":@5},@{@"kind":@"rail-ready",@"row":@"for-you-movie",@"wait":@.5},@{@"kind":@"rail-audit",@"row":@"for-you-movie",@"label":@"return",@"wait":@.2},@{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-original",@"wait":@2},@{@"kind":@"profile-picker",@"wait":@.2}];}
    if([@[@"home-rails",@"home-rails-kids",@"home-series",@"home-series-kids",@"home-theme-series",@"home-theme-series-kids",@"home-world",@"home-world-kids"]containsObject:action]){
        BOOL kids=[action hasSuffix:@"kids"],series=[action containsString:@"series"]||[action hasPrefix:@"home-world"],world=[action hasPrefix:@"home-world"],theme=[action hasPrefix:@"home-theme-"];NSString *firstRow=world?@"world":theme?(kids?@"category-cartoon-time":@"category-series-drama"):series?@"for-you-series":kids?@"category-animated-adventures":@"category-movie-action";NSMutableArray *steps=[NSMutableArray arrayWithArray:@[@{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":kids?@"profile-select-kids":@"profile-select-regular",@"wait":@10}]];
        for(NSString *row in (series?@[firstRow]:@[firstRow,@"world",@"for-you-series"])){[steps addObjectsFromArray:@[@{@"kind":@"rail-ready",@"row":row,@"wait":@.5},@{@"kind":@"rail-audit",@"row":row,@"label":@"before",@"wait":@.2},@{@"kind":@"rail-end",@"row":row,@"wait":@2},@{@"kind":@"rail-await",@"row":row,@"wait":@2},@{@"kind":@"rail-audit",@"row":row,@"label":@"after",@"wait":@.2},@{@"kind":@"rail-settled",@"row":row,@"wait":@.5},@{@"kind":@"rail-audit",@"row":row,@"label":@"settled",@"wait":@.2}]];
            if([row isEqual:firstRow])[steps addObjectsFromArray:@[@{@"kind":@"rail-end",@"row":row,@"wait":@2},@{@"kind":@"rail-await",@"row":row,@"wait":@2},@{@"kind":@"rail-audit",@"row":row,@"label":@"deep",@"wait":@.2},@{@"kind":@"rail-settled",@"row":row,@"wait":@.5},@{@"kind":@"rail-audit",@"row":row,@"label":@"deep-settled",@"wait":@.2}]];
        }
        [steps addObjectsFromArray:@[@{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":kids?@"profile-select-regular":@"profile-select-kids",@"wait":@5},@{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":kids?@"profile-select-kids":@"profile-select-regular",@"wait":@5},@{@"kind":@"rail-ready",@"row":firstRow,@"wait":@.5},@{@"kind":@"rail-settled",@"row":firstRow,@"wait":@.5},@{@"kind":@"rail-audit",@"row":firstRow,@"label":@"return",@"wait":@.2},@{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-original",@"wait":@3},@{@"kind":@"profile-picker",@"wait":@.2}]];return steps;
    }
    if([action isEqual:@"kids-series"]||[action isEqual:@"kids-series-reopen"]){
        BOOL reopen=[action isEqual:@"kids-series-reopen"];NSMutableArray *steps=[NSMutableArray arrayWithArray:@[@{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-select-kids",@"wait":@8}]];
        if(!reopen)[steps addObjectsFromArray:@[@{@"kind":@"profile-series-load",@"wait":@15},@{@"kind":@"profile-series-evict",@"wait":@8}]];
        [steps addObjectsFromArray:@[@{@"kind":@"profile-series-audit",@"wait":@.2},@{@"kind":@"profile-density-first",@"wait":@.2},@{@"kind":@"scroll-horizontal",@"fraction":@.95,@"wait":@3},@{@"kind":@"profile-density-scrolled",@"wait":@.2},@{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-select-regular",@"wait":@4},@{@"kind":@"profile-catalog-main",@"wait":@.2},@{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-select-kids",@"wait":@5},@{@"kind":@"profile-series-audit",@"wait":@.2},@{@"kind":@"profile-density-return",@"wait":@.2},@{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-original",@"wait":@3},@{@"kind":@"profile-picker",@"wait":@.2}]];return steps;
    }
    if([action isEqual:@"kids-density"])return @[
        @{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-select-kids",@"wait":@20},
        @{@"kind":@"profile-density-first",@"wait":@.2},
        @{@"kind":@"scroll-horizontal",@"fraction":@.95,@"wait":@3},@{@"kind":@"profile-density-scrolled",@"wait":@.2},
        @{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-select-regular",@"wait":@5},@{@"kind":@"profile-audit-home",@"wait":@.2},
        @{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-select-kids",@"wait":@8},@{@"kind":@"profile-density-return",@"wait":@.2},
        @{@"kind":@"profile-picker",@"wait":@.3},@{@"kind":@"profile-original",@"wait":@3},@{@"kind":@"profile-picker",@"wait":@.2}];
    if([action isEqual:@"profiles-details"]){
        NSMutableArray *steps=[NSMutableArray arrayWithObject:@{@"kind":@"active-profile",@"wait":@8}];
        for(NSUInteger i=0;i<10;i++){
            [steps addObject:@{@"kind":@"profile-picker",@"wait":@0.3}];
            if(i==0)[steps addObject:@{@"kind":@"profile-capture-picker",@"wait":@0.4}];
            [steps addObject:@{@"kind":i%2?@"profile-original":@"profile-other",@"wait":@4}];
            [steps addObject:@{@"kind":@"profile-audit-home",@"wait":@0.25}];
            if(i<2)[steps addObject:@{@"kind":@"profile-capture-home",@"wait":@0.4}];
            [steps addObject:@{@"kind":@"profile-scroll-home",@"wait":@0.8}];
            [steps addObject:@{@"kind":@"profile-open-detail",@"type":i%4<2?@"series":@"movie",@"wait":@3}];
            [steps addObject:@{@"kind":@"profile-audit-detail",@"wait":@0.25}];
            if(i<2)[steps addObject:@{@"kind":@"profile-capture-detail",@"wait":@0.4}];
            [steps addObject:@{@"kind":@"profile-detail-back",@"wait":@0.6}];
            [steps addObject:@{@"kind":@"profile-audit-return",@"wait":@0.25}];
        }return steps;
    }
    if([action isEqual:@"loading-ui"]){
        NSMutableArray *steps=[NSMutableArray arrayWithObject:@{@"kind":@"active-profile",@"wait":@8}];
        for(NSString *kind in @[@"capture-home",@"loading-preview",@"capture-loading",@"loading-content",@"loading-refresh",@"loading-append",@"loading-error",@"loading-retry",@"loading-empty",@"loading-dismiss"])
            [steps addObject:@{@"kind":kind,@"wait":@0.4}];
        return steps;
    }
    if([action isEqual:@"playback-reconnect"])return @[@{@"kind":@"active-profile",@"wait":@0.5},@{@"kind":@"await-playback-catalog",@"wait":@0.5},@{@"kind":@"play-public",@"wait":@1},@{@"kind":@"await-playback",@"wait":@1},@{@"kind":@"network-await-offline",@"wait":@1},@{@"kind":@"network-seek",@"wait":@1},@{@"kind":@"network-await-recovery",@"wait":@1},@{@"kind":@"player-pause",@"wait":@1},@{@"kind":@"player-resume",@"wait":@5},@{@"kind":@"player-close",@"wait":@1},@{@"kind":@"home",@"wait":@1}];
    if([action isEqual:@"playback"]||[action isEqual:@"playback-long"])return @[@{@"kind":@"active-profile",@"wait":@0.5},@{@"kind":@"await-playback-catalog",@"wait":@0.5},@{@"kind":@"play-public",@"wait":@1},@{@"kind":@"await-playback",@"wait":@1},@{@"kind":@"player-pause",@"wait":@1},@{@"kind":@"player-resume",@"wait":@5},@{@"kind":@"player-close",@"wait":@1},@{@"kind":@"home",@"wait":@1}];
    if(![action isEqual:@"home-scroll"])return nil;
    NSMutableArray *steps=[NSMutableArray arrayWithObject:@{@"kind":@"active-profile",@"wait":@8}];
    for(NSUInteger i=0;i<4;i++) {
        [steps addObject:@{@"kind":@"scroll-vertical",@"fraction":@(i%2?.0:.6),@"wait":@2}];
        [steps addObject:@{@"kind":@"scroll-horizontal",@"fraction":@(i%2?.0:.7),@"wait":@2}];
    }
    for(NSUInteger i=0;i<20;i++) {
        [steps addObject:@{@"kind":@"search",@"wait":@1.5}];
        [steps addObject:@{@"kind":@"home",@"wait":@2}];
    }
    NSMutableArray *audited=[NSMutableArray new];for(NSDictionary *step in steps){[audited addObject:step];NSString *kind=step[@"kind"];if([kind isEqual:@"active-profile"]||[kind isEqual:@"home"]||[kind hasPrefix:@"scroll-"])[audited addObject:@{@"kind":@"home-audit-content",@"wait":@0.05}];}
    return audited;
}
@end
