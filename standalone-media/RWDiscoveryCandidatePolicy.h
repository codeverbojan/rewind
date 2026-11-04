#import <Foundation/Foundation.h>
// Bounded, profile-local acquisition plan. A candidate is not playback evidence.
@interface RWDiscoveryCandidatePolicy : NSObject
+ (NSDictionary *)plan:(NSArray *)anchors state:(NSDictionary *)state restricted:(BOOL)restricted now:(double)now year:(NSInteger)year;
+ (NSDictionary *)finish:(NSDictionary *)plan next:(NSDictionary *)next error:(NSString *)error now:(double)now;
+ (NSArray *)verifiedItems:(NSArray *)items plan:(NSDictionary *)plan;
@end
