#import "../RWDiscoveryMetadata.h"
#import "../RWDiscoveryMetadataPolicy.h"
#import "../RWDiscoverySnapshot.h"
static NSDictionary *Claim(id value){return @{@"rank":@"normal",@"mainsnak":@{@"datavalue":@{@"value":value}}};}
static NSDictionary *Date(NSString *time,NSInteger precision){return Claim(@{@"time":time,@"precision":@(precision),@"before":@0,@"after":@0,@"calendarmodel":@"http://www.wikidata.org/entity/Q1985727"});}
static NSDictionary *Entity(NSArray *dates){return @{@"id":@"Q1",@"lastrevid":@23,@"claims":@{@"P345":@[Claim(@"tt1")],@"P577":dates}};}
static NSDictionary *Record(NSArray *dates){return [RWDiscoveryMetadataPolicy recordForEntity:Entity(dates) imdb:@"tt1" labels:@{}];}
int main(int argc,char **argv){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL release year line %d\n",__LINE__);}}while(0)
 NSDictionary *record=Record(@[Date(@"+2026-01-26T00:00:00Z",11),Date(@"+2026-11-19T00:00:00Z",11)]);
 CHECK([record[@"releaseYearEvidence"][@"year"]isEqual:@2026]);CHECK([record[@"releaseYearEvidence"][@"revision"]isEqual:@23]);
 CHECK(!Record(@[Date(@"+2025-11-19T00:00:00Z",11),Date(@"+2026-11-19T00:00:00Z",11)])[@"releaseYearEvidence"]);
 CHECK(!Record(@[Date(@"+2026-02-29T00:00:00Z",11)])[@"releaseYearEvidence"]);
 CHECK([Record(@[Date(@"+2024-02-29T00:00:00Z",11)])[@"releaseYearEvidence"][@"year"]isEqual:@2024]);
 CHECK([Record(@[Date(@"+2026-00-00T00:00:00Z",9)])[@"releaseYearEvidence"][@"year"]isEqual:@2026]);
 for(NSString *invalid in @[@"+2026-00-01T00:00:00Z",@"+2026-13-01T00:00:00Z",@"+2026-04-31T00:00:00Z",@"-2026-01-01T00:00:00Z",@"+1800-01-01T00:00:00Z",@"+2200-01-01T00:00:00Z",@"2026"]){CHECK(!Record(@[Date(invalid,11)])[@"releaseYearEvidence"]);}
 CHECK(!Record(@[Date(@"+2020-00-00T00:00:00Z",8)])[@"releaseYearEvidence"]);
 NSMutableDictionary *deprecated=[Date(@"+2020-01-01T00:00:00Z",11)mutableCopy];deprecated[@"rank"]=@"deprecated";
 CHECK([Record(@[deprecated,Date(@"+2026-01-01T00:00:00Z",11)])[@"releaseYearEvidence"][@"year"]isEqual:@2026]);
 CHECK(![RWDiscoveryMetadataPolicy recordForEntity:Entity(@[]) imdb:@"tt2" labels:@{}]);
 NSDictionary *film=@{@"id":@"tt1",@"type":@"movie",@"year":@"2020",@"releaseInfo":@"2020",@"released":@"2026-12-01T00:00:00Z"};
 NSDictionary *enriched=[RWDiscoveryMetadataPolicy enrich:film record:record];CHECK([enriched[@"year"]isEqual:@"2026"]);CHECK([enriched[@"releaseInfo"]isEqual:@"2026"]);CHECK([enriched[@"released"]isEqual:film[@"released"]]);CHECK([film[@"year"]isEqual:@"2020"]);
 NSMutableDictionary *series=[film mutableCopy];series[@"type"]=@"series";series[@"releaseInfo"]=@"2020–2026";CHECK([[RWDiscoveryMetadataPolicy enrich:series record:record][@"releaseInfo"]isEqual:@"2020–2026"]);
 NSMutableDictionary *wrong=[film mutableCopy];wrong[@"id"]=@"tt2";CHECK([[RWDiscoveryMetadataPolicy enrich:wrong record:record][@"year"]isEqual:@"2020"]);
 CHECK([[RWDiscoveryMetadataPolicy enrich:film record:@{@"imdb":@"tt1"}][@"year"]isEqual:@"2020"]);
 NSDictionary *snapshot=@{@"profile":@{@"maxAge":@(-1),@"saved":@[film]},@"metadata":@{@"tt1":record},@"quality":@0};
 NSDictionary *prepared=[RWDiscoverySnapshot prepare:@[film] snapshot:snapshot ratings:@{} now:1793000000];CHECK([prepared[@"items"][0][@"releaseInfo"]isEqual:@"2026"]);CHECK(![prepared[@"items"][0][@"availability"][@"hero_eligible"]boolValue]);
 CHECK([prepared[@"profile"][@"saved"][0][@"releaseInfo"]isEqual:@"2026"]);
 NSString *path=[NSTemporaryDirectory()stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".json"]];
 RWDiscoveryMetadata *service=[[RWDiscoveryMetadata alloc]initWithPath:path cached:@{@"titles":@{@"tt1":@{@"imdb":@"tt1",@"entityID":@"Q1",@"fetchedAt":@123,@"otherField":@"preserved"}}} seed:@{@"releaseYearEntities":@{@"tt1":Entity(@[Date(@"+2026-01-01T00:00:00Z",11)])}}];
 CHECK([[service enrich:film][@"releaseInfo"]isEqual:@"2026"]);CHECK([[service record:@"tt1"][@"fetchedAt"]isEqual:@123]);CHECK([[service record:@"tt1"][@"otherField"]isEqual:@"preserved"]);[service invalidate];
 NSDictionary *seed=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[1])] options:0 error:nil];
 RWDiscoveryMetadata *actual=[[RWDiscoveryMetadata alloc]initWithPath:path cached:@{} seed:seed];NSDictionary *actualTitle=@{@"id":@"tt10794054",@"type":@"movie",@"releaseInfo":@"2020"};CHECK([[actual enrich:actualTitle][@"releaseInfo"]isEqual:@"2026"]);[actual invalidate];
 CHECK(![NSFileManager.defaultManager fileExistsAtPath:path]);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
