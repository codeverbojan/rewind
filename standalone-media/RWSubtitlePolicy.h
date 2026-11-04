#import <Foundation/Foundation.h>
@interface RWSubtitlePolicy : NSObject
+ (NSString *)digest:(NSData *)data;
+ (NSString *)fingerprint:(id)value;
+ (NSString *)mediaKey:(NSDictionary *)source bundleBuild:(NSString *)build;
+ (NSDictionary *)descriptor:(NSDictionary *)raw kind:(NSString *)kind locator:(id)locator;
+ (NSDictionary *)preference:(NSDictionary *)profile videoID:(NSString *)videoID mediaKey:(NSString *)media;
+ (NSDictionary *)select:(NSArray *)choices preference:(NSDictionary *)preference;
+ (NSDictionary *)saveChoice:(NSDictionary *)choice enabled:(BOOL)enabled videoID:(NSString *)videoID mediaKey:(NSString *)media existing:(NSDictionary *)existing now:(double)now;
+ (NSString *)adjustmentKey:(NSDictionary *)choice videoID:(NSString *)videoID mediaKey:(NSString *)media contentDigest:(NSString *)content;
+ (NSDictionary *)adjustment:(NSDictionary *)profile key:(NSString *)key;
+ (NSDictionary *)saveAdjustment:(NSDictionary *)adjustment key:(NSString *)key existing:(NSDictionary *)existing now:(double)now;
+ (NSString *)sidecarMatch:(NSDictionary *)file videoID:(NSString *)videoID source:(NSDictionary *)source;
+ (NSArray *)mapMKV:(NSArray *)header runtime:(NSArray *)runtime;
+ (NSDictionary *)manualFileForURL:(NSString *)url;
+ (NSDictionary *)manualFileInProfile:(NSDictionary *)profile videoID:(NSString *)videoID mediaKey:(NSString *)media;
+ (NSDictionary *)saveManualFile:(NSDictionary *)file videoID:(NSString *)videoID mediaKey:(NSString *)media existing:(NSDictionary *)existing now:(double)now;
@end
