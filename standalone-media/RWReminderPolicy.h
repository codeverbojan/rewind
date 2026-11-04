#import <Foundation/Foundation.h>
@interface RWReminderPolicy : NSObject
+ (NSDictionary *)presentation:(NSDictionary *)meta mode:(NSString *)mode following:(BOOL)following watching:(BOOL)watching alerts:(BOOL)alerts;
+ (NSDictionary *)payload:(NSString *)kind profile:(NSString *)profile title:(NSString *)title video:(NSString *)video;
+ (NSDictionary *)destination:(NSDictionary *)userInfo state:(NSDictionary *)state show:(NSDictionary *)show rating:(NSDictionary *)rating now:(NSDate *)now;
@end
