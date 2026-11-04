#import <Foundation/Foundation.h>

// Main-queue provider-list cache. Cached magnets are candidates, never health
// guarantees. Volatile HTTP URLs always require a new provider lookup.
@interface RWSourceCache : NSObject
- (instancetype)initWithCapacity:(NSUInteger)capacity;
- (NSArray *)sourcesForKey:(NSString *)key now:(double)now freshOnly:(BOOL)freshOnly;
- (void)storeSources:(NSArray *)sources forKey:(NSString *)key now:(double)now;
- (void)removeObjectForKey:(NSString *)key;
- (void)removeAllObjects;
@end
