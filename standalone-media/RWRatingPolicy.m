#import "RWRatingPolicy.h"
static NSArray *Rows(id value){return [value isKindOfClass:NSArray.class]?value:@[];}
static id Value(id statement){if(![statement isKindOfClass:NSDictionary.class])return nil;id snak=statement[@"mainsnak"];if(![snak isKindOfClass:NSDictionary.class])return nil;id data=snak[@"datavalue"];return [data isKindOfClass:NSDictionary.class]?data[@"value"]:nil;}
@implementation RWRatingPolicy
+ (BOOL)needsLookup:(NSDictionary *)rating type:(NSString *)type now:(double)now {
    if(![rating isKindOfClass:NSDictionary.class]||!rating.count)return YES;
    NSInteger age=[rating[@"minimumAge"]integerValue];
    if(age<0&&[rating[@"publisherPolicy"]integerValue]>=3&&[rating[@"retryAfter"]doubleValue]>0)return now>=[rating[@"retryAfter"]doubleValue];
    // Share admission between shelf selection and the actual lookup service.
    // Only old series records get the one-time publisher-policy upgrade.
    if([type isEqual:@"series"]&&age<0&&[rating[@"publisherPolicy"]integerValue]<3)return YES;
    return !(now-[rating[@"checked"]doubleValue]<(age>=0?30:1)*86400);
}
+ (NSDictionary *)recordForPublisher:(NSDictionary *)record imdb:(NSString *)imdb {
    if(![record isKindOfClass:NSDictionary.class]||![record[@"imdb"]isEqual:imdb]||![record[@"source"]isKindOfClass:NSString.class])return nil;
    NSURL *url=[NSURL URLWithString:record[@"source"]];
    if(![url.scheme isEqual:@"https"]||![@[@"www.disneyplus.com",@"www.paramountplus.com",@"tv.apple.com"]containsObject:url.host])return nil;
    NSString *label=[record[@"label"]isKindOfClass:NSString.class]?record[@"label"]:nil;if(!label.length)return nil;
    NSDictionary *ages=@{@"TV-Y":@0,@"TV-G":@0,@"TV-Y7":@7,@"TV-Y7-FV":@7,@"TV-PG":@10,@"TV-14":@14,@"TV-MA":@18};NSNumber *age=ages[label];
    // A bare PG label is ambiguous across countries. Only use the verified US
    // movie listing, with explicit provenance, and our existing film age policy.
    if(!age&&[record[@"type"]isEqual:@"movie"]&&[record[@"region"]isEqual:@"US"]&&[url.host isEqual:@"tv.apple.com"]&&[url.path hasPrefix:@"/us/movie/"]&&url.path.pathComponents.count>=5){
        age=@{@"G":@0,@"PG":@10,@"PG-13":@13,@"R":@17,@"NC-17":@18}[label];
    }
    if(!age)return nil;
    return @{@"minimumAge":age,@"label":record[@"label"],@"source":record[@"source"],@"checked":record[@"checked"]?:@0};
}
+ (NSDictionary *)recordForEntity:(NSDictionary *)entity imdb:(NSString *)imdb {
    if(![entity isKindOfClass:NSDictionary.class]||![entity[@"claims"]isKindOfClass:NSDictionary.class])return nil;
    NSDictionary *claims=entity[@"claims"];BOOL match=NO;
    for(id s in Rows(claims[@"P345"]))if([s isKindOfClass:NSDictionary.class]&&![s[@"rank"]isEqual:@"deprecated"]&&[Value(s)isEqual:imdb])match=YES;
    if(!match)return nil;
    NSDictionary *map=@{@"Q18665330":@[@0,@"MPA G"],@"Q18665334":@[@10,@"MPA PG"],@"Q18665339":@[@13,@"MPA PG-13"],@"Q18665344":@[@17,@"MPA R"],@"Q18665349":@[@18,@"MPA NC-17"],@"Q4557532":@[@18,@"BBFC 18"],@"Q23301853":@[@0,@"BBFC U"],@"Q23301854":@[@8,@"BBFC PG"],@"Q23301855":@[@12,@"BBFC 12A"],@"Q23301856":@[@12,@"BBFC 12"],@"Q4550895":@[@15,@"BBFC 15"]};
    NSInteger age=-1;NSMutableArray *labels=[NSMutableArray new];BOOL unknown=NO;
    for(NSString *prop in @[@"P1657",@"P2629"])for(id s in Rows(claims[prop])){
        if(![s isKindOfClass:NSDictionary.class]){unknown=YES;continue;}
        if([s[@"rank"]isEqual:@"deprecated"])continue;id raw=Value(s);NSString *qid=[raw isKindOfClass:NSDictionary.class]?raw[@"id"]:nil;NSArray *r=qid?map[qid]:nil;
        if(!r){unknown=YES;continue;}age=MAX(age,[r[0]integerValue]);if(![labels containsObject:r[1]])[labels addObject:r[1]];
    }
    if(unknown)age=-1;
    return @{@"minimumAge":@(age),@"label":[labels componentsJoinedByString:@" · "],@"source":[@"https://www.wikidata.org/wiki/" stringByAppendingString:[entity[@"id"]isKindOfClass:NSString.class]?entity[@"id"]:@""],@"checked":@([NSDate date].timeIntervalSince1970)};
}
+ (BOOL)allows:(NSDictionary *)rating age:(NSInteger)age {
    if(age==-1)return YES;if(![rating isKindOfClass:NSDictionary.class])return NO;if(age<0||age>18||![rating[@"minimumAge"]isKindOfClass:NSNumber.class])return NO;
    NSInteger min=[rating[@"minimumAge"]integerValue];return min>=0&&min<=age;
}
@end
