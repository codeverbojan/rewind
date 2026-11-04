#import "RWRecommendationPolicy.h"
#import "RWHomeCategoryPolicy.h"
#import "RWDiscoveryMetadataPolicy.h"
#import "RWViewingSignals.h"
#import "RWRecommendationSignals.h"
#import "RWAvailability.h"
#include <math.h>
#include <string.h>
static NSString *RT(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static NSArray *RA(id x){return [x isKindOfClass:NSArray.class]?x:@[];}
static NSDictionary *RD(id x){return [x isKindOfClass:NSDictionary.class]?x:@{};}
static double RN(id x){double n=[x respondsToSelector:@selector(doubleValue)]?[x doubleValue]:0;return isfinite(n)?n:0;}
static NSString *RID(NSDictionary *m){return RT(m[@"id"]?:m[@"imdb_id"]);}
static BOOL VerifiedID(NSString *key){if(key.length<2||key.length>20||[key characterAtIndex:0]!='Q'||[key characterAtIndex:1]<'1'||[key characterAtIndex:1]>'9')return NO;for(NSUInteger i=1;i<key.length;i++){unichar c=[key characterAtIndex:i];if(c<'0'||c>'9')return NO;}return YES;}
static NSSet *Features(NSDictionary *m,NSArray *moods){NSMutableSet *set=[NSMutableSet new];NSUInteger genres=0;for(id raw in RA(m[@"genres"])){NSString *genre=[RT(raw)stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(genre.length&&genre.length<=80){[set addObject:[@"g:" stringByAppendingString:genre.lowercaseString]];if(++genres==16)break;}}NSDictionary *d=RD(m[@"discovery"]);
    for(NSArray *pair in @[@[@"cast",@"c:",@24],@[@"directors",@"d:",@8],@[@"studios",@"s:",@10],@[@"themes",@"t:",@12]]){NSUInteger added=0;for(id ref in RA(d[pair[0]])){NSString *key=RT(RD(ref)[@"id"]);if(VerifiedID(key)){[set addObject:[pair[1]stringByAppendingString:key]];if(++added==[pair[2]unsignedIntegerValue])break;}}}
    for(NSString *mood in moods)[set addObject:[@"m:" stringByAppendingString:mood]];return set;
}
// Strong pointer keys preserve per-record identity without allocating an NSValue
// and wrapper dictionary on every lookup. This cache exists only for one pass.
static NSDictionary *CachedTitle(NSDictionary *m,NSMutableDictionary *cache){
    NSMapTable *records=cache[@"featureRecords"];if(!records){records=[NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory|NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsStrongMemory];cache[@"featureRecords"]=records;}
    NSDictionary *record=[records objectForKey:m];if(!record){NSArray *moods=[RWDiscoveryMetadataPolicy moods:m];record=@{@"features":Features(m,moods),@"moods":moods};[records setObject:record forKey:m];}return record;
}
static NSSet *CachedFeatures(NSDictionary *m,NSMutableDictionary *cache){
    if(!m.count){if(!cache[@"emptyFeatures"])cache[@"emptyFeatures"]=[NSSet set];return cache[@"emptyFeatures"];}
    return CachedTitle(m,cache)[@"features"];
}
static NSArray *CachedMoods(NSDictionary *m,NSMutableDictionary *cache){return m.count?CachedTitle(m,cache)[@"moods"]:@[];}
static double FeatureWeight(NSString *feature){if([feature hasPrefix:@"t:"])return 3;if([feature hasPrefix:@"d:"]||[feature hasPrefix:@"m:"])return 2;if([feature hasPrefix:@"s:"])return .5;if([feature hasPrefix:@"c:"])return .6;if([feature isEqual:@"g:drama"]||[feature isEqual:@"g:comedy"])return .5;return 1;}
typedef struct {double weight,cap;NSUInteger token;} RWFeatureValue;
@interface RWRecommendationFeatureVector : NSObject {
@public NSData *values,*tokens;NSSet *features;NSUInteger count;double total;
}
@end
@implementation RWRecommendationFeatureVector @end
static double FeatureCap(NSString *f){if([f hasPrefix:@"t:"])return 1;if([f hasPrefix:@"d:"])return .9;if([f hasPrefix:@"c:"]||[f hasPrefix:@"s:"])return .65;if([f hasPrefix:@"m:"])return .55;return [f isEqual:@"g:drama"]||[f isEqual:@"g:comedy"]?.12:.45;}
static int TokenOrder(const void *a,const void *b){NSUInteger x=*(const NSUInteger *)a,y=*(const NSUInteger *)b;return x<y?-1:x>y?1:0;}
static BOOL ContainsToken(const NSUInteger *values,NSUInteger count,NSUInteger token){NSUInteger low=0;while(low<count){NSUInteger middle=low+(count-low)/2,value=values[middle];if(value<token)low=middle+1;else if(value>token)count=middle;else return YES;}return NO;}
static RWRecommendationFeatureVector *Vector(NSSet *features,NSMutableDictionary *cache){
    NSMapTable *vectors=cache[@"vectors"];if(!vectors){vectors=[NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory|NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsStrongMemory];cache[@"vectors"]=vectors;}RWRecommendationFeatureVector *v=[vectors objectForKey:features];if(v)return v;
    NSMutableDictionary *featureIDs=cache[@"featureIDs"];if(!featureIDs){featureIDs=[NSMutableDictionary new];cache[@"featureIDs"]=featureIDs;}
    v=[RWRecommendationFeatureVector new];v->features=features;v->count=features.count;NSArray *ordered=[features.allObjects sortedArrayUsingSelector:@selector(compare:)];NSMutableData *storage=[NSMutableData dataWithLength:features.count*sizeof(RWFeatureValue)],*tokens=[NSMutableData dataWithLength:features.count*sizeof(NSUInteger)];RWFeatureValue *entries=(RWFeatureValue *)storage.mutableBytes;NSUInteger *ids=(NSUInteger *)tokens.mutableBytes,i=0;
    for(NSString *f in ordered){NSNumber *known=cache[@"featureWeights"][f],*identity=featureIDs[f];if(!identity){identity=@(featureIDs.count+1);featureIDs[f]=identity;}double w=known?known.doubleValue:FeatureWeight(f)*1.5;ids[i]=identity.unsignedIntegerValue;entries[i++]=(RWFeatureValue){w,FeatureCap(f),identity.unsignedIntegerValue};v->total+=w;}
    if(v->count>1)qsort(ids,v->count,sizeof(NSUInteger),TokenOrder);v->values=storage;v->tokens=tokens;[vectors setObject:v forKey:features];return v;
}
static double CompareVectors(RWRecommendationFeatureVector *av,RWRecommendationFeatureVector *bv,BOOL confidence){
    if(!av->count||!bv->count)return 0;if(!confidence&&(av==bv||[av->features isEqual:bv->features]))return 1;
    if(av->count>bv->count){RWRecommendationFeatureVector *swap=av;av=bv;bv=swap;}
    // Keep the exact sorted floating-point accumulation and specificity caps.
    // Callers retain vectors directly; pair comparisons do no map lookups.
    double common=0,cap=.12;const RWFeatureValue *entries=(const RWFeatureValue *)av->values.bytes;const NSUInteger *tokens=(const NSUInteger *)bv->tokens.bytes;for(NSUInteger i=0;i<av->count;i++){RWFeatureValue entry=entries[i];if(ContainsToken(tokens,bv->count,entry.token)){common+=entry.weight;if(confidence)cap=MAX(cap,entry.cap);}}
    if(confidence&&cap==.12)return 0;
    double total=av->total+bv->total-common,value=total>0?common/total:0;return confidence?MIN(value,cap):value;
}
#include "RWRecommendationInterests.inc"
static NSArray *IDs(NSDictionary *m,NSString *field){NSMutableArray *out=[NSMutableArray new];for(id ref in RA(RD(m[@"discovery"])[field])){if([field isEqual:@"franchises"]&&![RWDiscoveryMetadataPolicy isNarrativeFranchise:RD(ref)])continue;NSString *key=RT(RD(ref)[@"id"]);if(key.length)[out addObject:key];}return out;}
static NSArray *Priors(NSArray *items){double sums[2]={0,0},priors[2]={6.5,6.5};NSUInteger counts[2]={0,0};for(NSDictionary *m in items)if(RN(m[@"imdbVotes"])>=10000&&RN(m[@"imdbRating"])>=1&&RN(m[@"imdbRating"])<=10){NSUInteger t=[m[@"type"]isEqual:@"series"]?1:0;sums[t]+=RN(m[@"imdbRating"]);counts[t]++;}for(int t=0;t<2;t++)if(counts[t]>=10)priors[t]=MAX(6,MIN(7.5,sums[t]/counts[t]));return @[@(priors[0]),@(priors[1])];}
#include "RWRelatedEvidence.inc"
@implementation RWRecommendationPolicy
+ (NSDictionary *)relatedEvidence:(NSDictionary *)candidate current:(NSDictionary *)current {return RelatedEvidence(RD(candidate),RD(current));}
+ (NSArray *)related:(NSArray *)items current:(NSDictionary *)current profile:(NSDictionary *)profile world:(BOOL)world now:(double)now limit:(NSUInteger)limit {
    if(!RID(current).length)return @[];NSMutableDictionary *context=[profile mutableCopy]?:[NSMutableDictionary new];context[@"rankingPurpose"]=@"related";
    return [self rank:items current:current profile:context world:world requireAvailability:NO now:now limit:limit];
}
+ (BOOL)homePendingEligible:(NSDictionary *)meta now:(double)now {return [self homeQualityEligible:meta]&&![RWAvailability futureRelease:meta now:now];}
+ (NSDictionary *)interestDiagnostics:(NSArray *)items profile:(NSDictionary *)profile now:(double)now {
    NSMutableDictionary *cache=[NSMutableDictionary new];PrepareInterests(items,profile,now,cache);NSMutableArray *groups=[NSMutableArray new];for(NSDictionary *group in cache[@"interestGroups"]){NSMutableArray *members=[NSMutableArray new];for(NSDictionary *signal in group[@"members"])[members addObject:@{@"id":RID(signal[@"meta"]),@"kind":signal[@"kind"],@"weight":signal[@"weight"],@"at":signal[@"at"]}];[groups addObject:@{@"id":group[@"id"],@"members":members}];}NSMutableDictionary *result=[cache[@"interestSummary"]mutableCopy];result[@"groups"]=groups;result[@"feature_weights"]=cache[@"featureWeights"];return result;
}
+ (NSSet *)homeExcludedIDsForProfile:(NSDictionary *)profile {
    NSMutableSet *excluded=[NSMutableSet setWithArray:RA(profile[@"hidden"])];[excluded addObjectsFromArray:RA(profile[@"homeExcludedIDs"])];
    for(id raw in RA(profile[@"liked"])){NSString *key=RID(RD(raw));if(key.length)[excluded addObject:key];}
    for(id raw in RD(profile[@"history"]).allValues){NSDictionary *r=RD(raw);NSString *key=RID(RD(r[@"meta"]));
        if(key.length&&([RWViewingSignals meaningful:r]||(![r[@"completed"]boolValue]&&RN(r[@"position"])>3)))[excluded addObject:key];
    }return excluded;
}
+ (double)quality:(NSDictionary *)meta prior:(double)prior {
    double rating=RN(meta[@"imdbRating"]),votes=RN(meta[@"imdbVotes"]);if(!isfinite(rating)||rating<1||rating>10||!isfinite(votes)||votes<1)return prior;
    return (votes*rating+5000*prior)/(votes+5000);
}
+ (BOOL)homeQualityEligible:(NSDictionary *)meta {
    // Automatic Home promotion has a quality floor. This does not change
    // search, explicit library/history access or contextual detail browsing.
    id raw=meta[@"imdbRating"];double rating=0;
    if([raw isKindOfClass:NSNumber.class])rating=[raw doubleValue];
    else if([raw isKindOfClass:NSString.class]){NSScanner *scanner=[NSScanner scannerWithString:raw];scanner.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];if(![scanner scanDouble:&rating]||!scanner.isAtEnd)return YES;}
    else return YES;
    return !isfinite(rating)||rating<1||rating>10||rating>=6;
}
+ (NSArray *)homeRefreshCandidates:(NSArray *)items profile:(NSDictionary *)profile now:(double)now {
    NSSet *excluded=[self homeExcludedIDsForProfile:profile];NSMutableArray *out=[NSMutableArray new];NSUInteger read=0;
    for(id raw in RA(items)){if(read++==500)break;NSDictionary *meta=RD(raw);NSString *key=RID(meta);
        if(key.length&&![excluded containsObject:key]&&[RWDiscoveryMetadataPolicy recommendationAudienceAllows:meta preferences:profile[@"discoveryPreferences"] restricted:[profile[@"maxAge"]integerValue]>=0]&&[self homePendingEligible:meta now:now])[out addObject:meta];
    }return out;
}
+ (NSArray *)rank:(NSArray *)items current:(NSDictionary *)current profile:(NSDictionary *)profile world:(BOOL)world requireAvailability:(BOOL)requireAvailability now:(double)now limit:(NSUInteger)limit {
    return [self rank:items current:current profile:profile world:world requireAvailability:requireAvailability now:now limit:limit featureCache:[NSMutableDictionary new]];
}
+ (NSArray *)rank:(NSArray *)items current:(NSDictionary *)current profile:(NSDictionary *)profile world:(BOOL)world requireAvailability:(BOOL)requireAvailability now:(double)now limit:(NSUInteger)limit featureCache:(NSMutableDictionary *)cache {
    NSDictionary *prefs=[RWDiscoveryMetadataPolicy preferences:profile[@"discoveryPreferences"]];NSMutableSet *excluded=[NSMutableSet setWithArray:RA(profile[@"hidden"])];[excluded addObjectsFromArray:RA(profile[@"rankingExcludedIDs"])];if(RID(current).length)[excluded addObject:RID(current)];
    BOOL contextual=[profile[@"rankingPurpose"]isEqual:@"related"];
    PrepareInterests(items,profile,now,cache);NSSet *currentFeatures=CachedFeatures(current,cache);RWRecommendationFeatureVector *currentVector=Vector(currentFeatures,cache);
    // A related-title row needs evidence about the title being viewed. Missing
    // metadata must not silently turn it into a generic popularity shelf.
    if(!contextual&&RID(current).length&&!currentFeatures.count)return @[];
    for(NSDictionary *m in RA(profile[@"liked"]))if(RID(m).length)[excluded addObject:RID(m)];
    for(NSDictionary *record in RD(profile[@"history"]).allValues)if([RWViewingSignals meaningful:record]&&RID(RD(record[@"meta"])).length)[excluded addObject:RID(record[@"meta"])];
    NSMutableArray *pool=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];BOOL kids=[profile[@"maxAge"]integerValue]>=0;
    // Separate type priors are recomputed from trustworthy local observations.
    NSArray *priors=RA(profile[@"rankingPriors"]);if(priors.count!=2)priors=Priors(items);
    for(id raw in items){NSDictionary *m=RD(raw);NSString *key=RID(m);if(!key.length||![@[@"movie",@"series"]containsObject:m[@"type"]?:@""]||[seen containsObject:key]||[excluded containsObject:key])continue;[seen addObject:key];if(seen.count>500)break;
        if([@[@"movie",@"series"]containsObject:RT(current[@"type"])]&&![m[@"type"]isEqual:current[@"type"]])continue;
        // World Cinema is a films-only Home shelf. A deliberately opened
        // non-English show still needs a contextual related-shows row.
        BOOL relatedShow=[current[@"type"]isEqual:@"series"]&&[m[@"type"]isEqual:@"series"];
        if(world&&![m[@"type"]isEqual:@"movie"]&&!relatedShow)continue;
        if(requireAvailability&&![RWDiscoveryMetadataPolicy recommendationAudienceAllows:m preferences:prefs restricted:kids])continue;
        NSDictionary *availability=RD(m[@"availability"]);if(requireAvailability&&![availability[@"discovery_eligible"]boolValue])continue;
        if([availability[@"watch_instead_of_play"]boolValue])continue;
        NSString *gateKey=[NSString stringWithFormat:@"gate:%d:%@",world,key];NSNumber *permitted=cache[gateKey];if(!permitted){permitted=@((kids?([m[@"ageAllowed"]boolValue]&&[RWDiscoveryMetadataPolicy isFamilyTitle:m]&&(!world||[RWDiscoveryMetadataPolicy permits:m preferences:prefs world:YES])):[RWDiscoveryMetadataPolicy permits:m preferences:prefs world:world])&&![RWAvailability futureRelease:m now:now]);cache[gateKey]=permitted;}if(!permitted.boolValue)continue;
        double quality=[self quality:m prior:RN(priors[[m[@"type"]isEqual:@"series"]?1:0])];
        if(world&&(RN(m[@"imdbRating"])<[prefs[@"worldMinRating"]doubleValue]||RN(m[@"imdbVotes"])<2000||quality<7.2))continue;
        NSDictionary *context=contextual?CachedRelatedEvidence(m,current,cache):nil;if(contextual&&(![context[@"eligible"]boolValue]||![self homeQualityEligible:m]))continue;
        NSSet *features=CachedFeatures(m,cache);
        // Context is fixed for this Home pass except exclusions and page caps.
        // Reuse each title's affinity/base score across row recipes; diversity
        // is still evaluated against each row's actual selected neighbours.
        NSString *scoreKey=[NSString stringWithFormat:@"score:%@:%@",RID(current),key];NSDictionary *scored=cache[scoreKey];
        if(!scored){NSMutableDictionary *tasteCache=cache[@"tasteScores"];if(!tasteCache){tasteCache=[NSMutableDictionary new];cache[@"tasteScores"]=tasteCache;}NSValue *featureKey=[NSValue valueWithNonretainedObject:features];NSDictionary *taste=tasteCache[featureKey];if(!taste){taste=TasteEvidence(features,cache);tasteCache[featureKey]=taste;}double affinity=[taste[@"affinity"]doubleValue];
            double currentSimilarity=contextual?[context[@"score"]doubleValue]:currentFeatures.count?CompareVectors(Vector(features,cache),currentVector,YES):1;if(currentFeatures.count)affinity=.8*currentSimilarity+.2*affinity;
            if(!cache[@"interestByTitle"])cache[@"interestByTitle"]=[NSMutableDictionary new];cache[@"interestByTitle"][key]=taste[@"interest"];
            NSDictionary *exposure=RD(RD(profile[@"discoveryExposures"])[key]);double age=MAX(0,now-[exposure[@"at"]doubleValue])/86400;double novelty=exposure.count?MIN(1,.15+age/7):1;
            NSInteger year=RN(m[@"releaseInfo"]);double currentYear=1970+now/(365.2425*86400),freshness=year>1900?MAX(0,1-(currentYear-year)/4):0;
            unsigned long hash=0;for(NSUInteger i=0;i<key.length;i++)hash=hash*33+[key characterAtIndex:i];double explore=(hash%101)/100.0;
            double base=.45*affinity+.20*MAX(0,MIN(1,(quality-5)/4))+.15*novelty+.10*freshness+.10*explore;
            if(contextual)base=.78*currentSimilarity+.17*MAX(0,MIN(1,(quality-5)/4))+.05*[taste[@"affinity"]doubleValue];
            scored=@{@"meta":m,@"features":features,@"vector":Vector(features,cache),@"context":context?:@{},@"base":@(base),@"affinity":@(affinity),@"interest":taste[@"interest"],@"currentSimilarity":@(currentSimilarity),@"directors":IDs(m,@"directors"),@"franchises":IDs(m,@"franchises")};cache[scoreKey]=scored;
        }
        if([scored[@"currentSimilarity"]doubleValue]<.06)continue;
        [pool addObject:scored];
    }
    [pool sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSComparisonResult order=[b[@"base"]compare:a[@"base"]];return order==NSOrderedSame?[RID(a[@"meta"])compare:RID(b[@"meta"])]:order;}];
    if(pool.count>80)[pool removeObjectsInRange:NSMakeRange(80,pool.count-80)];
    NSMutableArray *out=[NSMutableArray new];NSMutableDictionary *directors=[RD(profile[@"pageDirectorCounts"])mutableCopy];NSMutableSet *franchises=[NSMutableSet setWithArray:RA(profile[@"pageFranchises"])];NSMutableDictionary *interestCounts=[RD(profile[@"pageInterestCounts"])mutableCopy];
    // Pool is capped at80. Row-local doubles avoid copying/scoring dictionaries
    // and allocating a boxed similarity for each neighbour update.
    NSMutableDictionary *relatedFranchises=[NSMutableDictionary new];
    double similarities[80]={0};
    while(pool.count&&out.count<MIN(limit,(NSUInteger)40)){NSInteger best=-1;double bestScore=-DBL_MAX;
        for(NSUInteger i=0;i<pool.count;i++){NSDictionary *candidate=pool[i],*meta=candidate[@"meta"];BOOL capped=NO;for(NSString *d in candidate[@"directors"])if([directors[d]integerValue]>=(contextual?3:2))capped=YES;for(NSString *f in contextual?candidate[@"context"][@"franchises"]:candidate[@"franchises"])if(contextual?[relatedFranchises[f]integerValue]>=2:[franchises containsObject:f])capped=YES;if(capped)continue;
            double similarity=similarities[i];double repeatedInterest=currentFeatures.count||![candidate[@"interest"]length]?0:.035*MIN(4,[interestCounts[candidate[@"interest"]]integerValue]);double score=(contextual?.96:.82)*[candidate[@"base"]doubleValue]-(contextual?.04:.18)*similarity-repeatedInterest;if(score>bestScore){bestScore=score;best=(NSInteger)i;}
        }if(best<0)break;NSDictionary *chosen=pool[best],*meta=chosen[@"meta"];[out addObject:meta];NSString *interest=chosen[@"interest"];if(interest.length)interestCounts[interest]=@([interestCounts[interest]integerValue]+1);[pool removeObjectAtIndex:best];memmove(similarities+best,similarities+best+1,(pool.count-best)*sizeof(double));for(NSUInteger i=0;i<pool.count;i++)similarities[i]=MAX(similarities[i],CompareVectors(pool[i][@"vector"],chosen[@"vector"],NO));for(NSString *d in IDs(meta,@"directors"))directors[d]=@([directors[d]integerValue]+1);[franchises addObjectsFromArray:IDs(meta,@"franchises")];if(contextual)for(NSString *f in chosen[@"context"][@"franchises"])relatedFranchises[f]=@([relatedFranchises[f]integerValue]+1);
    }return out;
}
// A Home pass ranks only bounded, typed candidate sets. Shelves compete for a
// small page budget; their visible membership remains stable in mergeHome.
+ (NSDictionary *)home:(NSArray *)items profile:(NSDictionary *)profile year:(NSInteger)year now:(double)now {
    double began=NSProcessInfo.processInfo.systemUptime;NSMutableDictionary *cache=[NSMutableDictionary new],*context=[profile mutableCopy];
    NSMutableArray *hidden=[self homeExcludedIDsForProfile:profile].allObjects.mutableCopy,*franchises=[NSMutableArray new];NSMutableDictionary *directors=[NSMutableDictionary new],*interestCounts=[NSMutableDictionary new];
    context[@"hidden"]=hidden;context[@"pageDirectorCounts"]=directors;context[@"pageFranchises"]=franchises;context[@"pageInterestCounts"]=interestCounts;
    NSUInteger candidateCount=MIN(items.count,(NSUInteger)500);items=[items subarrayWithRange:NSMakeRange(0,candidateCount)];context[@"rankingPriors"]=Priors(items);
    NSDictionary *prefs=[RWDiscoveryMetadataPolicy preferences:profile[@"discoveryPreferences"]];BOOL kids=[profile[@"maxAge"]integerValue]>=0;
    NSMutableArray *qualified=[NSMutableArray new],*main=[NSMutableArray new],*heroPool=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(id raw in items){NSDictionary *m=RD(raw);NSString *key=RID(m);if(!key.length||[seen containsObject:key]||[hidden containsObject:key]||![@[@"movie",@"series"]containsObject:m[@"type"]?:@""])continue;[seen addObject:key];
        if(![RWDiscoveryMetadataPolicy recommendationAudienceAllows:m preferences:prefs restricted:kids]||![self homeQualityEligible:m]||![RD(m[@"availability"])[@"discovery_eligible"]boolValue]||[RD(m[@"availability"])[@"watch_instead_of_play"]boolValue]||[RWAvailability futureRelease:m now:now]||(kids&&(![m[@"ageAllowed"]boolValue]||![RWDiscoveryMetadataPolicy isFamilyTitle:m])))continue;
        [qualified addObject:m];BOOL permitted=kids||[RWDiscoveryMetadataPolicy permits:m preferences:prefs world:NO];cache[[NSString stringWithFormat:@"gate:0:%@",key]]=@(permitted);if(permitted){[main addObject:m];if([m[@"availability"][@"hero_eligible"]boolValue])[heroPool addObject:m];}
    }
    // Rarity is measured within the eligible catalog this page can recommend.
    // Unavailable titles cannot change taste weights or occupy feature memory.
    PrepareInterests(qualified,profile,now,cache);
    void(^remember)(NSArray *)=^(NSArray *titles){for(NSDictionary *m in titles){if(RID(m).length)[hidden addObject:RID(m)];for(NSString *d in IDs(m,@"directors"))directors[d]=@([directors[d]integerValue]+1);[franchises addObjectsFromArray:IDs(m,@"franchises")];NSString *interest=cache[@"interestByTitle"][RID(m)];if(interest.length)interestCounts[interest]=@([interestCounts[interest]integerValue]+1);}};
    NSDictionary *hero=[self rank:heroPool current:nil profile:context world:NO requireAvailability:YES now:now limit:1 featureCache:cache].firstObject;if(hero)remember(@[hero]);
    // Reserve a separate selective World Cinema shelf, including when a user
    // opts into all languages. The same title cannot also fill a general row.
    NSArray *world=[self rank:qualified current:nil profile:context world:YES requireAvailability:YES now:now limit:10 featureCache:cache];remember(world);
    NSMutableArray *rows=[NSMutableArray new],*decisions=[NSMutableArray new],*recipes=[NSMutableArray new];NSMutableDictionary *typeCounts=[NSMutableDictionary new];NSMutableSet *intents=[NSMutableSet new];
    for(NSString *type in @[@"movie",@"series"]){NSArray *likedAnchors=InterestAnchors(cache,type,YES);NSDictionary *anchor=likedAnchors.firstObject?:InterestAnchors(cache,type,NO).firstObject;BOOL film=[type isEqual:@"movie"];NSString *noun=film?@"Films":@"Series",*lower=film?@"films":@"series";NSMutableArray *typed=[NSMutableArray new],*recent=[NSMutableArray new],*older=[NSMutableArray new];NSMutableDictionary *moods=[NSMutableDictionary new];
        for(NSDictionary *m in main)if([m[@"type"]isEqual:type]){[typed addObject:m];NSInteger released=RN(m[@"releaseInfo"]);if(released>=year-1&&released<=year)[recent addObject:m];if(released>=1900&&released<=year-10)[older addObject:m];for(NSString *mood in CachedMoods(m,cache)){if(!moods[mood])moods[mood]=[NSMutableArray new];[moods[mood]addObject:m];}}
        // The first visible screen gets a real ranked prefix before specialist
        // rows consume their supply. Four picks leave room for useful categories.
        NSArray *leadingPool=typed;
        if(kids&&!anchor){NSMutableArray *child=[NSMutableArray new];for(NSDictionary *m in typed)if([RWDiscoveryMetadataPolicy isChildFocused:m])[child addObject:m];if(child.count>=4)leadingPool=child;}
        NSArray *leading=[self rank:leadingPool current:nil profile:context world:NO requireAvailability:YES now:now limit:4 featureCache:cache];
        NSMutableSet *leadingIDs=[NSMutableSet new];for(NSDictionary *m in leading)[leadingIDs addObject:RID(m)];
        BOOL categorySurvives=NO;NSMutableArray *scarce=[NSMutableArray new];
        for(NSDictionary *category in [RWHomeCategoryPolicy categoriesForKids:kids])if([category[@"mediaType"]isEqual:type]){
            NSMutableArray *available=[NSMutableArray new];NSUInteger remaining=0;BOOL containsFirst=NO;
            for(NSDictionary *m in typed)if(![hidden containsObject:RID(m)]&&[RWHomeCategoryPolicy matches:m category:category]){[available addObject:m];remaining+=![leadingIDs containsObject:RID(m)];containsFirst|=[RID(m)isEqual:RID(leading.firstObject)];}
            categorySurvives|=remaining>=6;if(available.count>=6&&!containsFirst)[scarce addObject:available];
        }
        // In a small catalog protect one coherent set when it leaves the best
        // leading recommendation intact. Do not manufacture a two-card genre row.
        if(!categorySurvives&&scarce.count&&leading.count){
            NSArray *reservedTitles=[self rank:scarce.firstObject current:nil profile:context world:NO requireAvailability:YES now:now limit:6 featureCache:cache];
            if(reservedTitles.count==6){NSMutableSet *ids=[NSMutableSet new];for(NSDictionary *m in reservedTitles)[ids addObject:RID(m)];NSMutableArray *rest=[NSMutableArray new];for(NSDictionary *m in leadingPool)if(![ids containsObject:RID(m)])[rest addObject:m];leading=[self rank:rest current:nil profile:context world:NO requireAvailability:YES now:now limit:4 featureCache:cache];}
        }
        if(typed.count){[rows addObject:@{@"id":[@"for-you-" stringByAppendingString:type],@"title":[noun stringByAppendingString:@" for you"],@"mediaType":type,@"recipe":@"for-you",@"minimumCount":@1,@"items":leading}];remember(leading);typeCounts[type]=@1;}
        void(^recipe)(NSString *,NSString *,NSArray *,double,NSDictionary *)=^(NSString *kind,NSString *title,NSArray *subset,double importance,NSDictionary *current){if(subset.count<6)return;[recipes addObject:@{@"id":[kind stringByAppendingFormat:@"-%@%@",type,[kind isEqual:@"because"]?[@"-" stringByAppendingString:RID(current)]:@""],@"title":title,@"mediaType":type,@"recipe":kind,@"items":subset,@"importance":@(importance),@"current":current?:@{},@"mood":[kind isEqual:@"mood"]?[[title componentsSeparatedByString:@" · "]lastObject]:@""}];};
        for(NSDictionary *category in [RWHomeCategoryPolicy categoriesForKids:kids])if([category[@"mediaType"]isEqual:type]){NSMutableArray *subset=[NSMutableArray new];for(NSDictionary *m in typed)if([RWHomeCategoryPolicy matches:m category:category])[subset addObject:m];if(subset.count>=6){NSMutableDictionary *proposal=[category mutableCopy];proposal[@"items"]=subset;proposal[@"importance"]=@1.05;proposal[@"current"]=@{};[recipes addObject:proposal];}}
        NSUInteger proposed=0;for(NSDictionary *liked in likedAnchors)if(RT(liked[@"name"]).length){recipe(@"because",[NSString stringWithFormat:@"%@ · Because you liked %@",noun,liked[@"name"]],typed,1.2,liked);if(++proposed==2)break;}
        recipe(@"new",[NSString stringWithFormat:@"New %@ worth watching",lower],recent,.72,nil);
        recipe(@"older",[NSString stringWithFormat:@"Older %@ to discover",lower],older,.72,nil);
        NSArray *preferred=CachedMoods(anchor,cache);NSArray *moodNames=[moods.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a,NSString *b){BOOL pa=[preferred containsObject:a],pb=[preferred containsObject:b];if(pa!=pb)return pa?NSOrderedAscending:NSOrderedDescending;NSUInteger ca=[moods[a]count],cb=[moods[b]count];return ca==cb?[a compare:b]:ca>cb?NSOrderedAscending:NSOrderedDescending;}];
        // At most one well-supported mood candidate per type, not every tag.
        for(NSString *mood in moodNames)if([moods[mood]count]>=6){recipe(@"mood",[NSString stringWithFormat:@"%@ · %@",noun,mood],moods[mood],.68,nil);break;}
        recipe(@"more",[NSString stringWithFormat:@"More %@ to discover",lower],typed,.25,nil);
    }
    NSUInteger budget=world.count?11:12;
    while(recipes.count&&rows.count<budget){NSInteger best=-1;double score=-DBL_MAX;NSUInteger support=0;
        for(NSUInteger i=0;i<recipes.count;i++){NSDictionary *recipe=recipes[i];NSUInteger count=0,remaining=0;for(NSDictionary *m in recipe[@"items"])if(![hidden containsObject:RID(m)])count++;for(NSDictionary *m in main)if([m[@"type"]isEqual:recipe[@"mediaType"]]&&![hidden containsObject:RID(m)])remaining++;if(count<6||remaining<6)continue;
            double value=[recipe[@"importance"]doubleValue]+.1*MIN(12,count)/12.0-.13*[typeCounts[recipe[@"mediaType"]]integerValue]-([intents containsObject:recipe[@"recipe"]]?.24:0);
            if(value>score){best=(NSInteger)i;score=value;support=count;}
        }if(best<0)break;NSDictionary *recipe=recipes[best];[recipes removeObjectAtIndex:best];
        NSUInteger remaining=0;for(NSDictionary *m in main)if([m[@"type"]isEqual:recipe[@"mediaType"]]&&![hidden containsObject:RID(m)])remaining++;NSUInteger take=MIN([recipe[@"recipe"]isEqual:@"category"]?(NSUInteger)6:(NSUInteger)10,remaining);NSArray *ranked=[self rank:recipe[@"items"] current:recipe[@"current"] profile:context world:NO requireAvailability:YES now:now limit:take featureCache:cache];if(ranked.count<6)continue;
        NSMutableDictionary *selected=[recipe mutableCopy];[selected removeObjectForKey:@"importance"];[selected removeObjectForKey:@"current"];selected[@"minimumCount"]=@6;selected[@"items"]=ranked;selected[@"mood"]=recipe[@"mood"]?:@"";selected[@"anchor"]=recipe[@"current"]?:@{};[rows addObject:selected];remember(ranked);typeCounts[recipe[@"mediaType"]]=@([typeCounts[recipe[@"mediaType"]]integerValue]+1);[intents addObject:recipe[@"recipe"]];
        [decisions addObject:@{@"row":recipe[@"id"],@"eligible_support":@(support),@"selected":@(ranked.count),@"selection_score":@(score)}];
    }
    // A few leftover candidates belong in the broad shelf of their own type,
    // never under a misleading specialist heading or a mixed "More" shelf.
    for(NSUInteger i=0;i<rows.count;i++){NSDictionary *old=rows[i];if(![old[@"recipe"]isEqual:@"for-you"]||[old[@"items"]count]>=12)continue;NSMutableArray *typed=[NSMutableArray new];for(NSDictionary *m in main)if([m[@"type"]isEqual:old[@"mediaType"]])[typed addObject:m];
        NSArray *extra=[self rank:typed current:nil profile:context world:NO requireAvailability:YES now:now limit:12-[old[@"items"]count] featureCache:cache];if(extra.count){NSMutableDictionary *row=[old mutableCopy];row[@"items"]=[row[@"items"]arrayByAddingObjectsFromArray:extra];rows[i]=row;remember(extra);}
    }
    [rows filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *r,NSDictionary *bindings){return [r[@"items"]count]>0;}]];
    if(world.count)[rows addObject:@{@"id":@"world",@"title":@"World Cinema · Films",@"mediaType":@"movie",@"recipe":@"world",@"minimumCount":@1,@"items":world}];
    return @{@"layoutVersion":@229,@"hero":hero?:@{},@"rows":rows,@"rowDecisions":decisions,@"computedAt":@(now),@"seconds":@(NSProcessInfo.processInfo.systemUptime-began),@"candidateCount":@(candidateCount),@"eligibleCount":@(qualified.count),@"ratingPriors":context[@"rankingPriors"],@"interestModel":cache[@"interestSummary"],@"interestAnchors":InterestAnchors(cache,nil,NO)};
}
@end
