#import "RewindUI.h"
#import "RWFeedStore.h"
// A bounded viewport backed by UIKit's cell reuse, shared by scrolling title
// destinations. Provider cursors remain outside this presentation component.
@interface RWPosterCollection : UICollectionView
@property(nonatomic,copy) void(^onSelect)(NSDictionary *meta);
@property(nonatomic,copy) void(^onLoadMore)(BOOL manual);
@property(nonatomic,copy) void(^onScroll)(CGPoint offset);
@property(nonatomic,copy) void(^onScrollSettled)(void);
@property(nonatomic,copy) void(^onContentNeeded)(void);
@property(nonatomic,assign) BOOL defersContents;
@property(nonatomic,assign) BOOL continuationPaused;
@property(nonatomic,strong) UIView *headerView;
@property(nonatomic,readonly) NSArray *items;
@property(nonatomic,readonly) id<RWPosterFeed> feed;
@property(nonatomic,copy) NSString *emptyMessage;
@property(nonatomic,assign) BOOL reviewMode;
@property(nonatomic,assign) BOOL horizontal, landscape;
@property(nonatomic,assign) BOOL entityCards, compactEntityCards;
- (instancetype)initWithFrame:(CGRect)frame;
- (void)updateItems:(NSArray *)items loading:(BOOL)loading more:(BOOL)more error:(NSString *)error cursor:(NSUInteger)cursor automatic:(BOOL)automatic;
- (void)updateFeed:(id<RWPosterFeed>)feed loading:(BOOL)loading more:(BOOL)more error:(NSString *)error cursor:(NSUInteger)cursor automatic:(BOOL)automatic;
- (void)loadVisibleArtwork;
- (void)cancelVisibleArtwork;
- (NSArray *)visibleMetadata;
- (NSSet *)preparationIDs;
- (NSUInteger)visiblePendingCount;
- (BOOL)hasPendingVisibleContent;
- (BOOL)prepareNextVisibleContent;
- (NSUInteger)visiblePreparedCount;
- (NSDictionary *)continuationDiagnostics;
- (NSDictionary *)positionAnchor;
- (void)restorePositionIndex:(NSUInteger)index delta:(double)delta;
- (void)restorePositionIndex:(NSUInteger)index delta:(double)delta context:(NSString *)context;
- (void)restorePositionAnchor:(NSDictionary *)anchor;
@end
