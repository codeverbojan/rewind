#import "RWEntityCreditPolicy.h"
#import "RWDiscoveryMetadataPolicy.h"
#import "RWCollectionIdentity.h"
static NSDictionary *D(id x){return [x isKindOfClass:NSDictionary.class]?x:@{};}
static NSArray *A(id x){return [x isKindOfClass:NSArray.class]?x:@[];}
static NSString *T(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static NSArray *Values(NSDictionary *e,NSString *p){NSMutableArray *out=[NSMutableArray new];for(id raw in A(D(e[@"claims"])[p])){NSDictionary *s=D(raw);if([s[@"rank"]isEqual:@"deprecated"])continue;id v=D(D(s[@"mainsnak"])[@"datavalue"])[@"value"];if(v)[out addObject:v];}return out;}
static NSString *Label(NSString *qid,NSDictionary *labels){return [RWDiscoveryMetadataPolicy displayName:D(labels[qid])];}
static NSArray *Refs(NSDictionary *e,NSString *p,NSDictionary *labels,NSUInteger cap){NSMutableArray *out=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];for(id v in Values(e,p)){NSString *key=T(D(v)[@"id"]);if([key rangeOfString:@"^Q[0-9]+$" options:NSRegularExpressionSearch].location!=0||[seen containsObject:key])continue;[seen addObject:key];[out addObject:@{@"id":key,@"name":Label(key,labels),@"provider":@"Wikidata"}];if(out.count>=cap)break;}return out;}
static BOOL Has(NSArray *refs,NSString *key){for(NSDictionary *ref in refs)if([ref[@"id"]isEqual:key])return YES;return NO;}
static NSNumber *VerifiedYear(NSDictionary *entity,NSString *property,BOOL first){
    NSMutableSet *years=[NSMutableSet new];BOOL ambiguous=NO;
    for(id value in Values(entity,property)){
        NSDictionary *date=D(value);NSString *time=T(date[@"time"]);
        NSInteger precision=[date[@"precision"]integerValue];
        if(precision<9||precision>11||[date[@"before"]integerValue]||[date[@"after"]integerValue]){ambiguous=YES;continue;}
        if(![T(date[@"calendarmodel"])isEqual:@"http://www.wikidata.org/entity/Q1985727"]||
           [time rangeOfString:@"^\\+[0-9]{4}-[0-9]{2}-[0-9]{2}T00:00:00Z$" options:NSRegularExpressionSearch].location!=0){ambiguous=YES;continue;}
        NSInteger year=[[time substringWithRange:NSMakeRange(1,4)]integerValue],month=[[time substringWithRange:NSMakeRange(6,2)]integerValue],day=[[time substringWithRange:NSMakeRange(9,2)]integerValue];
        NSInteger days[]={0,31,28,31,30,31,30,31,31,30,31,30,31};if(year%4==0&&(year%100!=0||year%400==0))days[2]=29;
        if(year<1888||year>2100||month>12||day>31||(precision>=10&&month<1)||(precision==11&&(day<1||day>days[month]))){ambiguous=YES;continue;}
        if(first)return @(year);[years addObject:@(year)];
    }
    return !ambiguous&&years.count==1?years.anyObject:nil;
}
@implementation RWDiscoveryMetadataPolicy
+ (NSString *)displayName:(NSDictionary *)entity {NSDictionary *labels=D(entity[@"labels"]);NSString *en=T(D(labels[@"en"])[@"value"]);return en.length?en:T(D(labels[@"mul"])[@"value"]);}
+ (NSDictionary *)entityProfile:(NSDictionary *)entity role:(NSString *)role {
    BOOL studio=[role isEqual:@"studio"];NSString *file=@"";for(id value in Values(entity,studio?@"P154":@"P18"))if(T(value).length){file=value;break;}
    return @{@"id":T(entity[@"id"]),@"name":[self displayName:entity],@"biography":T(D(D(entity[@"descriptions"])[@"en"])[@"value"]),@"imageFile":file,@"imageRole":studio?@"logo":@"portrait"};
}
+ (NSArray *)referencedIDs:(NSDictionary *)entity {
    NSMutableOrderedSet *ids=[NSMutableOrderedSet new];for(NSString *prop in @[@"P31",@"P364",@"P495",@"P57",@"P272",@"P750",@"P449",@"P136",@"P921",@"P179",@"P161"]){NSUInteger cap=[prop isEqual:@"P161"]?24:12;for(NSDictionary *ref in Refs(entity,prop,@{},cap))[ids addObject:ref[@"id"]];}return ids.array;
}
// Share the existing fifty-label allowance across the whole provider page.
// Classification and language precede cast/theme labels; one film's long cast
// must not leave later films with unnamed languages and genres.
+ (NSArray *)labelIDsForEntities:(NSArray *)entities {
    NSArray *page=entities.count>8?[entities subarrayWithRange:NSMakeRange(0,8)]:entities;
    NSMutableOrderedSet *ids=[NSMutableOrderedSet new];
    for(NSString *property in @[@"P31",@"P364",@"P136",@"P495",@"P57",@"P272",@"P750",@"P449",@"P921",@"P179",@"P161"]){
        NSMutableArray *groups=[NSMutableArray new];NSUInteger cap=[property isEqual:@"P161"]?24:12;
        for(NSDictionary *entity in page)[groups addObject:Refs(entity,property,@{},cap)];
        for(NSUInteger index=0;index<cap;index++)for(NSArray *refs in groups)if(index<refs.count){[ids addObject:refs[index][@"id"]];if(ids.count==50)return ids.array;}
    }return ids.array;
}
+ (NSArray *)collectionIDs:(NSDictionary *)entity {return [Refs(entity,@"P179",@{},6)valueForKey:@"id"];}
+ (BOOL)isNarrativeFranchise:(NSDictionary *)reference {
    // P179 includes filmographies and editorial lists. Even "animated film
    // series" is used for entire studio catalogues, so it alone cannot prove
    // narrative continuity. Unknown collections cannot suppress unrelated
    // recommendations or imply a sequel relationship.
    return RWIsNarrativeFranchise(reference);
}
+ (NSDictionary *)normalizeCollections:(NSDictionary *)record entities:(NSDictionary *)entities {
    record=D(record);NSMutableDictionary *out=[record mutableCopy];NSMutableArray *collections=[NSMutableArray new],*franchises=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    NSArray *raw=[record[@"collections"]isKindOfClass:NSArray.class]?record[@"collections"]:A(record[@"franchises"]);
    for(id value in raw){NSDictionary *ref=D(value);NSString *key=T(ref[@"id"]);if([key rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location!=0||[seen containsObject:key])continue;[seen addObject:key];
        NSMutableDictionary *copy=[ref mutableCopy];NSDictionary *entity=D(entities[key]);
        if([entity[@"id"]isEqual:key]&&[entity[@"claims"]isKindOfClass:NSDictionary.class]){copy[@"instanceOf"]=[Refs(entity,@"P31",@{},12)valueForKey:@"id"];NSString *name=[self displayName:entity];if(name.length)copy[@"name"]=name;copy[@"typeSource"]=[@"https://www.wikidata.org/wiki/" stringByAppendingString:key];copy[@"typeRevision"]=entity[@"lastrevid"]?:@0;}
        [collections addObject:copy];if([self isNarrativeFranchise:copy])[franchises addObject:copy];if(collections.count==6)break;
    }
    out[@"collections"]=collections;out[@"franchises"]=franchises;out[@"collectionPolicy"]=@1;return out;
}
+ (NSDictionary *)recordForEntity:(NSDictionary *)entity imdb:(NSString *)imdb labels:(NSDictionary *)labels {
    if(![imdb hasPrefix:@"tt"]||![Values(D(entity),@"P345")containsObject:imdb])return nil;
    NSArray *languages=Refs(entity,@"P364",labels,12),*countries=Refs(entity,@"P495",labels,12);
    BOOL explicitValue=Has(Refs(entity,@"P31",labels,12),@"Q93196")||Has(Refs(entity,@"P361",labels,12),@"Q93196")||Has(Refs(entity,@"P136",labels,12),@"Q93196");
    // Unknown industry is deliberately retained. India and Hindi are never
    // rewritten as a Bollywood label. Promotion can wait for reviewed evidence.
    NSString *industry=explicitValue?@"bollywood":(!countries.count||Has(countries,@"Q668"))?@"unknown":@"other";
    NSMutableDictionary *record=[[self normalizeCollections:@{@"imdb":imdb,@"entityID":T(entity[@"id"]),@"originalLanguages":languages,@"countries":countries,@"cast":Refs(entity,@"P161",labels,24),@"directors":Refs(entity,@"P57",labels,8),@"studios":Refs(entity,@"P272",labels,10),@"distributors":Refs(entity,@"P750",labels,10),@"networks":Refs(entity,@"P449",labels,10),@"genres":Refs(entity,@"P136",labels,12),@"themes":Refs(entity,@"P921",labels,12),@"franchises":Refs(entity,@"P179",labels,6),@"industry":industry,@"source":[@"https://www.wikidata.org/wiki/" stringByAppendingString:T(entity[@"id"])],@"revision":entity[@"lastrevid"]?:@0} entities:labels]mutableCopy];
    record[@"creditWorkType"]=[self creditTypeForEntity:entity labels:labels];record[@"creditTypePolicy"]=@1;
    // P577 is a premiere/publication date, not streaming availability. Only a
    // consensus year is used; conflicting years leave the catalog untouched.
    NSNumber *year=VerifiedYear(entity,@"P577",NO);
    if(year)record[@"releaseYearEvidence"]=@{@"year":year,@"property":@"P577",@"imdb":imdb,@"entityID":T(entity[@"id"]),@"source":record[@"source"],@"revision":record[@"revision"],@"policy":@1};
    return record;
}
+ (NSDictionary *)enrich:(NSDictionary *)meta record:(NSDictionary *)record {
    if(!record.count)return meta;NSMutableDictionary *copy=[meta mutableCopy];copy[@"discovery"]=record;
    NSDictionary *year=D(record[@"releaseYearEvidence"]);NSString *identifier=T(meta[@"id"]?:meta[@"imdb_id"]);NSInteger number=[year[@"year"]integerValue];
    if([meta[@"type"]isEqual:@"movie"]&&identifier.length&&[record[@"imdb"]isEqual:identifier]&&[year[@"imdb"]isEqual:identifier]&&[year[@"entityID"]isEqual:record[@"entityID"]]&&[year[@"property"]isEqual:@"P577"]&&[year[@"policy"]integerValue]==1&&[T(year[@"source"])hasPrefix:@"https://www.wikidata.org/wiki/Q"]&&number>=1888&&number<=2100){
        copy[@"year"]=[NSString stringWithFormat:@"%ld",(long)number];copy[@"releaseInfo"]=copy[@"year"];
    }return copy;
}
+ (NSArray *)worldFilmIDs:(NSDictionary *)entity {
    if(!Has(Refs(entity,@"P31",@{},12),@"Q11424"))return @[];
    NSArray *languages=Refs(entity,@"P364",@{},12);if(!languages.count)return @[];
    for(NSString *english in @[@"Q1860",@"Q7976",@"Q7979"])if(Has(languages,english))return @[];
    NSMutableOrderedSet *ids=[NSMutableOrderedSet new];for(id value in Values(entity,@"P345"))if([T(value)rangeOfString:@"^tt[0-9]+$" options:NSRegularExpressionSearch].location==0)[ids addObject:value];
    return ids.count==1?ids.array:@[];
}
// A label containing “television series” can describe an episode, not a show.
// Reject installments before testing any broad work class, including conflicts.
+ (NSString *)creditTypeForEntity:(NSDictionary *)entity labels:(NSDictionary *)labels {
    NSArray *classes=Refs(entity,@"P31",labels,12);BOOL film=NO,show=NO;
    for(NSDictionary *ref in classes){NSString *qid=T(ref[@"id"]),*name=[T(ref[@"name"])lowercaseString];
        if([qid isEqual:@"Q21191270"]||[name containsString:@"episode"]||[name containsString:@"season"]||[name containsString:@"film series"]||[name containsString:@"film franchise"])return @"installment";
        film|=[qid isEqual:@"Q11424"]||[name isEqual:@"film"]||[name hasSuffix:@" film"];
        show|=[qid isEqual:@"Q5398426"]||[name containsString:@"television series"]||[name containsString:@"miniseries"];
    }return film==show?@"unknown":film?@"movie":@"series";
}
// Only main statements describe the title's premiere. Broadcaster/company
// start-time qualifiers must not replace a show's original first-air year.
+ (NSString *)creditReleaseYearForEntity:(NSDictionary *)entity type:(NSString *)type {
    for(NSString *property in [type isEqual:@"series"]?@[@"P580",@"P577"]:@[@"P577"]){NSNumber *year=VerifiedYear(entity,property,[property isEqual:@"P577"]);if(year)return year.stringValue;}return @"";
}
+ (BOOL)allowsRetainedCredit:(NSDictionary *)meta record:(NSDictionary *)record {
    NSString *type=T(record[@"creditWorkType"]);
    if([record[@"creditTypePolicy"]integerValue]==1&&![type isEqual:@"unknown"]&&[record[@"imdb"]isEqual:T(meta[@"id"]?:meta[@"imdb_id"])])return [type isEqual:meta[@"type"]];
    // Old credit-derived guesses lack work-class proof; normal catalog titles
    // still seed the page. The corrected remote lookup refills derived credits.
    return !T(meta[@"creditEntityID"]).length;
}
+ (NSArray *)creditIDs:(NSDictionary *)entity role:(NSString *)role entityID:(NSString *)entityID {
    NSString *property=[RWEntityCreditPolicy property:role];if(!property||!Has(Refs(entity,property,@{},100),entityID))return @[];
    NSMutableArray *out=[NSMutableArray new];for(id value in Values(entity,@"P345"))if([T(value)rangeOfString:@"^tt[0-9]+$" options:NSRegularExpressionSearch].location==0)[out addObject:value];return out;
}
+ (NSString *)languageGroup:(NSDictionary *)record {
    NSString *primary=T(record[@"primaryLanguage"]);if(primary.length&&T(record[@"languageSource"]).length)return [primary isEqual:@"en"]?@"english":@"world";
    NSArray *langs=A(record[@"originalLanguages"]);if(!langs.count)return @"unknown";
    NSUInteger english=0;for(NSDictionary *language in langs){NSString *qid=T(D(language)[@"id"]),*label=[T(D(language)[@"name"])lowercaseString];if([@[@"Q1860",@"Q7976",@"Q7979"]containsObject:qid]||[label hasSuffix:@" english"])english++;}
    if(english==langs.count)return @"english";
    if(!english)return @"world";
    return @"unknown"; // A multilingual list does not establish the main language.
}
+ (NSDictionary *)preferences:(NSDictionary *)raw {
    raw=D(raw);NSString *mode=[T(raw[@"languageMode"])isEqual:@"all"]?@"all":@"english_first";
    return @{@"recommendationAudience":[T(raw[@"recommendationAudience"])isEqual:@"all_ages"]?@"all_ages":@"grown_up",@"languageMode":mode,@"worldCinema":@([raw[@"worldCinema"]respondsToSelector:@selector(boolValue)]?[raw[@"worldCinema"]boolValue]:YES),@"excludeBollywood":@([raw[@"excludeBollywood"]respondsToSelector:@selector(boolValue)]?[raw[@"excludeBollywood"]boolValue]:NO),@"worldMinRating":@(MIN(9,MAX(7,([raw[@"worldMinRating"]respondsToSelector:@selector(doubleValue)]?[raw[@"worldMinRating"]doubleValue]:7.5)?:7.5)))};
}
+ (BOOL)permits:(NSDictionary *)meta preferences:(NSDictionary *)preferences world:(BOOL)world {
    NSDictionary *p=[self preferences:preferences],*record=D(meta[@"discovery"]);NSString *industry=T(record[@"industry"]);
    if([p[@"excludeBollywood"]boolValue]&&([industry isEqual:@"bollywood"]||[industry isEqual:@"unknown"]||!industry.length))return NO;
    NSString *group=[self languageGroup:record];if(world)return [p[@"worldCinema"]boolValue]&&[group isEqual:@"world"];
    return [p[@"languageMode"]isEqual:@"all"]||[group isEqual:@"english"];
}
// Audience intent is a promotion preference, never an access/age restriction.
// Generic animation is not automatically a grown-up recommendation. Explicit
// adult-animation evidence remains eligible; search and library do not use this.
+ (BOOL)recommendationAudienceAllows:(NSDictionary *)meta preferences:(NSDictionary *)preferences restricted:(BOOL)restricted {
    return restricted||[[self preferences:preferences][@"recommendationAudience"]isEqual:@"all_ages"]||![self isFamilyTitle:meta];
}
+ (BOOL)isAdultAudience:(NSDictionary *)meta {
    for(NSDictionary *genre in A(D(meta[@"discovery"])[@"genres"]))if([T(D(genre)[@"id"])isEqual:@"Q138600175"])return YES;
    NSMutableArray *names=[NSMutableArray new];for(id g in A(meta[@"genres"]))if([g isKindOfClass:NSString.class])[names addObject:g];for(id g in A(D(meta[@"discovery"])[@"genres"]))if(T(D(g)[@"name"]).length)[names addObject:g[@"name"]];
    for(NSString *name in names){NSString *key=[[name lowercaseString]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if([@[@"adult animation",@"adult animated sitcom",@"adult cartoon",@"adult animated series"]containsObject:key])return YES;
    }return NO;
}
+ (BOOL)isChildFocused:(NSDictionary *)meta {
    if([self isAdultAudience:meta])return NO;
    NSMutableSet *names=[NSMutableSet new];for(id g in A(meta[@"genres"]))if([g isKindOfClass:NSString.class])[names addObject:[g lowercaseString]];
    for(NSDictionary *g in A(D(meta[@"discovery"])[@"genres"]))if(T(D(g)[@"name"]).length)[names addObject:[g[@"name"]lowercaseString]];
    // Family is broad permission. Lead a sparse Kids profile with positive
    // child audience/animation evidence; CGI nature documentaries stay separate.
    if([names containsObject:@"documentary"]||[names containsObject:@"nature documentary"]||[names containsObject:@"documentary television series"])return NO;
    for(NSString *name in names){NSString *key=[[name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]stringByReplacingOccurrencesOfString:@"’" withString:@"'"];
        if([@[@"kids",@"children",@"animation",@"animated",@"cartoon",@"anime",@"children's film",@"children's television series",@"children's television program",@"children's television programme",@"children's animated series",@"children's animation",@"children's comedy",@"animated television series",@"animated film",@"animated cartoon"]containsObject:key])return YES;
    }return NO;
}
+ (BOOL)isFamilyTitle:(NSDictionary *)meta {
    if([self isAdultAudience:meta])return NO;
    // Genre IDs remain meaningful when a label lookup is pending or absent.
    // Reviewed Wikidata concepts, not title-name or nationality heuristics.
    for(NSDictionary *genre in A(D(meta[@"discovery"])[@"genres"]))if([@[@"Q2143665",@"Q1273568",@"Q1361932",@"Q202866"]containsObject:T(D(genre)[@"id"])])return YES;
    // Positive title-level audience evidence. A provider's Family search result
    // is not evidence by itself, and this classification never grants an age rating.
    static NSSet *accepted;static dispatch_once_t once;dispatch_once(&once,^{accepted=[NSSet setWithArray:@[@"family",@"kids",@"children",@"animation",@"animated",@"cartoon",@"anime",@"children's film",@"children's television series",@"children's television program",@"children's television programme",@"children's animated series",@"children's animation",@"children's comedy",@"children's fiction",@"family film",@"family comedy",@"family television series",@"animated television series",@"animated film",@"animated cartoon"]];});
    NSMutableArray *names=[NSMutableArray new];for(id g in A(meta[@"genres"]))if([g isKindOfClass:NSString.class])[names addObject:g];for(id g in A(D(meta[@"discovery"])[@"genres"]))if(T(D(g)[@"name"]).length)[names addObject:g[@"name"]];
    for(NSString *name in names){NSString *key=[[[name lowercaseString]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]stringByReplacingOccurrencesOfString:@"’" withString:@"'"];if([accepted containsObject:key])return YES;}return NO;
}
+ (NSArray *)moods:(NSDictionary *)meta {
    NSMutableString *tags=[NSMutableString new];for(id genre in A(meta[@"genres"]))if([genre isKindOfClass:NSString.class])[tags appendFormat:@" %@",[genre lowercaseString]];
    NSDictionary *record=D(meta[@"discovery"]);for(NSString *field in @[@"genres",@"themes"])for(NSDictionary *ref in A(record[field]))[tags appendFormat:@" %@",[T(D(ref)[@"name"])lowercaseString]];
    BOOL thriller=[tags containsString:@"thriller"],mystery=[tags containsString:@"mystery"],scifi=[tags containsString:@"sci-fi"]||[tags containsString:@"science fiction"],crime=[tags containsString:@"crime"];
    NSMutableArray *out=[NSMutableArray new];
    if((thriller||mystery||scifi)&&([tags containsString:@"dream"]||[tags containsString:@"time travel"]||[tags containsString:@"parallel universe"]||[tags containsString:@"identity"]))[out addObject:@"Mind-bending"];
    if(crime&&(thriller||mystery))[out addObject:@"Crime & suspense"];
    if([tags containsString:@"adventure"]&&(scifi||[tags containsString:@"fantasy"]))[out addObject:@"Epic adventures"];
    if(([tags containsString:@"romantic comedy"]||[tags containsString:@"screwball"]||([tags containsString:@"family"]&&[tags containsString:@"comedy"]))&&!thriller&&!crime&&![tags containsString:@"horror"]&&![tags containsString:@"war"])[out addObject:@"Light-hearted"];
    if([tags containsString:@"biographical"]||[tags containsString:@"biography"]||[tags containsString:@"historical drama"])[out addObject:@"True stories"];
    return out;
}
@end
