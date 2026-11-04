#import <Foundation/Foundation.h>
// Codec/channel compatibility is established by the actual media probes.
// This policy ranks bounded metadata; it cannot verify the spoken language.
@interface RWAudioPolicy : NSObject
+ (NSString *)language:(id)value;
+ (NSDictionary *)nativeMetadata:(NSArray *)metadata;
+ (NSArray *)tracks:(NSArray *)raw;
+ (NSDictionary *)selection:(NSArray *)tracks preference:(NSDictionary *)preference;
+ (NSString *)mediaKey:(NSDictionary *)source;
+ (NSDictionary *)preferenceInProfile:(NSDictionary *)profile videoID:(NSString *)videoID mediaKey:(NSString *)key;
+ (NSDictionary *)selectionsBySaving:(NSDictionary *)track mediaKey:(NSString *)key videoID:(NSString *)videoID existing:(NSDictionary *)existing now:(double)now;
@end
