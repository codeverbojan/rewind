#import <Foundation/Foundation.h>
@interface RWDiscoveryMetadata : NSObject
+ (NSURL *)URLForRequest:(NSString *)url;
- (instancetype)initWithPath:(NSString *)path bundled:(NSString *)bundled;
- (instancetype)initWithPath:(NSString *)path cached:(NSDictionary *)cached seed:(NSDictionary *)seed;
@property(nonatomic,assign) BOOL paused;
@property(nonatomic,readonly) NSDictionary *diagnostics;
@property(nonatomic,readonly) NSDictionary *entitySearchDiagnostics;
- (void)invalidate;
- (NSDictionary *)record:(NSString *)imdb;
- (NSDictionary *)enrich:(NSDictionary *)meta;
- (NSDictionary *)titleSnapshot;
- (NSDictionary *)entitySnapshot;
- (void)enqueue:(NSArray *)items;
// Reorder at most four visible-row lookups on the existing bounded lane.
- (void)prioritizeTitles:(NSArray *)items;
// One bounded exact-identity artwork refresh for an opened series; cached
// results are shared by the detail header and ordinary catalog cards.
- (void)refreshArtwork:(NSDictionary *)meta;
- (BOOL)isResolvingItems:(NSArray *)items;
- (void)resolve:(NSDictionary *)meta done:(void(^)(NSDictionary *,NSString *))done;
// Exact provider IDs only; never a global person-name search.
- (void)resolvePerson:(NSDictionary *)person done:(void(^)(NSDictionary *,NSString *))done;
- (void)credits:(NSString *)entityID role:(NSString *)role offset:(NSUInteger)offset done:(void(^)(NSArray *,BOOL,NSString *))done;
- (void)creditPage:(NSString *)entityID role:(NSString *)role continuation:(NSDictionary *)continuation done:(void(^)(NSArray *,NSDictionary *,NSString *))done;
// Background credit acquisition has its own cancellation owner and budget lane.
- (void)creditPage:(NSString *)entityID role:(NSString *)role continuation:(NSDictionary *)continuation owner:(NSString *)owner foreground:(BOOL)foreground done:(void(^)(NSArray *,NSDictionary *,NSString *))done;
- (void)worldPage:(NSDictionary *)continuation owner:(NSString *)owner done:(void(^)(NSArray *,NSDictionary *,NSString *))done;
- (void)cancelCreditRequestsForOwner:(NSString *)owner;
- (void)entity:(NSString *)entityID done:(void(^)(NSDictionary *,NSString *))done;
- (void)entity:(NSString *)entityID role:(NSString *)role done:(void(^)(NSDictionary *,NSString *))done;
// Revalidate a failed exact image once per entity per 15 minutes.
- (void)entity:(NSString *)entityID role:(NSString *)role failedImage:(NSString *)url done:(void(^)(NSDictionary *,NSString *))done;
// Rich page lookup is separate from card photos. Progress and completion run
// on main; stale cached details may arrive before a bounded refresh.
- (void)entityDetails:(NSString *)entityID role:(NSString *)role progress:(void(^)(NSDictionary *))progress done:(void(^)(NSDictionary *,NSString *))done;
- (void)searchEntities:(NSString *)query kind:(NSString *)kind continuation:(NSDictionary *)continuation done:(void(^)(NSArray *,NSDictionary *,NSString *))done;
// Discard just this departed credits request, preserving unrelated lookups.
- (void)cancelCredits:(NSString *)entityID role:(NSString *)role;
- (void)cancelEntitySearch;
- (void)cancelPending;
@end
