#import "RWInteractionMetrics.h"
#include <math.h>
@implementation RWInteractionMetrics {NSMutableDictionary *_samples,*_totals,*_maxima;}
- (instancetype)init {if((self=[super init])){_samples=[NSMutableDictionary new];_totals=[NSMutableDictionary new];_maxima=[NSMutableDictionary new];}return self;}
- (void)add:(NSString *)kind seconds:(double)seconds context:(NSDictionary *)context {
    if(!isfinite(seconds)||seconds<0||!kind.length||kind.length>80)return;
    NSString *screen=[context[@"screen"]isKindOfClass:NSString.class]?context[@"screen"]:@"Unknown";if(screen.length>40)screen=@"Other";
    NSString *key=[screen stringByAppendingFormat:@"/%@",kind];NSMutableArray *bucket=_samples[key];
    // Surface names and kinds are internal constants, nevertheless bound the
    // number of buckets as well as each history.
    if(!bucket){if(_samples.count>=96)return;bucket=[NSMutableArray new];_samples[key]=bucket;}
    [bucket addObject:@(seconds)];NSUInteger limit=[kind isEqual:@"display_callback_interval"]?720:128;
    if(bucket.count>limit)[bucket removeObjectsInRange:NSMakeRange(0,bucket.count-limit)];
    _totals[key]=@([_totals[key]unsignedIntegerValue]+1);_maxima[key]=@(MAX(seconds,[_maxima[key]doubleValue]));
}
- (NSDictionary *)snapshot {NSMutableDictionary *samples=[NSMutableDictionary new];for(NSString *key in _samples)samples[key]=[_samples[key]copy];return @{@"samples":samples,@"totals":[_totals copy],@"maxima":[_maxima copy]};}
+ (NSDictionary *)summarize:(NSDictionary *)snapshot {
    NSMutableDictionary *result=[NSMutableDictionary new];for(NSString *key in snapshot[@"samples"]){NSArray *sorted=[snapshot[@"samples"][key]sortedArrayUsingSelector:@selector(compare:)];if(!sorted.count)continue;
        NSUInteger slow=0;for(NSNumber *n in sorted)if(n.doubleValue>.1)slow++;
        result[key]=@{@"window_samples":@(sorted.count),@"total_samples":snapshot[@"totals"][key]?:@0,@"p50_seconds":sorted[(NSUInteger)ceil(sorted.count*.50)-1],@"p95_seconds":sorted[(NSUInteger)ceil(sorted.count*.95)-1],@"window_max_seconds":sorted.lastObject,@"session_max_seconds":snapshot[@"maxima"][key]?:sorted.lastObject,@"window_over_100ms":@(slow)};
    }return result;
}
@end
