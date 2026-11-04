#import "RWSourceExperience.h"
#include <math.h>
@implementation RWSourceExperience
+ (NSString *)keyForSource:(NSDictionary *)source {
    NSString *hash=[source[@"infoHash"]isKindOfClass:NSString.class]?source[@"infoHash"]:nil;
    if(hash.length!=40||[hash rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"]invertedSet]].location!=NSNotFound)return nil;
    id value=source[@"fileIdx"];double index=[value isKindOfClass:NSNumber.class]?[value doubleValue]:-1;
    if(value&&(![value isKindOfClass:NSNumber.class]||!isfinite(index)||index < -1||index>10000||index!=floor(index)))return nil;
    NSInteger file=(NSInteger)index;
    return [NSString stringWithFormat:@"%@:%ld",hash.lowercaseString,(long)file];
}
+ (NSString *)failureKind:(NSDictionary *)s {
    NSString *kind=s[@"failureKind"];if([@[@"local",@"metadata",@"unavailable",@"slow",@"format",@"playback"]containsObject:kind])return kind;
    NSString *r=[s[@"reason"]isKindOfClass:NSString.class]?[s[@"reason"]lowercaseString]:@"";
    if([s[@"local_checking"]boolValue]||[r containsString:@"storage"]||[r containsString:@"free space"]||[r containsString:@"cancel"]||[r containsString:@"offline"]||[r containsString:@"dns"])return @"local";
    if([r containsString:@"codec"]||[r containsString:@"not supported"]||[r containsString:@"unsupported"]||[r containsString:@"exceeds"]||[r containsString:@"differs from"]||[r containsString:@"not present"])return @"format";
    if([r containsString:@"too slow"])return @"slow";
    if(s[@"metadata"]&&![s[@"metadata"]boolValue])return @"metadata";
    if([r containsString:@"no usable startup"]||[r containsString:@"no peers"])return @"unavailable";
    return @"playback";
}
+ (NSDictionary *)record:(NSDictionary *)old source:(NSDictionary *)source success:(BOOL)success now:(double)now {
    return [self record:old source:source success:success assessment:nil capability:nil now:now];
}
+ (NSDictionary *)record:(NSDictionary *)old source:(NSDictionary *)source success:(BOOL)success assessment:(NSDictionary *)assessment capability:(NSString *)capability now:(double)now {
    NSMutableDictionary *r=[old isKindOfClass:NSDictionary.class]?[old mutableCopy]:[NSMutableDictionary new];
    r[@"updated"]=@(now);r[@"version"]=@1;
    if(success){r[@"success"]=@(now);[r removeObjectForKey:@"media_incompatibility"];[r removeObjectForKey:@"last_media_code"];[r removeObjectForKey:@"failure"];[r removeObjectForKey:@"failure_kind"];
        r[@"success_count"]=@(MIN(10000,[r[@"success_count"]integerValue]+1));
        NSMutableArray *samples=[r[@"samples"]isKindOfClass:NSArray.class]?[r[@"samples"]mutableCopy]:[NSMutableArray new];
        NSMutableDictionary *sample=[NSMutableDictionary dictionaryWithObject:@(now) forKey:@"at"];
        for(NSString *key in @[@"tap_to_advancing_seconds",@"measured_bytes_per_second",@"required_bytes_per_second_estimate",@"video_bytes",@"piece_bytes",@"verifiedWidth",@"verifiedHeight"]){
            id n=source[key];if([n isKindOfClass:NSNumber.class]&&isfinite([n doubleValue])&&[n doubleValue]>=0)sample[key]=n;
        }
        [samples addObject:sample];while(samples.count>6)[samples removeObjectAtIndex:0];r[@"samples"]=samples;
    }else{r[@"failure"]=@(now);r[@"failure_kind"]=[self failureKind:source];r[@"failure_count"]=@(MIN(10000,[r[@"failure_count"]integerValue]+1));}
    if(!success&&[assessment isKindOfClass:NSDictionary.class]){
        NSString *status=assessment[@"status"];
        if([status isEqual:@"unknown"])r[@"failure_kind"]=@"metadata";
        else if([status isEqual:@"policy"])r[@"failure_kind"]=@"local";
        else if([status isEqual:@"incompatible"]){
            r[@"failure_kind"]=@"format";
            // A caller's file locator is not sufficient. This index is supplied
            // by the selected engine after metadata/file identity verification.
            id index=source[@"resolvedFileIdx"];double file=[index isKindOfClass:NSNumber.class]?[index doubleValue]:-1;
            NSDictionary *evidence=assessment[@"evidence"];NSString *code=assessment[@"code"];
            BOOL known=[@[@"dimensions_exceeded",@"codec_unsupported",@"frame_rate_exceeded",@"h264_unsupported"]containsObject:code];
            NSData *data=[evidence isKindOfClass:NSDictionary.class]&&[NSJSONSerialization isValidJSONObject:evidence]?[NSJSONSerialization dataWithJSONObject:evidence options:0 error:nil]:nil;
            if(known&&file>=0&&file<=10000&&file==floor(file)&&capability.length&&capability.length<=128&&data.length&&data.length<=1024){
                NSDictionary *owned=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                r[@"media_incompatibility"]=@{@"version":@1,@"file_index":@((NSInteger)file),@"capability":capability,@"code":code,@"evidence":owned,@"at":@(now)};
            }
        }
        if([assessment[@"code"]isKindOfClass:NSString.class]&&[assessment[@"code"]length]<=64)r[@"last_media_code"]=assessment[@"code"];
    }
    return r;
}
+ (NSDictionary *)hints:(NSDictionary *)r now:(double)now {
    double good=now-[r[@"success"]doubleValue],bad=now-[r[@"failure"]doubleValue];NSString *kind=r[@"failure_kind"];
    double ttl=[kind isEqual:@"format"]?7*86400:[kind isEqual:@"slow"]?300:[kind isEqual:@"metadata"]||[kind isEqual:@"unavailable"]?90:[kind isEqual:@"playback"]?60:0;
    BOOL recentFailure=r[@"failure"]&&bad>=0&&bad<ttl;
    BOOL recentSuccess=r[@"success"]&&good>=0&&good<6*3600&&!recentFailure;
    NSMutableDictionary *h=[@{@"localSuccess":@(recentSuccess),@"localFailure":@(recentFailure)}mutableCopy];
    if(recentFailure)h[@"previousFailureKind"]=kind;
    NSDictionary *sample=[r[@"samples"]isKindOfClass:NSArray.class]?[r[@"samples"]lastObject]:nil;
    double age=now-[sample[@"at"]doubleValue];
    if(sample&&age>=0&&age<1800){h[@"previousSourceObservation"]=sample;h[@"previousObservationAgeSeconds"]=@(age);}
    return h;
}
// Providers, caches and history can carry old decorations. Rebuild all local
// hints only from this device's saved observations on every ranking boundary.
+ (NSDictionary *)sourceForRanking:(NSDictionary *)source record:(NSDictionary *)record capability:(NSString *)capability now:(double)now {
    NSMutableDictionary *s=[source mutableCopy];
    for(NSString *key in @[@"localMediaRejection",@"localSuccess",@"localFailure",@"previousFailureKind",@"previousSourceObservation",@"previousObservationAgeSeconds"])[s removeObjectForKey:key];
    NSDictionary *r=[record isKindOfClass:NSDictionary.class]?record:@{};
    [s addEntriesFromDictionary:[self hints:r now:now]];
    NSDictionary *proof=[r[@"media_incompatibility"]isKindOfClass:NSDictionary.class]?r[@"media_incompatibility"]:nil;
    NSString *key=[self keyForSource:source];double age=now-[proof[@"at"]doubleValue];
    id file=source[@"fileIdx"];
    if(key&&[file isKindOfClass:NSNumber.class]&&[file integerValue]>=0&&[proof[@"file_index"]isEqual:file]&&[proof[@"version"]isEqual:@1]&&[proof[@"capability"]isEqual:capability]&&age>=0&&age<7*86400){
        NSMutableDictionary *hint=[proof mutableCopy];hint[@"key"]=key;s[@"localMediaRejection"]=[hint copy];
    }
    return [s copy];
}
+ (void)trim:(NSMutableDictionary *)history {
    if(history.count<=128)return;
    NSArray *keys=[history.allKeys sortedArrayUsingComparator:^NSComparisonResult(id a,id b){return [history[a][@"updated"]compare:history[b][@"updated"]];}];
    for(NSUInteger i=0;i<keys.count-128;i++)[history removeObjectForKey:keys[i]];
}
@end
