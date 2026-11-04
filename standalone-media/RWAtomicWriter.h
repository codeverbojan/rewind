#import <Foundation/Foundation.h>

// Thread-safe producer. At most one in-flight batch and one latest snapshot
// per destination; slow storage cannot accumulate old history/metric writes.
// whenIdle completes on main after previously submitted snapshots reach disk.
@interface RWAtomicWriter : NSObject
+ (instancetype)shared;
// Explicit deep ownership, not an inference from NSDictionary's class. The
// returned JSON graph has immutable containers/strings and may be shared by
// later captures. Call on the input's owning thread; invalid JSON returns nil.
+ (id)immutableJSON:(id)object;
+ (BOOL)isOwnedJSON:(id)object;
- (void)write:(NSData *)data path:(NSString *)path;
// Call on the thread that owns object; it must not mutate during this call.
// Recursively captures containers/strings before returning. JSON conversion
// and disk I/O run on the writer queue, never against the live mutable graph.
// Returns NO for unsupported JSON values without replacing the previous file.
- (BOOL)writeJSON:(id)object path:(NSString *)path;
- (NSDictionary *)diagnostics;
- (void)whenIdle:(void (^)(void))completion;
@end
