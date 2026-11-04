#import <Foundation/Foundation.h>
#import "../RWTVPolicy.h"
#import "../RWTrailerPolicy.h"
static id Read(NSString *p){return [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:p] options:NSJSONReadingMutableContainers error:nil];}
int main(int argc,char **argv){@autoreleasepool{__block int checks=0,failures=0;void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *label){checks++;if(!ok){failures++;fprintf(stderr,"FAIL %s\n",label.UTF8String);}};NSString *root=@(argv[1]);
NSDictionary *show=Read([root stringByAppendingPathComponent:@"two-half-meta.json"])[@"meta"];NSArray *eps=[RWTVPolicy episodes:show];check(eps.count==263,@"Real series preserves all 263 uniquely identified episodes");
NSDate *now=[NSDate dateWithTimeIntervalSince1970:1792540000];NSDictionary *first=nil,*last=eps.lastObject;for(NSDictionary *e in eps)if([e[@"id"]isEqual:@"tt0369179:1:1"])first=e;
check([[RWTVPolicy nextEpisode:show history:@{} now:now][@"id"]isEqual:@"tt0369179:1:1"],@"New viewer starts at the first episode");
NSMutableDictionary *h=[NSMutableDictionary new];h[first[@"id"]]=@{@"position":@180,@"duration":@1200,@"updated":@100,@"completed":@NO};check([[RWTVPolicy nextEpisode:show history:h now:now][@"id"]isEqual:first[@"id"]],@"Partly watched episode resumes");
h[first[@"id"]]=@{@"position":@1200,@"updated":@100,@"completed":@YES};check([[RWTVPolicy nextEpisode:show history:h now:now][@"id"]isEqual:@"tt0369179:1:2"],@"Finished episode advances to next");
NSDictionary *finalSeason=eps[247];h[finalSeason[@"id"]]=@{@"position":@123,@"updated":@200,@"completed":@NO};check([[RWTVPolicy nextEpisode:show history:h now:now][@"id"]isEqual:finalSeason[@"id"]],@"Latest viewing session resumes across seasons");
h=[NSMutableDictionary new];h[last[@"id"]]=@{@"position":@1200,@"updated":@300,@"completed":@YES};check(![RWTVPolicy nextEpisode:show history:h now:now],@"Series finale does not restart episode one");
NSMutableDictionary *future=[first mutableCopy];future[@"released"]=@"2099-01-01T00:00:00.000Z";check(![RWTVPolicy released:future now:now],@"Future episode cannot autoplay");future[@"released"]=@"";check(![RWTVPolicy released:future now:now],@"Missing date is not assumed released");
NSMutableDictionary *bad=[first mutableCopy];bad[@"id"]=@"tt9999999:1:1";check([RWTVPolicy episodes:@{@"id":show[@"id"],@"videos":@[first,first,bad]}].count==1,@"Duplicate and wrong-series episode identifiers rejected");
NSArray *search=Read([root stringByAppendingPathComponent:@"two-half-search.json"])[@"metas"];NSMutableArray *pool=[NSMutableArray arrayWithObject:@{@"id":@"tt999",@"type":@"movie",@"name":@"Two Men"}];[pool addObjectsFromArray:search];[pool addObjectsFromArray:search];
NSArray *ranked=[RWTVPolicy search:pool query:@"  TWO AND A HALF MEN!! "];check([ranked.firstObject[@"id"]isEqual:@"tt0369179"],@"Exact title ranks above movies and partial series matches");check(ranked.count==5,@"Duplicate result IDs removed");
NSArray *ordered=[RWTVPolicy search:@[@{@"id":@"1",@"name":@"Men"},@{@"id":@"2",@"name":@"Two and a Half Men Special"},@{@"id":@"3",@"name":@"Two and a Half Men"}] query:@"two and a half men"];check([ordered[0][@"id"]isEqual:@"3"]&&[ordered[1][@"id"]isEqual:@"2"],@"Exact then prefix then partial matching");
NSArray *local=[RWTVPolicy localMatches:@[@{@"id":@"a",@"name":@"Toy Story"},@{@"id":@"b",@"name":@"Two and a Half Men"},@{@"id":@"c",@"name":@"Finding Nemo"}] query:@"two and a half"];check(local.count==1&&[local.firstObject[@"id"]isEqual:@"b"],@"Immediate offline search excludes unrelated cached titles");
check(![RWTVPolicy localMatches:pool query:@"!!!"].count,@"Punctuation-only input cannot display the entire local catalog");
NSArray *early=[RWTVPolicy search:@[@{@"id":@"partial",@"type":@"movie",@"name":@"Two Men"}] query:@"two and a half men"];
NSArray *merged=[RWTVPolicy search:[early arrayByAddingObjectsFromArray:search] query:@"two and a half men"];check([merged.firstObject[@"id"]isEqual:@"tt0369179"],@"Series arriving after movies moves the exact title to first position");
NSDictionary *meta=[RWTVPolicy episodeMeta:first show:show];check([meta[@"seriesName"]isEqual:@"Two and a Half Men"]&&[meta[@"season"]intValue]==1&&!meta[@"videos"],@"Playback retains show identity without copying all episodes");
check([RWTVPolicy newEpisodes:show seen:nil since:NSDate.distantPast now:now].count==0,@"Initial follow does not notify entire back catalog");
check([RWTVPolicy newEpisodes:show seen:@[] since:now now:now].count==0,@"Old missing metadata does not create new-episode alerts");
check([RWTVPolicy newEpisodes:show seen:[eps valueForKey:@"id"] since:NSDate.distantPast now:now].count==0,@"Previously seen episodes never notify twice");
check([RWTVPolicy newEpisodes:@{@"id":show[@"id"],@"videos":@[first]} seen:@[] since:NSDate.distantPast now:now].count==1,@"New released episode is detected");
NSDictionary *entity=Read([root stringByAppendingPathComponent:@"inception-entity.json"])[@"entities"][@"Q25188"];
NSArray *ids=[RWTrailerPolicy appleIDs:entity imdb:@"tt1375666"];check([ids containsObject:@"400763833"],@"Exact IMDb entity resolves official Apple movie ID");check(![RWTrailerPolicy appleIDs:entity imdb:@"tt0000000"].count,@"Wrong IMDb match rejected");
NSMutableDictionary *response=Read([root stringByAppendingPathComponent:@"apple-inception-lookup.json"]);NSDictionary *movie=@{@"id":@"tt1375666",@"name":@"Inception",@"type":@"movie",@"releaseInfo":@"2010"};
check([RWTrailerPolicy source:response ids:ids meta:movie]!=nil,@"Real Apple lookup supplies matching native preview");
check(![RWTrailerPolicy source:response ids:@[@"123"] meta:movie],@"Unmatched catalog ID rejected");NSMutableDictionary *wrong=[movie mutableCopy];wrong[@"releaseInfo"]=@"2011";check(![RWTrailerPolicy source:response ids:ids meta:wrong],@"Wrong release year rejected");wrong[@"releaseInfo"]=@"2010";wrong[@"name"]=@"Inception 2";check(![RWTrailerPolicy source:response ids:ids meta:wrong],@"Similar title is not accepted");
response[@"results"][0][@"previewUrl"]=@"https://video-ssl.itunes.apple.com.evil.invalid/movie.mp4";check(![RWTrailerPolicy source:response ids:ids meta:movie],@"Lookalike media domain rejected");
check([[RWTrailerPolicy embeddedSource:show][@"youtubeID"]isEqual:@"E7ap_eCWxYI"],@"Real series metadata provides an inline trailer without movie-only restriction");
NSDictionary *youtube=@{@"type":@"movie",@"id":@"tt1375666",@"trailers":@[@{@"type":@"Trailer",@"source":@"cdx31ak4KbQ"}]};
check([RWTrailerPolicy embeddedSource:youtube]!=nil,@"Movie trailer metadata can use the embedded player");
check(![RWTrailerPolicy embeddedSource:@{@"type":@"movie",@"trailers":@[@{@"type":@"Trailer",@"source":@"x';alert(1)//"}]}],@"Invalid video ID cannot inject script into embedded player");
check(![RWTrailerPolicy embeddedSource:@{@"type":@"movie",@"trailers":@[@{@"type":@"Clip",@"source":@"cdx31ak4KbQ"}]}],@"Unlabelled clips are not silently promoted to trailers");
printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;}}
