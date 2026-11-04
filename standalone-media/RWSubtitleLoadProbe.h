#import <Foundation/Foundation.h>
@interface RWSubtitleLoadProbe : NSObject
// Diagnostic worker; bounded original text, production parser and lookup.
+ (NSDictionary *)runCancelled:(BOOL(^)(void))cancelled;
@end
