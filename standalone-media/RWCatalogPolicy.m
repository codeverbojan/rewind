#import "RWCatalogPolicy.h"
static NSString *CText(id x){return [x isKindOfClass:NSString.class]?x:([x isKindOfClass:NSNumber.class]?[x stringValue]:@"");}
static NSString *CEscape(NSString *s){return [s stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"]];}
@implementation RWCatalogPolicy
+ (NSString *)URLForType:(NSString *)type sort:(NSString *)sort genre:(NSString *)genre year:(NSInteger)year skip:(NSUInteger)skip now:(NSDate *)now {
    if(![@[@"movie",@"series"]containsObject:type])return nil;
    NSInteger current=[[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian]component:NSCalendarUnitYear fromDate:now];
    if(year<0||year>current||year>0&&year<1900||skip>10000)return nil;
    NSString *catalog=@"top",*value=genre;
    if(year||[sort isEqual:@"Newest"]){catalog=@"year";value=[@(year?:current)stringValue];}
    else if([sort isEqual:@"Top rated"])catalog=@"imdbRating";
    NSString *extra=value.length?[NSString stringWithFormat:@"genre=%@&skip=%lu",CEscape(value),(unsigned long)skip]:[NSString stringWithFormat:@"skip=%lu",(unsigned long)skip];
    return [NSString stringWithFormat:@"https://v3-cinemeta.strem.io/catalog/%@/%@/%@.json",type,catalog,extra];
}
+ (NSArray *)filter:(NSArray *)items genre:(NSString *)genre year:(NSInteger)year rating:(double)rating sort:(NSString *)sort now:(NSDate *)now {
    NSDateFormatter *f=[NSDateFormatter new];f.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"];f.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];f.dateFormat=@"yyyy-MM-dd";
    NSString *today=[f stringFromDate:now];NSMutableArray *out=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(id raw in items){if(![raw isKindOfClass:NSDictionary.class])continue;NSDictionary *m=raw;NSString *identifier=CText(m[@"id"]),*release=CText(m[@"released"]),*yearString=CText(m[@"releaseInfo"]?:m[@"year"]);
        if(!identifier.length||!CText(m[@"name"]).length||[seen containsObject:identifier])continue;
        if(release.length>=10&&[[release substringToIndex:10]compare:today]==NSOrderedDescending)continue;
        if(year&&yearString.integerValue!=year)continue;
        NSArray *genres=[m[@"genres"]isKindOfClass:NSArray.class]?m[@"genres"]:([m[@"genre"]isKindOfClass:NSArray.class]?m[@"genre"]:@[]);
        if(genre.length&&![genres containsObject:genre])continue;
        if(rating>0&&CText(m[@"imdbRating"]).doubleValue<rating)continue;
        [seen addObject:identifier];[out addObject:m];
    }
    if([sort isEqual:@"Newest"]||[sort isEqual:@"Top rated"])[out sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){
        if([sort isEqual:@"Top rated"])return [@(CText(b[@"imdbRating"]).doubleValue)compare:@(CText(a[@"imdbRating"]).doubleValue)];
        NSString *da=CText(a[@"released"]),*db=CText(b[@"released"]);if(!da.length)da=CText(a[@"releaseInfo"]);if(!db.length)db=CText(b[@"releaseInfo"]);return [db compare:da];
    }];return out;
}
@end
