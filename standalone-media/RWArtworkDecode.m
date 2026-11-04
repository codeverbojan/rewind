#import "RWArtworkDecode.h"
#import "RWArtworkPolicy.h"
#import <ImageIO/ImageIO.h>
@implementation RWArtworkDecode
+ (NSDictionary *)decode:(NSData *)data request:(NSDictionary *)request {
    if(!data.length||data.length>5*1024*1024)return nil;
    CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data,(__bridge CFDictionaryRef)@{(id)kCGImageSourceShouldCache:@NO});if(!source)return nil;
    NSDictionary *properties=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL));
    double w=[properties[(id)kCGImagePropertyPixelWidth]doubleValue],h=[properties[(id)kCGImagePropertyPixelHeight]doubleValue];NSInteger orientation=[properties[(id)kCGImagePropertyOrientation]integerValue];if(orientation>=5&&orientation<=8){double tmp=w;w=h;h=tmp;}
    NSDictionary *sizing=[RWArtworkPolicy sizing:request sourceWidth:w height:h];if(!sizing){CFRelease(source);return nil;}
    CGImageRef bitmap=CGImageSourceCreateThumbnailAtIndex(source,0,(__bridge CFDictionaryRef)@{(id)kCGImageSourceCreateThumbnailFromImageAlways:@YES,(id)kCGImageSourceCreateThumbnailWithTransform:@YES,(id)kCGImageSourceShouldCacheImmediately:@YES,(id)kCGImageSourceThumbnailMaxPixelSize:sizing[@"max_pixel"]});CFRelease(source);if(!bitmap)return nil;
    NSMutableDictionary *result=[sizing mutableCopy];result[@"bitmap"]=CFBridgingRelease(bitmap);result[@"decoded_width"]=@(CGImageGetWidth(bitmap));result[@"decoded_height"]=@(CGImageGetHeight(bitmap));result[@"decoded_bytes"]=@(CGImageGetBytesPerRow(bitmap)*CGImageGetHeight(bitmap));result[@"decode_off_main"]=@(!NSThread.isMainThread);return result;
}
@end
