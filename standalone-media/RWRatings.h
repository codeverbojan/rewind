#import <Foundation/Foundation.h>
@interface RWRatings : NSObject
@property(nonatomic,readonly) BOOL busy;
@property(nonatomic,readonly) NSDictionary *diagnostics;
- (instancetype)initWithCache:(NSString *)cache bundled:(NSString *)bundled;
- (instancetype)initWithCache:(NSString *)cache bundled:(NSString *)bundled configuration:(NSURLSessionConfiguration *)configuration;
- (NSDictionary *)rating:(NSString *)imdb;
- (NSDictionary *)snapshot;
- (BOOL)isResolvingItems:(NSArray *)items;
- (void)resolve:(NSArray *)items;
- (void)resolve:(NSArray *)items interactive:(BOOL)interactive;
@end
