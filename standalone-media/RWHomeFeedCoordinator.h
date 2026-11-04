#import "RWHomeFeedStore.h"
// A single foreground continuation lane shared by all Home shelves.
@interface RWHomeFeedCoordinator : NSObject
- (instancetype)initWithFolder:(NSString *)folder;
@property(nonatomic,copy) void(^onChange)(void);
@property(nonatomic,copy) BOOL(^permitsRecord)(NSDictionary *,NSDictionary *);
@property(nonatomic,copy) BOOL(^isActive)(void);
// Pure metadata check: permits migration from one ended catalog to other lists.
@property(nonatomic,copy) BOOL(^hasMoreCatalogPages)(NSDictionary *,NSDictionary *);
@property(nonatomic,copy) void(^prepareRecords)(NSArray *,NSDictionary *,void(^)(NSArray *,NSString *));
@property(nonatomic,copy) void(^fetchPage)(NSDictionary *,NSDictionary *,NSSet *,BOOL(^)(void),void(^)(NSArray *,NSDictionary *,BOOL,NSString *));
// Save successful catalog reads before slower rating/source work. Continuation
// waits for the cursor transaction to acknowledge; no unverified card is inserted.
@property(nonatomic,copy) void(^fetchPageWithProgress)(NSDictionary *,NSDictionary *,NSSet *,BOOL(^)(void),void(^)(NSDictionary *,BOOL,void(^)(NSString *)),void(^)(NSArray *,NSDictionary *,BOOL,NSString *));
// Re-evaluate already acquired metadata only. Must not fetch pages, ratings or sources.
@property(nonatomic,copy) void(^recheckLocal)(NSDictionary *,NSSet *,BOOL(^)(void),void(^)(NSArray *,NSString *));
@property(nonatomic,readonly) NSArray *rows;
@property(nonatomic,readonly) NSDictionary *hero;
@property(nonatomic,readonly) NSDictionary *diagnostics;
@property(nonatomic,readonly) NSString *scope;
- (void)activate:(NSString *)scope profile:(NSString *)profile rows:(NSArray *)rows excluding:(NSSet *)excluded;
- (void)activate:(NSString *)scope profile:(NSString *)profile rows:(NSArray *)rows excluding:(NSSet *)excluded settled:(BOOL)settled;
- (void)sealOrganization:(NSString *)scope profile:(NSString *)profile;
- (void)loadMore:(NSString *)identifier manual:(BOOL)manual;
// Rechecks quiet requested rows locally and makes ended rows eligible to revisit.
// Repeated enrichment notifications share a thirty-second per-row cooldown.
- (void)catalogChanged;
- (void)rememberAnchor:(NSDictionary *)anchor identifier:(NSString *)identifier;
- (void)anchorIndex:(NSString *)identifier done:(void(^)(NSUInteger,NSDictionary *))done;
- (void)cancel;
- (void)discardMemory;
@end
