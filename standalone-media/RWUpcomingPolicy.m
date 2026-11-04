#import "RWUpcomingPolicy.h"
#import "RWAvailability.h"
#import "RWDiscoveryMetadataPolicy.h"
#include <float.h>
#include <math.h>
static NSDictionary *UD(id x){return [x isKindOfClass:NSDictionary.class]?x:@{};}
static NSArray *UA(id x){return [x isKindOfClass:NSArray.class]?x:@[];}
static NSString *UT(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static NSArray *UV(NSDictionary *e,NSString *p){NSMutableArray *out=[NSMutableArray new];for(id raw in UA(UD(e[@"claims"])[p])){NSDictionary *s=UD(raw);if([s[@"rank"]isEqual:@"deprecated"])continue;id v=UD(UD(s[@"mainsnak"])[@"datavalue"])[@"value"];if(v)[out addObject:v];}return out;}
static BOOL UMatch(NSString *value,NSString *pattern){NSRange r=[value rangeOfString:pattern options:NSRegularExpressionSearch];return r.location==0&&r.length==value.length;}
@implementation RWUpcomingPolicy
+ (NSString *)day:(NSDate *)now {
    NSDateFormatter *f=[NSDateFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];f.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];f.dateFormat=@"yyyy-MM-dd";return [f stringFromDate:now];
}
+ (NSArray *)scheduleRequests:(NSDate *)now days:(NSUInteger)days {
    NSMutableArray *out=[NSMutableArray new];for(NSUInteger i=0;i<MIN(28,days);i++){
        NSString *day=[self day:[now dateByAddingTimeInterval:i*86400]];
        for(NSString *path in @[@"schedule?country=US&",@"schedule?country=GB&",@"schedule/web?"])[out addObject:[NSString stringWithFormat:@"https://api.tvmaze.com/%@date=%@",path,day]];
    }return out;
}
+ (BOOL)scheduled:(NSDictionary *)meta now:(double)now {
    NSDictionary *ep=UD(meta[@"scheduledEpisode"]);double stamp=[ep[@"airAt"]isKindOfClass:NSNumber.class]?[ep[@"airAt"]doubleValue]:0;
    return [meta[@"type"]isEqual:@"series"]&&stamp>now&&stamp<=now+29*86400&&[ep[@"id"]isEqual:[NSString stringWithFormat:@"%@:%@:%@",UT(meta[@"id"]),ep[@"season"],ep[@"episode"]]];
}
+ (NSString *)scheduleLabel:(NSDictionary *)meta {
    NSDictionary *ep=UD(meta[@"scheduledEpisode"]);if(!ep.count)return @"";
    NSDateFormatter *f=[NSDateFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];f.dateFormat=@"EEE, d MMM · HH:mm";
    return [NSString stringWithFormat:@"S%02ld E%02ld · %@",(long)[ep[@"season"]integerValue],(long)[ep[@"episode"]integerValue],[f stringFromDate:[NSDate dateWithTimeIntervalSince1970:[ep[@"airAt"]doubleValue]]]];
}
+ (NSArray *)scheduledTitles:(NSArray *)episodes now:(double)now query:(NSString *)query {
    NSDateFormatter *f=[NSDateFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];f.dateFormat=@"yyyy-MM-dd'T'HH:mm:ssZZZZZ";f.lenient=NO;
    NSMutableArray *out=[NSMutableArray new];for(id value in UA(episodes)){
        NSDictionary *ep=UD(value),*show=UD(ep[@"show"]);if(!show.count)show=UD(UD(ep[@"_embedded"])[@"show"]);
        NSString *imdb=UT(UD(show[@"externals"])[@"imdb"]),*name=UT(show[@"name"]),*kind=UT(show[@"type"]);
        if(!UMatch(imdb,@"tt[0-9]{5,12}")||!name.length||name.length>300||![@[@"Scripted",@"Animation",@"Documentary"]containsObject:kind])continue;
        NSNumber *season=ep[@"season"],*number=ep[@"number"];if(![season isKindOfClass:NSNumber.class]||![number isKindOfClass:NSNumber.class]||season.integerValue<1||season.integerValue>200||number.integerValue<1||number.integerValue>10000||season.doubleValue!=season.integerValue||number.doubleValue!=number.integerValue)continue;
        NSString *stamp=UT(ep[@"airstamp"]);if(!UMatch(stamp,@"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:[0-9]{2})"))continue;
        NSDate *air=[f dateFromString:stamp];if(!air||air.timeIntervalSince1970<=now||air.timeIntervalSince1970>now+29*86400)continue;
        NSURL *source=[NSURL URLWithString:UT(show[@"url"])];if(![source.scheme isEqual:@"https"]||![source.host isEqual:@"www.tvmaze.com"])continue;
        NSString *language=UT(show[@"language"]),*premiere=UT(show[@"premiered"]);NSMutableDictionary *m=[@{@"id":imdb,@"type":@"series",@"name":name,@"upcomingVerifiedAt":@(now),@"upcomingSource":source.absoluteString,@"scheduledQuery":query?:@"",@"scheduledEpisode":@{@"id":[NSString stringWithFormat:@"%@:%@:%@",imdb,season,number],@"season":season,@"episode":number,@"name":UT(ep[@"name"]),@"airAt":@(air.timeIntervalSince1970),@"airstamp":stamp},@"discovery":@{@"imdb":imdb,@"primaryLanguage":[language isEqual:@"English"]?@"en":language,@"languageSource":source.absoluteString,@"industry":@"television",@"source":source.absoluteString},@"genres":UA(show[@"genres"])}mutableCopy];
        if([kind isEqual:@"Animation"]&&![m[@"genres"]containsObject:@"Animation"])m[@"genres"]=[m[@"genres"]arrayByAddingObject:@"Animation"];
        // Preserve the series premiere. An upcoming episode must never turn an
        // already-released series into an unreleased title or a ready stream.
        if(UMatch(premiere,@"[0-9]{4}-[0-9]{2}-[0-9]{2}")){m[@"released"]=premiere;m[@"releaseInfo"]=[premiere substringToIndex:4];}
        NSString *poster=UT(UD(show[@"image"])[@"medium"]);NSURL *image=[NSURL URLWithString:poster];if([image.scheme isEqual:@"https"]&&[image.host isEqual:@"static.tvmaze.com"])m[@"poster"]=poster;
        [out addObject:m];
    }return [self merge:@[] incoming:out now:now];
}
+ (NSArray *)requests:(NSDate *)now {
    NSCalendar *calendar=[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];calendar.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];NSInteger year=[calendar component:NSCalendarUnitYear fromDate:now];NSMutableArray *out=[NSMutableArray new];
    // Text search finds candidates, never proves a release. Claims below do.
    for(NSString *type in @[@"Q11424|P31=Q18011172",@"Q5398426|P31=Q1259759"])for(NSInteger i=0;i<2;i++){
        NSString *query=[NSString stringWithFormat:@"%@%ld haswbstatement:P31=%@ haswbstatement:P345",i?@"":@"upcoming ",(long)(year+i),type];
        NSString *escaped=[query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"]];escaped=[escaped stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
        [out addObject:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=query&list=search&format=json&srnamespace=0&srprop=&srlimit=24&srsearch=%@",escaped]];
    }return out;
}
+ (NSArray *)titles:(NSDictionary *)entities now:(double)now {
    NSMutableArray *out=[NSMutableArray new];NSDateFormatter *date=[NSDateFormatter new];date.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];date.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];date.dateFormat=@"yyyy-MM-dd";date.lenient=NO;
    for(id raw in [UD(entities)allValues]){NSDictionary *e=UD(raw);NSString *qid=UT(e[@"id"]);if(!UMatch(qid,@"Q[1-9][0-9]*"))continue;
        NSString *type=nil;for(id v in UV(e,@"P31")){NSString *kind=UT(UD(v)[@"id"]);if([@[@"Q11424",@"Q18011172"]containsObject:kind])type=@"movie";if([@[@"Q5398426",@"Q1259759"]containsObject:kind])type=@"series";}if(!type)continue;
        NSMutableSet *imdbs=[NSMutableSet new];for(id v in UV(e,@"P345"))if(UMatch(UT(v),@"tt[0-9]{5,12}"))[imdbs addObject:v];if(imdbs.count!=1)continue;
        NSString *name=[RWDiscoveryMetadataPolicy displayName:e];if(!name.length||name.length>300)continue;
        NSString *earliest=nil,*precise=nil;BOOL invalid=NO;
        // The earliest non-deprecated release wins, including festival/other
        // regions. A later local release must not make an old film Upcoming.
        for(id v in UV(e,@"P577")){NSDictionary *value=UD(v);NSString *time=UT(value[@"time"]);NSInteger precision=[value[@"precision"]isKindOfClass:NSNumber.class]?[value[@"precision"]integerValue]:0;
            if(precision<9||time.length<11||![time hasPrefix:@"+"]){invalid=YES;break;}
            NSString *year=[time substringWithRange:NSMakeRange(1,4)],*month=[time substringWithRange:NSMakeRange(6,2)],*day=[time substringWithRange:NSMakeRange(9,2)];
            NSString *lower=[NSString stringWithFormat:@"%@-%@-%@",year,precision>=10?month:@"01",precision>=11?day:@"01"];
            NSDate *parsed=[date dateFromString:lower];if(!parsed||![[date stringFromDate:parsed]isEqual:lower]||year.integerValue<1900||year.integerValue>2200){invalid=YES;break;}
            if(!earliest||[lower compare:earliest]==NSOrderedAscending){earliest=lower;precise=precision>=11?lower:nil;}
        }if(invalid||!earliest)continue;
        NSString *imdb=imdbs.anyObject;NSMutableDictionary *m=[@{@"id":imdb,@"type":type,@"name":name,@"releaseInfo":[earliest substringToIndex:4],@"upcomingVerifiedAt":@(now),@"upcomingEntity":qid,@"upcomingSource":[@"https://www.wikidata.org/wiki/" stringByAppendingString:qid],@"discovery":[RWDiscoveryMetadataPolicy recordForEntity:e imdb:imdb labels:@{}]?:@{}}mutableCopy];
        if(precise)m[@"released"]=precise;
        if(![RWAvailability futureRelease:m now:now])continue;
        // Do not turn a coarse current-year/month date into an invented day.
        if([[date dateFromString:earliest]timeIntervalSince1970]<=now)continue;
        [out addObject:m];
    }return [self merge:@[] incoming:out now:now];
}
+ (NSArray *)orderedTitles:(NSArray *)titles {
    // Parse film dates once per title, not once per sort comparison. Schedule
    // ordering uses the absolute episode time, including time-zone offsets.
    NSDateFormatter *date=[NSDateFormatter new];date.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];date.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];date.dateFormat=@"yyyy-MM-dd";
    NSMutableArray *rows=[NSMutableArray new];for(NSDictionary *m in titles){
        double stamp=[UD(m[@"scheduledEpisode"])[@"airAt"]doubleValue];
        if(!stamp){NSString *day=UT(m[@"released"]);if(day.length>=10)day=[day substringToIndex:10];if(!day.length)day=[UT(m[@"releaseInfo"])stringByAppendingString:@"-12-31"];NSDate *parsed=[date dateFromString:day];stamp=parsed&&[[date stringFromDate:parsed]isEqual:day]?parsed.timeIntervalSince1970:DBL_MAX;}
        [rows addObject:@{@"meta":m,@"stamp":@(stamp)}];
    }
    [rows sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSComparisonResult order=[a[@"stamp"]compare:b[@"stamp"]];if(order==NSOrderedSame)order=[UT(a[@"meta"][@"name"])compare:UT(b[@"meta"][@"name"])];if(order==NSOrderedSame)order=[UT(a[@"meta"][@"id"])compare:UT(b[@"meta"][@"id"])];return order;}];
    NSMutableArray *out=[NSMutableArray new];for(NSDictionary *row in rows)[out addObject:row[@"meta"]];return out;
}
+ (NSUInteger)cachedDays:(NSDictionary *)cache now:(double)now {
    if(![cache[@"schema"]isKindOfClass:NSNumber.class]||![cache[@"days"]isKindOfClass:NSNumber.class]||![cache[@"checked"]isKindOfClass:NSNumber.class])return 0;
    if([cache[@"days"]doubleValue]<0||[cache[@"days"]doubleValue]>28||[cache[@"days"]doubleValue]!=[cache[@"days"]integerValue])return 0;
    if([cache[@"schema"]integerValue]!=RWUpcomingCacheSchema||![cache[@"day"]isEqual:[self day:[NSDate dateWithTimeIntervalSince1970:now]]])return 0;
    double checked=[cache[@"checked"]doubleValue];if(checked<=0||checked>now||now-checked>=86400)return 0;
    return MIN(28,[cache[@"days"]unsignedIntegerValue]);
}
+ (NSArray *)merge:(NSArray *)existing incoming:(NSArray *)incoming now:(double)now {
    NSMutableDictionary *byID=[NSMutableDictionary new];for(NSArray *group in @[UA(existing),UA(incoming)])for(id raw in group){NSDictionary *m=UD(raw);NSString *key=UT(m[@"id"]);double age=now-[m[@"upcomingVerifiedAt"]doubleValue];BOOL schedule=[self scheduled:m now:now];if(!UMatch(key,@"tt[0-9]{5,12}")||age<0||age>(m[@"scheduledEpisode"]?86400:7*86400)||(!schedule&&![RWAvailability futureRelease:m now:now]))continue;NSDictionary *old=byID[key];if(schedule&&[self scheduled:old now:now]&&[old[@"scheduledEpisode"][@"airAt"]doubleValue]<[m[@"scheduledEpisode"][@"airAt"]doubleValue])continue;byID[key]=m;}
    // Keep an independent bounded allowance for every UTC episode date. A
    // full early date must not crowd newly requested later dates out of the
    // cache. Valid schedules span at most30 UTC dates; together with the film
    // allowance this stays below4MiB of serialized metadata, not decoded art.
    NSMutableArray *bounded=[NSMutableArray new];NSMutableDictionary *counts=[NSMutableDictionary new],*bytes=[NSMutableDictionary new];
    for(NSDictionary *m in [self orderedTitles:byID.allValues]){
        BOOL scheduled=[self scheduled:m now:now];NSString *bucket=scheduled?[NSString stringWithFormat:@"%.0f",floor([m[@"scheduledEpisode"][@"airAt"]doubleValue]/86400)]:@"films";
        NSUInteger count=[counts[bucket]unsignedIntegerValue],used=[bytes[bucket]unsignedIntegerValue];if(count>=96)continue;
        NSData *encoded=[NSJSONSerialization dataWithJSONObject:m options:0 error:nil];if(!encoded||encoded.length+1>128*1024-used)continue;
        counts[bucket]=@(count+1);bytes[bucket]=@(used+encoded.length+1);[bounded addObject:m];
    }return bounded;
}
@end
