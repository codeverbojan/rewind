#import <Foundation/Foundation.h>
// One automatic attempt per title/profile visit. Metadata/layout changes share
// the same session; terminal outcomes quietly keep artwork until another visit.
@interface RWPreviewSession : NSObject
@property(nonatomic,readonly) NSString *key;
@property(nonatomic,readonly) NSString *state;
@property(nonatomic,readonly) NSUInteger generation,attempts;
- (void)selectKey:(NSString *)key;
- (BOOL)beginAllowed:(BOOL)allowed visible:(BOOL)visible manual:(BOOL)manual;
- (BOOL)acceptSource:(BOOL)available generation:(NSUInteger)generation;
- (BOOL)beginNativeFallback;
- (BOOL)event:(NSString *)event generation:(NSUInteger)generation;
- (void)cancel;
- (NSDictionary *)diagnostics;
@end
