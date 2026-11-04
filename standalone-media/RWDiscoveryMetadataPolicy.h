#import <Foundation/Foundation.h>
@interface RWDiscoveryMetadataPolicy : NSObject
+ (NSString *)displayName:(NSDictionary *)entity;
+ (NSDictionary *)entityProfile:(NSDictionary *)entity role:(NSString *)role;
+ (NSDictionary *)recordForEntity:(NSDictionary *)entity imdb:(NSString *)imdb labels:(NSDictionary *)labels;
+ (NSDictionary *)enrich:(NSDictionary *)meta record:(NSDictionary *)record;
+ (NSArray *)referencedIDs:(NSDictionary *)entity;
+ (NSArray *)labelIDsForEntities:(NSArray *)entities;
+ (NSArray *)collectionIDs:(NSDictionary *)entity;
+ (NSDictionary *)normalizeCollections:(NSDictionary *)record entities:(NSDictionary *)entities;
+ (BOOL)isNarrativeFranchise:(NSDictionary *)reference;
+ (NSArray *)worldFilmIDs:(NSDictionary *)entity;
+ (NSString *)creditTypeForEntity:(NSDictionary *)entity labels:(NSDictionary *)labels;
+ (NSString *)creditReleaseYearForEntity:(NSDictionary *)entity type:(NSString *)type;
+ (BOOL)allowsRetainedCredit:(NSDictionary *)meta record:(NSDictionary *)record;
+ (NSArray *)creditIDs:(NSDictionary *)entity role:(NSString *)role entityID:(NSString *)entityID;
+ (NSString *)languageGroup:(NSDictionary *)record;
+ (BOOL)isFamilyTitle:(NSDictionary *)meta;
+ (BOOL)isChildFocused:(NSDictionary *)meta;
+ (BOOL)recommendationAudienceAllows:(NSDictionary *)meta preferences:(NSDictionary *)preferences restricted:(BOOL)restricted;
+ (BOOL)isAdultAudience:(NSDictionary *)meta;
+ (NSArray *)moods:(NSDictionary *)meta;
+ (NSDictionary *)preferences:(NSDictionary *)raw;
+ (BOOL)permits:(NSDictionary *)meta preferences:(NSDictionary *)preferences world:(BOOL)world;
@end
