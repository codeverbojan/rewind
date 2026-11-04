#import <Foundation/Foundation.h>
typedef void (^RWLookupResult)(id result, NSString *error);
// Main-queue single-flight requests. Only the owner starts work; every caller
// receives one result. Failed requests do not poison subsequent attempts.
@interface RWRequestCoalescer : NSObject
@property(nonatomic,readonly) NSUInteger joinedCount;
- (void)perform:(NSString *)key start:(void (^)(RWLookupResult finish))start done:(RWLookupResult)done;
@end
