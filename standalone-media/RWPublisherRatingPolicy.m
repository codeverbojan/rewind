#import "RWPublisherRatingPolicy.h"
#import "RWRatingPolicy.h"
#import "RWApplePreviewPolicy.h"
static NSDictionary *Map(id v){return [v isKindOfClass:NSDictionary.class]?v:@{};}
static NSArray *List(id v){return [v isKindOfClass:NSArray.class]?v:@[];}
static NSString *Text(id v){return [v isKindOfClass:NSString.class]?v:@"";}
static NSString *Name(NSString *s){return [[[[s stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]]lowercaseString]componentsSeparatedByCharactersInSet:NSCharacterSet.alphanumericCharacterSet.invertedSet]componentsJoinedByString:@""];}
static BOOL Matches(NSString *s,NSString *pattern){return s.length&&NSEqualRanges([s rangeOfString:pattern options:NSRegularExpressionSearch],NSMakeRange(0,s.length));}
static id Claim(id raw){NSDictionary *c=Map(raw);return [c[@"rank"]isEqual:@"deprecated"]?nil:Map(Map(c[@"mainsnak"])[@"datavalue"])[@"value"];}
@implementation RWPublisherRatingPolicy
+ (NSString *)storeSearchURL:(NSDictionary *)meta {
    NSString *title=Text(meta[@"name"]),*release=Text(meta[@"releaseInfo"]);
    if(![meta[@"type"]isEqual:@"series"]||!Matches(Text(meta[@"id"]),@"^tt[0-9]+$")||!Name(title).length||title.length>200||release.length<4||!Matches([release substringToIndex:4],@"^(18|19|20|21)[0-9]{2}$"))return nil;
    NSString *term=[title stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"]];
    return [NSString stringWithFormat:@"https://itunes.apple.com/search?term=%@&country=US&media=tvShow&entity=tvSeason&attribute=showTerm&limit=25",term];
}
+ (NSString *)storeShowURL:(NSData *)json meta:(NSDictionary *)meta {
    if(![self storeSearchURL:meta]||![json isKindOfClass:NSData.class]||json.length>128*1024)return nil;
    NSDictionary *root=Map([NSJSONSerialization JSONObjectWithData:json options:0 error:nil]);NSArray *rows=List(root[@"results"]);
    if(!rows.count||rows.count>25||![root[@"resultCount"]isKindOfClass:NSNumber.class]||[root[@"resultCount"]unsignedIntegerValue]!=rows.count)return nil;
    NSMutableDictionary *identities=[NSMutableDictionary new];
    for(id raw in rows){NSDictionary *r=Map(raw);
        if(![r[@"wrapperType"]isEqual:@"collection"]||![r[@"collectionType"]isEqual:@"TV Season"]||![r[@"country"]isEqual:@"USA"]||![Name(Text(r[@"artistName"]))isEqual:Name(Text(meta[@"name"]))])continue;
        id artist=r[@"artistId"];if(![artist isKindOfClass:NSNumber.class]||!Matches([artist stringValue],@"^[1-9][0-9]{0,15}$"))return nil;
        NSURL *url=[NSURL URLWithString:Text(r[@"artistViewUrl"])];NSString *identifier=[@"id" stringByAppendingString:[artist stringValue]];
        if(![url.scheme isEqual:@"https"]||![url.host isEqual:@"itunes.apple.com"]||url.user||url.password||url.port||url.fragment||(url.query&&![url.query isEqual:@"uo=4"])||!Matches(url.path,@"^/us/tv-show/[^/]+/id[1-9][0-9]*$")||![url.lastPathComponent isEqual:identifier])return nil;
        NSString *canonical=[@"https://itunes.apple.com" stringByAppendingString:url.path];
        if(identities[identifier]&&![identities[identifier]isEqual:canonical])return nil;
        identities[identifier]=canonical;
    }
    return identities.count==1?identities.allValues.firstObject:nil;
}
+ (BOOL)allowsStoreURL:(NSURL *)url showURL:(NSString *)showURL {
    if(![url.scheme isEqual:@"https"]||url.user||url.password||url.port||url.query||url.fragment)return NO;
    if([url.host isEqual:@"itunes.apple.com"])return showURL.length&&[url.absoluteString isEqual:showURL];
    return [url.host isEqual:@"tv.apple.com"]&&Matches(url.path,@"^/us/show/(?:[^/]+/)?umc\\.cmc\\.[a-z0-9]{10,40}$");
}
+ (NSDictionary *)storeRecord:(NSData *)html URL:(NSURL *)url meta:(NSDictionary *)meta {
    if(![self allowsStoreURL:url showURL:nil]||![url.host isEqual:@"tv.apple.com"])return nil;
    NSDictionary *record=[self record:html identifier:url.lastPathComponent meta:meta];
    return [record[@"source"]isEqual:url.absoluteString]?record:nil;
}
+ (NSArray *)disneyIDs:(NSDictionary *)entity imdb:(NSString *)imdb {
    if(!Matches(Text(imdb),@"^tt[0-9]+$"))return @[];NSDictionary *claims=Map(Map(entity)[@"claims"]);BOOL exact=NO;
    for(id c in List(claims[@"P345"]))if([Claim(c)isEqual:imdb])exact=YES;if(!exact)return @[];
    NSMutableOrderedSet *ids=[NSMutableOrderedSet new];for(id c in List(claims[@"P7596"])){NSString *key=Text(Claim(c));if(Matches(key,@"^[A-Za-z0-9]{12}$")){[ids addObject:key];if(ids.count==3)break;}}return ids.array;
}
+ (BOOL)allowsDisneyURL:(NSURL *)url identifier:(NSString *)identifier {
    if(!Matches(Text(identifier),@"^[A-Za-z0-9]{12}$")||![url.scheme isEqual:@"https"]||![url.host.lowercaseString isEqual:@"www.disneyplus.com"]||url.user||url.password||url.query||url.fragment||(url.port&&url.port.integerValue!=443))return NO;
    return [url.path isEqual:[@"/series/wp/" stringByAppendingString:identifier]]||Matches(url.path,@"^/browse/entity-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$");
}
+ (NSDictionary *)disneyRecord:(NSData *)html URL:(NSURL *)url identifier:(NSString *)identifier meta:(NSDictionary *)meta {
    if(![html isKindOfClass:NSData.class]||html.length>2*1024*1024||![self allowsDisneyURL:url identifier:identifier]||![url.path hasPrefix:@"/browse/entity-"]||![meta[@"type"]isEqual:@"series"]||!Matches(Text(meta[@"id"]),@"^tt[0-9]+$"))return nil;
    NSString *name=Name(Text(meta[@"name"])),*release=Text(meta[@"releaseInfo"]);if(!name.length||release.length<4)return nil;NSString *year=[release substringToIndex:4];if(!Matches(year,@"^(18|19|20|21)[0-9]{2}$"))return nil;
    NSString *text=[[NSString alloc]initWithData:html encoding:NSUTF8StringEncoding];if(!text)return nil;
    NSRegularExpression *re=[NSRegularExpression regularExpressionWithPattern:@"<script\\b[^>]*\\bid\\s*=\\s*[\"']__NEXT_DATA__[\"'][^>]*>(.*?)</script\\s*>" options:NSRegularExpressionDotMatchesLineSeparators|NSRegularExpressionCaseInsensitive error:nil];
    NSArray *hits=[re matchesInString:text options:0 range:NSMakeRange(0,text.length)];if(hits.count!=1)return nil;NSTextCheckingResult *hit=hits[0];
    NSDictionary *root=Map([NSJSONSerialization JSONObjectWithData:[[text substringWithRange:[hit rangeAtIndex:1]]dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil]),*page=Map(Map(root[@"props"])[@"pageProps"]);
    if(![page[@"region"]isEqual:@"us"]||![page[@"language"]isEqual:@"en"]||![page[@"hasContent"]isEqual:@YES]||![page[@"pathname"]isEqual:url.path]||![page[@"pageId"]isEqual:url.lastPathComponent])return nil;
    NSArray *content=List(Map(page[@"stitchDocument"])[@"mainContent"]);if(content.count>64)return nil;NSDictionary *series=nil,*details=nil;NSString *linkedName=nil,*promotion=nil;NSUInteger shows=0,links=0,detailCount=0,heroes=0;
    for(id raw in content){NSDictionary *component=Map(raw);if([component[@"_type"]isEqual:@"MediaDetails"]){details=component;detailCount++;}if([component[@"_type"]isEqual:@"DetailEntityHero"]){promotion=Text(component[@"promotion"]);heroes++;}NSArray *graph=List(Map(component[@"ldJSON"])[@"@graph"]);if(graph.count>16)return nil;
        for(id node in graph){NSDictionary *m=Map(node);
            if([m[@"@type"]isEqual:@"TVSeries"]){series=m;shows++;}
            if([m[@"@type"]isEqual:@"BreadcrumbList"]){NSDictionary *item=Map(Map(List(m[@"itemListElement"]).lastObject)[@"item"]);
                if([item[@"@type"]isEqual:@"WebPage"]&&[item[@"url"]isEqual:url.absoluteString]&&[item[@"@id"]isEqual:url.absoluteString]){linkedName=Text(item[@"name"]);links++;}}
        }
    }
    // Read only the page's single series record, never episode/recommendation
    // ratings. Redirect identity, page identity, title and premiere must agree.
    if(shows!=1||links!=1||detailCount!=1||![linkedName isEqual:series[@"name"]]||![details[@"locale"]isEqual:@"en-us"])return nil;
    NSString *title=Text(details[@"title"]),*detailYear=Text(details[@"release"]),*seoTitle=Text(series[@"name"]);
    if(![Name(title)isEqual:name]||detailYear.length<4||![[detailYear substringToIndex:4]isEqual:year])return nil;
    // The SEO title may contain an upcoming-season announcement. Accept only
    // the page's exact promotion, backed by its separate series title/year.
    BOOL titleMatches=[seoTitle isEqual:title]||[seoTitle isEqual:[title stringByAppendingString:@" | Watch Full Episodes | Disney+"]];
    if(!titleMatches&&heroes==1&&promotion.length>0&&promotion.length<=200)titleMatches=[seoTitle isEqual:[NSString stringWithFormat:@"%@ | %@ | Disney+",title,promotion]];
    NSString *published=Text(series[@"datePublished"]);if(!titleMatches||!Matches(published,@"^(18|19|20|21)[0-9]{2}(?:-[0-9]{2}-[0-9]{2})?$")||![[published substringToIndex:4]isEqual:year])return nil;
    return [RWRatingPolicy recordForPublisher:@{@"imdb":meta[@"id"],@"label":Text(series[@"contentRating"]),@"source":url.absoluteString,@"checked":@(NSDate.date.timeIntervalSince1970)} imdb:meta[@"id"]];
}
+ (NSDictionary *)record:(NSData *)html identifier:(NSString *)identifier meta:(NSDictionary *)meta {
    if(![html isKindOfClass:NSData.class]||html.length>2*1024*1024||![meta[@"type"]isEqual:@"series"]||[Text(meta[@"id"])rangeOfString:@"^tt[0-9]+$" options:NSRegularExpressionSearch].location!=0||[Text(identifier)rangeOfString:@"^umc\\.cmc\\.[a-z0-9]{10,40}$" options:NSRegularExpressionSearch].location!=0)return nil;
    NSString *name=Name(Text(meta[@"name"])),*year=Text(meta[@"releaseInfo"]);if(!name.length||year.length<4||[[year substringToIndex:4]rangeOfString:@"^(18|19|20|21)[0-9]{2}$" options:NSRegularExpressionSearch].location!=0)return nil;year=[year substringToIndex:4];
    NSString *text=[[NSString alloc]initWithData:html encoding:NSUTF8StringEncoding];if(!text)return nil;
    NSRegularExpression *re=[NSRegularExpression regularExpressionWithPattern:@"<script\\b[^>]*\\bid\\s*=\\s*[\"']?serialized-server-data[\"']?[^>]*>(.*?)</script\\s*>" options:NSRegularExpressionDotMatchesLineSeparators|NSRegularExpressionCaseInsensitive error:nil];NSTextCheckingResult *hit=[re firstMatchInString:text options:0 range:NSMakeRange(0,text.length)];if(!hit)return nil;
    NSDictionary *root=Map([NSJSONSerialization JSONObjectWithData:[[text substringWithRange:[hit rangeAtIndex:1]]dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil]);NSDictionary *chosen=nil;BOOL unknown=NO;NSUInteger matched=0;
    for(id raw in List(root[@"data"])){NSDictionary *page=Map(Map(raw)[@"data"]);NSURL *url=[RWApplePreviewPolicy allowedURL:Text(page[@"canonicalURL"]) base:nil];
        if(![url.host isEqual:@"tv.apple.com"]||![url.path hasPrefix:@"/us/show/"]||![url.lastPathComponent isEqual:identifier])continue;
        for(id rawShelf in List(page[@"shelves"])){NSDictionary *shelf=Map(rawShelf);if(![shelf[@"id"]isEqual:[@"canonical-header-" stringByAppendingString:identifier]])continue;
            for(id rawItem in List(shelf[@"items"])){NSDictionary *m=Map(rawItem);if(![m[@"type"]isEqual:@"Show"]||![Name(Text(m[@"title"]))isEqual:name]||![List(m[@"badgeRowMetadata"])containsObject:year])continue;
                // Only the title's formal US classification. Common Sense ages,
                // episode cards, trailers and recommendations are not its rating.
                matched++;NSArray *badges=List(m[@"ratingBadges"]);if(!badges.count)unknown=YES;
                for(id rawBadge in badges){NSDictionary *b=Map(rawBadge);if(![b[@"$type"]isEqual:@"rating"])continue;
                    NSDictionary *r=[RWRatingPolicy recordForPublisher:@{@"imdb":meta[@"id"],@"label":Text(b[@"fallbackText"]),@"source":url.absoluteString,@"checked":@(NSDate.date.timeIntervalSince1970)} imdb:meta[@"id"]];
                    if(!r){unknown=YES;continue;}if(!chosen||[r[@"minimumAge"]integerValue]>[chosen[@"minimumAge"]integerValue])chosen=r;
                }
            }
        }
    }return unknown||matched!=1?nil:chosen;
}
@end
