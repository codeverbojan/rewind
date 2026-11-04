#import <Foundation/Foundation.h>
@class RWMetadataBudget;
// One due-show request at a time. Background fetch is a bounded OS-granted
// window, not permission to resume the application's paused discovery queue.
@interface RWEpisodeFetcher : NSObject
- (instancetype)initWithSession:(NSURLSession *)session budget:(RWMetadataBudget *)budget;
- (void)startWhenReady:(BOOL(^)(void))ready identifiers:(NSArray *(^)(void))identifiers background:(BOOL)background timeout:(double)timeout accept:(void(^)(NSDictionary *))accept done:(void(^)(NSDictionary *))done;
- (void)cancel;
@property(nonatomic,readonly) BOOL background;
@property(nonatomic,readonly) NSDictionary *diagnostics;
@end
