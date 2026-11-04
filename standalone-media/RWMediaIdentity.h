#import <Foundation/Foundation.h>
#include <math.h>

// Provider catalogs occasionally label an episode-bearing show as a movie.
// Correct only an exact title/season/episode identity, never a genre or year hint.
static inline BOOL RWHasSeriesIdentity(NSDictionary *record, NSString *identifier) {
    if(![record isKindOfClass:NSDictionary.class]||!identifier.length)return NO;
    id key=record[@"id"]?:record[@"imdb_id"];
    if(![key isEqual:identifier]||![record[@"videos"]isKindOfClass:NSArray.class])return NO;
    NSUInteger read=0;
    for(id raw in record[@"videos"]){
        if(read++==10000)break;if(![raw isKindOfClass:NSDictionary.class])continue;
        id season=raw[@"season"],episode=raw[@"episode"];
        if(![season isKindOfClass:NSNumber.class]||![episode isKindOfClass:NSNumber.class])continue;
        double s=[season doubleValue],e=[episode doubleValue];
        if(!isfinite(s)||!isfinite(e)||s<0||s>100||e<1||e>2000||floor(s)!=s||floor(e)!=e)continue;
        NSString *video=[NSString stringWithFormat:@"%@:%ld:%ld",identifier,(long)s,(long)e];
        if([raw[@"id"]isEqual:video])return YES;
    }return NO;
}
static inline NSDictionary *RWNormalizeMediaIdentity(NSDictionary *meta, NSDictionary *show) {
    if(![meta isKindOfClass:NSDictionary.class]||![meta[@"type"]isEqual:@"movie"])return meta;
    id identifier=meta[@"id"]?:meta[@"imdb_id"];
    if(![identifier isKindOfClass:NSString.class]||(!RWHasSeriesIdentity(meta,identifier)&&!RWHasSeriesIdentity(show,identifier)))return meta;
    NSMutableDictionary *copy=[meta mutableCopy];copy[@"type"]=@"series";
    // Movie evidence cannot qualify any episode of the corrected series.
    for(NSString *field in @[@"availability",@"episodeVideoID",@"episodeCaption",@"season",@"episode",@"ageAllowed",@"homePreparationPending"])[copy removeObjectForKey:field];
    return copy;
}
