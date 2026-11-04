#import "RWListAnchor.h"
#include <math.h>
static NSString *LAID(id raw){id key=[raw isKindOfClass:NSDictionary.class]?raw[@"id"]:nil;return [key isKindOfClass:NSString.class]?key:@"";}
@implementation RWListAnchor
+ (NSDictionary *)capture:(NSArray *)items index:(NSUInteger)index delta:(double)delta {
    if(index>=items.count||!isfinite(delta))return nil;
    return @{@"id":LAID(items[index]),@"next":index+1<items.count?LAID(items[index+1]):@"",@"previous":index?LAID(items[index-1]):@"",@"index":@(index),@"delta":@(delta)};
}
+ (NSUInteger)index:(NSDictionary *)anchor items:(NSArray *)items {
    if(![anchor isKindOfClass:NSDictionary.class]||!items.count)return NSNotFound;
    for(NSString *field in @[@"id",@"next",@"previous"]){NSString *key=anchor[field];if(![key isKindOfClass:NSString.class]||!key.length)continue;
        for(NSUInteger i=0;i<items.count;i++)if([LAID(items[i])isEqual:key])return i;}
    id raw=anchor[@"index"];if(![raw isKindOfClass:NSNumber.class])return NSNotFound;
    return MIN(items.count-1,(NSUInteger)MAX(0,[raw integerValue]));
}
@end
