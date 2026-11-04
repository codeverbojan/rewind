#import <Foundation/Foundation.h>
@interface RWPublisherRatingPolicy : NSObject
// identifier must come from the same exact IMDb-linked Wikidata entity.
+ (NSDictionary *)record:(NSData *)html identifier:(NSString *)identifier meta:(NSDictionary *)meta;
// Search establishes one exact artist identity, then its publisher redirect
// establishes the show page. Season/episode advisory ratings are never used.
+ (NSString *)storeSearchURL:(NSDictionary *)meta;
+ (NSString *)storeShowURL:(NSData *)json meta:(NSDictionary *)meta;
+ (BOOL)allowsStoreURL:(NSURL *)url showURL:(NSString *)showURL;
+ (NSDictionary *)storeRecord:(NSData *)html URL:(NSURL *)url meta:(NSDictionary *)meta;
// P7596 is used only on an entity whose non-deprecated P345 exactly matches.
+ (NSArray *)disneyIDs:(NSDictionary *)entity imdb:(NSString *)imdb;
+ (BOOL)allowsDisneyURL:(NSURL *)url identifier:(NSString *)identifier;
+ (NSDictionary *)disneyRecord:(NSData *)html URL:(NSURL *)url identifier:(NSString *)identifier meta:(NSDictionary *)meta;
@end
