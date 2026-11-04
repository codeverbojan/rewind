#import <Foundation/Foundation.h>
// Reads local discovery data only. Never reads or replaces mutable profile state.
@interface RWLocalCatalog : NSObject
+ (void)loadDocuments:(NSString *)documents resources:(NSString *)resources done:(void(^)(NSDictionary *))done;
@end
