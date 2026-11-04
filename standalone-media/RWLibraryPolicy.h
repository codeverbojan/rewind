#import <Foundation/Foundation.h>
@interface RWLibraryPolicy : NSObject
+ (NSArray *)recommend:(NSArray *)items current:(NSDictionary *)current history:(NSArray *)history saved:(NSArray *)saved hidden:(NSArray *)hidden limit:(NSUInteger)limit;
@end
