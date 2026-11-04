#import "../RWDiscoveryMetadataPolicy.h"
static NSDictionary *Claim(id value){return @{@"mainsnak":@{@"datavalue":@{@"value":value}}};}
static NSDictionary *Entity(NSArray *classes){NSMutableArray *claims=[NSMutableArray new];for(NSString *qid in classes)[claims addObject:Claim(@{@"id":qid})];return @{@"id":@"Q20",@"claims":@{@"P31":claims,@"P345":@[Claim(@"tt20")]}};}
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
 NSDictionary *labels=@{@"Q1":@{@"labels":@{@"en":@{@"value":@"television series episode"}}},@"Q2":@{@"labels":@{@"en":@{@"value":@"television series season"}}},@"Q3":@{@"labels":@{@"en":@{@"value":@"film series"}}},@"Q4":@{@"labels":@{@"en":@{@"value":@"short film"}}},@"Q5":@{@"labels":@{@"en":@{@"value":@"miniseries"}}},@"Q6":@{@"labels":@{@"en":@{@"value":@"film festival"}}}};
 for(NSString *bad in @[@"Q21191270",@"Q1",@"Q2",@"Q3"])for(NSArray *classes in @[@[bad],@[bad,@"Q5398426"],@[@"Q5398426",bad],@[@"Q11424",bad]])CHECK([[RWDiscoveryMetadataPolicy creditTypeForEntity:Entity(classes) labels:labels]isEqual:@"installment"]);
 CHECK([[RWDiscoveryMetadataPolicy creditTypeForEntity:Entity(@[@"Q11424"]) labels:labels]isEqual:@"movie"]);
 CHECK([[RWDiscoveryMetadataPolicy creditTypeForEntity:Entity(@[@"Q4"]) labels:labels]isEqual:@"movie"]);
 CHECK([[RWDiscoveryMetadataPolicy creditTypeForEntity:Entity(@[@"Q5398426"]) labels:labels]isEqual:@"series"]);
 CHECK([[RWDiscoveryMetadataPolicy creditTypeForEntity:Entity(@[@"Q5"]) labels:labels]isEqual:@"series"]);
 for(NSArray *classes in @[@[],@[@"Q6"],@[@"Q11424",@"Q5398426"]])CHECK([[RWDiscoveryMetadataPolicy creditTypeForEntity:Entity(classes) labels:labels]isEqual:@"unknown"]);
 NSDictionary *episode=[RWDiscoveryMetadataPolicy recordForEntity:Entity(@[@"Q21191270"]) imdb:@"tt20" labels:labels];CHECK([episode[@"creditWorkType"]isEqual:@"installment"]&&[episode[@"creditTypePolicy"]isEqual:@1]);
 NSDictionary *raw=@{@"id":@"tt20",@"type":@"series",@"creditEntityID":@"Q10"},*catalog=@{@"id":@"tt20",@"type":@"series"};
 CHECK(![RWDiscoveryMetadataPolicy allowsRetainedCredit:raw record:episode]);CHECK(![RWDiscoveryMetadataPolicy allowsRetainedCredit:catalog record:episode]);
 CHECK(![RWDiscoveryMetadataPolicy allowsRetainedCredit:raw record:@{}]);CHECK([RWDiscoveryMetadataPolicy allowsRetainedCredit:catalog record:@{}]);
 NSDictionary *series=[RWDiscoveryMetadataPolicy recordForEntity:Entity(@[@"Q5398426"]) imdb:@"tt20" labels:labels];CHECK([RWDiscoveryMetadataPolicy allowsRetainedCredit:raw record:series]);
 CHECK(![RWDiscoveryMetadataPolicy allowsRetainedCredit:@{@"id":@"tt20",@"type":@"movie"} record:series]);
 CHECK(![RWDiscoveryMetadataPolicy allowsRetainedCredit:@{@"id":@"tt21",@"type":@"series",@"creditEntityID":@"Q10"} record:series]);
 NSDictionary *(^date)(NSString *)=^NSDictionary *(NSString *year){return @{@"time":[NSString stringWithFormat:@"+%@-00-00T00:00:00Z",year],@"precision":@9,@"calendarmodel":@"http://www.wikidata.org/entity/Q1985727"};};
 NSDictionary *dated=@{@"claims":@{@"P580":@[Claim(date(@"2011"))],@"P577":@[Claim(date(@"2016"))]}};
 CHECK([[RWDiscoveryMetadataPolicy creditReleaseYearForEntity:dated type:@"series"]isEqual:@"2011"]);
 CHECK([[RWDiscoveryMetadataPolicy creditReleaseYearForEntity:dated type:@"movie"]isEqual:@"2016"]);
 CHECK([[RWDiscoveryMetadataPolicy creditReleaseYearForEntity:@{@"claims":@{@"P577":@[Claim(date(@"2016"))]}} type:@"series"]isEqual:@"2016"]);
 CHECK(![RWDiscoveryMetadataPolicy creditReleaseYearForEntity:@{@"claims":@{@"P580":@[Claim(date(@"2011")),Claim(date(@"2016"))]}} type:@"series"].length);
 CHECK(![RWDiscoveryMetadataPolicy creditReleaseYearForEntity:@{@"claims":@{@"P580":@[Claim(date(@"9999"))]}} type:@"series"].length);
 NSDictionary *qualified=@{@"claims":@{@"P449":@[@{@"mainsnak":@{@"datavalue":@{@"value":@{@"id":@"Q1"}}},@"qualifiers":@{@"P580":@[Claim(date(@"2016"))]}}]}};
 CHECK([[RWDiscoveryMetadataPolicy creditReleaseYearForEntity:@{@"claims":@{@"P577":@[Claim(date(@"2016")),Claim(date(@"2017"))]}} type:@"movie"]isEqual:@"2016"]);
 CHECK(![RWDiscoveryMetadataPolicy creditReleaseYearForEntity:qualified type:@"series"].length);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
