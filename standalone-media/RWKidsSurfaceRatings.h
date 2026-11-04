#import "RWRatings.h"
// One explicit, owned foreground diagnostic only. Never persists overrides.
@interface RWKidsSurfaceRatings : RWRatings
@property(nonatomic,strong) RWRatings *original;
@property(nonatomic,strong) NSMutableDictionary *overrides;
@property(nonatomic,copy) NSString *run;
@property(nonatomic,assign) NSInteger build;
@end
