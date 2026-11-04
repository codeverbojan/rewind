#import "RWEntityCreditPolicy.h"
#import "RWExploreIndex.h"
#import "RWDiscoveryMetadataPolicy.h"
#include <math.h>
#include <float.h>
static NSString *ES(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static NSDictionary *ED(id x){return [x isKindOfClass:NSDictionary.class]?x:@{};}
static NSArray *EA(id x){return [x isKindOfClass:NSArray.class]?x:@[];}
static double EN(id x){double n=[x respondsToSelector:@selector(doubleValue)]?[x doubleValue]:0;return isfinite(n)?n:0;}
static NSString *Fold(NSString *s){return [[ES(s) stringByFoldingWithOptions:NSDiacriticInsensitiveSearch|NSCaseInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]]lowercaseString];}
static NSInteger Match(NSString *name,NSString *query){
    if(!query.length)return 0;NSString *n=Fold(name);if([n isEqual:query])return 0;if([n hasPrefix:query])return 1;
    NSArray *words=[n componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];BOOL all=YES;
    for(NSString *term in [query componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet])if(term.length){BOOL found=NO;for(NSString *word in words)if([word hasPrefix:term]){found=YES;break;}if(!found){all=NO;break;}}
    if(all)return 2;return [n rangeOfString:query].location!=NSNotFound?3:99;
}
static double CreditScore(NSDictionary *m,NSInteger year,NSString *today){
    NSInteger released=EN(m[@"releaseInfo"]?:m[@"year"]);NSString *date=ES(m[@"released"]);
    BOOL future=released>year||(date.length>=10&&[[date substringToIndex:10]compare:today]==NSOrderedDescending);
    if(released<1800||future)return 0;double rating=EN(m[@"imdbRating"]),votes=MAX(0,EN(m[@"imdbVotes"]));
    if(rating<1||rating>10||votes<1)return 1;
    // Shrink small samples towards the title-rating prior, then give recent
    // well-rated releases a small boost. This is never shown as a person rating.
    double quality=(votes*rating+5000*6.5)/(votes+5000);
    return quality+(quality>=7&&released>=year-2&&released<=year?.45:0);
}
static NSDictionary *CreditBrief(NSDictionary *m){NSMutableDictionary *out=[NSMutableDictionary new];for(NSString *key in @[@"id",@"type",@"name",@"poster",@"background",@"releaseInfo",@"released",@"imdbRating",@"imdbVotes",@"genres"]){id value=m[key];if(value)out[key]=value;}return out;}
static NSArray *Diversified(NSArray *ranked){
    // Default discovery should introduce different work, rather than filling
    // the first screen with one ensemble. Preserve relevance for named queries
    // and preserve every record; only reorder the first 24 recommendations.
    NSMutableArray *remaining=[ranked mutableCopy],*out=[NSMutableArray new];NSMutableDictionary *uses=[NSMutableDictionary new];
    while(remaining.count&&out.count<24){NSUInteger best=0;double bestScore=-DBL_MAX;
        for(NSUInteger i=0;i<remaining.count;i++){NSDictionary *row=remaining[i];NSString *anchor=ES([EA(row[@"knownFor"])firstObject][@"id"]);double score=EN(row[@"score"])-1.25*EN(uses[anchor]);if(score>bestScore){bestScore=score;best=i;}}
        NSDictionary *row=remaining[best];NSString *anchor=ES([EA(row[@"knownFor"])firstObject][@"id"]);if(anchor.length)uses[anchor]=@(EN(uses[anchor])+1);[out addObject:row];[remaining removeObjectAtIndex:best];
    }[out addObjectsFromArray:remaining];return out;
}
@implementation RWExploreIndex
+ (NSArray *)moodNames{return @[@"Mind-bending",@"Crime & suspense",@"Epic adventures",@"Light-hearted",@"True stories"];}
+ (NSString *)moodDescription:(NSString *)mood {return @{@"Mind-bending":@"Unusual worlds and stories that keep you guessing.",@"Crime & suspense":@"Investigations, secrets and mounting tension.",@"Epic adventures":@"Big journeys into unfamiliar worlds.",@"Light-hearted":@"Warm stories, laughter and a lighter mood.",@"True stories":@"Real events and the people behind them."}[mood?:@""]?:@"";}
+ (NSArray *)records:(NSArray *)titles kind:(NSString *)kind mood:(NSString *)mood query:(NSString *)query profile:(NSString *)profile entities:(NSDictionary *)entities now:(double)now {
    return [self records:titles kind:kind mood:mood query:query profile:profile preferences:@{@"recommendationAudience":@"all_ages"} restricted:NO entities:entities now:now];
}
+ (NSArray *)records:(NSArray *)titles kind:(NSString *)kind mood:(NSString *)mood query:(NSString *)query profile:(NSString *)profile preferences:(NSDictionary *)preferences restricted:(BOOL)restricted entities:(NSDictionary *)entities now:(double)now {
    NSString *q=Fold([ES(query)stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]);NSDate *date=[NSDate dateWithTimeIntervalSince1970:now];NSInteger year=[[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian]component:NSCalendarUnitYear fromDate:date];NSDateFormatter *f=[NSDateFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];f.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];f.dateFormat=@"yyyy-MM-dd";NSString *today=[f stringFromDate:date];
    NSMutableArray *ranked=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(id raw in titles){NSDictionary *m=ED(raw);NSString *identifier=ES(m[@"id"]);if(!identifier.length||[seen containsObject:identifier]||![@[@"movie",@"series"]containsObject:m[@"type"]?:@""]||!ES(m[@"name"]).length)continue;if([kind isEqual:@"Moods"]&&(!mood.length||!q.length)&&![RWDiscoveryMetadataPolicy recommendationAudienceAllows:m preferences:preferences restricted:restricted])continue;[seen addObject:identifier];double score=CreditScore(m,year,today);if(score<=0)continue;[ranked addObject:@{@"meta":m,@"score":@(score)}];}
    [ranked sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSComparisonResult order=[b[@"score"]compare:a[@"score"]];return order==NSOrderedSame?[ES(a[@"meta"][@"id"])compare:ES(b[@"meta"][@"id"])]:order;}];
    if(mood.length){NSMutableArray *out=[NSMutableArray new];for(NSDictionary *row in ranked){NSDictionary *m=row[@"meta"];if([[RWDiscoveryMetadataPolicy moods:m]containsObject:mood]&&Match(ES(m[@"name"]),q)<99)[out addObject:m];}return out;}
    BOOL moods=[kind isEqual:@"Moods"],studio=[kind isEqual:@"Studios"];NSMutableDictionary *groups=[NSMutableDictionary new];
    for(NSDictionary *row in ranked){NSDictionary *m=row[@"meta"],*discovery=ED(m[@"discovery"]);NSMutableArray *refs=[NSMutableArray new];
        if(moods){for(NSString *name in [RWDiscoveryMetadataPolicy moods:m])if([[self moodNames]containsObject:name])[refs addObject:@{@"id":[@"mood:" stringByAppendingString:name],@"name":name,@"role":@"mood"}];}
        else for(NSString *field in studio?@[@"studios",@"distributors",@"networks"]:@[@"cast",@"directors"])for(id raw in EA(discovery[field])){NSDictionary *ref=ED(raw);NSString *identifier=ES(ref[@"id"]);if([identifier rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location!=0||!ES(ref[@"name"]).length)continue;[refs addObject:@{@"id":identifier,@"name":ref[@"name"],@"role":@{@"studios":@"studio",@"distributors":@"distributor",@"networks":@"network",@"directors":@"director",@"cast":@"cast"}[field]}];}
        for(NSDictionary *ref in refs){NSString *identifier=ref[@"id"],*name=ref[@"name"];NSInteger match=Match(name,q);if(match>=99)continue;NSMutableDictionary *group=groups[identifier];
            if(!group){NSString *type=moods?@"mood":studio?@"studio":@"person";group=[@{@"id":identifier,@"name":name,@"type":type,@"profileID":profile?:@"",@"roles":[NSMutableArray new],@"knownFor":[NSMutableArray new],@"creditIDs":[NSMutableSet new],@"score":row[@"score"],@"match":@(match)}mutableCopy];groups[identifier]=group;
                NSDictionary *cached=ED(entities[[identifier stringByAppendingString:studio?@":studio":@":person"]]);for(NSString *key in @[@"image",@"imageRole",@"biography",@"credit",@"sourceURL",@"kindLabel"])if(ES(cached[key]).length)group[key]=cached[key];
                if(moods){group[@"biography"]=[self moodDescription:name];group[@"image"]=ES(m[@"background"]).length?m[@"background"]:ES(m[@"poster"]);group[@"imageRole"]=@"mood-artwork";}
            }
            NSMutableArray *roles=group[@"roles"],*known=group[@"knownFor"];if(![roles containsObject:ref[@"role"]])[roles addObject:ref[@"role"]];NSMutableSet *creditIDs=group[@"creditIDs"];if(![creditIDs containsObject:m[@"id"]]){[creditIDs addObject:m[@"id"]];if(known.count<3)[known addObject:CreditBrief(m)];}
        }
    }
    NSMutableArray *out=[NSMutableArray new];for(NSMutableDictionary *g in groups.allValues){NSArray *roles=g[@"roles"];if(studio){NSMutableArray *ordered=[NSMutableArray new];for(NSString *role in @[@"studio",@"distributor",@"network"])if([roles containsObject:role])[ordered addObject:role];roles=ordered;g[@"roles"]=roles;if(!ES(g[@"kindLabel"]).length)g[@"kindLabel"]=[RWEntityCreditPolicy companySummary:roles];}g[@"creditRole"]=[roles containsObject:@"director"]?@"director":roles.firstObject?:@"cast";g[@"creditCount"]=@([g[@"creditIDs"]count]);[g removeObjectForKey:@"creditIDs"];[out addObject:g];}
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSComparisonResult order=[a[@"match"]compare:b[@"match"]];if(order==NSOrderedSame)order=[b[@"score"]compare:a[@"score"]];if(order==NSOrderedSame)order=[b[@"creditCount"]compare:a[@"creditCount"]];if(order==NSOrderedSame)order=[Fold(a[@"name"])compare:Fold(b[@"name"])];if(order==NSOrderedSame)order=[a[@"id"]compare:b[@"id"]];return order;}];return !q.length&&!moods?Diversified(out):out;
}
@end
