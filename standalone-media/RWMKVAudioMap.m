#import "RWMKVAudioMap.h"
#import "RWAudioPolicy.h"
#include <math.h>
static NSString *Text(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static double Num(id x){return [x isKindOfClass:NSNumber.class]&&isfinite([x doubleValue])?[x doubleValue]:-1;}
static NSString *Name(id x){NSString *s=Text(x);if(s.length>180)s=[s substringToIndex:180];return [[s componentsSeparatedByCharactersInSet:NSCharacterSet.controlCharacterSet]componentsJoinedByString:@" "];}
static NSString *Family(id x){NSString *s=Text(x);if([@[@"A_AAC",@"A_AAC/MPEG4/LC",@"mp4a"]containsObject:s])return @"AAC";if([@[@"A_AC3",@"a52 "]containsObject:s])return @"AC3";if([@[@"A_EAC3",@"eac3"]containsObject:s])return @"EAC3";if([@[@"A_MPEG/L2",@"A_MPEG/L3",@"mpga",@"mp3 "]containsObject:s])return @"MPEG";return @"";}
static BOOL Matches(NSDictionary *h,NSDictionary *r){
    NSString *family=Family(h[@"codec"]);double rate=Num(r[@"sampleRate"]);
    if(!family.length||![family isEqual:Family(r[@"codec"])]||Num(h[@"channels"])!=Num(r[@"channels"])||rate<=0||rate>48000||
       (fabs(rate-Num(h[@"sampleRate"]))>1&&fabs(rate-Num(h[@"inputSampleRate"]))>1)||![Name(h[@"name"])isEqual:Name(r[@"name"])])return NO;
    NSString *lang=[RWAudioPolicy language:r[@"language"]];
    if([h[@"languageDeclared"]boolValue]&&![lang isEqual:h[@"language"]]&&![lang isEqual:h[@"legacyLanguage"]])return NO;
    return YES;
}
@implementation RWMKVAudioMap
+ (NSArray *)mapHeader:(NSArray *)header runtime:(NSArray *)runtime {
    if(![header isKindOfClass:NSArray.class]||![runtime isKindOfClass:NSArray.class]||!header.count||!runtime.count||header.count>128||runtime.count>128)return @[];
    NSMutableSet *ids=[NSMutableSet new],*numbers=[NSMutableSet new];BOOL ordered=header.count==runtime.count;
    for(id h in header){if(![h isKindOfClass:NSDictionary.class])return @[];double n=Num(h[@"containerNumber"]);if(n<1||n>INT32_MAX||floor(n)!=n||[numbers containsObject:@(n)])ordered=NO;[numbers addObject:@(n)];}
    for(id r in runtime){if(![r isKindOfClass:NSDictionary.class])return @[];double n=Num(r[@"id"]);if(n<0||n>INT32_MAX||floor(n)!=n||[ids containsObject:@(n)])return @[];[ids addObject:@(n)];}
    // Pinned Matroska ESCreate emits recognized tracks in TrackNumber order;
    // core ES IDs increase in emission order. Use order only if the complete
    // audio lists agree AND every pair independently matches its metadata.
    NSArray *hs=ordered?[header sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"containerNumber"]compare:b[@"containerNumber"]];}]:header;
    NSArray *rs=[runtime sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"id"]compare:b[@"id"]];}];
    if(ordered)for(NSUInteger i=0;i<hs.count;i++)if(!Matches(hs[i],rs[i])){ordered=NO;break;}
    NSMutableArray *out=[NSMutableArray new];
    for(NSUInteger i=0;i<header.count;i++){
        NSDictionary *h=ordered?hs[i]:header[i],*r=ordered?rs[i]:nil;
        if(!ordered){NSUInteger count=0;for(NSDictionary *candidate in runtime)if(Matches(h,candidate)){r=candidate;count++;}if(count!=1)continue;
            NSUInteger reverse=0;for(NSDictionary *other in header)if(Matches(other,r))reverse++;if(reverse!=1)continue;}
        if(![h[@"compatible"]boolValue])continue;
        NSMutableDictionary *mapped=[h mutableCopy];mapped[@"runtime_id"]=r[@"id"];mapped[@"mapping"]=ordered?@"complete_order_and_metadata":@"unique_metadata";[out addObject:mapped];
    }return out;
}
@end
