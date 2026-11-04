#import "RWSubtitlePolicy.h"
#import "RWAudioPolicy.h"
#include "RWSourceIdentity.h"
#import <CommonCrypto/CommonDigest.h>
#include <math.h>
static NSString *Text(id v){return [v isKindOfClass:NSString.class]?v:@"";}
static double Num(id v){return [v isKindOfClass:NSNumber.class]&&isfinite([v doubleValue])?[v doubleValue]:NAN;}
static BOOL Digest(id v){NSString *s=Text(v);return s.length==64&&[s rangeOfString:@"[^0-9a-f]" options:NSRegularExpressionSearch].location==NSNotFound;}
static BOOL Match(NSString *p,NSString *s){return [s rangeOfString:p options:NSRegularExpressionSearch|NSCaseInsensitiveSearch].location!=NSNotFound;}
static NSString *Clean(id v){NSString *s=Text(v);if(s.length>180)s=[s substringToIndex:180];return [[s componentsSeparatedByCharactersInSet:NSCharacterSet.controlCharacterSet]componentsJoinedByString:@" "];}
static id Canonical(id value,NSUInteger depth,NSUInteger *nodes,NSUInteger *bytes){
    if(depth>8||!*nodes)return nil;(*nodes)--;NSUInteger length=([value isKindOfClass:NSString.class]||[value isKindOfClass:NSData.class])?[value length]:0;if(length>*bytes)return nil;*bytes-=length;if([value isKindOfClass:NSString.class])return [value length]<=16384?@[@"s",value]:nil;
    if([value isKindOfClass:NSNumber.class])return isfinite([value doubleValue])?@[@"n",[value stringValue]]:nil;
    if([value isKindOfClass:NSData.class])return [value length]<=16384?@[@"b",[value base64EncodedStringWithOptions:0]]:nil;
    if([value isKindOfClass:NSArray.class]){if([value count]>128)return nil;NSMutableArray *out=[NSMutableArray arrayWithObject:@"a"];for(id v in value){id c=Canonical(v,depth+1,nodes,bytes);if(!c)return nil;[out addObject:c];}return out;}
    if([value isKindOfClass:NSDictionary.class]){if([value count]>128)return nil;for(id k in value){if(![k isKindOfClass:NSString.class]||[k length]>16384||[k length]>*bytes)return nil;*bytes-=[k length];}NSMutableArray *out=[NSMutableArray arrayWithObject:@"d"];for(NSString *k in [[value allKeys]sortedArrayUsingSelector:@selector(compare:)]){id c=Canonical(value[k],depth+1,nodes,bytes);if(!c)return nil;[out addObject:@[k,c]];}return out;}
    return nil;
}
static BOOL Bool(id v){return [v isKindOfClass:NSNumber.class]&&([v integerValue]==0||[v integerValue]==1)&&[v doubleValue]==[v integerValue];}
static BOOL Flag(id value){return Bool(value)&&[value boolValue];}
static BOOL SubtitleSuffix(NSString *suffix){
    if(suffix.length>100)return NO;NSArray *words=[suffix.lowercaseString componentsSeparatedByCharactersInSet:NSCharacterSet.alphanumericCharacterSet.invertedSet];
    NSSet *allowed=[NSSet setWithArray:@[@"en",@"eng",@"english",@"fr",@"fra",@"fre",@"french",@"de",@"deu",@"ger",@"es",@"spa",@"it",@"ita",@"pt",@"por",@"mk",@"mkd",@"ru",@"rus",@"cs",@"ces",@"cze",@"pl",@"pol",@"ar",@"ara",@"ja",@"jpn",@"ko",@"kor",@"zh",@"zho",@"chi",@"und",@"sdh",@"cc",@"hi",@"forced",@"default",@"sub",@"subs",@"subtitle",@"subtitles"]];
    NSUInteger count=0;for(NSString *word in words)if(word.length){if(![allowed containsObject:word]||++count>6)return NO;}return count>0;
}
static NSDictionary *Choice(id value){
    if(![value isKindOfClass:NSDictionary.class])return nil;NSDictionary *r=value;
    if(!Digest(r[@"media_key"])||!Bool(r[@"enabled"])||!isfinite(Num(r[@"updated"]))||Num(r[@"updated"])<=0)return nil;
    BOOL enabled=[r[@"enabled"]boolValue];if(enabled&&(!Digest(r[@"token"])||!Bool(r[@"forced"])||!Bool(r[@"sdh"])))return nil;
    return @{@"media_key":r[@"media_key"],@"enabled":@(enabled),@"token":enabled?r[@"token"]:@"",@"language":[RWAudioPolicy language:r[@"language"]],@"forced":@(enabled&&Flag(r[@"forced"])),@"sdh":@(enabled&&Flag(r[@"sdh"])),@"updated":r[@"updated"]};
}
static NSDictionary *Adjustment(id value){
    if(![value isKindOfClass:NSDictionary.class])return nil;NSDictionary *r=value;double delay=Num(r[@"delay"]),at=Num(r[@"updated"]);
    if(!isfinite(delay)||fabs(delay)>10||!isfinite(at)||at<=0||![@[@"auto",@"utf-8",@"windows-1252",@"windows-1250",@"windows-1251"]containsObject:r[@"encoding"]?:@""])return nil;
    return @{@"delay":@(delay),@"encoding":r[@"encoding"],@"updated":@(at)};
}
static void Trim(NSMutableDictionary *map,NSString *keep,NSUInteger cap){while(map.count>cap){NSString *oldest=nil;for(NSString *k in map)if(![k isEqual:keep]&&(!oldest||[map[k][@"updated"]doubleValue]<[map[oldest][@"updated"]doubleValue]||([map[k][@"updated"]doubleValue]==[map[oldest][@"updated"]doubleValue]&&[k compare:oldest]==NSOrderedAscending)))oldest=k;if(!oldest)break;[map removeObjectForKey:oldest];}}
static NSString *SubtitleCodec(id value){NSString *s=Text(value);NSDictionary *families=@{@"S_TEXT/UTF8":@"text",@"subt":@"text",@"S_TEXT/ASS":@"ass",@"S_TEXT/SSA":@"ass",@"ssa ":@"ass",@"ass ":@"ass",@"S_HDMV/PGS":@"pgs",@"bdpg":@"pgs",@"S_VOBSUB":@"dvd",@"spu ":@"dvd",@"S_TEXT/WEBVTT":@"vtt",@"wvtt":@"vtt"};return families[s]?:@"";}
static BOOL SubtitleMatches(NSDictionary *h,NSDictionary *r){NSString *codec=SubtitleCodec(h[@"codec"]);if(!codec.length||![codec isEqual:SubtitleCodec(r[@"codec"])]||![Clean(h[@"name"])isEqual:Clean(r[@"name"])])return NO;
    NSString *lang=[RWAudioPolicy language:r[@"language"]];return ![h[@"languageDeclared"]boolValue]||[h[@"language"]isEqual:lang]||[h[@"legacyLanguage"]isEqual:lang];}
