#import <Foundation/Foundation.h>
#import "../RWSourceWork.h"
@interface CaptionSnapshotHarness:NSObject
@property NSMutableDictionary *exerciseRealCaptions;
- (NSDictionary *)snapshot;
@end
@implementation CaptionSnapshotHarness
- (NSDictionary *)snapshot {
#include "CaptionSnapshotUnderTest.inc"
}
@end
int main(){@autoreleasepool{
 int checks=0,failures=0;
#define CHECK(v) do{checks++;if(!(v)){failures++;fprintf(stderr,"FAIL snapshot line %d\n",__LINE__);}}while(0)
 CaptionSnapshotHarness *h=[CaptionSnapshotHarness new];NSMutableDictionary *selected=[@{@"language":@"",@"token":@"first"}mutableCopy];h.exerciseRealCaptions=[@{@"stage":@"middle",@"target":@3483,@"selected":selected}mutableCopy];NSDictionary *first=[h snapshot];h.exerciseRealCaptions[@"stage"]=@"end";h.exerciseRealCaptions[@"target"]=@6269;selected[@"token"]=@"second";NSDictionary *second=[h snapshot];
 CHECK([first[@"real_captions"][@"stage"]isEqual:@"middle"]);CHECK([first[@"real_captions"][@"target"]isEqual:@3483]);CHECK([first[@"real_captions"][@"selected"][@"token"]isEqual:@"first"]);CHECK([second[@"real_captions"][@"target"]isEqual:@6269]);
 [h.exerciseRealCaptions removeAllObjects];CHECK([second[@"real_captions"][@"selected"][@"token"]isEqual:@"second"]);CHECK([NSJSONSerialization isValidJSONObject:first]);h.exerciseRealCaptions=nil;CHECK([[h snapshot][@"real_captions"]isEqual:@{}]);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
