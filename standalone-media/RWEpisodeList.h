#import <UIKit/UIKit.h>
@interface RWEpisodeList : UIView
@property(nonatomic,copy) void(^onPlay)(NSDictionary *episode);
@property(nonatomic,copy) void(^onOptions)(NSDictionary *episode,UIView *anchor);
- (instancetype)initWithEpisodes:(NSArray *)episodes history:(NSDictionary *)history nextID:(NSString *)nextID width:(CGFloat)width;
- (void)updateViewport:(CGRect)viewport loadImages:(BOOL)loadImages;
- (NSDictionary *)diagnostics;
@end
