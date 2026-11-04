#import "RewindUI.h"
@interface RWAvailabilityList : UITableView
@property(nonatomic,copy) void(^onSelect)(NSDictionary *meta);
@property(nonatomic,copy) void(^onFollow)(NSDictionary *meta,UIView *anchor);
@property(nonatomic,copy) void(^onMore)(void);
@property(nonatomic,assign) BOOL hasMore;
@property(nonatomic,assign) NSUInteger scheduleDays;
- (void)loadMoreIfNearEnd;
@property(nonatomic,assign) BOOL reviewMode;
@property(nonatomic,assign) BOOL separatesWorldCinema;
@property(nonatomic,copy) NSString *reminderMode;
@property(nonatomic,readonly) NSDictionary *diagnostics;
@property(nonatomic,readonly) NSArray *items;
- (instancetype)initWithFrame:(CGRect)frame;
- (NSDictionary *)metaAtPath:(NSIndexPath *)path;
- (void)updateItems:(NSArray *)items;
- (void)loadVisibleArtwork;
- (void)setLoading:(BOOL)loading error:(NSString *)error retry:(void(^)(void))retry;
@end
