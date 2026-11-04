#import <Foundation/Foundation.h>
@interface RWApplePreviewPolicy : NSObject
+ (NSArray *)showIDs:(NSDictionary *)entity imdb:(NSString *)imdb;
+ (NSArray *)movieIDs:(NSDictionary *)entity imdb:(NSString *)imdb;
+ (NSArray *)reviewedMovieIDs:(NSDictionary *)record meta:(NSDictionary *)meta;
+ (NSURL *)allowedURL:(NSString *)url base:(NSURL *)base;
+ (NSDictionary *)preview:(NSData *)html showID:(NSString *)identifier meta:(NSDictionary *)meta;
+ (NSDictionary *)variant:(NSString *)master base:(NSURL *)base;
+ (NSDictionary *)media:(NSString *)playlist base:(NSURL *)base;
+ (NSString *)localMaster:(NSDictionary *)variant;
@end
