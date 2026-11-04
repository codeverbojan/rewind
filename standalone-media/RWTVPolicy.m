#import "RWTVPolicy.h"
static NSString *Text(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static NSString *Normal(id x){NSArray *bits=[[[Text(x)stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]]lowercaseString]componentsSeparatedByCharactersInSet:NSCharacterSet.alphanumericCharacterSet.invertedSet];NSMutableArray *out=[NSMutableArray new];for(NSString *b in bits)if(b.length)[out addObject:b];return [out componentsJoinedByString:@" "];}
static NSDate *Released(id raw){NSString *s=Text(raw);if(s.length<10)return nil;static NSCache *cache;static NSArray *formats;static dispatch_once_t once;dispatch_once(&once,^{cache=[NSCache new];cache.countLimit=1200;NSMutableArray *list=[NSMutableArray new];for(NSString *format in @[@"yyyy-MM-dd",@"yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",@"yyyy-MM-dd'T'HH:mm:ssXXXXX"]){NSDateFormatter *f=[NSDateFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];f.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];f.dateFormat=format;[list addObject:f];}formats=list;});id saved=[cache objectForKey:s];if(saved)return saved==NSNull.null?nil:saved;NSDateFormatter *f=formats[s.length==10?0:([s containsString:@"."]?1:2)];NSDate *date=[f dateFromString:s];[cache setObject:date?:NSNull.null forKey:s];return date;}
static NSInteger Order(NSDictionary *ep){return [ep[@"season"]integerValue]*10000+[ep[@"episode"]integerValue];}
static BOOL Progress(NSDictionary *r){return [r[@"position"]doubleValue]>3||[r[@"completed"]boolValue]||[r[@"progressOverride"]isEqual:@"unwatched"];}
#include "RWSearchIdentity.h"
@implementation RWTVPolicy
+ (NSArray *)localMatches:(NSArray *)items query:(NSString *)query {
    NSString *q=Normal(query);if(!q.length)return @[];
    NSArray *words=[q componentsSeparatedByString:@" "];NSMutableArray *matches=[NSMutableArray new];
    for(NSDictionary *item in items){NSString *name=Normal(item[@"seriesName"]?:item[@"name"]);BOOL match=[name containsString:q];
        if(!match){NSSet *tokens=[NSSet setWithArray:[name componentsSeparatedByString:@" "]];match=YES;for(NSString *word in words)if(![tokens containsObject:word]){match=NO;break;}}
        if(match)[matches addObject:item];
    }
    return [self search:matches query:query];
}
+ (NSArray *)search:(NSArray *)items query:(NSString *)query {
    NSString *q=Normal(query);NSArray *words=[q componentsSeparatedByString:@" "];NSMutableArray *scored=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];NSUInteger index=0;
    for(id m in RWSearchUnique(items)){if(![m isKindOfClass:NSDictionary.class])continue;NSString *key=[Text(m[@"type"])stringByAppendingFormat:@":%@",Text(m[@"id"])];if(!Text(m[@"id"]).length||[seen containsObject:key])continue;[seen addObject:key];NSString *name=Normal(m[@"name"]);NSInteger score=0;
        if([name isEqual:q])score=10000;else if([name hasPrefix:[q stringByAppendingString:@" "]])score=7000;else if([name containsString:q])score=5000;else{NSSet *tokens=[NSSet setWithArray:[name componentsSeparatedByString:@" "]];NSUInteger matched=0;for(NSString *word in words)if([tokens containsObject:word])matched++;score=matched==words.count?3000:100*(NSInteger)matched;}
        [scored addObject:@{@"meta":m,@"score":@(score),@"index":@(index++)}];
    }
    [scored sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSComparisonResult r=[b[@"score"]compare:a[@"score"]];if(r!=NSOrderedSame)return r;return [a[@"index"]compare:b[@"index"]];}];return [scored valueForKey:@"meta"];
}
+ (NSArray *)episodes:(NSDictionary *)show {
    NSMutableArray *out=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];id videos=show[@"videos"];if(![videos isKindOfClass:NSArray.class])return out;
    for(id e in videos)if([e isKindOfClass:NSDictionary.class]&&[e[@"season"]integerValue]>=0&&[e[@"episode"]integerValue]>0){NSString *expected=[NSString stringWithFormat:@"%@:%ld:%ld",Text(show[@"id"]),(long)[e[@"season"]integerValue],(long)[e[@"episode"]integerValue]];if([Text(e[@"id"])isEqual:expected]&&![seen containsObject:expected]){[seen addObject:expected];[out addObject:e];}}
    return [out sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSInteger x=Order(a),y=Order(b);return x<y?NSOrderedAscending:(x>y?NSOrderedDescending:NSOrderedSame);}];
}
+ (BOOL)released:(NSDictionary *)episode now:(NSDate *)now {NSDate *date=Released(episode[@"released"]);return date&&[date compare:now]!=NSOrderedDescending;}
+ (NSDictionary *)nextEpisode:(NSDictionary *)show history:(NSDictionary *)history now:(NSDate *)now {
    return [self nextFromEpisodes:[self episodes:show] history:history now:now];
}
+ (NSDictionary *)nextFromEpisodes:(NSArray *)episodes history:(NSDictionary *)history now:(NSDate *)now {
    NSDictionary *latest=nil,*lastEpisode=nil;
    for(NSDictionary *e in episodes){NSDictionary *r=history[e[@"id"]];if([self released:e now:now]&&Progress(r)&&(!latest||[r[@"updated"]doubleValue]>[latest[@"updated"]doubleValue]||([r[@"updated"]doubleValue]==[latest[@"updated"]doubleValue]&&Order(e)>Order(lastEpisode)))){latest=r;lastEpisode=e;}}
    if(latest&&![latest[@"completed"]boolValue])return lastEpisode;
    for(NSDictionary *e in episodes)if([e[@"season"]intValue]>0&&(!lastEpisode||Order(e)>Order(lastEpisode))&&![history[e[@"id"]][@"completed"]boolValue]&&[self released:e now:now])return e;
    return nil;
}
// Playback continuation follows the current episode, independently of Home's
// latest-history selection. Never skip an unreleased next episode.
+ (NSDictionary *)episodeAfter:(NSString *)videoID show:(NSDictionary *)show now:(NSDate *)now {
    if(!videoID.length||![show[@"type"]isEqual:@"series"])return nil;
    BOOL found=NO;
    for(NSDictionary *episode in [self episodes:show]){
        if([episode[@"season"]integerValue]<1)continue;
        if(found)return [self released:episode now:now]?episode:nil;
        if([episode[@"id"]isEqual:videoID])found=[self released:episode now:now];
    }
    return nil;
}
+ (NSArray *)continuingRecords:(NSArray *)records {
    // Choose the latest meaningful event BEFORE excluding completed records.
    // Otherwise an old unfinished episode reappears after a newer one ends.
    NSArray *ordered=[records sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){double x=[a[@"updated"]doubleValue],y=[b[@"updated"]doubleValue];if(x!=y)return x>y?NSOrderedAscending:NSOrderedDescending;BOOL ac=[a[@"completed"]boolValue],bc=[b[@"completed"]boolValue];if(ac!=bc)return ac?NSOrderedAscending:NSOrderedDescending;return [Text(a[@"videoID"])compare:Text(b[@"videoID"])];}];
    NSMutableSet *seen=[NSMutableSet new];NSMutableArray *out=[NSMutableArray new];
    for(NSDictionary *r in ordered){NSString *key=Text(r[@"meta"][@"id"]?:r[@"meta"][@"imdb_id"]);if(!key.length||!Text(r[@"videoID"]).length||!Progress(r)||[seen containsObject:key])continue;[seen addObject:key];if(![r[@"completed"]boolValue]&&[r[@"position"]doubleValue]>3)[out addObject:r];}
    return out;
}
+ (NSDictionary *)episodeMeta:(NSDictionary *)episode show:(NSDictionary *)show {
    NSMutableDictionary *m=[show mutableCopy];[m removeObjectForKey:@"videos"];NSString *name=Text(show[@"seriesName"]);if(!name.length)name=Text(show[@"name"]);NSString *title=Text(episode[@"title"]);if(!title.length)title=Text(episode[@"name"]);
    m[@"seriesName"]=name;m[@"name"]=[NSString stringWithFormat:@"%@ · S%02ld E%02ld · %@",name,(long)[episode[@"season"]integerValue],(long)[episode[@"episode"]integerValue],title];m[@"season"]=episode[@"season"];m[@"episode"]=episode[@"episode"];return m;
}
+ (NSArray *)newEpisodes:(NSDictionary *)show seen:(NSArray *)seen since:(NSDate *)since now:(NSDate *)now {
    if(!seen)return @[];NSSet *known=[NSSet setWithArray:seen];NSMutableArray *out=[NSMutableArray new];
    for(NSDictionary *e in [self episodes:show]){NSDate *date=Released(e[@"released"]);if([e[@"season"]intValue]>0&&date&&[date compare:since]!=NSOrderedAscending&&[date compare:now]!=NSOrderedDescending&&![known containsObject:e[@"id"]])[out addObject:e];}return out;
}
@end
