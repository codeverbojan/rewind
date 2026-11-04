#pragma once
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

static inline NSString *RWIdentityText(id v){return [v isKindOfClass:NSString.class]?v:@"";}
// A torrent may contain several independently advertised files. A bad locator
// must not consume another locator's chance, or merge contradictory filenames.
static inline NSString *RWSourceCandidateKey(NSDictionary *source){
    NSString *hash=RWIdentityText(source[@"infoHash"]).lowercaseString;
    NSString *name=[RWIdentityText(source[@"filename"]) stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    NSInteger index=[source[@"fileIdx"]isKindOfClass:NSNumber.class]?[source[@"fileIdx"]integerValue]:-1;
    return [NSString stringWithFormat:@"%@:%ld:%@",hash.length?hash:RWIdentityText(source[@"url"]),(long)index,name.lowercaseString];
}

// A filename provides evidence of episode identity, not proof of the actual
// story or spoken language. Missing/ambiguous evidence never becomes a match.
static inline NSArray *RWEpisodeInTorrentPath(NSString *path){
    if(!path.length||path.length>2048)return nil;
    static NSRegularExpression *number,*extra,*folder,*leaf;static dispatch_once_t once;
    dispatch_once(&once,^{
        number=[NSRegularExpression regularExpressionWithPattern:@"(?:^|[^a-z0-9])(?:s([0-9]{1,3})[ ._-]*e([0-9]{1,4})|([0-9]{1,3})x([0-9]{1,4}))(?![0-9])" options:NSRegularExpressionCaseInsensitive error:nil];
        extra=[NSRegularExpression regularExpressionWithPattern:@"^(?:[ ._-]*e[ ._-]*[0-9]{1,4}(?![0-9])|-[0-9]{1,4}(?=$|[ ._/-]))" options:NSRegularExpressionCaseInsensitive error:nil];
        folder=[NSRegularExpression regularExpressionWithPattern:@"(?:^|/)(?:season[ ._-]*|s)([0-9]{1,3})(?=/|$)" options:NSRegularExpressionCaseInsensitive error:nil];
        leaf=[NSRegularExpression regularExpressionWithPattern:@"^(?:episode[ ._-]*|e)?([0-9]{1,4})(?=[ ._-]|$)" options:NSRegularExpressionCaseInsensitive error:nil];
    });
    NSArray *matches=[number matchesInString:path options:0 range:NSMakeRange(0,path.length)];
    NSArray *identity=nil;
    for(NSTextCheckingResult *m in matches){
        NSString *suffix=[path substringFromIndex:NSMaxRange(m.range)];
        if([extra firstMatchInString:suffix options:0 range:NSMakeRange(0,suffix.length)])return nil;
        NSUInteger s=[m rangeAtIndex:1].location==NSNotFound?3:1;
        NSInteger season=[[path substringWithRange:[m rangeAtIndex:s]]integerValue],episode=[[path substringWithRange:[m rangeAtIndex:s+1]]integerValue];
        if(season<0||season>100||episode<1||episode>2000)return nil;
        NSArray *found=@[@(season),@(episode)];if(identity&&![identity isEqual:found])return nil;identity=found;
    }
    NSArray *seasons=[folder matchesInString:path options:0 range:NSMakeRange(0,path.length)];NSNumber *folderSeason=nil;
    for(NSTextCheckingResult *m in seasons){
        NSInteger s=[[path substringWithRange:[m rangeAtIndex:1]]integerValue];
        if(s>100||(folderSeason&&folderSeason.integerValue!=s))return nil;
        folderSeason=@(s);
    }
    if(identity)return !folderSeason||[folderSeason isEqual:identity[0]]?identity:nil;
    NSString *name=path.lastPathComponent;
    NSTextCheckingResult *episode=[leaf firstMatchInString:name options:0 range:NSMakeRange(0,name.length)];
    if(!folderSeason||!episode)return nil;
    NSInteger e=[[name substringWithRange:[episode rangeAtIndex:1]]integerValue];
    return e>=1&&e<=2000?@[folderSeason,@(e)]:nil;
}

// Descriptors are made from hash-verified torrent metadata after its path,
// symlink and file-count guards. Selection never defaults to the largest file.
static inline NSInteger RWSelectTorrentVideo(NSArray *files,NSDictionary *source,NSInteger desired,NSString **error){
    NSString *identifier=RWIdentityText(source[@"requestedVideoID"]),*expected=RWIdentityText(source[@"filename"]);
    if(expected.length>2048){if(error)*error=@"The source filename is too long.";return -1;}
    expected=[expected stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    NSArray *parts=[identifier componentsSeparatedByString:@":"];NSArray *episode=nil;
    if([identifier hasPrefix:@"tt"]&&(identifier.length>64||[parts[0]rangeOfString:@"^tt[0-9]+$" options:NSRegularExpressionSearch].location!=0)){
        if(error)*error=@"The requested title identifier is invalid.";return -1;
    }
    if([identifier hasPrefix:@"tt"]&&parts.count>1){
        if(parts.count!=3||![identifier isEqual:[NSString stringWithFormat:@"%@:%ld:%ld",parts[0],(long)[parts[1]integerValue],(long)[parts[2]integerValue]]]||[parts[1]integerValue]<0||[parts[1]integerValue]>100||[parts[2]integerValue]<1||[parts[2]integerValue]>2000){if(error)*error=@"The requested episode identifier is invalid.";return -1;}
        episode=@[@([parts[1]integerValue]),@([parts[2]integerValue])];
    }
    NSMutableArray *matches=[NSMutableArray new];
    for(NSDictionary *file in files){
        NSInteger index=[file[@"index"]integerValue];if(desired>=0&&index!=desired)continue;
        NSString *path=RWIdentityText(file[@"path"]),*name=path.lastPathComponent;
        if(![@[@"mp4",@"m4v",@"mov",@"mkv"]containsObject:name.pathExtension.lowercaseString]||[file[@"size"]longLongValue]<=0)continue;
        if(expected.length){
            BOOL exact=[expected caseInsensitiveCompare:name]==NSOrderedSame||[expected caseInsensitiveCompare:path]==NSOrderedSame;
            // A provider can omit the torrent's root directory, but must match
            // all supplied subdirectories, not just a duplicate leaf name.
            if([expected rangeOfString:@"/"].location!=NSNotFound)exact=[path caseInsensitiveCompare:expected]==NSOrderedSame||[path.lowercaseString hasSuffix:[@"/" stringByAppendingString:expected.lowercaseString]];
            if(!exact)continue;
        }
        if(episode&&![RWEpisodeInTorrentPath(path)isEqual:episode])continue;
        [matches addObject:file];
    }
    if(matches.count!=1){if(error)*error=matches.count?@"This source does not identify one matching video.":episode?@"The torrent file cannot be matched to the requested episode.":@"The requested video file is not present in this torrent.";return -1;}
    return [matches[0][@"index"]integerValue];
}
