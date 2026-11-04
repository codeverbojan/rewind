#import <Foundation/Foundation.h>
@interface RWHomeDelivery : NSObject
+ (NSArray *)displaySignature:(NSDictionary *)home;
+ (NSDictionary *)titleMetadata:(NSDictionary *)meta;
+ (NSArray *)retainedTitles:(NSDictionary *)observations;
+ (BOOL)needsRefresh:(NSDictionary *)meta now:(double)now;
+ (NSArray *)refreshable:(NSArray *)prepared observations:(NSDictionary *)observations shows:(NSDictionary *)shows history:(NSDictionary *)history metadataAttempts:(NSDictionary *)attempts quality:(NSInteger)quality now:(double)now;
+ (NSDictionary *)snapshot:(NSDictionary *)home profile:(NSDictionary *)profile quality:(NSInteger)quality now:(double)now;
+ (NSDictionary *)restore:(NSDictionary *)snapshot profile:(NSDictionary *)profile quality:(NSInteger)quality now:(double)now;
+ (NSArray *)targets:(NSArray *)ranked world:(NSArray *)world older:(NSArray *)older shows:(NSArray *)shows now:(double)now limit:(NSUInteger)limit;
+ (NSArray *)targets:(NSArray *)ranked includingWatches:(NSArray *)watches;
+ (BOOL)publishCompleted:(NSUInteger)completed total:(NSUInteger)total;
@end
