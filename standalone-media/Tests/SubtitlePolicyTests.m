#import <Foundation/Foundation.h>
#import "../RWSubtitlePolicy.h"
static int checks,failures;
static void Check(BOOL ok,NSString *s){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",s.UTF8String);}}
int main(){@autoreleasepool{
    NSDictionary *source=@{@"infoHash":@"0123456789abcdef0123456789abcdef01234567",@"resolvedFileIdx":@3,@"resolvedFilename":@"Show.S01E01.Release.mkv"};NSString *media=[RWSubtitlePolicy mediaKey:source bundleBuild:@"243"];
    Check(media.length==64,@"Hash and exact file establish release key");
    Check(![RWSubtitlePolicy mediaKey:@{@"infoHash":source[@"infoHash"]} bundleBuild:@"243"].length,@"Unresolved torrent identity is not persisted");
    Check(![RWSubtitlePolicy mediaKey:@{@"url":@"https://host/video.mp4?token=secret"}bundleBuild:@"243"].length,@"Mutable directURL alone cannot restore timings");
    Check(![[RWSubtitlePolicy mediaKey:@{@"url":@"asset:test.mp4"}bundleBuild:@"243"]isEqual:[RWSubtitlePolicy mediaKey:@{@"url":@"asset:test.mp4"}bundleBuild:@"244"]],@"Bundled update invalidates old exact media identity");
    NSString *p1=[RWSubtitlePolicy fingerprint:@{@"b":@2,@"a":@1}],*p2=[RWSubtitlePolicy fingerprint:@{@"a":@1,@"b":@2}];Check([p1 isEqual:p2],@"PropertyList dictionary order does not change identity");
    Check(![[RWSubtitlePolicy fingerprint:@[@1]]isEqual:[RWSubtitlePolicy fingerprint:@[@"1"]]],@"Canonical identities preserve types");
    NSDictionary *english=[RWSubtitlePolicy descriptor:@{@"name":@"English",@"language":@"en"}kind:@"external" locator:@"https://sub.test/sub.srt?token=secret"],*french=[RWSubtitlePolicy descriptor:@{@"language":@"fr",@"sdh":@YES}kind:@"native" locator:@{@"track":@5}],*forced=[RWSubtitlePolicy descriptor:@{@"language":@"eng",@"forced":@YES}kind:@"mkv" locator:@2];
    Check([english[@"language"]isEqual:@"en"]&&[forced[@"forced"]boolValue]&&[french[@"sdh"]boolValue],@"Language and explicit roles preserved");
    Check([[RWSubtitlePolicy descriptor:@{@"filename":@"English.Patient.fr.SDH.srt"}kind:@"torrent" locator:@4][@"language"]isEqual:@"fr"],@"Suffix language wins over movie title word");
    NSMutableDictionary *profile=[@{@"subtitleLanguage":@"en",@"subtitlesEnabled":@YES,@"subtitleDelay":@9}mutableCopy];NSString *video=@"tt123:1:1";
    NSDictionary *preference=[RWSubtitlePolicy preference:profile videoID:video mediaKey:media];Check(!preference[@"delay"]&&!preference[@"subtitleDelay"],@"Unscoped legacy delay is never inherited");
    Check([[RWSubtitlePolicy select:@[forced,english] preference:preference]isEqual:english],@"Full English preferred over forced-only track");
    profile[@"subtitleForced"]=@YES;Check([[RWSubtitlePolicy select:@[english,forced]preference:[RWSubtitlePolicy preference:profile videoID:video mediaKey:media]]isEqual:forced],@"Forced-only preference honored");profile[@"subtitleForced"]=@NO;
    NSDictionary *saved=[RWSubtitlePolicy saveChoice:french enabled:YES videoID:video mediaKey:media existing:nil now:100];profile[@"subtitleSelections"]=saved;
    NSData *json=[NSJSONSerialization dataWithJSONObject:profile options:0 error:nil];profile=[[NSJSONSerialization JSONObjectWithData:json options:NSJSONReadingMutableContainers error:nil]mutableCopy];
    preference=[RWSubtitlePolicy preference:profile videoID:video mediaKey:media];Check([preference[@"token"]isEqual:french[@"token"]]&&[preference[@"sdh"]boolValue],@"Explicit track andSDH surviveJSON restart");
    Check([[RWSubtitlePolicy select:@[english,french]preference:preference]isEqual:french],@"Saved actual track chosen over defaultlanguage");
    Check(![RWSubtitlePolicy preference:profile videoID:@"tt123:1:2" mediaKey:media][@"token"],@"Adjacent episode cannot inherit exact track");
    NSString *other=[RWSubtitlePolicy mediaKey:@{@"infoHash":source[@"infoHash"],@"resolvedFileIdx":@4}bundleBuild:@"243"];
    NSDictionary *changed=[RWSubtitlePolicy preference:profile videoID:video mediaKey:other];Check(!changed[@"token"]&&[changed[@"language"]isEqual:@"fr"]&&[changed[@"sdh"]boolValue],@"Different release retains onlylanguage/role intent");
    NSString *bytes=[RWSubtitlePolicy digest:[@"Subtitle versionA" dataUsingEncoding:NSUTF8StringEncoding]],*bytes2=[RWSubtitlePolicy digest:[@"Subtitle versionB" dataUsingEncoding:NSUTF8StringEncoding]];
    NSString *key=[RWSubtitlePolicy adjustmentKey:english videoID:video mediaKey:media contentDigest:bytes];
    Check(![RWSubtitlePolicy adjustmentKey:english videoID:video mediaKey:media contentDigest:nil].length,@"External offsets await exact downloaded bytes");
    Check(![key isEqual:[RWSubtitlePolicy adjustmentKey:english videoID:video mediaKey:media contentDigest:bytes2]],@"Changedbytes atsameURL never reuse olddelay");
    Check(![key isEqual:[RWSubtitlePolicy adjustmentKey:english videoID:@"tt123:1:2" mediaKey:media contentDigest:bytes]],@"Offset exactepisode binding");
    Check(![key isEqual:[RWSubtitlePolicy adjustmentKey:english videoID:video mediaKey:other contentDigest:bytes]],@"Offset exactrelease binding");
    profile[@"subtitleAdjustments"]=[RWSubtitlePolicy saveAdjustment:@{@"delay":@1.5,@"encoding":@"windows-1251"}key:key existing:nil now:100];Check([[RWSubtitlePolicy adjustment:profile key:key][@"delay"]doubleValue]==1.5,@"Exact subtitle offset restored");Check(![RWSubtitlePolicy adjustment:profile key:[RWSubtitlePolicy adjustmentKey:english videoID:video mediaKey:media contentDigest:bytes2]].count,@"Replacement bytes startwithoutoldencodingoroffset");
    Check(![RWSubtitlePolicy saveAdjustment:@{@"delay":@11,@"encoding":@"auto"}key:key existing:nil now:100],@"Existingdelaybound retained");
    Check(![RWSubtitlePolicy saveAdjustment:@{@"delay":@0,@"encoding":@"shell"}key:key existing:nil now:100],@"Onlysupported encodings persist");
    NSDictionary *off=[RWSubtitlePolicy saveChoice:nil enabled:NO videoID:video mediaKey:media existing:saved now:101];profile[@"subtitleSelections"]=off;
    Check(![[RWSubtitlePolicy preference:profile videoID:video mediaKey:media][@"enabled"]boolValue],@"ExplicitOffrestores onlythismedia");Check([[RWSubtitlePolicy preference:profile videoID:video mediaKey:other][@"enabled"]boolValue],@"Offdoesnotleak tootherrelease");
    for(NSArray *test in @[@[@"Show.S01E02.Release.en.srt",@"conflict"],@[@"Show.S01E01.Release.en.srt",@"release_filename"],@[@"Show.S01E01.Other.en.srt",@"episode"],@[@"eng.srt",@"unknown"],@[@"Show.S01E01-E02.en.srt",@"conflict"]])Check([[RWSubtitlePolicy sidecarMatch:@{@"filename":test[0]}videoID:video source:source]isEqual:test[1]],@"Sidecar episode/filename evidence classified");
    NSDictionary *unknown=@{@"descriptor":english,@"match":@"unknown"};Check(![RWSubtitlePolicy select:@[unknown]preference:[RWSubtitlePolicy preference:@{@"subtitlesEnabled":@YES}videoID:video mediaKey:media]],@"Generic packsubtitle not auto-selectedbylanguage");
    NSMutableDictionary *many=[NSMutableDictionary new];for(int i=0;i<90;i++)many=[[RWSubtitlePolicy saveChoice:english enabled:YES videoID:[NSString stringWithFormat:@"video%d",i]mediaKey:media existing:many now:100+i]mutableCopy];Check(many.count==64&&many[@"video89"]&&!many[@"video0"],@"Titlechoices bounded64 after90saves");
    NSDictionary *bad=@{@"media_key":media,@"enabled":@NO,@"forced":NSNull.null,@"updated":@100};Check([RWSubtitlePolicy preference:@{@"subtitleSelections":@{video:bad}}videoID:video mediaKey:media]!=nil,@"CorruptOffmetadata handled without messagingnull");
    profile[@"subtitlesEnabled"]=@NO;profile[@"subtitleSelections"]=saved;
    Check([[RWSubtitlePolicy preference:profile videoID:video mediaKey:other][@"enabled"]boolValue],@"Explicit selected language stays enabled for another release of same title");
    Check(![[RWSubtitlePolicy preference:profile videoID:@"tt123:1:2" mediaKey:other][@"enabled"]boolValue],@"Different episode still uses global disabled preference");
    NSString *huge=[@"x" stringByPaddingToLength:16385 withString:@"x" startingAtIndex:0];
    Check(![RWSubtitlePolicy fingerprint:@{huge:@1}].length,@"Oversized dictionary key cannot exceed canonical identity budget");
    NSMutableDictionary *wide=[NSMutableDictionary new];for(int i=0;i<5;i++)wide[[NSString stringWithFormat:@"%d%@",i,[huge substringToIndex:14000]]]=@1;
    Check(![RWSubtitlePolicy fingerprint:wide].length,@"Dictionary keys count toward aggregate identity bound");
    NSString *stored=[[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:@[saved,profile]options:0 error:nil]encoding:NSUTF8StringEncoding];Check(![stored containsString:@"secret"]&&![stored containsString:@"https://"],@"PersistedidentitydoesnotcontainrawcredentialsURLs");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
