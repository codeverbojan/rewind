#import "../RWDeviceExercise.h"
#import "../RWPlaybackAdmission.h"
static NSUInteger checks,failures;
static void check(BOOL value){checks++;if(!value)failures++;}
int main(){@autoreleasepool{
    NSDictionary *valid=@{@"protocol":@1,@"expected_build":@61,@"expires":@1100,@"run":@"4291D630-9F47-4229-AD36-7095533ADDA8",@"action":@"home-scroll"};
    NSArray *steps=[RWDeviceExercise stepsForRequest:valid build:61 now:1000];check(steps.count==78);
    {
        NSMutableDictionary *r=[valid mutableCopy];r[@"expected_build"]=@287;r[@"action"]=@"audio-mkv";
        for(NSString *action in @[@"audio-mkv",@"subtitles-mkv"]){r[@"action"]=action;for(NSString *font in @[@"default",@"Arial"]){r[@"legacy_font"]=font;check([RWDeviceExercise stepsForRequest:r build:287 now:1000].count>0);}}
        for(id bad in @[@"",@"Helvetica",@"--text-renderer=none",@YES,NSNull.null,@[],@{}]){r[@"legacy_font"]=bad;check(![RWDeviceExercise stepsForRequest:r build:287 now:1000]);}
        r[@"legacy_font"]=@"Arial";for(NSString *action in @[@"audio-native",@"home-scroll",@"playback-title"]){r[@"action"]=action;check(![RWDeviceExercise stepsForRequest:r build:287 now:1000]);}
        r[@"action"]=@"audio-mkv";check(![RWDeviceExercise stepsForRequest:r build:287 now:1101]);r[@"expected_build"]=@286;check(![RWDeviceExercise stepsForRequest:r build:286 now:1000]);
    }
    {NSMutableDictionary *r=[valid mutableCopy];r[@"expected_build"]=@288;r[@"action"]=@"font-lookup";check([RWDeviceExercise stepsForRequest:r build:288 now:1000].count==2);for(NSString *key in @[@"legacy_font",@"playback_case",@"caption_check"]){r[key]=@"invalid";check(![RWDeviceExercise stepsForRequest:r build:288 now:1000]);[r removeObjectForKey:key];}check(![RWDeviceExercise stepsForRequest:r build:288 now:1101]);r[@"expected_build"]=@287;check(![RWDeviceExercise stepsForRequest:r build:287 now:1000]);}
    {
        NSMutableDictionary *r=[valid mutableCopy];r[@"expected_build"]=@289;r[@"legacy_font"]=@"HelveticaNeue";
        for(NSString *action in @[@"audio-mkv",@"subtitles-mkv"]){r[@"action"]=action;check([RWDeviceExercise stepsForRequest:r build:289 now:1000].count>0);}
        for(NSString *action in @[@"audio-native",@"home-scroll",@"playback-title",@"font-lookup"]){r[@"action"]=action;check(![RWDeviceExercise stepsForRequest:r build:289 now:1000]);}
        r[@"action"]=@"audio-mkv";check(![RWDeviceExercise stepsForRequest:r build:289 now:1101]);
        for(id bad in @[@"Helvetica Neue",@"HelveticaNeue --text-renderer=none",@"ArialMT",@YES,NSNull.null,@[],@{}]){r[@"legacy_font"]=bad;check(![RWDeviceExercise stepsForRequest:r build:289 now:1000]);}
        r[@"legacy_font"]=@"HelveticaNeue";r[@"expected_build"]=@288;check(![RWDeviceExercise stepsForRequest:r build:288 now:1000]);
    }
    {
        NSMutableDictionary *r=[valid mutableCopy];r[@"expected_build"]=@290;r[@"action"]=@"subtitles-font-mkv";
        NSArray *steps=[RWDeviceExercise stepsForRequest:r build:290 now:1000];check(steps.count==37);
        check([steps.firstObject[@"kind"]isEqual:@"active-profile"]);
        NSArray *kinds=[steps valueForKey:@"kind"];check([[kinds filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@",@"subtitle-frame:font-"]]count]==5);
        for(NSString *font in @[@"default",@"HelveticaNeue"]){r[@"legacy_font"]=font;check([RWDeviceExercise stepsForRequest:r build:290 now:1000].count==37);}
        r[@"legacy_font"]=@"Arial";check(![RWDeviceExercise stepsForRequest:r build:290 now:1000]);[r removeObjectForKey:@"legacy_font"];
        for(NSString *key in @[@"playback_case",@"caption_check",@"prepare_check",@"caption_choice",@"caption_probe"]){r[key]=@YES;check(![RWDeviceExercise stepsForRequest:r build:290 now:1000]);[r removeObjectForKey:key];}
        check(![RWDeviceExercise stepsForRequest:r build:290 now:1101]);r[@"expected_build"]=@289;check(![RWDeviceExercise stepsForRequest:r build:289 now:1000]);
    }
    NSMutableDictionary *real=[valid mutableCopy];real[@"action"]=@"playback-title";
    {
        NSMutableDictionary *r=[valid mutableCopy];r[@"action"]=@"playback-title";r[@"playback_case"]=@"severance";r[@"caption_check"]=@YES;r[@"caption_choice"]=@"severance-embedded";r[@"caption_probe"]=@"severance-2648";
        NSArray *k=[[RWDeviceExercise stepsForRequest:r build:61 now:1000]valueForKey:@"kind"];
        check(k.count==28);check([k containsObject:@"title-caption-startup"]&&![k containsObject:@"await-playback"]);
        check([k indexOfObject:@"title-caption-known-approach"]<[k indexOfObject:@"title-caption-known-seek"]);
        check([k indexOfObject:@"title-caption-known-presented"]<[k indexOfObject:@"title-caption-known-capture"]);
        check([k containsObject:@"title-caption-known-live"]&&[k containsObject:@"title-caption-known-observe"]&&[k containsObject:@"title-caption-off"]&&[k containsObject:@"player-close"]);
        for(NSString *key in @[@"action",@"playback_case",@"caption_check",@"caption_choice",@"caption_probe"]){NSMutableDictionary *bad=[r mutableCopy];bad[key]=@"arbitrary";check(![RWDeviceExercise stepsForRequest:bad build:61 now:1000]);}
        for(id value in @[@NO,@YES,NSNull.null,@[],@{},@2648.5]){r[@"caption_probe"]=value;check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);}
        r[@"caption_probe"]=@"severance-2648";check(![RWDeviceExercise stepsForRequest:r build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:r build:61 now:1101]);
        [r removeObjectForKey:@"caption_probe"];check([[[RWDeviceExercise stepsForRequest:r build:61 now:1000]valueForKey:@"kind"]containsObject:@"await-playback"]);
    }
    check(![RWDeviceExercise stepsForRequest:real build:61 now:1000]);
    {
        NSDictionary *identity=@{@"profile_id":@"test",@"type":@"movie",@"video_id":@"movie",@"quality":@0};
        NSString *hash=[@"a" stringByPaddingToLength:40 withString:@"a" startingAtIndex:0];
        NSDictionary *read=@{@"infoHash":hash,@"header_bytes_returned":@192,@"verified_read_bytes":@907264};
        NSMutableDictionary *p=[@{@"payload_source":hash,@"duration_reads":@[read],@"payload_bytes":@0,@"discovery":@{@"prepared_ready":@NO}}mutableCopy];
        NSMutableDictionary *d=[@{@"identity":identity,@"engine_created":@YES,@"preparation":p}mutableCopy];
        check([RWDeviceExercise preparedHeader:d matchesIdentity:identity]); // cached, no network rate yet
        for(NSString *key in identity){NSMutableDictionary *other=[identity mutableCopy];other[key]=@"different";check(![RWDeviceExercise preparedHeader:d matchesIdentity:other]);}
        d[@"engine_created"]=@NO;check(![RWDeviceExercise preparedHeader:d matchesIdentity:identity]);d[@"engine_created"]=@YES;
        p[@"payload_source"]=[@"b" stringByPaddingToLength:40 withString:@"b" startingAtIndex:0];check(![RWDeviceExercise preparedHeader:d matchesIdentity:identity]);p[@"payload_source"]=hash;
        for(NSString *key in @[@"header_bytes_returned",@"verified_read_bytes"]){NSMutableDictionary *empty=[read mutableCopy];empty[key]=@0;p[@"duration_reads"]=@[empty];check(![RWDeviceExercise preparedHeader:d matchesIdentity:identity]);}
        p[@"discovery"]=@{@"prepared_ready":@YES};check(![RWDeviceExercise preparedHeader:d matchesIdentity:identity]); // capacity alone is not a header read
        p[@"duration_reads"]=@[read,read,read];check(![RWDeviceExercise preparedHeader:d matchesIdentity:identity]);p[@"duration_reads"]=@[read];
        for(id bad in @[NSNull.null,@[],@"bad"]){check(![RWDeviceExercise preparedHeader:bad matchesIdentity:identity]);check(![RWDeviceExercise preparedHeader:d matchesIdentity:bad]);}
        check([RWDeviceExercise preparedHeader:d matchesIdentity:identity]);
        NSMutableDictionary *finished=[read mutableCopy];finished[@"prefix_finished"]=@YES;p[@"duration_reads"]=@[finished];
        p[@"payload_source"]=[@"b" stringByPaddingToLength:40 withString:@"b" startingAtIndex:0];
        check([RWDeviceExercise preparedHeader:d matchesIdentity:identity]);
        check([[RWDeviceExercise preparedHeaderRead:d matchesIdentity:identity][@"infoHash"]isEqual:hash]);
        p[@"payload_source"]=@"";check([RWDeviceExercise preparedHeader:d matchesIdentity:identity]);
        finished[@"verified_read_bytes"]=@0;check(![RWDeviceExercise preparedHeader:d matchesIdentity:identity]);
        finished[@"verified_read_bytes"]=@907264;finished[@"prefix_finished"]=@NO;check(![RWDeviceExercise preparedHeader:d matchesIdentity:identity]);
        finished[@"prefix_finished"]=@YES;finished[@"infoHash"]=[@"x" stringByPaddingToLength:40 withString:@"x" startingAtIndex:0];check(![RWDeviceExercise preparedHeader:d matchesIdentity:identity]);
    }
    {
        NSMutableDictionary *r=[valid mutableCopy];r[@"action"]=@"playback-title";r[@"playback_case"]=@"just-play-dead";r[@"prepare_check"]=@YES;
        NSArray *recipe=[RWDeviceExercise stepsForRequest:r build:61 now:1000],*k=[recipe valueForKey:@"kind"];
        check(recipe.count==12);check([k[4]isEqual:@"title-prepare"]&&[k[5]isEqual:@"title-prepare-await"]&&[k[6]isEqual:@"title-play"]);
        for(NSNumber *dwell in @[@0,@12]){r[@"prepare_dwell"]=dwell;check([RWDeviceExercise stepsForRequest:r build:61 now:1000].count==12);}
        for(id bad in @[@(-1),@1,@20,@"12",NSNull.null,@[]]){r[@"prepare_dwell"]=bad;check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);}
        r[@"prepare_dwell"]=@12;[r removeObjectForKey:@"prepare_check"];check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);r[@"prepare_check"]=@YES;[r removeObjectForKey:@"prepare_dwell"];
        check(![RWDeviceExercise stepsForRequest:r build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:r build:61 now:1101]);
        for(id bad in @[@NO,@"yes",NSNull.null,@[],@{}]){r[@"prepare_check"]=bad;check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);}r[@"prepare_check"]=@YES;
        r[@"caption_check"]=@YES;check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);[r removeObjectForKey:@"caption_check"];
        for(NSString *bad in @[@"arbitrary",@"severance",@"two-half-early"]){r[@"playback_case"]=bad;check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);}
        r[@"playback_case"]=@"just-play-dead";r[@"action"]=@"home-scroll";check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);
    }
    {NSMutableDictionary *r=[valid mutableCopy];r[@"action"]=@"playback-title";r[@"playback_case"]=@"severance";r[@"caption_check"]=@YES;
        NSArray *recipe=[RWDeviceExercise stepsForRequest:r build:61 now:1000],*k=[recipe valueForKey:@"kind"];check(recipe.count==30);check([k containsObject:@"await-playback"]);check([k containsObject:@"title-caption-english"]);check([k containsObject:@"title-caption-seek:middle"]&&[k containsObject:@"title-caption-seek:end"]);check([k containsObject:@"title-caption-off"]);check([k indexOfObject:@"await-playback"]<[k indexOfObject:@"title-caption-english"]);check(![RWDeviceExercise stepsForRequest:r build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:r build:61 now:1101]);
        for(id bad in @[@NO,@"yes",NSNull.null,@[],@{}]){r[@"caption_check"]=bad;check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);}
    }

    {
        NSMutableDictionary *r=[valid mutableCopy];r[@"action"]=@"playback-title";r[@"playback_case"]=@"back-to-future";r[@"caption_check"]=@YES;r[@"caption_choice"]=@"back-to-future-sidecar";
        NSArray *recipe=[RWDeviceExercise stepsForRequest:r build:61 now:1000],*k=[recipe valueForKey:@"kind"];check(recipe.count==31);check([k containsObject:@"title-caption-manual"]&&![k containsObject:@"title-caption-english"]);check([k indexOfObject:@"title-caption-export"]>[k indexOfObject:@"title-caption-ready"]);
        for(id bad in @[@YES,@"unknown",NSNull.null,@[],@{}]){r[@"caption_choice"]=bad;check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);}r[@"caption_choice"]=@"back-to-future-sidecar";
        r[@"playback_case"]=@"matrix";check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);r[@"playback_case"]=@"back-to-future";[r removeObjectForKey:@"caption_check"];check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);r[@"action"]=@"home-scroll";check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);
        NSDictionary *source=@{@"infoHash":@"0ce7772b55bef2da98c49aa1df608debbb20670f",@"resolvedFileIdx":@0,@"resolvedFilename":@"Back.to.the.Future.1985.720p.BrRip.x264.YIFY.mp4"};
        NSDictionary *choice=@{@"kind":@"torrent",@"match":@"release_filename",@"descriptor":@{@"kind":@"torrent",@"language":@"",@"stable":@YES,@"token":[@"a" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0]},@"raw":@{@"index":@2,@"size":@125647,@"filename":@"Back.to.the.Future.1985.720p.BrRip.x264.YIFY.srt"}};
        check([RWDeviceExercise isManualCaptionChoice:choice source:source videoID:@"tt0088763"]);check(![RWDeviceExercise isManualCaptionChoice:choice source:source videoID:@"tt0133093"]);
        for(NSString *key in source){NSMutableDictionary *bad=[source mutableCopy];bad[key]=NSNull.null;check(![RWDeviceExercise isManualCaptionChoice:choice source:bad videoID:@"tt0088763"]);}
        for(NSString *key in @[@"raw",@"descriptor",@"kind",@"match"]){NSMutableDictionary *bad=[choice mutableCopy];bad[key]=NSNull.null;check(![RWDeviceExercise isManualCaptionChoice:bad source:source videoID:@"tt0088763"]);}
        for(NSString *key in choice[@"raw"]){NSMutableDictionary *bad=[choice mutableCopy],*raw=[choice[@"raw"]mutableCopy];raw[key]=NSNull.null;bad[@"raw"]=raw;check(![RWDeviceExercise isManualCaptionChoice:bad source:source videoID:@"tt0088763"]);}
        for(NSString *key in choice[@"descriptor"]){NSMutableDictionary *bad=[choice mutableCopy],*d=[choice[@"descriptor"]mutableCopy];d[key]=NSNull.null;bad[@"descriptor"]=d;check(![RWDeviceExercise isManualCaptionChoice:bad source:source videoID:@"tt0088763"]);}
    }

    {
        NSMutableDictionary *r=[valid mutableCopy];r[@"action"]=@"playback-title";r[@"playback_case"]=@"severance";r[@"caption_check"]=@YES;r[@"caption_choice"]=@"severance-embedded";
        NSArray *recipe=[RWDeviceExercise stepsForRequest:r build:61 now:1000],*k=[recipe valueForKey:@"kind"];
        check(recipe.count==30);check([k containsObject:@"title-caption-manual"]&&![k containsObject:@"title-caption-english"]&&![k containsObject:@"title-caption-export"]);
        for(NSString *other in @[@"back-to-future",@"two-half-early",@"matrix"]){r[@"playback_case"]=other;check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);}
        r[@"playback_case"]=@"severance";[r removeObjectForKey:@"caption_check"];check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);
        NSDictionary *source=@{@"infoHash":@"e492a2eec786b2bb983766f77563f6ac629c30d8",@"resolvedFileIdx":@0,@"resolvedFilename":@"Severance.S02E01.720p.ATVP.WEB-DL.x264-MIKE.mkv"};
        NSDictionary *descriptor=@{@"kind":@"mkv",@"language":@"",@"stable":@YES,@"token":@"71d60df02dca598b9f15abecc943f051a108b6c74c0e253717032bb58afee33f"};
        NSDictionary *raw=@{@"id":@2,@"descriptor":descriptor,@"language":@"",@"mapping":@"complete_order_and_metadata"};
        NSDictionary *choice=@{@"kind":@"mkv",@"descriptor":descriptor,@"raw":raw};
        check([RWDeviceExercise isManualCaptionChoice:choice source:source videoID:@"tt11280740:2:1"]);
        for(NSString *other in @[@"tt11280740",@"tt11280740:1:1",@"tt11280740:2:2",@"tt0088763"])
            check(![RWDeviceExercise isManualCaptionChoice:choice source:source videoID:other]);
        for(NSString *key in source){NSMutableDictionary *bad=[source mutableCopy];bad[key]=NSNull.null;check(![RWDeviceExercise isManualCaptionChoice:choice source:bad videoID:@"tt11280740:2:1"]);}
        for(NSString *key in descriptor){NSMutableDictionary *bad=[choice mutableCopy],*d=[descriptor mutableCopy],*rawBad=[raw mutableCopy];d[key]=NSNull.null;bad[@"descriptor"]=d;rawBad[@"descriptor"]=d;bad[@"raw"]=rawBad;check(![RWDeviceExercise isManualCaptionChoice:bad source:source videoID:@"tt11280740:2:1"]);}
        for(NSString *key in raw){NSMutableDictionary *bad=[choice mutableCopy],*d=[raw mutableCopy];d[key]=NSNull.null;bad[@"raw"]=d;check(![RWDeviceExercise isManualCaptionChoice:bad source:source videoID:@"tt11280740:2:1"]);}
        for(id invalid in @[@(-1),@128,@1.5,@YES,@"2"]){NSMutableDictionary *bad=[choice mutableCopy],*d=[raw mutableCopy];d[@"id"]=invalid;bad[@"raw"]=d;check(![RWDeviceExercise isManualCaptionChoice:bad source:source videoID:@"tt11280740:2:1"]);}
        // Runtime IDs may differ; verified stable identity and mapping must win.
        NSMutableDictionary *moved=[choice mutableCopy],*runtime=[raw mutableCopy];runtime[@"id"]=@4;moved[@"raw"]=runtime;
        check([RWDeviceExercise isManualCaptionChoice:moved source:source videoID:@"tt11280740:2:1"]);
        NSMutableDictionary *english=[descriptor mutableCopy];english[@"language"]=@"en";moved[@"descriptor"]=english;runtime[@"descriptor"]=english;moved[@"raw"]=runtime;
        check(![RWDeviceExercise isManualCaptionChoice:moved source:source videoID:@"tt11280740:2:1"]);
    }

    for(id key in @[@"",@"arbitrary",@"https://example.com/movie",@1,NSNull.null]){real[@"playback_case"]=key;check(![RWDeviceExercise stepsForRequest:real build:61 now:1000]);}
    for(NSString *key in @[@"tenzing",@"just-play-dead",@"matrix",@"back-to-future",@"two-half-early",@"two-half-late",@"breaking-bad",@"severance"]){
        real[@"playback_case"]=key;NSArray *recipe=[RWDeviceExercise stepsForRequest:real build:61 now:1000];
        check(recipe.count==10);check([recipe[2][@"kind"]isEqual:@"title-load"]);check([recipe[3][@"kind"]isEqual:@"title-await"]);check([recipe[4][@"kind"]isEqual:@"title-play"]);
        check(![RWDeviceExercise stepsForRequest:real build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:real build:61 now:1101]);
        NSDictionary *title=[RWDeviceExercise playbackCase:key];check([title[@"id"]hasPrefix:@"tt"]);check([title[@"video_id"]hasPrefix:title[@"id"]]);
    }
    check([[RWDeviceExercise playbackCase:@"two-half-early"][@"video_id"]isEqual:@"tt0369179:1:1"]);
    check([[RWDeviceExercise playbackCase:@"two-half-late"][@"video_id"]isEqual:@"tt0369179:12:1"]);
    check([[RWDeviceExercise playbackCase:@"severance"][@"video_id"]isEqual:@"tt11280740:2:1"]);
    NSUInteger homes=0,search=0,scrolls=0,homeAudits=0;double total=0;
    for(NSDictionary *step in steps){homeAudits+=[step[@"kind"]isEqual:@"home-audit-content"];homes+=[step[@"kind"]isEqual:@"home"];search+=[step[@"kind"]isEqual:@"search"];scrolls+=[step[@"kind"]hasPrefix:@"scroll-"];total+=[step[@"wait"]doubleValue];}
    check(homes==20&&search==20&&scrolls==8);check(homeAudits==29);check(total<180);
    check(![RWDeviceExercise stepsForRequest:valid build:60 now:1000]);
    check(![RWDeviceExercise stepsForRequest:valid build:61 now:1101]);
    check(![RWDeviceExercise stepsForRequest:valid build:61 now:700]);
    for(id bad in @[[NSNull null],@[],@"command",@1,@{}])check(![RWDeviceExercise stepsForRequest:bad build:61 now:1000]);
    for(NSString *key in valid){NSMutableDictionary *bad=[valid mutableCopy];[bad removeObjectForKey:key];check(![RWDeviceExercise stepsForRequest:bad build:61 now:1000]);bad[key]=[NSNull null];check(![RWDeviceExercise stepsForRequest:bad build:61 now:1000]);}
    NSMutableDictionary *artRequest=[valid mutableCopy];artRequest[@"action"]=@"artwork-states";NSArray *artSteps=[RWDeviceExercise stepsForRequest:artRequest build:61 now:1000];
    check(artSteps.count==23);check([artSteps[1][@"kind"]isEqual:@"resume-prepare"]);check([[artSteps valueForKey:@"kind"]containsObject:@"artstate-audit-late"]);check([[artSteps valueForKey:@"kind"]containsObject:@"artstate-audit-corrupt"]);
    check(![RWDeviceExercise stepsForRequest:artRequest build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:artRequest build:61 now:1101]);
    NSMutableDictionary *ks=[valid mutableCopy];ks[@"action"]=@"kids-surfaces";NSArray *kss=[RWDeviceExercise stepsForRequest:ks build:61 now:1000];check(kss.count==44);check([[kss valueForKey:@"kind"]containsObject:@"kids-surface-revoke-related"]);check([[kss valueForKey:@"kind"]containsObject:@"kids-select-0"]);check([[kss valueForKey:@"kind"]containsObject:@"kids-select-12"]);check(![RWDeviceExercise stepsForRequest:ks build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:ks build:61 now:1101]);
    NSMutableDictionary *intro=[valid mutableCopy];intro[@"action"]=@"profile-intro";NSArray *introSteps=[RWDeviceExercise stepsForRequest:intro build:61 now:1000];
    check(introSteps.count==21);check([introSteps.firstObject[@"kind"]isEqual:@"profile-motion-initial"]);check([introSteps.lastObject[@"kind"]isEqual:@"profile-picker"]);
    check(![RWDeviceExercise stepsForRequest:intro build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:intro build:61 now:1101]);
    intro[@"action"]=@"profile-cinematic";NSArray *cinematicSteps=[RWDeviceExercise stepsForRequest:intro build:61 now:1000];check(cinematicSteps.count==26);check([cinematicSteps[2][@"kind"]isEqual:@"profile-motion-enable-full"]);check([cinematicSteps[6][@"kind"]isEqual:@"profile-motion-brand-done"]);check(![RWDeviceExercise stepsForRequest:intro build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:intro build:61 now:1101]);
    NSMutableDictionary *density=[valid mutableCopy];density[@"action"]=@"kids-density";NSArray *ds=[RWDeviceExercise stepsForRequest:density build:61 now:1000];
    check(ds.count==14);check([[ds valueForKey:@"kind"]containsObject:@"profile-density-return"]);check([ds[12][@"kind"]isEqual:@"profile-original"]);
    check(![RWDeviceExercise stepsForRequest:density build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:density build:61 now:1101]);
    for(NSString *action in @[@"kids-series",@"kids-series-reopen"]){NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=action;NSArray *steps=[RWDeviceExercise stepsForRequest:request build:61 now:1000];BOOL reopen=[action hasSuffix:@"reopen"];check(steps.count==(reopen?16:18));check([[steps valueForKey:@"kind"]containsObject:@"profile-series-evict"]==!reopen);check(![RWDeviceExercise stepsForRequest:request build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:request build:61 now:1101]);double duration=0;for(NSDictionary *step in steps)duration+=[step[@"wait"]doubleValue];check(duration<90);}
    NSMutableDictionary *close=[valid mutableCopy];close[@"action"]=@"close";check([[RWDeviceExercise stepsForRequest:close build:61 now:1000]count]==1);
    NSMutableDictionary *loading=[valid mutableCopy];loading[@"action"]=@"loading-ui";NSArray *loadingSteps=[RWDeviceExercise stepsForRequest:loading build:61 now:1000];
    check(loadingSteps.count==11);check([loadingSteps[1][@"kind"]isEqual:@"capture-home"]);check([loadingSteps[3][@"kind"]isEqual:@"capture-loading"]);check([loadingSteps.lastObject[@"kind"]isEqual:@"loading-dismiss"]);
    double loadingTime=0;for(NSDictionary *step in loadingSteps)loadingTime+=[step[@"wait"]doubleValue];check(loadingTime<20);
    NSMutableDictionary *playback=[valid mutableCopy];playback[@"action"]=@"playback";NSArray *playSteps=[RWDeviceExercise stepsForRequest:playback build:61 now:1000];check(playSteps.count==8);check([playSteps[1][@"kind"]isEqual:@"await-playback-catalog"]);check([playSteps[2][@"kind"]isEqual:@"play-public"]);check([playSteps[3][@"kind"]isEqual:@"await-playback"]);check([playSteps[6][@"kind"]isEqual:@"player-close"]);
    check(RWPlaybackCatalogAdmission(NO,8)==RWCatalogWaiting);check(RWPlaybackCatalogAdmission(YES,14.5)==RWCatalogReady);check(RWPlaybackCatalogAdmission(NO,34.9)==RWCatalogWaiting);check(RWPlaybackCatalogAdmission(NO,35)==RWCatalogExpired);check(RWPlaybackCatalogAdmission(YES,35)==RWCatalogExpired);check(RWPlaybackCatalogAdmission(YES,NAN)==RWCatalogExpired);check(RWPlaybackCatalogAdmission(NO,-1)==RWCatalogExpired);
    NSMutableDictionary *network=[valid mutableCopy];network[@"action"]=@"playback-reconnect";NSArray *networkSteps=[RWDeviceExercise stepsForRequest:network build:61 now:1000];check(networkSteps.count==11);check([networkSteps[4][@"kind"]isEqual:@"network-await-offline"]);check([networkSteps[5][@"kind"]isEqual:@"network-seek"]);check([networkSteps[6][@"kind"]isEqual:@"network-await-recovery"]);check(![RWDeviceExercise stepsForRequest:network build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:network build:61 now:1101]);
    NSMutableDictionary *profiles=[valid mutableCopy];profiles[@"action"]=@"profiles-details";NSArray *profileSteps=[RWDeviceExercise stepsForRequest:profiles build:61 now:1000];
    check(profileSteps.count==86);NSUInteger originals=0,others=0,opens=0,backs=0,audits=0,captures=0;double seconds=0;NSString *lastSelection=nil;
    for(NSDictionary *step in profileSteps){NSString *kind=step[@"kind"];originals+=[kind isEqual:@"profile-original"];others+=[kind isEqual:@"profile-other"];opens+=[kind isEqual:@"profile-open-detail"];backs+=[kind isEqual:@"profile-detail-back"];audits+=[kind hasPrefix:@"profile-audit-"];captures+=[kind hasPrefix:@"profile-capture-"];seconds+=[step[@"wait"]doubleValue];if([@[@"profile-original",@"profile-other"]containsObject:kind]){check(![kind isEqual:lastSelection]);lastSelection=kind;}}
    check(originals==5&&others==5);check(opens==10&&backs==10&&audits==30);check(captures==5);check(seconds<120);check([lastSelection isEqual:@"profile-original"]);check([profileSteps.lastObject[@"kind"]isEqual:@"profile-audit-return"]);
    NSMutableDictionary *cast=[valid mutableCopy];cast[@"action"]=@"cast-scroll";NSArray *castSteps=[RWDeviceExercise stepsForRequest:cast build:61 now:1000];check(castSteps.count==17);
    double castWait=0;for(NSDictionary *step in castSteps){castWait+=[step[@"wait"]doubleValue];check(![@[@"play-public",@"player-resume",@"close"]containsObject:step[@"kind"]]);}
    check(castWait<60); /* Includes bounded first-time actor identity/details/credits lookup. */check([castSteps.lastObject[@"kind"]isEqual:@"cast-return-home"]);check(![RWDeviceExercise stepsForRequest:cast build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:cast build:61 now:1101]);
    NSMutableDictionary *discovery=[valid mutableCopy];discovery[@"action"]=@"discovery";NSArray *discoverySteps=[RWDeviceExercise stepsForRequest:discovery build:61 now:1000];check(discoverySteps.count==31);double discoveryWait=0;NSUInteger discoveryAudits=0;for(NSDictionary *step in discoverySteps){discoveryWait+=[step[@"wait"]doubleValue];discoveryAudits+=[step[@"kind"]hasPrefix:@"discover-audit-"];check(![@[@"play-public",@"close",@"profile-other"]containsObject:step[@"kind"]]);}check(discoveryWait<150);check(discoveryAudits==12);check([discoverySteps.lastObject[@"kind"]isEqual:@"home"]);check(![RWDeviceExercise stepsForRequest:discovery build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:discovery build:61 now:1101]);
    NSMutableDictionary *related=[valid mutableCopy];related[@"action"]=@"related-quality";NSArray *relatedSteps=[RWDeviceExercise stepsForRequest:related build:61 now:1000];check(relatedSteps.count==18);double relatedWait=0;NSUInteger relatedAudits=0;for(NSDictionary *step in relatedSteps){relatedWait+=[step[@"wait"]doubleValue];relatedAudits+=[step[@"kind"]hasPrefix:@"detail-audit-related-"];check(![@[@"play-public",@"close",@"profile-other",@"detail-photo-fixture"]containsObject:step[@"kind"]]);}check(relatedWait<100);check(relatedAudits==4);
    {NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=@"detail-pages-landscape";NSArray *steps=[RWDeviceExercise stepsForRequest:request build:61 now:1000];check(steps.count==35);NSArray *k=[steps valueForKey:@"kind"];check([k indexOfObject:@"presentation-landscape"]<[k indexOfObject:@"detail-open-oak"]);check([k.lastObject isEqual:@"presentation-audit-restored"]);check([[k filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@",@"detail-audit-"]]count]==12);check(![RWDeviceExercise stepsForRequest:request build:60 now:1000]);}
    NSMutableDictionary *detail=[valid mutableCopy];detail[@"action"]=@"detail-pages";NSArray *detailSteps=[RWDeviceExercise stepsForRequest:detail build:61 now:1000];check(detailSteps.count==30);double detailWait=0;NSUInteger detailAudits=0;for(NSDictionary *step in detailSteps){detailWait+=[step[@"wait"]doubleValue];detailAudits+=[step[@"kind"]hasPrefix:@"detail-audit-"];check(![@[@"play-public",@"close",@"profile-other"]containsObject:step[@"kind"]]);}check(detailWait<110);check(detailAudits==12);check([detailSteps.lastObject[@"kind"]isEqual:@"home"]);
    NSMutableDictionary *longPlayback=[valid mutableCopy];longPlayback[@"action"]=@"playback-long";check([[RWDeviceExercise stepsForRequest:longPlayback build:61 now:1000]isEqual:playSteps]);check(![RWDeviceExercise stepsForRequest:longPlayback build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:longPlayback build:61 now:1101]);
    NSMutableDictionary *library=[valid mutableCopy];library[@"action"]=@"library-browse";NSArray *librarySteps=[RWDeviceExercise stepsForRequest:library build:61 now:1000];NSArray *libraryKinds=[librarySteps valueForKey:@"kind"];check(librarySteps.count==38);check([libraryKinds containsObject:@"library-audit-kids-list"]&&[libraryKinds containsObject:@"library-audit-kids-downloads"]);check([libraryKinds containsObject:@"presentation-restore"]);check(![libraryKinds containsObject:@"resume-play"]);check(![RWDeviceExercise stepsForRequest:library build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:library build:61 now:1101]);
    for(NSString *action in @[@"notification-routing",@"notification-schedule",@"notification-open-probe"]){
        NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=action;NSArray *recipe=[RWDeviceExercise stepsForRequest:request build:61 now:1000];NSArray *kinds=[recipe valueForKey:@"kind"];
        check(recipe.count>0);check(![RWDeviceExercise stepsForRequest:request build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:request build:61 now:1101]);
        check(![kinds containsObject:@"play-public"]&&![kinds containsObject:@"resume-play"]);
        check([kinds containsObject:@"notification-schedule"]==[action isEqual:@"notification-schedule"]);
        if([action isEqual:@"notification-routing"])check([kinds containsObject:@"notification-audit-profile"]&&[kinds containsObject:@"notification-audit-foreground"]&&[kinds containsObject:@"notification-audit-ignored"]);
    }
    NSMutableDictionary *reminders=[valid mutableCopy];reminders[@"action"]=@"reminders";NSArray *reminderSteps=[RWDeviceExercise stepsForRequest:reminders build:61 now:1000];check(reminderSteps.count==16);double reminderWait=0;for(NSDictionary *step in reminderSteps){reminderWait+=[step[@"wait"]doubleValue];check(![@[@"play-public",@"close",@"profile-other"]containsObject:step[@"kind"]]);}check(reminderWait<100);check([reminderSteps.lastObject[@"kind"]isEqual:@"home"]);check(![RWDeviceExercise stepsForRequest:reminders build:60 now:1000]);
    NSMutableDictionary *availability=[valid mutableCopy];availability[@"action"]=@"availability";NSArray *availabilitySteps=[RWDeviceExercise stepsForRequest:availability build:61 now:1000];check(availabilitySteps.count==20);double availabilityWait=0;NSUInteger availabilityAudits=0;for(NSDictionary *step in availabilitySteps){availabilityWait+=[step[@"wait"]doubleValue];availabilityAudits+=[step[@"kind"]hasPrefix:@"avail-audit-"];check(![@[@"play-public",@"close",@"profile-other"]containsObject:step[@"kind"]]);}check(availabilityWait<75);check(availabilityAudits==10);check([availabilitySteps.lastObject[@"kind"]isEqual:@"avail-audit-home-return"]);check(![RWDeviceExercise stepsForRequest:availability build:60 now:1000]);
    for(NSString *action in @[@"subtitles-native",@"subtitles-mkv"]){NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=action;NSArray *recipe=[RWDeviceExercise stepsForRequest:request build:61 now:1000];check(recipe.count==([action isEqual:@"subtitles-mkv"]?58:29));double wait=0;NSUInteger audits=0;for(NSDictionary *step in recipe){wait+=[step[@"wait"]doubleValue];audits+=[step[@"kind"]hasPrefix:@"subtitle-audit-"];check(![@[@"play-public",@"close",@"profile-other"]containsObject:step[@"kind"]]);}check(wait<40);check(audits==([action isEqual:@"subtitles-mkv"]?21:7));check([recipe.lastObject[@"kind"]isEqual:@"home"]);check(![RWDeviceExercise stepsForRequest:request build:60 now:1000]);}
    for(NSString *action in @[@"resume-save-native",@"resume-open-native",@"resume-save-mkv",@"resume-open-mkv",@"resume-save-torrent",@"resume-open-torrent"]){NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=action;NSArray *recipe=[RWDeviceExercise stepsForRequest:request build:61 now:1000];check(recipe.count==8);double wait=0;for(NSDictionary *step in recipe)wait+=[step[@"wait"]doubleValue];check(wait<10);check([recipe.firstObject[@"kind"]isEqual:@"resume-prepare"]);check([recipe.lastObject[@"kind"]isEqual:@"resume-record"]);check(![RWDeviceExercise stepsForRequest:request build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:request build:61 now:1101]);}
    NSMutableDictionary *http=[valid mutableCopy];http[@"action"]=@"subtitles-http";NSArray *httpSteps=[RWDeviceExercise stepsForRequest:http build:61 now:1000];NSUInteger httpAudits=0,httpWaits=0,httpErrors=0;double httpSeconds=0;
    for(NSDictionary *step in httpSteps){httpSeconds+=[step[@"wait"]doubleValue];httpAudits+=[step[@"kind"]hasPrefix:@"http-audit-"];httpWaits+=[step[@"kind"]hasPrefix:@"http-await-"];httpErrors+=[step[@"kind"]isEqual:@"http-dismiss-error"];}
    check(httpAudits==12&&httpWaits==11&&httpErrors==6);check(httpSeconds<60);check([httpSteps.lastObject[@"kind"]isEqual:@"home"]);check(![RWDeviceExercise stepsForRequest:http build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:http build:61 now:1101]);
    NSDictionary *owner=@{@"protocol":@1,@"build":@61,@"original":@"main",@"run":valid[@"run"]};
    {NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=@"home-categories";NSArray *steps=[RWDeviceExercise stepsForRequest:request build:61 now:1000];check(steps.count==49);NSUInteger audits=0;double waits=0;for(NSDictionary *step in steps){audits+=[step[@"kind"]isEqual:@"rail-categories-audit"];waits+=[step[@"wait"]doubleValue];check(![step[@"kind"]isEqual:@"play-public"]);}check(audits==18&&waits<100);check([steps.lastObject[@"kind"]isEqual:@"profile-picker"]);check(![RWDeviceExercise stepsForRequest:request build:60 now:1000]);}
    {NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=@"home-categories-landscape";NSArray *steps=[RWDeviceExercise stepsForRequest:request build:61 now:1000];check(steps.count==54);NSArray *kinds=[steps valueForKey:@"kind"];check([kinds indexOfObject:@"profile-select-regular"]<[kinds indexOfObject:@"presentation-landscape"]);check([kinds indexOfObject:@"profile-original"]<[kinds indexOfObject:@"presentation-restore"]);check([[kinds filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF == %@",@"rail-categories-audit"]]count]==18);check([kinds.lastObject isEqual:@"profile-picker"]);check(![RWDeviceExercise stepsForRequest:request build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:request build:61 now:1101]);}
    for(NSString *action in @[@"home-world",@"home-world-kids"]){NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=action;NSArray *steps=[RWDeviceExercise stepsForRequest:request build:61 now:1000];check(steps.count==24);NSUInteger ends=0;for(NSDictionary *step in steps){if(step[@"row"])check([step[@"row"]isEqual:@"world"]);ends+=[step[@"kind"]isEqual:@"rail-end"];}check(ends==2);check([steps.lastObject[@"kind"]isEqual:@"profile-picker"]);}
    {NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=@"availability-layout";NSArray *steps=[RWDeviceExercise stepsForRequest:request build:61 now:1000];check(steps.count==19);NSUInteger audits=0,rotations=0;double wait=0;for(NSDictionary *step in steps){audits+=[step[@"kind"]hasPrefix:@"avail-audit-coming"];rotations+=[step[@"kind"]isEqual:@"presentation-await-orientation"];wait+=[step[@"wait"]doubleValue];check(![step[@"kind"]isEqual:@"play-public"]);}check(audits==4&&rotations==4&&wait<30);check([steps.lastObject[@"kind"]isEqual:@"profile-picker"]);}
    for(NSString *action in @[@"home-series",@"home-series-kids"]){NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=action;NSArray *steps=[RWDeviceExercise stepsForRequest:request build:61 now:1000];check(steps.count==24);NSUInteger ends=0,settles=0;for(NSDictionary *step in steps){if(step[@"row"])check([step[@"row"]isEqual:@"for-you-series"]);ends+=[step[@"kind"]isEqual:@"rail-end"];settles+=[step[@"kind"]isEqual:@"rail-settled"];}check(ends==2&&settles==3);check([steps.lastObject[@"kind"]isEqual:@"profile-picker"]);}
    for(NSString *action in @[@"home-theme-series",@"home-theme-series-kids"]){NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=action;NSArray *steps=[RWDeviceExercise stepsForRequest:request build:61 now:1000];check(steps.count==24);NSUInteger ends=0;for(NSDictionary *step in steps){if(step[@"row"])check([step[@"row"]isEqual:[action hasSuffix:@"kids"]?@"category-cartoon-time":@"category-series-drama"]);ends+=[step[@"kind"]isEqual:@"rail-end"];}check(ends==2);check([steps.lastObject[@"kind"]isEqual:@"profile-picker"]);}
    {NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=@"availability-refresh";NSArray *steps=[RWDeviceExercise stepsForRequest:request build:61 now:1000];check(steps.count==20);check([[steps valueForKey:@"kind"]containsObject:@"avail-upcoming-refresh"]);}
    for(NSString *action in @[@"home-rails",@"home-rails-kids"]){NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=action;NSArray *steps=[RWDeviceExercise stepsForRequest:request build:61 now:1000];check(steps.count==38);NSArray *kinds=[steps valueForKey:@"kind"];check([kinds.firstObject isEqual:@"profile-picker"]&&[kinds.lastObject isEqual:@"profile-picker"]);NSUInteger scrolls=0;double waits=0;for(NSDictionary *step in steps){scrolls+=[step[@"kind"]isEqual:@"rail-end"];waits+=[step[@"wait"]doubleValue];}check(scrolls==4&&waits<55);check([[kinds filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF == %@",@"rail-settled"]]count]==5);check([steps[2][@"row"]isEqual:[action hasSuffix:@"kids"]?@"category-animated-adventures":@"category-movie-action"]);}
    NSMutableDictionary *lists=[valid mutableCopy];lists[@"action"]=@"feed-lists";NSArray *listSteps=[RWDeviceExercise stepsForRequest:lists build:61 now:1000];NSArray *listKinds=[listSteps valueForKey:@"kind"];
    check(listSteps.count==33);check([listKinds containsObject:@"feed-open-movies"]&&[listKinds containsObject:@"feed-open-series"]&&[listKinds containsObject:@"feed-open-entity"]);
    check([listKinds containsObject:@"feed-fixture-retry"]&&[listKinds containsObject:@"feed-fixture-dismiss"]);check(![listKinds containsObject:@"play-public"]);
    check(![RWDeviceExercise stepsForRequest:lists build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:lists build:61 now:1101]);
    NSMutableDictionary *feeds=[valid mutableCopy];feeds[@"action"]=@"feed-discovery";NSArray *feedSteps=[RWDeviceExercise stepsForRequest:feeds build:61 now:1000];NSArray *feedKinds=[feedSteps valueForKey:@"kind"];
    check(feedSteps.count==29);check([feedKinds.firstObject isEqual:@"active-profile"]&&[feedKinds.lastObject isEqual:@"home"]);
    check([feedKinds containsObject:@"feed-open-studio"]&&[feedKinds containsObject:@"feed-audit-page"]&&[feedKinds containsObject:@"feed-audit-return"]);
    check([feedKinds containsObject:@"feed-query-first"]&&[feedKinds containsObject:@"feed-query-final"]&&[feedKinds containsObject:@"feed-audit-query"]);
    check([feedKinds containsObject:@"feed-mood-scroll"]&&[feedKinds containsObject:@"feed-mood-audit"]&&[feedKinds containsObject:@"discover-shows"]);
    check(![feedKinds containsObject:@"play-public"]&&![feedKinds containsObject:@"resume-prepare"]&&![feedKinds containsObject:@"feed-fixture"]);
    double feedWait=0;for(NSDictionary *step in feedSteps)feedWait+=[step[@"wait"]doubleValue];check(feedWait<45);
    check(![RWDeviceExercise stepsForRequest:feeds build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:feeds build:61 now:1101]);
    for(NSString *action in @[@"feed-entity",@"feed-retry"]){
        NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=action;NSArray *recipe=[RWDeviceExercise stepsForRequest:request build:61 now:1000];NSArray *kinds=[recipe valueForKey:@"kind"];
        check(recipe.count==([action isEqual:@"feed-entity"]?10:9));check([kinds.firstObject isEqual:@"active-profile"]&&[kinds.lastObject isEqual:@"home"]);
        check(![kinds containsObject:@"feed-open-movies"]&&![kinds containsObject:@"feed-open-series"]&&![kinds containsObject:@"play-public"]);
        check([kinds containsObject:@"feed-open-entity"]==[action isEqual:@"feed-entity"]);check([kinds containsObject:@"feed-fixture-dismiss"]==[action isEqual:@"feed-retry"]);
        check(![RWDeviceExercise stepsForRequest:request build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:request build:61 now:1101]);
    }
    for(NSString *action in @[@"preferences-save-native",@"preferences-open-native",@"preferences-save-mkv",@"preferences-open-mkv",@"download-controls"]){
        NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=action;NSArray *recipe=[RWDeviceExercise stepsForRequest:request build:61 now:1000];NSArray *kinds=[recipe valueForKey:@"kind"];
        check([kinds.firstObject isEqual:@"resume-prepare"]);check(recipe.count>=10&&recipe.count<=25);double seconds=0;for(NSDictionary *step in recipe)seconds+=[step[@"wait"]doubleValue];check(seconds<30);
        check(![kinds containsObject:@"play-public"]&&! [kinds containsObject:@"feed-fixture"]);
        if([action isEqual:@"download-controls"]){check([kinds containsObject:@"download-confirm"]&&[kinds containsObject:@"download-audit-removed"]&&[kinds containsObject:@"download-audit-trim"]);check(![kinds containsObject:@"resume-play"]);}
        else{check([kinds containsObject:@"resume-play"]&&[kinds.lastObject isEqual:@"resume-record"]);check([kinds containsObject:@"prefs-audit-restored"]==[action hasPrefix:@"preferences-open-"]);check([kinds containsObject:@"prefs-choice:Off"]==[action hasPrefix:@"preferences-save-"]);}
        check(![RWDeviceExercise stepsForRequest:request build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:request build:61 now:1101]);
    }
    NSMutableDictionary *episode=[valid mutableCopy];episode[@"action"]=@"episode-progress";NSArray *episodeSteps=[RWDeviceExercise stepsForRequest:episode build:61 now:1000];
    check([episodeSteps.firstObject[@"kind"]isEqual:@"resume-prepare"]);check([episodeSteps.lastObject[@"kind"]isEqual:@"home"]);
    NSArray *kinds=[episodeSteps valueForKey:@"kind"];check([kinds containsObject:@"episode-choice:Mark as watched"]&&[kinds containsObject:@"episode-choice:Mark as unwatched"]);
    check([kinds containsObject:@"episode-audit-home-resume"]&&[kinds containsObject:@"episode-audit-home-next"]);
    check([kinds containsObject:@"episode-other-profile"]&&[kinds containsObject:@"episode-return-profile"]);
    check(![kinds containsObject:@"play-public"]&&! [kinds containsObject:@"resume-play"]);
    check(![RWDeviceExercise stepsForRequest:episode build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:episode build:61 now:1101]);
    NSMutableDictionary *torrent=[@{@"infoHash":@"c9e15763f722f23e98a29decdfae341b98d53056",@"publicTest":@YES,@"url":@"magnet:?xt=urn:btih:c9e15763f722f23e98a29decdfae341b98d53056&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce"}mutableCopy];
    check([RWDeviceExercise isResumeTorrentSource:torrent]);for(NSString *key in torrent){NSMutableDictionary *bad=[torrent mutableCopy];bad[key]=NSNull.null;check(![RWDeviceExercise isResumeTorrentSource:bad]);}check(![RWDeviceExercise isResumeTorrentSource:@"wrong"]);
    NSDictionary *owned=@{@"name":@"Device resume check",@"maxAge":@(-1),@"sources":@{@"rw:resume-owner":owner}};
    check([RWDeviceExercise ownsResumeProfile:owned build:61]);check(![RWDeviceExercise ownsResumeProfile:owned build:62]);
    for(id bad in @[@{},@[],@"main",NSNull.null,@{@"name":@"Main",@"maxAge":@(-1)},@{@"name":@"Device resume check",@"maxAge":@12,@"sources":owned[@"sources"]}])check(![RWDeviceExercise ownsResumeProfile:bad build:61]);
    for(NSString *field in owner){NSMutableDictionary *badOwner=[owner mutableCopy];badOwner[field]=NSNull.null;NSMutableDictionary *bad=[owned mutableCopy];bad[@"sources"]=@{@"rw:resume-owner":badOwner};check(![RWDeviceExercise ownsResumeProfile:bad build:61]);}
    NSDictionary *companion=@{@"name":@"Device audio other",@"maxAge":@(-1),@"sources":@{@"rw:audio-owner":owner}};
    check([RWDeviceExercise ownsAudioCompanion:companion parent:owned build:61]);check(![RWDeviceExercise ownsAudioCompanion:companion parent:owned build:62]);check(![RWDeviceExercise ownsAudioCompanion:companion parent:@{} build:61]);
    for(NSString *field in @[@"name",@"maxAge",@"sources"]){NSMutableDictionary *bad=[companion mutableCopy];bad[field]=NSNull.null;check(![RWDeviceExercise ownsAudioCompanion:bad parent:owned build:61]);}
    NSMutableDictionary *alienOwner=[owner mutableCopy];alienOwner[@"run"]=NSUUID.UUID.UUIDString;NSMutableDictionary *alien=[companion mutableCopy];alien[@"sources"]=@{@"rw:audio-owner":alienOwner};check(![RWDeviceExercise ownsAudioCompanion:alien parent:owned build:61]);
    for(NSString *action in @[@"audio-name-native",@"audio-name-mkv"]){NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=action;NSArray *recipe=[RWDeviceExercise stepsForRequest:request build:61 now:1000],*kinds=[recipe valueForKey:@"kind"];check(recipe.count==16);check([kinds.firstObject isEqual:@"resume-prepare"]&&[kinds.lastObject isEqual:@"player-close"]);check([kinds containsObject:@"audio-audit-named-menu"]&&[kinds containsObject:@"audio-choice:Polish · Stereo"]);check(![RWDeviceExercise stepsForRequest:request build:60 now:1000]);}
    for(NSString *action in @[@"audio-save-native",@"audio-open-native",@"audio-save-mkv",@"audio-open-mkv"]){NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=action;NSArray *recipe=[RWDeviceExercise stepsForRequest:request build:61 now:1000],*kinds=[recipe valueForKey:@"kind"];BOOL save=[action hasPrefix:@"audio-save-"];check(recipe.count>5&&recipe.count<50);check([kinds.firstObject isEqual:@"resume-prepare"]&&[kinds.lastObject isEqual:@"player-close"]);check([kinds containsObject:@"audio-choice:French · Stereo"]==save);check([kinds containsObject:@"audio-profile-other"]==!save);check([kinds containsObject:@"audio-audit-fallback"]==!save);check(![kinds containsObject:@"play-public"]);check(![RWDeviceExercise stepsForRequest:request build:60 now:1000]);if(!save){check([kinds indexOfObject:@"audio-profile-primary"]<[kinds indexOfObject:@"audio-audit-return"]);check([kinds indexOfObject:@"audio-audit-return"]<[kinds indexOfObject:@"audio-fallback-play"]);}}
    NSDictionary *state=@{@"activeProfile":@"main",@"profiles":@{@"main":@{@"maxAge":@(-1)},@"child":@{@"maxAge":@12},@"invalid":@{@"maxAge":@99}}};
    NSDictionary *pair=[RWDeviceExercise profilePairForState:state];check([pair isEqual:@{@"original":@"main",@"other":@"child"}]);
    NSMutableDictionary *kids=[state mutableCopy];kids[@"activeProfile"]=@"child";pair=[RWDeviceExercise profilePairForState:kids];check([pair isEqual:@{@"original":@"child",@"other":@"main"}]);check([state[@"activeProfile"]isEqual:@"main"]);
    for(id bad in @[@{},@{@"activeProfile":@"missing",@"profiles":state[@"profiles"]},@{@"activeProfile":@"invalid",@"profiles":state[@"profiles"]},@{@"activeProfile":@"main",@"profiles":@{@"main":@{@"maxAge":@(-1)}}},@{@"activeProfile":@"main",@"profiles":@{@"main":@{@"maxAge":@"12"}}}])check(![RWDeviceExercise profilePairForState:bad]);
    for(id bad in @[@"shell",@"play",@"install",@"erase",@"../../../x",@[]]){NSMutableDictionary *r=[valid mutableCopy];r[@"action"]=bad;check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);}
    NSDictionary *mp4=@{@"url":@"asset:subtitle-check.mp4"},*mkv=@{@"url":@"asset:subtitle-check.mkv"};
    check([RWDeviceExercise isEpisodeExerciseSource:mp4 videoID:@"rw:handoff:1:24"]);
    check([RWDeviceExercise isEpisodeExerciseSource:mkv videoID:@"rw:handoff:2:1"]);
    check(![RWDeviceExercise isEpisodeExerciseSource:mp4 videoID:@"tt123:1:24"]);
    check(![RWDeviceExercise isEpisodeExerciseSource:mp4 videoID:@"rw:handoff:2:1"]);
    check(![RWDeviceExercise isEpisodeExerciseSource:@{@"url":@"asset:subtitle-check.mp4",@"infoHash":@"abc"} videoID:@"rw:handoff:1:24"]);
    for(id value in @[@{},@[],@"asset:subtitle-check.mp4",NSNull.null])check(![RWDeviceExercise isEpisodeExerciseSource:value videoID:@"rw:handoff:1:24"]);
    NSMutableDictionary *handoff=[valid mutableCopy];handoff[@"action"]=@"episode-handoff";
    NSArray *handoffSteps=[RWDeviceExercise stepsForRequest:handoff build:61 now:1000];check(handoffSteps.count==10);
    check([handoffSteps[3][@"kind"]isEqual:@"handoff-next"]);check([handoffSteps.lastObject[@"kind"]isEqual:@"handoff-record"]);
    NSDictionary *offline=@{@"infoHash":@"c0ed8c16ade445c7121456d816e11be210abe43c",@"url":@"magnet:?xt=urn:btih:c0ed8c16ade445c7121456d816e11be210abe43c",@"fileIdx":@0};
    check([RWDeviceExercise isOfflineExerciseSource:offline]);
    for(NSString *key in offline){NSMutableDictionary *bad=[offline mutableCopy];[bad removeObjectForKey:key];check(![RWDeviceExercise isOfflineExerciseSource:bad]);}
    for(id bad in @[@[],@"magnet",NSNull.null])check(![RWDeviceExercise isOfflineExerciseSource:bad]);
    handoff[@"action"]=@"featured-ready";NSArray *featured=[RWDeviceExercise stepsForRequest:handoff build:61 now:1000];NSArray *featuredKinds=[featured valueForKey:@"kind"];
    check(featured.count==27);check([featuredKinds.firstObject isEqual:@"resume-prepare"]);check([featuredKinds.lastObject isEqual:@"player-close"]);
    for(NSString *step in @[@"offline-prepare",@"offline-await",@"offline-keep",@"featured-buffer-stop",@"featured-buffer-await",@"featured-pause-audit",@"featured-prepare",@"featured-await-ranking",@"featured-audit",@"featured-details",@"featured-back",@"featured-play",@"featured-play-audit"])check([featuredKinds containsObject:step]);
    check(![RWDeviceExercise stepsForRequest:handoff build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:handoff build:61 now:1101]);
    handoff[@"action"]=@"download-playback";NSArray *offlineSteps=[RWDeviceExercise stepsForRequest:handoff build:61 now:1000];check(offlineSteps.count==20);check([offlineSteps.lastObject[@"kind"]isEqual:@"offline-record"]);
    check([offlineSteps[5][@"kind"]isEqual:@"offline-try-remove"]&&[offlineSteps[6][@"kind"]isEqual:@"offline-await-remove"]);
    NSMutableDictionary *kidRequest=[valid mutableCopy];kidRequest[@"action"]=@"kids-boundaries";
    NSArray *kidSteps=[RWDeviceExercise stepsForRequest:kidRequest build:61 now:1000];check(kidSteps.count==42);
    check(![RWDeviceExercise stepsForRequest:kidRequest build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:kidRequest build:61 now:1101]);
    kidRequest[@"action"]=@"kids-playback";NSArray *kidPlayback=[RWDeviceExercise stepsForRequest:kidRequest build:61 now:1000];
    check(kidPlayback.count==23);check([kidPlayback.firstObject[@"kind"]isEqual:@"kids-film-prepare"]);
    check(![RWDeviceExercise stepsForRequest:kidRequest build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:kidRequest build:61 now:1101]);
    NSCountedSet *playbackKinds=[[NSCountedSet alloc]initWithArray:[kidPlayback valueForKey:@"kind"]];
    for(NSString *step in @[@"kids-film-denied",@"kids-film-play",@"kids-film-audit",@"kids-film-record",@"player-pause",@"player-resume",@"player-close"])check([playbackKinds countForObject:step]==2);
    NSDictionary *kidOwner=@{@"protocol":@1,@"build":@61,@"original":@"main",@"run":valid[@"run"],@"age":@12};
    NSDictionary *kidProfile=@{@"name":@"Device Kids check",@"maxAge":@12,@"sources":@{@"rw:kids-owner":kidOwner}};
    check([RWDeviceExercise ownsKidsProfile:kidProfile build:61 run:valid[@"run"]]);
    check(![RWDeviceExercise ownsKidsProfile:kidProfile build:62 run:valid[@"run"]]);
    check(![RWDeviceExercise ownsKidsProfile:kidProfile build:61 run:NSUUID.UUID.UUIDString]);
    for(id bad in @[@{},@[],@"main",NSNull.null])check(![RWDeviceExercise ownsKidsProfile:bad build:61 run:valid[@"run"]]);
    for(id bad in @[@"bad",@[],NSNull.null])check(![RWDeviceExercise ownsKidsProfile:kidProfile build:61 run:bad]);
    for(NSString *field in kidOwner){NSMutableDictionary *badOwner=[kidOwner mutableCopy];badOwner[field]=NSNull.null;NSMutableDictionary *bad=[kidProfile mutableCopy];bad[@"sources"]=@{@"rw:kids-owner":badOwner};check(![RWDeviceExercise ownsKidsProfile:bad build:61 run:valid[@"run"]]);}
    for(NSString *field in @[@"name",@"maxAge",@"sources"]){NSMutableDictionary *bad=[kidProfile mutableCopy];bad[field]=NSNull.null;check(![RWDeviceExercise ownsKidsProfile:bad build:61 run:valid[@"run"]]);}
    for(NSNumber *age in @[@0,@12,@13,@(-1)]){NSMutableDictionary *p=[kidProfile mutableCopy],*o=[kidOwner mutableCopy];p[@"maxAge"]=age;o[@"age"]=age;p[@"sources"]=@{@"rw:kids-owner":o};check([RWDeviceExercise ownsKidsProfile:p build:61 run:valid[@"run"]]==([age isEqual:@0]||[age isEqual:@12]));}
    {NSMutableDictionary *r=[valid mutableCopy];r[@"action"]=@"playback-lifecycle";NSArray *steps=[RWDeviceExercise stepsForRequest:r build:61 now:1000],*kinds=[steps valueForKey:@"kind"];check(steps.count==83);check([kinds.firstObject isEqual:@"active-profile"]&&[kinds.lastObject isEqual:@"home"]);check([kinds containsObject:@"lifecycle-cleanup-await"]);check(![kinds containsObject:@"play-public"]);check(![kinds containsObject:@"recovery-gate"]);
        NSUInteger cycle=0,released=0;for(NSString *kind in kinds){if([kind hasPrefix:@"lifecycle-play:"]){check([kind isEqual:cycle%2?@"lifecycle-play:mkv":@"lifecycle-play:native"]);cycle++;}if([kind isEqual:@"lifecycle-released"])released++;}check(cycle==6&&released==6);check(![RWDeviceExercise stepsForRequest:r build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:r build:61 now:1101]);}
    for(NSString *backend in @[@"native",@"mkv"]){NSDictionary *source=[RWDeviceExercise lifecycleSource:backend];check([RWDeviceExercise isLifecycleSource:source backend:backend]);check(![RWDeviceExercise isLifecycleSource:source backend:[backend isEqual:@"native"]?@"mkv":@"native"]);for(NSString *key in @[@"url",@"infoHash",@"filename",@"fileIdx"]){NSMutableDictionary *bad=[source mutableCopy];bad[key]=@"wrong";check(![RWDeviceExercise isLifecycleSource:bad backend:backend]);}NSMutableDictionary *bad=[source mutableCopy];bad[@"fileIdx"]=@NO;check(![RWDeviceExercise isLifecycleSource:bad backend:backend]);}check(![RWDeviceExercise lifecycleSource:@"other"]);
    for(NSString *backend in @[@"native",@"mkv"])for(NSString *phase in @[@"save-revision",@"open-revision-changed",@"open-revision-again",@"open-revision-restored",@"open-revision-profiles"]){
        NSString *action=[NSString stringWithFormat:@"preferences-%@-%@",phase,backend];NSMutableDictionary *r=[valid mutableCopy];r[@"action"]=action;
        NSArray *steps=[RWDeviceExercise stepsForRequest:r build:61 now:1000],*kinds=[steps valueForKey:@"kind"];BOOL profiles=[phase hasSuffix:@"profiles"];
        check(steps.count>10&&steps.count<100);check([kinds.firstObject isEqual:@"resume-prepare"]);check([kinds containsObject:@"prefs-revision-audit:saved"]);check(![kinds containsObject:@"play-public"]);
        check([kinds containsObject:@"prefs-revision-choice:Central European"]==[phase hasSuffix:@"changed"]);
        check([kinds containsObject:@"prefs-revision-audit:changed-unadjusted"]==[phase hasSuffix:@"changed"]);
        check([kinds containsObject:@"prefs-revision-other"]==profiles);check([kinds containsObject:@"prefs-revision-audit:empty-profile"]==profiles);
        check([kinds containsObject:@"prefs-revision-audit:primary-return"]==profiles);check([kinds containsObject:@"prefs-revision-audit:companion-return"]==profiles);
        if(profiles){check([kinds indexOfObject:@"prefs-revision-audit:empty-profile"]<[kinds indexOfObject:@"prefs-revision-add"]);check([kinds indexOfObject:@"prefs-revision-audit:companion"]<[kinds indexOfObject:@"prefs-revision-audit:primary-return"]);}
        check(![RWDeviceExercise stepsForRequest:r build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:r build:61 now:1101]);
        double wait=0;for(NSDictionary *step in steps)wait+=[step[@"wait"]doubleValue];check(wait<30);
    }
    for(NSString *action in @[@"preferences-open-revision-unknown-native",@"preferences-open-revision-changed-torrent"]){NSMutableDictionary *r=[valid mutableCopy];r[@"action"]=action;check(![RWDeviceExercise stepsForRequest:r build:61 now:1000]);}
    for(NSString *action in @[@"preferences-save-link-native",@"preferences-open-link-native",@"preferences-save-link-mkv",@"preferences-open-link-mkv"]){NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=action;NSArray *recipe=[RWDeviceExercise stepsForRequest:request build:61 now:1000];NSArray *kinds=[recipe valueForKey:@"kind"];BOOL save=[action hasPrefix:@"preferences-save-"];check(recipe.count>10&&recipe.count<40);check([kinds.firstObject isEqual:@"resume-prepare"]&&[kinds.lastObject isEqual:@"resume-record"]);check([kinds containsObject:@"prefs-link-add"]==save);check([kinds containsObject:@"prefs-choice:Cyrillic"]==save);check([kinds containsObject:@"prefs-link-seek:52"]==!save);check(![kinds containsObject:@"play-public"]);BOOL frames=[action isEqual:@"preferences-open-link-mkv"];check([kinds containsObject:@"prefs-link-frame:seek-52"]==frames);check([kinds containsObject:@"prefs-link-frame:seek-52-delayed"]==frames);if(frames){check([kinds indexOfObject:@"prefs-link-presented"]<[kinds indexOfObject:@"prefs-link-frame:seek-52"]);check([kinds indexOfObject:@"prefs-audit-link-52"]<[kinds indexOfObject:@"prefs-link-frame:seek-52"]);check([kinds indexOfObject:@"prefs-link-frame:seek-52-delayed"]<[kinds indexOfObject:@"player-resume"]);}}
    {
        NSMutableDictionary *r=[valid mutableCopy];r[@"action"]=@"subtitles-frames-mkv";r[@"expected_build"]=@293;
        NSArray *steps=[RWDeviceExercise stepsForRequest:r build:293 now:1000],*kinds=[steps valueForKey:@"kind"];
        check(steps.count==17);check([kinds.firstObject isEqual:@"active-profile"]&&[kinds.lastObject isEqual:@"player-close"]);
        check(![kinds containsObject:@"subtitle-timing-load"]&&![kinds containsObject:@"play-public"]);
        check([kinds indexOfObject:@"player-pause"]<[kinds indexOfObject:@"subtitle-timing-start"]);
        check([kinds indexOfObject:@"subtitle-timing-start"]<[kinds indexOfObject:@"subtitle-timing-audit"]);
        check([kinds containsObject:@"subtitle-timing-off"]);check(![RWDeviceExercise stepsForRequest:r build:293 now:1101]);
        r[@"expected_build"]=@294;NSArray *newSteps=[RWDeviceExercise stepsForRequest:r build:294 now:1000],*newKinds=[newSteps valueForKey:@"kind"];
        check(newSteps.count==29);check([newKinds containsObject:@"subtitle-clock-audit:paused-stable"]);check([newKinds containsObject:@"subtitle-clock-seek:12"]&&[newKinds containsObject:@"subtitle-clock-seek:6"]);check([newKinds indexOfObject:@"subtitle-timing-audit"]<[newKinds indexOfObject:@"subtitle-clock-seek:12"]);
        check([newSteps[[newKinds indexOfObject:@"subtitle-clock-audit:paused"]][@"wait"]doubleValue]==2);check([newSteps[[newKinds indexOfObject:@"subtitle-clock-audit:paused-stable"]][@"wait"]doubleValue]<1);
        r[@"expected_build"]=@292;check(![RWDeviceExercise stepsForRequest:r build:292 now:1000]);
    }
    for(NSString *action in @[@"subtitles-timing-native",@"subtitles-timing-mkv"]){
        NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=action;NSArray *recipe=[RWDeviceExercise stepsForRequest:request build:61 now:1000],*kinds=[recipe valueForKey:@"kind"];
        check(recipe.count==19);check([kinds.firstObject isEqual:@"active-profile"]&&[kinds.lastObject isEqual:@"player-close"]);
        check([kinds indexOfObject:@"subtitle-timing-load-await"]<[kinds indexOfObject:@"subtitle-timing-start"]);
        check([kinds indexOfObject:@"subtitle-timing-start"]<[kinds indexOfObject:@"subtitle-timing-audit"]);
        check([kinds containsObject:@"subtitle-choice:Timing sample"]&&[kinds containsObject:@"subtitle-timing-off"]);
        check(![kinds containsObject:@"play-public"]&&![kinds containsObject:@"resume-prepare"]);
        check(![RWDeviceExercise stepsForRequest:request build:60 now:1000]);check(![RWDeviceExercise stepsForRequest:request build:61 now:1101]);
    }
    for(NSString *action in @[@"subtitles-layout-native",@"subtitles-layout-mkv"]){
        NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=action;NSArray *recipe=[RWDeviceExercise stepsForRequest:request build:61 now:1000];NSArray *kinds=[recipe valueForKey:@"kind"];
        check(recipe.count>100&&recipe.count<180);check([kinds.firstObject isEqual:@"active-profile"]&&[kinds.lastObject isEqual:@"presentation-audit-restored"]);
        NSCountedSet *counts=[[NSCountedSet alloc]initWithArray:kinds];check([counts countForObject:@"subtitle-play"]==2&&[counts countForObject:@"player-close"]==2);check([counts countForObject:@"subtitle-layout-await-close"]==2);for(NSUInteger n=0;n<kinds.count;n++)if([kinds[n]isEqual:@"player-close"])check(n+1<kinds.count&&[kinds[n+1]isEqual:@"subtitle-layout-await-close"]);
        for(NSString *orientation in @[@"portrait",@"landscape"])for(NSString *name in @[@"short",@"long",@"international",@"rtl"])for(NSString *size in @[@"Small",@"Medium",@"Large"])check([kinds containsObject:[NSString stringWithFormat:@"subtitle-layout-audit:%@:%@:%@",orientation,name,size]]);
        check(![kinds containsObject:@"play-public"]&&![kinds containsObject:@"resume-prepare"]);double duration=0;for(NSDictionary *step in recipe)duration+=[step[@"wait"]doubleValue];check(duration<100);
        check(![RWDeviceExercise stepsForRequest:request build:62 now:1000]);check(![RWDeviceExercise stepsForRequest:request build:61 now:1101]);
    }
    {NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=@"subtitles-layout-native-landscape";NSArray *recipe=[RWDeviceExercise stepsForRequest:request build:61 now:1000],*kinds=[recipe valueForKey:@"kind"];check(recipe.count>60&&recipe.count<100);check([kinds containsObject:@"presentation-landscape"]&&![kinds containsObject:@"presentation-portrait"]);check([kinds containsObject:@"subtitle-layout-audit:landscape:rtl:Large"]);check([kinds.lastObject isEqual:@"presentation-audit-restored"]);}
    // The USB recovery recipe has exactly one owned source and no caller URLs.
    {NSDictionary *source=[RWDeviceExercise recoverySource];check([RWDeviceExercise isRecoverySource:source]);
     for(NSString *key in @[@"url",@"infoHash",@"fileIdx",@"filename"]){NSMutableDictionary *bad=[source mutableCopy];[bad removeObjectForKey:key];check(![RWDeviceExercise isRecoverySource:bad]);bad[key]=[key isEqual:@"fileIdx"]?(id)@1:(id)@"other";check(![RWDeviceExercise isRecoverySource:bad]);}
     NSMutableDictionary *bad=[source mutableCopy];bad[@"fileIdx"]=@"0";check(![RWDeviceExercise isRecoverySource:bad]);bad[@"fileIdx"]=@0.5;check(![RWDeviceExercise isRecoverySource:bad]);check(![RWDeviceExercise isRecoverySource:@[]]);
     NSMutableDictionary *request=[valid mutableCopy];request[@"action"]=@"playback-controlled-mkv";
     NSArray *recipe=[RWDeviceExercise stepsForRequest:request build:61 now:1000];NSArray *kinds=[recipe valueForKey:@"kind"];
     check(recipe.count==30&&[kinds containsObject:@"recovery-blocked"]&&[kinds containsObject:@"recovery-sustain"]&&[kinds containsObject:@"recovery-cleanup-await"]);
     check([source[@"subtitles"][0][@"url"]isEqual:@"http://127.0.0.1:18884/recovery-captions.srt"]);
     check([kinds indexOfObject:@"recovery-caption-observe"]<[kinds indexOfObject:@"recovery-captions"]);
     check([kinds indexOfObject:@"recovery-caption-pending"]<[kinds indexOfObject:@"recovery-caption-ready"]);
     check([kinds indexOfObject:@"recovery-caption-ready"]<[kinds indexOfObject:@"recovery-arm-outage"]);
     check([kinds indexOfObject:@"recovery-recovered"]<[kinds indexOfObject:@"recovery-clock-audit"]);
     check([kinds indexOfObject:@"recovery-seek-back"]<[kinds indexOfObject:@"recovery-paused-ready"]);
     check([kinds indexOfObject:@"recovery-paused-ready"]<[kinds indexOfObject:@"recovery-resume"]);
     check([kinds indexOfObject:@"recovery-sustain"]<[kinds indexOfObject:@"recovery-caption-off"]);
     check([kinds indexOfObject:@"recovery-caption-off-audit"]<[kinds indexOfObject:@"recovery-close"]);
     for(NSString *key in @[@"url",@"source",@"playback_case",@"prepare_check",@"caption_check",@"extra"]){NSMutableDictionary *other=[request mutableCopy];other[key]=@YES;check(![RWDeviceExercise stepsForRequest:other build:61 now:1000]);}
     check(![RWDeviceExercise stepsForRequest:request build:62 now:1000]);check(![RWDeviceExercise stepsForRequest:request build:61 now:1101]);
    }
    printf("{\"checks\":%lu,\"failures\":%lu}\n",(unsigned long)checks,(unsigned long)failures);return failures?1:0;
}}
