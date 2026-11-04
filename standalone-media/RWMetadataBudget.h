#import <Foundation/Foundation.h>
// Shared by metadata clients with separate NSURLSessions. All bookkeeping runs
// on main; callbacks from delegate queues may call complete/cancel safely.
// Callers create suspended tasks, enqueue instead of resume, and complete every
// task before processing its callback (including cancelled/stale callbacks).
@interface RWMetadataBudget : NSObject
+ (instancetype)shared;
- (void)enqueue:(NSURLSessionTask *)task foreground:(BOOL)foreground;
- (void)complete:(NSURLSessionTask *)task;
- (void)cancel:(NSURLSessionTask *)task;
- (void)hold:(NSURLSessionTask *)task;
@property(nonatomic,assign) BOOL paused;
// Let visible metadata continue while a trailer pauses background discovery.
@property(nonatomic,assign) BOOL backgroundPaused;
@property(nonatomic,readonly) NSDictionary *diagnostics;
@end
