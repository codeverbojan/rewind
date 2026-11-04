#import "RWCatalogSearch.h"
// Instantiated only by an admitted, bounded search-network device exercise.
// Fixed loopback endpoint: no request can supply an arbitrary test address.
@interface RWExerciseCatalogSearch:RWCatalogSearch @end
@implementation RWExerciseCatalogSearch
+ (NSURL *)URLForType:(NSString *)type query:(NSString *)query {
    NSString *q=[query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"]];
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:18882/catalog?type=%@&q=%@",type,q]];
}
@end
#import "RWDiscoveryMetadata.h"
@interface RWExerciseEntityMetadata:RWDiscoveryMetadata @end
@implementation RWExerciseEntityMetadata
+ (NSURL *)URLForRequest:(NSString *)request {
    NSURL *original=[super URLForRequest:request];if(![original.host isEqual:@"www.wikidata.org"]||![original.path isEqual:@"/w/api.php"])return nil;
    NSString *value=[request stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"]];
    return [NSURL URLWithString:[@"http://127.0.0.1:18882/entity?url=" stringByAppendingString:value]];
}
- (void)persist {} // Fixture responses never enter the real metadata cache.
@end
