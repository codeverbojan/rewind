#import <Foundation/Foundation.h>
#include <math.h>
static inline NSString *RWWorldCatalogQuery(void) {
    return @"haswbstatement:P31=Q11424 haswbstatement:P345 haswbstatement:P364 -haswbstatement:P364=Q1860 -haswbstatement:P364=Q7976 -haswbstatement:P364=Q7979";
}
// Search continuation measures provider results, not the number of films that
// survive language/identity filtering. Keep its offset and opaque token together.
static inline NSDictionary *RWWorldCursor(id raw) {
    if(![raw isKindOfClass:NSDictionary.class])return nil;
    if(![raw count])return @{};
    id offset=raw[@"sroffset"],token=raw[@"continue"];
    if(![offset isKindOfClass:NSNumber.class]||![token isKindOfClass:NSString.class]||![token length]||[token length]>128)return nil;
    double value=[offset doubleValue];if(!isfinite(value)||value<=0||value>10000||floor(value)!=value)return nil;
    return @{@"sroffset":offset,@"continue":token};
}
