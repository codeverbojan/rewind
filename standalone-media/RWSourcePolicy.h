#import <Foundation/Foundation.h>

// Pure Foundation policy: shared by the ARMv7 app and host-side contract tests.
@interface RWSourcePolicy : NSObject
+ (void)setLegacyEnabled:(BOOL)enabled;
+ (BOOL)legacyEnabled;
+ (void)setNativeSurroundEnabled:(BOOL)enabled;
+ (BOOL)nativeSurroundEnabled;
+ (NSDictionary *)capabilities;
+ (NSDictionary *)analysis:(NSArray *)sources quality:(NSInteger)quality capabilities:(NSDictionary *)capabilities;
+ (NSDictionary *)normalize:(NSDictionary *)stream provider:(NSString *)provider;
+ (NSArray *)ytsSources:(NSDictionary *)response imdbID:(NSString *)imdbID;
+ (NSDictionary *)evaluate:(NSDictionary *)source quality:(NSInteger)quality freeBytes:(uint64_t)freeBytes;
+ (NSArray *)rank:(NSArray *)sources quality:(NSInteger)quality freeBytes:(uint64_t)freeBytes;
+ (NSArray *)sources:(NSArray *)sources withMeta:(NSDictionary *)meta;
+ (NSArray *)sources:(NSArray *)sources withMeta:(NSDictionary *)meta videoID:(NSString *)videoID;
+ (NSUInteger)nextIndexInSources:(NSArray *)sources startingAt:(NSUInteger)index excludingHashes:(NSSet *)hashes;
+ (NSArray *)qualities:(NSArray *)sources;
+ (NSString *)mediaRejection:(NSDictionary *)media quality:(NSInteger)quality;
+ (NSDictionary *)mediaAssessment:(NSDictionary *)media quality:(NSInteger)quality;
+ (NSString *)mediaCapabilityKey:(NSDictionary *)capabilities;
+ (NSInteger)resolutionForWidth:(NSInteger)width height:(NSInteger)height;
@end
