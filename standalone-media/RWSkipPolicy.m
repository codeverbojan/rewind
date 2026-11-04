#import "RWSkipPolicy.h"
@implementation RWSkipPolicy
+ (NSArray *)segments:(NSDictionary *)response imdb:(NSString *)imdb season:(NSInteger)season episode:(NSInteger)episode duration:(double)duration {
    if(![response isKindOfClass:NSDictionary.class]||![response[@"imdb_id"]isEqual:imdb]||![response[@"season"]isKindOfClass:NSNumber.class]||![response[@"episode"]isKindOfClass:NSNumber.class]||[response[@"season"]integerValue]!=season||[response[@"episode"]integerValue]!=episode||![response[@"media_type"]isEqual:@"tv"]||!isfinite(duration)||duration<=0)return @[];
    NSMutableArray *out=[NSMutableArray new];for(NSString *kind in @[@"recap",@"intro"]){id s=response[kind];if(![s isKindOfClass:NSDictionary.class])continue;
        BOOL valid=YES;for(NSString *k in @[@"start_sec",@"end_sec",@"confidence",@"submission_count"])if(![s[k]isKindOfClass:NSNumber.class])valid=NO;if(!valid)continue;
        double start=[s[@"start_sec"]doubleValue],end=[s[@"end_sec"]doubleValue],confidence=[s[@"confidence"]doubleValue];
        if(!isfinite(start)||!isfinite(end)||!isfinite(confidence)||start<0||start>1200||end>duration||end-start<5||end-start>([kind isEqual:@"intro"]?300:480)||confidence<.8||confidence>1||[s[@"submission_count"]integerValue]<1)continue;
        [out addObject:@{@"start":@(start),@"end":@(end),@"kind":kind,@"label":[kind isEqual:@"intro"]?@"Skip intro":@"Skip recap",@"source":@"IntroDB"}];
    }return out;
}
@end
