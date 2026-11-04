#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
// Foundation/ImageIO only, shared by the iOS loader and real-image host tests.
@interface RWArtworkDecode : NSObject
+ (NSDictionary *)decode:(NSData *)data request:(NSDictionary *)request;
@end
