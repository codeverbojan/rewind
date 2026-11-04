#import <Foundation/Foundation.h>
// Bounded, cancellable header inspection. It never downloads a complete movie.
@interface RWRemoteMKVProbe : NSObject
- (instancetype)initWithURL:(NSURL *)url completion:(void(^)(NSDictionary *media,NSURL *resolvedURL,NSString *error))completion;
- (instancetype)initWithURL:(NSURL *)url configuration:(NSURLSessionConfiguration *)configuration completion:(void(^)(NSDictionary *media,NSURL *resolvedURL,NSString *error))completion;
- (void)cancel;
@end
