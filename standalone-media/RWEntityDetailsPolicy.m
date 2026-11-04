#import "RWEntityCreditPolicy.h"
#import "RWEntityDetailsPolicy.h"
#import "RWDiscoveryMetadataPolicy.h"
#import <math.h>
static NSDictionary *D(id x){return [x isKindOfClass:NSDictionary.class]?x:@{};}
static NSArray *A(id x){return [x isKindOfClass:NSArray.class]?x:@[];}
static NSString *T(id x){return [x isKindOfClass:NSString.class]?x:[x isKindOfClass:NSNumber.class]?[x stringValue]:@"";}
static double N(id x){NSString *s=T(x);NSScanner *scanner=[NSScanner scannerWithString:s];double n=0;return s.length&&[scanner scanDouble:&n]&&scanner.isAtEnd&&isfinite(n)?n:0;}
static NSInteger Year(id value){NSString *s=T(value);return [s rangeOfString:@"^[12][0-9]{3}($|[-–— ])" options:NSRegularExpressionSearch].location==0?[[s substringToIndex:4]integerValue]:0;}
static NSArray *Values(NSDictionary *e,NSString *property){NSMutableArray *normal=[NSMutableArray new],*preferred=[NSMutableArray new];for(id raw in A(D(e[@"claims"])[property])){NSDictionary *claim=D(raw);if([claim[@"rank"]isEqual:@"deprecated"])continue;id value=D(D(claim[@"mainsnak"])[@"datavalue"])[@"value"];if(value&&value!=NSNull.null)[([claim[@"rank"]isEqual:@"preferred"]?preferred:normal) addObject:value];}return preferred.count?preferred:normal;}
static NSString *DateValue(NSArray *values){NSMutableOrderedSet *dates=[NSMutableOrderedSet new];for(id raw in values){NSDictionary *date=D(raw);NSString *time=T(date[@"time"]);NSInteger precision=N(date[@"precision"]);if(precision<9||[time rangeOfString:@"^\\+[0-9]{4}-[0-9]{2}-[0-9]{2}T" options:NSRegularExpressionSearch].location!=0||N(date[@"before"])>0||N(date[@"after"])>0)continue;NSString *year=[time substringWithRange:NSMakeRange(1,4)];if(year.integerValue<1000||year.integerValue>2200)continue;
    NSString *value=year;BOOL gregorian=[T(date[@"calendarmodel"])hasSuffix:@"/Q1985727"];NSInteger month=[[time substringWithRange:NSMakeRange(6,2)]integerValue],day=[[time substringWithRange:NSMakeRange(9,2)]integerValue];
    if(precision>=10&&gregorian){if(month<1||month>12)continue;NSInteger days=[@[@31,@28,@31,@30,@31,@30,@31,@31,@30,@31,@30,@31][month-1]integerValue],y=year.integerValue;if(month==2&&y%4==0&&(y%100!=0||y%400==0))days++;if(precision>=11&&(day<1||day>days))continue;NSString *m=@[@"Jan",@"Feb",@"Mar",@"Apr",@"May",@"Jun",@"Jul",@"Aug",@"Sep",@"Oct",@"Nov",@"Dec"][month-1];value=precision>=11?[NSString stringWithFormat:@"%ld %@ %@",(long)day,m,year]:[NSString stringWithFormat:@"%@ %@",m,year];}[dates addObject:value];}return dates.count==1?dates.firstObject:@"";}
static NSString *Names(NSArray *values,NSDictionary *labels){NSMutableOrderedSet *names=[NSMutableOrderedSet new];for(id raw in values){NSString *qid=T(D(raw)[@"id"]),*name=[RWDiscoveryMetadataPolicy displayName:D(labels[qid])];if(name.length&&name.length<100)[names addObject:name];if(names.count==3)break;}return [names.array componentsJoinedByString:@", "];}
@implementation RWEntityDetailsPolicy
+ (NSString *)cleanBiography:(NSString *)text {
    if(![text isKindOfClass:NSString.class])return @"";
    // Wikipedia plain extracts may leave empty pronunciation parentheses.
    // Keep dates, aliases and all parentheticals containing letters/numbers.
    NSString *clean=[text stringByReplacingOccurrencesOfString:@"\\s*\\([\\s,;:/\\-]*\\)" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0,text.length)];
    return [clean stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}
