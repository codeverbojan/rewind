#import <Foundation/Foundation.h>

@interface RWTrackerPolicy : NSObject
+ (BOOL)supportsHTTPS;
// Identity is private in-memory data: it can contain an authentication token.
// Never include this value, or a full tracker URL, in diagnostics.
+ (NSString *)canonicalKeyForURL:(NSString *)url allowHTTPS:(BOOL)allowHTTPS;
+ (NSArray *)URLsFromSourceEntries:(NSArray *)entries allowHTTPS:(BOOL)allowHTTPS limit:(NSUInteger)limit;
+ (NSArray *)publicFallbacks;
@end
