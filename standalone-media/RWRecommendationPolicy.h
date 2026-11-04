#import <Foundation/Foundation.h>
@interface RWRecommendationPolicy : NSObject
// Contextual details use evidence and relevance, independently of Home novelty.
+ (NSArray *)related:(NSArray *)items current:(NSDictionary *)current profile:(NSDictionary *)profile world:(BOOL)world now:(double)now limit:(NSUInteger)limit;
+ (NSDictionary *)relatedEvidence:(NSDictionary *)candidate current:(NSDictionary *)current;
// Bounded diagnostic evidence for offline calibration; never a user match percentage.
+ (NSDictionary *)interestDiagnostics:(NSArray *)items profile:(NSDictionary *)profile now:(double)now;
+ (NSSet *)homeExcludedIDsForProfile:(NSDictionary *)profile;
+ (double)quality:(NSDictionary *)meta prior:(double)prior;
+ (BOOL)homePendingEligible:(NSDictionary *)meta now:(double)now;
+ (BOOL)homeQualityEligible:(NSDictionary *)meta;
+ (NSArray *)homeRefreshCandidates:(NSArray *)items profile:(NSDictionary *)profile now:(double)now;
+ (NSArray *)rank:(NSArray *)items current:(NSDictionary *)current profile:(NSDictionary *)profile world:(BOOL)world requireAvailability:(BOOL)requireAvailability now:(double)now limit:(NSUInteger)limit;
+ (NSDictionary *)home:(NSArray *)items profile:(NSDictionary *)profile year:(NSInteger)year now:(double)now;
@end
