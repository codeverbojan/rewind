#import <Foundation/Foundation.h>
static NSString *RWID(NSDictionary *m){return m[@"id"]?:@"";}
@interface RewindStore:NSObject
@property NSDictionary *state,*profile;
+ (instancetype)shared;
- (BOOL)allowed:(NSDictionary *)meta;
@end
@implementation RewindStore
+ (instancetype)shared {static RewindStore *s;static dispatch_once_t once;dispatch_once(&once,^{s=[self new];});return s;}
- (BOOL)allowed:(NSDictionary *)meta{return ![meta[@"denied"]boolValue];}
@end
@interface Controller:NSObject
@property NSString *page,*detailTab,*relatedKey;
@property NSDictionary *detail;
@property NSArray *relatedTitles;
@property NSUInteger relatedGeneration;
@end
@implementation Controller
#include "../RewindDetailNavigation.inc"
@end
int main(){@autoreleasepool{int checks=0,failures=0;
#define C(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL %d\n",__LINE__);}}while(0)
 RewindStore *s=[RewindStore shared];s.state=@{@"activeProfile":@"main"};s.profile=@{@"hidden":@[@"hidden"]};
 Controller *c=[Controller new];c.page=@"Details";c.detail=@{@"id":@"origin",@"type":@"series"};c.detailTab=@"More like this";
 NSDictionary *good=@{@"id":@"good",@"type":@"series"};c.relatedTitles=@[good,@{@"id":@"hidden",@"type":@"series"},@{@"id":@"denied",@"type":@"series",@"denied":@YES},@{@"id":@"movie",@"type":@"movie"},c.detail,good];
 NSDictionary *saved=[c detailNavigationSnapshot];C([saved[@"related"]count]==6);c.relatedTitles=@[];c.relatedKey=@"stale";
 [c restoreDetailNavigation:saved];C([c.relatedTitles isEqual:@[good]]);C([c.detailTab isEqual:@"More like this"]);C(!c.relatedKey&&c.relatedGeneration==1);
 s.state=@{@"activeProfile":@"kids"};[c restoreDetailNavigation:saved];C(!c.relatedTitles.count&&[c.detailTab isEqual:@"Episodes"]);
 s.state=@{@"activeProfile":@"main"};c.detail=@{@"id":@"other",@"type":@"series"};[c restoreDetailNavigation:saved];C(!c.relatedTitles.count);
 [c restoreDetailNavigation:nil];C(!c.relatedTitles.count&&!c.relatedKey);
 c.page=@"Entity";C(![c detailNavigationSnapshot].count);
 c.page=@"Details";NSMutableArray *many=[NSMutableArray new];for(int i=0;i<50;i++)[many addObject:@{@"id":[NSString stringWithFormat:@"item%d",i],@"type":@"series"}];c.relatedTitles=many;c.detailTab=@"invalid";saved=[c detailNavigationSnapshot];C([saved[@"related"]count]==24);[c restoreDetailNavigation:saved];C(c.relatedTitles.count==24&&[c.detailTab isEqual:@"Episodes"]);
 C(many.count==50);C([s.state[@"activeProfile"]isEqual:@"main"]);C([s.profile[@"hidden"]isEqual:@[@"hidden"]]);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
