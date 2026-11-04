#import <Foundation/Foundation.h>
static NSString *RWID(NSDictionary *m){return m[@"id"]?:@"";}
@interface RewindStore:NSObject
@property NSDictionary *state;
@property NSMutableArray *pending;
@property(readonly) RewindStore *discoveryMetadata;
+ (instancetype)shared;
- (NSDictionary *)enrich:(NSDictionary *)m;
- (NSDictionary *)discoveryMeta:(NSDictionary *)m;
- (void)relatedTitles:(NSDictionary *)m done:(void(^)(NSArray *))done;
@end
@implementation RewindStore
+ (instancetype)shared{static RewindStore *s;static dispatch_once_t once;dispatch_once(&once,^{s=[self new];s.pending=[NSMutableArray new];});return s;}
- (RewindStore *)discoveryMetadata{return self;}
- (NSDictionary *)enrich:(NSDictionary *)m{return m;}
- (NSDictionary *)discoveryMeta:(NSDictionary *)m{return m;}
- (void)relatedTitles:(NSDictionary *)m done:(void(^)(NSArray *))done{[self.pending addObject:[done copy]];}
@end
@interface RewindController:NSObject
@property BOOL reviewMode;
@property NSString *page,*relatedKey;
@property NSDictionary *detail;
@property NSArray *relatedTitles;
@property NSUInteger relatedGeneration,renders;
@end
@implementation RewindController
- (void)requestDetailRender{self.renders++;}
#include "../RewindDetailRelated.inc"
@end
int main(){@autoreleasepool{int checks=0,failures=0;
#define C(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL %d\n",__LINE__);}}while(0)
 RewindStore *s=[RewindStore shared];s.state=@{@"activeProfile":@"main"};RewindController *c=[RewindController new];c.page=@"Details";c.detail=@{@"id":@"series",@"type":@"series"};
 [c requestRelatedTitles];C(s.pending.count==1);[c requestRelatedTitles];C(s.pending.count==1);
 NSDictionary *full=@{@"id":@"series",@"type":@"series",@"genres":@[@"Mystery",@"Sci-Fi"]};
 [c acceptDetailResult:full profile:@"main" identifier:@"series"];C(s.pending.count==2);C(c.relatedKey.length>0);C(c.relatedGeneration==2);
 void(^old)(NSArray *)=s.pending[0];old(@[@{@"id":@"stale"}]);C(c.relatedTitles.count==0);
 if(s.pending.count>1){void(^fresh)(NSArray *)=s.pending[1];fresh(@[@{@"id":@"relevant"}]);C([c.relatedTitles[0][@"id"]isEqual:@"relevant"]);}
 [c acceptDetailResult:full profile:@"main" identifier:@"series"];C(s.pending.count==2);
 [c acceptDetailResult:@{@"id":@"wrong"} profile:@"kids" identifier:@"series"];C([c.detail isEqual:full]);
 [c acceptDetailResult:@{@"id":@"wrong"} profile:@"main" identifier:@"different"];C([c.detail isEqual:full]);
 c.page=@"Home";[c acceptDetailResult:@{@"id":@"series",@"name":@"late"} profile:@"main" identifier:@"series"];C([c.detail isEqual:full]);
 C([s.state[@"activeProfile"]isEqual:@"main"]);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
