#import "RWHomePresentation.h"
#import "RWLanguageLabels.h"
#import <math.h>
static NSDictionary *Map(id v){return [v isKindOfClass:NSDictionary.class]?v:@{};}
static NSArray *List(id v){return [v isKindOfClass:NSArray.class]?v:@[];}
static NSString *Text(id v){return [v isKindOfClass:NSString.class]?v:[v isKindOfClass:NSNumber.class]?[v stringValue]:@"";}
static NSString *Time(double n){if(!isfinite(n)||n<0)n=0;n=MIN(n,864000);NSInteger t=(NSInteger)n;return t>=3600?[NSString stringWithFormat:@"%ld:%02ld:%02ld",(long)(t/3600),(long)(t/60%60),(long)(t%60)]:[NSString stringWithFormat:@"%ld:%02ld",(long)(t/60),(long)(t%60)];}
@implementation RWHomePresentation
+ (NSArray *)rows:(NSArray *)rows mediaType:(NSString *)type {
    if(!type.length)return rows;NSMutableArray *out=[NSMutableArray new];
    for(NSDictionary *row in rows){if(Text(row[@"mediaType"]).length){if([row[@"mediaType"]isEqual:type])[out addObject:row];continue;}
        NSMutableArray *items=[NSMutableArray new];for(NSDictionary *m in List(row[@"items"]))if([m[@"type"]isEqual:type])[items addObject:m];
        if(items.count){NSMutableDictionary *copy=[row mutableCopy];copy[@"items"]=items;[out addObject:copy];}
    }return out;
}
+ (NSString *)heading:(NSDictionary *)row kids:(BOOL)kids {
    NSString *key=Text(row[@"id"]),*recipe=Text(row[@"recipe"]);BOOL film=[row[@"mediaType"]isEqual:@"movie"];
    if([key isEqual:@"continue"])return @"Continue Watching";
    if([key isEqual:@"up-next"])return @"Your Next Episode";
    if([recipe isEqual:@"world"])return @"World Cinema";
    if([recipe isEqual:@"for-you"])return kids?(film?@"Movies for Kids":@"Shows for Kids"):(film?@"Movies for You":@"Series for You");
    if([recipe isEqual:@"new"])return film?@"New Movies to Discover":@"New Series to Discover";
    if([recipe isEqual:@"older"])return film?@"Rediscover These Movies":@"Rediscover These Series";
    if([recipe isEqual:@"more"])return film?@"More Movies for You":@"More Series for You";
    if([recipe isEqual:@"because"]&&Text(Map(row[@"anchor"])[@"name"]).length)return [@"Because You Liked " stringByAppendingString:row[@"anchor"][@"name"]];
    // These remain the same evidence-backed recipes. Presentation never
    // assigns an unverified runtime, award, franchise or popularity claim.
    if([recipe isEqual:@"mood"]&&Text(row[@"mood"]).length)return [NSString stringWithFormat:@"%@ · %@",row[@"mood"],film?@"Movies":@"Series"];
    return Text(row[@"title"]);
}
+ (NSArray *)initialLoadingRows {
    // No fictitious titles or eligibility. Only the visible reusable cells
    // draw these static shapes; they never trigger artwork/source requests.
    return @[@{@"id":@"loading-first",@"items":@[],@"loading":@YES,@"landscape":@NO},
             @{@"id":@"loading-second",@"items":@[],@"loading":@YES,@"landscape":@NO}];
}
+ (NSDictionary *)posterContent:(NSDictionary *)meta {
    // Only values consumed by RWPoster. Source checks, cast enrichment and
    // ranking diagnostics must not tear down an otherwise unchanged card.
    meta=Map(meta);NSMutableDictionary *content=[NSMutableDictionary new];
    for(NSString *key in @[@"id",@"imdb_id",@"name",@"type",@"seriesName",@"releaseInfo",@"imdbRating",@"poster",@"background",@"episodeCaption",@"episodeVideoID",@"showLanguage"])if(meta[key])content[key]=meta[key];
    NSDictionary *art=Map(Map(meta[@"discovery"])[@"artwork"]);
    if([meta[@"type"]isEqual:@"series"]&&[art[@"imdb"]isEqual:meta[@"id"]?:meta[@"imdb_id"]]&&[art[@"provider"]isEqual:@"TVmaze"])
        content[@"verifiedArtwork"]=@{@"background":List(art[@"background"]),@"poster":List(art[@"poster"])};
    NSDictionary *record=Map(meta[@"historyRecord"]);NSMutableDictionary *progress=[NSMutableDictionary new];
    if(record.count){for(NSString *key in @[@"videoID",@"position",@"duration"])if(record[key])progress[key]=record[key];content[@"historyRecord"]=progress;}
    if([meta[@"showLanguage"]boolValue]){NSDictionary *d=Map(meta[@"discovery"]);content[@"language"]=@[Text(d[@"primaryLanguage"]),Text(Map(List(d[@"originalLanguages"]).firstObject)[@"id"]),Text(Map(List(d[@"originalLanguages"]).firstObject)[@"name"])];}
    return content;
}
+ (NSDictionary *)normalizedHome:(NSDictionary *)home {
    home=Map(home);if(!home.count||[home[@"layoutVersion"]integerValue]>=46)return home;
    NSMutableDictionary *page=[home mutableCopy];NSMutableArray *rows=[NSMutableArray new];
    // Upgrade cached mixed shelves without waiting for metadata or discarding
    // the cached page. Live availability/age checks still run before display.
    for(id raw in List(home[@"rows"])){NSDictionary *old=Map(raw);NSString *key=Text(old[@"id"]);if(!key.length)continue;
        for(NSString *type in @[@"movie",@"series"]){BOOL film=[type isEqual:@"movie"],world=[key isEqual:@"world"];if(world&&!film)continue;
            NSMutableArray *items=[NSMutableArray new];for(id item in List(old[@"items"]))if([Map(item)[@"type"]isEqual:type])[items addObject:item];if(!items.count)continue;
            NSString *noun=film?@"Films":@"Series",*lower=film?@"films":@"series",*title=Text(old[@"title"]);BOOL broad=[@[@"for-you",@"series",@"more",@"world"]containsObject:key];
            if([key isEqual:@"for-you"]||[key isEqual:@"series"])title=[noun stringByAppendingString:@" for you"];
            else if([key isEqual:@"new"])title=[NSString stringWithFormat:@"New %@ worth watching",lower];
            else if([key isEqual:@"older"])title=[NSString stringWithFormat:@"Older %@ to discover",lower];
            else if([key isEqual:@"more"])title=[NSString stringWithFormat:@"More %@ to discover",lower];
            else if(world)title=@"World Cinema · Films";
            else title=[NSString stringWithFormat:@"%@ · %@",noun,title];
            [rows addObject:@{@"id":world?@"world":[key stringByAppendingFormat:@"-%@",type],@"mediaType":type,@"recipe":key,@"title":title,@"items":items,@"minimumCount":broad?@1:@6}];
        }
    }
    // A migration is bounded by the old seven rows (up to fourteen typed
    // halves). The next worker plan supplies the normal seven-shelf budget.
    page[@"rows"]=rows;page[@"layoutVersion"]=@46;page[@"migratedLayout"]=@YES;return page;
}
+ (NSDictionary *)cardText:(NSDictionary *)meta {
    meta=Map(meta);BOOL series=[meta[@"type"]isEqual:@"series"],film=[meta[@"type"]isEqual:@"movie"];NSString *kind=series?@"Series":film?@"Film":@"";
    NSString *title=Text(meta[@"name"]),*year=Text(meta[@"releaseInfo"]);if(year.length>9)year=[year substringToIndex:4];if(year.integerValue<1800||year.integerValue>2200)year=@"";
    NSDictionary *record=Map(meta[@"historyRecord"]);NSString *caption=Text(meta[@"episodeCaption"]),*video=Text(record[@"videoID"]?:meta[@"episodeVideoID"]),*identifier=Text(meta[@"id"]?:meta[@"imdb_id"]);NSArray *parts=[video componentsSeparatedByString:@":"];
    NSString *episode=@"";if(series&&parts.count==3&&[parts[0]isEqual:identifier]&&[parts[1]integerValue]>0&&[parts[2]integerValue]>0)episode=[NSString stringWithFormat:@"S%ld E%ld",(long)[parts[1]integerValue],(long)[parts[2]integerValue]];
    NSString *secondary=caption.length?caption:episode.length?episode:year;
    if(record.count){NSString *position=Time([Text(record[@"position"])doubleValue]);secondary=episode.length?[NSString stringWithFormat:@"%@ · %@",episode,position]:[NSString stringWithFormat:@"Resume at %@",position];}
    if(series&&Text(meta[@"seriesName"]).length)title=meta[@"seriesName"];
    NSString *language=@"";NSDictionary *discovery=Map(meta[@"discovery"]);
    if([meta[@"showLanguage"]boolValue]){language=RWLanguageDisplay(discovery,RWLanguageBundledLabels());if(language.length)secondary=secondary.length?[secondary stringByAppendingFormat:@" · %@",language]:language;}
    NSScanner *scanner=[NSScanner scannerWithString:Text(meta[@"imdbRating"])];double score=0;BOOL valid=[scanner scanDouble:&score]&&scanner.isAtEnd&&isfinite(score)&&score>=1&&score<=10;
    NSString *rating=valid?[NSString stringWithFormat:@"IMDb %.1f",score]:@"";
    NSMutableArray *access=[NSMutableArray new];for(NSString *part in @[title,kind,secondary,rating])if(part.length)[access addObject:part];
    return @{@"title":title,@"kind":kind,@"secondary":secondary,@"rating":rating,@"language":language,@"accessibility":[access componentsJoinedByString:@", "]};
}
@end
