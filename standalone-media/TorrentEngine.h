#import <Foundation/Foundation.h>

@interface TorrentEngine : NSObject
// All engine work and reads share this serial queue, never the UI queue.
@property(nonatomic,readonly) dispatch_queue_t workQueue;
- (void)perform:(void (^)(TorrentEngine *engine))work;
// Arm only from an admitted diagnostic player; call on workQueue.
- (void)setTransportDiagnosticsEnabled:(BOOL)enabled;
+ (NSUInteger)activeSessionCount;
+ (void)removeDownload:(NSString *)hash done:(void (^)(BOOL))done;
+ (void)clearTemporary:(NSSet *)pinned done:(void (^)(NSDictionary *))done;
+ (void)downloadInventory:(NSArray *)history gate:(NSDictionary *)gate pinned:(NSSet *)pinned done:(void (^)(NSDictionary *))done;
+ (void)afterCleanupWithPinned:(NSSet *)pinned ready:(void (^)(void))ready;
- (void)retireWithPinned:(NSSet *)pinned completion:(void (^)(NSDictionary *))completion;
- (BOOL)startMagnet:(NSString *)magnet publicTest:(BOOL)publicTest error:(NSString **)error;
- (BOOL)startMagnet:(NSString *)magnet fileIndex:(int)fileIndex publicTest:(BOOL)publicTest error:(NSString **)error;
- (NSDictionary *)snapshot;
- (void)startCandidates:(NSArray *)sources;
- (void)startPreparingCandidates:(NSArray *)sources;
- (void)setPreparationPayloadAllowed:(BOOL)allowed;
- (BOOL)adoptPreparation;
- (NSDictionary *)preparationSnapshot;
- (void)appendCandidates:(NSArray *)sources;
- (NSDictionary *)discoverySnapshot;
@property(nonatomic,readonly) NSDictionary *selectedSource;
- (void)pause;
// Final teardown. Create a new engine to open another session afterward.
- (void)shutdown;
- (void)resume;
- (NSData *)readVerifiedBytesAt:(int64_t)offset length:(NSUInteger)length;
- (void)prioritizeOffset:(int64_t)offset length:(NSUInteger)length;
- (void)resetPlaybackRequests;
- (NSArray *)subtitleFiles;
- (BOOL)beginSubtitle:(NSInteger)index;
- (NSData *)subtitleData;
- (void)cancelSubtitle;
@property(nonatomic,readonly) int64_t videoSize;
@property(nonatomic,readonly) NSString *videoName;
@end
