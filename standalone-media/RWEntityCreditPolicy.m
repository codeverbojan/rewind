#import "RWEntityCreditPolicy.h"
static NSString *Text(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static NSDictionary *Role(NSString *role){
    static NSDictionary *values;static dispatch_once_t once;dispatch_once(&once,^{values=@{
        @"cast":@{@"field":@"cast",@"property":@"P161",@"label":@"Acting",@"heading":@"Acting credits"},
        @"director":@{@"field":@"directors",@"property":@"P57",@"label":@"Directing",@"heading":@"Directing credits"},
        @"studio":@{@"field":@"studios",@"property":@"P272",@"label":@"Productions",@"heading":@"Production credits",@"summary":@"Production"},
        @"distributor":@{@"field":@"distributors",@"property":@"P750",@"label":@"Distributions",@"heading":@"Distribution credits",@"summary":@"Distribution"},
        @"network":@{@"field":@"networks",@"property":@"P449",@"label":@"Broadcasts",@"heading":@"Original broadcast credits",@"summary":@"Original broadcaster"}};});return values[Text(role)];
}
@implementation RWEntityCreditPolicy
+ (BOOL)isCompany:(NSDictionary *)entity {NSString *type=Text(entity[@"type"]);if([type isEqual:@"person"])return NO;return [type isEqual:@"studio"]||[@[@"studio",@"distributor",@"network"]containsObject:Text(entity[@"creditRole"])];}
+ (NSArray *)roles:(NSDictionary *)entity {return [self isCompany:entity]?@[@"studio",@"distributor",@"network"]:@[@"cast",@"director"];}
+ (NSDictionary *)selectRole:(NSString *)role entity:(NSDictionary *)entity {if(![[self roles:entity]containsObject:Text(role)])return nil;NSMutableDictionary *copy=[entity mutableCopy];copy[@"creditRole"]=role;return copy;}
+ (NSString *)field:(NSString *)role {return Role(role)[@"field"];}
+ (NSString *)property:(NSString *)role {return Role(role)[@"property"];}
+ (NSString *)label:(NSString *)role {return Role(role)[@"label"]?:@"Credits";}
+ (NSString *)heading:(NSString *)role {return Role(role)[@"heading"]?:@"Credits";}
+ (NSString *)companySummary:(NSArray *)roles {NSMutableArray *parts=[NSMutableArray new];for(NSString *role in @[@"studio",@"distributor",@"network"])if([roles containsObject:role])[parts addObject:Role(role)[@"summary"]];return parts.count?[parts componentsJoinedByString:@" · "]:@"Company";}
@end
