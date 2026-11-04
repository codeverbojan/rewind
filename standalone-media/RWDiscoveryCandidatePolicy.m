#import "RWDiscoveryCandidatePolicy.h"
static NSDictionary *CD(id x){return [x isKindOfClass:NSDictionary.class]?x:@{};}
static NSArray *CA(id x){return [x isKindOfClass:NSArray.class]?x:@[];}
static NSString *CT(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static BOOL CQ(id x){return [CT(x) rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location==0;}
static BOOL CI(id x){return [CT(x) rangeOfString:@"^tt[0-9]+$" options:NSRegularExpressionSearch].location==0;}
static BOOL CV(NSDictionary *m){NSDictionary *d=CD(m[@"discovery"]);return CI(m[@"id"])&&[d[@"imdb"]isEqual:m[@"id"]]&&CQ(d[@"entityID"])&&[d[@"source"]isEqual:[@"https://www.wikidata.org/wiki/" stringByAppendingString:CT(d[@"entityID"])]];}
static NSDictionary *Cursor(id raw){NSDictionary *d=CD(raw);id offset=d[@"sroffset"];NSString *token=CT(d[@"continue"]);if(![offset isKindOfClass:NSNumber.class]||[offset longLongValue]<0||token.length>128)return @{};return token.length?@{@"sroffset":offset,@"continue":token}:@{@"sroffset":offset};}
@implementation RWDiscoveryCandidatePolicy
+ (NSDictionary *)plan:(NSArray *)input state:(NSDictionary *)raw restricted:(BOOL)restricted now:(double)now year:(NSInteger)year {
    NSDictionary *old=CD(raw);double at=[old[@"at"]doubleValue];if(at>0&&now>=at&&now-at<3600)return nil;
    NSUInteger turn=[old[@"turn"]unsignedIntegerValue]%1000000;NSMutableArray *anchors=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(id rawTitle in CA(input)){NSDictionary *m=CD(rawTitle);if(!CI(m[@"id"])||![@[@"movie",@"series"]containsObject:m[@"type"]]||[seen containsObject:m[@"id"]])continue;[anchors addObject:m];[seen addObject:m[@"id"]];if(anchors.count==6)break;}
    NSUInteger index=turn%MAX((NSUInteger)1,anchors.count),cycle=turn/MAX((NSUInteger)1,anchors.count),mode=(cycle+index)%3;
    NSDictionary *anchor=anchors.count?anchors[index]:@{};NSString *type=CT(anchor[@"type"]);if(!type.length)type=turn%2?@"series":@"movie";
    NSMutableDictionary *pages=[NSMutableDictionary new];for(id key in CD(old[@"pages"])){NSDictionary *p=CD(old[@"pages"][key]);if(CT(key).length<=100&&CT(key).length&&([p[@"exhausted"]boolValue]||Cursor(p[@"next"]).count))pages[key]=p;}
    NSArray *order=[pages keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [b[@"at"]?:@0 compare:a[@"at"]?:@0];}];for(NSUInteger i=24;i<order.count;i++)[pages removeObjectForKey:order[i]];
    NSMutableDictionary *state=[@{@"at":@(now),@"turn":@(turn+1),@"pages":pages}mutableCopy];
    NSString *genre=restricted?@"Family":CT(CA(anchor[@"genres"]).firstObject);
    NSMutableDictionary *plan=[@{@"kind":@"catalog",@"type":type,@"genre":genre,@"sort":@[@"Popular",@"Newest",@"Top rated"][(cycle/3)%3],@"year":@(mode==2?MAX(1900,year-10-(NSInteger)((cycle/3)%5)*10):0),@"anchor":CT(anchor[@"id"]),@"state":state}mutableCopy];
    if(mode!=0||!CV(anchor))return plan;
    NSDictionary *metadata=CD(anchor[@"discovery"]);NSMutableArray *relations=[NSMutableArray new];
    // Interleave roles, then second credits; avoid locking one anchor to one role.
    for(NSUInteger n=0;n<2;n++)for(NSArray *pair in @[@[@"director",@"directors"],@[@"studio",@"studios"],@[@"cast",@"cast"]]){NSArray *refs=CA(metadata[pair[1]]);if(n>=refs.count)continue;NSDictionary *ref=CD(refs[n]);if(!CQ(ref[@"id"])||![ref[@"provider"]isEqual:@"Wikidata"])continue;[relations addObject:@{@"entity":ref[@"id"],@"role":pair[0]}];}
    for(NSUInteger n=0;n<relations.count;n++){NSDictionary *r=relations[((cycle/3)+n)%relations.count];NSString *key=[NSString stringWithFormat:@"%@:%@:%@",r[@"role"],r[@"entity"],type];NSDictionary *page=CD(pages[key]);double age=now-[page[@"at"]doubleValue];if([page[@"exhausted"]boolValue]&&age>=0&&age<7*86400)continue;
        plan[@"kind"]=@"credits";plan[@"entity"]=r[@"entity"];plan[@"role"]=r[@"role"];plan[@"key"]=key;plan[@"continuation"]=[page[@"exhausted"]boolValue]?@{}:Cursor(page[@"next"]);break;
    }return plan;
}
+ (NSDictionary *)finish:(NSDictionary *)plan next:(NSDictionary *)next error:(NSString *)error now:(double)now {
    NSMutableDictionary *state=[CD(plan[@"state"])mutableCopy];if(error.length||![plan[@"kind"]isEqual:@"credits"])return state;
    NSDictionary *cursor=Cursor(next);if(CD(next).count&&(!cursor.count||[cursor[@"sroffset"]longLongValue]<=[CD(plan[@"continuation"])[@"sroffset"]longLongValue]))return state;
    NSMutableDictionary *pages=[CD(state[@"pages"])mutableCopy];NSString *key=CT(plan[@"key"]);if(!key.length)return state;pages[key]=@{@"at":@(now),@"next":cursor,@"exhausted":@(!cursor.count)};
    NSArray *order=[pages keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [b[@"at"]?:@0 compare:a[@"at"]?:@0];}];for(NSUInteger i=24;i<order.count;i++)[pages removeObjectForKey:order[i]];state[@"pages"]=pages;return state;
}
+ (NSArray *)verifiedItems:(NSArray *)items plan:(NSDictionary *)plan {
    NSMutableArray *out=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];for(id raw in CA(items)){NSDictionary *m=CD(raw);NSString *key=CT(m[@"id"]);if(!CV(m)||![m[@"type"]isEqual:plan[@"type"]]||![m[@"creditEntityID"]isEqual:plan[@"entity"]]||![m[@"creditRole"]isEqual:plan[@"role"]]||[seen containsObject:key]||[key isEqual:plan[@"anchor"]])continue;
        NSString *field=[plan[@"role"]isEqual:@"director"]?@"directors":[plan[@"role"]isEqual:@"studio"]?@"studios":@"cast";BOOL exact=NO;for(id rawRef in CA(CD(m[@"discovery"])[field])){NSDictionary *r=CD(rawRef);if([r[@"provider"]isEqual:@"Wikidata"]&&[r[@"id"]isEqual:plan[@"entity"]])exact=YES;}if(!exact)continue;
        // Whitelist metadata. No remote result can manufacture local health/offline evidence.
        NSMutableDictionary *clean=[NSMutableDictionary new];for(NSString *field in @[@"id",@"type",@"name",@"releaseInfo",@"discovery",@"creditEntityID",@"creditRole"])if(m[field])clean[field]=m[field];[out addObject:clean];[seen addObject:key];if(out.count==8)break;
    }return out;
}
@end
