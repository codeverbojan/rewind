#import <Foundation/Foundation.h>
@interface RWApplePreviewLookup : NSObject
@property(nonatomic,readonly) NSDictionary *diagnostics;
- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration;
- (void)resolve:(NSDictionary *)meta knownIDs:(NSArray *)ids done:(void(^)(NSDictionary *,NSString *))done;
- (void)resolveRating:(NSDictionary *)meta identifier:(NSString *)identifier done:(void(^)(NSDictionary *,NSString *))done;
// Reuses bounded classification transport; does not enable Disney trailer URLs.
- (void)resolveDisneyRating:(NSDictionary *)meta identifier:(NSString *)identifier done:(void(^)(NSDictionary *,NSString *))done;
- (void)resolveStoreRating:(NSDictionary *)meta done:(void(^)(NSDictionary *,NSString *))done;
- (void)cancel;
- (void)invalidate;
@end
