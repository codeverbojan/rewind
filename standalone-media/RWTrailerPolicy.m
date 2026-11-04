#import "RWTrailerPolicy.h"
static NSString *Text(id x){return [x isKindOfClass:NSString.class]?x:([x isKindOfClass:NSNumber.class]?[x stringValue]:@"");}
static NSArray *Rows(id x){return [x isKindOfClass:NSArray.class]?x:@[];}
static id Value(id s){if(![s isKindOfClass:NSDictionary.class]||[s[@"rank"]isEqual:@"deprecated"])return nil;id n=s[@"mainsnak"];if(![n isKindOfClass:NSDictionary.class])return nil;id d=n[@"datavalue"];return [d isKindOfClass:NSDictionary.class]?d[@"value"]:nil;}
static NSString *Normal(NSString *s){return [[[[s stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]]lowercaseString]componentsSeparatedByCharactersInSet:NSCharacterSet.alphanumericCharacterSet.invertedSet]componentsJoinedByString:@""];}
@implementation RWTrailerPolicy
+ (BOOL)movieIdentityReady:(NSDictionary *)meta {
    if(![meta isKindOfClass:NSDictionary.class]||![meta[@"type"]isEqual:@"movie"]||!Text(meta[@"name"]).length)return NO;
    NSInteger year=Text(meta[@"releaseInfo"]).integerValue;
    return year>=1800&&year<=2200&&[Text(meta[@"id"])rangeOfString:@"^tt[0-9]+$" options:NSRegularExpressionSearch].location==0;
}
+ (NSString *)cachedEntityID:(NSDictionary *)meta {
    if(![meta isKindOfClass:NSDictionary.class]||![meta[@"type"]isEqual:@"movie"]||![meta[@"discovery"]isKindOfClass:NSDictionary.class])return nil;
    NSDictionary *record=meta[@"discovery"];NSString *imdb=Text(meta[@"id"]),*qid=Text(record[@"entityID"]);
    if([imdb rangeOfString:@"^tt[0-9]+$" options:NSRegularExpressionSearch].location!=0||![record[@"imdb"]isEqual:imdb]||[qid rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location!=0||![record[@"source"]isEqual:[@"https://www.wikidata.org/wiki/" stringByAppendingString:qid]])return nil;
    return qid; // A fetch hint only. Fresh P345 and Apple catalog identity must still agree.
}
+ (BOOL)embeddedRuntimeFailure:(NSArray *)errors {
    for(id error in Rows(errors)){if(![error isKindOfClass:NSDictionary.class])continue;NSString *message=Text(error[@"message"]),*host=[NSURL URLWithString:Text(error[@"file"])].host.lowercaseString;BOOL provider=[host isEqual:@"youtube.com"]||[host hasSuffix:@".youtube.com"]||[host isEqual:@"youtube-nocookie.com"]||[host hasSuffix:@".youtube-nocookie.com"]||[host hasSuffix:@".ytimg.com"];
        if(provider&&[message hasPrefix:@"SyntaxError:"]&&[message rangeOfString:@"Unexpected" options:NSCaseInsensitiveSearch].location!=NSNotFound)return YES;
    }return NO;
}
+ (NSDictionary *)embeddedSource:(NSDictionary *)meta {
    if(![@[@"movie",@"series"]containsObject:meta[@"type"]?:@""])return nil;
    // IDs come from the exact title's metadata, never a fuzzy video search.
    for(id row in Rows(meta[@"trailers"])){
        if(![row isKindOfClass:NSDictionary.class]||![Text(row[@"type"]).lowercaseString isEqual:@"trailer"])continue;
        NSString *identifier=Text(row[@"source"]);
        if([identifier rangeOfString:@"^[A-Za-z0-9_-]{11}$" options:NSRegularExpressionSearch].location!=0)continue;
        return @{@"youtubeID":identifier,@"name":@"YouTube trailer",@"imdb":Text(meta[@"id"]),@"lookupSeconds":@0};
    }return nil;
}
+ (NSArray *)appleIDs:(NSDictionary *)entity imdb:(NSString *)imdb {
    if(![entity isKindOfClass:NSDictionary.class]||![entity[@"claims"]isKindOfClass:NSDictionary.class])return @[];
    NSDictionary *c=entity[@"claims"];BOOL match=NO;for(id s in Rows(c[@"P345"]))if([Value(s)isEqual:imdb])match=YES;if(!match)return @[];
    NSMutableOrderedSet *ids=[NSMutableOrderedSet new];for(id s in Rows(c[@"P6398"])){NSString *v=Text(Value(s));if(v.length>=5&&v.length<=14&&[v rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location==NSNotFound)[ids addObject:v];}return ids.array;
}
+ (NSDictionary *)source:(NSDictionary *)response ids:(NSArray *)ids meta:(NSDictionary *)meta {
    if(![response isKindOfClass:NSDictionary.class]||![meta[@"type"]isEqual:@"movie"])return nil;
    NSInteger year=[Text(meta[@"releaseInfo"])integerValue];if(year<1800||!Text(meta[@"name"]).length)return nil;
    for(id r in Rows(response[@"results"])){
        if(![r isKindOfClass:NSDictionary.class]||![ids containsObject:Text(r[@"trackId"])]||![r[@"kind"]isEqual:@"feature-movie"]||![Normal(Text(r[@"trackName"]))isEqual:Normal(Text(meta[@"name"]))]||[Text(r[@"releaseDate"])integerValue]!=year)continue;
        NSURL *video=[NSURL URLWithString:Text(r[@"previewUrl"])],*store=[NSURL URLWithString:Text(r[@"trackViewUrl"])];
        BOOL videoHost=[video.host.lowercaseString hasSuffix:@".itunes.apple.com"]||[video.host.lowercaseString hasSuffix:@".mzstatic.com"];
        BOOL storeHost=[@[@"itunes.apple.com",@"tv.apple.com"]containsObject:store.host.lowercaseString];
        if(![video.scheme isEqual:@"https"]||!videoHost||![store.scheme isEqual:@"https"]||!storeHost)continue;
        return @{@"url":video.absoluteString,@"storeURL":store.absoluteString,@"name":@"Apple TV preview",@"appleID":Text(r[@"trackId"])};
    }return nil;
}
@end
