#import <Foundation/Foundation.h>
#import "../RWSubtitlePolicy.h"
#import "../RWProfiles.h"
static int checks,failures;
static void Check(BOOL ok,NSString *s){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",s.UTF8String);}}
int main(){@autoreleasepool{
    NSString *media=[RWSubtitlePolicy fingerprint:@"releaseA"],*other=[RWSubtitlePolicy fingerprint:@"releaseB"],*video=@"tt123:1:1";
    NSDictionary *file=[RWSubtitlePolicy manualFileForURL:@" https://example.org/Show.ru.forced.sdh.srt?token=private "];
    Check(file&&[file[@"filename"]isEqual:@"Show.ru.forced.sdh.srt"],@"Manual URL normalized without losing signed query");
    NSDictionary *desc=[RWSubtitlePolicy descriptor:file kind:@"external" locator:file[@"url"]];Check([desc[@"language"]isEqual:@"ru"]&&[desc[@"forced"]boolValue]&&[desc[@"sdh"]boolValue],@"Explicit subtitle filename roles/language restored");
    NSMutableDictionary *profile=[RWProfiles make:@"Test" age:-1];profile[@"subtitleLinks"]=[RWSubtitlePolicy saveManualFile:file videoID:video mediaKey:media existing:nil now:100];profile[@"subtitleSelections"]=[RWSubtitlePolicy saveChoice:desc enabled:YES videoID:video mediaKey:media existing:nil now:100];
    NSDictionary *raw=@{@"profiles":@{@"main":profile},@"activeProfile":@"main",@"profilePickerVersion":@25,@"discoveryPreferencesVersion":@34};
    NSData *bytes=[NSJSONSerialization dataWithJSONObject:raw options:0 error:nil];NSMutableDictionary *state=[NSJSONSerialization JSONObjectWithData:bytes options:NSJSONReadingMutableContainers error:nil];[RWProfiles prepare:state];profile=[RWProfiles active:state];
    NSDictionary *restored=[RWSubtitlePolicy manualFileInProfile:profile videoID:video mediaKey:media];Check([restored isEqual:file],@"Manual caption URL survives actual cold-start normalization");
    Check(![RWSubtitlePolicy manualFileInProfile:profile videoID:@"tt123:1:2" mediaKey:media]&&![RWSubtitlePolicy manualFileInProfile:profile videoID:video mediaKey:other],@"Manual link isolated from another episode and release");
    Check(![RWSubtitlePolicy manualFileInProfile:[RWProfiles make:@"Other" age:-1]videoID:video mediaKey:media],@"No link inherited by another profile");
    Check([[RWSubtitlePolicy preference:profile videoID:video mediaKey:media][@"token"]isEqual:desc[@"token"]],@"Exact saved forced/SDH selection survives normalization");
    for(id url in @[@"file:///etc/passwd",@"javascript:alert(1)",@"asset:subtitle-check.en.srt",@"https://user:pass@example.org/a.srt",@"https://",NSNull.null,@"https://example.org/a\nsrt"])
        Check(![RWSubtitlePolicy manualFileForURL:url],@"Non-HTTP/credential/malformed URL rejected");
    NSMutableDictionary *map=[NSMutableDictionary new];for(int i=0;i<50;i++)map=[[RWSubtitlePolicy saveManualFile:file videoID:[NSString stringWithFormat:@"video%d",i]mediaKey:media existing:map now:100+i]mutableCopy];Check(map.count==32,@"Saved links bounded to32 titles/releases");
    Check(![RWSubtitlePolicy saveManualFile:file videoID:video mediaKey:@"" existing:nil now:100],@"Unknown media identity cannot persist external link across releases");
    Check(![RWSubtitlePolicy manualFileInProfile:@{@"subtitleLinks":@{@"":@{@"url":file[@"url"],@"updated":@100}}}videoID:video mediaKey:@""],@"Empty corrupted key cannot restore to unidentified media");
    Check(![RWSubtitlePolicy manualFileInProfile:(id)NSNull.null videoID:video mediaKey:media],@"Malformed profile rejected safely");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
