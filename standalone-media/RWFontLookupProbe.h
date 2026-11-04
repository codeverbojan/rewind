#import <Foundation/Foundation.h>
// Read-only diagnostic reconstruction of pinned VLC Darwin font lookup.
// No font registration, renderer replacement, global cache or playback changes.
@interface RWFontLookupProbe : NSObject
- (BOOL)start;
- (void)cancel;
- (NSDictionary *)snapshot;
@end