+ (NSArray *)labelIDs:(NSDictionary *)entity studio:(BOOL)studio {NSMutableOrderedSet *ids=[NSMutableOrderedSet new];for(NSString *property in studio?@[@"P31",@"P159",@"P112"]:@[@"P106",@"P19"]){for(id raw in Values(entity,property)){NSString *qid=T(D(raw)[@"id"]);if([qid rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location==0)[ids addObject:qid];if(ids.count==12)return ids.array;}}return ids.array;}
+ (NSDictionary *)details:(NSDictionary *)entity role:(NSString *)role labels:(NSDictionary *)labels {
    BOOL studio=[role isEqual:@"studio"];NSMutableDictionary *result=[[RWDiscoveryMetadataPolicy entityProfile:entity role:role]mutableCopy];NSString *qid=T(entity[@"id"]);if([qid rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location!=0)return @{};
    NSString *source=[@"https://www.wikidata.org/wiki/" stringByAppendingString:qid];result[@"entitySourceURL"]=source;result[@"entityRevision"]=entity[@"lastrevid"]?:@0;result[@"summary"]=result[@"biography"]?:@"";
    NSString *kind=Names(Values(entity,studio?@"P31":@"P106"),labels);result[@"kindLabel"]=kind.length?kind:studio?@"Company":[role isEqual:@"director"]?@"Director":[role isEqual:@"cast"]?@"Actor":@"Person";
    NSMutableArray *facts=[NSMutableArray new];void(^fact)(NSString *,NSString *,NSString *)=^(NSString *label,NSString *value,NSString *property){if(value.length)[facts addObject:@{@"label":label,@"value":value,@"property":property,@"sourceURL":source}];};
    if(studio){fact(@"Founded",DateValue(Values(entity,@"P571")),@"P571");fact(@"Based in",Names(Values(entity,@"P159"),labels),@"P159");fact(@"Founded by",Names(Values(entity,@"P112"),labels),@"P112");}
    else {fact(@"Born",DateValue(Values(entity,@"P569")),@"P569");fact(@"Birthplace",Names(Values(entity,@"P19"),labels),@"P19");fact(@"Died",DateValue(Values(entity,@"P570")),@"P570");}
    result[@"facts"]=facts;NSString *article=T(D(D(entity[@"sitelinks"])[@"enwiki"])[@"title"]);if(article.length&&article.length<=200)result[@"wikipediaTitle"]=article;
    return result;
}
+ (NSDictionary *)biography:(NSDictionary *)response entityID:(NSString *)identifier {
    NSArray *pages=D(D(response[@"query"])[@"pages"]).allValues;if(pages.count!=1)return @{};NSDictionary *page=D(pages[0]);
    if([T(identifier)rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location!=0||![D(page[@"pageprops"])[@"wikibase_item"]isEqual:identifier]||page[@"missing"]||page[@"invalid"]||![page[@"ns"]isEqual:@0]||D(page[@"pageprops"])[@"disambiguation"])return @{};
    NSString *extract=[T(page[@"extract"])stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet],*title=T(page[@"title"]);if(!extract.length||!title.length)return @{};
    extract=[extract stringByReplacingOccurrencesOfString:@"\\[[0-9, –-]+\\]" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0,extract.length)];
    if(extract.length>1400){NSRange cut=[extract rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,1396)];extract=[[extract substringWithRange:cut]stringByAppendingString:@"…"];}
    NSString *path=[title stringByReplacingOccurrencesOfString:@" " withString:@"_"];path=[path stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"]];
    return @{@"biography":[self cleanBiography:extract],@"biographySourceURL":[@"https://en.wikipedia.org/wiki/" stringByAppendingString:path],@"biographyCredit":@"Wikipedia · CC BY-SA 4.0 · excerpt",@"biographyRevision":page[@"lastrevid"]?:@0};
}
+ (NSDictionary *)highlights:(NSArray *)credits entity:(NSDictionary *)entity now:(double)now {
    NSString *qid=T(entity[@"id"]),*role=T(entity[@"creditRole"]),*field=[RWEntityCreditPolicy field:role];if([qid rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location!=0||!field)return @{@"pool":@[],@"knownFor":@[],@"recent":@[],@"rated":@[]};
    NSDateFormatter *format=[NSDateFormatter new];format.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];format.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];format.dateFormat=@"yyyy-MM-dd";NSString *today=[format stringFromDate:[NSDate dateWithTimeIntervalSince1970:now]];NSInteger year=today.integerValue;NSMutableDictionary *unique=[NSMutableDictionary new];
    for(id raw in credits){NSDictionary *m=D(raw);NSString *key=T(m[@"id"]?:m[@"imdb_id"]);if(!key.length||![@[@"movie",@"series"]containsObject:T(m[@"type"])])continue;BOOL match=[m[@"creditEntityID"]isEqual:qid]&&[m[@"creditRole"]isEqual:role];for(id ref in A(D(m[@"discovery"])[field]))if([D(ref)[@"id"]isEqual:qid])match=YES;if(!match)continue;
        NSMutableDictionary *copy=[(unique[key]?:@{})mutableCopy];[copy addEntriesFromDictionary:m];[copy removeObjectForKey:@"videos"];unique[key]=copy;
    }
    double(^quality)(NSDictionary *)=^double(NSDictionary *m){double rating=N(m[@"imdbRating"]),votes=N(m[@"imdbVotes"]);return rating>=1&&rating<=10&&votes>0?(rating*votes+6.5*5000)/(votes+5000):6.5;};
    NSArray *ranked=[unique.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){double qa=quality(a),qb=quality(b);if(qa!=qb)return qa>qb?NSOrderedAscending:NSOrderedDescending;double va=N(a[@"imdbVotes"]),vb=N(b[@"imdbVotes"]);return va==vb?[T(a[@"id"])compare:T(b[@"id"])]:va>vb?NSOrderedAscending:NSOrderedDescending;}];
    NSMutableArray *released=[NSMutableArray new];for(NSDictionary *m in ranked){NSInteger y=Year(m[@"releaseInfo"]);NSString *date=T(m[@"released"]);if(y<1800||y>year||(date.length>=10&&[[date substringToIndex:10]compare:today]==NSOrderedDescending))continue;[released addObject:m];}
    NSArray *recent=[released sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSInteger ya=Year(a[@"releaseInfo"]),yb=Year(b[@"releaseInfo"]);return ya==yb?quality(a)>quality(b)?NSOrderedAscending:quality(a)<quality(b)?NSOrderedDescending:[T(a[@"id"])compare:T(b[@"id"])]:ya>yb?NSOrderedAscending:NSOrderedDescending;}];
    NSMutableArray *high=[NSMutableArray new];for(NSDictionary *m in released)if(N(m[@"imdbRating"])>=7.5&&N(m[@"imdbVotes"])>=1000&&quality(m)>=7)[high addObject:m];
    // Retain quality and recent windows, not an ever-growing filmography copy.
    NSMutableOrderedSet *keep=[NSMutableOrderedSet new];for(NSArray *list in @[ranked,recent])for(NSUInteger i=0;i<MIN((NSUInteger)60,list.count);i++)[keep addObject:list[i]];
    NSArray *(^first)(NSArray *)=^NSArray *(NSArray *a){return [a subarrayWithRange:NSMakeRange(0,MIN((NSUInteger)8,a.count))];};
    return @{@"pool":keep.array,@"knownFor":first(released),@"recent":first(recent),@"rated":first(high)};
}
@end
