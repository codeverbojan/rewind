#import <Foundation/Foundation.h>
#include <math.h>
// A refresh may enrich an existing handle, but cannot change its file identity.
static inline NSDictionary *RWMergeSourceHints(NSDictionary *existing,NSDictionary *fresh) {
    id a=existing[@"infoHash"],b=fresh[@"infoHash"];
    if(![a isKindOfClass:NSString.class]||![b isKindOfClass:NSString.class]||![a isEqual:b])return existing;
    NSInteger first=[existing[@"fileIdx"]isKindOfClass:NSNumber.class]?[existing[@"fileIdx"]integerValue]:-1;
    NSInteger second=[fresh[@"fileIdx"]isKindOfClass:NSNumber.class]?[fresh[@"fileIdx"]integerValue]:-1;
    if(first!=second)return existing;
    NSMutableDictionary *merged=[existing mutableCopy];
    for(NSString *key in @[@"durationHintSeconds",@"score",@"seeders"]){
        id value=fresh[key];if(![value isKindOfClass:NSNumber.class]||!isfinite([value doubleValue]))continue;
        double n=[value doubleValue];
        if([key isEqual:@"durationHintSeconds"]&&(n<=0||n>86400))continue;
        if([key isEqual:@"seeders"]&&(n<0||n>1000000))continue;
        merged[key]=value;
    }
    if([fresh[@"metadataURL"]isKindOfClass:NSString.class]&&[fresh[@"metadataURL"]length])merged[@"metadataURL"]=fresh[@"metadataURL"];
    return merged;
}
