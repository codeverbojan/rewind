#import <Foundation/Foundation.h>
@interface RWEntityDetailsPolicy : NSObject
+ (NSString *)cleanBiography:(NSString *)text;
+ (NSArray *)labelIDs:(NSDictionary *)entity studio:(BOOL)studio;
+ (NSDictionary *)details:(NSDictionary *)entity role:(NSString *)role labels:(NSDictionary *)labels;
+ (NSDictionary *)biography:(NSDictionary *)response entityID:(NSString *)identifier;
+ (NSDictionary *)highlights:(NSArray *)credits entity:(NSDictionary *)entity now:(double)now;
@end
