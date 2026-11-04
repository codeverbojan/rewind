#import "RWHomeRailPolicy.h"
#import "RWWorldCatalog.h"
#import "RWHomeCategoryPolicy.h"
#import "RWRecommendationPolicy.h"
#import "RWDiscoveryMetadataPolicy.h"
#import "RWAvailability.h"
#import "RWRatingPolicy.h"
#include <math.h>
static double RailNumber(id value){
    double number=0;if([value isKindOfClass:NSNumber.class])number=[value doubleValue];
    else if([value isKindOfClass:NSString.class]){NSScanner *scan=[NSScanner scannerWithString:value];scan.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];if(![scan scanDouble:&number]||!scan.isAtEnd)return 0;}
    return isfinite(number)&&number>0?number:0;
}
static NSDictionary *CatalogMap(id value){return [value isKindOfClass:NSDictionary.class]?value:@{};}
static NSUInteger CatalogInteger(id value,NSUInteger limit){if(![value isKindOfClass:NSNumber.class])return 0;double n=[value doubleValue];return isfinite(n)&&n>=0&&n<=limit&&floor(n)==n?(NSUInteger)n:0;}
static NSUInteger LocalPages(NSDictionary *cursor){
    if(cursor[@"localOnlyPages"])return CatalogInteger(cursor[@"localOnlyPages"],2);
    // Legacy rows with repeated local pages and no catalog offset were starved.
    return !cursor[@"catalogPolicy"]&&!cursor[@"skip"]?MIN((NSUInteger)2,CatalogInteger(cursor[@"page"],1000000)):0;
}
static double CatalogEnd(id value,double now){if(![value isKindOfClass:NSNumber.class])return 0;double n=[value doubleValue];return isfinite(n)&&n>0&&n<=now?n:0;}
// Audience evidence orders research only; it never grants an age rating.
// Broad Family includes dramas for grown-ups. Prefer explicit children’s titles,
// then family cartoons, then other animation before spending slots on those dramas.
static NSUInteger FamilyAudienceRank(NSDictionary *meta){
    static NSSet *children,*families,*animation;static dispatch_once_t once;dispatch_once(&once,^{
        children=[NSSet setWithArray:@[@"kids",@"children",@"children's film",@"children's television series",@"children's television program",@"children's television programme",@"children's animated series",@"children's animation",@"children's comedy",@"children's fiction"]];
        families=[NSSet setWithArray:@[@"family",@"family film",@"family comedy",@"family television series"]];
        animation=[NSSet setWithArray:@[@"animation",@"animated",@"cartoon",@"anime",@"animated television series",@"animated film",@"animated cartoon"]];
    });
    NSMutableArray *names=[NSMutableArray new];for(id g in [meta[@"genres"]isKindOfClass:NSArray.class]?meta[@"genres"]:@[])if([g isKindOfClass:NSString.class])[names addObject:g];
    id genres=CatalogMap(meta[@"discovery"])[@"genres"];for(id g in [genres isKindOfClass:NSArray.class]?genres:@[])if([CatalogMap(g)[@"name"]isKindOfClass:NSString.class])[names addObject:g[@"name"]];
    BOOL family=NO,animated=NO,documentary=NO;
    for(NSString *name in names){NSString *key=[[[name lowercaseString]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]stringByReplacingOccurrencesOfString:@"’" withString:@"'"];
        if([children containsObject:key])return 0;family|=[families containsObject:key];animated|=[animation containsObject:key];documentary|=[@[@"documentary",@"documentary television series",@"nature documentary"]containsObject:key];
    }
    return animated&&!documentary?(family?1:2):3;
}
static NSDictionary *CatalogPage(NSArray *providers,NSDictionary *input,double now){
    input=CatalogMap(input);NSMutableDictionary *states=[NSMutableDictionary new];BOOL modern=[input[@"catalogPolicy"]isEqual:@1],legacy=input[@"catalogPolicy"]==nil;
    NSDictionary *raw=modern?CatalogMap(input[@"catalogs"]):@{};
    for(NSUInteger i=0;i<providers.count;i++){
        NSString *key=providers[i][@"key"];NSDictionary *old=modern?CatalogMap(raw[key]):(legacy&&i==0?input:@{});
        NSUInteger skip=CatalogInteger(old[@"skip"],10100);double end=CatalogEnd(old[@"exhaustedAt"],now);
        if(end>0&&now-end>=21600){skip=0;end=0;}
        if(skip>10000&&!end)end=now;
        double failed=CatalogEnd(old[@"failedAt"],now);
        NSMutableDictionary *state=[@{@"skip":@(skip)}mutableCopy];if(end>0)state[@"exhaustedAt"]=@(end);
        if(!end&&failed>0&&now-failed<60)state[@"failedAt"]=@(failed);
        if([providers[i][@"sort"]isEqual:@"World Cinema"]&&skip){NSDictionary *continuation=RWWorldCursor(old[@"continuation"]);if(continuation.count&&[continuation[@"sroffset"]unsignedIntegerValue]==skip)state[@"continuation"]=continuation;else state[@"skip"]=@0;}
        states[key]=state;
    }
    NSUInteger turn=modern?CatalogInteger(input[@"nextCatalog"],providers.count?providers.count-1:0):0;
    NSMutableDictionary *cursor=[@{@"page":@(CatalogInteger(input[@"page"],1000000)),@"skip":@(CatalogInteger(input[@"skip"],10100)),@"catalogPolicy":@1,@"catalogs":states,@"nextCatalog":@(turn)}mutableCopy];
    if(LocalPages(input))cursor[@"localOnlyPages"]=@(LocalPages(input));
    NSMutableDictionary *page=[@{@"cursor":cursor,@"providers":providers}mutableCopy];
    NSDictionary *deferred=nil;NSUInteger deferredIndex=0;double earliestRetry=0;
    for(NSUInteger delta=0;delta<providers.count;delta++){
        NSUInteger index=(turn+delta)%providers.count;NSDictionary *provider=providers[index],*state=states[provider[@"key"]];
        if(state[@"exhaustedAt"])continue;
        NSMutableDictionary *request=[provider mutableCopy];request[@"skip"]=state[@"skip"];if(state[@"continuation"])request[@"continuation"]=state[@"continuation"];
        double failed=[state[@"failedAt"]doubleValue];if(failed>0){double retry=failed+60;if(!earliestRetry||retry<earliestRetry){deferred=request;deferredIndex=index;earliestRetry=retry;}continue;}
        page[@"request"]=request;page[@"index"]=@(index);return page;
    }
    // A temporary outage is still an unfinished catalog. Keep its exact
    // request for retry, but don't issue it repeatedly during the cooldown.
    if(deferred){page[@"request"]=deferred;page[@"index"]=@(deferredIndex);page[@"deferred"]=@YES;page[@"retryAt"]=@(earliestRetry);return page;}
    double earliest=0;for(NSDictionary *state in states.allValues){double at=[state[@"exhaustedAt"]doubleValue];if(at>0&&(!earliest||at<earliest))earliest=at;}
    if(earliest>0)cursor[@"exhaustedAt"]=@(earliest);return page;
}
@implementation RWHomeRailPolicy
+ (NSArray *)metadataCandidates:(NSArray *)items row:(NSDictionary *)row excluding:(NSSet *)excluded metadata:(NSDictionary *)metadata preferences:(NSDictionary *)preferences now:(double)now {
    NSDictionary *prefs=[RWDiscoveryMetadataPolicy preferences:preferences];BOOL world=[row[@"recipe"]isEqual:@"world"];NSMutableArray *out=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];NSUInteger read=0;
    if(world&&![prefs[@"worldCinema"]boolValue])return @[];
    for(NSDictionary *m in items){if(read++==500)break;NSString *key=m[@"id"];if(![key isKindOfClass:NSString.class]||[seen containsObject:key]||[excluded containsObject:key]||![m[@"type"]isEqual:row[@"mediaType"]]||![RWRecommendationPolicy homePendingEligible:m now:now])continue;[seen addObject:key];
        if([row[@"recipe"]isEqual:@"category"]&&![RWHomeCategoryPolicy matches:m category:row])continue;
        NSDictionary *record=CatalogMap(metadata[key]?:m[@"discovery"]);NSMutableDictionary *title=[m mutableCopy];title[@"discovery"]=record;
        if([RWDiscoveryMetadataPolicy permits:title preferences:prefs world:world])continue;
        NSString *language=[RWDiscoveryMetadataPolicy languageGroup:record];
        if((world&&[language isEqual:@"english"])||(!world&&[prefs[@"languageMode"]isEqual:@"english_first"]&&[language isEqual:@"world"])||([prefs[@"excludeBollywood"]boolValue]&&[record[@"industry"]isEqual:@"bollywood"]))continue;
        // A recent complete identity has already been researched. Missing
        // evidence cannot be invented or repeatedly fetched on every swipe.
        if([record[@"entityID"]length]&&now-[record[@"fetchedAt"]doubleValue]<30*86400)continue;
        [out addObject:m];
    }
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){double av=RailNumber(a[@"imdbVotes"]),bv=RailNumber(b[@"imdbVotes"]);if(av!=bv)return av>bv?NSOrderedAscending:NSOrderedDescending;double ar=RailNumber(a[@"imdbRating"]),br=RailNumber(b[@"imdbRating"]);if(ar!=br)return ar>br?NSOrderedAscending:NSOrderedDescending;return [a[@"id"]compare:b[@"id"]];}];
    return out.count>4?[out subarrayWithRange:NSMakeRange(0,4)]:out;
}
+ (NSArray *)ratingCandidates:(NSArray *)items row:(NSDictionary *)row excluding:(NSSet *)excluded rating:(NSDictionary *(^)(NSString *))rating now:(double)now {
    return [self ratingCandidates:items row:row excluding:excluded metadata:@{} preferences:@{} rating:rating now:now];
}
+ (NSArray *)ratingCandidates:(NSArray *)items row:(NSDictionary *)row excluding:(NSSet *)excluded metadata:(NSDictionary *)metadata preferences:(NSDictionary *)preferences rating:(NSDictionary *(^)(NSString *))rating now:(double)now {
    NSMutableArray *eligible=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];NSMutableDictionary *languageRanks=[NSMutableDictionary new],*familyRanks=[NSMutableDictionary new];BOOL world=[row[@"recipe"]isEqual:@"world"];NSDictionary *prefs=[RWDiscoveryMetadataPolicy preferences:preferences];if(world&&![prefs[@"worldCinema"]boolValue])return @[];
    for(NSDictionary *m in items){NSString *key=m[@"id"];if(![key isKindOfClass:NSString.class]||[seen containsObject:key]||[excluded containsObject:key]||![m[@"type"]isEqual:row[@"mediaType"]])continue;[seen addObject:key];
        if(![RWRecommendationPolicy homePendingEligible:m now:now])continue;
        if([row[@"recipe"]isEqual:@"category"]&&![RWHomeCategoryPolicy matches:m category:row])continue;
        NSMutableDictionary *audience=[m mutableCopy];if([metadata[key]isKindOfClass:NSDictionary.class])audience[@"discovery"]=metadata[key];if(![RWDiscoveryMetadataPolicy isFamilyTitle:audience])continue;
        NSDictionary *r=rating(key);
        // Match RWRatings' negative-cache admission: only legacy series can
        // retry immediately for the new publisher mapping. A recent unknown
        // film cannot consume a slot which the lookup service will skip.
        if((r&&[r[@"minimumAge"]integerValue]>=0)||![RWRatingPolicy needsLookup:r type:m[@"type"] now:now])continue;
        if(world){NSDictionary *record=[metadata[key]isKindOfClass:NSDictionary.class]?metadata[key]:[m[@"discovery"]isKindOfClass:NSDictionary.class]?m[@"discovery"]:@{};NSString *group=[RWDiscoveryMetadataPolicy languageGroup:record];
            if([group isEqual:@"english"]||([prefs[@"excludeBollywood"]boolValue]&&[record[@"industry"]isEqual:@"bollywood"]))continue;
            double value=RailNumber(m[@"imdbRating"]);if(value>=1&&value<=10&&value<[prefs[@"worldMinRating"]doubleValue])continue;
            // Unknown language remains a possible future match. Confirmed
            // international films get the scarce classification slots first.
            languageRanks[key]=@([group isEqual:@"world"]?0:1);
        }
        if(!world&&[prefs[@"languageMode"]isEqual:@"english_first"]){NSString *group=[RWDiscoveryMetadataPolicy languageGroup:CatalogMap(audience[@"discovery"])];languageRanks[key]=@([group isEqual:@"english"]?0:[group isEqual:@"world"]?2:1);}
        familyRanks[key]=@(FamilyAudienceRank(audience));[eligible addObject:m];
    }
    // Spend the existing four-title classification allowance on relevant,
    // released titles. Input group order must not keep upcoming titles first.
    [eligible sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){
        if(world){NSComparisonResult language=[languageRanks[a[@"id"]]compare:languageRanks[b[@"id"]]];if(language!=NSOrderedSame)return language;}
        NSComparisonResult family=[familyRanks[a[@"id"]]compare:familyRanks[b[@"id"]]];if(family!=NSOrderedSame)return family;
        if(!world&&[prefs[@"languageMode"]isEqual:@"english_first"]){NSComparisonResult language=[languageRanks[a[@"id"]]compare:languageRanks[b[@"id"]]];if(language!=NSOrderedSame)return language;}
        double av=RailNumber(a[@"imdbVotes"]),bv=RailNumber(b[@"imdbVotes"]);if(av!=bv)return av>bv?NSOrderedAscending:NSOrderedDescending;
        double ar=RailNumber(a[@"imdbRating"]),br=RailNumber(b[@"imdbRating"]);if(ar!=br)return ar>br?NSOrderedAscending:NSOrderedDescending;
        return [a[@"id"]compare:b[@"id"]];
    }];return eligible.count>4?[eligible subarrayWithRange:NSMakeRange(0,4)]:eligible;
}
+ (NSArray *)rank:(NSArray *)items row:(NSDictionary *)row profile:(NSDictionary *)profile excluding:(NSSet *)excluded available:(BOOL)available now:(double)now {
    NSString *recipe=row[@"recipe"]?:@"for-you";NSInteger year=[[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian]component:NSCalendarUnitYear fromDate:[NSDate dateWithTimeIntervalSince1970:now]];
    NSMutableArray *pool=[NSMutableArray new];NSDictionary *anchor=row[@"anchor"];
    for(NSDictionary *m in items){if(![m[@"type"]isEqual:row[@"mediaType"]]||[excluded containsObject:m[@"id"]]||![RWRecommendationPolicy homeQualityEligible:m])continue;
        if([recipe isEqual:@"category"]&&![RWHomeCategoryPolicy matches:m category:row])continue;
        NSInteger released=[m[@"releaseInfo"]integerValue];if([recipe isEqual:@"new"]&&(released<year-1||released>year))continue;if([recipe isEqual:@"older"]&&(released<1900||released>year-10))continue;
        if([recipe isEqual:@"mood"]&&(![row[@"mood"]length]||![[RWDiscoveryMetadataPolicy moods:m]containsObject:row[@"mood"]]))continue;
        if([recipe isEqual:@"because"]&&![anchor[@"id"]length])continue;[pool addObject:m];
    }
    NSArray *ranked=[RWRecommendationPolicy rank:pool current:[recipe isEqual:@"because"]?anchor:nil profile:profile world:[recipe isEqual:@"world"] requireAvailability:available now:now limit:available?12:4];
    if(![recipe isEqual:@"world"])return ranked;NSMutableArray *cards=[NSMutableArray new];
    for(NSDictionary *m in ranked){NSMutableDictionary *card=[m mutableCopy];card[@"showLanguage"]=@YES;[cards addObject:card];}return cards;
}
+ (NSDictionary *)provider:(NSDictionary *)row restricted:(BOOL)restricted {
    NSString *recipe=row[@"recipe"]?:@"for-you";
    // Catalog pagination is independent of local ranking. Filter the returned
    // page using this same recipe; a filtered empty page is not the endpoint.
    return @{@"type":row[@"mediaType"]?:@"movie",@"sort":[recipe isEqual:@"new"]?@"Newest":@"Top rated",@"genre":[recipe isEqual:@"category"]?(row[@"providerGenre"]?:@""):(restricted?@"Family":@"")};
}
+ (NSArray *)providers:(NSDictionary *)row restricted:(BOOL)restricted {
    row=CatalogMap(row);
    if(![@[@"movie",@"series"]containsObject:row[@"mediaType"]])return @[];
    if(!restricted&&[row[@"recipe"]isEqual:@"world"]&&[row[@"mediaType"]isEqual:@"movie"])return @[@{@"type":@"movie",@"sort":@"World Cinema",@"genre":@"",@"key":@"movie|World Cinema|"}];
    NSDictionary *base=[self provider:row restricted:restricted];NSMutableArray *choices=[NSMutableArray new];
    // A Kids theme should first discover family series, then apply its actual
    // genre predicate. Keep both original catalogs as independent fallbacks.
    if(restricted&&[row[@"recipe"]isEqual:@"category"]&&[row[@"mediaType"]isEqual:@"series"]&&![base[@"genre"]isEqual:@"Family"]){
        for(NSString *sort in @[@"Top rated",@"Popular"])[choices addObject:@{@"type":@"series",@"sort":sort,@"genre":@"Family"}];
    }
    [choices addObject:base];
    if(![base[@"sort"]isEqual:@"Newest"]){
        NSMutableDictionary *popular=[base mutableCopy];popular[@"sort"]=@"Popular";[choices addObject:popular];
        if(restricted&&![row[@"recipe"]isEqual:@"category"]){NSMutableDictionary *animation=[popular mutableCopy];animation[@"genre"]=@"Animation";[choices addObject:animation];}
    }
    NSMutableArray *result=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(NSDictionary *choice in choices){NSMutableDictionary *provider=[choice mutableCopy];NSString *key=[NSString stringWithFormat:@"%@|%@|%@",choice[@"type"],choice[@"sort"],choice[@"genre"]];if([seen containsObject:key])continue;[seen addObject:key];provider[@"key"]=key;[result addObject:provider];}
    return result;
}
+ (NSDictionary *)cursorAfterLocalPage:(NSDictionary *)input {
    NSDictionary *old=CatalogMap(input);NSMutableDictionary *next=[old mutableCopy];
    next[@"page"]=@(MIN((NSUInteger)1000000,CatalogInteger(old[@"page"],1000000)+1));
    next[@"localOnlyPages"]=@(MIN((NSUInteger)2,LocalPages(old)+1));return next;
}
+ (BOOL)shouldBrowseBeforeCheckingLocal:(NSDictionary *)row cursor:(NSDictionary *)cursor restricted:(BOOL)restricted now:(double)now {
    if(LocalPages(CatalogMap(cursor))<2)return NO;
    NSDictionary *page=[self catalogPage:row cursor:cursor restricted:restricted now:now];
    return page[@"request"]!=nil&&![page[@"deferred"]boolValue];
}
+ (NSDictionary *)catalogPage:(NSDictionary *)row cursor:(NSDictionary *)cursor restricted:(BOOL)restricted now:(double)now {
    if(!isfinite(now)||now<=0)return @{@"cursor":@{},@"providers":@[]};
    cursor=CatalogMap(cursor);
    if(!restricted&&[row[@"recipe"]isEqual:@"world"]&&!CatalogMap(cursor[@"catalogs"])[@"movie|World Cinema|"])cursor=@{@"page":@(CatalogInteger(cursor[@"page"],1000000))};
    // Legacy single-catalog offsets belong to the old genre, not the newly
    // inserted Family catalog. Modern keyed offsets already keep identity.
    NSDictionary *base=[self provider:row restricted:restricted];
    if(!cursor[@"catalogPolicy"]&&(cursor[@"skip"]||cursor[@"exhaustedAt"])&&restricted&&[row[@"recipe"]isEqual:@"category"]&&[row[@"mediaType"]isEqual:@"series"]&&![base[@"genre"]isEqual:@"Family"]){
        NSMutableDictionary *m=[cursor mutableCopy];NSString *key=[NSString stringWithFormat:@"%@|%@|%@",base[@"type"],base[@"sort"],base[@"genre"]];m[@"catalogPolicy"]=@1;m[@"nextCatalog"]=@0;m[@"catalogs"]=@{key:cursor};cursor=m;
    }
    return CatalogPage([self providers:row restricted:restricted],cursor,now);
}
+ (NSDictionary *)advanceCatalogPage:(NSDictionary *)page received:(NSUInteger)count now:(double)now {
    NSArray *providers=page[@"providers"];NSDictionary *request=page[@"request"],*old=CatalogMap(page[@"cursor"]);
    if(![providers isKindOfClass:NSArray.class]||!providers.count||!request||count>100||!isfinite(now)||now<=0)return old;
    NSUInteger index=CatalogInteger(page[@"index"],providers.count-1);NSString *key=request[@"key"];
    if(![providers[index][@"key"]isEqual:key])return old;
    NSMutableDictionary *cursor=[old mutableCopy],*states=[CatalogMap(old[@"catalogs"])mutableCopy],*state=[CatalogMap(states[key])mutableCopy];
    NSUInteger skip=CatalogInteger(request[@"skip"],10000);state[@"skip"]=@(skip+count);
    [state removeObjectForKey:@"failedAt"];
    if(!count||skip+count>10000)state[@"exhaustedAt"]=@(now);else [state removeObjectForKey:@"exhaustedAt"];
    states[key]=state;cursor[@"localOnlyPages"]=@0;cursor[@"catalogs"]=states;cursor[@"skip"]=state[@"skip"];cursor[@"nextCatalog"]=@((index+1)%providers.count);
    return CatalogPage(providers,cursor,now)[@"cursor"];
}
+ (NSDictionary *)advanceWorldPage:(NSDictionary *)page continuation:(NSDictionary *)continuation now:(double)now {
    NSDictionary *request=CatalogMap(page[@"request"]),*old=CatalogMap(page[@"cursor"]),*next=RWWorldCursor(continuation);NSString *key=request[@"key"];
    if(![request[@"sort"]isEqual:@"World Cinema"]||!next||!isfinite(now)||now<=0)return nil;
    NSUInteger before=[request[@"skip"]unsignedIntegerValue],after=[next[@"sroffset"]unsignedIntegerValue];
    if(next.count&&(after<=before||after>before+8))return nil;
    NSMutableDictionary *cursor=[old mutableCopy],*states=[CatalogMap(old[@"catalogs"])mutableCopy],*state=[CatalogMap(states[key])mutableCopy];
    [state removeObjectForKey:@"failedAt"];
    if(next.count){state[@"skip"]=@(after);state[@"continuation"]=next;[state removeObjectForKey:@"exhaustedAt"];}else state[@"exhaustedAt"]=@(now);
    states[key]=state;cursor[@"catalogs"]=states;cursor[@"skip"]=state[@"skip"]?:@0;cursor[@"localOnlyPages"]=@0;cursor[@"nextCatalog"]=@0;
    return CatalogPage(page[@"providers"],cursor,now)[@"cursor"];
}
+ (NSDictionary *)deferCatalogPage:(NSDictionary *)page now:(double)now {
    NSArray *providers=page[@"providers"];NSDictionary *request=page[@"request"],*old=CatalogMap(page[@"cursor"]);
    if(![providers isKindOfClass:NSArray.class]||!providers.count||!request||!isfinite(now)||now<=0)return old;
    NSUInteger index=CatalogInteger(page[@"index"],providers.count-1);NSString *key=request[@"key"];
    if(![providers[index][@"key"]isEqual:key])return old;
    NSMutableDictionary *cursor=[old mutableCopy],*states=[CatalogMap(old[@"catalogs"])mutableCopy],*state=[CatalogMap(states[key])mutableCopy];
    state[@"failedAt"]=@(now);states[key]=state;cursor[@"catalogs"]=states;cursor[@"nextCatalog"]=@((index+1)%providers.count);
    return CatalogPage(providers,cursor,now)[@"cursor"];
}

@end
