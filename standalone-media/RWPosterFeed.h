#import <Foundation/Foundation.h>
// Metadata windows only. The collection owns reusable visible cells/artwork.
@protocol RWPosterFeed <NSObject>
@property(nonatomic,readonly) NSString *context;
@property(nonatomic,readonly) NSUInteger count,revision;
- (NSDictionary *)cachedItem:(NSUInteger)index;
- (void)loadRange:(NSRange)range done:(void(^)(NSString *error))done;
@end
