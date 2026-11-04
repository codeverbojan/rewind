#import "../RWHomePreparation.h"
#import "../RWHomeCategoryPolicy.h"
#import "../RWHomeDelivery.h"
#import "../RWDiscoveryMetadataPolicy.h"
static NSString *RWID(NSDictionary *m){return m[@"id"]?:@"";}
@interface PriorMetadata:NSObject
- (NSDictionary *)record:(NSString *)key;
@end
@implementation PriorMetadata
- (NSDictionary *)record:(NSString *)key{return nil;}
@end
@interface PriorStore:NSObject
@property NSDictionary *profile,*discoveryHome;
@property PriorMetadata *discoveryMetadata;
@property BOOL restricted;
- (BOOL)allowed:(NSDictionary *)m;
- (NSDictionary *)availability:(NSDictionary *)m videoID:(NSString *)key;
- (NSString *)availabilityVideoID:(NSDictionary *)m;
@end
@implementation PriorStore
- (BOOL)allowed:(NSDictionary *)m{return YES;}
- (NSDictionary *)availability:(NSDictionary *)m videoID:(NSString *)key{return @{@"discovery_eligible":@YES};}
- (NSString *)availabilityVideoID:(NSDictionary *)m{return RWID(m);}
#include "HomeRailPriorUnderTest.inc"
@end
int main(){@autoreleasepool{int checks=0,failures=0;
#define C(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL%d %s\n",__LINE__,#__VA_ARGS__);}}while(0)
 PriorStore *s=[PriorStore new];s.profile=@{@"maxAge":@12};s.restricted=YES;s.discoveryHome=@{@"ratingPriors":@[@7.5,@7.5]};s.discoveryMetadata=[PriorMetadata new];
 NSDictionary *m=@{@"id":@"tt0432325",@"type":@"movie",@"name":@"The Cave of the Yellow Dog",@"genres":@[@"Family"],@"imdbRating":@7.5,@"imdbVotes":@3844,@"discovery":@{@"primaryLanguage":@"mn",@"languageSource":@"fixture",@"industry":@"other"}};
 C([s homeRailRecordAllowed:m row:@{@"recipe":@"world"}]);s.discoveryHome=@{@"ratingPriors":@[@6.5,@6.5]};C(![s homeRailRecordAllowed:m row:@{@"recipe":@"world"}]);s.discoveryHome=@{@"ratingPriors":@[@7.5,@7.5]};C([s homeRailRecordAllowed:m row:@{@"recipe":@"world"}]);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
