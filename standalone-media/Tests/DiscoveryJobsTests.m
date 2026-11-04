#import "../RWDiscoverySnapshot.h"
#import "../RWRecommendationPolicy.h"
#import "../RWDiscoveryMetadataPolicy.h"
static int Checks,Failures;static BOOL MainAccess=YES;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
static BOOL Until(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:3];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];return ready();}
@interface JobRatings:NSObject
@property(nonatomic) NSUInteger calls;
@property(nonatomic) BOOL held;
@property(nonatomic,strong) NSMutableArray *pending;
- (void)ratingsForIDs:(NSArray *)ids done:(void(^)(NSDictionary *))done;
- (void)releaseAll;
@end
@implementation JobRatings
- (instancetype)init {if((self=[super init]))_pending=[NSMutableArray new];return self;}
- (void)ratingsForIDs:(NSArray *)ids done:(void(^)(NSDictionary *))done {MainAccess&=NSThread.isMainThread;self.calls++;CHECK(ids.count<=525);if(self.held)[self.pending addObject:[done copy]];else dispatch_async(dispatch_get_main_queue(),^{done(@{});});}
- (void)releaseAll {NSArray *pending=[self.pending copy];[self.pending removeAllObjects];for(void(^done)(NSDictionary *) in pending)done(@{});}
@end
@interface JobStore:NSObject {
    dispatch_queue_t _recommendationQueue;NSOperation *_relatedWork;NSMutableDictionary *_discoveryRatings;
}
@property(nonatomic,strong) NSMutableDictionary *state,*input;
@property(nonatomic,strong) JobRatings *imdbIndex;
@property(nonatomic,strong) NSDictionary *lastReport;
@property(nonatomic,readonly) NSDictionary *profile;
@property(nonatomic,readonly) BOOL restricted;
@property(nonatomic) NSInteger quality;
- (NSDictionary *)discoveryInputSnapshot;
- (NSArray *)allowedItems:(NSArray *)items;
- (void)report:(NSDictionary *)report;
- (void)blockWorker:(dispatch_semaphore_t)gate;
- (void)drain;
@end
@implementation JobStore
- (instancetype)init {if((self=[super init])){_recommendationQueue=dispatch_queue_create("org.rewind.tests.discovery",DISPATCH_QUEUE_SERIAL);_discoveryRatings=[NSMutableDictionary new];_imdbIndex=[JobRatings new];}return self;}
- (NSDictionary *)profile {MainAccess&=NSThread.isMainThread;return self.state[@"profiles"][self.state[@"activeProfile"]];}
- (BOOL)restricted {return [self.profile[@"maxAge"]integerValue]>=0;}
- (NSDictionary *)discoveryInputSnapshot {MainAccess&=NSThread.isMainThread;NSMutableDictionary *copy=[self.input mutableCopy];copy[@"profile"]=[self.profile copy];copy[@"quality"]=@(self.quality);return copy;}
- (NSArray *)allowedItems:(NSArray *)items {MainAccess&=NSThread.isMainThread;return [RWDiscoverySnapshot filter:items snapshot:[self discoveryInputSnapshot]];}
- (void)report:(NSDictionary *)report {MainAccess&=NSThread.isMainThread;self.lastReport=report;}
- (void)blockWorker:(dispatch_semaphore_t)gate {dispatch_async(_recommendationQueue,^{dispatch_semaphore_wait(gate,dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC));});}
- (void)drain {dispatch_sync(_recommendationQueue,^{});}
#include "../RewindDiscoveryJobs.inc"
@end
static NSMutableDictionary *Title(NSString *key){return [@{@"id":key,@"name":key,@"type":@"movie",@"genres":@[@"Thriller"],@"discovery":@{@"primaryLanguage":@"en",@"languageSource":@"fixture",@"industry":@"other"},@"imdbRating":@8.2,@"imdbVotes":@50000}mutableCopy];}
static JobStore *Store(void){JobStore *s=[JobStore new];s.state=[@{@"activeProfile":@"main",@"profiles":[@{@"main":[@{@"maxAge":@(-1),@"liked":@[],@"saved":@[],@"history":@{},@"hidden":@[],@"discoveryPreferences":@{}}mutableCopy],@"other":@{@"maxAge":@7}}mutableCopy]}mutableCopy];NSMutableArray *items=[NSMutableArray new];for(int i=0;i<30;i++)[items addObject:Title([NSString stringWithFormat:@"title-%d",i])];s.input=[@{@"groups":@[items],@"metadata":@{},@"ageRatings":@{}}mutableCopy];return s;}
int main(){@autoreleasepool{
    JobStore *s=Store();__block NSUInteger completed=0;__block NSArray *result=nil;NSDictionary *anchor=Title(@"anchor");
    [s relatedTitles:anchor done:^(NSArray *items){MainAccess&=NSThread.isMainThread;result=items;completed++;}];CHECK(Until(^BOOL{return completed==1;}));CHECK(result.count==12);NSDictionary *m=s.lastReport[@"discovery_job"];CHECK([m[@"worker_off_main"]boolValue]);CHECK([m[@"kind"]isEqual:@"related"]);CHECK([m[@"prepared"]integerValue]==30);CHECK([m[@"ratings_ids"]integerValue]==31);
    __block BOOL yielded=NO;dispatch_async(dispatch_get_main_queue(),^{yielded=YES;});[s enrichDiscoveryItems:s.input[@"groups"][0] done:^(NSArray *items){CHECK(yielded);MainAccess&=NSThread.isMainThread;result=items;completed++;}];CHECK(Until(^BOOL{return completed==2;}));CHECK(result.count==30);CHECK([s.lastReport[@"discovery_job"][@"worker_off_main"]boolValue]);CHECK([s.lastReport[@"discovery_job"][@"signals"]integerValue]==0);
    // A superseded request waiting behind the worker must not reach ratings.
    dispatch_semaphore_t gate=dispatch_semaphore_create(0);[s blockWorker:gate];NSUInteger previous=s.imdbIndex.calls;__block NSUInteger first=0,second=0;
    [s relatedTitles:anchor done:^(NSArray *items){CHECK(!items.count);first++;}];[s relatedTitles:Title(@"replacement") done:^(NSArray *items){CHECK(items.count==12);second++;}];dispatch_semaphore_signal(gate);CHECK(Until(^BOOL{return first&&second;}));CHECK(s.imdbIndex.calls==previous+1);
    // Cancellation after ratings starts cannot publish an obsolete result.
    s.imdbIndex.held=YES;completed=0;[s relatedTitles:anchor done:^(NSArray *items){CHECK(!items.count);completed++;}];CHECK(Until(^BOOL{return s.imdbIndex.pending.count==1;}));[s cancelRelatedTitles];[s.imdbIndex releaseAll];CHECK(Until(^BOOL{return completed==1;}));
    // Profile, age, quality, preference and hidden changes invalidate snapshots.
    for(int mode=0;mode<5;mode++){s=Store();s.imdbIndex.held=YES;completed=0;[s enrichDiscoveryItems:s.input[@"groups"][0] done:^(NSArray *items){CHECK(!items.count);completed++;}];CHECK(Until(^BOOL{return s.imdbIndex.pending.count==1;}));NSMutableDictionary *p=s.state[@"profiles"][@"main"];
        if(mode==0)s.state[@"activeProfile"]=@"other";if(mode==1)p[@"maxAge"]=@7;if(mode==2)s.quality=720;if(mode==3)p[@"discoveryPreferences"]=@{@"worldCinema":@NO};if(mode==4)p[@"hidden"]=@[@"title-0"];
        [s.imdbIndex releaseAll];CHECK(Until(^BOOL{return completed==1;}));CHECK(!s.lastReport);[s drain];}
    // Fresh Kids results still enforce the current rating, including a rating
    // update that arrives after the request snapshot but before delivery.
    s=Store();s.imdbIndex.held=YES;s.state[@"profiles"][@"main"][@"maxAge"]=@7;NSMutableDictionary *child=Title(@"child");child[@"genres"]=@[@"Family"];s.input[@"groups"]=@[@[child]];s.input[@"ageRatings"]=@{@"cache":@{@"child":@{@"minimumAge":@0}}};completed=0;
    [s enrichDiscoveryItems:@[child] done:^(NSArray *items){CHECK(!items.count);completed++;}];CHECK(Until(^BOOL{return s.imdbIndex.pending.count==1;}));s.input[@"ageRatings"]=@{@"cache":@{@"child":@{@"minimumAge":@12}}};[s.imdbIndex releaseAll];CHECK(Until(^BOOL{return completed==1;}));
    CHECK(MainAccess);[s cancelRelatedTitles];[s drain];printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
