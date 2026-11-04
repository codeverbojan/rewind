#import <Foundation/Foundation.h>
// In-memory startup evidence only. Never writes raw URLs, headers or file paths.
@interface RWPreviewTrace : NSObject
- (void)record:(const char *)message module:(const char *)module level:(int)level;
- (NSDictionary *)snapshot;
@end
