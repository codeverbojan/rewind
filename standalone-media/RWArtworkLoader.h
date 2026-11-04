#import <Foundation/Foundation.h>
// All I/O, decoding, transfer scheduling and cache bookkeeping are serialized
// off-main. At most two distinct compressed sources are in flight.
@interface RWArtworkLoader : NSObject <NSURLSessionDataDelegate>
- (instancetype)initWithFolder:(NSString *)folder resources:(NSString *)resources configuration:(NSURLSessionConfiguration *)configuration;
- (void)setBundledArtwork:(NSDictionary *)mapping;
- (NSString *)loadURLs:(NSArray *)urls request:(NSDictionary *)request result:(void(^)(NSDictionary *result, BOOL final))result;
- (void)cancel:(NSString *)token;
- (void)clearMemory;
- (void)diagnostics:(void(^)(NSDictionary *))done;
- (void)close;
@end
