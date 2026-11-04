#import <Foundation/Foundation.h>
@interface RWIMDbIndex : NSObject <NSURLSessionDownloadDelegate>
- (instancetype)initWithFolder:(NSString *)folder bundled:(NSString *)bundled;
@property(atomic,assign) BOOL paused;
@property(nonatomic,readonly) NSDictionary *diagnostics;
// Bounded local lookup: 500 candidates + one detail anchor + 24 feedback IDs.
- (void)ratingsForIDs:(NSArray *)ids done:(void(^)(NSDictionary *))done;
- (void)refreshIfNeeded;
+ (NSDictionary *)importGzip:(NSString *)gzipPath destination:(NSString *)destination cancelled:(BOOL(^)(void))cancelled;
+ (NSDictionary *)importGzip:(NSString *)gzipPath destination:(NSString *)destination maximumBytes:(unsigned long long)maximumBytes cancelled:(BOOL(^)(void))cancelled;
+ (NSDictionary *)updateBudgetForFolder:(NSString *)folder bundled:(NSString *)bundled downloadBytes:(unsigned long long)downloadBytes;
@end
