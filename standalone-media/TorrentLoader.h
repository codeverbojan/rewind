#import <AVFoundation/AVFoundation.h>
#import "TorrentEngine.h"
@interface TorrentLoader : NSObject <AVAssetResourceLoaderDelegate>
@property(atomic,copy,readonly) NSDictionary *diagnostics;
- (instancetype)initWithEngine:(TorrentEngine *)engine name:(NSString *)name size:(int64_t)size;
- (AVPlayerItem *)playerItem;
- (void)stop;
@end
