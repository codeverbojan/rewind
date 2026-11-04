#import "RWLibraryPolicy.h"
static NSString *ID(NSDictionary *m){id v=m[@"id"]?:m[@"imdb_id"];return [v isKindOfClass:NSString.class]?v:@"";}
static NSArray *Genres(NSDictionary *m){return [m[@"genres"]isKindOfClass:NSArray.class]?m[@"genres"]:@[];}
@implementation RWLibraryPolicy
+ (NSArray *)recommend:(NSArray *)items current:(NSDictionary *)current history:(NSArray *)history saved:(NSArray *)saved hidden:(NSArray *)hidden limit:(NSUInteger)limit {
    NSMutableSet *excluded=[NSMutableSet setWithArray:hidden?:@[]];if(ID(current).length)[excluded addObject:ID(current)];
    NSMutableDictionary *weights=[NSMutableDictionary new];
    for(NSDictionary *m in saved)for(NSString *g in Genres(m))weights[g]=@([weights[g]doubleValue]+1);
    for(NSString *g in Genres(current))weights[g]=@([weights[g]doubleValue]+4);
    for(NSDictionary *r in history){NSDictionary *m=r[@"meta"];if([r[@"completed"]boolValue]||[r[@"position"]doubleValue]>30)[excluded addObject:ID(m)];
        double duration=[r[@"duration"]doubleValue],fraction=duration>0?MIN(1,[r[@"position"]doubleValue]/duration):0;
        for(NSString *g in Genres(m))weights[g]=@([weights[g]doubleValue]+MIN(4,fraction*4));
    }
    NSMutableArray *pool=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(id item in items){if(![item isKindOfClass:NSDictionary.class])continue;NSString *key=ID(item);if(!key.length||[excluded containsObject:key]||[seen containsObject:key])continue;[seen addObject:key];[pool addObject:item];}
    NSMutableArray *result=[NSMutableArray new];NSMutableDictionary *counts=[NSMutableDictionary new];
    while(pool.count&&result.count<limit){NSUInteger best=0;double bestScore=-1e9;
        for(NSUInteger i=0;i<pool.count;i++){NSDictionary *m=pool[i];double score=[m[@"imdbRating"]doubleValue]*.15;
            for(NSString *g in Genres(m))score+=[weights[g]doubleValue]-[counts[g]doubleValue]*2;
            if(score>bestScore){bestScore=score;best=i;}}
        NSDictionary *chosen=pool[best];[result addObject:chosen];[pool removeObjectAtIndex:best];for(NSString *g in Genres(chosen))counts[g]=@([counts[g]integerValue]+1);
    }return result;
}
@end
