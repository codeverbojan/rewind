#import <Foundation/Foundation.h>
// Shared bounded feedback selection, before metadata work and during ranking.
// permission may supply the current age gate for an unenriched snapshot.
@interface RWRecommendationSignals : NSObject
+ (NSArray *)select:(NSDictionary *)profile now:(double)now allows:(BOOL(^)(NSDictionary *meta))permission;
@end
