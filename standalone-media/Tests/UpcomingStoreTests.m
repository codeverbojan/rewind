#import <Foundation/Foundation.h>
#import "../RWUpcomingPolicy.h"
#import "../RWAtomicWriter.h"
static NSString *Documents;
static NSString *RWDocuments(void){return Documents;}
static NSString *RWString(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static NSString *Esc(NSString *x){return [x stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];}
typedef NS_ENUM(NSInteger,UIApplicationState){UIApplicationStateActive,UIApplicationStateBackground};
@interface UIApplication:NSObject
@property(nonatomic,assign) UIApplicationState applicationState;
+ (instancetype)sharedApplication;
@end
@implementation UIApplication
+ (instancetype)sharedApplication{static UIApplication *a;static dispatch_once_t once;dispatch_once(&once,^{a=[self new];});return a;}
@end
@interface TestRatings:NSObject
- (void)resolve:(NSArray *)items;
@end
@implementation TestRatings
- (void)resolve:(NSArray *)items{}
@end
@interface ScheduleStore:NSObject {
@public NSArray *_upcomingRequests;NSUInteger _upcomingRequestIndex,_upcomingDays,_upcomingTargetDays;NSString *_upcomingDay;BOOL _upcomingVisible;double _upcomingChecked,_upcomingRetryAfter,_upcomingRequestBegan;NSMutableDictionary *_upcomingFailures;NSMutableArray *_upcomingTrace;dispatch_queue_t _recommendationQueue;
}
@property(nonatomic,assign) BOOL catalogReady,upcomingBusy,restricted;
@property(nonatomic,strong) NSString *upcomingError;
@property(nonatomic,strong) NSArray *upcomingCatalog;
@property(nonatomic,strong) TestRatings *ratings;
@property(nonatomic,strong) NSMutableArray *requests;
@property(nonatomic,copy) void(^pending)(id,NSString *);
- (void)JSON:(NSString *)url foreground:(BOOL)foreground done:(void(^)(id,NSString *))done;
- (void)report:(NSDictionary *)report;
- (void)respond:(id)data error:(NSString *)error;
- (void)refreshUpcoming;
- (void)finishUpcoming:(NSArray *)items error:(NSString *)error;
- (void)persistUpcoming;
- (void)setUpcomingVisible:(BOOL)visible;
- (void)loadMoreUpcoming;
- (void)retryUpcoming;
@end
@implementation ScheduleStore
- (instancetype)init{if((self=[super init])){self.catalogReady=YES;self.requests=[NSMutableArray new];self.upcomingCatalog=@[];self.ratings=[TestRatings new];_recommendationQueue=dispatch_queue_create("schedule-test",DISPATCH_QUEUE_SERIAL);}return self;}
- (void)JSON:(NSString *)url foreground:(BOOL)foreground done:(void(^)(id,NSString *))done{NSAssert(!self.pending,@"Only one request");NSAssert(foreground,@"Visible schedule uses existing foreground metadata priority");[self.requests addObject:url];self.pending=done;}
- (void)report:(NSDictionary *)report{}
- (void)respond:(id)data error:(NSString *)error{void(^done)(id,NSString *)=self.pending;self.pending=nil;if(done)done(data,error);}
#include "../RewindUpcomingStore.inc"
@end
static void Spin(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.003]];}
static void Finish(ScheduleStore *s){for(int i=0;i<120&&(s.pending||s.upcomingBusy);i++){if(s.pending){NSString *url=s.requests.lastObject;[s respond:[url hasPrefix:@"https://api.tvmaze.com"]?@{@"episodes":@[]}:@{@"query":@{@"search":@[]}} error:nil];}Spin(.01);}}
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    Documents=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:Documents withIntermediateDirectories:YES attributes:nil error:nil];
    ScheduleStore *s=[ScheduleStore new];[s refreshUpcoming];CHECK(!s.requests.count);
    // A new day cannot retain yesterday's pagination with a fresh cache stamp.
    s->_upcomingDays=28;s->_upcomingDay=@"2000-01-01";s->_upcomingChecked=NSDate.date.timeIntervalSince1970-100;
    [s setUpcomingVisible:YES];CHECK(s.requests.count==1&&s.upcomingBusy);CHECK(s->_upcomingDays==0&&s->_upcomingChecked==0);
    [s loadMoreUpcoming];[s refreshUpcoming];CHECK(s.requests.count==1);
    [s setUpcomingVisible:NO];[s respond:@{@"episodes":@[]} error:nil];Spin(.03);CHECK(!s.pending&&!s.upcomingBusy&&s.requests.count==1);
    [s setUpcomingVisible:YES];CHECK(s.requests.count==2);NSString *failed=s.requests.lastObject;[s respond:nil error:@"HTTP 503"];CHECK(s.upcomingBusy&&!s.upcomingError.length&&s.requests.count==3&&![s.requests.lastObject isEqual:failed]);
    Finish(s);CHECK(!s.upcomingBusy&&s.upcomingError.length&&s->_upcomingRetryAfter>NSDate.date.timeIntervalSince1970);CHECK(s.requests.count==10&&s->_upcomingDays==0&&s->_upcomingChecked==0);CHECK([s->_upcomingRequests isEqual:@[failed]]);
    [s refreshUpcoming];CHECK(s.requests.count==10);[s retryUpcoming];CHECK(s.requests.count==11&&[s.requests.lastObject isEqual:failed]);Finish(s);
    CHECK(!s.upcomingBusy&&!s.pending&&!s.upcomingError.length);CHECK(s->_upcomingDays==2&&s.requests.count==11);CHECK(s->_upcomingRequests==nil);
    [s refreshUpcoming];CHECK(s.requests.count==11);[s loadMoreUpcoming];CHECK(s.upcomingBusy&&s.requests.count==12);NSString *more=s.requests.lastObject;CHECK([more containsString:@"api.tvmaze.com"]);[s loadMoreUpcoming];CHECK(s.requests.count==12);Finish(s);CHECK(s->_upcomingDays==4&&s.requests.count==17);
    [UIApplication sharedApplication].applicationState=UIApplicationStateBackground;[s loadMoreUpcoming];CHECK(s.requests.count==17&&!s.upcomingBusy);[UIApplication sharedApplication].applicationState=UIApplicationStateActive;[s refreshUpcoming];Finish(s);CHECK(s->_upcomingDays==6&&s.requests.count==23);
    s->_upcomingDays=28;[s loadMoreUpcoming];CHECK(s.requests.count==23);
    [s setUpcomingVisible:NO];s->_upcomingChecked=0;[s refreshUpcoming];CHECK(s.requests.count==23);
    dispatch_sync(s->_recommendationQueue,^{});__block BOOL idle=NO;[[RWAtomicWriter shared]whenIdle:^{idle=YES;}];for(int i=0;i<100&&!idle;i++)Spin(.01);CHECK(idle);
    NSDictionary *cache=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[Documents stringByAppendingPathComponent:@"rewind-upcoming.json"]] options:0 error:nil];CHECK([cache[@"days"]intValue]==6&&[cache[@"day"]isEqual:[RWUpcomingPolicy day:NSDate.date]]);CHECK(!cache[@"profiles"]);CHECK([cache[@"schema"]integerValue]==RWUpcomingCacheSchema);
    // Restoring an older saturated cache must refill earlier skipped dates.
    NSMutableDictionary *old=[cache mutableCopy];[old removeObjectForKey:@"schema"];CHECK([RWUpcomingPolicy cachedDays:old now:NSDate.date.timeIntervalSince1970]==0);CHECK([RWUpcomingPolicy cachedDays:cache now:NSDate.date.timeIntervalSince1970]==6);
    ScheduleStore *probe=[ScheduleStore new];[probe setUpcomingVisible:YES];
    CHECK([probe.requests.firstObject hasPrefix:@"https://api.tvmaze.com/"]);
    [probe respond:nil error:@"HTTP 503"];Spin(.03);
    CHECK(probe.pending!=nil);CHECK(probe.requests.count==2);CHECK(!probe.upcomingError.length);
    NSDateFormatter *air=[NSDateFormatter new];air.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];air.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];air.dateFormat=@"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
    NSDictionary *episode=@{@"season":@1,@"number":@2,@"airstamp":[air stringFromDate:[NSDate dateWithTimeIntervalSinceNow:3600]],@"name":@"New episode",@"show":@{@"name":@"Live schedule fixture",@"type":@"Scripted",@"externals":@{@"imdb":@"tt9199999"},@"url":@"https://www.tvmaze.com/shows/99999/fixture",@"language":@"English",@"premiered":@"2020-01-01"}};
    [probe respond:@{@"episodes":@[episode]} error:nil];Spin(.03);CHECK(probe.upcomingCatalog.count==1);CHECK([probe.upcomingCatalog[0][@"id"]isEqual:@"tt9199999"]);CHECK(probe.pending!=nil);
    Finish(probe);CHECK(probe.requests.count==10&&probe->_upcomingFailures.count==1&&probe->_upcomingRequests.count==1);CHECK(probe->_upcomingDays==0&&probe->_upcomingChecked==0);CHECK(probe->_upcomingTrace.count==10);
    NSString *retry=probe->_upcomingRequests.firstObject;[probe retryUpcoming];CHECK([probe.requests.lastObject isEqual:retry]);Finish(probe);CHECK(probe.requests.count==11&&probe->_upcomingDays==2&&!probe.upcomingError.length);
    // A manual refresh preserves existing metadata while beginning a new batch.
    probe.upcomingCatalog=@[@{@"id":@"tt12345",@"name":@"Kept until verified replacement"}];[probe retryUpcoming];CHECK(probe.pending&&probe.upcomingCatalog.count==1&&probe->_upcomingDays==0);[probe setUpcomingVisible:NO];[probe respond:nil error:@"Offline"];CHECK(!probe.pending&&!probe.upcomingBusy);
    ScheduleStore *outage=[ScheduleStore new];[outage setUpcomingVisible:YES];for(NSUInteger i=0;i<10;i++){CHECK(outage.pending!=nil);[outage respond:nil error:@"HTTP 503"];}
    CHECK(!outage.pending&&!outage.upcomingBusy&&outage.requests.count==10&&outage->_upcomingRequests.count==10);CHECK(outage->_upcomingDays==0&&outage->_upcomingChecked==0);[outage refreshUpcoming];CHECK(outage.requests.count==10);[outage setUpcomingVisible:NO];
    ScheduleStore *claims=[ScheduleStore new];[claims setUpcomingVisible:YES];for(NSUInteger i=0;i<3;i++){[claims respond:@{@"episodes":@[]} error:nil];Spin(.03);}
    NSString *query=claims.requests.lastObject;CHECK([query hasPrefix:@"https://www.wikidata.org/"]);[claims respond:@{@"query":@{@"search":@[@{@"title":@"Q12345"}]}} error:nil];CHECK([claims.requests.lastObject containsString:@"action=wbgetentities"]);
    [claims respond:nil error:@"HTTP 503"];Finish(claims);CHECK([claims->_upcomingRequests isEqual:@[query]]);CHECK(claims.requests.count==11&&claims->_upcomingDays==2&&claims->_upcomingChecked==0);
    [claims loadMoreUpcoming];CHECK(claims.pending&&[claims.requests.lastObject hasPrefix:@"https://api.tvmaze.com/"]);Finish(claims);CHECK(claims.requests.count==17&&claims->_upcomingDays==4&&claims->_upcomingChecked==0);CHECK([claims->_upcomingRequests isEqual:@[query]]);
    [claims retryUpcoming];CHECK([claims.requests.lastObject isEqual:query]);Finish(claims);CHECK(claims->_upcomingDays==4&&claims.requests.count==18&&claims->_upcomingChecked>0);[claims setUpcomingVisible:NO];
    dispatch_sync(probe->_recommendationQueue,^{});__block BOOL probeIdle=NO;[[RWAtomicWriter shared]whenIdle:^{probeIdle=YES;}];for(int i=0;i<100&&!probeIdle;i++)Spin(.01);CHECK(probeIdle);
    [NSFileManager.defaultManager removeItemAtPath:Documents error:nil];CHECK(![NSFileManager.defaultManager fileExistsAtPath:Documents]);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
