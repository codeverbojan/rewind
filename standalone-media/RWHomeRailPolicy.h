#import <Foundation/Foundation.h>
@interface RWHomeRailPolicy : NSObject
+ (NSArray *)rank:(NSArray *)items row:(NSDictionary *)row profile:(NSDictionary *)profile excluding:(NSSet *)excluded available:(BOOL)available now:(double)now;
+ (NSDictionary *)provider:(NSDictionary *)row restricted:(BOOL)restricted;
+ (NSArray *)providers:(NSDictionary *)row restricted:(BOOL)restricted;
+ (NSDictionary *)cursorAfterLocalPage:(NSDictionary *)cursor;
+ (BOOL)shouldBrowseBeforeCheckingLocal:(NSDictionary *)row cursor:(NSDictionary *)cursor restricted:(BOOL)restricted now:(double)now;
// Pure bounded pagination. A missing request means every catalog is ended.
+ (NSDictionary *)catalogPage:(NSDictionary *)row cursor:(NSDictionary *)cursor restricted:(BOOL)restricted now:(double)now;
+ (NSDictionary *)advanceCatalogPage:(NSDictionary *)page received:(NSUInteger)count now:(double)now;
+ (NSDictionary *)advanceWorldPage:(NSDictionary *)page continuation:(NSDictionary *)continuation now:(double)now;
+ (NSDictionary *)deferCatalogPage:(NSDictionary *)page now:(double)now;
+ (NSArray *)ratingCandidates:(NSArray *)items row:(NSDictionary *)row excluding:(NSSet *)excluded rating:(NSDictionary *(^)(NSString *))rating now:(double)now;
+ (NSArray *)ratingCandidates:(NSArray *)items row:(NSDictionary *)row excluding:(NSSet *)excluded metadata:(NSDictionary *)metadata preferences:(NSDictionary *)preferences rating:(NSDictionary *(^)(NSString *))rating now:(double)now;
+ (NSArray *)metadataCandidates:(NSArray *)items row:(NSDictionary *)row excluding:(NSSet *)excluded metadata:(NSDictionary *)metadata preferences:(NSDictionary *)preferences now:(double)now;
@end
