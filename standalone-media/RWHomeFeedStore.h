#import <Foundation/Foundation.h>
#import "RWPosterFeed.h"
@class RWHomeFeedStore;
@interface RWHomeRowFeed : NSObject <RWPosterFeed>
@property(nonatomic,readonly) NSString *identifier;
@property(nonatomic,readonly) NSDictionary *descriptor,*cursor,*anchor;
@property(nonatomic,readonly) BOOL more;
@end
// Main-thread API. One shared SQLite worker, one persistent database, atomic
// global title ownership across all rows of a profile/context. No user history.
@interface RWHomeFeedStore : NSObject
- (instancetype)initWithFolder:(NSString *)folder;
@property(nonatomic,readonly) NSArray<RWHomeRowFeed *> *rows;
@property(nonatomic,readonly) NSString *scope;
@property(nonatomic,readonly) NSDictionary *diagnostics;
// Optional asynchronous current-policy gate. Returned records must be a subset
// of the input in the same order. It runs only for the small visible window.
@property(nonatomic,copy) void(^prepareRecords)(NSArray *,NSDictionary *,void(^)(NSArray *,NSString *));
@property(nonatomic,copy) void(^onChange)(void);
@property(nonatomic,copy) BOOL(^permitsRecord)(NSDictionary *,NSDictionary *);
- (void)assignedIDs:(void(^)(NSSet *,NSString *))done;
- (void)assignedIDsExceptRemovedInRow:(NSString *)row done:(void(^)(NSSet *,NSString *))done;
- (void)anchorIndex:(RWHomeRowFeed *)row done:(void(^)(NSUInteger))done;
- (void)activate:(NSString *)scope profile:(NSString *)profile seedRows:(NSArray *)rows excluding:(NSSet *)identifiers done:(void(^)(NSString *error))done;
// A partial viewport seed can load the cache without consuming initial grouping.
- (void)activate:(NSString *)scope profile:(NSString *)profile seedRows:(NSArray *)rows excluding:(NSSet *)identifiers settled:(BOOL)settled done:(void(^)(NSString *error))done;
// First real interaction freezes ownership for this profile/context session.
- (void)sealOrganization:(NSString *)scope profile:(NSString *)profile;
- (void)append:(NSArray *)records row:(RWHomeRowFeed *)row expectedCursor:(NSDictionary *)expected nextCursor:(NSDictionary *)next more:(BOOL)more done:(void(^)(NSUInteger added,NSString *error))done;
- (void)saveAnchor:(NSDictionary *)anchor row:(RWHomeRowFeed *)row done:(void(^)(NSString *error))done;
- (void)removeIdentifiers:(NSArray *)identifiers row:(RWHomeRowFeed *)row done:(void(^)(NSString *error))done;
- (void)discardMemory;
- (void)close:(void(^)(void))done;
@end
