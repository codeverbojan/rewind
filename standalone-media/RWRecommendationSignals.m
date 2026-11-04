#import "RWRecommendationSignals.h"
#import "RWViewingSignals.h"
#include <math.h>
static NSString *RT(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static NSArray *RA(id x){return [x isKindOfClass:NSArray.class]?x:@[];}
static NSDictionary *RD(id x){return [x isKindOfClass:NSDictionary.class]?x:@{};}
static double RN(id x){double n=[x respondsToSelector:@selector(doubleValue)]?[x doubleValue]:0;return isfinite(n)?n:0;}
static NSString *RID(NSDictionary *m){return RT(m[@"id"]?:m[@"imdb_id"]);}
static double SignalDate(id value,double now){double date=RN(value);return date>0&&date<=now+86400?MIN(date,now):0;}
@implementation RWRecommendationSignals
+ (NSArray *)select:(NSDictionary *)profile now:(double)now allows:(BOOL(^)(NSDictionary *))permission {
    NSMutableArray *out=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new],*hidden=[NSMutableSet setWithArray:RA(profile[@"hidden"])];BOOL kids=RN(profile[@"maxAge"])>=0;
    BOOL(^allowed)(NSDictionary *)=^BOOL(NSDictionary *m){NSString *key=RID(m);return key.length&&[@[@"movie",@"series"]containsObject:RT(m[@"type"])]&&![hidden containsObject:key]&&(permission?permission(m):(!kids||[m[@"ageAllowed"]boolValue]))&&![m[@"technicalTest"]boolValue];};
    for(NSString *kind in @[@"liked",@"saved"]){NSUInteger added=0,cap=[kind isEqual:@"liked"]?12:6;NSArray *raw=RA(profile[kind]);NSEnumerator *order=[kind isEqual:@"liked"]?raw.reverseObjectEnumerator:raw.objectEnumerator;
        for(id value in order){NSDictionary *m=RD(value);NSString *key=RID(m);if(!allowed(m)||[seen containsObject:key])continue;[seen addObject:key];double at=SignalDate(m[[kind isEqual:@"liked"]?@"discoveryLikedAt":@"discoverySavedAt"],now),base=[kind isEqual:@"liked"]?3:2,halfLife=[kind isEqual:@"liked"]?365:180;
            double decay=at?MAX(.35,exp(-log(2)*MAX(0,now-at)/(halfLife*86400))):1;
            [out addObject:@{@"meta":m,@"kind":kind,@"weight":@(base*decay),@"at":@(at)}];if(++added==cap)break;
        }
    }
    // Deduplicate episodes by show identity before taking the history quota.
    // Pick the strongest meaningful record, using recency to break ties.
    NSComparisonResult(^signalOrder)(NSDictionary *,NSDictionary *)=^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSComparisonResult order=[b[@"weight"]compare:a[@"weight"]];if(order==NSOrderedSame)order=[b[@"at"]compare:a[@"at"]];return order==NSOrderedSame?[RID(a[@"meta"])compare:RID(b[@"meta"])]:order;};
    NSMutableDictionary *viewed=[NSMutableDictionary new];
    for(id historyKey in RD(profile[@"history"])){NSDictionary *record=RD(RD(profile[@"history"])[historyKey]),*m=RD(record[@"meta"]);NSString *key=RID(m);if(!allowed(m)||[seen containsObject:key]||[record[@"technicalTest"]boolValue]||![RWViewingSignals meaningful:record])continue;
        NSString *recordKey=RT(historyKey);double at=SignalDate(record[@"updated"],now),decay=at?exp(-log(2)*MAX(0,now-at)/(90*86400)):.5,weight=([RWViewingSignals finished:record]?1.5:.75)*decay;
        NSDictionary *old=viewed[key];if(weight<.05||(old&&([old[@"weight"]doubleValue]>weight||([old[@"weight"]doubleValue]==weight&&([old[@"at"]doubleValue]>at||([old[@"at"]doubleValue]==at&&[RT(old[@"recordKey"])compare:recordKey]!=NSOrderedDescending))))))continue;
        viewed[key]=@{@"meta":m,@"kind":@"watched",@"weight":@(weight),@"at":@(at),@"recordKey":recordKey};
        if(viewed.count>6){NSDictionary *last=[viewed.allValues sortedArrayUsingComparator:signalOrder].lastObject;[viewed removeObjectForKey:RID(last[@"meta"])];}
    }
    NSArray *ordered=[viewed.allValues sortedArrayUsingComparator:signalOrder];
    for(NSUInteger i=0;i<MIN((NSUInteger)6,ordered.count);i++)[out addObject:ordered[i]];
    return [out sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSComparisonResult order=[b[@"weight"]compare:a[@"weight"]];if(order==NSOrderedSame)order=[b[@"at"]compare:a[@"at"]];return order==NSOrderedSame?[RID(a[@"meta"])compare:RID(b[@"meta"])]:order;}];
}
@end
