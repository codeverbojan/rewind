#import <Foundation/Foundation.h>
@interface RWTVPolicy : NSObject
+ (NSArray *)search:(NSArray *)items query:(NSString *)query;
+ (NSArray *)localMatches:(NSArray *)items query:(NSString *)query;
+ (NSArray *)episodes:(NSDictionary *)show;
+ (BOOL)released:(NSDictionary *)episode now:(NSDate *)now;
+ (NSDictionary *)nextEpisode:(NSDictionary *)show history:(NSDictionary *)history now:(NSDate *)now;
+ (NSDictionary *)nextFromEpisodes:(NSArray *)episodes history:(NSDictionary *)history now:(NSDate *)now;
+ (NSDictionary *)episodeAfter:(NSString *)videoID show:(NSDictionary *)show now:(NSDate *)now;
+ (NSArray *)continuingRecords:(NSArray *)records;
+ (NSDictionary *)episodeMeta:(NSDictionary *)episode show:(NSDictionary *)show;
+ (NSArray *)newEpisodes:(NSDictionary *)show seen:(NSArray *)seen since:(NSDate *)since now:(NSDate *)now;
@end
