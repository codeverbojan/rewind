#import <Foundation/Foundation.h>
// Worker-only streaming archive for disposable feed databases. Neither method
// overwrites an existing destination or removes its input on failure/success.
@interface RWFeedArchive : NSObject
+ (BOOL)pack:(NSString *)source to:(NSString *)destination limit:(unsigned long long)limit error:(NSString **)error;
+ (BOOL)unpack:(NSString *)source to:(NSString *)destination limit:(unsigned long long)limit expected:(unsigned long long)expected error:(NSString **)error;
@end
