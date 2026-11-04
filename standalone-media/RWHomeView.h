#import "RWPosterCollection.h"

// Native reusable shelves. The table owns only visible shelf cells; each shelf
// owns only visible poster cells. Ranking and eligibility stay in the store.
@interface RWHomeView : UITableView
@property(nonatomic,copy) void(^onSelect)(NSDictionary *meta);
@property(nonatomic,copy) void(^onViewport)(void);
@property(nonatomic,copy) void(^onLoadMore)(NSString *,BOOL);
@property(nonatomic,copy) void(^onAnchor)(NSString *,NSDictionary *);
@property(nonatomic,copy) void(^restoreAnchor)(NSString *,void(^)(NSUInteger,NSDictionary *));
@property(nonatomic,assign) BOOL reviewMode;
@property(nonatomic,strong) NSMutableDictionary *railOffsets;
@property(nonatomic,copy) NSString *scope;
@property(nonatomic,readonly) NSArray *displayedRows;
- (instancetype)initWithFrame:(CGRect)frame;
- (void)updateRows:(NSArray *)rows header:(UIView *)header;
- (void)parkForReuse;
- (void)saveVisibleAnchors;
- (void)loadVisibleArtwork;
- (NSArray *)visibleMetadata;
- (NSSet *)preparationIDs;
- (NSDictionary *)viewportAnchor;
- (NSDictionary *)diagnostics;
- (BOOL)isInteracting;
@end
