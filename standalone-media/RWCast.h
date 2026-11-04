#import <Foundation/Foundation.h>
// Exact title/credit relationships; never choose a person by name alone.
@interface RWCast : NSObject
@property(nonatomic,readonly) NSDictionary *lastFailure;
+ (NSURLSessionConfiguration *)sessionConfiguration;
- (instancetype)initWithCache:(NSString *)path;
- (NSArray *)cached:(NSDictionary *)meta;
- (void)resolve:(NSDictionary *)meta done:(void(^)(NSArray *people))done;
- (void)cancel;
+ (NSString *)showID:(NSDictionary *)show imdb:(NSString *)imdb;
+ (NSArray *)publicMoviePeople:(NSString *)html meta:(NSDictionary *)meta;
+ (NSDictionary *)personReference:(NSDictionary *)person;
+ (NSDictionary *)canonicalPerson:(NSDictionary *)entity reference:(NSDictionary *)reference;
+ (NSString *)knownPersonID:(NSDictionary *)person titleCredits:(NSArray *)credits;
+ (NSArray *)tvPeople:(NSDictionary *)show imdb:(NSString *)imdb;
+ (NSArray *)actorIDs:(NSDictionary *)entity imdb:(NSString *)imdb;
+ (NSArray *)wikiPeople:(NSDictionary *)entities names:(NSArray *)cast;
+ (NSArray *)photos:(NSDictionary *)response people:(NSArray *)people;
@end
