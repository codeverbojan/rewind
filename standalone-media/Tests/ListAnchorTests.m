#import "../RWListAnchor.h"
#include <math.h>
static int checks,failures;
#define C(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"line%d\n",__LINE__);}}while(0)
int main(){@autoreleasepool{
 NSArray *items=@[@{@"id":@"a"},@{@"id":@"b"},@{@"id":@"c"},@{@"id":@"d"}];
 NSDictionary *a=[RWListAnchor capture:items index:1 delta:28];C([a[@"id"]isEqual:@"b"]);C([a[@"delta"]doubleValue]==28);C([RWListAnchor index:a items:items]==1);
 C([RWListAnchor index:a items:@[items[3],items[0],items[2],items[1]]]==3);
 C([RWListAnchor index:a items:@[items[0],items[2],items[3]]]==1); // Deleted anchor -> next title.
 C([RWListAnchor index:a items:@[items[3],items[0]]]==1); // Next deleted too -> previous.
 C([RWListAnchor index:a items:@[@{@"id":@"e"}]]==0);
 C([RWListAnchor index:a items:@[]]==NSNotFound);C([RWListAnchor index:nil items:items]==NSNotFound);
 C(![RWListAnchor capture:items index:4 delta:0]);C(![RWListAnchor capture:items index:0 delta:NAN]);
 NSDictionary *first=[RWListAnchor capture:items index:0 delta:-10],*last=[RWListAnchor capture:items index:3 delta:10];C([first[@"previous"]isEqual:@""]);C([last[@"next"]isEqual:@""]);
 C([RWListAnchor index:last items:@[items[0],items[1],items[2]]]==2);C([RWListAnchor index:@{@"index":@(-2)} items:items]==0);
 C([RWListAnchor index:@{@"id":@123,@"index":@1} items:items]==1);C([RWListAnchor index:@{} items:items]==NSNotFound);
 // Same selected title lands in its new row when columns change. The UIKit
 // adapter applies delta to the actual new layout, not the old pixel offset.
 NSMutableArray *many=[NSMutableArray new];for(int i=0;i<48;i++)[many addObject:@{@"id":[NSString stringWithFormat:@"title%d",i]}];
 NSDictionary *rotation=[RWListAnchor capture:many index:20 delta:15];NSUInteger index=[RWListAnchor index:rotation items:many];C(index==20);C(index/5==4&&index/4==5);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
