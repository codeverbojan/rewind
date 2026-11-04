#import <Foundation/Foundation.h>
// Immutable canonical metadata, stored once as bounded byte buffers. Episode
// dictionaries are materialized only when a consumer reads an element.
@interface RWPackedEpisodes : NSArray
+ (instancetype)episodes:(NSArray *)ordered title:(NSString *)title;
+ (instancetype)archive:(NSDictionary *)archive title:(NSString *)title;
- (NSDictionary *)archive;
- (NSDictionary *)episodeForID:(NSString *)identifier;
@property(nonatomic,readonly) NSUInteger storageBytes;
@property(nonatomic,readonly) NSString *titleIdentifier;
@end
