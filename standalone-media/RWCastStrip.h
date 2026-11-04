#import "RewindUI.h"
// One detail/profile scope, reusable across metadata refreshes. No provider work.
@interface RWCastStrip : UIView
@property(nonatomic,copy,readonly) NSString *scope;
@property(nonatomic,strong,readonly) UICollectionView *rail;
@property(nonatomic,copy) void(^onSelect)(NSDictionary *person);
@property(nonatomic,copy) void(^onOffset)(CGFloat offset);
- (instancetype)initWithScope:(NSString *)scope;
- (BOOL)updatePeople:(NSArray *)people;
- (void)restoreOffset:(CGFloat)offset;
- (void)updateViewport;
- (void)suspendArtwork;
- (NSDictionary *)diagnostics;
@end
