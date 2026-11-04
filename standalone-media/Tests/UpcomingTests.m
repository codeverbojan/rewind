#import "../RWUpcomingPolicy.h"
#import "../RWAvailability.h"
#import "../RWDiscoveryMetadataPolicy.h"
#include <math.h>
static NSDictionary *S(id v){return @{@"rank":@"normal",@"mainsnak":@{@"datavalue":@{@"value":v}}};}
static NSDictionary *D(NSString *t,NSInteger p){return S(@{@"time":t,@"precision":@(p)});}
static NSDictionary *E(NSArray *dates){return @{@"id":@"Q1234",@"labels":@{@"en":@{@"value":@"Fixture film"}},@"claims":@{@"P31":@[S(@{@"id":@"Q11424"})],@"P345":@[S(@"tt1234567")],@"P577":dates,@"P364":@[S(@{@"id":@"Q1860"})]}};}
int main(int argc,char **argv){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    double now=1792706400;NSArray *(^titles)(NSArray *)=^NSArray *(NSArray *dates){return [RWUpcomingPolicy titles:@{@"Q1234":E(dates)} now:now];};
    CHECK(titles(@[D(@"+2027-05-21T00:00:00Z",11)]).count==1);
    CHECK([titles(@[D(@"+2027-05-21T00:00:00Z",11)])[0][@"released"]isEqual:@"2027-05-21"]);
    CHECK(titles(@[D(@"+2027-00-00T00:00:00Z",9)]).count==1);
    CHECK(!titles(@[D(@"+2027-00-00T00:00:00Z",9)])[0][@"released"]);
    CHECK(titles(@[D(@"+2026-11-20T00:00:00Z",11)]).count==1);
    CHECK(!titles(@[D(@"+2026-00-00T00:00:00Z",9)]).count);
    CHECK(!titles(@[D(@"+2026-11-00T00:00:00Z",10)]).count);
    CHECK(!titles(@[D(@"+2020-01-01T00:00:00Z",11),D(@"+2027-01-01T00:00:00Z",11)]).count);
    CHECK(!titles(@[D(@"+2027-01-01T00:00:00Z",11),D(@"+2020-01-01T00:00:00Z",11)]).count);
    CHECK(!titles(@[D(@"+2027-02-30T00:00:00Z",11)]).count);
    CHECK(!titles(@[D(@"+2027-00-00T00:00:00Z",11)]).count);
    CHECK(!titles(@[D(@"bad",11)]).count);
    CHECK(!titles(@[]).count);
    NSMutableDictionary *deprecated=[D(@"+2020-01-01T00:00:00Z",11)mutableCopy];deprecated[@"rank"]=@"deprecated";
    CHECK(titles(@[deprecated,D(@"+2027-01-01T00:00:00Z",11)]).count==1);
    NSMutableDictionary *entity=[E(@[D(@"+2027-01-01T00:00:00Z",11)])mutableCopy],*claims=[entity[@"claims"]mutableCopy];entity[@"claims"]=claims;claims[@"P345"]=@[S(@"tt1234567"),S(@"tt7654321")];
    CHECK(![RWUpcomingPolicy titles:@{@"Q1234":entity} now:now].count);
    claims[@"P345"]=@[S(@"tt1234567")];claims[@"P31"]=@[S(@{@"id":@"Q5"})];CHECK(![RWUpcomingPolicy titles:@{@"Q1234":entity} now:now].count);
    claims[@"P31"]=@[S(@{@"id":@"Q5398426"})];CHECK([[RWUpcomingPolicy titles:@{@"Q1234":entity} now:now][0][@"type"]isEqual:@"series"]);
    NSArray *valid=titles(@[D(@"+2027-01-01T00:00:00Z",11)]);
    CHECK([RWUpcomingPolicy merge:valid incoming:valid now:now].count==1);
    CHECK(![RWUpcomingPolicy merge:valid incoming:@[] now:now+7*86400+1].count);
    CHECK(![RWUpcomingPolicy merge:valid incoming:@[] now:now-1].count);
    NSMutableArray *large=[NSMutableArray new];for(int i=0;i<110;i++){NSMutableDictionary *m=[valid[0]mutableCopy];m[@"id"]=[NSString stringWithFormat:@"tt%07d",i];[large addObject:m];}CHECK([RWUpcomingPolicy merge:large incoming:@[] now:now].count==96);
    NSArray *requests=[RWUpcomingPolicy requests:[NSDate dateWithTimeIntervalSince1970:now]];CHECK(requests.count==4);CHECK([requests[0]containsString:@"2026"]);CHECK([requests[1]containsString:@"2027"]);
    for(NSString *url in requests){CHECK([[NSURL URLWithString:url].host isEqual:@"www.wikidata.org"]);CHECK(![url containsString:@" "]&&[url containsString:@"srlimit=24"]);}
    NSData *data=[NSData dataWithContentsOfFile:@(argv[1])];NSDictionary *live=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];NSArray *actual=[RWUpcomingPolicy titles:live[@"entities"] now:now];CHECK(actual.count>=5);
    BOOL hunger=NO,past=NO,english=NO,world=NO;for(NSDictionary *m in actual){if([m[@"name"]containsString:@"Sunrise on the Reaping"])hunger=YES;if([m[@"name"]isEqual:@"Les Misérables"])past=YES;NSString *lang=[RWDiscoveryMetadataPolicy languageGroup:m[@"discovery"]];if([lang isEqual:@"english"])english=YES;if([lang isEqual:@"world"])world=YES;}
    CHECK(hunger&&!past);CHECK(english&&world);
    NSArray *scheduleURLs=[RWUpcomingPolicy scheduleRequests:[NSDate dateWithTimeIntervalSince1970:now] days:2];CHECK(scheduleURLs.count==6);CHECK([RWUpcomingPolicy scheduleRequests:NSDate.date days:100].count==84);CHECK(![RWUpcomingPolicy scheduleRequests:NSDate.date days:0].count);
    CHECK([scheduleURLs[0]containsString:@"country=US"]&&[scheduleURLs[1]containsString:@"country=GB"]&&[scheduleURLs[2]containsString:@"schedule/web?"]);CHECK(![scheduleURLs[2]containsString:@"country="]);
    NSDictionary *show=@{@"id":@123,@"url":@"https://www.tvmaze.com/shows/123/example",@"name":@"Fixture series",@"type":@"Scripted",@"language":@"English",@"premiered":@"2020-01-01",@"externals":@{@"imdb":@"tt1234567"},@"image":@{@"medium":@"https://static.tvmaze.com/example.jpg"}};
    NSMutableDictionary *episode=[@{@"season":@2,@"number":@3,@"name":@"New episode",@"airstamp":@"2026-10-23T21:00:00+00:00",@"show":show}mutableCopy];
    NSArray *(^schedule)(id)=^NSArray *(id row){return [RWUpcomingPolicy scheduledTitles:@[row] now:now query:scheduleURLs[0]];};
    NSArray *scheduled=schedule(episode);CHECK(scheduled.count==1);NSDictionary *next=scheduled.firstObject;
    CHECK([next[@"released"]isEqual:@"2020-01-01"]);CHECK([next[@"scheduledEpisode"][@"id"]isEqual:@"tt1234567:2:3"]);CHECK([RWUpcomingPolicy scheduled:next now:now]);
    CHECK(![RWAvailability futureRelease:next now:now]);CHECK(!next[@"imdbRating"]);CHECK([RWUpcomingPolicy scheduleLabel:next].length>10);
    CHECK([RWDiscoveryMetadataPolicy permits:next preferences:@{@"excludeBollywood":@YES} world:NO]);
    CHECK([RWUpcomingPolicy merge:scheduled incoming:scheduled now:now].count==1);
    CHECK(![RWUpcomingPolicy merge:scheduled incoming:@[] now:now+86401].count);
    CHECK(![RWUpcomingPolicy scheduled:next now:[next[@"scheduledEpisode"][@"airAt"]doubleValue]]);
    NSMutableDictionary *later=[episode mutableCopy];later[@"number"]=@4;later[@"airstamp"]=@"2026-10-24T21:00:00+00:00";
    CHECK([[RWUpcomingPolicy merge:schedule(later) incoming:scheduled now:now][0][@"scheduledEpisode"][@"episode"]intValue]==3);
    CHECK([[RWUpcomingPolicy merge:scheduled incoming:schedule(later) now:now][0][@"scheduledEpisode"][@"episode"]intValue]==3);
    NSMutableDictionary *embedded=[episode mutableCopy];[embedded removeObjectForKey:@"show"];embedded[@"_embedded"]=@{@"show":show};CHECK(schedule(embedded).count==1);
    for(id invalid in @[NSNull.null,@"bad",@{},@{@"show":@"bad"}])CHECK(!schedule(invalid).count);
    for(id invalid in @[NSNull.null,@0,@(-1),@1.5,@"3"]){NSMutableDictionary *bad=[episode mutableCopy];bad[@"number"]=invalid;CHECK(!schedule(bad).count);}
    for(NSString *invalid in @[@"",@"bad",@"2026-10-01T21:00:00+00:00",@"2027-10-01T21:00:00+00:00",@"2026-13-01T21:00:00+00:00"]){NSMutableDictionary *bad=[episode mutableCopy];bad[@"airstamp"]=invalid;CHECK(!schedule(bad).count);}
    for(NSString *kind in @[@"News",@"Talk Show",@"Reality",@""]){NSMutableDictionary *badShow=[show mutableCopy];badShow[@"type"]=kind;NSMutableDictionary *bad=[episode mutableCopy];bad[@"show"]=badShow;CHECK(!schedule(bad).count);}
    NSDictionary *tv=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[2])] options:0 error:nil];NSArray *liveSchedule=[RWUpcomingPolicy scheduledTitles:tv[@"episodes"] now:[tv[@"now"]doubleValue] query:@"fixture"];
    CHECK(liveSchedule.count>0);for(NSDictionary *m in liveSchedule){CHECK([m[@"type"]isEqual:@"series"]&&[RWUpcomingPolicy scheduled:m now:[tv[@"now"]doubleValue]]);CHECK([m[@"upcomingSource"]hasPrefix:@"https://www.tvmaze.com/shows/"]);CHECK(!m[@"imdbRating"]);}
    // More than96 early shows must not suppress any later-date bucket. The
    // reverse premiere dates deliberately expose the old series-date ordering.
    NSMutableArray *crowded=[NSMutableArray new];double first=floor(now/86400)*86400+86400+3600;
    for(int i=0;i<120;i++){NSMutableDictionary *m=[next mutableCopy],*ep=[next[@"scheduledEpisode"]mutableCopy];NSString *key=[NSString stringWithFormat:@"tt%07d",1000+i];m[@"id"]=key;m[@"name"]=[NSString stringWithFormat:@"Series %03d",i];m[@"released"]=i<110?@"2020-01-01":@"1990-01-01";ep[@"id"]=[key stringByAppendingString:@":2:3"];ep[@"airAt"]=@(first+(i<110?0:86400));m[@"scheduledEpisode"]=ep;[crowded addObject:m];}
    NSArray *page=[RWUpcomingPolicy merge:@[] incoming:[crowded subarrayWithRange:NSMakeRange(0,110)] now:now];CHECK(page.count==96);
    page=[RWUpcomingPolicy merge:page incoming:[crowded subarrayWithRange:NSMakeRange(110,10)] now:now];CHECK(page.count==106);CHECK([page.firstObject[@"scheduledEpisode"][@"airAt"]doubleValue]==first);CHECK([page.lastObject[@"scheduledEpisode"][@"airAt"]doubleValue]==first+86400);
    CHECK([[page valueForKey:@"id"]containsObject:@"tt0001119"]);CHECK([[RWUpcomingPolicy merge:page incoming:page now:now]isEqual:page]);
    // Use absolute time even when textual offsets sort in the opposite order.
    NSMutableDictionary *earlier=[crowded[0]mutableCopy],*laterTitle=[crowded[1]mutableCopy];NSMutableDictionary *earlyEp=[earlier[@"scheduledEpisode"]mutableCopy],*lateEp=[laterTitle[@"scheduledEpisode"]mutableCopy];earlyEp[@"airAt"]=@(first);earlyEp[@"airstamp"]=@"2026-10-24T09:00:00+09:00";lateEp[@"airAt"]=@(first+3600);lateEp[@"airstamp"]=@"2026-10-24T01:00:00+00:00";earlier[@"scheduledEpisode"]=earlyEp;laterTitle[@"scheduledEpisode"]=lateEp;
    CHECK([[[RWUpcomingPolicy orderedTitles:@[laterTitle,earlier]]firstObject][@"id"]isEqual:earlier[@"id"]]);
    NSDictionary *isoFilm=@{@"id":@"tt1000011",@"name":@"December film",@"released":@"2026-12-02T00:00:00.000Z"},*plainFilm=@{@"id":@"tt1000012",@"name":@"November film",@"released":@"2026-11-03"},*yearFilm=@{@"id":@"tt1000013",@"name":@"Next year film",@"releaseInfo":@"2027"};
    CHECK([[RWUpcomingPolicy orderedTitles:@[yearFilm,isoFilm,plainFilm]]isEqual:@[plainFilm,isoFilm,yearFilm]]);
    CHECK([[RWUpcomingPolicy orderedTitles:@[isoFilm,yearFilm]]firstObject]==isoFilm);
    // Worst bounded window: oversized metadata also respects per-date bytes,
    // independently of the96-title limit, and keeps all requested dates.
    NSMutableArray *window=[NSMutableArray new];NSString *padding=[@"x" stringByPaddingToLength:2400 withString:@"x" startingAtIndex:0];
    for(int day=0;day<28;day++)for(int i=0;i<110;i++){NSMutableDictionary *m=[next mutableCopy],*ep=[next[@"scheduledEpisode"]mutableCopy];NSString *key=[NSString stringWithFormat:@"tt%07d",10000+day*110+i];m[@"id"]=key;m[@"description"]=padding;ep[@"id"]=[key stringByAppendingString:@":2:3"];ep[@"airAt"]=@(first+day*86400);m[@"scheduledEpisode"]=ep;[window addObject:m];}
    NSArray *bounded=[RWUpcomingPolicy merge:window incoming:large now:now];NSData *serialized=[NSJSONSerialization dataWithJSONObject:@{@"items":bounded,@"schema":@(RWUpcomingCacheSchema)} options:0 error:nil];CHECK(serialized.length<RWUpcomingCacheBytes);CHECK(bounded.count<28*96+96);
    NSMutableSet *days=[NSMutableSet new];BOOL monotonic=YES;double previous=0;for(NSDictionary *m in bounded)if(m[@"scheduledEpisode"]){double t=[m[@"scheduledEpisode"][@"airAt"]doubleValue];if(t<previous)monotonic=NO;previous=t;[days addObject:@(floor(t/86400))];}CHECK(days.count==28&&monotonic);
    NSDictionary *cache=@{@"schema":@(RWUpcomingCacheSchema),@"day":[RWUpcomingPolicy day:[NSDate dateWithTimeIntervalSince1970:now]],@"days":@8,@"checked":@(now-10)};
    CHECK([RWUpcomingPolicy cachedDays:cache now:now]==8);
    for(NSDictionary *change in @[@{@"schema":@1},@{@"schema":NSNull.null},@{@"days":@(-1)},@{@"days":@29},@{@"days":@2.5},@{@"checked":@(now+1)},@{@"checked":@(now-86400)},@{@"day":@"2000-01-01"}]){NSMutableDictionary *bad=[cache mutableCopy];[bad addEntriesFromDictionary:change];CHECK([RWUpcomingPolicy cachedDays:bad now:now]==0);}
    printf("{\"checks\":%d,\"failures\":%d,\"live_fixture_upcoming\":%lu}\n",checks,failures,(unsigned long)actual.count);return failures?1:0;
}}
