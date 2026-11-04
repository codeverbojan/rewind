#import <Foundation/Foundation.h>
@interface RWEntitySearchPolicy : NSObject
+ (NSString *)query:(NSString *)query;
+ (NSInteger)match:(NSString *)name query:(NSString *)query;
+ (NSArray *)references:(NSArray *)entities parents:(BOOL)parents;
+ (NSArray *)records:(NSArray *)hits entities:(NSDictionary *)entities types:(NSDictionary *)types kind:(NSString *)kind query:(NSString *)query;
+ (NSArray *)merge:(NSArray *)local remote:(NSArray *)remote query:(NSString *)query profile:(NSString *)profile restricted:(BOOL)restricted;
@end
