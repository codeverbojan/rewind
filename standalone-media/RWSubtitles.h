#import <Foundation/Foundation.h>
@interface RWSubtitles : NSObject
+ (NSArray *)parse:(NSData *)data;
// UTF-8/UTF-16 BOM are automatic. Ambiguous legacy bytes require an explicit
// encoding choice; WebVTT always requires UTF-8. Result includes cues/status.
+ (NSDictionary *)parse:(NSData *)data format:(NSString *)format encoding:(NSString *)encoding cancelled:(BOOL(^)(void))cancelled;
+ (NSArray *)encodingOptions;
+ (BOOL)isBundledSubtitle:(NSString *)url;
+ (NSString *)textIn:(NSArray *)cues at:(double)time;
+ (BOOL)language:(NSString *)language matches:(NSString *)preferred;
+ (BOOL)fileName:(NSString *)name matchesLanguage:(NSString *)preferred;
+ (NSArray *)providedBySource:(NSDictionary *)source meta:(NSDictionary *)meta allowBundled:(BOOL)bundled;
@end
