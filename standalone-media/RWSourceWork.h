#import <Foundation/Foundation.h>
// Owner: main. At most16 jobs including one active task; queued foreground work
// precedes background work. Validity blocks and completions run only on main.
// Tasks run serially off-main and must capture owned/immutable inputs, never
// mutable app state. Invalid queued jobs do no CPU work; late output is dropped.
@interface RWSourceWork : NSObject
+ (id)snapshot:(id)value; // bounded deep capture on the input's owning thread
- (void)submitForeground:(BOOL)foreground valid:(BOOL(^)(void))valid task:(id(^)(void))task done:(void(^)(id,NSString *))done;
- (NSDictionary *)diagnostics;
@end
