#import <Foundation/Foundation.h>
// Main-thread API, shared metadata admission, bounded response buffering.
@interface RWCatalogSearch : NSObject
+ (NSURLSessionConfiguration *)sessionConfiguration;
- (instancetype)initWithURLCache:(NSURLCache *)cache;
+ (NSURL *)URLForType:(NSString *)type query:(NSString *)query;
- (NSURLSessionDataTask *)searchType:(NSString *)type query:(NSString *)query done:(void(^)(NSArray *,NSString *))done;
- (void)cancel:(NSURLSessionTask *)task;
- (void)clearCache;
- (void)invalidate;
@property(nonatomic,readonly) NSDictionary *diagnostics;
@end
