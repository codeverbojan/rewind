#import <Foundation/Foundation.h>
@interface RWTrailers : NSObject
@property(nonatomic,readonly) NSDictionary *diagnostics;
- (instancetype)initWithCache:(NSString *)path bundled:(NSString *)bundled;
- (instancetype)initWithCache:(NSString *)path bundled:(NSString *)bundled configuration:(NSURLSessionConfiguration *)configuration;
- (void)resolve:(NSDictionary *)meta done:(void(^)(NSDictionary *,NSString *))done;
- (void)resolveNative:(NSDictionary *)meta done:(void(^)(NSDictionary *,NSString *))done;
- (void)cancel:(NSString *)identifier;
- (void)failed:(NSString *)imdb;
- (void)failed:(NSString *)imdb embedded:(BOOL)embedded;
- (void)embeddedUnsupported;
@end
