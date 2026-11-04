#import "RWAvailability.h"
#import "RWSourcePolicy.h"
#include <time.h>
static BOOL Fresh(id value,double ttl,double now){double t=[value respondsToSelector:@selector(doubleValue)]?[value doubleValue]:0;return t>0&&now>=t&&now-t<ttl;}
static NSInteger ReleaseYear(NSDictionary *meta){
    for(NSString *key in @[@"releaseInfo",@"year"]){id value=meta[key];NSString *text=[value isKindOfClass:NSString.class]?value:[value isKindOfClass:NSNumber.class]?[value stringValue]:@"";
        text=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if([text rangeOfString:@"^[12][0-9]{3}(?:\\s*[-–]\\s*(?:[12][0-9]{3})?)?$" options:NSRegularExpressionSearch].location==NSNotFound)continue;
        NSInteger year=text.integerValue;if(year>=1800&&year<=2200)return year;
    }return 0;
}
@implementation RWAvailability
+ (NSDictionary *)observe:(NSArray *)sources complete:(BOOL)complete error:(NSString *)error now:(double)now {
    return [self observe:sources complete:complete error:error quality:0 now:now];
}
+ (NSDictionary *)observe:(NSArray *)sources complete:(BOOL)complete error:(NSString *)error quality:(NSInteger)quality now:(double)now {
    NSUInteger eligible=0,camera=0;for(id source in sources){if(![source isKindOfClass:NSDictionary.class])continue;NSDictionary *result=[RWSourcePolicy evaluate:source quality:quality freeBytes:0];eligible+=[result[@"eligible"]boolValue];camera+=[result[@"rejection"]isEqual:@"Camera recording or unfinished release"];}
    return [self observeAnalysis:@{@"compatible":@(eligible),@"camera":@(camera),@"listings":@(sources.count)} complete:complete error:error quality:quality now:now];
}
+ (NSDictionary *)observeAnalysis:(NSDictionary *)analysis complete:(BOOL)complete error:(NSString *)error quality:(NSInteger)quality now:(double)now {
    NSUInteger eligible=[analysis[@"compatible"]unsignedIntegerValue],camera=[analysis[@"camera"]unsignedIntegerValue],count=[analysis[@"listings"]unsignedIntegerValue];
    NSString *state=eligible?@"candidates":complete&&!error.length?@"waiting":@"unknown";
    NSString *reason=eligible?@"":error.length?@"Lookup unavailable":count&&camera==count?@"No finished release found":count?@"No iPad-compatible version found":@"No playback sources found";
    return @{@"state":state,@"reason":reason,@"checked":@(now),@"listings":@(count),@"compatible":@(eligible),@"quality":@(quality),@"policy":@34};
}
+ (BOOL)futureRelease:(NSDictionary *)meta now:(double)now {
    time_t current=(time_t)now;struct tm today;gmtime_r(&current,&today);
    NSInteger currentYear=today.tm_year+1900;
    NSString *date=[meta[@"released"]isKindOfClass:NSString.class]?meta[@"released"]:@"";
    // A valid day is more precise than a year/range. Without one, a known
    // future start year is enough to classify Upcoming, never to claim ready.
    if(date.length<10||[date characterAtIndex:4]!='-'||[date characterAtIndex:7]!='-')return ReleaseYear(meta)>currentYear;
    const char *raw=[[date substringToIndex:10]UTF8String];for(int i=0;i<10;i++)if(i!=4&&i!=7&&(raw[i]<'0'||raw[i]>'9'))return ReleaseYear(meta)>currentYear;
    int y=0,m=0,d=0;if(sscanf(raw,"%4d-%2d-%2d",&y,&m,&d)!=3||y<1800||y>2200||m<1||m>12||d<1||d>31)return ReleaseYear(meta)>currentYear;
    int days[]={31,28,31,30,31,30,31,31,30,31,30,31};if(y%4==0&&(y%100!=0||y%400==0))days[1]=29;if(d>days[m-1])return ReleaseYear(meta)>currentYear;
    return y*10000+m*100+d>(today.tm_year+1900)*10000+(today.tm_mon+1)*100+today.tm_mday;
}
+ (NSDictionary *)presentation:(NSDictionary *)meta observation:(NSDictionary *)observation now:(double)now {
    return [self presentation:meta observation:observation quality:0 now:now];
}
+ (NSDictionary *)presentation:(NSDictionary *)meta observation:(NSDictionary *)observation quality:(NSInteger)quality now:(double)now {
    BOOL same=[observation[@"policy"]integerValue]==34&&[observation[@"quality"]integerValue]==quality;
    NSString *raw=observation[@"state"],*state=@"unknown",*label=@"";
    // Discovery caches a positive listing for one day. It does not cache a
    // ready-to-play claim: readiness below still expires after five minutes.
    // The player independently refreshes its source list when Play is pressed.
    double listingTTL=[raw isEqual:@"candidates"]?86400:[raw isEqual:@"waiting"]?3600:180;
    if(same&&Fresh(observation[@"checked"],listingTTL,now))state=raw?:@"unknown";
    BOOL ready=same&&Fresh(observation[@"ready_at"],300,now)&&[observation[@"ready_source"]length]&&[observation[@"failed_at"]doubleValue]<[observation[@"ready_at"]doubleValue];
    if(ready)state=@"ready";
    // Re-reading an index is not evidence that a failed stream recovered.
    // Keep failed titles out of promotion for a day. A successful playback can
    // recover immediately; after the cooldown require a genuinely later lookup.
    double failure=[observation[@"unready_at"]doubleValue];
    BOOL blocked=same&&failure>0&&failure>=[observation[@"ready_at"]doubleValue]&&
        (now<failure+86400||[observation[@"checked"]doubleValue]<failure+86400);
    if(blocked)state=@"unknown";
    if(same&&[observation[@"offline_valid"]boolValue]&&[observation[@"offline_at"]doubleValue]>[observation[@"failed_at"]doubleValue])state=@"offline";
    // Calendar metadata alone never establishes playback. Future releases are
    // excluded even when an index has pre-release or incorrectly dated listings.
    if([self futureRelease:meta now:now])state=@"upcoming";
    if([state isEqual:@"waiting"])label=@"Waiting for availability";
    if([state isEqual:@"upcoming"])label=@"Coming soon";
    BOOL playable=[state isEqual:@"ready"]||[state isEqual:@"offline"];BOOL discovery=[state isEqual:@"candidates"]||playable;
    return @{@"state":state,@"label":label,@"watch_instead_of_play":@([state isEqual:@"waiting"]||[state isEqual:@"upcoming"]),@"discovery_eligible":@(discovery),@"hero_eligible":@(playable),@"retry_after":@(blocked?failure+86400:0),@"checked":same?(observation[@"checked"]?:@0):@0,@"listing_fresh":@(same&&Fresh(observation[@"checked"],180,now))};
}
+ (NSDictionary *)ready:(NSDictionary *)observation sourceKey:(NSString *)sourceKey quality:(NSInteger)quality now:(double)now {
    NSMutableDictionary *value=[observation mutableCopy]?:[NSMutableDictionary new];
    if(!sourceKey.length)return value;
    value[@"quality"]=@(quality);value[@"policy"]=@34;value[@"ready_at"]=@(now);value[@"ready_source"]=sourceKey;
    return value;
}
+ (NSDictionary *)failed:(NSDictionary *)observation sourceKey:(NSString *)sourceKey now:(double)now {
    NSMutableDictionary *value=[observation mutableCopy]?:[NSMutableDictionary new];
    if(!sourceKey.length||[sourceKey isEqual:value[@"ready_source"]])value[@"failed_at"]=@(now);
    if(!sourceKey.length)value[@"unready_at"]=@(now);
    return value;
}
+ (BOOL)newOptions:(NSDictionary *)before after:(NSDictionary *)after {
    return [before[@"state"]isEqual:@"waiting"]&&[after[@"state"]isEqual:@"candidates"];
}
@end
