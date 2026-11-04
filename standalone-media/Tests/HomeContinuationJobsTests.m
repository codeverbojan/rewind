#import <Foundation/Foundation.h>
#import "../RWHomeRailPolicy.h"
#import "../RWHomeCategoryPolicy.h"
#import "../RWHomePreparation.h"
#import "../RWHomeDelivery.h"
#import "../RWRecommendationPolicy.h"
#import "../RWDiscoveryMetadataPolicy.h"
#import "../RWDiscoverySnapshot.h"
#import "../RWAvailability.h"
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSString *RWString(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static NSString *RWID(NSDictionary *m){return RWString(m[@"id"]);}
static NSString *Esc(NSString *s){return s;}
static void Wait(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:5];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];CHECK(ready());}
@interface RailMetadata:NSObject
@property NSUInteger enqueued;
@property BOOL busy;
@property NSSet *pendingIDs;
@property NSDictionary *records;
@property(copy) void(^onPriority)(NSArray *);
@property(copy) void(^worldHandler)(NSDictionary *,NSString *,void(^)(NSArray *,NSDictionary *,NSString *));
- (void)worldPage:(NSDictionary *)cursor owner:(NSString *)owner done:(void(^)(NSArray *,NSDictionary *,NSString *))done;
- (void)enqueue:(NSArray *)items;
- (void)prioritizeTitles:(NSArray *)items;
- (void)resolve:(NSArray *)items;
- (void)resolve:(NSArray *)items interactive:(BOOL)interactive;
- (NSDictionary *)record:(NSString *)key;
- (NSDictionary *)rating:(NSString *)key;
- (NSDictionary *)titleSnapshot;
- (BOOL)isResolvingItems:(NSArray *)items;
@end
@implementation RailMetadata
- (void)worldPage:(NSDictionary *)cursor owner:(NSString *)owner done:(void(^)(NSArray *,NSDictionary *,NSString *))done{CHECK(self.worldHandler!=nil);if(self.worldHandler)self.worldHandler(cursor,owner,done);else done(@[],cursor,@"Unexpected World request");}
- (NSDictionary *)record:(NSString *)key{return self.records[key];}
- (NSDictionary *)rating:(NSString *)key{return nil;}
- (NSDictionary *)titleSnapshot{return self.records?:@{};}
- (BOOL)isResolvingItems:(NSArray *)items{for(NSDictionary *m in items)if([self.pendingIDs containsObject:m[@"id"]])return YES;return NO;}
- (void)enqueue:(NSArray *)items{self.enqueued+=items.count;}
- (void)prioritizeTitles:(NSArray *)items{CHECK(items.count<=4);self.enqueued+=items.count;if(self.onPriority)self.onPriority(items);}
- (void)resolve:(NSArray *)items{self.enqueued+=items.count;}
- (void)resolve:(NSArray *)items interactive:(BOOL)interactive{CHECK(interactive);self.enqueued+=items.count;}
@end
@interface RailHarness:NSObject {
    dispatch_queue_t _recommendationQueue;NSMutableDictionary *_discoveryRatings,*_homeMetadataAttempts;BOOL _homeAvailabilityBusy;NSMutableArray *_homeRailRejections,*_homeRailEvents;
}
@property NSMutableDictionary *state,*profile,*shows;
@property NSDictionary *discoveryHome;
@property NSArray *pool,*providerItems,*providerPages,*providerErrors;
@property RailMetadata *discoveryMetadata,*ratings;
@property NSMutableArray *requests,*checks;
@property NSString *providerError;
@property BOOL hold,holdSources,dropEnriched;
@property NSMutableArray *heldSources;
@property NSUInteger sourceActive,sourcePeak;
@property NSUInteger metadataRequests;
@property(copy) void(^held)(id,NSString *);
- (NSDictionary *)discoveryInputSnapshot;
- (BOOL)discoveryJobMatches:(NSDictionary *)snapshot profile:(NSString *)profile;
- (BOOL)restricted;
- (NSInteger)quality;
- (BOOL)allowed:(NSDictionary *)meta;
- (NSArray *)discoveryPool;
- (void)report:(NSDictionary *)data;
- (NSDictionary *)canonicalShow:(NSString *)key;
- (NSString *)availabilityVideoID:(NSDictionary *)m;
- (NSDictionary *)availability:(NSDictionary *)meta videoID:(NSString *)video;
- (void)streams:(NSDictionary *)meta videoID:(NSString *)video foreground:(BOOL)fg done:(void(^)(id,NSString *))done;
- (void)JSON:(NSString *)url foreground:(BOOL)fg done:(void(^)(id,NSString *))done;
- (void)acceptShow:(NSDictionary *)m profile:(NSString *)profile notify:(BOOL)notify;
- (void)acceptDiscoveryCandidates:(NSArray *)items;
- (void)enrichDiscoveryItems:(NSArray *)items done:(void(^)(NSArray *))done;
- (void)browse:(NSString *)type sort:(NSString *)sort genre:(NSString *)genre year:(NSInteger)year skip:(NSUInteger)skip foreground:(BOOL)fg done:(void(^)(id,NSString *))done;
@end
@implementation RailHarness
- (instancetype)init{if((self=[super init])){_recommendationQueue=dispatch_queue_create("home-rail-test",DISPATCH_QUEUE_SERIAL);_discoveryRatings=[NSMutableDictionary new];_homeMetadataAttempts=[NSMutableDictionary new];self.profile=[@{@"maxAge":@(-1),@"hidden":@[],@"history":@{},@"liked":@[],@"saved":@[],@"sourceAvailability":[NSMutableDictionary new],@"discoveryPreferences":@{}}mutableCopy];self.state=[@{@"activeProfile":@"regular"}mutableCopy];self.shows=[NSMutableDictionary new];self.discoveryMetadata=[RailMetadata new];self.ratings=[RailMetadata new];self.pool=@[];self.providerItems=@[];self.requests=[NSMutableArray new];self.checks=[NSMutableArray new];self.heldSources=[NSMutableArray new];}return self;}
- (NSDictionary *)discoveryInputSnapshot {return @{@"profile":[NSJSONSerialization JSONObjectWithData:[NSJSONSerialization dataWithJSONObject:self.profile options:0 error:nil] options:0 error:nil],@"quality":@0,@"groups":@[self.pool],@"family":@[],@"shows":[self.shows copy],@"metadata":self.discoveryMetadata.records?:@{},@"ageRatings":@{},@"offline":@{},@"offlineAt":@0};}
- (BOOL)discoveryJobMatches:(NSDictionary *)snapshot profile:(NSString *)profile {return [profile isEqual:self.state[@"activeProfile"]]&&[RWDiscoverySnapshot matches:snapshot profile:self.profile quality:0];}
- (BOOL)restricted{return [self.profile[@"maxAge"]integerValue]>=0;}
- (NSInteger)quality{return 0;}
- (BOOL)allowed:(NSDictionary *)m{return !self.restricted;}
- (NSArray *)discoveryPool{return self.pool;}
- (void)report:(NSDictionary *)data{if(data[@"home_rail_check"])CHECK([data[@"home_rail_check"][@"targets"]integerValue]<=4);}
- (NSDictionary *)canonicalShow:(NSString *)key{return self.shows[key];}
- (NSString *)availabilityVideoID:(NSDictionary *)m{return [m[@"type"]isEqual:@"movie"]?RWID(m):[self.shows[RWID(m)][@"videos"]firstObject][@"id"]?:@"";}
- (NSDictionary *)availability:(NSDictionary *)meta videoID:(NSString *)video{return [RWAvailability presentation:meta observation:self.profile[@"sourceAvailability"][video] quality:0 now:NSDate.date.timeIntervalSince1970];}
- (void)streams:(NSDictionary *)meta videoID:(NSString *)video foreground:(BOOL)fg done:(void(^)(id,NSString *))done{CHECK(!fg);[self.checks addObject:video];void(^finish)(void)=^{self.profile[@"sourceAvailability"][video]=[RWAvailability observeAnalysis:@{@"compatible":@1,@"listings":@1} complete:YES error:nil quality:0 now:NSDate.date.timeIntervalSince1970];done(@[],nil);};if(self.holdSources){self.sourceActive++;self.sourcePeak=MAX(self.sourcePeak,self.sourceActive);[self.heldSources addObject:[^{self.sourceActive--;finish();}copy]];}else finish();}
- (void)JSON:(NSString *)url foreground:(BOOL)fg done:(void(^)(id,NSString *))done{CHECK(!fg);self.metadataRequests++;done(nil,@"Test unavailable");}
- (void)acceptShow:(NSDictionary *)m profile:(NSString *)profile notify:(BOOL)notify{self.shows[RWID(m)]=m;}
- (void)acceptDiscoveryCandidates:(NSArray *)items{self.pool=[self.pool arrayByAddingObjectsFromArray:items];}
- (void)enrichDiscoveryItems:(NSArray *)items done:(void(^)(NSArray *))done{done(self.dropEnriched?@[]:items);}
- (void)browse:(NSString *)type sort:(NSString *)sort genre:(NSString *)genre year:(NSInteger)year skip:(NSUInteger)skip foreground:(BOOL)fg done:(void(^)(id,NSString *))done{CHECK(!fg);[self.requests addObject:@{@"type":type,@"sort":sort,@"skip":@(skip),@"genre":genre?:@""}];if(self.hold)self.held=done;else {id error=self.providerErrors.count?self.providerErrors[MIN(self.requests.count-1,self.providerErrors.count-1)]:self.providerError;done(self.providerPages.count?self.providerPages[MIN(self.requests.count-1,self.providerPages.count-1)]:self.providerItems,[error isKindOfClass:NSString.class]?error:nil);}}
#include "../RewindHomeContinuation.inc"
@end
static NSDictionary *Title(int i){return @{@"id":[NSString stringWithFormat:@"tt%07d",i],@"name":@"Test film",@"type":@"movie",@"releaseInfo":@"2000",@"genres":@[@"Drama"],@"imdbRating":@8.5,@"imdbVotes":@50000,@"discovery":@{@"primaryLanguage":@"en",@"languageSource":@"https://example.com/fixture",@"industry":@"other"}};}
static NSArray *Titles(int first,int count){NSMutableArray *out=[NSMutableArray new];for(int i=first;i<first+count;i++)[out addObject:Title(i)];return out;}
static NSDictionary *Request(RailHarness *s,NSDictionary *cursor,NSSet *excluded,BOOL(^current)(void)){__block NSDictionary *result=nil;[s homeRailPage:@{@"id":@"films",@"mediaType":@"movie",@"recipe":@"for-you"} cursor:cursor excluding:excluded current:current done:^(NSArray *items,NSDictionary *next,BOOL more,NSString *error){result=@{@"items":items?:@[],@"cursor":next?:@{},@"more":@(more),@"error":error?:@""};}];Wait(^BOOL{return result!=nil;});return result;}
int main(){@autoreleasepool{
    RailHarness *waiter=[RailHarness new];waiter.profile[@"maxAge"]=@7;waiter.ratings.busy=YES;waiter.ratings.pendingIDs=[NSSet setWithObject:@"tt999"];
    __block BOOL ready=NO;[waiter settleHomeRatingsUntil:NSProcessInfo.processInfo.systemUptime+4 items:@[@{@"id":@"tt1"}] current:^BOOL{return YES;} done:^{ready=YES;}];CHECK(ready);
    ready=NO;[waiter settleHomeRatingsUntil:NSProcessInfo.processInfo.systemUptime+4 items:@[@{@"id":@"tt999"}] current:^BOOL{return YES;} done:^{ready=YES;}];CHECK(!ready);waiter.ratings.pendingIDs=[NSSet set];Wait(^BOOL{return ready;});
    ready=NO;[waiter settleHomeRatingsUntil:NSProcessInfo.processInfo.systemUptime-1 items:@[@{@"id":@"tt999"}] current:^BOOL{return YES;} done:^{ready=YES;}];CHECK(ready);

    // A source observation arriving while a real worker snapshot is queued must
    // not cause a current eligible title to be pruned by the old result.
    RailHarness *race=[RailHarness new];NSDictionary *raceTitle=Title(8801);__block NSArray *raceWindow=nil;
    [race prepareHomeRail:@[raceTitle] row:@{@"id":@"films",@"recipe":@"for-you"} done:^(NSArray *items,NSString *error){CHECK(!error);raceWindow=items;}];
    race.profile[@"sourceAvailability"][@"tt0008801"]=[RWAvailability observeAnalysis:@{@"compatible":@1,@"listings":@1} complete:YES error:nil quality:0 now:NSDate.date.timeIntervalSince1970];
    Wait(^BOOL{return raceWindow!=nil;});CHECK(raceWindow.count==1);
    double now=NSDate.date.timeIntervalSince1970;NSMutableArray *ratingPool=[NSMutableArray new];for(int i=0;i<12;i++){NSMutableDictionary *m=[Title(2000+i)mutableCopy];m[@"type"]=@"series";m[@"genres"]=@[@"Animation",@"Comedy"];m[@"imdbVotes"]=@(1000+i);[ratingPool addObject:m];}
    ratingPool[11][@"releaseInfo"]=@"2099";ratingPool[10][@"imdbRating"]=@2;ratingPool[9][@"genres"]=@[@"Drama"];
    NSDictionary *ratingRow=@{@"mediaType":@"series",@"recipe":@"category",@"anyGenres":@[@"Animation"]};NSDictionary *(^ratings)(NSString *)=^NSDictionary *(NSString *key){if([key isEqual:@"tt0002008"])return @{@"minimumAge":@18};if([key isEqual:@"tt0002007"])return @{@"minimumAge":@(-1),@"publisherAttempted":@YES,@"publisherPolicy":@3,@"checked":@(now)};return nil;};
    NSArray *classify=[RWHomeRailPolicy ratingCandidates:ratingPool row:ratingRow excluding:[NSSet setWithObject:@"tt0002006"] rating:ratings now:now];CHECK([[classify valueForKey:@"id"]isEqual:@[@"tt0002005",@"tt0002004",@"tt0002003",@"tt0002002"]]);
    CHECK([RWHomeRailPolicy ratingCandidates:[ratingPool arrayByAddingObjectsFromArray:ratingPool] row:ratingRow excluding:[NSSet set] rating:ratings now:now].count==4);
    CHECK([RWHomeRailPolicy ratingCandidates:ratingPool row:@{@"mediaType":@"movie"} excluding:[NSSet set] rating:ratings now:now].count==0);
    NSArray *upgrade=[RWHomeRailPolicy ratingCandidates:@[ratingPool[7]] row:ratingRow excluding:[NSSet set] rating:^NSDictionary *(NSString *key){return @{@"minimumAge":@(-1),@"publisherAttempted":@YES,@"checked":@(now)};} now:now];CHECK(upgrade.count==1);
    // Scarce Kids rating lookups prefer explicit family/children evidence over
    // a high-vote generic Animation tag; this priority does not grant a rating.
    NSMutableDictionary *family=[ratingPool[0]mutableCopy];family[@"genres"]=@[@"Animation",@"Family"];family[@"imdbVotes"]=@1;
    NSMutableDictionary *child=[ratingPool[1]mutableCopy];child[@"imdbVotes"]=@2;
    NSDictionary *childMeta=@{child[@"id"]:@{@"genres":@[@{@"name":@"children’s animated series"}]}};
    NSArray *targeted=[RWHomeRailPolicy ratingCandidates:@[ratingPool[2],ratingPool[3],ratingPool[4],ratingPool[5],family,child] row:ratingRow excluding:[NSSet set] metadata:childMeta preferences:@{} rating:^NSDictionary *(NSString *key){return nil;} now:now];
    CHECK([[targeted valueForKey:@"id"]isEqual:@[@"tt0002001",@"tt0002000",@"tt0002005",@"tt0002004"]]);
    NSMutableDictionary *adult=[family mutableCopy];adult[@"genres"]=@[@"Animation",@"Family",@"Adult animation"];
    CHECK([RWHomeRailPolicy ratingCandidates:@[adult] row:ratingRow excluding:[NSSet set] rating:^NSDictionary *(NSString *key){return nil;} now:now].count==0);
    CHECK([RWHomeRailPolicy ratingCandidates:@[family] row:ratingRow excluding:[NSSet set] rating:^NSDictionary *(NSString *key){return @{@"minimumAge":@18};} now:now].count==0);
    // Family-tagged adult/family dramas must not consume all four research
    // slots ahead of actual children and family-animation candidates.
    NSMutableDictionary *drama=[Title(4100)mutableCopy];drama[@"type"]=@"series";drama[@"genres"]=@[@"Family",@"Drama"];drama[@"imdbVotes"]=@900000;
    NSMutableDictionary *cartoon=[Title(4101)mutableCopy];cartoon[@"type"]=@"series";cartoon[@"genres"]=@[@"Animation",@"Family"];cartoon[@"imdbVotes"]=@500;
    NSMutableDictionary *kidsLive=[Title(4102)mutableCopy];kidsLive[@"type"]=@"series";kidsLive[@"genres"]=@[@"Kids",@"Comedy"];kidsLive[@"imdbVotes"]=@100;
    NSMutableDictionary *animation=[Title(4103)mutableCopy];animation[@"type"]=@"series";animation[@"genres"]=@[@"Animation",@"Adventure"];animation[@"imdbVotes"]=@400;
    NSMutableDictionary *doc=[Title(4104)mutableCopy];doc[@"type"]=@"series";doc[@"genres"]=@[@"Documentary",@"Animation",@"Family"];doc[@"imdbVotes"]=@500000;
    NSDictionary *kidsRow=@{@"mediaType":@"series",@"recipe":@"for-you"};NSArray *audienceItems=@[drama,cartoon,kidsLive,animation,doc];
    NSArray *audienceTargets=[RWHomeRailPolicy ratingCandidates:audienceItems row:kidsRow excluding:[NSSet set] rating:^NSDictionary *(NSString *key){return nil;} now:now];
    CHECK([[audienceTargets valueForKey:@"id"]isEqual:@[@"tt0004102",@"tt0004101",@"tt0004103",@"tt0004100"]]);
    // This changes lookup order only, not formal age admission or returned metadata.
    NSDictionary *ageInput=@{@"profile":@{@"maxAge":@12},@"ageRatings":@{},@"metadata":@{},@"family":@[]};CHECK([RWDiscoverySnapshot filter:audienceTargets snapshot:ageInput].count==0);
    NSMutableDictionary *foreign=[cartoon mutableCopy];foreign[@"id"]=@"tt0004105";foreign[@"imdbVotes"]=@900000;foreign[@"discovery"]=@{@"primaryLanguage":@"tr",@"languageSource":@"https://example.com/fixture",@"industry":@"other"};
    NSArray *languageTargets=[RWHomeRailPolicy ratingCandidates:@[foreign,cartoon] row:kidsRow excluding:[NSSet set] metadata:@{} preferences:@{@"languageMode":@"english_first"} rating:^NSDictionary *(NSString *key){return nil;} now:now];CHECK([[languageTargets valueForKey:@"id"]isEqual:@[@"tt0004101",@"tt0004105"]]);
    languageTargets=[RWHomeRailPolicy ratingCandidates:@[foreign,cartoon] row:kidsRow excluding:[NSSet set] metadata:@{} preferences:@{@"languageMode":@"all"} rating:^NSDictionary *(NSString *key){return nil;} now:now];CHECK([[languageTargets valueForKey:@"id"]isEqual:@[@"tt0004105",@"tt0004101"]]);
    // World classification must spend its four slots on relevant titles.
    // Cached metadata is authoritative even if the raw provider card is stale.
    NSMutableArray *international=[NSMutableArray new];NSMutableDictionary *languages=[NSMutableDictionary new];
    for(int i=0;i<9;i++){NSMutableDictionary *m=[Title(3000+i)mutableCopy];m[@"genres"]=@[@"Animation",@"Family"];m[@"imdbVotes"]=@(90000-i*1000);[international addObject:m];languages[m[@"id"]]=@{@"primaryLanguage":i<3?@"en":@"ja",@"languageSource":@"https://example.com/fixture",@"industry":@"other"};}
    [languages removeObjectForKey:@"tt0003003"];[international[3]removeObjectForKey:@"discovery"];international[7][@"imdbRating"]=@7.0;languages[@"tt0003008"]=@{@"primaryLanguage":@"hi",@"languageSource":@"https://example.com/fixture",@"industry":@"bollywood"};
    // The production Home path must advance by provider cursor, not filtered item count.
    RailHarness *worldStore=[RailHarness new];NSMutableArray *worldFilms=[NSMutableArray new];
    for(NSDictionary *raw in Titles(54000,2)){NSMutableDictionary *m=[raw mutableCopy];m[@"discovery"]=@{@"primaryLanguage":@"fr",@"languageSource":@"fixture",@"industry":@"other"};[worldFilms addObject:m];}
    __block NSUInteger worldCalls=0;
    worldStore.discoveryMetadata.worldHandler=^(NSDictionary *cursor,NSString *owner,void(^done)(NSArray *,NSDictionary *,NSString *)){worldCalls++;CHECK([owner isEqual:@"home-world:regular"]);CHECK(!cursor.count);done(worldFilms,@{@"sroffset":@8,@"continue":@"-||"},nil);};
    __block BOOL worldDone=NO;
    [worldStore homeRailPage:@{@"id":@"world",@"mediaType":@"movie",@"recipe":@"world"} cursor:@{} excluding:[NSSet set] current:^BOOL{return YES;} done:^(NSArray *items,NSDictionary *next,BOOL more,NSString *error){CHECK(!error&&more);CHECK([next[@"skip"]integerValue]==8);CHECK(items.count==2);for(NSDictionary *m in items)CHECK([m[@"showLanguage"]boolValue]);worldDone=YES;}];
    Wait(^BOOL{return worldDone;});CHECK(worldCalls==1&&!worldStore.requests.count&&worldStore.checks.count==2);
    NSDictionary *worldRow=@{@"mediaType":@"movie",@"recipe":@"world"};NSDictionary *(^none)(NSString *)=^NSDictionary *(NSString *key){return nil;};
    NSArray *worldTargets=[RWHomeRailPolicy ratingCandidates:international row:worldRow excluding:[NSSet set] metadata:languages preferences:@{@"excludeBollywood":@YES} rating:none now:now];CHECK([[worldTargets valueForKey:@"id"]isEqual:@[@"tt0003004",@"tt0003005",@"tt0003006",@"tt0003003"]]);
    CHECK([RWHomeRailPolicy ratingCandidates:international row:worldRow excluding:[NSSet set] metadata:languages preferences:@{@"worldCinema":@NO} rating:none now:now].count==0);
    NSArray *high=[RWHomeRailPolicy ratingCandidates:international row:worldRow excluding:[NSSet setWithObject:@"tt0003004"] metadata:languages preferences:@{@"worldMinRating":@9} rating:none now:now];CHECK(high.count==0);
    NSDictionary *generalFilmRow=@{@"mediaType":@"movie",@"recipe":@"for-you"};
    NSArray *recentFilm=[RWHomeRailPolicy ratingCandidates:@[international[4]] row:generalFilmRow excluding:[NSSet set] rating:^NSDictionary *(NSString *key){return @{@"minimumAge":@(-1),@"checked":@(now)};} now:now];CHECK(recentFilm.count==0);
    NSArray *oldFilm=[RWHomeRailPolicy ratingCandidates:@[international[4]] row:generalFilmRow excluding:[NSSet set] rating:^NSDictionary *(NSString *key){return @{@"minimumAge":@(-1),@"checked":@(now-86401)};} now:now];CHECK(oldFilm.count==1);
    // Real Cinemeta pages contain null ratings/votes.169 aborted in the sort
    // comparator. Unknown and malformed values must sort as missing evidence.
    for(id raw in @[NSNull.null,@{},@[],@"not-rated",@"8.1 extra",@"nan",@(-1)]){
        ratingPool[0][@"imdbVotes"]=raw;ratingPool[1][@"imdbRating"]=raw;
        NSArray *safe=[RWHomeRailPolicy ratingCandidates:ratingPool row:ratingRow excluding:[NSSet setWithObject:@"tt0002006"] rating:ratings now:now];CHECK(safe.count==4);CHECK(![[safe valueForKey:@"id"]containsObject:@"tt0002000"]);
    }
    RailHarness *s=[RailHarness new];s.pool=@[];s.providerItems=Titles(100,50);
    NSDictionary *page=Request(s,@{},[NSSet set],^BOOL{return YES;});CHECK(![page[@"error"]length]);CHECK([page[@"items"]count]==4);CHECK(s.checks.count==4);CHECK([page[@"cursor"][@"skip"]integerValue]==50);CHECK([page[@"more"]boolValue]);for(NSDictionary *m in page[@"items"])CHECK([m[@"availability"][@"discovery_eligible"]boolValue]);
    NSSet *assigned=[NSSet setWithArray:[page[@"items"]valueForKey:@"id"]];NSDictionary *second=Request(s,page[@"cursor"],assigned,^BOOL{return YES;});CHECK(s.checks.count==8);CHECK(s.requests.count==1);CHECK([second[@"cursor"][@"skip"]integerValue]==50);for(NSDictionary *m in second[@"items"])CHECK(![assigned containsObject:RWID(m)]);
    // Once eligible records exist locally they append without another provider
    // or source request. The original assigned IDs remain excluded.
    NSUInteger requested=s.requests.count,checked=s.checks.count;NSDictionary *cached=Request(s,second[@"cursor"],[NSSet set],^BOOL{return YES;});CHECK([cached[@"items"]count]==8);CHECK(s.requests.count==requested&&s.checks.count==checked);
    // Enrichment rechecks must stay local, preserve exclusions, and never turn
    // newly acquired but unverified media into playable shelf cards.
    __block NSArray *local=nil;NSDictionary *localRow=@{@"id":@"films",@"mediaType":@"movie",@"recipe":@"for-you"};NSUInteger ratingsBefore=s.ratings.enqueued,metadataBefore=s.discoveryMetadata.enqueued;
    [s recheckHomeRail:localRow excluding:assigned current:^BOOL{return YES;} done:^(NSArray *items,NSString *error){CHECK(!error);local=items;}];Wait(^BOOL{return local!=nil;});CHECK(local.count==4);for(NSDictionary *m in local)CHECK(![assigned containsObject:RWID(m)]&&[m[@"availability"][@"discovery_eligible"]boolValue]);
    CHECK(s.requests.count==requested&&s.checks.count==checked&&s.ratings.enqueued==ratingsBefore&&s.discoveryMetadata.enqueued==metadataBefore);
    s.profile[@"maxAge"]=@7;local=nil;[s recheckHomeRail:localRow excluding:[NSSet set] current:^BOOL{return YES;} done:^(NSArray *items,NSString *error){CHECK(!error);local=items;}];Wait(^BOOL{return local!=nil;});CHECK(!local.count);s.profile[@"maxAge"]=@(-1);
    __block BOOL localActive=YES,localDone=NO;[s recheckHomeRail:localRow excluding:[NSSet set] current:^BOOL{return localActive;} done:^(NSArray *items,NSString *error){CHECK(!items.count&&error.length>0);localDone=YES;}];localActive=NO;Wait(^BOOL{return localDone;});CHECK(s.requests.count==requested&&s.checks.count==checked&&s.ratings.enqueued==ratingsBefore);
    NSMutableSet *all=[assigned mutableCopy];[all addObjectsFromArray:[second[@"items"]valueForKey:@"id"]];NSArray *acquired=s.pool;s.pool=@[];s.providerError=@"Offline";NSDictionary *failed=Request(s,second[@"cursor"],all,^BOOL{return YES;});CHECK([failed[@"error"]isEqual:@"Offline"]&&[failed[@"cursor"]count]&&[failed[@"more"]boolValue]&&!failed[@"cursor"][@"exhaustedAt"]);CHECK(s.checks.count==checked);s.pool=acquired;
    NSDictionary *liveCard=[page[@"items"]firstObject],*filmRow=@{@"recipe":@"for-you"};CHECK([s homeRailRecordAllowed:liveCard row:filmRow]);CHECK(![s homeRailRecordAllowed:liveCard row:@{@"recipe":@"hero"}]);s.profile[@"hidden"]=@[RWID(liveCard)];CHECK(![s homeRailRecordAllowed:liveCard row:filmRow]);s.profile[@"hidden"]=@[];
    // Retained cache windows must use current metadata for category membership,
    // not the genre evidence stored when the card first entered the window.
    NSMutableDictionary *cachedCard=[liveCard mutableCopy],*oldGenre=[liveCard[@"discovery"]mutableCopy];oldGenre[@"genres"]=@[@{@"name":@"Action"}];cachedCard[@"discovery"]=oldGenre;
    NSDictionary *actionRow=@{@"recipe":@"category",@"mediaType":@"movie",@"anyGenres":@[@"Action"]};CHECK([s homeRailRecordAllowed:cachedCard row:actionRow]);
    NSMutableDictionary *newGenre=[oldGenre mutableCopy];newGenre[@"genres"]=@[@{@"name":@"Comedy"}];s.discoveryMetadata.records=@{RWID(cachedCard):newGenre};CHECK(![s homeRailRecordAllowed:cachedCard row:actionRow]);s.discoveryMetadata.records=nil;
    // Current-policy cache preparation removes hidden / expired cards and does
    // not carry an adult ready flag into a restricted profile.
    __block NSArray *window=nil;[s prepareHomeRail:page[@"items"] row:@{@"recipe":@"for-you"} done:^(NSArray *items,NSString *error){CHECK(!error);window=items;}];Wait(^BOOL{return window!=nil;});CHECK(window.count==4);s.profile[@"maxAge"]=@7;window=nil;[s prepareHomeRail:page[@"items"] row:@{@"recipe":@"for-you"} done:^(NSArray *items,NSString *error){CHECK(!error);window=items;}];Wait(^BOOL{return window!=nil;});CHECK(window.count==0);
    s.providerError=nil;NSUInteger beforeScan=s.requests.count;NSDictionary *kids=Request(s,@{},[NSSet set],^BOOL{return YES;});CHECK([kids[@"items"]count]==0&&[kids[@"more"]boolValue]);CHECK(s.checks.count==checked);CHECK(s.requests.count==beforeScan+3);CHECK([s.requests[beforeScan][@"genre"]isEqual:@"Family"]&&[s.requests[beforeScan+1][@"genre"]isEqual:@"Family"]&&[s.requests[beforeScan+2][@"genre"]isEqual:@"Animation"]);CHECK([kids[@"cursor"][@"catalogs"]count]==3);NSUInteger kidsConsumed=0;for(NSDictionary *c in [kids[@"cursor"][@"catalogs"]allValues])kidsConsumed+=[c[@"skip"]unsignedIntegerValue];CHECK(kidsConsumed==150);
    // Two pages containing only ineligible titles automatically lead to the
    // third, without using more than the one four-target source budget.
    s=[RailHarness new];NSMutableArray *bad=[NSMutableArray new];for(NSDictionary *m in Titles(800,50)){NSMutableDictionary *x=[m mutableCopy];x[@"imdbRating"]=@2;[bad addObject:x];}
    s.providerPages=@[bad,bad,Titles(900,50)];NSDictionary *third=Request(s,@{},[NSSet set],^BOOL{return YES;});CHECK(s.requests.count==3);CHECK(s.checks.count==4);CHECK([third[@"items"]count]==4);CHECK([third[@"cursor"][@"skip"]integerValue]==100);CHECK([third[@"cursor"][@"catalogs"][@"movie|Popular|"][@"skip"]integerValue]==50);
    s=[RailHarness new];s.providerPages=@[bad,@[]];NSDictionary *end=Request(s,@{},[NSSet set],^BOOL{return YES;});CHECK(s.requests.count==3&&! [end[@"more"]boolValue]);CHECK([end[@"cursor"][@"skip"]integerValue]==50);CHECK(!s.checks.count);
    CHECK([end[@"cursor"][@"exhaustedAt"]doubleValue]>0);
    // Classification can finish after the provider was exhausted. Local cards
    // still qualify, without repeating the known empty endpoint.
    NSDictionary *quiet=Request(s,end[@"cursor"],[NSSet set],^BOOL{return YES;});CHECK(![quiet[@"more"]boolValue]&&s.requests.count==3);
    s.pool=Titles(1000,4);NSDictionary *late=Request(s,end[@"cursor"],[NSSet set],^BOOL{return YES;});CHECK([late[@"items"]count]==4&&s.requests.count==3&&s.checks.count==4);
    NSDictionary *used=Request(s,late[@"cursor"],[NSSet setWithArray:[late[@"items"]valueForKey:@"id"]],^BOOL{return YES;});CHECK(![used[@"more"]boolValue]&&s.requests.count==3);
    s.pool=@[];s.providerPages=@[];s.providerItems=Titles(1100,4);NSMutableDictionary *expired=[end[@"cursor"]mutableCopy];expired[@"exhaustedAt"]=@(NSDate.date.timeIntervalSince1970-21601);NSMutableDictionary *expiredCatalogs=[NSMutableDictionary new];for(NSString *key in expired[@"catalogs"]){NSMutableDictionary *c=[expired[@"catalogs"][key]mutableCopy];c[@"exhaustedAt"]=expired[@"exhaustedAt"];expiredCatalogs[key]=c;}expired[@"catalogs"]=expiredCatalogs;
    NSDictionary *fresh=Request(s,expired,[NSSet set],^BOOL{return YES;});CHECK(s.requests.count==4&&[s.requests.lastObject[@"skip"]integerValue]==0);CHECK([fresh[@"items"]count]==4&&[fresh[@"cursor"][@"skip"]integerValue]==4&&!fresh[@"cursor"][@"exhaustedAt"]);
    // A late provider response cannot start source work after leaving Home.
    s=[RailHarness new];s.hold=YES;__block BOOL active=YES,done=NO;[s homeRailPage:@{@"id":@"films",@"mediaType":@"movie",@"recipe":@"for-you"} cursor:@{} excluding:[NSSet set] current:^BOOL{return active;} done:^(NSArray *items,NSDictionary *next,BOOL more,NSString *error){CHECK(error.length>0);done=YES;}];Wait(^BOOL{return s.held!=nil;});active=NO;s.held(Titles(400,32),nil);s.held=nil;Wait(^BOOL{return done;});CHECK(s.checks.count==0);
    // The actual async cache path must agree with Home's quality prior.
    RailHarness *priorStore=[RailHarness new];priorStore.profile[@"discoveryPreferences"]=@{@"recommendationAudience":@"all_ages"};NSDictionary *cave=@{@"id":@"tt0432325",@"type":@"movie",@"name":@"The Cave of the Yellow Dog",@"releaseInfo":@"2005",@"genres":@[@"Family"],@"imdbRating":@7.5,@"imdbVotes":@3844,@"discovery":@{@"primaryLanguage":@"mn",@"languageSource":@"fixture",@"industry":@"other"}};
    priorStore.profile[@"sourceAvailability"][@"tt0432325"]=[RWAvailability observeAnalysis:@{@"compatible":@1,@"listings":@1} complete:YES error:nil quality:0 now:NSDate.date.timeIntervalSince1970];
    for(NSNumber *prior in @[@7.5,@6.5,@7.5]){priorStore.discoveryHome=@{@"ratingPriors":@[prior,prior]};window=nil;
        [priorStore prepareHomeRail:@[cave] row:worldRow done:^(NSArray *items,NSString *error){CHECK(!error);window=items;}];Wait(^BOOL{return window!=nil;});CHECK(window.count==([prior doubleValue]>7?1:0));}
    // The opening batch processes offscreen rows and preserves prior/recipe
    // gates without network work. Profile changes reject its queued response.
    __block NSArray *opening=nil;NSDictionary *offscreen=@{@"id":@"world",@"title":@"World Cinema",@"recipe":@"world",@"mediaType":@"movie",@"items":@[cave]};
    [priorStore prepareHomeFeedRows:@[offscreen] done:^(NSArray *rows,NSString *error){CHECK(!error);opening=rows;}];Wait(^BOOL{return opening!=nil;});CHECK([opening[0][@"items"]count]==1);CHECK([opening[0][@"items"][0][@"id"]isEqual:@"tt0432325"]);
    priorStore.profile[@"maxAge"]=@7;opening=nil;[priorStore prepareHomeFeedRows:@[offscreen] done:^(NSArray *rows,NSString *error){CHECK(!error);opening=rows;}];Wait(^BOOL{return opening!=nil;});CHECK([opening[0][@"items"]count]==0);
    priorStore.profile[@"maxAge"]=@(-1);__block BOOL openingDone=NO;[priorStore prepareHomeFeedRows:@[offscreen] done:^(NSArray *rows,NSString *error){CHECK(rows==nil&&error.length>0);openingDone=YES;}];priorStore.state[@"activeProfile"]=@"other";Wait(^BOOL{return openingDone;});
    CHECK(!priorStore.requests.count&&!priorStore.checks.count);
    // Failed metadata lookups share the existing five-minute cooldown. A new
    // end-scroll must not select the same four missing indexes over and over.
    RailHarness *missing=[RailHarness new];NSMutableArray *seriesMissing=[NSMutableArray new];
    for(NSDictionary *m in Titles(9000,4)){NSMutableDictionary *x=[m mutableCopy];x[@"type"]=@"series";[seriesMissing addObject:x];}missing.pool=seriesMissing;
    __block BOOL firstMissing=NO;[missing verifyHomeRail:seriesMissing index:0 current:^BOOL{return YES;} done:^{firstMissing=YES;}];Wait(^BOOL{return firstMissing;});CHECK(missing.metadataRequests==4&&missing.checks.count==0);
    __block NSArray *retryTargets=nil;[missing rankHomeRail:seriesMissing row:@{@"id":@"shows",@"mediaType":@"series",@"recipe":@"for-you"} excluding:[NSSet set] available:NO done:^(NSArray *items){retryTargets=items;}];Wait(^BOOL{return retryTargets!=nil;});CHECK(retryTargets.count==0);
    __block BOOL secondMissing=NO;[missing verifyHomeRail:seriesMissing index:0 current:^BOOL{return YES;} done:^{secondMissing=YES;}];Wait(^BOOL{return secondMissing;});CHECK(missing.metadataRequests==4&&missing.checks.count==0);
    for(NSDictionary *m in Titles(9004,4)){NSMutableDictionary *x=[m mutableCopy];x[@"type"]=@"series";[seriesMissing addObject:x];}missing.pool=seriesMissing;
    retryTargets=nil;[missing rankHomeRail:seriesMissing row:@{@"id":@"shows",@"mediaType":@"series",@"recipe":@"for-you"} excluding:[NSSet set] available:NO done:^(NSArray *items){retryTargets=items;}];Wait(^BOOL{return retryTargets!=nil;});CHECK(retryTargets.count==4);
    for(NSDictionary *candidate in retryTargets)CHECK([[candidate[@"id"]substringFromIndex:2]integerValue]>=9004);
    __block BOOL advancedMissing=NO;[missing verifyHomeRail:retryTargets index:0 current:^BOOL{return YES;} done:^{advancedMissing=YES;}];Wait(^BOOL{return advancedMissing;});CHECK(missing.metadataRequests==8&&missing.checks.count==0);
    // An old exhausted Featured cursor must not block the independent Popular
    // catalog. Cards already assigned to other shelves remain excluded.
    RailHarness *expandedCatalog=[RailHarness new];expandedCatalog.providerItems=Titles(9500,4);
    NSDictionary *legacyEnd=@{@"page":@22,@"skip":@99,@"exhaustedAt":@(NSDate.date.timeIntervalSince1970)};
    NSDictionary *expandedPage=Request(expandedCatalog,legacyEnd,[NSSet setWithObject:@"tt0009500"],^BOOL{return YES;});
    CHECK(expandedCatalog.requests.count==1);CHECK([expandedCatalog.requests.firstObject[@"sort"]isEqual:@"Popular"]);CHECK([expandedCatalog.requests.firstObject[@"skip"]integerValue]==0);
    CHECK([expandedPage[@"items"]count]==3&&expandedCatalog.checks.count==3);for(NSDictionary *m in expandedPage[@"items"])CHECK(![m[@"id"]isEqual:@"tt0009500"]);
    // Successfully acquired catalog pages are acknowledged before slow work.
    // Holding/failing a save cannot start source checks or another page.
    RailHarness *progress=[RailHarness new];progress.providerItems=Titles(9600,4);
    __block NSDictionary *savedCursor=nil;__block void(^ack)(NSString *)=nil;__block NSDictionary *progressResult=nil;
    [progress homeRailPage:localRow cursor:@{} excluding:[NSSet set] current:^BOOL{return YES;} checkpoint:^(NSDictionary *cursor,BOOL more,void(^saved)(NSString *)){
        CHECK(more&&progress.pool.count==4&&progress.checks.count==0);savedCursor=cursor;ack=[saved copy];
    } done:^(NSArray *items,NSDictionary *cursor,BOOL more,NSString *error){progressResult=@{@"items":items?:@[],@"cursor":cursor?:@{},@"error":error?:@""};}];
    Wait(^BOOL{return ack!=nil;});CHECK(progressResult==nil&&progress.checks.count==0);CHECK([savedCursor[@"skip"]integerValue]==4);
    ack(nil);ack=nil;Wait(^BOOL{return progressResult!=nil;});CHECK([progressResult[@"items"]count]==4&&[progressResult[@"cursor"]isEqual:savedCursor]);
    RailHarness *saveFailed=[RailHarness new];saveFailed.providerItems=Titles(9700,4);__block BOOL failedSave=NO;
    [saveFailed homeRailPage:localRow cursor:@{} excluding:[NSSet set] current:^BOOL{return YES;} checkpoint:^(NSDictionary *cursor,BOOL more,void(^saved)(NSString *)){saved(@"Disk unavailable");} done:^(NSArray *items,NSDictionary *cursor,BOOL more,NSString *error){CHECK([error isEqual:@"Disk unavailable"]&&!items.count&&!cursor.count);failedSave=YES;}];
    Wait(^BOOL{return failedSave;});CHECK(!saveFailed.checks.count&&saveFailed.requests.count==1);
    RailHarness *cancelledSave=[RailHarness new];cancelledSave.providerItems=Titles(9800,4);__block BOOL progressActive=YES,progressCancelled=NO;
    [cancelledSave homeRailPage:localRow cursor:@{} excluding:[NSSet set] current:^BOOL{return progressActive;} checkpoint:^(NSDictionary *cursor,BOOL more,void(^saved)(NSString *)){progressActive=NO;saved(nil);} done:^(NSArray *items,NSDictionary *cursor,BOOL more,NSString *error){CHECK(error.length&&!items.count);progressCancelled=YES;}];
    Wait(^BOOL{return progressCancelled;});CHECK(!cancelledSave.checks.count&&cancelledSave.requests.count==1);
    // An old regular shelf must reach its own catalog even when shared
    // metadata from another profile keeps supplying unchecked candidates.
    RailHarness *starved=[RailHarness new];starved.pool=Titles(10000,20);starved.providerItems=Titles(11000,8);
    NSDictionary *ownPage=Request(starved,@{@"page":@17},[NSSet set],^BOOL{return YES;});
    CHECK(starved.requests.count==1);CHECK([ownPage[@"cursor"][@"skip"]integerValue]==8);
    CHECK([ownPage[@"items"]count]==4);for(NSDictionary *m in ownPage[@"items"])CHECK([[m[@"id"]substringFromIndex:2]integerValue]>=11000);
    // Two asynchronous lanes overlap eligibility work, but never start a fifth
    // target. The harness holds callbacks rather than faking elapsed time.
    RailHarness *lanes=[RailHarness new];lanes.holdSources=YES;__block BOOL lanesDone=NO;
    [lanes verifyHomeRail:Titles(12000,12) index:0 current:^BOOL{return YES;} done:^{lanesDone=YES;}];
    Wait(^BOOL{return lanes.heldSources.count>0;});CHECK(lanes.heldSources.count==2&&!lanesDone);
    for(NSUInteger i=0;i<4;i++){Wait(^BOOL{return lanes.heldSources.count>0;});void(^reply)(void)=lanes.heldSources.firstObject;[lanes.heldSources removeObjectAtIndex:0];reply();}
    Wait(^BOOL{return lanesDone;});CHECK(lanes.checks.count==4&&lanes.sourcePeak==2&&lanes.sourceActive==0&&!lanes.heldSources.count);
    // Ready cached cards remain immediate between catalog turns. The warm-pool
    // regression below separately requires a real request when the turn is due.
    NSUInteger readyRequests=starved.requests.count;NSDictionary *immediate=Request(starved,ownPage[@"cursor"],[NSSet set],^BOOL{return YES;});CHECK([immediate[@"items"]count]==4&&starved.requests.count==readyRequests);
    RailHarness *cancelLanes=[RailHarness new];cancelLanes.holdSources=YES;__block BOOL runLanes=YES;__block NSUInteger completions=0;
    [cancelLanes verifyHomeRail:Titles(13000,12) index:0 current:^BOOL{return runLanes;} done:^{completions++;}];
    Wait(^BOOL{return cancelLanes.heldSources.count==2;});runLanes=NO;
    NSArray *held=[cancelLanes.heldSources copy];[cancelLanes.heldSources removeAllObjects];for(void(^reply)(void) in held)reply();
    CHECK(completions==1&&cancelLanes.checks.count==2&&cancelLanes.sourceActive==0);
    // Bounded diagnostic stages retain no provider bodies or unbounded history.
    for(int i=0;i<80;i++)[cancelLanes traceHomeRailStage:@"test" detail:@{@"index":@(i)}];CHECK([[cancelLanes valueForKey:@"homeRailEvents"]count]==64);
    // Enrichment may reflect an older age snapshot. The received page remains
    // the candidate set; the next rank uses today's complete eligibility gates.
    RailHarness *lateClassification=[RailHarness new];lateClassification.dropEnriched=YES;lateClassification.providerItems=Titles(14000,4);
    NSDictionary *reconsidered=Request(lateClassification,@{},[NSSet set],^BOOL{return YES;});CHECK([reconsidered[@"items"]count]==4&&lateClassification.requests.count==1&&lateClassification.checks.count==4);
    // A transient failure must not monopolize a shelf: use the independent
    // next catalog without consuming any offset from the failed request.
    RailHarness *fallback=[RailHarness new];fallback.providerItems=Titles(15000,4);fallback.providerErrors=@[@"HTTP 504",NSNull.null];
    NSDictionary *recovered=Request(fallback,@{},[NSSet setWithObject:@"tt0015000"],^BOOL{return YES;});
    CHECK(fallback.requests.count==2);CHECK([fallback.requests.lastObject[@"sort"]isEqual:@"Popular"]);
    CHECK([recovered[@"items"]count]==3&&![recovered[@"error"]length]);
    CHECK([recovered[@"cursor"][@"catalogs"][@"movie|Top rated|"][@"skip"]integerValue]==0);
    CHECK([recovered[@"cursor"][@"catalogs"][@"movie|Popular|"][@"skip"]integerValue]==4);
    for(NSDictionary *m in recovered[@"items"])CHECK(![RWID(m)isEqual:@"tt0015000"]);
    // All endpoints failing consumes at most the existing three reads. A
    // second gesture during cooldown performs no network or source checks.
    RailHarness *outage=[RailHarness new];outage.profile[@"maxAge"]=@7;outage.providerError=@"HTTP 504";
    NSDictionary *unavailable=Request(outage,@{},[NSSet set],^BOOL{return YES;});
    CHECK(outage.requests.count==3&&!outage.checks.count&&[unavailable[@"more"]boolValue]);
    CHECK([unavailable[@"error"]length]&&!unavailable[@"cursor"][@"exhaustedAt"]);
    for(NSDictionary *state in [unavailable[@"cursor"][@"catalogs"]allValues])CHECK([state[@"skip"]integerValue]==0&&state[@"failedAt"]&&!state[@"exhaustedAt"]);
    NSDictionary *deferred=Request(outage,unavailable[@"cursor"],[NSSet set],^BOOL{return YES;});
    CHECK(outage.requests.count==3&&!outage.checks.count&&[deferred[@"more"]boolValue]&&[deferred[@"error"]length]);
    // Failure checkpoints cannot bypass durable-save failures or cancellation.
    for(NSNumber *cancel in @[@NO,@YES]){
        RailHarness *guard=[RailHarness new];guard.providerError=@"HTTP 504";__block BOOL current=YES,finished=NO;
        [guard homeRailPage:localRow cursor:@{} excluding:[NSSet set] current:^BOOL{return current;} checkpoint:^(NSDictionary *cursor,BOOL more,void(^saved)(NSString *)){
            CHECK(more&&guard.requests.count==1&&!guard.checks.count);
            CHECK([cursor[@"catalogs"][@"movie|Top rated|"][@"skip"]integerValue]==0&&cursor[@"catalogs"][@"movie|Top rated|"][@"failedAt"]);
            if(cancel.boolValue)current=NO;saved(cancel.boolValue?nil:@"Disk unavailable");
        } done:^(NSArray *items,NSDictionary *cursor,BOOL more,NSString *error){CHECK(!items.count&&error.length);if(!cancel.boolValue)CHECK([error isEqual:@"Disk unavailable"]);finished=YES;}];
        Wait(^BOOL{return finished;});CHECK(guard.requests.count==1&&!guard.checks.count);
    }
    // Metadata arriving after a received page must be used before consuming
    // another page. Existing source checks still qualify every returned card.
    RailHarness *lateMetadata=[RailHarness new];NSMutableArray *unclassified=[NSMutableArray new];
    for(NSDictionary *m in Titles(16000,4)){NSMutableDictionary *copy=[m mutableCopy];[copy removeObjectForKey:@"discovery"];[unclassified addObject:copy];}
    lateMetadata.providerItems=unclassified;__weak RailMetadata *metadataService=lateMetadata.discoveryMetadata;
    lateMetadata.discoveryMetadata.onPriority=^(NSArray *items){metadataService.pendingIDs=[NSSet setWithArray:[items valueForKey:@"id"]];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/5),dispatch_get_main_queue(),^{NSMutableDictionary *records=[NSMutableDictionary new];for(NSDictionary *m in items)records[m[@"id"]]=@{@"primaryLanguage":@"en",@"languageSource":@"https://example.test/verified",@"industry":@"other"};metadataService.records=records;metadataService.pendingIDs=[NSSet set];});};
    NSDictionary *lateResult=Request(lateMetadata,@{},[NSSet set],^BOOL{return YES;});
    CHECK(lateMetadata.requests.count==1);CHECK(lateMetadata.checks.count==4);CHECK([lateResult[@"items"]count]==4);CHECK(![lateResult[@"error"]length]);
    // Unknown language/industry is researched; positively excluded evidence,
    // hidden identities, future releases and low quality do not consume slots.
    NSDictionary *metaRow=@{@"mediaType":@"movie",@"recipe":@"for-you"};NSMutableDictionary *metadataMap=[NSMutableDictionary new];
    metadataMap[@"tt0016000"]=@{@"primaryLanguage":@"fr",@"languageSource":@"fixture",@"industry":@"other"};
    NSArray *metaTargets=[RWHomeRailPolicy metadataCandidates:unclassified row:metaRow excluding:[NSSet setWithObject:@"tt0016001"] metadata:metadataMap preferences:@{} now:now];
    CHECK([[metaTargets valueForKey:@"id"]isEqual:@[@"tt0016002",@"tt0016003"]]);
    metadataMap[@"tt0016002"]=@{@"entityID":@"Q3",@"fetchedAt":@(now),@"industry":@"unknown"};
    metaTargets=[RWHomeRailPolicy metadataCandidates:unclassified row:metaRow excluding:[NSSet setWithObject:@"tt0016001"] metadata:metadataMap preferences:@{} now:now];CHECK(metaTargets.count==1);
    CHECK([RWHomeRailPolicy metadataCandidates:Titles(17000,8) row:metaRow excluding:[NSSet set] metadata:@{} preferences:@{} now:now].count==0);
    __block BOOL evidenceDone=NO;lateMetadata.discoveryMetadata.pendingIDs=[NSSet setWithObject:@"tt0016000"];
    [lateMetadata settleHomeEvidenceUntil:NSProcessInfo.processInfo.systemUptime-1 ratings:@[] metadata:@[unclassified[0]] current:^BOOL{return YES;} done:^{evidenceDone=YES;}];CHECK(evidenceDone);
    evidenceDone=NO;[lateMetadata settleHomeEvidenceUntil:NSProcessInfo.processInfo.systemUptime+8 ratings:@[] metadata:@[unclassified[0]] current:^BOOL{return NO;} done:^{evidenceDone=YES;}];CHECK(evidenceDone);
    // A warm shared pool must not starve this row's own catalog forever.
    // Two locally ready batches are useful; the third owes a real catalog turn.
    RailHarness *fair=[RailHarness new];fair.pool=Titles(18000,40);fair.providerItems=Titles(19000,4);
    for(NSDictionary *m in fair.pool)fair.profile[@"sourceAvailability"][RWID(m)]=[RWAvailability observeAnalysis:@{@"compatible":@1,@"listings":@1} complete:YES error:nil quality:0 now:NSDate.date.timeIntervalSince1970];
    NSMutableSet *shown=[NSMutableSet new];NSDictionary *one=Request(fair,@{},shown,^BOOL{return YES;});CHECK([one[@"items"]count]==12&&fair.requests.count==0);[shown addObjectsFromArray:[one[@"items"]valueForKey:@"id"]];
    NSDictionary *two=Request(fair,one[@"cursor"],shown,^BOOL{return YES;});CHECK([two[@"items"]count]==12&&fair.requests.count==0);[shown addObjectsFromArray:[two[@"items"]valueForKey:@"id"]];
    NSDictionary *freshTurn=Request(fair,two[@"cursor"],shown,^BOOL{return YES;});CHECK(fair.requests.count==1);CHECK(fair.checks.count==4);CHECK([freshTurn[@"cursor"][@"catalogPolicy"]integerValue]==1);CHECK([freshTurn[@"cursor"][@"catalogs"][@"movie|Top rated|"][@"skip"]integerValue]==4);CHECK([freshTurn[@"cursor"][@"localOnlyPages"]integerValue]==0);
    for(NSString *key in fair.checks)CHECK([[fair.providerItems valueForKey:@"id"]containsObject:key]);
    // A failed catalog turn must still return qualified local records, while
    // recording the provider cooldown without claiming its page was consumed.
    RailHarness *cachedOutage=[RailHarness new];cachedOutage.pool=fair.pool;cachedOutage.profile[@"sourceAvailability"]=[fair.profile[@"sourceAvailability"]mutableCopy];cachedOutage.providerError=@"Offline";
    NSDictionary *due=@{@"page":@2,@"localOnlyPages":@2};NSDictionary *fallbackReady=Request(cachedOutage,due,[NSSet set],^BOOL{return YES;});
    CHECK(cachedOutage.requests.count==1);CHECK([fallbackReady[@"items"]count]==12&&![fallbackReady[@"error"]length]);CHECK(fallbackReady[@"cursor"][@"catalogs"][@"movie|Top rated|"][@"failedAt"]!=nil);CHECK([fallbackReady[@"cursor"][@"catalogs"][@"movie|Top rated|"][@"skip"]integerValue]==0);
    NSDictionary *cooldown=@{@"localOnlyPages":@2,@"catalogPolicy":@1,@"catalogs":@{@"movie|Top rated|":@{@"skip":@0,@"failedAt":@(now)},@"movie|Popular|":@{@"skip":@0,@"failedAt":@(now)}}};
    NSUInteger calls=cachedOutage.requests.count;NSDictionary *duringCooldown=Request(cachedOutage,cooldown,[NSSet set],^BOOL{return YES;});CHECK(cachedOutage.requests.count==calls&&[duringCooldown[@"items"]count]==12&&![duringCooldown[@"error"]length]);
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
