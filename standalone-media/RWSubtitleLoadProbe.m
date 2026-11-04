#import "RWSubtitleLoadProbe.h"
#import "RWSubtitles.h"
#import <mach/mach.h>
static uint64_t RWSubtitleResident(void){struct mach_task_basic_info info={0};mach_msg_type_number_t n=MACH_TASK_BASIC_INFO_COUNT;return task_info(mach_task_self(),MACH_TASK_BASIC_INFO,(task_info_t)&info,&n)==KERN_SUCCESS?info.resident_size:0;}
static NSString *RWProbeTimestamp(NSUInteger n){return [NSString stringWithFormat:@"%02lu:%02lu:%02lu,000",(unsigned long)(n/3600),(unsigned long)(n/60%60),(unsigned long)(n%60)];}
@implementation RWSubtitleLoadProbe
+ (NSDictionary *)runCancelled:(BOOL(^)(void))cancelled {
    double began=NSProcessInfo.processInfo.systemUptime;
    BOOL(^stop)(void)=^BOOL{return (cancelled&&cancelled())||NSProcessInfo.processInfo.systemUptime-began>15;};
    if(stop())return @{@"status":@"cancelled"};
    __block NSMutableDictionary *out=[NSMutableDictionary new];uint64_t before=RWSubtitleResident(),peak=before;
    @autoreleasepool {
        NSMutableData *data=[NSMutableData new];
        for(NSUInteger i=0;i<10000;i++){@autoreleasepool {
            if(stop())return @{@"status":@"cancelled"};
            NSString *entry=[NSString stringWithFormat:@"%lu\n%@ --> %@\nCaption %lu — Café Привет 日本語\n\n",(unsigned long)i+1,RWProbeTimestamp(i*2),RWProbeTimestamp(i*2+1),(unsigned long)i];
            [data appendData:[entry dataUsingEncoding:NSUTF8StringEncoding]];
        }}
        double parseBegan=NSProcessInfo.processInfo.systemUptime;
        NSDictionary *parsed=[RWSubtitles parse:data format:@"srt" encoding:@"auto" cancelled:stop];
        double parseSeconds=NSProcessInfo.processInfo.systemUptime-parseBegan;NSArray *cues=parsed[@"cues"];
        peak=MAX(peak,RWSubtitleResident());NSUInteger checks=0,failures=0;
        if(![parsed[@"status"]isEqual:@"ok"]||cues.count!=10000)return @{@"status":parsed[@"status"]?:@"parse_failed",@"cues":@(cues.count)};
        double lookupBegan=NSProcessInfo.processInfo.systemUptime;
        for(NSUInteger j=0;j<5000;j++){@autoreleasepool {
            if(stop())return @{@"status":@"cancelled"};
            NSUInteger i=(j*7919)%10000;NSString *expected=[NSString stringWithFormat:@"Caption %lu — Café Привет 日本語",(unsigned long)i];
            failures+=![[RWSubtitles textIn:cues at:i*2+.25]isEqual:expected];checks++;
            failures+=[[RWSubtitles textIn:cues at:i*2+1.25]length]!=0;checks++;
            if(j%128==0)peak=MAX(peak,RWSubtitleResident());
        }}
        out=[@{@"status":failures?@"lookup_failed":@"complete",@"cues":@(cues.count),@"checks":@(checks),@"failures":@(failures),@"data_bytes":@(data.length),@"index_bytes":parsed[@"index_bytes"]?:@0,@"parse_seconds":@(parseSeconds),@"lookup_seconds":@(NSProcessInfo.processInfo.systemUptime-lookupBegan)}mutableCopy];
    }
    out[@"resident_before"]=@(before);out[@"observed_peak_resident"]=@(peak);out[@"resident_after"]=@(RWSubtitleResident());out[@"seconds"]=@(NSProcessInfo.processInfo.systemUptime-began);
    return out;
}
@end
