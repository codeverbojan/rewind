#import <Foundation/Foundation.h>
#import "../RWSubtitleLoadProbe.h"
#import "../RWSubtitles.h"
static int checks=0,failures=0;
static void check(BOOL ok){checks++;if(!ok)failures++;}
int main(){@autoreleasepool {
    NSDictionary *report=[RWSubtitleLoadProbe runCancelled:nil];
    check([report[@"status"]isEqual:@"complete"]);check([report[@"checks"]intValue]==10000);check([report[@"failures"]intValue]==0);check([report[@"cues"]intValue]==10000);
    check([report[@"data_bytes"]unsignedIntegerValue]<2*1024*1024);check([report[@"index_bytes"]unsignedIntegerValue]<=262144);check([report[@"parse_seconds"]doubleValue]>0);check([report[@"lookup_seconds"]doubleValue]>0);check([report[@"seconds"]doubleValue]<=15);
    check([report[@"resident_before"]unsignedLongLongValue]>0);check([report[@"observed_peak_resident"]unsignedLongLongValue]>=[report[@"resident_before"]unsignedLongLongValue]);
    check([[RWSubtitleLoadProbe runCancelled:^{return YES;}][@"status"]isEqual:@"cancelled"]);
    __block NSUInteger polls=0;check([[RWSubtitleLoadProbe runCancelled:^BOOL{return ++polls>10010;}][@"status"]isEqual:@"cancelled"]);check(polls==10011);
    NSDictionary *source=@{@"subtitles":@[@{@"name":@"Timing sample",@"url":@"asset:subtitle-timing.srt"}]};
    check([RWSubtitles providedBySource:source meta:@{} allowBundled:YES].count==1);check([RWSubtitles providedBySource:source meta:@{} allowBundled:NO].count==0);check(![RWSubtitles isBundledSubtitle:@"asset:other.srt"]);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
