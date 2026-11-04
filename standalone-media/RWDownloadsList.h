#import "RewindUI.h"
@interface RWDownloadsList : UITableView
@property(nonatomic,copy) void(^onResume)(NSDictionary *record);
@property(nonatomic,copy) void(^onKeep)(NSDictionary *record);
@property(nonatomic,copy) void(^onRemove)(NSDictionary *record);
@property(nonatomic,copy) void(^onClear)(void);
@property(nonatomic,copy) void(^onRetry)(void);
@property(nonatomic,copy) void(^onBrowse)(void);
@property(nonatomic,copy) NSString *profileID;
@property(nonatomic,assign) BOOL reviewMode;
@property(nonatomic,assign) BOOL actionsEnabled;
- (instancetype)initWithFrame:(CGRect)frame;
- (void)updateSnapshot:(NSDictionary *)snapshot loading:(BOOL)loading;
- (void)loadVisibleArtwork;
@end
