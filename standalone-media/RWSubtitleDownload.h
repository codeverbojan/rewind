#import <Foundation/Foundation.h>
// One bounded subtitle transfer. Completion always runs on main; cancel suppresses
// it even when a completion is already queued. No disk or URL cache is retained.
@interface RWSubtitleDownload : NSObject
- (instancetype)initWithURL:(NSURL *)url completion:(void(^)(NSData *data,NSString *error,NSDictionary *metrics))completion;
- (instancetype)initWithURL:(NSURL *)url configuration:(NSURLSessionConfiguration *)configuration completion:(void(^)(NSData *,NSString *,NSDictionary *))completion;
- (void)cancel;
@end
