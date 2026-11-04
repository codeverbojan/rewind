#import <Foundation/Foundation.h>
#import "RWPosterFeed.h"

// Main-thread API; all SQLite work runs on one owned serial queue. This is a
// disposable browsing cache, never the profile/history database.
@interface RWFeedStore : NSObject <RWPosterFeed>
+ (dispatch_queue_t)storageQueue;
// Call on storageQueue. Shared quota includes persistent Home and other feeds.
+ (unsigned long long)roomForPath:(NSString *)path;
+ (NSDictionary *)cardRecord:(NSDictionary *)record;
- (instancetype)initWithFolder:(NSString *)folder context:(NSString *)context;
@property(nonatomic,readonly) NSString *context;
@property(nonatomic,readonly) NSUInteger count, revision;
@property(nonatomic,readonly) BOOL pagesComplete;
@property(nonatomic,readonly) NSDictionary *diagnostics;
- (void)append:(NSArray *)records done:(void(^)(NSUInteger added, NSString *error))done;
// Commit 32 records at a time. A later quota failure preserves the already
// published prefix. Input is released on completion/cancellation, never cached
// in the UI. Progress always runs on main; close from progress cancels the rest.
- (void)appendPages:(NSArray *)records progress:(void(^)(NSUInteger added, NSString *error, BOOL finished))progress;
// Replace an explicit query in place, atomically publishing its first page.
// This reclaims the old query's space even when the shared cache is full.
- (void)replacePages:(NSArray *)records context:(NSString *)context type:(NSString *)type progress:(void(^)(NSUInteger added, NSString *error, BOOL finished))progress;
- (void)cancelPages;
// Sort the locally retained records on explicit user intent. Later pages append
// in the selected order without moving cards the person is already viewing.
- (void)selectType:(NSString *)type sort:(NSString *)sort done:(void(^)(NSString *error))done;
- (NSDictionary *)cachedItem:(NSUInteger)index;
- (void)loadRange:(NSRange)range done:(void(^)(NSString *error))done;
// Small exact-ID read for merging late metadata without retaining the feed.
- (void)recordsForIDs:(NSArray *)identifiers done:(void(^)(NSArray *,NSString *))done;
- (void)discardMemory;
// Navigation retains every record/order/cursor while inactive databases are
// losslessly compacted off-main. Reads restore lazily within the same disk cap.
- (void)park;
- (void)activate;
- (void)close:(void(^)(void))done;
@end
