#import "RWSubtitles.h"
#include <math.h>
#include "RWSubtitleParser.inc"
static NSDictionary *LanguageCodes(void) {
    static NSDictionary *codes;static dispatch_once_t once;dispatch_once(&once,^{codes=@{@"en":@"en",@"eng":@"en",@"english":@"en",@"fr":@"fr",@"fre":@"fr",@"fra":@"fr",@"french":@"fr",@"de":@"de",@"ger":@"de",@"deu":@"de",@"german":@"de",@"es":@"es",@"spa":@"es",@"spanish":@"es",@"it":@"it",@"ita":@"it",@"italian":@"it",@"pt":@"pt",@"por":@"pt",@"portuguese":@"pt"};});return codes;
}
static NSString *LanguageCode(NSString *value) {
    if(![value isKindOfClass:NSString.class])return @"";
    for(NSString *part in [value.lowercaseString componentsSeparatedByCharactersInSet:NSCharacterSet.letterCharacterSet.invertedSet])if(part.length)return LanguageCodes()[part]?:part;
    return @"";
}
@implementation RWSubtitles
+ (NSArray *)providedBySource:(NSDictionary *)source meta:(NSDictionary *)meta allowBundled:(BOOL)bundled {
    NSMutableArray *out=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(id list in @[source[@"subtitles"]?:@[],meta[@"subtitles"]?:@[]])if([list isKindOfClass:NSArray.class])for(id raw in list){
        if(out.count==32)break;if(![raw isKindOfClass:NSDictionary.class])continue;
        NSString *url=[raw[@"url"]isKindOfClass:NSString.class]?raw[@"url"]:@"";NSURL *u=[NSURL URLWithString:url];
        BOOL http=[@[@"http",@"https"]containsObject:u.scheme.lowercaseString]&&u.host.length;
        BOOL asset=bundled&&[self isBundledSubtitle:url];
        if((!http&&!asset)||[seen containsObject:url])continue;[seen addObject:url];
        NSString *lang=[raw[@"lang"]isKindOfClass:NSString.class]?raw[@"lang"]:@"",*name=[raw[@"name"]isKindOfClass:NSString.class]?raw[@"name"]:@"";
        if(!name.length)name=lang.length?lang:@"Provided subtitles";NSMutableDictionary *file=[@{@"url":url,@"lang":lang,@"name":name}mutableCopy];for(NSString *key in @[@"forced",@"sdh"])if([raw[key]isKindOfClass:NSNumber.class])file[key]=@([raw[key]boolValue]);[out addObject:file];
    }return out;
}
+ (BOOL)fileName:(NSString *)name matchesLanguage:(NSString *)preferred {
    if(![name isKindOfClass:NSString.class])return NO;
    NSArray *parts=[[name.stringByDeletingPathExtension lowercaseString]componentsSeparatedByCharactersInSet:NSCharacterSet.letterCharacterSet.invertedSet];
    NSDictionary *codes=LanguageCodes();
    for(NSString *part in parts.reverseObjectEnumerator)if(codes[part])return [self language:codes[part] matches:preferred];return NO;
}
 + (BOOL)language:(NSString *)language matches:(NSString *)preferred {
    NSString *actual=LanguageCode(language),*wanted=LanguageCode(preferred);return actual.length&&wanted.length&&[actual isEqual:wanted];
}
 + (NSString *)textIn:(NSArray *)cues at:(double)time {
    if([cues isKindOfClass:RWSubtitleTimeline.class])return [(RWSubtitleTimeline *)cues textAt:time];
    if(!isfinite(time)||time<0)return @"";NSMutableArray *active=[NSMutableArray new];
    for(NSUInteger i=0;i<MIN(cues.count,(NSUInteger)10000);i++){NSDictionary *cue=cues[i];if([cue[@"start"]doubleValue]<=time&&time<[cue[@"end"]doubleValue]){[active addObject:cue[@"text"]];if(active.count==32)break;}}return RWSubtitleJoin(active);
}
+ (NSArray *)parse:(NSData *)data {return [self parse:data format:@"" encoding:@"auto" cancelled:nil][@"cues"];}
+ (NSDictionary *)parse:(NSData *)data format:(NSString *)format encoding:(NSString *)encoding cancelled:(BOOL(^)(void))cancelled {return RWSubtitleParse(data,format,encoding,cancelled);}
+ (BOOL)isBundledSubtitle:(NSString *)url {return [@[@"asset:subtitle-timing.srt",@"asset:subtitle-check.en.srt",@"asset:subtitle-text-unicode.srt",@"asset:subtitle-text-cyrillic.srt",@"asset:subtitle-text-central.srt",@"asset:subtitle-text-overlap.vtt",@"asset:subtitle-layout-short.srt",@"asset:subtitle-layout-long.srt",@"asset:subtitle-layout-international.srt",@"asset:subtitle-layout-rtl.srt"]containsObject:url?:@""];}
+ (NSArray *)encodingOptions {return @[@{@"id":@"auto",@"name":@"Automatic (Unicode)"},@{@"id":@"windows-1252",@"name":@"Western European"},@{@"id":@"windows-1250",@"name":@"Central European"},@{@"id":@"windows-1251",@"name":@"Cyrillic"}];}
@end
