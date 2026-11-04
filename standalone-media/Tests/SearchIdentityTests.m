#import <Foundation/Foundation.h>
#import "../RWTVPolicy.h"
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
NSDictionary *source=@{@"url":@"magnet:?xt=urn:btih:public",@"publisherSource":@"https://www.blender.org/"};
for(NSArray *film in @[@[@"rw:sintel",@"tt1727587",@"Sintel",@"2010"],@[@"rw:cosmos",@"tt4957236",@"Cosmos Laundromat",@"2015"]]){
 NSDictionary *pub=@{@"id":film[0],@"name":film[2],@"releaseInfo":film[3],@"type":@"movie",@"source":source,@"subtitles":@[@"public captions"],@"ageAllowed":@NO,@"availability":@"unknown",@"poster":@"public-landscape"};
 NSDictionary *remote=@{@"id":film[1],@"name":film[2],@"releaseInfo":film[3],@"type":@"movie",@"source":@{@"url":@"unrelated"},@"poster":@"canonical-poster",@"imdbRating":@"7.4",@"ageAllowed":@YES,@"availability":@"ready"};
 for(NSArray *items in @[@[pub,remote],@[remote,pub],@[pub,remote,remote,pub]]){
  NSArray *found=[RWTVPolicy search:items query:film[2]];CHECK(found.count==1);NSDictionary *m=found.firstObject;
  CHECK([m[@"id"]isEqual:film[0]]);CHECK([m[@"source"]isEqual:source]);CHECK([m[@"subtitles"]isEqual:pub[@"subtitles"]]);CHECK([m[@"ageAllowed"]isEqual:@NO]);CHECK([m[@"availability"]isEqual:@"unknown"]);CHECK([m[@"poster"]isEqual:@"canonical-poster"]);CHECK([m[@"imdbRating"]isEqual:@"7.4"]);CHECK([m[@"imdb_id"]isEqual:film[1]]);
 }
 NSMutableDictionary *partial=[pub mutableCopy];[partial removeObjectForKey:@"source"];
 NSArray *found=[RWTVPolicy search:@[partial,remote,pub] query:film[2]];CHECK(found.count==1);CHECK([found.firstObject[@"source"]isEqual:source]);CHECK([found.firstObject[@"poster"]isEqual:@"canonical-poster"]);
 for(NSString *field in @[@"id",@"type",@"name",@"releaseInfo"]){NSMutableDictionary *other=[remote mutableCopy];other[field]=[field isEqual:@"releaseInfo"]?@"2020":@"other";CHECK([RWTVPolicy search:@[pub,other] query:film[2]].count==2);}
 CHECK([[RWTVPolicy search:@[remote] query:film[2]]isEqual:@[remote]]);CHECK([[RWTVPolicy localMatches:@[pub,remote] query:film[2]]firstObject][@"source"]!=nil);
 CHECK([pub[@"poster"]isEqual:@"public-landscape"]);CHECK(!pub[@"imdb_id"]);
}
NSDictionary *exact=@{@"id":@"tt0369179",@"name":@"Two and a Half Men",@"type":@"series"},*partial=@{@"id":@"ttother",@"name":@"The Making of Two and a Half Men",@"type":@"movie"};
CHECK([[[RWTVPolicy search:@[partial,exact] query:@"two and a half men"]firstObject]isEqual:exact]);CHECK([RWTVPolicy search:@[exact,exact] query:@"two"].count==1);
printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
