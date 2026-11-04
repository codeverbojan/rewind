#import <Foundation/Foundation.h>
#import "../RWTVPolicy.h"
#import "../RWReminderPolicy.h"
#import "../RWDiscoveryEpisodes.h"
#import "../RWAtomicWriter.h"
#import "../RWRatingPolicy.h"
#import "../RWEpisodeFetcher.h"
#import "../RWEpisodeCatalog.h"
#import "../RWMetadataBudget.h"
static NSString *Documents;
static NSString *RWDocuments(void){return Documents;}
static NSString *RWString(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static NSString *RWID(NSDictionary *m){return RWString(m[@"id"]);}
typedef NS_OPTIONS(NSUInteger,UIUserNotificationType){UIUserNotificationTypeSound=2,UIUserNotificationTypeAlert=4};
typedef NS_ENUM(NSInteger,UIApplicationState){UIApplicationStateActive,UIApplicationStateBackground};
static NSString *UILocalNotificationDefaultSoundName=@"default";
@interface UIUserNotificationSettings:NSObject
@property(nonatomic,assign) UIUserNotificationType types;
+ (instancetype)settingsForTypes:(UIUserNotificationType)t categories:(id)c;
@end
@implementation UIUserNotificationSettings
+ (instancetype)settingsForTypes:(UIUserNotificationType)t categories:(id)c{UIUserNotificationSettings *s=[self new];s.types=t;return s;}
@end
@interface UILocalNotification:NSObject
@property(nonatomic,strong) NSString *alertBody,*soundName;
@property(nonatomic,strong) NSDictionary *userInfo;
@end
@implementation UILocalNotification @end
@interface UIApplication:NSObject
@property(nonatomic,assign) UIApplicationState applicationState;
@property(nonatomic,strong) UIUserNotificationSettings *currentUserNotificationSettings;
@property(nonatomic,strong) NSMutableArray *sent;
@property(nonatomic,assign) NSUInteger permissionRequests;
+ (instancetype)sharedApplication;
- (void)registerUserNotificationSettings:(UIUserNotificationSettings *)s;
- (void)presentLocalNotificationNow:(UILocalNotification *)n;
@end
@implementation UIApplication
+ (instancetype)sharedApplication{static UIApplication *a;static dispatch_once_t once;dispatch_once(&once,^{a=[self new];a.sent=[NSMutableArray new];a.currentUserNotificationSettings=[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:nil];});return a;}
- (void)registerUserNotificationSettings:(UIUserNotificationSettings *)s{self.permissionRequests++;}
- (void)presentLocalNotificationNow:(UILocalNotification *)n{[self.sent addObject:n];}
@end
@interface TestRatings:NSObject
@property(nonatomic,strong) NSDictionary *value;
- (NSDictionary *)rating:(NSString *)key;
@end
@implementation TestRatings
- (NSDictionary *)rating:(NSString *)key{return self.value;}
@end
@interface RewindStore:NSObject {
@public RWEpisodeCatalog *_episodeCatalog;NSMutableDictionary *_seriesCache;RWDiscoveryEpisodes *_discoveryEpisodes;dispatch_queue_t _recommendationQueue;BOOL _checkingEpisodes;RWEpisodeFetcher *_episodeFetcher;NSURLSession *_episodeSession;NSDictionary *_lastEpisodeFetch;
}
@property(nonatomic,strong) NSMutableDictionary *state;
@property(nonatomic,strong) TestRatings *ratings;
@property(nonatomic,assign) BOOL catalogReady;
- (NSMutableDictionary *)profile;
- (BOOL)allowed:(NSDictionary *)show;
- (void)saveForReason:(NSString *)reason;
- (void)report:(NSDictionary *)report;
- (NSDictionary *)record:(NSString *)key;
- (NSArray *)history;
- (void)checkEpisodesBackground:(BOOL)b minimumInterval:(double)i notify:(BOOL)n done:(void(^)(BOOL))done;
@end
@implementation RewindStore
- (instancetype)init{if((self=[super init])){_episodeCatalog=[[RWEpisodeCatalog alloc]initWithSnapshot:@{} now:NSDate.date.timeIntervalSince1970];_seriesCache=[NSMutableDictionary new];_discoveryEpisodes=[RWDiscoveryEpisodes new];_recommendationQueue=dispatch_queue_create("episode-store-test",DISPATCH_QUEUE_SERIAL);self.ratings=[TestRatings new];self.state=[@{@"activeProfile":@"regular",@"profiles":[NSMutableDictionary new]}mutableCopy];for(NSString *key in @[@"regular",@"kids"])self.state[@"profiles"][key]=[@{@"maxAge":[key isEqual:@"kids"]?@7:@(-1),@"following":[NSMutableDictionary new],@"unfollowedShows":[NSMutableArray new],@"episodeUpdates":[NSMutableDictionary new],@"history":[NSMutableDictionary new],@"selectedSeasons":[NSMutableDictionary new],@"hidden":[NSMutableArray new],@"episodeNotifications":@YES}mutableCopy];}return self;}
- (NSMutableDictionary *)profile{return self.state[@"profiles"][self.state[@"activeProfile"]];}
- (BOOL)allowed:(NSDictionary *)show{return [RWRatingPolicy allows:[self.ratings rating:RWID(show)] age:[self.profile[@"maxAge"]integerValue]];}
- (void)saveForReason:(NSString *)reason{}
- (void)report:(NSDictionary *)report{}
- (NSDictionary *)record:(NSString *)key{return self.profile[@"history"][key];}
- (NSString *)availabilityVideoID:(NSDictionary *)meta{return [[RWDiscoveryEpisodes new]episode:nil show:[self canonicalShow:RWID(meta)] history:self.profile[@"history"] now:NSDate.date][@"id"]?:@"";}
- (NSArray *)history{return [self.profile[@"history"]allValues];}
#include "../RewindTVStore.inc"
@end
static void Spin(double s){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:s];while(end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];}
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    Documents=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:Documents withIntermediateDirectories:YES attributes:nil error:nil];
    RewindStore *s=[RewindStore new];UIApplication *app=UIApplication.sharedApplication;NSString *key=@"tt1234567";NSDictionary *base=@{@"id":key,@"type":@"series",@"name":@"A private show"};NSDateFormatter *f=[NSDateFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];f.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];f.dateFormat=@"yyyy-MM-dd'T'HH:mm:ss'Z'";
    NSString *released=[f stringFromDate:[NSDate dateWithTimeIntervalSinceNow:-60]];NSDictionary *ep=@{@"id":[key stringByAppendingString:@":1:1"],@"season":@1,@"episode":@1,@"released":released};NSMutableDictionary *show=[base mutableCopy];show[@"videos"]=@[ep];
    // Cache-only changes affect Home even when this show is not followed and
    // the caller never runs a full episode-reminder fetch.
    NSMutableArray *cacheEvents=[NSMutableArray new];
    id observer=[NSNotificationCenter.defaultCenter addObserverForName:@"RWSeriesCacheUpdated" object:s queue:nil usingBlock:^(NSNotification *note){[cacheEvents addObject:note.userInfo?:@{}];}];
    CHECK([s acceptShow:show profile:@"regular" notify:NO]==0);
    CHECK(cacheEvents.count==1&&[cacheEvents.lastObject[@"title"]isEqual:key]);
    CHECK(app.permissionRequests==0&&app.sent.count==0&&![s following:base]);
    [s->_seriesCache removeAllObjects];[cacheEvents removeAllObjects];
    [s follow:base enabled:YES];CHECK(app.permissionRequests==0&&[s following:base]);CHECK(![s.profile[@"following"][key][@"baseline"]boolValue]);
    CHECK([s acceptShow:show profile:@"regular" notify:YES]==0&&app.sent.count==0);CHECK([s.profile[@"following"][key][@"baseline"]boolValue]);
    // Install an existing followed-show baseline, then exercise production detection.
    void(^reset)(NSString *)=^(NSString *pid){s.state[@"profiles"][pid][@"following"][key]=@{@"meta":base,@"seen":@[],@"baseline":@YES,@"checked":@0,@"started":@(NSDate.date.timeIntervalSince1970-3600)};[s.state[@"profiles"][pid][@"episodeUpdates"]removeAllObjects];};
    reset(@"regular");CHECK([s acceptShow:show profile:@"regular" notify:YES]==1&&app.sent.count==1);CHECK([s episodeUpdates].count==1);UILocalNotification *n=app.sent.lastObject;CHECK([n.userInfo[@"rewindEpisodeUpdate"]boolValue]&&[n.alertBody rangeOfString:base[@"name"]].location==NSNotFound);CHECK([n.userInfo[@"rewindReminder"][@"profileID"]isEqual:@"regular"]);CHECK([n.userInfo[@"rewindReminder"][@"titleID"]isEqual:show[@"id"]]);
    CHECK([s acceptShow:show profile:@"regular" notify:YES]==0&&app.sent.count==1);
    reset(@"regular");s.profile[@"history"][ep[@"id"]]=@{@"completed":@YES};CHECK([s acceptShow:show profile:@"regular" notify:YES]==0&&app.sent.count==1&&![s episodeUpdates].count);[s.profile[@"history"]removeAllObjects];
    reset(@"regular");[s.profile[@"hidden"]addObject:key];CHECK([s acceptShow:show profile:@"regular" notify:YES]==0&&app.sent.count==1);[s.profile[@"hidden"]removeAllObjects];
    reset(@"regular");s.profile[@"episodeNotifications"]=@NO;CHECK([s acceptShow:show profile:@"regular" notify:YES]==1&&app.sent.count==1);s.profile[@"episodeNotifications"]=@YES;
    reset(@"regular");app.currentUserNotificationSettings.types=0;CHECK([s acceptShow:show profile:@"regular" notify:YES]==1&&app.sent.count==1);app.currentUserNotificationSettings.types=UIUserNotificationTypeAlert;
    reset(@"kids");CHECK([s acceptShow:show profile:@"kids" notify:YES]==0&&app.sent.count==1);s.ratings.value=@{@"minimumAge":@6};reset(@"kids");CHECK([s acceptShow:show profile:@"kids" notify:YES]==1&&app.sent.count==1);
    s.state[@"activeProfile"]=@"kids";s.ratings.value=@{@"minimumAge":@12};reset(@"kids");CHECK([s acceptShow:show profile:@"kids" notify:YES]==0&&app.sent.count==1);s.ratings.value=@{@"minimumAge":@6};reset(@"kids");CHECK([s acceptShow:show profile:@"kids" notify:YES]==1&&app.sent.count==2);
    reset(@"kids");CHECK([s acceptShow:show profile:@"kids" notify:NO]==1&&app.sent.count==2);
    [s remindEpisodes:base enabled:YES];CHECK(app.permissionRequests==1&&[s.profile[@"episodeNotifications"]boolValue]);[s remindEpisodes:base enabled:NO];CHECK(![s following:base]&&![s episodeUpdates].count&&[s.profile[@"unfollowedShows"]containsObject:key]);
    [cacheEvents removeAllObjects];
    for(int i=0;i<13;i++){NSString *identifier=[NSString stringWithFormat:@"ttcache%d",i];NSDictionary *value=@{@"id":identifier,@"type":@"series",@"videos":@[]};NSSet *before=[NSSet setWithArray:s->_seriesCache.allKeys];
        [s acceptShow:value profile:@"regular" notify:NO];
        CHECK(cacheEvents.count==(NSUInteger)i+1&&[cacheEvents.lastObject[@"title"]isEqual:identifier]);
        NSString *evicted=cacheEvents.lastObject[@"evicted"];if(before.count==12)CHECK(evicted.length&&[before containsObject:evicted]&&!s->_seriesCache[evicted]);else CHECK(!evicted.length);
        CHECK(s->_seriesCache.count<=12&&s->_seriesCache[identifier]);
    }
    NSUInteger events=cacheEvents.count;[s acceptShow:base profile:@"regular" notify:NO];CHECK(cacheEvents.count==events);
    // The production detail-capacity path retains only compact canonical data.
    RewindStore *capacity=[RewindStore new];NSMutableArray *ids=[NSMutableArray new];for(int i=1;i<=16;i++){NSString *identifier=[NSString stringWithFormat:@"tt%d",i];[ids addObject:identifier];[capacity acceptShow:@{@"id":identifier,@"type":@"series",@"videos":@[@{@"id":[identifier stringByAppendingString:@":1:1"],@"season":@1,@"episode":@1,@"released":released}]} profile:@"regular" notify:NO];}
    NSUInteger compactOnly=0;for(NSString *identifier in ids){CHECK([capacity canonicalShow:identifier]!=nil);if(![capacity cachedShow:identifier]){compactOnly++;CHECK([capacity canonicalShow:identifier][@"episodeIndexAt"]!=nil);}}CHECK(compactOnly==4&&capacity->_seriesCache.count==12&&[capacity discoveryShows].count==16);

    [s acceptShow:show profile:@"regular" notify:NO];NSDictionary *eviction=[s evictEpisodeDetailsForDiagnostics:@[key]];CHECK(eviction&&[eviction[@"before"]isEqual:eviction[@"after"]]);CHECK(![s cachedShow:key]&&[s canonicalShow:key]);
    [NSNotificationCenter.defaultCenter removeObserver:observer];
    // Actual store mutation, cache invalidation and profile separation.
    s.state[@"activeProfile"]=@"regular";[s.profile[@"history"]removeAllObjects];
    NSDictionary *ep2=@{@"id":[key stringByAppendingString:@":2:1"],@"season":@2,@"episode":@1,@"released":released};show[@"videos"]=@[ep,ep2];
    [s acceptShow:show profile:@"regular" notify:NO];[s follow:show enabled:YES];
    CHECK([[s upNext].firstObject[@"episodeVideoID"]isEqual:ep[@"id"]]);
    NSDictionary *other=[s.state[@"profiles"][@"kids"]copy];
    s.profile[@"history"][ep[@"id"]]=@{@"meta":base,@"videoID":ep[@"id"],@"position":@40,@"duration":@600,@"watchedSeconds":@30};
    CHECK([s markEpisode:ep show:show watched:YES]);
    CHECK([[s upNext].firstObject[@"episodeVideoID"]isEqual:ep2[@"id"]]);
    CHECK(![s continuingHistory].count);
    CHECK([[s record:ep[@"id"]][@"watchedSeconds"]intValue]==30);
    CHECK([s markEpisode:ep2 show:show watched:YES]);CHECK(![s upNext].count);
    CHECK([s.profile[@"selectedSeasons"][key]intValue]==2);
    CHECK([s markEpisode:ep show:show watched:NO]);
    CHECK([[s upNext].firstObject[@"episodeVideoID"]isEqual:ep[@"id"]]);
    CHECK([[s record:ep[@"id"]][@"position"]doubleValue]==0&&![[s record:ep[@"id"]][@"completed"]boolValue]);
    CHECK([s.state[@"profiles"][@"kids"]isEqual:other]);
    CHECK(![s markEpisode:@{@"id":@"other:1:1"} show:show watched:YES]);
    [s.profile[@"hidden"]addObject:key];CHECK(![s markEpisode:ep show:show watched:YES]);[s.profile[@"hidden"]removeObject:key];
    s.state[@"activeProfile"]=@"kids";s.ratings.value=@{@"minimumAge":@12};CHECK(![s markEpisode:ep show:show watched:YES]);
    NSDictionary *second=@{@"id":[key stringByAppendingString:@":2:1"],@"season":@2,@"episode":@1,@"released":released};show[@"videos"]=@[ep,second];
    CHECK(![s playbackAfter:ep[@"id"] show:show profileID:@"regular"]);
    CHECK(![s playbackAfter:ep[@"id"] show:show profileID:@"kids"]);
    s.ratings.value=@{@"minimumAge":@6};
    CHECK([[s playbackAfter:ep[@"id"] show:show profileID:@"kids"][@"videoID"]isEqual:second[@"id"]]);
    CHECK([[s playbackAfter:ep[@"id"] show:show profileID:@"kids"][@"meta"][@"season"]isEqual:@2]);
    [s.profile[@"hidden"]addObject:key];CHECK(![s playbackAfter:ep[@"id"] show:show profileID:@"kids"]);[s.profile[@"hidden"]removeObject:key];
    s.ratings.value=nil;CHECK(![s playbackAfter:ep[@"id"] show:show profileID:@"kids"]);
    s.state[@"activeProfile"]=@"regular";CHECK([s playbackAfter:ep[@"id"] show:show profileID:@"regular"]!=nil);
    CHECK(![s playbackAfter:second[@"id"] show:show profileID:@"regular"]);
    CHECK(![s playbackAfter:ep[@"id"] show:show profileID:@"kids"]);
    dispatch_sync(s->_recommendationQueue,^{});__block BOOL idle=NO;[RWAtomicWriter.shared whenIdle:^{idle=YES;}];for(int i=0;i<100&&!idle;i++)Spin(.01);CHECK(idle);[NSFileManager.defaultManager removeItemAtPath:Documents error:nil];CHECK(![NSFileManager.defaultManager fileExistsAtPath:Documents]);
    printf("{\"checks\":%d,\"failures\":%d,\"notification_calls\":%lu}\n",checks,failures,(unsigned long)app.sent.count);return failures?1:0;
}}
