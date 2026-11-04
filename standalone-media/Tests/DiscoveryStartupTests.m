#import <Foundation/Foundation.h>
#import "../RWHomeDelivery.h"
static int checks,failures;
#define C(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL %d %s\n",__LINE__,#__VA_ARGS__);}}while(0)
@interface Metadata:NSObject
@property NSDictionary *record;
- (NSDictionary *)titleSnapshot;
- (NSDictionary *)snapshot;
@end
@implementation Metadata
- (NSDictionary *)titleSnapshot{return self.record;}
- (NSDictionary *)snapshot{return self.record;}
@end
@interface Store:NSObject {NSDictionary *_offlineEvidence;double _offlineEvidenceAt;}
@property BOOL restricted;
@property NSInteger quality;
@property NSMutableDictionary *profile;
@property NSArray *familyCatalog,*freshMovies,*freshSeries,*movies,*series,*discoveryCatalog,*curatedMovies,*curatedSeries,*saved;
@property NSDictionary *shows;
@property Metadata *discoveryMetadata,*ratings;
- (NSDictionary *)discoveryShows;
- (NSDictionary *)discoveryInputSnapshot;
@end
@implementation Store
- (NSDictionary *)discoveryShows{return self.shows;}
#include "discovery-snapshot-under-test.inc"
@end
int main(){@autoreleasepool{
 Store *s=[Store new];s.profile=[@{@"maxAge":@(-1),@"history":[@{} mutableCopy],@"sourceAvailability":@{},@"discoveryExposures":@{}} mutableCopy];
 for(NSNumber *kids in @[@NO,@YES]){s.restricted=kids.boolValue;NSDictionary *d=[s discoveryInputSnapshot];C([d[@"groups"]count]==10);for(NSArray *a in d[@"groups"])C(a.count==0);C([d[@"family"]count]==0&&[d[@"metadata"]count]==0&&[d[@"ageRatings"]count]==0&&[d[@"shows"]count]==0);C([NSJSONSerialization isValidJSONObject:d]);}
 s.discoveryMetadata=[Metadata new];s.ratings=[Metadata new];C([[s discoveryInputSnapshot][@"metadata"]count]==0);
 s.discoveryMetadata.record=@{@"tt1":@{@"genres":@[]}};s.ratings.record=@{@"tt1":@{@"minimumAge":@12}};s.familyCatalog=@[@{@"id":@"tt1"}];s.shows=@{@"tt1":@{}};
 NSDictionary *d=[s discoveryInputSnapshot];C([d[@"family"]count]==1&&[d[@"groups"][0]count]==1);C([d[@"metadata"]isEqual:s.discoveryMetadata.record]);C([d[@"ageRatings"]isEqual:s.ratings.record]);C([d[@"shows"]isEqual:s.shows]);
 s.profile[@"history"][@"tt1"]=@{@"position":@10};C([d[@"profile"][@"history"]count]==0);s.restricted=NO;C([[s discoveryInputSnapshot][@"groups"][0]count]==0);
 // A title can leave a rotating provider page while its own profile still
 // retains acquired metadata. Include that metadata, not stale availability.
 NSDictionary *retained=@{@"id":@"tt39571",@"name":@"Previously discovered film",@"type":@"movie",@"genres":@[@"Family"],@"availability":@{@"discovery_eligible":@YES},@"ageAllowed":@YES,@"videos":@[@{@"id":@"unwanted"}]};
 s.profile[@"sourceAvailability"]=@{@"tt39571":@{@"state":@"candidates",@"meta":retained,@"checked":@100}};
 NSDictionary *own=[s discoveryInputSnapshot];NSArray *recovered=[own[@"groups"]lastObject];C(recovered.count==1);C([recovered.firstObject[@"id"]isEqual:@"tt39571"]);C(!recovered.firstObject[@"availability"]&&!recovered.firstObject[@"ageAllowed"]&&!recovered.firstObject[@"videos"]);
 s.profile[@"sourceAvailability"]=@{};C([[[s discoveryInputSnapshot][@"groups"]lastObject]count]==0);C([[[own[@"groups"]lastObject]firstObject][@"id"]isEqual:@"tt39571"]);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
