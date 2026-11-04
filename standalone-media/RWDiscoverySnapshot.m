#import "RWDiscoverySnapshot.h"
#import "RWMediaIdentity.h"
#import "RWDiscoveryCatalog.h"
#import "RWDiscoveryMetadataPolicy.h"
#import "RWDiscoveryEpisodes.h"
#import "RWRatingPolicy.h"
#import "RWAvailability.h"
#import "RWRecommendationSignals.h"
#import "RWViewingSignals.h"
static NSDictionary *D(id value){return [value isKindOfClass:NSDictionary.class]?value:@{};}
static NSArray *A(id value){return [value isKindOfClass:NSArray.class]?value:@[];}
static NSString *S(id value){return [value isKindOfClass:NSString.class]?value:@"";}
static NSString *ID(NSDictionary *meta){return S(meta[@"id"]?:meta[@"imdb_id"]);}
static BOOL Allowed(NSDictionary *meta,NSDictionary *input,NSSet *family){
    if(![meta isKindOfClass:NSDictionary.class])return NO;
    NSInteger age=[input[@"profile"][@"maxAge"]integerValue];
    if(age<0)return YES;
    NSDictionary *cached=D(input[@"ageRatings"][@"cache"])[ID(meta)],*publisher=D(input[@"ageRatings"][@"publishers"])[ID(meta)];
    NSDictionary *rating=publisher&&(!cached||[cached[@"minimumAge"]integerValue]<[publisher[@"minimumAge"]integerValue])?publisher:cached;
    if(![RWRatingPolicy allows:rating age:age])return NO;
    NSMutableDictionary *audience=[meta mutableCopy];NSDictionary *record=D(input[@"metadata"])[ID(meta)];if(record.count)audience[@"discovery"]=record;
    if([RWDiscoveryMetadataPolicy isAdultAudience:audience])return NO;
    if([family containsObject:ID(meta)])return YES;
    return [RWDiscoveryMetadataPolicy isFamilyTitle:audience];
}
static NSSet *Family(NSDictionary *input){NSMutableSet *ids=[NSMutableSet new];for(NSDictionary *m in A(input[@"family"]))if(ID(m).length&&[RWDiscoveryMetadataPolicy isFamilyTitle:m])[ids addObject:ID(m)];return ids;}
static BOOL Identity(NSDictionary *meta,NSString *videoID){
    NSString *title=ID(meta);if(!title.length||!videoID.length)return NO;
    if([meta[@"type"]isEqual:@"movie"])return [videoID isEqual:title];
    if(![meta[@"type"]isEqual:@"series"]||![videoID hasPrefix:[title stringByAppendingString:@":"]])return NO;
    NSArray *parts=[videoID componentsSeparatedByString:@":"];if(parts.count!=3)return NO;
    NSCharacterSet *invalid=NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    return [parts[1]length]&&[parts[2]length]&&[parts[1]rangeOfCharacterFromSet:invalid].location==NSNotFound&&[parts[2]rangeOfCharacterFromSet:invalid].location==NSNotFound&&[parts[2]integerValue]>0;
}
static NSDictionary *Prepare(NSDictionary *meta,NSDictionary *input,NSDictionary *ratings,NSSet *family,RWDiscoveryEpisodes *episodes,double now){
    meta=RWNormalizeMediaIdentity(meta,D(input[@"shows"])[ID(meta)]);
    NSMutableDictionary *m=[meta mutableCopy];[m removeObjectForKey:@"videos"];
    NSDictionary *metadata=D(input[@"metadata"])[ID(meta)],*rating=ratings[ID(meta)];
    if(metadata.count)m=[[RWDiscoveryMetadataPolicy enrich:m record:metadata]mutableCopy];
    if(rating){m[@"imdbRating"]=[NSString stringWithFormat:@"%.1f",[rating[@"rating"]doubleValue]];m[@"imdbVotes"]=rating[@"votes"];}
    NSString *videoID=@"";NSDictionary *show=D(input[@"shows"])[ID(meta)]?:meta,*history=D(input[@"profile"][@"history"]);NSDate *date=[NSDate dateWithTimeIntervalSince1970:now];
    if([meta[@"type"]isEqual:@"movie"])videoID=ID(meta);
    else if(Identity(meta,S(meta[@"episodeVideoID"])))videoID=meta[@"episodeVideoID"];
    else {
        NSString *explicitID=meta[@"season"]&&meta[@"episode"]?[NSString stringWithFormat:@"%@:%@:%@",ID(meta),meta[@"season"],meta[@"episode"]]:@"";
        videoID=Identity(meta,explicitID)?explicitID:S([episodes episode:nil show:show history:history now:date][@"id"]);
    }
    NSMutableDictionary *target=[m mutableCopy];
    if([meta[@"type"]isEqual:@"series"]){NSDictionary *ep=[episodes episode:videoID show:show history:history now:date];if(ep)target[@"released"]=ep[@"released"]?:@"";if(videoID.length)m[@"episodeVideoID"]=videoID;}
    NSDictionary *observation=Identity(meta,videoID)?D(input[@"profile"][@"sourceAvailability"])[videoID]:nil;
    NSDictionary *offline=D(input[@"offline"])[videoID];NSInteger quality=[input[@"quality"]integerValue];double age=now-[input[@"offlineAt"]doubleValue];
    if(offline&&[offline[@"quality"]integerValue]==quality&&age>=0&&age<120){NSMutableDictionary *copy=[observation mutableCopy]?:[NSMutableDictionary new];copy[@"offline_valid"]=@YES;copy[@"offline_at"]=offline[@"at"];copy[@"quality"]=@(quality);copy[@"policy"]=@34;observation=copy;}
    m[@"availability"]=[RWAvailability presentation:target observation:observation quality:quality now:now];m[@"ageAllowed"]=@(Allowed(meta,input,family));return m;
}
// Ranking retains full exclusion identities, but only the 24 feedback records
// whose metadata can influence this pass. This never edits persisted state.
static NSDictionary *RankingProfile(NSDictionary *input,NSDictionary *ratings,NSSet *family,double now){
    NSDictionary *original=D(input[@"profile"]);NSMutableDictionary *profile=[NSMutableDictionary new];
    for(NSString *key in @[@"maxAge",@"hidden",@"discoveryPreferences",@"discoveryExposures"])if(original[key])profile[key]=original[key];
    NSMutableSet *rankExcluded=[NSMutableSet new],*homeExcluded=[NSMutableSet new];
    for(id raw in A(original[@"liked"])){NSDictionary *m=D(raw);if(ID(m).length&&Allowed(m,input,family))[rankExcluded addObject:ID(m)];}
    for(id key in D(original[@"history"])){NSDictionary *r=D(original[@"history"][key]),*m=D(r[@"meta"]);if(!ID(m).length||!Allowed(m,input,family))continue;
        if([RWViewingSignals meaningful:r])[rankExcluded addObject:ID(m)];
        if(![r[@"completed"]boolValue]&&[r[@"position"]doubleValue]>3)[homeExcluded addObject:ID(m)];
    }[homeExcluded unionSet:rankExcluded];profile[@"rankingExcludedIDs"]=[rankExcluded.allObjects sortedArrayUsingSelector:@selector(compare:)];profile[@"homeExcludedIDs"]=[homeExcluded.allObjects sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *liked=[NSMutableArray new],*saved=[NSMutableArray new];NSMutableDictionary *history=[NSMutableDictionary new];
    NSArray *signals=[RWRecommendationSignals select:original now:now allows:^BOOL(NSDictionary *m){return Allowed(m,input,family);}];
    for(NSDictionary *signal in signals){NSDictionary *source=signal[@"meta"];NSMutableDictionary *meta=[NSMutableDictionary new];
        for(NSString *key in @[@"id",@"imdb_id",@"name",@"type",@"genres",@"discoveryLikedAt",@"discoverySavedAt",@"technicalTest",@"releaseInfo"])if(source[key])meta[key]=source[key];
        NSDictionary *metadata=D(input[@"metadata"])[ID(source)]?:D(source[@"discovery"]);if(metadata.count)meta=[[RWDiscoveryMetadataPolicy enrich:meta record:metadata]mutableCopy];meta[@"ageAllowed"]=@YES;
        NSDictionary *rating=ratings[ID(source)];if(rating){meta[@"imdbRating"]=rating[@"rating"];meta[@"imdbVotes"]=rating[@"votes"];}
        if([signal[@"kind"]isEqual:@"liked"])[liked addObject:meta];else if([signal[@"kind"]isEqual:@"saved"])[saved addObject:meta];else{
            NSString *key=S(signal[@"recordKey"]);NSDictionary *old=D(original[@"history"][key]);NSMutableDictionary *record=[NSMutableDictionary new];
            for(NSString *field in @[@"updated",@"watchSignalVersion",@"watchSeconds",@"duration",@"completed",@"position",@"technicalTest"])if(old[field])record[field]=old[field];record[@"meta"]=meta;history[key]=record;
        }
    }profile[@"liked"]=liked;profile[@"saved"]=saved;profile[@"history"]=history;profile[@"rankingContextVersion"]=@52;return profile;
}
@implementation RWDiscoverySnapshot
+ (BOOL)matches:(NSDictionary *)snapshot profile:(NSDictionary *)profile quality:(NSInteger)quality {
    NSDictionary *prior=D(snapshot[@"profile"]);return [snapshot[@"quality"]integerValue]==quality&&[prior[@"maxAge"]integerValue]==[profile[@"maxAge"]integerValue]&&[D(prior[@"discoveryPreferences"])isEqual:D(profile[@"discoveryPreferences"])]&&[A(prior[@"hidden"])isEqual:A(profile[@"hidden"])];
}
+ (NSArray *)ratingIDs:(NSArray *)items snapshot:(NSDictionary *)snapshot includeSignals:(BOOL)includeSignals now:(double)now {
    NSMutableOrderedSet *ids=[NSMutableOrderedSet new];NSUInteger read=0;for(id raw in A(items)){if(read++==501)break;NSString *key=ID(D(raw));if(key.length)[ids addObject:key];}
    if(includeSignals){NSSet *family=Family(snapshot);for(NSDictionary *signal in [RWRecommendationSignals select:D(snapshot[@"profile"]) now:now allows:^BOOL(NSDictionary *m){return Allowed(m,snapshot,family);}])[ids addObject:ID(signal[@"meta"])];}return ids.array;
}
+ (NSDictionary *)prepareItems:(NSArray *)items snapshot:(NSDictionary *)snapshot ratings:(NSDictionary *)ratings now:(double)now {
    double began=NSProcessInfo.processInfo.systemUptime;NSSet *family=Family(snapshot);RWDiscoveryEpisodes *episodes=[RWDiscoveryEpisodes new];NSMutableArray *prepared=[NSMutableArray new];NSUInteger read=0;
    for(id raw in A(items)){if(read++==501)break;NSDictionary *m=D(raw);if(ID(m).length&&[@[@"movie",@"series"]containsObject:S(m[@"type"])]&&Allowed(m,snapshot,family))[prepared addObject:Prepare(m,snapshot,ratings,family,episodes,now)];}
    return @{@"items":prepared,@"seconds":@(NSProcessInfo.processInfo.systemUptime-began),@"off_main":@(!NSThread.isMainThread),@"episode_cache":episodes.diagnostics};
}
+ (NSArray *)filter:(NSArray *)items snapshot:(NSDictionary *)snapshot {NSSet *family=Family(snapshot);NSMutableArray *out=[NSMutableArray new];for(id raw in A(items))if([raw isKindOfClass:NSDictionary.class]&&Allowed(raw,snapshot,family))[out addObject:raw];return out;}
+ (NSArray *)pool:(NSDictionary *)snapshot {
    NSMutableArray *out=[NSMutableArray new];NSSet *family=Family(snapshot);
    NSArray *pool=[RWDiscoveryCatalog balancedPool:A(snapshot[@"groups"]) limit:500 allows:^BOOL(NSDictionary *m){return Allowed(m,snapshot,family);}];
    for(NSDictionary *m in pool){NSMutableDictionary *brief=[m mutableCopy];[brief removeObjectForKey:@"videos"];[out addObject:brief];}return out;
}
 + (NSDictionary *)prepare:(NSArray *)items snapshot:(NSDictionary *)snapshot ratings:(NSDictionary *)ratings now:(double)now {
    double began=NSProcessInfo.processInfo.systemUptime;NSMutableDictionary *result=[[self prepareItems:items snapshot:snapshot ratings:ratings now:now]mutableCopy];
    result[@"profile"]=RankingProfile(snapshot,ratings,Family(snapshot),now);result[@"seconds"]=@(NSProcessInfo.processInfo.systemUptime-began);return result;
}
@end
