#import <Foundation/Foundation.h>
// Credit relationships are distinct from present-day streaming availability.
@interface RWEntityCreditPolicy : NSObject
+ (BOOL)isCompany:(NSDictionary *)entity;
+ (NSArray *)roles:(NSDictionary *)entity;
+ (NSDictionary *)selectRole:(NSString *)role entity:(NSDictionary *)entity;
+ (NSString *)field:(NSString *)role;
+ (NSString *)property:(NSString *)role;
+ (NSString *)label:(NSString *)role;
+ (NSString *)heading:(NSString *)role;
+ (NSString *)companySummary:(NSArray *)roles;
@end
