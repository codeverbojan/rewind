#import <Foundation/Foundation.h>
#import "../RWCast.h"
static id Read(NSString *p){return [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:p] options:NSJSONReadingMutableContainers error:nil];}
int main(int argc,char **argv){@autoreleasepool{
    __block int checks=0,failures=0;void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *label){checks++;if(!ok){failures++;fprintf(stderr,"FAIL %s\n",label.UTF8String);}};NSString *root=@(argv[1]);
    NSMutableDictionary *show=Read([root stringByAppendingPathComponent:@"tvmaze-cast.json"]);
    check([[RWCast showID:show imdb:@"tt0369179"]isEqual:@"130"],@"Exact IMDb resolves the correct TVmaze show");
    check(![RWCast showID:show imdb:@"tt0000000"],@"Wrong show cannot inherit cast photographs");
    NSArray *people=[RWCast tvPeople:show imdb:@"tt0369179"];
    check(people.count>3&&people.count<=12,@"Real show cast is bounded and includes more than the three catalog names");
    check([people.firstObject[@"image"]hasPrefix:@"https://static.tvmaze.com/"],@"Actual portrait uses the documented image CDN");
    NSMutableDictionary *person=show[@"_embedded"][@"cast"][0][@"person"];
    person[@"image"]=@{@"medium":@"https://static.tvmaze.com.evil.invalid/photo.jpg"};
    check(![[RWCast tvPeople:show imdb:@"tt0369179"]firstObject][@"image"]||![[[RWCast tvPeople:show imdb:@"tt0369179"]firstObject][@"image"]length],@"Lookalike image host rejected");
    person[@"image"]=[NSNull null];check([RWCast tvPeople:show imdb:@"tt0369179"].count==people.count,@"Missing photo preserves actor name and role");
    NSDictionary *entity=Read([root stringByAppendingPathComponent:@"movie-entity.json"])[@"entities"][@"Q25188"];
    NSArray *ids=[RWCast actorIDs:entity imdb:@"tt1375666"];
    check([ids containsObject:@"Q38111"],@"Actor identity comes from the exact film credit relationship");
    check(![RWCast actorIDs:entity imdb:@"tt9999999"].count,@"Different film identity cannot reuse actor list");
    NSMutableDictionary *entities=Read([root stringByAppendingPathComponent:@"movie-people.json"])[@"entities"];
    NSArray *names=@[@"Leonardo DiCaprio",@"Joseph Gordon-Levitt",@"Elliot Page"];
    people=[RWCast wikiPeople:entities names:names];check(people.count==3,@"All three catalog actors match credited entities");
    check(![RWCast wikiPeople:entities names:@[@"Unrelated Person"]].count,@"Unrelated person is never selected by resemblance");
    entities[@"Q999999999"]=[entities[@"Q38111"]mutableCopy];check([RWCast wikiPeople:entities names:@[@"Leonardo DiCaprio"]].count==0,@"Ambiguous actor identity fails closed");
    NSMutableDictionary *photos=Read([root stringByAppendingPathComponent:@"movie-photos.json"]);
    NSArray *resolved=[RWCast photos:photos people:people];check(resolved.count==3,@"Real Commons records supply all three small portraits with credits");
    for(NSMutableDictionary *page in [photos[@"query"][@"pages"]allValues]){page[@"imageinfo"][0][@"thumburl"]=@"https://upload.wikimedia.org.evil.invalid/photo.jpg";}
    check(![RWCast photos:photos people:people].count,@"Image-source lookalikes rejected for movies too");
    photos=Read([root stringByAppendingPathComponent:@"movie-photos.json"]);for(NSMutableDictionary *page in [photos[@"query"][@"pages"]allValues])[page[@"imageinfo"][0][@"extmetadata"]removeObjectForKey:@"Artist"];
    check(![RWCast photos:photos people:people].count,@"No movie photograph displayed without attribution");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
