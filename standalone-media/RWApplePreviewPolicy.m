#import "RWApplePreviewPolicy.h"
static NSDictionary *PD(id x){return [x isKindOfClass:NSDictionary.class]?x:@{};}
static NSArray *PA(id x){return [x isKindOfClass:NSArray.class]?x:@[];}
static NSString *PT(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static double PF(id x){return [x respondsToSelector:@selector(doubleValue)]?[x doubleValue]:0;}
static BOOL PM(NSString *s,NSString *pattern){return [s rangeOfString:pattern options:NSRegularExpressionSearch].location==0;}
static NSString *PN(NSString *s){return [[[[s stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]]lowercaseString]componentsSeparatedByCharactersInSet:NSCharacterSet.alphanumericCharacterSet.invertedSet]componentsJoinedByString:@""];}
static NSArray *PV(NSDictionary *entity,NSString *property){NSMutableArray *out=[NSMutableArray new];for(id raw in PA(PD(entity[@"claims"])[property])){NSDictionary *c=PD(raw);if([c[@"rank"]isEqual:@"deprecated"])continue;id v=PD(PD(c[@"mainsnak"])[@"datavalue"])[@"value"];if(v)[out addObject:v];}return out;}
static NSDictionary *Attrs(NSString *line){NSRange colon=[line rangeOfString:@":"];if(colon.location==NSNotFound)return @{};NSString *value=[line substringFromIndex:colon.location+1];NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:@"(?:^|,)([A-Z0-9-]+)=(\"[^\"]*\"|[^,]*)" options:0 error:nil];NSMutableDictionary *out=[NSMutableDictionary new];for(NSTextCheckingResult *m in [regex matchesInString:value options:0 range:NSMakeRange(0,value.length)]){NSString *s=[value substringWithRange:[m rangeAtIndex:2]];if([s hasPrefix:@"\""]&&s.length>=2)s=[s substringWithRange:NSMakeRange(1,s.length-2)];out[[value substringWithRange:[m rangeAtIndex:1]]]=s;}return out;}
@implementation RWApplePreviewPolicy
+ (NSArray *)showIDs:(NSDictionary *)entity imdb:(NSString *)imdb {
    if(!PM(PT(imdb),@"^tt[0-9]+$")||![PV(PD(entity),@"P345")containsObject:imdb])return @[];NSMutableOrderedSet *ids=[NSMutableOrderedSet new];for(id raw in PV(entity,@"P9751"))if(PM(PT(raw),@"^umc\\.cmc\\.[a-z0-9]{10,40}$")){[ids addObject:raw];if(ids.count==3)break;}return ids.array;
}
+ (NSArray *)movieIDs:(NSDictionary *)entity imdb:(NSString *)imdb {
    if(!PM(PT(imdb),@"^tt[0-9]+$")||![PV(PD(entity),@"P345")containsObject:imdb])return @[];
    NSMutableOrderedSet *ids=[NSMutableOrderedSet new];for(id raw in PV(entity,@"P9586"))if(PM(PT(raw),@"^umc\\.cmc\\.[a-z0-9]{10,40}$")){[ids addObject:raw];if(ids.count==3)break;}return ids.array;
}
+ (NSArray *)reviewedMovieIDs:(NSDictionary *)record meta:(NSDictionary *)meta {
    // A separately attributed publisher mapping, never a fabricated Wikidata claim.
    NSDictionary *r=PD(record);NSString *year=PT(meta[@"releaseInfo"]);NSURL *url=[self allowedURL:PT(r[@"url"]) base:nil];
    if(![meta[@"type"]isEqual:@"movie"]||!PM(PT(meta[@"id"]),@"^tt[0-9]+$")||![r[@"imdb"]isEqual:meta[@"id"]]||![r[@"type"]isEqual:@"movie"]||!PN(PT(meta[@"name"])).length||![PN(PT(r[@"name"]))isEqual:PN(meta[@"name"])]||year.length<4||![PT(r[@"year"])isEqual:[year substringToIndex:4]]||![url.host isEqual:@"tv.apple.com"]||![url.path hasPrefix:@"/us/movie/"]||!PM(url.lastPathComponent?:@"",@"^umc\\.cmc\\.[a-z0-9]{10,40}$"))return @[];
    return @[url.lastPathComponent];
}
+ (NSURL *)allowedURL:(NSString *)url base:(NSURL *)base {
    if(!PT(url).length||url.length>4096||[url rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n\""]].location!=NSNotFound)return nil;
    NSURL *u=[NSURL URLWithString:url relativeToURL:base].absoluteURL;NSString *host=u.host.lowercaseString;
    BOOL apple=[host isEqual:@"tv.apple.com"]||[host hasSuffix:@".tv.apple.com"]||[host hasSuffix:@".itunes.apple.com"]||[host hasSuffix:@".mzstatic.com"];
    return [u.scheme.lowercaseString isEqual:@"https"]&&apple&&!u.user&&!u.password&&(!u.port||u.port.integerValue==443)?u:nil;
}
+ (NSDictionary *)preview:(NSData *)html showID:(NSString *)identifier meta:(NSDictionary *)meta {
    BOOL movie=[meta[@"type"]isEqual:@"movie"];NSString *type=movie?@"Movie":@"Show",*path=movie?@"/us/movie/":@"/show/";
    NSString *year=PT(meta[@"releaseInfo"]);if(movie&&(year.length<4||!PM([year substringToIndex:4],@"^(18|19|20|21)[0-9]{2}$")))return nil;
    if(![html isKindOfClass:NSData.class]||html.length>2*1024*1024||(!movie&&![meta[@"type"]isEqual:@"series"])||!PM(PT(identifier),@"^umc\\.cmc\\.[a-z0-9]{10,40}$")||!PT(meta[@"name"]).length)return nil;
    NSString *text=[[NSString alloc]initWithData:html encoding:NSUTF8StringEncoding];if(!text)return nil;
    NSRegularExpression *re=[NSRegularExpression regularExpressionWithPattern:@"<script\\b[^>]*\\bid\\s*=\\s*[\"']?serialized-server-data[\"']?[^>]*>(.*?)</script\\s*>" options:NSRegularExpressionDotMatchesLineSeparators|NSRegularExpressionCaseInsensitive error:nil];
    NSTextCheckingResult *hit=[re firstMatchInString:text options:0 range:NSMakeRange(0,text.length)];if(!hit)return nil;
    NSData *json=[[text substringWithRange:[hit rangeAtIndex:1]]dataUsingEncoding:NSUTF8StringEncoding];NSDictionary *root=PD([NSJSONSerialization JSONObjectWithData:json options:0 error:nil]);NSDictionary *page=nil;
    for(id raw in PA(root[@"data"])){NSDictionary *d=PD(PD(raw)[@"data"]);NSURL *canonical=[self allowedURL:PT(d[@"canonicalURL"]) base:nil];if([canonical.host.lowercaseString isEqual:@"tv.apple.com"]&&[canonical.path containsString:path]&&[canonical.lastPathComponent isEqual:identifier]){page=d;break;}}
    if(!page)return nil;BOOL exact=NO;for(id raw in PA(page[@"shelves"])){NSDictionary *s=PD(raw);if(movie&&![s[@"id"]isEqual:[@"canonical-header-" stringByAppendingString:identifier]])continue;for(id item in PA(s[@"items"])){NSDictionary *m=PD(item);if([m[@"type"]isEqual:type]&&[PN(PT(m[@"title"]))isEqual:PN(meta[@"name"])]&&(!movie||[PA(m[@"badgeRowMetadata"])containsObject:[year substringToIndex:4]]))exact=YES;}}if(!exact)return nil;
    NSString *shelfID=[@"uts.col.Trailers." stringByAppendingString:identifier];NSDictionary *best=nil;NSInteger bestSeason=NSIntegerMax;
    for(id raw in PA(page[@"shelves"])){NSDictionary *shelf=PD(raw);if(![shelf[@"id"]isEqual:shelfID])continue;NSUInteger examined=0;
        for(id row in PA(shelf[@"playlistItems"])){if(++examined>24)break;NSDictionary *item=PD(row),*playable=PD(item[@"playable"]),*asset=PD(playable[@"assets"]),*lockup=PD(PD(item[@"playlist"])[@"lockup"]);double duration=PF(playable[@"duration"]);NSString *clip=PT(playable[@"canonicalId"]),*title=PT(playable[@"title"]);
            if(![item[@"type"]isEqual:@"Preview"]||![playable[@"type"]isEqual:@"Vod"]||!isfinite(duration)||duration<10||duration>300||PF(asset[@"requiresPlaybackId"])!=0||!PM(clip,@"^umc\\.cmc\\.[a-z0-9]{10,40}$")||![PN(PT(lockup[@"subtitle"]))isEqual:PN(meta[@"name"])])continue;
            NSURL *url=[self allowedURL:PT(asset[@"hlsUrl"]) base:nil];if(!url||![url.pathExtension.lowercaseString isEqual:@"m3u8"])continue;
            // The exact trailer shelf and clip's target must agree with the show.
            BOOL linked=NO;for(id rawLock in PA(shelf[@"items"])){NSDictionary *l=PD(rawLock),*context=PD(l[@"contextAction"]);NSURLComponents *parts=[NSURLComponents componentsWithString:PT(context[@"url"])];NSMutableDictionary *params=[NSMutableDictionary new];for(NSURLQueryItem *p in parts.queryItems)if(p.value)params[p.name]=p.value;
                if([l[@"id"]isEqual:clip]&&[context[@"type"]isEqual:@"Preview"]&&[params[@"targetId"]isEqual:identifier]&&[params[@"targetType"]isEqual:type]&&[self allowedURL:parts.URL.absoluteString base:nil])linked=YES;}
            if(!linked)continue;NSInteger season=999;NSRange marker=[title rangeOfString:@"Season " options:NSCaseInsensitiveSearch];if(marker.location!=NSNotFound){NSInteger n=[[title substringFromIndex:NSMaxRange(marker)]integerValue];if(n>0&&n<100)season=n;}
            if(!best||season<bestSeason){bestSeason=season;best=@{@"url":url.absoluteString,(movie?@"movieID":@"showID"):identifier,@"previewID":clip,@"name":title,@"duration":@(duration),@"storeURL":page[@"canonicalURL"]};}
        }
    }return best;
}
+ (NSDictionary *)variant:(NSString *)master base:(NSURL *)base {
    if(![master hasPrefix:@"#EXTM3U"]||master.length>1024*1024||[master containsString:@"#EXT-X-SESSION-KEY"]||![self allowedURL:base.absoluteString base:nil])return nil;
    NSArray *lines=[master componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];NSMutableDictionary *audio=[NSMutableDictionary new];
    for(NSString *line in lines)if([line hasPrefix:@"#EXT-X-MEDIA:"]){NSDictionary *a=Attrs(line);NSString *language=PT(a[@"LANGUAGE"]);if(![a[@"TYPE"]isEqual:@"AUDIO"]||!([language isEqual:@"en"]||[language hasPrefix:@"en-"])||![a[@"CHANNELS"]isEqual:@"2"]||[PT(a[@"CHARACTERISTICS"])containsString:@"describes-video"])continue;NSURL *u=[self allowedURL:PT(a[@"URI"]) base:base];NSString *group=PT(a[@"GROUP-ID"]);if(u&&group.length&&!audio[group])audio[group]=u.absoluteString;}
    NSDictionary *best=nil;NSUInteger examined=0;
    for(NSUInteger i=0;i+1<lines.count;i++){NSString *line=lines[i];if(![line hasPrefix:@"#EXT-X-STREAM-INF:"])continue;if(++examined>600)break;NSDictionary *a=Attrs(line);NSArray *codecs=[PT(a[@"CODECS"])componentsSeparatedByString:@","];NSString *video=nil;for(NSString *c in codecs)if([c hasPrefix:@"avc1."])video=c;
        if(!video||![codecs containsObject:@"mp4a.40.2"]||codecs.count!=2||!PM(video,@"^avc1\\.(42|4d|64)[0-9a-fA-F]{4}$"))continue;unsigned int level=0;[[NSScanner scannerWithString:[video substringFromIndex:9]]scanHexInt:&level];if(level>41)continue;
        NSArray *size=[PT(a[@"RESOLUTION"])componentsSeparatedByString:@"x"];if(size.count!=2)continue;NSInteger w=[size[0]integerValue],h=[size[1]integerValue];double fps=[a[@"FRAME-RATE"]doubleValue],bandwidth=[a[@"BANDWIDTH"]doubleValue];NSString *range=PT(a[@"VIDEO-RANGE"]);if(!isfinite(fps)||!isfinite(bandwidth)||w<=0||h<=0||w>1280||h>720||fps<=0||fps>30.1||bandwidth<=0||bandwidth>4000000||(range.length&&![range isEqual:@"SDR"]))continue;
        NSString *sound=audio[a[@"AUDIO"]];NSURL *u=[self allowedURL:lines[i+1] base:base];if(!sound||!u)continue;
        if(!best||w>[best[@"width"]integerValue]||(w==[best[@"width"]integerValue]&&bandwidth<[best[@"bandwidth"]doubleValue]))best=@{@"videoURL":u.absoluteString,@"audioURL":sound,@"width":@(w),@"height":@(h),@"fps":@(fps),@"bandwidth":@(bandwidth),@"codecs":a[@"CODECS"]};
    }return best;
}
+ (NSDictionary *)media:(NSString *)playlist base:(NSURL *)base {
    if(![playlist hasPrefix:@"#EXTM3U"]||playlist.length>128*1024||![playlist containsString:@"#EXT-X-ENDLIST"]||[playlist containsString:@"#EXT-X-BYTERANGE"]||![self allowedURL:base.absoluteString base:nil])return nil;
    NSMutableArray *out=[NSMutableArray new];double duration=0;NSUInteger segments=0;BOOL pending=NO,map=NO;
    for(NSString *raw in [playlist componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]){NSString *line=[raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];if(!line.length)continue;
        if([line hasPrefix:@"#EXT-X-KEY:"]){if(![Attrs(line)[@"METHOD"]isEqual:@"NONE"])return nil;continue;}
        if([line hasPrefix:@"#EXT-X-MAP:"]){NSDictionary *a=Attrs(line);NSURL *url=[self allowedURL:a[@"URI"] base:base];if(!url||a[@"BYTERANGE"])return nil;[out addObject:[NSString stringWithFormat:@"#EXT-X-MAP:URI=\"%@\"",url.absoluteString]];map=YES;continue;}
        if([line hasPrefix:@"#EXTINF:"]){double d=[[line substringFromIndex:8]doubleValue];if(pending||!isfinite(d)||d<=0||d>30)return nil;duration+=d;if(duration>330)return nil;pending=YES;[out addObject:[NSString stringWithFormat:@"#EXTINF:%.6f,",d]];continue;}
        if(![line hasPrefix:@"#"]){NSURL *url=[self allowedURL:line base:base];if(!pending||!url||++segments>180)return nil;pending=NO;[out addObject:url.absoluteString];continue;}
        if([line isEqual:@"#EXTM3U"]||[line hasPrefix:@"#EXT-X-VERSION:"]||[line hasPrefix:@"#EXT-X-TARGETDURATION:"]||[line hasPrefix:@"#EXT-X-MEDIA-SEQUENCE:"]||[line isEqual:@"#EXT-X-INDEPENDENT-SEGMENTS"]||[line isEqual:@"#EXT-X-PLAYLIST-TYPE:VOD"]||[line isEqual:@"#EXT-X-DISCONTINUITY"]||[line isEqual:@"#EXT-X-ENDLIST"])[out addObject:line];
    }if(pending||!map||!segments||duration<10)return nil;return @{@"text":[[out componentsJoinedByString:@"\n"]stringByAppendingString:@"\n"],@"duration":@(duration),@"segments":@(segments)};
}
+ (NSString *)localMaster:(NSDictionary *)v {
    return [NSString stringWithFormat:@"#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-INDEPENDENT-SEGMENTS\n#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"stereo\",NAME=\"English\",DEFAULT=YES,AUTOSELECT=YES,LANGUAGE=\"en\",CHANNELS=\"2\",URI=\"audio.m3u8\"\n#EXT-X-STREAM-INF:BANDWIDTH=%ld,CODECS=\"%@\",RESOLUTION=%ldx%ld,FRAME-RATE=%.3f,AUDIO=\"stereo\"\nvideo.m3u8\n",(long)[v[@"bandwidth"]integerValue],v[@"codecs"],(long)[v[@"width"]integerValue],(long)[v[@"height"]integerValue],[v[@"fps"]doubleValue]];
}
@end