@implementation RWSubtitlePolicy
+ (NSString *)digest:(NSData *)data {if(![data isKindOfClass:NSData.class]||!data.length||data.length>2*1024*1024)return @"";unsigned char h[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,h);NSMutableString *s=[NSMutableString new];for(NSUInteger i=0;i<sizeof(h);i++)[s appendFormat:@"%02x",h[i]];return s;}
+ (NSString *)fingerprint:(id)value {NSUInteger nodes=1024,bytes=65536;id c=Canonical(value,0,&nodes,&bytes);return c?[self digest:[NSJSONSerialization dataWithJSONObject:c options:0 error:nil]]:@"";}
+ (NSString *)mediaKey:(NSDictionary *)source bundleBuild:(NSString *)build {
    if(![source isKindOfClass:NSDictionary.class])return @"";NSString *hash=Text(source[@"infoHash"]);id index=source[@"resolvedFileIdx"]?:source[@"fileIdx"];
    if(Match(@"\\A[0-9a-f]{40}\\z",hash)&&isfinite(Num(index))&&Num(index)>=0&&Num(index)<=10000&&floor(Num(index))==Num(index))return [self fingerprint:@[@"torrent",hash.lowercaseString,index]];
    NSString *url=Text(source[@"url"]);if([url hasPrefix:@"asset:"]&&url.length<512&&Text(build).length)return [self fingerprint:@[@"bundle",build,url]];
    // A mutable HTTP URL alone cannot establish exact release identity. Do not
    // reuse persistent timing/encoding for it without a verified content ID.
    return @"";
}
+ (NSDictionary *)descriptor:(NSDictionary *)raw kind:(NSString *)kind locator:(id)locator {
    if(![raw isKindOfClass:NSDictionary.class]||![@[@"native",@"mkv",@"torrent",@"external"]containsObject:kind])return nil;
    NSString *name=Clean(raw[@"name"]),*language=[RWAudioPolicy language:raw[@"language"]?:raw[@"lang"]];
    if(!language.length){NSArray *words=[Text(raw[@"filename"]).stringByDeletingPathExtension.lowercaseString componentsSeparatedByCharactersInSet:NSCharacterSet.letterCharacterSet.invertedSet];
        for(NSString *word in words.reverseObjectEnumerator){if([@[@"en",@"eng",@"english",@"fr",@"fra",@"fre",@"french",@"de",@"deu",@"ger",@"es",@"spa",@"it",@"ita",@"pt",@"por",@"mk",@"mkd",@"ru",@"rus",@"cs",@"ces",@"cze",@"pl",@"pol"]containsObject:word]){language=[RWAudioPolicy language:word];break;}}}
    NSString *hint=[NSString stringWithFormat:@"%@ %@",name,Text(raw[@"filename"])];BOOL forced=Bool(raw[@"forced"])?[raw[@"forced"]boolValue]:Match(@"(?:^|[^a-z])forced(?:$|[^a-z])",hint),sdh=Bool(raw[@"sdh"])?[raw[@"sdh"]boolValue]:Match(@"(?:^|[^a-z])(?:sdh|cc|hearing.impaired)(?:$|[^a-z])",hint);
    NSString *token=[self fingerprint:@[kind,locator?:@"",language,@(forced),@(sdh)]];if(!token.length)return nil;
    return @{@"kind":kind,@"token":token,@"language":language?:@"",@"forced":@(forced),@"sdh":@(sdh),@"name":name,@"stable":@(locator!=nil&&(!raw[@"stable"]||Flag(raw[@"stable"])))};
}
+ (NSDictionary *)preference:(NSDictionary *)profile videoID:(NSString *)videoID mediaKey:(NSString *)media {
    if(![profile isKindOfClass:NSDictionary.class])profile=@{};NSString *lang=[RWAudioPolicy language:profile[@"subtitleLanguage"]];NSMutableDictionary *out=[@{@"enabled":@(Flag(profile[@"subtitlesEnabled"])),@"language":lang.length?lang:@"en",@"forced":@(Flag(profile[@"subtitleForced"])),@"sdh":@(Flag(profile[@"subtitleSDH"]))}mutableCopy];
    id map=profile[@"subtitleSelections"];NSDictionary *saved=[map isKindOfClass:NSDictionary.class]?Choice(map[videoID?:@""]):nil;
    if(saved){if([saved[@"enabled"]boolValue]){out[@"enabled"]=@YES;if([saved[@"language"]length])out[@"language"]=saved[@"language"];out[@"forced"]=saved[@"forced"];out[@"sdh"]=saved[@"sdh"];}
        if(Digest(media)&&[saved[@"media_key"]isEqual:media]){out[@"enabled"]=saved[@"enabled"];if([saved[@"enabled"]boolValue])out[@"token"]=saved[@"token"];}}
    return out;
}
+ (NSDictionary *)select:(NSArray *)choices preference:(NSDictionary *)preference {
    if(![preference[@"enabled"]boolValue]||choices.count>128)return nil;NSDictionary *best=nil;NSInteger score=NSIntegerMin;
    for(NSDictionary *entry in choices){NSDictionary *t=entry[@"descriptor"]?:entry;if([entry[@"match"]isEqual:@"conflict"])continue;if([t[@"token"]isEqual:preference[@"token"]]&&[t[@"stable"]boolValue])return entry;
        if(![t[@"language"]length]||![t[@"language"]isEqual:preference[@"language"]]||[entry[@"match"]isEqual:@"unknown"]||[entry[@"match"]isEqual:@"conflict"])continue;
        if([t[@"forced"]boolValue]!=[preference[@"forced"]boolValue])continue;NSInteger n=[t[@"sdh"]boolValue]==[preference[@"sdh"]boolValue]?100:0;
        if([@[@"native",@"mkv"]containsObject:t[@"kind"]])n+=20;else if([t[@"kind"]isEqual:@"torrent"])n+=10;
        NSInteger confidence=[@[@"native",@"mkv"]containsObject:t[@"kind"]]?4:[entry[@"match"]isEqual:@"release_filename"]?3:[entry[@"match"]isEqual:@"episode"]?1:2;n+=confidence*1000;
        if(!best||n>score||(n==score&&[t[@"token"]compare:(best[@"descriptor"]?:best)[@"token"]]==NSOrderedAscending)){best=entry;score=n;}}
    return best;
}
+ (NSDictionary *)saveChoice:(NSDictionary *)choice enabled:(BOOL)enabled videoID:(NSString *)videoID mediaKey:(NSString *)media existing:(NSDictionary *)existing now:(double)now {
    if(!Text(videoID).length||videoID.length>128||!Digest(media)||!isfinite(now)||now<=0||(enabled&&(![choice[@"stable"]boolValue]||!Digest(choice[@"token"]))))return nil;
    NSDictionary *entry=Choice(@{@"media_key":media,@"enabled":@(enabled),@"token":choice[@"token"]?:@"",@"language":choice[@"language"]?:@"",@"forced":choice[@"forced"]?:@NO,@"sdh":choice[@"sdh"]?:@NO,@"updated":@(now)});if(!entry)return nil;NSMutableDictionary *map=[NSMutableDictionary new];
    if([existing isKindOfClass:NSDictionary.class]&&existing.count<=128)for(id k in existing){NSDictionary *c=Choice(existing[k]);if(Text(k).length&&[k length]<=128&&c)map[k]=c;}
    map[videoID]=entry;Trim(map,videoID,64);return map;
}
+ (NSString *)adjustmentKey:(NSDictionary *)choice videoID:(NSString *)videoID mediaKey:(NSString *)media contentDigest:(NSString *)content {
    if(!Text(videoID).length||videoID.length>128||!Digest(media)||!Digest(choice[@"token"])||![choice[@"stable"]boolValue])return @"";
    BOOL bytes=[@[@"external",@"torrent"]containsObject:choice[@"kind"]];if(bytes&&!Digest(content))return @"";
    return [self fingerprint:@[videoID,media,choice[@"token"],bytes?content:@"embedded"]];
}
+ (NSDictionary *)adjustment:(NSDictionary *)profile key:(NSString *)key {id map=profile[@"subtitleAdjustments"];return Digest(key)&&[map isKindOfClass:NSDictionary.class]?Adjustment(map[key])?:@{}:@{};}
+ (NSDictionary *)saveAdjustment:(NSDictionary *)adjustment key:(NSString *)key existing:(NSDictionary *)existing now:(double)now {
    if(!Digest(key)||![adjustment isKindOfClass:NSDictionary.class])return nil;NSMutableDictionary *r=[adjustment mutableCopy];r[@"updated"]=@(now);NSDictionary *entry=Adjustment(r);if(!entry)return nil;NSMutableDictionary *map=[NSMutableDictionary new];
    if([existing isKindOfClass:NSDictionary.class]&&existing.count<=256)for(id k in existing){NSDictionary *a=Adjustment(existing[k]);if(Digest(k)&&a)map[k]=a;}map[key]=entry;Trim(map,key,128);return map;
}
+ (NSString *)sidecarMatch:(NSDictionary *)file videoID:(NSString *)videoID source:(NSDictionary *)source {
    NSString *path=Text(file[@"path"]).length?Text(file[@"path"]):Text(file[@"filename"]),*video=Text(source[@"resolvedFilename"]).length?Text(source[@"resolvedFilename"]):Text(source[@"filename"]);
    NSArray *parts=[videoID componentsSeparatedByString:@":"];BOOL episode=[videoID hasPrefix:@"tt"]&&parts.count==3;
    NSArray *found=RWEpisodeInTorrentPath(path);if(episode&&!found&&Match(@"(?:s[0-9]+[ ._-]*e[0-9]+|[0-9]+x[0-9]+)",path))return @"conflict";if(episode){NSArray *wanted=@[@([parts[1]integerValue]),@([parts[2]integerValue])];if(found&&![found isEqual:wanted])return @"conflict";}
    NSString *base=video.lastPathComponent.stringByDeletingPathExtension.lowercaseString,*sub=path.lastPathComponent.stringByDeletingPathExtension.lowercaseString;
    if(base.length&&([sub isEqual:base]||([sub hasPrefix:base]&&sub.length>base.length&&[[NSCharacterSet characterSetWithCharactersInString:@" ._-[("]characterIsMember:[sub characterAtIndex:base.length]]&&SubtitleSuffix([sub substringFromIndex:base.length]))))return @"release_filename";
    if(episode&&found)return @"episode";
    // Same torrent does not imply same cut/movie: generic eng.srt in a pack is
    // offered manually, never silently promoted by language alone.
    return @"unknown";
}
+ (NSDictionary *)manualFileForURL:(NSString *)value {
    NSString *url=[Text(value)stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(!url.length||url.length>2048||[url rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)return nil;
    NSURL *u=[NSURL URLWithString:url];if(![@[@"https",@"http"]containsObject:u.scheme.lowercaseString]||!u.host.length||u.user.length||u.password.length)return nil;
    return @{@"url":url,@"name":@"Added subtitles",@"filename":Clean(u.path.lastPathComponent),@"added":@YES};
}
+ (NSString *)manualKey:(NSString *)videoID mediaKey:(NSString *)media {return Text(videoID).length&&videoID.length<=128&&Digest(media)?[self fingerprint:@[@"manual",videoID,media]]:@"";}
+ (NSDictionary *)manualFileInProfile:(NSDictionary *)profile videoID:(NSString *)videoID mediaKey:(NSString *)media {
    if(![profile isKindOfClass:NSDictionary.class])return nil;NSString *key=[self manualKey:videoID mediaKey:media];if(!key.length)return nil;
    id map=profile[@"subtitleLinks"];if(![map isKindOfClass:NSDictionary.class]||[map count]>64)return nil;id record=map[key];
    return [record isKindOfClass:NSDictionary.class]&&isfinite(Num(record[@"updated"]))&&Num(record[@"updated"])>0?[self manualFileForURL:record[@"url"]]:nil;
}
+ (NSDictionary *)saveManualFile:(NSDictionary *)file videoID:(NSString *)videoID mediaKey:(NSString *)media existing:(NSDictionary *)existing now:(double)now {
    NSDictionary *valid=[self manualFileForURL:[file isKindOfClass:NSDictionary.class]?file[@"url"]:nil];NSString *key=[self manualKey:videoID mediaKey:media];if(!valid||!key.length||!isfinite(now)||now<=0)return nil;
    NSMutableDictionary *map=[NSMutableDictionary new];if([existing isKindOfClass:NSDictionary.class]&&existing.count<=64)for(id k in existing){id record=existing[k];if(!Digest(k)||![record isKindOfClass:NSDictionary.class]||!isfinite(Num(record[@"updated"]))||Num(record[@"updated"])<=0)continue;NSDictionary *f=[self manualFileForURL:record[@"url"]];if(f)map[k]=@{@"url":f[@"url"],@"updated":record[@"updated"]};}
    map[key]=@{@"url":valid[@"url"],@"updated":@(now)};Trim(map,key,32);return map;
}
+ (NSArray *)mapMKV:(NSArray *)header runtime:(NSArray *)runtime {
    if(![header isKindOfClass:NSArray.class]||!header.count||header.count>128||![runtime isKindOfClass:NSArray.class]||runtime.count>128)return @[];
    NSMutableSet *ids=[NSMutableSet new],*numbers=[NSMutableSet new];BOOL ordered=header.count==runtime.count;
    for(id h in header){if(![h isKindOfClass:NSDictionary.class])return @[];double n=Num(h[@"containerNumber"]);if(!isfinite(n)||n<1||n>INT32_MAX||floor(n)!=n||[numbers containsObject:@(n)])ordered=NO;[numbers addObject:@(n)];}
    for(id r in runtime){if(![r isKindOfClass:NSDictionary.class])return @[];double n=Num(r[@"id"]);if(!isfinite(n)||n<0||n>INT32_MAX||floor(n)!=n||[ids containsObject:@(n)])return @[];[ids addObject:@(n)];}
    NSArray *hs=ordered?[header sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"containerNumber"]compare:b[@"containerNumber"]];}]:header,*rs=[runtime sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"id"]compare:b[@"id"]];}];
    if(ordered)for(NSUInteger i=0;i<hs.count;i++)if(!SubtitleMatches(hs[i],rs[i])){ordered=NO;break;}
    NSMutableArray *out=[NSMutableArray new];
    for(NSUInteger i=0;i<header.count;i++){NSDictionary *h=ordered?hs[i]:header[i],*r=ordered?rs[i]:nil;if(!ordered){NSUInteger count=0;for(NSDictionary *candidate in runtime)if(SubtitleMatches(h,candidate)){r=candidate;count++;}if(count!=1)continue;count=0;for(NSDictionary *other in header)if(SubtitleMatches(other,r))count++;if(count!=1)continue;}
        double number=Num(h[@"containerNumber"]);if(!isfinite(number)||number<1||number>INT32_MAX||floor(number)!=number||![h[@"enabled"]boolValue])continue;NSDictionary *d=[self descriptor:h kind:@"mkv" locator:@[h[@"containerNumber"],h[@"uid"]?:@"",h[@"codec"]?:@"",h[@"name"]?:@""]];if(!d)continue;
        [out addObject:@{@"id":r[@"id"],@"descriptor":d,@"mapping":ordered?@"complete_order_and_metadata":@"unique_metadata"}];}
    return out;
}
@end
