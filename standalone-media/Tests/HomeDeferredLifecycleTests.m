#import <Foundation/Foundation.h>
#include <float.h>
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSString *RWID(NSDictionary *m){return m[@"id"]?:@"";}
enum {UIApplicationStateActive,UIApplicationStateInactive};
@interface UIApplication:NSObject
@property NSInteger applicationState;
+ (instancetype)sharedApplication;
@end
@implementation UIApplication
+ (instancetype)sharedApplication {static UIApplication *a;if(!a)a=[self new];return a;}
@end
@interface ValidationStub:NSObject
@property(nonatomic,strong) NSSet *ready;
- (NSDictionary *)entryForTitle:(NSDictionary *)title now:(double)now;
- (NSDictionary *)diagnostics;
@end
@implementation ValidationStub
- (NSDictionary *)entryForTitle:(NSDictionary *)title now:(double)now{return [self.ready containsObject:RWID(title)]?@{@"meta":title}:nil;}
- (NSDictionary *)diagnostics{return @{};}
@end
@interface RewindStore:NSObject
@property(nonatomic,strong) NSMutableDictionary *state;
@property(nonatomic,strong) ValidationStub *validation;
@property(nonatomic,strong) NSDictionary *lastFallback;
@property NSUInteger validationCalls;
@property(nonatomic,copy) void(^completion)(NSDictionary *);
@property NSUInteger submitted;
@property(nonatomic,strong) NSSet *requested;
@property(nonatomic,strong) NSDictionary *previous;
+ (instancetype)shared;
- (ValidationStub *)homeValidationWithFallback:(NSDictionary *)prepared;
- (void)prepareHomeMetadata:(NSDictionary *)home requestedIDs:(NSSet *)requested previous:(NSDictionary *)previous done:(void(^)(NSDictionary *))done;
- (void)report:(NSDictionary *)value;
@end
@implementation RewindStore
+ (instancetype)shared {static RewindStore *s;if(!s){s=[self new];s.state=[@{@"activeProfile":@"main"}mutableCopy];}return s;}
- (ValidationStub *)homeValidationWithFallback:(NSDictionary *)prepared{self.validationCalls++;self.lastFallback=prepared;return self.validation;}
- (void)prepareHomeMetadata:(NSDictionary *)home requestedIDs:(NSSet *)requested previous:(NSDictionary *)previous done:(void(^)(NSDictionary *))done{self.submitted++;self.requested=requested;self.previous=previous;self.completion=done;}
- (void)report:(NSDictionary *)value{}
@end
@interface Home:NSObject
@property BOOL interacting;
@property(nonatomic,strong) id window;
@property(nonatomic,strong) NSSet *ids;
- (NSSet *)preparationIDs;
- (BOOL)isInteracting;
@end
@implementation Home
- (NSSet *)preparationIDs{return self.ids?:[NSSet set];}
- (BOOL)isInteracting{return self.interacting;}
@end
@interface RewindController:NSObject
@property(nonatomic,strong) NSDictionary *homeDeferredBatch,*homePlan;
@property(nonatomic,strong) ValidationStub *homeValidation;
@property(nonatomic,copy) NSString *homeDeferredProfile,*page;
@property(nonatomic,strong) Home *homeView;
@property(nonatomic,strong) id presentedViewController;
@property BOOL homeDeferredNeeded,homeDeferredBusy,reviewMode;
@property double discoveryMemoryCooldown;
@property NSUInteger updates;
- (void)updateHomeList;
- (void)beginHomePreparationPass;
- (void)finishHomePreparationPass;
- (void)applyPreparedHome;
@end
@implementation RewindController
- (void)updateHomeList{self.updates++;}
#include "../RewindHomeDeferred.inc"
@end
int main(){@autoreleasepool{
    RewindStore *s=RewindStore.shared;RewindController *c=[RewindController new];c.page=@"Home";c.homeView=[Home new];c.homePlan=@{@"hero":@{@"id":@"hero"},@"rows":@[@{@"items":@[@{@"id":@"visible"},@{@"id":@"hidden"}]}]};c.homeView.ids=[NSSet setWithObject:@"visible"];
    s.validation=[ValidationStub new];c.homeDeferredBatch=@{@"marker":@1};c.homeDeferredProfile=@"main";
    [c beginHomePreparationPass];CHECK(c.homeValidation==s.validation);CHECK(s.lastFallback==c.homeDeferredBatch);CHECK(s.validationCalls==1);CHECK(!c.homeDeferredNeeded);
    c.homeDeferredNeeded=YES;[c finishHomePreparationPass];CHECK(s.submitted==1&&c.homeDeferredBusy&&!c.homeValidation);CHECK([s.requested isEqual:[NSSet setWithArray:@[@"hero",@"visible"]]]);CHECK(s.previous==c.homeDeferredBatch);[c finishHomePreparationPass];CHECK(s.submitted==1);
    void(^reply)(NSDictionary *)=s.completion;s.completion=nil;reply(@{@"entries":@{}});CHECK(!c.homeDeferredBusy&&c.homeDeferredBatch&&c.updates==1);
    c.homeDeferredNeeded=YES;[c finishHomePreparationPass];s.state[@"activeProfile"]=@"kids";[c beginHomePreparationPass];CHECK(!c.homeDeferredBatch&&[c.homeDeferredProfile isEqual:@"kids"]);
    reply=s.completion;s.completion=nil;reply(@{@"entries":@{@"adult":@1}});CHECK(!c.homeDeferredBatch&&!c.homeDeferredBusy&&c.updates==2);
    c.homeDeferredNeeded=YES;[c finishHomePreparationPass];c.page=@"Search";reply=s.completion;s.completion=nil;reply(@{@"entries":@{}});CHECK(!c.homeDeferredBusy&&c.updates==2);CHECK(c.homeDeferredBatch);
    NSUInteger count=s.submitted;c.homeDeferredNeeded=YES;[c finishHomePreparationPass];CHECK(s.submitted==count);c.page=@"Home";
    c.discoveryMemoryCooldown=NSProcessInfo.processInfo.systemUptime+30;[c finishHomePreparationPass];CHECK(s.submitted==count);c.discoveryMemoryCooldown=0;
    c.reviewMode=YES;[c finishHomePreparationPass];CHECK(s.submitted==count);c.reviewMode=NO;
    c.presentedViewController=[NSObject new];[c applyPreparedHome];CHECK(c.updates==2);c.presentedViewController=nil;
    UIApplication.sharedApplication.applicationState=UIApplicationStateInactive;[c applyPreparedHome];CHECK(c.updates==2);UIApplication.sharedApplication.applicationState=UIApplicationStateActive;
    c.homeView.interacting=YES;[c applyPreparedHome];CHECK(c.updates==2);[NSObject cancelPreviousPerformRequestsWithTarget:c];c.homeView.interacting=NO;[c applyPreparedHome];CHECK(c.updates==3);
    c.homeDeferredNeeded=YES;[c finishHomePreparationPass];c.discoveryMemoryCooldown=NSProcessInfo.processInfo.systemUptime+30;c.homeDeferredBatch=nil;reply=s.completion;s.completion=nil;reply(@{@"entries":@{}});CHECK(!c.homeDeferredBatch&&!c.homeDeferredBusy&&c.updates==3);
    c.discoveryMemoryCooldown=0;c.homeDeferredNeeded=YES;[c finishHomePreparationPass];__weak RewindController *weak=c;c=nil;CHECK(!weak);reply=s.completion;s.completion=nil;reply(@{});CHECK(!weak);
    c=[RewindController new];c.page=@"Home";c.homeView=[Home new];c.homeView.window=[NSObject new];c.homeView.ids=[NSSet setWithObject:@"visible"];c.homePlan=@{@"hero":@{@"id":@"hero"},@"rows":@[@{@"items":@[@{@"id":@"visible"},@{@"id":@"hidden"}]}]};
    s.validation.ready=[NSSet setWithArray:@[@"hero",@"visible"]];count=s.submitted;[c prepareHomeViewport];CHECK(s.submitted==count);CHECK(!c.homeValidation);
    c.homeView.ids=[NSSet setWithObject:@"hidden"];[c prepareHomeViewport];CHECK(s.submitted==count+1&&[s.requested isEqual:[NSSet setWithObject:@"hidden"]]);
    reply=s.completion;s.completion=nil;reply(@{@"entries":@{}});count=s.submitted;
    c.homeView.window=nil;[c prepareHomeViewport];CHECK(s.submitted==count);c.homeView.window=[NSObject new];
    UIApplication.sharedApplication.applicationState=UIApplicationStateInactive;[c prepareHomeViewport];CHECK(s.submitted==count);UIApplication.sharedApplication.applicationState=UIApplicationStateActive;
    c.presentedViewController=[NSObject new];[c prepareHomeViewport];CHECK(s.submitted==count);c.presentedViewController=nil;
    [c scheduleHomeViewportPreparation];[c scheduleHomeViewportPreparation];[NSObject cancelPreviousPerformRequestsWithTarget:c];
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
