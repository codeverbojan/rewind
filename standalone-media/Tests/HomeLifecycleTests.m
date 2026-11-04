#import <Foundation/Foundation.h>
#import "../RWHomeDelivery.h"
#import "../RWAvailability.h"
#import "../RWSourcePolicy.h"
#import "../RWSourceCache.h"
#import "../RWSourceWork.h"
#import "../RWRequestCoalescer.h"
typedef void (^RWResult)(id,NSString *);
enum {UIApplicationStateActive,UIApplicationStateInactive};
@interface UIApplication:NSObject
@property NSInteger applicationState;
+ (instancetype)sharedApplication;
@end
@implementation UIApplication
+ (instancetype)sharedApplication {static UIApplication *a;if(!a)a=[self new];return a;}
@end
@interface RWUIProbe:NSObject
+ (instancetype)shared;
- (void)work:(NSString *)kind started:(double)started;
@end
@implementation RWUIProbe
+ (instancetype)shared {static RWUIProbe *p;if(!p)p=[self new];return p;}
- (void)work:(NSString *)kind started:(double)started {}
@end
static NSString *RWString(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static NSString *RWID(NSDictionary *m){return RWString(m[@"id"]);}
static NSString *Esc(NSString *s){return [s stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];}
@interface RWRecommendationPolicy:NSObject
+ (NSArray *)homeRefreshCandidates:(NSArray *)input profile:(NSDictionary *)profile now:(double)now;
+ (NSArray *)rank:(NSArray *)input current:(NSDictionary *)current profile:(NSDictionary *)profile world:(BOOL)world requireAvailability:(BOOL)required now:(double)now limit:(NSUInteger)limit;
@end
@implementation RWRecommendationPolicy
// Lifecycle harness stubs ranking; admission policy is tested against the real
// implementation in HomeRecommendationRecoveryTests.
+ (NSArray *)homeRefreshCandidates:(NSArray *)input profile:(NSDictionary *)profile now:(double)now {return input;}
+ (NSArray *)rank:(NSArray *)input current:(NSDictionary *)current profile:(NSDictionary *)profile world:(BOOL)world requireAvailability:(BOOL)required now:(double)now limit:(NSUInteger)limit {return [input subarrayWithRange:NSMakeRange(0,MIN(input.count,limit))];}
@end
@interface MetadataStub:NSObject
- (void)enqueue:(NSArray *)items;
@end
@implementation MetadataStub
- (void)enqueue:(NSArray *)items {}
@end
@interface HomeHarness:NSObject {
    RWSourceWork *_sourceWork;RWSourceCache *_sourceCache;RWRequestCoalescer *_streamRequests,*_jsonRequests;NSDictionary *_publisherSources;
    NSArray *_homeRefreshBatch;NSMutableSet *_homeRefreshFinished;NSDictionary *_homeRefreshBatchScope;
    NSUInteger _homeGeneration,_homeCompleted,_availabilityWatchGeneration;BOOL _homeAvailabilityBusy,_discoveryPaused,_homePublicationRequested,_homeRefreshRequested,_homeAvailabilityVisible,_checkingAvailability;
    NSString *_homeAvailabilityType;dispatch_queue_t _recommendationQueue;NSArray *_discoveryPrepared;NSDictionary *_discoveryContext;NSMutableArray *_homeRefreshAudit;NSMutableDictionary *_seriesCache,*_homeMetadataAttempts;
}
@property(nonatomic,strong) NSMutableDictionary *state;
@property(nonatomic,strong) MetadataStub *discoveryMetadata;
@property(nonatomic,strong) NSMutableArray *requests,*observations,*held;
@property(nonatomic,assign) NSUInteger mode,active,peak,refreshes;
@property(nonatomic,assign) BOOL holdBackground;
- (NSArray *)availabilityWatchTargets;
- (BOOL)watchingAvailability:(NSDictionary *)meta;
- (void)recordAvailabilityWatchCheck:(NSDictionary *)meta videoID:(NSString *)videoID;
- (BOOL)setHomeAvailabilityVisible:(BOOL)visible;
- (BOOL)setHomeAvailabilityVisible:(BOOL)visible mediaType:(NSString *)type;
- (BOOL)selectScope:(NSString *)type items:(NSArray *)items;
- (void)checkAvailability;
- (void)watch:(NSDictionary *)meta;
- (void)pauseBackground;
- (void)streams:(NSDictionary *)meta videoID:(NSString *)video foreground:(BOOL)foreground done:(RWResult)done;
- (void)startHome:(NSArray *)targets;
- (BOOL)busy;
- (RWSourceWork *)work;
- (void)selectStale:(NSArray *)prepared;
- (NSArray *)audit;
- (void)cacheShow:(NSDictionary *)show;
- (void)refreshHomeAvailability;
- (void)cancelHome;
@end
@implementation HomeHarness
- (instancetype)init {if((self=[super init])){_state=[@{@"activeProfile":@"main",@"profiles":[@{@"main":[@{@"sources":[NSMutableDictionary new],@"sourceAvailability":[NSMutableDictionary new]}mutableCopy],@"kids":[@{@"sources":[NSMutableDictionary new],@"sourceAvailability":[NSMutableDictionary new]}mutableCopy]}mutableCopy]}mutableCopy];_seriesCache=[NSMutableDictionary new];_recommendationQueue=dispatch_queue_create("org.rewind.tests.home",DISPATCH_QUEUE_SERIAL);_sourceCache=[[RWSourceCache alloc]initWithCapacity:16];_streamRequests=[RWRequestCoalescer new];_jsonRequests=[RWRequestCoalescer new];_publisherSources=@{};_requests=[NSMutableArray new];_observations=[NSMutableArray new];_held=[NSMutableArray new];_discoveryMetadata=[MetadataStub new];}return self;}
- (NSMutableDictionary *)profile{return _state[@"profiles"][_state[@"activeProfile"]];}
- (BOOL)allowed:(NSDictionary *)meta{return ![meta[@"blocked"]boolValue];}
- (BOOL)catalogReady{return YES;}
- (BOOL)watchingAvailability:(NSDictionary *)meta {return self.profile[@"availabilityWatch"][RWID(meta)]!=nil;}
- (void)watch:(NSDictionary *)meta {if(!self.profile[@"availabilityWatch"])self.profile[@"availabilityWatch"]=[NSMutableDictionary new];self.profile[@"availabilityWatch"][RWID(meta)]=@{@"meta":meta,@"checked":@0,@"initialState":@"waiting"};}
- (void)pauseBackground {if([self respondsToSelector:NSSelectorFromString(@"suspendHomeRefresh")])[self performSelector:NSSelectorFromString(@"suspendHomeRefresh")];_discoveryPaused=YES;_availabilityWatchGeneration++;_checkingAvailability=NO;_homeGeneration++;_homeAvailabilityBusy=NO;}
- (NSDictionary *)record:(NSString *)video{return @{};}
- (NSInteger)quality{return [self.profile[@"quality"]integerValue];}
- (NSDictionary *)availability:(NSDictionary *)meta videoID:(NSString *)video {return [RWAvailability presentation:meta observation:self.profile[@"sourceAvailability"][video] quality:self.quality now:NSDate.date.timeIntervalSince1970];}
- (NSArray *)withSourceExperience:(NSArray *)sources{return sources;}
- (void)save {}
- (void)saveForReason:(NSString *)reason {[self save];}
- (void)report:(NSDictionary *)value {}
- (void)refreshDiscovery {_refreshes++;}
- (void)refreshDiscoveryCandidates {}
- (NSArray *)discoveryPool{return @[];}
- (NSDictionary *)discoveryShows{return [_seriesCache copy];}
- (NSDictionary *)canonicalShow:(NSString *)identifier{return _seriesCache[identifier];}
- (NSDictionary *)cachedShow:(NSString *)identifier{return _seriesCache[identifier];}
- (NSString *)availabilityVideoID:(NSDictionary *)meta {if([meta[@"type"]isEqual:@"movie"])return RWID(meta);if([meta[@"episodeVideoID"]length])return meta[@"episodeVideoID"];NSDictionary *show=_seriesCache[RWID(meta)]?:meta;return [show[@"videos"]firstObject][@"id"];}
- (void)acceptShow:(NSDictionary *)show profile:(NSString *)profile notify:(BOOL)notify {_seriesCache[RWID(show)]=show;}
- (void)noteAvailability:(NSDictionary *)meta videoID:(NSString *)video sources:(NSArray *)sources complete:(BOOL)complete error:(NSString *)error {
    NSDictionary *observation=[RWAvailability observe:sources complete:complete error:error quality:self.quality now:NSDate.date.timeIntervalSince1970];
    [self noteAvailability:meta videoID:video observation:observation complete:complete];
}
- (void)noteAvailability:(NSDictionary *)meta videoID:(NSString *)video observation:(NSDictionary *)observation complete:(BOOL)complete {
    NSAssert(NSThread.isMainThread,@"Publish only on main");
    [_observations addObject:@{@"video":video,@"complete":@(complete),@"state":observation[@"state"]}];self.profile[@"sourceAvailability"][video]=observation;
}
- (void)JSON:(NSString *)url foreground:(BOOL)foreground done:(RWResult)done {
    BOOL primary=[url containsString:@"torrentio"],metadata=[url containsString:@"/meta/series/"];[_requests addObject:@{@"primary":@(primary),@"metadata":@(metadata),@"foreground":@(foreground)}];_active++;_peak=MAX(_peak,_active);
    void(^reply)(void)=^{
        self->_active--;NSString *video=(primary||metadata)?[[url.lastPathComponent componentsSeparatedByString:@".json"]firstObject]:[[url componentsSeparatedByString:@"query_term="][1]componentsSeparatedByString:@"&"].firstObject;
        if(self.mode==2){done(nil,@"Offline");return;}
        if(metadata){done(@{@"meta":@{@"id":video,@"type":@"series",@"videos":self.mode==3?@[]:@[@{@"id":[video stringByAppendingString:@":1:1"],@"season":@1,@"episode":@1,@"released":@"2020-01-01T00:00:00Z"}]}},nil);return;}
        if(primary){NSDictionary *source=@{@"infoHash":@"1111111111111111111111111111111111111111",@"name":@"720p",@"title":@"Film.2026.720p.WEBRip.x264.AAC.mp4",@"seeders":@100};done(@{@"streams":self.mode==1?@[]:@[source]},nil);}
        else done(@{@"data":@{@"movies":@[@{@"imdb_code":video,@"title":@"Film",@"torrents":@[@{@"hash":@"2222222222222222222222222222222222222222",@"quality":@"720p",@"type":@"web",@"video_codec":@"x264",@"bit_depth":@"8",@"seeds":@100,@"size_bytes":@500000000}]}]}},nil);
    };
    if(!foreground&&self.holdBackground)[_held addObject:[reply copy]];
    else dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.01*NSEC_PER_SEC)),dispatch_get_main_queue(),reply);
}
#include "../RewindStreams.inc"
#include "../RewindAvailabilityWatch.inc"
#include "../RewindHomeRefresh.inc"
#include "../RewindHomeSelection.inc"
- (void)selectStale:(NSArray *)prepared {[self setHomeAvailabilityVisible:YES];_discoveryPrepared=prepared;[self refreshHomeAvailability];}
- (BOOL)selectScope:(NSString *)type items:(NSArray *)items {
    // Compatibility branch makes the same scenario runnable against the old
    // boolean-only implementation, so the before-fix failure is meaningful.
    BOOL changed=[self respondsToSelector:@selector(setHomeAvailabilityVisible:mediaType:)]?[self setHomeAvailabilityVisible:YES mediaType:type]:[self setHomeAvailabilityVisible:YES];_discoveryPrepared=items;if(changed)[self refreshHomeAvailability];return changed;
}
- (NSArray *)audit {return [_homeRefreshAudit copy];}
- (void)cacheShow:(NSDictionary *)show {_seriesCache[show[@"id"]]=show;}
- (void)startHome:(NSArray *)targets {_homeGeneration++;_homeAvailabilityBusy=YES;[self beginHomeRefreshTargets:targets profile:self.state[@"activeProfile"] generation:_homeGeneration];}
- (BOOL)busy{return _homeAvailabilityBusy;}
- (RWSourceWork *)work {if(!_sourceWork)_sourceWork=[RWSourceWork new];return _sourceWork;}
- (void)cancelHome {_homeGeneration++;_homeAvailabilityBusy=NO;}
- (void)resumeBackground {_discoveryPaused=NO;if(_homeRefreshRequested)[self refreshHomeAvailability];}
- (void)replacePrepared:(NSArray *)items {_discoveryPrepared=items;}
@end
static BOOL Wait(BOOL(^done)(void)){NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];while(!done()&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];return done();}
int main(){@autoreleasepool{__block int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    [RWSourcePolicy setLegacyEnabled:YES];NSDictionary *movie=@{@"id":@"tt0000001",@"type":@"movie",@"name":@"Film"};
    HomeHarness *primary=[HomeHarness new];__block NSUInteger calls=0;__block NSArray *found=nil;[primary streams:movie videoID:RWID(movie) foreground:NO done:^(id result,NSString *error){calls++;found=result;}];CHECK(Wait(^BOOL{return calls==1;}));CHECK(found.count==1);CHECK(primary.requests.count==1);CHECK([primary.observations.lastObject[@"complete"]boolValue]);
    HomeHarness *fallback=[HomeHarness new];fallback.mode=1;calls=0;[fallback streams:movie videoID:RWID(movie) foreground:NO done:^(id result,NSString *error){calls++;found=result;}];CHECK(Wait(^BOOL{return calls==1;}));CHECK(found.count==1);CHECK(fallback.requests.count==2);CHECK([fallback.observations[0][@"state"]isEqual:@"unknown"]);CHECK([fallback.observations.lastObject[@"state"]isEqual:@"candidates"]);
    HomeHarness *offline=[HomeHarness new];offline.mode=2;calls=0;[offline streams:movie videoID:RWID(movie) foreground:NO done:^(id result,NSString *error){calls++;CHECK(error.length>0);}];CHECK(Wait(^BOOL{return calls==1;}));CHECK([offline.observations.lastObject[@"state"]isEqual:@"unknown"]);
    HomeHarness *foreground=[HomeHarness new];foreground.holdBackground=YES;__block BOOL bgDone=NO,fgDone=NO;[foreground streams:movie videoID:RWID(movie) foreground:NO done:^(id result,NSString *error){bgDone=YES;}];[foreground streams:movie videoID:RWID(movie) foreground:YES done:^(id result,NSString *error){fgDone=YES;}];CHECK(Wait(^BOOL{return fgDone;}));CHECK(!bgDone);CHECK(foreground.requests.count==3);for(void(^reply)(void) in [foreground.held copy])reply();[foreground.held removeAllObjects];CHECK(Wait(^BOOL{return bgDone;}));
    NSMutableArray *targets=[NSMutableArray new];for(int i=0;i<24;i++)[targets addObject:@{@"id":[NSString stringWithFormat:@"tt%07d",100+i],@"type":@"movie",@"name":@"Film"}];
    HomeHarness *batch=[HomeHarness new];[batch startHome:targets];CHECK(Wait(^BOOL{return !batch.busy;}));CHECK(batch.requests.count==4);CHECK(batch.peak==2);CHECK(batch.profile[@"homeDiscoveryRefresh"]!=nil);CHECK(batch.refreshes==2);CHECK([batch.profile[@"sourceAvailability"]count]==4);CHECK([batch.audit.lastObject[@"targets"]intValue]==4);
    HomeHarness *cancelled=[HomeHarness new];cancelled.holdBackground=YES;[cancelled startHome:targets];CHECK(cancelled.requests.count==2);[cancelled cancelHome];cancelled.state[@"activeProfile"]=@"kids";for(void(^reply)(void) in [cancelled.held copy])reply();[cancelled.held removeAllObjects];CHECK(!cancelled.busy);CHECK(cancelled.requests.count==2);CHECK(!cancelled.observations.count);CHECK(!cancelled.profile[@"homeDiscoveryRefresh"]);
    HomeHarness *odd=[HomeHarness new];[odd startHome:[targets subarrayWithRange:NSMakeRange(0,3)]];CHECK(Wait(^BOOL{return !odd.busy;}));CHECK(odd.requests.count==3);CHECK([odd.profile[@"sourceAvailability"]count]==3);
    HomeHarness *empty=[HomeHarness new];[empty startHome:@[]];CHECK(!empty.busy);CHECK(!empty.requests.count);
    // Actual selector + executor: never refresh the stale ranked snapshot in
    // this harness. Fresh observations must independently advance each visit.
    HomeHarness *stale=[HomeHarness new];[stale selectStale:targets];CHECK(Wait(^BOOL{return !stale.busy;}));CHECK(stale.requests.count==4);
    NSSet *first=[NSSet setWithArray:stale.audit.lastObject[@"target_ids"]];[stale selectStale:targets];CHECK(Wait(^BOOL{return !stale.busy;}));CHECK(stale.requests.count==8);
    NSMutableSet *second=[NSMutableSet setWithArray:stale.audit.lastObject[@"target_ids"]];[second intersectSet:first];CHECK(!second.count);CHECK([stale.profile[@"sourceAvailability"]count]==8);
    // Cooldowns belong to profile + quality + exact video, never another scope.
    stale.state[@"activeProfile"]=@"kids";[stale selectStale:targets];CHECK(Wait(^BOOL{return !stale.busy;}));CHECK(stale.requests.count==12);CHECK([stale.profile[@"sourceAvailability"]count]==4);
    stale.profile[@"quality"]=@720;[stale selectStale:targets];CHECK(Wait(^BOOL{return !stale.busy;}));CHECK(stale.requests.count==16);
    // Switching actual destinations must refresh the requested type even
    // though all three are Home controllers. Same-scope layout is not a visit.
    // A modal cancels unfinished Home requests. Returning must finish the same
    // four identities, even if a newer ranking pool is ready in the meantime.
    HomeHarness *interrupted=[HomeHarness new];interrupted.holdBackground=YES;[interrupted selectStale:targets];
    CHECK(Wait(^BOOL{return interrupted.requests.count==2;}));NSSet *originalBatch=[NSSet setWithArray:interrupted.audit.lastObject[@"target_ids"]];
    if(interrupted.held.count){void(^firstReply)(void)=interrupted.held.firstObject;[interrupted.held removeObjectAtIndex:0];firstReply();}
    CHECK(Wait(^BOOL{return interrupted.observations.count==1&&interrupted.held.count==2;}));
    [interrupted pauseBackground];for(void(^reply)(void) in [interrupted.held copy])reply();[interrupted.held removeAllObjects];CHECK(Wait(^BOOL{return interrupted.active==0;}));CHECK(interrupted.observations.count==1);
    [interrupted replacePrepared:[targets subarrayWithRange:NSMakeRange(8,8)]];interrupted.holdBackground=NO;[interrupted resumeBackground];
    CHECK(Wait(^BOOL{return !interrupted.busy&&interrupted.observations.count==4;}));
    CHECK([[NSSet setWithArray:[interrupted.observations valueForKey:@"video"]]isEqual:originalBatch]);
    CHECK([interrupted.audit.lastObject[@"completed"]unsignedIntegerValue]==[interrupted.audit.lastObject[@"targets"]unsignedIntegerValue]);
    CHECK([interrupted.audit.lastObject[@"targets"]unsignedIntegerValue]==3);CHECK(interrupted.peak<=2);
    NSUInteger afterResume=interrupted.requests.count;[interrupted pauseBackground];[interrupted resumeBackground];CHECK(interrupted.requests.count==afterResume&&!interrupted.busy);
    // A pause before worker selection returns must also leave resumable intent.
    HomeHarness *beforeSelection=[HomeHarness new];[beforeSelection selectStale:targets];[beforeSelection pauseBackground];[beforeSelection resumeBackground];
    CHECK(Wait(^BOOL{return !beforeSelection.busy&&beforeSelection.observations.count==4;}));CHECK(beforeSelection.requests.count==4);
    // The retained batch belongs to its exact profile and quality. A new scope
    // may refresh its own candidates but may never publish the suspended ones.
    for(NSUInteger scopeChange=0;scopeChange<2;scopeChange++){
        HomeHarness *rescope=[HomeHarness new];rescope.holdBackground=YES;[rescope selectStale:targets];CHECK(Wait(^BOOL{return rescope.requests.count==2;}));
        [rescope pauseBackground];for(void(^reply)(void) in [rescope.held copy])reply();[rescope.held removeAllObjects];CHECK(Wait(^BOOL{return rescope.active==0;}));
        if(scopeChange==0)rescope.state[@"activeProfile"]=@"kids";else rescope.profile[@"quality"]=@720;
        NSArray *replacement=[targets subarrayWithRange:NSMakeRange(12,8)];[rescope replacePrepared:replacement];rescope.holdBackground=NO;[rescope resumeBackground];
        CHECK(Wait(^BOOL{return !rescope.busy&&rescope.observations.count==4;}));NSSet *newIDs=[NSSet setWithArray:[replacement valueForKey:@"id"]];for(NSDictionary *observation in rescope.observations)CHECK([newIDs containsObject:observation[@"video"]]);
    }
    NSMutableArray *mixed=[NSMutableArray arrayWithArray:[targets subarrayWithRange:NSMakeRange(0,8)]];
    for(int i=0;i<8;i++)[mixed addObject:@{@"id":[NSString stringWithFormat:@"tt%07d",200+i],@"type":@"series",@"name":@"Series",@"episodeVideoID":[NSString stringWithFormat:@"tt%07d:1:1",200+i]}];
    HomeHarness *typed=[HomeHarness new];[typed watch:mixed[0]];[typed watch:mixed[8]];
    CHECK([typed selectScope:nil items:mixed]);CHECK(Wait(^BOOL{return !typed.busy;}));NSUInteger n=typed.requests.count;
    CHECK(![typed selectScope:nil items:mixed]);CHECK(typed.requests.count==n);
    CHECK([typed selectScope:@"series" items:mixed]);CHECK(Wait(^BOOL{return !typed.busy;}));CHECK([typed.audit.lastObject[@"media_type"]isEqual:@"series"]);CHECK([typed.audit.lastObject[@"targets"]intValue]==4);
    for(NSString *key in typed.audit.lastObject[@"target_ids"])CHECK([key integerValue]==0&&[key compare:@"tt0000200"]!=NSOrderedAscending);
    CHECK(typed.requests.count>n);n=typed.requests.count;CHECK(![typed selectScope:@"series" items:mixed]);CHECK(typed.requests.count==n);
    CHECK([typed selectScope:@"movie" items:mixed]);CHECK(Wait(^BOOL{return !typed.busy;}));CHECK([typed.audit.lastObject[@"media_type"]isEqual:@"movie"]);
    for(NSString *key in typed.audit.lastObject[@"target_ids"])CHECK([key compare:@"tt0000200"]==NSOrderedAscending);
    CHECK(typed.peak<=2);CHECK([typed selectScope:nil items:mixed]);CHECK(Wait(^BOOL{return !typed.busy;}));CHECK([typed.audit.lastObject[@"media_type"]isEqual:@"all"]);
    // An old source chain is invalid once the destination changes, just as
    // when navigating away. It cannot publish into the newly selected view.
    HomeHarness *typeChanged=[HomeHarness new];typeChanged.holdBackground=YES;CHECK([typeChanged selectScope:@"movie" items:mixed]);CHECK(Wait(^BOOL{return typeChanged.requests.count==2;}));
    BOOL scoped=[typeChanged respondsToSelector:@selector(setHomeAvailabilityVisible:mediaType:)];CHECK(scoped);
    if(scoped)[typeChanged setHomeAvailabilityVisible:YES mediaType:@"series"];else [typeChanged setHomeAvailabilityVisible:YES];
    for(void(^reply)(void) in [typeChanged.held copy])reply();[typeChanged.held removeAllObjects];CHECK(Wait(^BOOL{return typeChanged.active==0;}));CHECK(!typeChanged.observations.count&&!typeChanged.busy);
    // Cache reuse returns candidates without resetting their evidence time.
    calls=0;NSUInteger observations=primary.observations.count,requests=primary.requests.count;NSDictionary *original=[primary.profile[@"sourceAvailability"][RWID(movie)]copy];
    [primary streams:movie videoID:RWID(movie) foreground:YES done:^(id result,NSString *error){calls++;CHECK([result count]>0);}];CHECK(calls==1&&primary.requests.count==requests&&primary.observations.count==observations);CHECK([original isEqual:primary.profile[@"sourceAvailability"][RWID(movie)]]);
    // A changed quality does not reuse a differently evaluated cache entry.
    primary.profile[@"quality"]=@720;calls=0;[primary streams:movie videoID:RWID(movie) foreground:YES done:^(id result,NSString *error){calls++;}];CHECK(Wait(^BOOL{return calls==1&&primary.active==0;}));CHECK(primary.requests.count==requests+2);
    // A quality change while an old request is held cannot publish or start a
    // new fallback lookup in the wrong quality scope.
    HomeHarness *changed=[HomeHarness new];changed.mode=1;changed.holdBackground=YES;calls=0;[changed streams:movie videoID:RWID(movie) foreground:NO done:^(id result,NSString *error){calls++;CHECK(error.length>0&&![(NSArray *)result count]);}];changed.profile[@"quality"]=@720;for(void(^reply)(void) in [changed.held copy])reply();[changed.held removeAllObjects];CHECK(calls==1&&!changed.observations.count&&changed.requests.count==1);
    // A title that became fresh after worker selection does not start a lookup.
    NSUInteger prior=stale.requests.count;[stale startHome:[targets subarrayWithRange:NSMakeRange(0,4)]];CHECK(Wait(^BOOL{return !stale.busy;}));CHECK(stale.requests.count==prior);
    // A newly cached series needs no completed full-ranking job to acquire its
    // exact episode cooldown on the next Home visit.
    NSDictionary *showTitle=@{@"id":@"tt99999",@"type":@"series",@"name":@"Series"};HomeHarness *series=[HomeHarness new];[series selectStale:@[showTitle]];CHECK(Wait(^BOOL{return !series.busy;}));CHECK(series.requests.count==2&&series.observations.count==1);[series selectStale:@[showTitle]];CHECK(Wait(^BOOL{return !series.busy;}));CHECK(series.requests.count==2&&[series.audit.lastObject[@"targets"]intValue]==0);
    // Missing episode metadata is a bounded retry, not a fabricated observation.
    HomeHarness *missing=[HomeHarness new];missing.mode=3;[missing selectStale:@[showTitle]];CHECK(Wait(^BOOL{return !missing.busy;}));CHECK(missing.requests.count==1&&!missing.observations.count);[missing selectStale:@[showTitle]];CHECK(Wait(^BOOL{return !missing.busy;}));CHECK(missing.requests.count==1&&!missing.observations.count);
    CHECK(Wait(^BOOL{return foreground.active==0;}));
    // Followed titles occupy two of Home's four slots, including overlap with
    // the recommendation pool. Lifecycle callbacks cannot open a fifth slot.
    HomeHarness *watched=[HomeHarness new];[watched watch:targets[0]];[watched watch:targets[1]];[watched selectStale:targets];
    for(int i=0;i<10;i++)[watched checkAvailability];CHECK(Wait(^BOOL{return !watched.busy;}));CHECK(watched.requests.count==4);CHECK([watched.audit.lastObject[@"watch_ids"]count]==2);[watched checkAvailability];CHECK(watched.requests.count==4);
    CHECK([watched.profile[@"availabilityWatch"][RWID(targets[0])][@"checked"]doubleValue]>0);CHECK(![watched availabilityWatchTargets].count);
    // Outside Home, automatic checks retain their two-title bound and use only
    // background requests, including series metadata.
    HomeHarness *outside=[HomeHarness new];[outside watch:showTitle];[outside watch:movie];[outside checkAvailability];[outside checkAvailability];CHECK(Wait(^BOOL{return outside.active==0&&[outside.profile[@"availabilityWatch"][RWID(movie)][@"checked"]doubleValue]>0;}));CHECK(outside.requests.count==3);BOOL allBackground=YES;for(NSDictionary *request in outside.requests)if([request[@"foreground"]boolValue])allBackground=NO;CHECK(allBackground);[outside checkAvailability];CHECK(outside.requests.count==3);
    // Entering Home while a watch's metadata is pending invalidates the old
    // chain before it can start a source request or populate the show cache.
    HomeHarness *handoff=[HomeHarness new];handoff.holdBackground=YES;[handoff watch:showTitle];[handoff checkAvailability];CHECK(handoff.requests.count==1);[handoff setHomeAvailabilityVisible:YES];for(void(^reply)(void) in [handoff.held copy])reply();[handoff.held removeAllObjects];CHECK(handoff.requests.count==1&&!handoff.observations.count&&![handoff cachedShow:RWID(showTitle)]);CHECK([handoff.profile[@"availabilityWatch"][RWID(showTitle)][@"checked"]doubleValue]==0);
    handoff.holdBackground=NO;[handoff selectStale:targets];CHECK(Wait(^BOOL{return !handoff.busy;}));CHECK([handoff.audit.lastObject[@"targets"]intValue]==4&&[handoff.audit.lastObject[@"watch_ids"]count]==1);
    // Playback/background pause prevents a held watch from starting more work.
    HomeHarness *paused=[HomeHarness new];paused.holdBackground=YES;[paused watch:showTitle];[paused checkAvailability];[paused pauseBackground];for(void(^reply)(void) in [paused.held copy])reply();[paused.held removeAllObjects];[paused checkAvailability];CHECK(paused.requests.count==1&&!paused.observations.count);
    // A source response that arrives after Home takes over must not launch
    // its old watch's fallback, nor join the new Home request under an old key.
    HomeHarness *oldSource=[HomeHarness new];oldSource.mode=1;oldSource.holdBackground=YES;[oldSource watch:movie];[oldSource checkAvailability];CHECK(oldSource.requests.count==1);[oldSource setHomeAvailabilityVisible:YES];for(void(^reply)(void) in [oldSource.held copy])reply();[oldSource.held removeAllObjects];CHECK(oldSource.requests.count==1&&!oldSource.observations.count);oldSource.mode=0;oldSource.holdBackground=NO;[oldSource selectStale:targets];CHECK(Wait(^BOOL{return !oldSource.busy;}));CHECK(oldSource.requests.count==5&&[oldSource.audit.lastObject[@"targets"]intValue]==4);
    // A watch may not cross profile or quality scopes, even if old metadata
    // arrives after the change. Returning to the original scope can retry.
    HomeHarness *watchScope=[HomeHarness new];watchScope.holdBackground=YES;[watchScope watch:showTitle];[watchScope checkAvailability];watchScope.state[@"activeProfile"]=@"kids";for(void(^reply)(void) in [watchScope.held copy])reply();[watchScope.held removeAllObjects];CHECK(watchScope.requests.count==1&&![watchScope cachedShow:RWID(showTitle)]&&!watchScope.observations.count);
    HomeHarness *watchQuality=[HomeHarness new];watchQuality.holdBackground=YES;[watchQuality watch:showTitle];[watchQuality checkAvailability];watchQuality.profile[@"quality"]=@720;for(void(^reply)(void) in [watchQuality.held copy])reply();[watchQuality.held removeAllObjects];CHECK(watchQuality.requests.count==1&&!watchQuality.observations.count);
    // Hidden/disallowed watched items cannot steal slots or bypass Kids gates.
    HomeHarness *gated=[HomeHarness new];[gated watch:movie];gated.profile[@"hidden"]=@[RWID(movie)];[gated watch:@{@"id":@"tt999",@"type":@"movie",@"blocked":@YES}];CHECK(![gated availabilityWatchTargets].count);
    // Future watches remain honest and are scheduled again later without a
    // provider lookup or an invented source observation.
    HomeHarness *future=[HomeHarness new];NSDictionary *upcoming=@{@"id":@"tt12341234",@"type":@"movie",@"released":@"2099-01-01T00:00:00Z"};[future watch:upcoming];[future selectStale:@[upcoming]];CHECK(Wait(^BOOL{return !future.busy;}));CHECK(!future.requests.count&&!future.observations.count);CHECK([future.profile[@"availabilityWatch"][RWID(upcoming)][@"checked"]doubleValue]>0);
    // Hold the worker, deliver JSON, then invalidate the context. Queued source
    // work must neither observe availability, cache candidates, nor start fallback.
    for(NSUInteger change=0;change<4;change++){
        HomeHarness *queued=[HomeHarness new];queued.mode=1;queued.holdBackground=YES;
        dispatch_semaphore_t gate=dispatch_semaphore_create(0);__block BOOL blockerDone=NO,ended=NO;
        [queued.work submitForeground:NO valid:^BOOL{return YES;} task:^id{dispatch_semaphore_wait(gate,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC));return @YES;} done:^(id value,NSString *error){blockerDone=YES;}];
        [queued streams:movie videoID:RWID(movie) foreground:NO done:^(id result,NSString *error){ended=YES;CHECK(error.length&&![(NSArray *)result count]);}];
        for(void(^reply)(void) in [queued.held copy])reply();[queued.held removeAllObjects];
        CHECK([queued.work.diagnostics[@"pending"]unsignedIntegerValue]==1);
        if(change==0)queued.state[@"activeProfile"]=@"kids";
        if(change==1)queued.profile[@"quality"]=@720;
        if(change==2)[queued pauseBackground];
        if(change==3){[RWSourcePolicy setLegacyEnabled:NO];[RWSourcePolicy setLegacyEnabled:YES];}
        dispatch_semaphore_signal(gate);CHECK(Wait(^BOOL{return ended&&blockerDone;}));
        CHECK(!queued.observations.count&&queued.requests.count==1);
        CHECK(![queued cachedStreams:movie videoID:RWID(movie)].count);
        CHECK([queued.work.diagnostics[@"skipped"]unsignedIntegerValue]==1);
    }
    // Both foreground providers may complete at different times. Deliver first
    // usable sources once, publish late additions once, and keep callbacks on main.
    HomeHarness *late=[HomeHarness new];__block NSUInteger firstCalls=0,updates=0;
    id observer=[NSNotificationCenter.defaultCenter addObserverForName:@"RWSourceResultsUpdated" object:late queue:nil usingBlock:^(NSNotification *note){CHECK(NSThread.isMainThread);updates++;}];
    [late streams:movie videoID:RWID(movie) foreground:YES done:^(id result,NSString *error){CHECK(NSThread.isMainThread&&[(NSArray *)result count]>0);firstCalls++;}];
    CHECK(Wait(^BOOL{return firstCalls==1&&updates==1;}));CHECK(late.observations.count==2);
    CHECK([late.observations.lastObject[@"complete"]boolValue]);
    [NSNotificationCenter.defaultCenter removeObserver:observer];
    // Expired positive observations outside the ordinary top-40 still get
    // two slots. Exercise the production selection and execution includes.
    HomeHarness *recovery=[HomeHarness new];NSMutableArray *recoveryTitles=[NSMutableArray new];
    for(int i=0;i<64;i++){NSString *key=[NSString stringWithFormat:@"tt%07d",8100000+i];[recoveryTitles addObject:@{@"id":key,@"type":@"movie",@"name":@"Recovery fixture",@"releaseInfo":@"2020"}];if(i>=62)recovery.profile[@"sourceAvailability"][key]=@{@"state":@"candidates",@"quality":@0,@"policy":@34,@"checked":@(NSDate.date.timeIntervalSince1970-90000)};}
    [recovery selectStale:recoveryTitles];CHECK(Wait(^BOOL{return recovery.observations.count==4&&!recovery.busy;}));
    CHECK([[recovery.audit.lastObject[@"target_ids"]subarrayWithRange:NSMakeRange(0,2)]isEqual:@[@"tt8100062",@"tt8100063"]]);
    CHECK([recovery.audit.lastObject[@"recovery_ids"]count]==2&&[recovery.audit.lastObject[@"targets"]integerValue]==4);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
