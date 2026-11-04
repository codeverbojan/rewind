#import "RWViewingSignals.h"
#include <math.h>
@implementation RWViewingSignals
+ (NSDictionary *)merge:(NSDictionary *)previous metrics:(NSDictionary *)metrics duration:(double)duration {
    NSString *session=[metrics[@"session_id"]isKindOfClass:NSString.class]?metrics[@"session_id"]:@"";
    double seconds=[metrics[@"playing_seconds_estimate"]doubleValue];
    if(!session.length||!isfinite(seconds)||seconds<0)return @{};
    double prior=[previous[@"watchSeconds"]doubleValue],last=[previous[@"watchSession"]isEqual:session]?[previous[@"watchSessionSeconds"]doubleValue]:0;
    if(!isfinite(prior)||prior<0)prior=0;if(!isfinite(last)||last<0)last=0;
    double total=MIN(7*86400,prior+MAX(0,seconds-last));
    return @{@"watchSeconds":@(total),@"watchSession":session,@"watchSessionSeconds":@(MAX(seconds,last)),@"watchSignalVersion":@1};
}
+ (BOOL)meaningful:(NSDictionary *)record {
    double seconds=[record[@"watchSeconds"]doubleValue],duration=[record[@"duration"]doubleValue];
    double required=duration>0?MIN(300,MAX(30,duration*.25)):300;
    return [record[@"watchSignalVersion"]integerValue]==1&&isfinite(seconds)&&seconds>=required;
}
+ (BOOL)finished:(NSDictionary *)record {
    double duration=[record[@"duration"]doubleValue];
    return [self meaningful:record]&&[record[@"completed"]boolValue]&&duration>0&&[record[@"watchSeconds"]doubleValue]>=duration*.7;
}
@end
