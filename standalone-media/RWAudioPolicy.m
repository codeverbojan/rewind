#import "RWAudioPolicy.h"
#import <CommonCrypto/CommonDigest.h>
#include <math.h>
#include <stdint.h>
static NSString *Text(id v){return [v isKindOfClass:NSString.class]?v:@"";}
static BOOL Flag(id v){return [v isKindOfClass:NSNumber.class]&&[v boolValue];}
static double Number(id v){return [v isKindOfClass:NSNumber.class]&&isfinite([v doubleValue])?[v doubleValue]:-1;}
static NSString *Clean(id v){NSString *s=Text(v);if(s.length>180)s=[s substringToIndex:180];return [[s componentsSeparatedByCharactersInSet:NSCharacterSet.controlCharacterSet]componentsJoinedByString:@" "];}
static NSString *Hash(NSArray *values){NSData *data=[NSJSONSerialization dataWithJSONObject:values options:0 error:nil];unsigned char h[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,h);NSMutableString *s=[NSMutableString new];for(NSUInteger i=0;i<sizeof(h);i++)[s appendFormat:@"%02x",h[i]];return s;}
static BOOL Match(NSString *pattern,NSString *s){return [s rangeOfString:pattern options:NSRegularExpressionSearch|NSCaseInsensitiveSearch].location!=NSNotFound;}
static NSString *Role(NSDictionary *r){NSString *name=Clean(r[@"name"]);
    if([@[@"main",@"commentary",@"description",@"auxiliary"]containsObject:r[@"role"]?:@""])return r[@"role"];
    if(Flag(r[@"commentary"])||Match(@"\\bcommentar(?:y|ies|io|ios)\\b|\\bkommentar\\b",name))return @"commentary";
    if(Flag(r[@"description"])||Match(@"\\baudio[ ._-]*descri(?:ption|ptive)\\b|\\bdescribed[ ._-]*audio\\b|\\bAD\\b",name))return @"description";
    if(Flag(r[@"auxiliary"]))return @"auxiliary";return @"main";
}
static BOOL Digest(id v){NSString *s=Text(v);return s.length==64&&Match(@"\\A[0-9a-f]{64}\\z",s);}
static NSDictionary *Saved(id value){
    if(![value isKindOfClass:NSDictionary.class])return nil;NSDictionary *r=value;
    if(!Digest(r[@"media_key"])||!Digest(r[@"token"])||Number(r[@"updated"])<=0||![@[@"main",@"commentary",@"description",@"auxiliary"]containsObject:r[@"role"]?:@""])return nil;
    return @{@"media_key":r[@"media_key"],@"token":r[@"token"],@"language":[RWAudioPolicy language:r[@"language"]],@"role":r[@"role"],@"updated":r[@"updated"]};
}
static NSString *LanguageName(NSString *language){return language.length?([[NSLocale localeWithLocaleIdentifier:@"en"]displayNameForKey:NSLocaleLanguageCode value:language]?:language):@"Unknown language";}
// A container name is weaker evidence than a language tag. Accept only an
// explicit leading language name plus bounded audio qualifiers, never arbitrary
// release/title text or mixed-language descriptions. Keep the raw tag and token.
static NSString *NameLanguage(NSString *name){
    NSString *s=name.lowercaseString;
    for(NSString *mark in @[@"[",@"]",@"(",@")",@":",@","])s=[s stringByReplacingOccurrencesOfString:mark withString:@" "];
    NSMutableArray *words=[NSMutableArray new];for(NSString *word in [s componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet])if(word.length)[words addObject:word];
    if(!words.count||![@[@"english",@"angielski"]containsObject:words[0]])return @"";
    static NSSet *qualifiers;static dispatch_once_t once;dispatch_once(&once,^{qualifiers=[NSSet setWithArray:@[@"original",@"oryginalny",@"main",@"default",@"stereo",@"mono",@"surround",@"aac",@"ac3",@"ac-3",@"eac3",@"e-ac-3",@"dts",@"flac",@"truehd",@"pcm",@"lpcm",@"5.1",@"2.0",@"1.0",@"6ch",@"2ch",@"commentary",@"audio",@"description",@"descriptive",@"director",@"director's",@"director’s",@"directors"]];});
    for(NSUInteger i=1;i<words.count;i++)if(![qualifiers containsObject:words[i]])return @"";return @"en";
}
@implementation RWAudioPolicy
+ (NSString *)language:(id)value {
    NSString *s=Text(value).lowercaseString;if(!s.length||s.length>64)return @"";s=[s stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
    static NSDictionary *aliases;static dispatch_once_t once;dispatch_once(&once,^{aliases=@{@"eng":@"en",@"english":@"en",@"fra":@"fr",@"fre":@"fr",@"french":@"fr",@"deu":@"de",@"ger":@"de",@"german":@"de",@"spa":@"es",@"spanish":@"es",@"ita":@"it",@"por":@"pt",@"rus":@"ru",@"ces":@"cs",@"cze":@"cs",@"pol":@"pl",@"jpn":@"ja",@"zho":@"zh",@"chi":@"zh",@"kor":@"ko",@"nld":@"nl",@"dut":@"nl",@"mkd":@"mk",@"mac":@"mk",@"srp":@"sr",@"hrv":@"hr",@"ara":@"ar",@"hin":@"hi"};});
    if(aliases[s])return aliases[s];if(!Match(@"\\A[a-z]{2,3}(?:-[a-z0-9]{2,8})*\\z",s))return @"";
    NSString *base=[s componentsSeparatedByString:@"-"].firstObject;if([@[@"und",@"mul",@"zxx",@"mis"]containsObject:base])return @"";return aliases[base]?:base;
}
// AVFoundation exposes ISO track name/kind as raw public AVMetadataItem
// values, not commonMetadata. Decode only these known bounded representations.
+ (NSDictionary *)nativeMetadata:(NSArray *)metadata {
    if(![metadata isKindOfClass:NSArray.class]||metadata.count>128)return @{};
    NSMutableDictionary *result=[NSMutableDictionary new];
    for(id raw in metadata){if(![raw isKindOfClass:NSDictionary.class])continue;NSDictionary *m=raw;id value=m[@"value"];
        if([m[@"common"]isEqual:@"title"]&&[value isKindOfClass:NSString.class]&&[value length]<=512)result[@"name"]=Clean(value);
        if(![m[@"space"]isEqual:@"uiso"]||![value isKindOfClass:NSData.class]||[value length]>2048)continue;
        BOOL name=[m[@"key"]isEqual:@1851878757]||[m[@"key"]isEqual:@"name"],kind=[m[@"key"]isEqual:@1802071652]||[m[@"key"]isEqual:@"kind"];
        NSData *data=value;if(name&&!result[@"name"]&&data.length<=512){NSString *s=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];if(s)result[@"name"]=Clean(s);}
        if(kind&&data.length>=6){const uint8_t *b=(const uint8_t *)data.bytes;if(b[0]||b[1]||b[2]||b[3])continue;
            NSString *s=[[NSString alloc]initWithData:[data subdataWithRange:NSMakeRange(4,data.length-4)] encoding:NSUTF8StringEncoding];if(!s)continue;
            NSArray *parts=[s componentsSeparatedByString:[NSString stringWithFormat:@"%C",(unichar)0]];
            if(parts.count!=3||![parts[0]isEqual:@"urn:mpeg:dash:role:2011"]||[parts[2]length])continue;
            if([parts[1]isEqual:@"commentary"])result[@"commentary"]=@YES;
            if([parts[1]isEqual:@"description"])result[@"description"]=@YES;
            if([@[@"alternate",@"supplementary"]containsObject:parts[1]])result[@"auxiliary"]=@YES;
        }
    }return result;
}
+ (NSArray *)tracks:(NSArray *)raw {
    if(![raw isKindOfClass:NSArray.class]||raw.count>128)return @[];
    NSMutableArray *out=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(id value in raw){if(![value isKindOfClass:NSDictionary.class])continue;NSDictionary *r=value;double n=Number(r[@"id"]);if(n<0||n>INT32_MAX||floor(n)!=n)continue;if([seen containsObject:@((NSInteger)n)])return @[];[seen addObject:@((NSInteger)n)];
        NSString *language=[self language:r[@"language"]],*name=Clean(r[@"name"]),*role=Role(r),*codec=Clean(r[@"codec"]);double c=Number(r[@"channels"]);NSInteger channels=c>=1&&c<=64&&floor(c)==c?(NSInteger)c:0;
        BOOL compatible=Flag(r[@"compatible"])&&channels>=1&&channels<=6&&(!r[@"enabled"]||Flag(r[@"enabled"]));
        NSString *suffix=[role isEqual:@"main"]?@"":[role isEqual:@"description"]?@" · Audio description":[role isEqual:@"commentary"]?@" · Commentary":@" · Alternate";
        NSString *layout=channels==1?@"Mono":channels==2?@"Stereo":channels==6?@"5.1":channels>0?[NSString stringWithFormat:@"%ld channels",(long)channels]:@"";
        NSString *hint=language.length?@"":NameLanguage(name),*evidence=language.length?@"tag":hint.length?@"track_name":@"unknown";
        NSString *display=hint.length?[NSString stringWithFormat:@"%@ (track name)",LanguageName(hint)]:LanguageName(language);
        NSString *label=[NSString stringWithFormat:@"%@%@%@%@",display,suffix,layout.length?@" · ":@"",layout];
        NSString *token=Hash(@[@((NSInteger)n),language,role,name,codec,@(channels)]);
        [out addObject:@{@"id":@((NSInteger)n),@"language":language,@"language_hint":hint,@"language_evidence":evidence,@"name":name,@"role":role,@"codec":codec,@"channels":@(channels),@"compatible":@(compatible),@"default":@(Flag(r[@"default"])),@"label":label,@"token":token}];
    }return out;
}
+ (NSDictionary *)selection:(NSArray *)tracks preference:(NSDictionary *)preference {
    if(![tracks isKindOfClass:NSArray.class]||tracks.count>128)return @{};
    if(![preference isKindOfClass:NSDictionary.class])preference=@{};
    NSString *wanted=[self language:preference[@"language"]];if(!wanted.length)wanted=@"en";
    NSString *role=Text(preference[@"role"]);if(![@[@"main",@"commentary",@"description",@"auxiliary"]containsObject:role])role=@"main";
    NSString *token=Text(preference[@"token"]);NSDictionary *best=nil;NSInteger score=NSIntegerMin;BOOL exact=NO;
    for(id value in tracks){if(![value isKindOfClass:NSDictionary.class])continue;NSDictionary *t=value;if(!Flag(t[@"compatible"]))continue;NSInteger s=[t[@"role"]isEqual:role]?10000:[t[@"role"]isEqual:@"main"]?5000:0;
        if([t[@"language"]isEqual:wanted])s+=1000;else if(![t[@"language"]length]&&[NameLanguage(Clean(t[@"name"]))isEqual:wanted])s+=800;if([t[@"language"]length])s+=10;if(Flag(t[@"default"]))s+=100;if([t[@"channels"]integerValue]<=2)s+=20;
        if(token.length&&[t[@"token"]isEqual:token]){best=t;exact=YES;break;}if(!best||s>score){best=t;score=s;}}
    if(!best)return @{@"message":@"No compatible audio track is available.",@"reason":@"unsupported"};
    BOOL matching=[best[@"language"]isEqual:wanted]&&[best[@"role"]isEqual:role];
    BOOL inferred=![best[@"language"]length]&&[NameLanguage(Clean(best[@"name"]))isEqual:wanted]&&[best[@"role"]isEqual:role];
    NSString *message=@"",*reason=exact?@"saved_track":matching?@"preferred_language":inferred?@"preferred_language_name":@"fallback";
    if(inferred)message=[NSString stringWithFormat:@"%@ is indicated by the track name; this source has no language tag.",LanguageName(wanted)];
    else if(!matching&&!exact)message=[NSString stringWithFormat:@"No compatible %@ %@ track identified. Using %@.",LanguageName(wanted),[role isEqual:@"main"]?@"main":role,best[@"label"]];
    else if(![best[@"language"]length])message=@"This source does not identify its audio language.";
    return @{@"track":best,@"message":message,@"reason":reason,@"preferred_language":wanted,@"preferred_role":role};
}
+ (NSString *)mediaKey:(NSDictionary *)source {
    if(![source isKindOfClass:NSDictionary.class])return @"";NSString *hash=Text(source[@"infoHash"]).lowercaseString;id index=source[@"resolvedFileIdx"]?:source[@"fileIdx"];
    if(Match(@"\\A[0-9a-f]{40}\\z",hash)&&Number(index)>=0&&Number(index)<=10000&&floor(Number(index))==Number(index))return Hash(@[@"torrent",hash,index]);
    NSString *url=Text(source[@"url"]);if(url.length&&url.length<=16384&&![[NSURL URLWithString:url].scheme.lowercaseString isEqual:@"magnet"])return Hash(@[@"url",url]);return @"";
}
+ (NSDictionary *)preferenceInProfile:(NSDictionary *)profile videoID:(NSString *)videoID mediaKey:(NSString *)key {
    if(![profile isKindOfClass:NSDictionary.class])profile=@{};
    NSString *language=[self language:profile[@"audioLanguage"]];NSMutableDictionary *p=[@{@"language":language.length?language:@"en",@"role":@"main"}mutableCopy];
    id map=profile[@"audioSelections"];id raw=[map isKindOfClass:NSDictionary.class]&&Text(videoID).length?Saved(map[videoID]):nil;
    if([raw isKindOfClass:NSDictionary.class]){NSDictionary *saved=raw;NSString *preferred=[self language:saved[@"language"]];if(preferred.length)p[@"language"]=preferred;
        if([@[@"main",@"commentary",@"description",@"auxiliary"]containsObject:saved[@"role"]?:@""])p[@"role"]=saved[@"role"];
        if(Digest(key)&&[saved[@"media_key"]isEqual:key])p[@"token"]=saved[@"token"];
    }return p;
}
+ (NSDictionary *)selectionsBySaving:(NSDictionary *)track mediaKey:(NSString *)key videoID:(NSString *)videoID existing:(NSDictionary *)existing now:(double)now {
    if(![track isKindOfClass:NSDictionary.class]||!Text(videoID).length||videoID.length>128||!Digest(key)||!Digest(track[@"token"])||!Flag(track[@"compatible"])||!isfinite(now)||now<=0)return nil;
    NSDictionary *entry=Saved(@{@"media_key":key,@"token":track[@"token"],@"language":Text(track[@"language"]),@"role":Text(track[@"role"]),@"updated":@(now)});if(!entry)return nil;
    NSMutableDictionary *map=[NSMutableDictionary new];
    // A corrupt oversized map is discarded, never scanned without a bound.
    if([existing isKindOfClass:NSDictionary.class]&&existing.count<=128)for(id k in existing){NSDictionary *r=Saved(existing[k]);if(Text(k).length&&[k length]<=128&&r)map[k]=r;}
    map[videoID]=entry;
    while(map.count>64){NSString *oldest=nil;for(NSString *k in map)if(![k isEqual:videoID]&&(!oldest||Number(map[k][@"updated"])<Number(map[oldest][@"updated"])||(Number(map[k][@"updated"])==Number(map[oldest][@"updated"])&&[k compare:oldest]==NSOrderedAscending)))oldest=k;if(!oldest)break;[map removeObjectForKey:oldest];}return [map copy];
}
@end
