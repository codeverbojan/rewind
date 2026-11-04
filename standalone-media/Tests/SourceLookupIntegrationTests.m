#import <Foundation/Foundation.h>
#import "../RWSourcePolicy.h"
#import "../RWSourceCache.h"
#import "../RWSourceWork.h"
#import "../RWRequestCoalescer.h"
#import "../RWAvailability.h"
typedef void (^RWResult)(id,NSString *);
static NSString *RWString(id v){return [v isKindOfClass:NSString.class]?v:@"";}
static NSString *Esc(NSString *s){return [s stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];}
@interface RWUIProbe:NSObject
+(instancetype)shared;
-(void)work:(NSString *)kind started:(double)start;
@end
@implementation RWUIProbe
+(instancetype)shared{static RWUIProbe *v;if(!v)v=[self new];return v;}
-(void)work:(NSString *)kind started:(double)start{}
@end
@interface LookupHarness:NSObject {
 RWSourceCache *_sourceCache;RWSourceWork *_sourceWork;RWRequestCoalescer *_streamRequests,*_jsonRequests;NSDictionary *_publisherSources;
 NSUInteger _homeGeneration,_availabilityWatchGeneration;BOOL _homeAvailabilityVisible,_discoveryPaused;
}
@property NSMutableDictionary *state;
@property NSMutableArray *requests,*observations,*reports;
@property NSInteger quality;
-(void)streams:(NSDictionary *)meta videoID:(NSString *)videoID foreground:(BOOL)foreground done:(RWResult)done;
-(void)reply:(NSUInteger)index result:(id)result error:(NSString *)error;
-(BOOL)idle;
@end
@implementation LookupHarness
-(instancetype)init{if((self=[super init])){_state=[@{@"activeProfile":@"main"}mutableCopy];_sourceCache=[[RWSourceCache alloc]initWithCapacity:16];_sourceWork=[RWSourceWork new];_streamRequests=[RWRequestCoalescer new];_jsonRequests=[RWRequestCoalescer new];_publisherSources=@{};_requests=[NSMutableArray new];_observations=[NSMutableArray new];_reports=[NSMutableArray new];}return self;}
-(NSDictionary *)profile{return @{};}
-(NSDictionary *)record:(NSString *)videoID{return @{};}
-(BOOL)allowed:(NSDictionary *)meta{return ![meta[@"blocked"]boolValue];}
-(NSArray *)withSourceExperience:(NSArray *)sources{return sources;}
-(void)report:(NSDictionary *)report{[_reports addObject:report];}
-(void)noteAvailability:(NSDictionary *)meta videoID:(NSString *)video observation:(NSDictionary *)observation complete:(BOOL)complete{[_observations addObject:@{@"video":video,@"complete":@(complete),@"observation":observation}];}
-(void)JSON:(NSString *)url foreground:(BOOL)foreground done:(RWResult)done{[_requests addObject:[@{@"url":url,@"foreground":@(foreground),@"done":[done copy]}mutableCopy]];}
-(void)reply:(NSUInteger)index result:(id)result error:(NSString *)error{NSMutableDictionary *request=_requests[index];RWResult done=request[@"done"];NSAssert(done,@"One reply per actual request");[request removeObjectForKey:@"done"];done(result,error);}
-(BOOL)idle{return ![_sourceWork.diagnostics[@"active"]boolValue]&&![_sourceWork.diagnostics[@"pending"]integerValue];}
#ifndef RW_STREAMS_UNDER_TEST
#define RW_STREAMS_UNDER_TEST "../RewindStreams.inc"
#endif
#include RW_STREAMS_UNDER_TEST
@end
static int checks,failures;
static NSMutableArray *failuresList;
#define CHECK(value,message) do{checks++;if(!(value)){failures++;[failuresList addObject:message];fprintf(stderr,"FAIL %s\n",[message UTF8String]);}}while(0)
static BOOL Wait(BOOL(^condition)(void),double limit){double end=NSProcessInfo.processInfo.systemUptime+limit;while(!condition()&&NSProcessInfo.processInfo.systemUptime<end)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];return condition();}
static NSDictionary *Movie(NSString *vid){return @{@"id":vid,@"name":@"Generated lookup fixture",@"type":@"movie"};}
static NSDictionary *Primary(BOOL eligible){return @{@"streams":@[@{@"infoHash":@"1111111111111111111111111111111111111111",@"name":@"720p",@"title":eligible?@"Fixture.720p.WEBRip.x264.AAC.mp4":@"Fixture.720p.HDCAM.x264.AAC.mp4",@"seeders":@100}]};}
static NSDictionary *Secondary(NSString *vid){return @{@"data":@{@"movies":@[@{@"imdb_code":vid,@"title":@"Fixture",@"torrents":@[@{@"hash":@"2222222222222222222222222222222222222222",@"quality":@"720p",@"type":@"web",@"video_codec":@"x264",@"bit_depth":@"8",@"seeds":@10,@"size_bytes":@500000000}]}]}};}
static NSUInteger Eligible(id sources){return [RWSourcePolicy analysis:sources quality:0 capabilities:RWSourcePolicy.capabilities][@"eligible"]?[[RWSourcePolicy analysis:sources quality:0 capabilities:RWSourcePolicy.capabilities][@"eligible"]count]:0;}
int main(){@autoreleasepool{
 failuresList=[NSMutableArray new];[RWSourcePolicy setLegacyEnabled:YES];NSDictionary *movie=Movie(@"tt0000001");
 // A fast usable provider delivers immediately; warm callers avoid duplicate work,
 // while the second provider still publishes its late addition once.
 {LookupHarness *h=[LookupHarness new];__block int calls=0,updates=0;id observer=[NSNotificationCenter.defaultCenter addObserverForName:@"RWSourceResultsUpdated" object:h queue:nil usingBlock:^(NSNotification *n){updates++;CHECK(NSThread.isMainThread,@"Late additions arrive on main");CHECK([n.userInfo[@"videoID"]isEqual:movie[@"id"]],@"Late result retains title identity");}];
 [h streams:movie videoID:movie[@"id"] foreground:YES done:^(id r,NSString *e){calls++;CHECK(Eligible(r)>0&&!e,@"First result is usable");}];CHECK(h.requests.count==2,@"Movie starts one request per provider");[h reply:0 result:Primary(YES) error:nil];CHECK(Wait(^BOOL{return calls==1;},2),@"Fast provider does not wait for slow provider");
 [h streams:movie videoID:movie[@"id"] foreground:YES done:^(id r,NSString *e){calls++;CHECK(Eligible(r)>0,@"Warm cache remains usable");}];CHECK(calls==2&&h.requests.count==2,@"Warm lookup does not duplicate provider requests");[h reply:1 result:Secondary(movie[@"id"]) error:nil];CHECK(Wait(^BOOL{return updates==1&&h.idle;},2),@"Late eligible provider publishes once");CHECK(calls==2,@"Initial callbacks never repeat");[NSNotificationCenter.defaultCenter removeObserver:observer];}
 // Reproduces the partial-ineligible-cache race: a second Play must join the
 // original pending providers instead of receiving an early unusable result.
 {LookupHarness *h=[LookupHarness new];__block int calls=0;__block NSUInteger good=0;RWResult receive=^(id r,NSString *e){calls++;good+=Eligible(r)>0;};[h streams:movie videoID:movie[@"id"] foreground:YES done:receive];[h reply:0 result:Primary(NO) error:nil];CHECK(Wait(^BOOL{return h.observations.count==1&&h.idle;},2),@"Ineligible first response is processed");CHECK(calls==0,@"Rejected first response alone does not finish");
 [h streams:movie videoID:movie[@"id"] foreground:YES done:receive];CHECK(calls==0,@"Second Play joins pending lookup instead of fresh rejected cache");CHECK(h.requests.count==2,@"Concurrent same-title lookup does not duplicate provider work");[h reply:1 result:Secondary(movie[@"id"]) error:nil];CHECK(Wait(^BOOL{return calls==2&&h.idle;},2),@"Both callers receive one eventual result");CHECK(good==2,@"Both callers receive a usable source");}
 // Completed negative listings must not suppress a new availability lookup.
 {LookupHarness *h=[LookupHarness new];__block int calls=0;[h streams:movie videoID:movie[@"id"] foreground:YES done:^(id r,NSString *e){calls++;CHECK(!Eligible(r),@"No eligible result stays honest");}];[h reply:0 result:Primary(NO) error:nil];[h reply:1 result:@{} error:nil];CHECK(Wait(^BOOL{return calls==1&&h.idle;},2),@"Negative lookup terminates");
 [h streams:movie videoID:movie[@"id"] foreground:YES done:^(id r,NSString *e){calls++;}];CHECK(h.requests.count==4&&calls==1,@"Negative provider listing is not a fresh positive cache hit");if(h.requests.count==4){[h reply:2 result:Primary(YES) error:nil];[h reply:3 result:@{} error:nil];CHECK(Wait(^BOOL{return calls==2&&h.idle;},2),@"Retry may discover newly available source");}}
 // Network failures are not cached; retry and empty first provider are bounded.
 {LookupHarness *h=[LookupHarness new];__block int calls=0;[h streams:movie videoID:movie[@"id"] foreground:YES done:^(id r,NSString *e){calls++;CHECK(e.length&&!Eligible(r),@"Provider outage reports an error");}];[h reply:0 result:nil error:@"Fixture unavailable"];[h reply:1 result:nil error:@"Fixture unavailable"];CHECK(Wait(^BOOL{return calls==1&&h.idle;},2),@"Outage completes once");[h streams:movie videoID:movie[@"id"] foreground:YES done:^(id r,NSString *e){calls++;CHECK(Eligible(r)>0,@"Retry after outage can recover");}];CHECK(h.requests.count==4,@"Outage retry contacts providers");[h reply:2 result:@{@"streams":@[]} error:nil];[h reply:3 result:Secondary(movie[@"id"]) error:nil];CHECK(Wait(^BOOL{return calls==2&&h.idle;},2),@"Empty primary does not suppress secondary");}
 // Context changes invalidate both worker results and delivery deadline.
 for(int mode=0;mode<3;mode++){LookupHarness *h=[LookupHarness new];__block int calls=0;[h streams:movie videoID:movie[@"id"] foreground:YES done:^(id r,NSString *e){calls++;CHECK(![r count]&&e.length,@"Changed-context request returns no foreign sources");}];if(mode==0)h.state[@"activeProfile"]=@"kids";if(mode==1)h.quality=1080;if(mode==2){[RWSourcePolicy setLegacyEnabled:NO];[RWSourcePolicy setLegacyEnabled:YES];}[h reply:0 result:Primary(YES) error:nil];[h reply:1 result:Secondary(movie[@"id"]) error:nil];CHECK(Wait(^BOOL{return calls==1&&h.idle;},2),@"Context cancellation returns once");CHECK(!h.observations.count,@"Invalid context cannot write availability");CHECK(![h cachedStreams:movie videoID:movie[@"id"]].count,@"Invalid context cannot populate cache");}
 // Cache decisions track policy inputs by index, including invalid and
 // contradictory duplicates, rather than attributing a saved source's verdict
 // to a different provider listing with the same torrent hash.
 {NSDictionary *good=[RWSourcePolicy normalize:Primary(YES)[@"streams"][0] provider:@"Torrentio"],*bad=[RWSourcePolicy normalize:Primary(NO)[@"streams"][0] provider:@"Torrentio"];NSDictionary *a=[RWSourcePolicy analysis:@[NSNull.null,good,bad,good] quality:0 capabilities:RWSourcePolicy.capabilities];CHECK(([a[@"eligible_input_indices"]isEqual:@[@1,@3]]),@"Cache indices identify each accepted input without admitting contradictory CAM listing");}
 // A change of decoder capabilities starts a new scoped lookup.
 {LookupHarness *h=[LookupHarness new];__block int calls=0;[h streams:movie videoID:movie[@"id"] foreground:YES done:^(id r,NSString *e){calls++;}];[h reply:0 result:Primary(YES) error:nil];[h reply:1 result:Secondary(movie[@"id"]) error:nil];CHECK(Wait(^BOOL{return calls==1&&h.observations.count==2&&h.idle;},2),@"Capability fixture fills an eligible cache");[RWSourcePolicy setLegacyEnabled:NO];[RWSourcePolicy setLegacyEnabled:YES];[h streams:movie videoID:movie[@"id"] foreground:YES done:^(id r,NSString *e){calls++;}];CHECK(h.requests.count==4&&calls==1,@"Changed capabilities cannot reuse a stale cached verdict");if(h.requests.count==4){[h reply:2 result:Primary(YES) error:nil];[h reply:3 result:Secondary(movie[@"id"]) error:nil];CHECK(Wait(^BOOL{return calls==2&&h.idle;},2),@"New capability lookup completes normally");}}
 // Different title chains can complete in reverse order without swapping data.
 {LookupHarness *h=[LookupHarness new];NSDictionary *b=Movie(@"tt0000002");__block int calls=0;[h streams:movie videoID:movie[@"id"] foreground:YES done:^(id r,NSString *e){calls++;CHECK([r[0][@"infoHash"]isEqual:@"1111111111111111111111111111111111111111"],@"First title receives its own source");}];[h streams:b videoID:b[@"id"] foreground:YES done:^(id r,NSString *e){calls++;CHECK([r[0][@"infoHash"]isEqual:@"3333333333333333333333333333333333333333"],@"Second title receives its own source");}];CHECK(h.requests.count==4,@"Different titles do not join one request");NSMutableDictionary *second=[Primary(YES)[@"streams"][0]mutableCopy];second[@"infoHash"]=@"3333333333333333333333333333333333333333";[h reply:2 result:@{@"streams":@[second]} error:nil];[h reply:3 result:@{} error:nil];CHECK(Wait(^BOOL{return calls==1&&h.idle;},2),@"Second title may complete first");[h reply:0 result:Primary(YES) error:nil];[h reply:1 result:@{} error:nil];CHECK(Wait(^BOOL{return calls==2&&h.idle;},2),@"First title remains independently pending");}
 // TV stays a one-provider episode-scoped lookup with no invented fallback.
 {LookupHarness *h=[LookupHarness new];NSDictionary *show=@{@"id":@"tt0000003",@"type":@"series"};__block int calls=0;[h streams:show videoID:@"tt0000003:1:1" foreground:YES done:^(id r,NSString *e){calls++;CHECK(Eligible(r)>0,@"Episode receives usable result");}];CHECK(h.requests.count==1,@"TV lookup has one configured provider");[h reply:0 result:Primary(YES) error:nil];CHECK(Wait(^BOOL{return calls==1&&h.idle;},2),@"Episode lookup completes");CHECK(![h cachedStreams:show videoID:@"tt0000003:1:2"].count,@"Adjacent episodes do not share cached file lists");}
 // Actual seven-second production delivery boundary; late providers update only
 // their own title, without a duplicate foreground completion or new request.
 {LookupHarness *h=[LookupHarness new];__block int calls=0,updates=0;double began=NSProcessInfo.processInfo.systemUptime;__block double delivered=0;id o=[NSNotificationCenter.defaultCenter addObserverForName:@"RWSourceResultsUpdated" object:h queue:nil usingBlock:^(NSNotification *n){updates++;CHECK(Eligible(n.userInfo[@"sources"])>0,@"Late result contains usable sources");}];[h streams:movie videoID:movie[@"id"] foreground:YES done:^(id r,NSString *e){calls++;delivered=NSProcessInfo.processInfo.systemUptime-began;CHECK(e.length&&![r count],@"Deadline reports waiting without invented source");}];CHECK(Wait(^BOOL{return calls==1;},8),@"Production delivery deadline remains bounded");CHECK(delivered>=6.9&&delivered<8,@"Seven-second deadline was not extended");[h reply:0 result:Primary(YES) error:nil];[h reply:1 result:Secondary(movie[@"id"]) error:nil];CHECK(Wait(^BOOL{return updates==2&&h.idle;},2),@"Both late completions publish after deadline");CHECK(calls==1&&h.requests.count==2,@"Late results do not restart provider request");[NSNotificationCenter.defaultCenter removeObserver:o];}
 NSDictionary *out=@{@"checks":@(checks),@"failures":@(failures),@"failure_messages":failuresList,@"scope":@"Exact production stream orchestration/cache/policy/work/coalescer; provider transport is a controlled response double. No network, player or iPad timing claim."};NSData *data=[NSJSONSerialization dataWithJSONObject:out options:0 error:nil];fwrite(data.bytes,1,data.length,stdout);return failures?1:0;
}}
