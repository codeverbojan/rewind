#import <Foundation/Foundation.h>
@interface TestFeed:NSObject
@property(nonatomic,copy) NSString *context;
@end
@implementation TestFeed
@end
@interface TestRail:NSObject
@property(nonatomic,strong) TestFeed *feed;
@property(nonatomic,strong) NSDictionary *anchor;
@property(nonatomic,copy) void(^onCancel)(void);
@property(nonatomic,assign) NSUInteger cancellations;
- (NSDictionary *)positionAnchor;
- (void)cancelVisibleArtwork;
@end
@implementation TestRail
- (NSDictionary *)positionAnchor{return self.anchor;}
- (void)cancelVisibleArtwork{_cancellations++;if(self.onCancel)self.onCancel();}
@end
@interface UITableView:NSObject
@end
@implementation UITableView
@end
@interface UITableViewCell:NSObject
@end
@implementation UITableViewCell
@end
@interface RWHomeShelf:UITableViewCell
@property(nonatomic,copy) NSString *identity,*rowIdentifier,*feedContext;
@property(nonatomic,strong) TestRail *rail;
@end
@implementation RWHomeShelf
@end
@interface HomeHarness:NSObject
@property(nonatomic,copy) NSString *scope;
@property(nonatomic,copy) void(^onAnchor)(NSString *,NSDictionary *);
- (NSString *)key:(NSDictionary *)row;
- (void)saveAnchorForShelf:(RWHomeShelf *)cell;
- (void)tableView:(UITableView *)table didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)path;
@end
@implementation HomeHarness
- (NSString *)key:(NSDictionary *)row{return [NSString stringWithFormat:@"%@:%@",self.scope?:@"",row[@"id"]];}
#include "../RWHomeAnchorLifecycle.inc"
@end
static int checks,failures;
#define C(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"line%d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
int main(){@autoreleasepool{
 HomeHarness *view=[HomeHarness new];view.scope=@"kids:All";
 RWHomeShelf *cell=[RWHomeShelf new];cell.identity=@"kids:All:adventures";cell.rowIdentifier=@"adventures";cell.feedContext=@"kids-feed:adventures";
 cell.rail=[TestRail new];cell.rail.feed=[TestFeed new];cell.rail.feed.context=cell.feedContext;
 __block NSUInteger saves=0;__block NSString *savedRow=nil;__block NSDictionary *saved=nil;
 view.onAnchor=^(NSString *row,NSDictionary *anchor){saves++;savedRow=row;saved=anchor;};
 // Settling can precede the async metadata window. No record means no save.
 [view saveAnchorForShelf:cell];C(saves==0);
 // Metadata arrives after settling. Leaving the shelf must save the now-known
 // title before releasing the cells, independent of its old table index.
 cell.rail.anchor=@{@"id":@"tt3521164",@"delta":@170};
 cell.rail.onCancel=^{C(saves==1);C([saved isEqual:cell.rail.anchor]);};
 [view tableView:nil didEndDisplayingCell:cell forRowAtIndexPath:[NSIndexPath indexPathWithIndex:99]];
 C(saves==1&&[savedRow isEqual:@"adventures"]);C(cell.rail.cancellations==1);cell.rail.onCancel=nil;
 // An old profile's disappearing cell cannot save into the new profile.
 view.scope=@"main:All";[view tableView:nil didEndDisplayingCell:cell forRowAtIndexPath:nil];C(saves==1);C(cell.rail.cancellations==2);
 view.scope=@"kids:All";cell.rail.feed.context=@"main-feed:adventures";[view saveAnchorForShelf:cell];C(saves==1);
 cell.rail.feed.context=cell.feedContext;cell.rail.anchor=nil;[view saveAnchorForShelf:cell];C(saves==1);
 cell.rail.anchor=@{@"id":@"tt0398286",@"delta":@24};[view saveAnchorForShelf:cell];C(saves==2&&[saved[@"id"]isEqual:@"tt0398286"]);
 cell.rail.feed=nil;[view saveAnchorForShelf:cell];C(saves==2);
 [view tableView:nil didEndDisplayingCell:[UITableViewCell new] forRowAtIndexPath:nil];C(saves==2);
 view.onAnchor=nil;[view saveAnchorForShelf:cell];C(saves==2);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
