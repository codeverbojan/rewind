#import <Foundation/Foundation.h>
// Reads only the bounded EBML track header, never scans payload for magic bytes.
@interface RWMKVProbe : NSObject
+ (NSDictionary *)video:(NSData *)header;
+ (NSDictionary *)media:(NSData *)header;
+ (NSDictionary *)media:(NSData *)header audioPreference:(NSDictionary *)preference;
+ (NSDictionary *)selectAudioInMedia:(NSDictionary *)media preference:(NSDictionary *)preference;
@end
