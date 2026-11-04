#import "../RWDiscoveryCandidatePolicy.h"
#import "../RWRecommendationSignals.h"
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
@interface CandidateService:NSObject
@property(nonatomic,strong) NSMutableArray *calls,*cancelled;
@property(nonatomic) BOOL paused;
@property(nonatomic) NSUInteger resolved,enqueued;
- (NSDictionary *)enrich:(NSDictionary *)m;
- (void)cancelCreditRequestsForOwner:(NSString *)owner;
- (void)creditPage:(NSString *)entity role:(NSString *)role continuation:(NSDictionary *)cursor owner:(NSString *)owner foreground:(BOOL)foreground done:(void(^)(NSArray *,NSDictionary *,NSString *))done;
- (void)resolve:(NSArray *)items;
- (void)enqueue:(NSArray *)items;
@end
@implementation CandidateService
- (instancetype)init{if((self=[super init])){_calls=[NSMutableArray new];_cancelled=[NSMutableArray new];}return self;}
- (NSDictionary *)enrich:(NSDictionary *)m{return m;}
- (void)cancelCreditRequestsForOwner:(NSString *)owner{if(owner)[self.cancelled addObject:owner];}
- (void)creditPage:(NSString *)entity role:(NSString *)role continuation:(NSDictionary *)cursor owner:(NSString *)owner foreground:(BOOL)foreground done:(void(^)(NSArray *,NSDictionary *,NSString *))done{CHECK(NSThread.isMainThread);[self.calls addObject:@{@"entity":entity,@"role":role,@"continuation":cursor,@"owner":owner,@"foreground":@(foreground),@"done":[done copy]}];}
- (void)resolve:(NSArray *)items{self.resolved+=items.count;}
- (void)enqueue:(NSArray *)items{self.enqueued+=items.count;}
@end
@interface CandidateStore:NSObject{
    NSMutableDictionary *_diagnostics;BOOL _candidateBusy,_discoveryPaused;NSUInteger _candidateGeneration;NSString *_candidateOwner;
}
@property(nonatomic,strong) NSMutableDictionary *state;
@property(nonatomic,strong) NSDictionary *discoveryHome,*reportValue;
@property(nonatomic,strong) CandidateService *discoveryMetadata,*imdbIndex,*ratings;
@property(nonatomic,strong) NSMutableArray *browseCalls,*accepted;
@property(nonatomic) NSUInteger saves;
@property(nonatomic,readonly) NSMutableDictionary *profile;
@property(nonatomic,readonly) BOOL restricted,busy;
- (BOOL)allowed:(NSDictionary *)m;
- (void)save;
- (void)report:(NSDictionary *)r;
- (void)acceptDiscoveryCandidates:(NSArray *)items;
- (void)browse:(NSString *)type sort:(NSString *)sort genre:(NSString *)genre year:(NSInteger)year skip:(NSUInteger)skip foreground:(BOOL)foreground done:(void(^)(id,NSString *))done;
@end
@implementation CandidateStore
- (instancetype)init{if((self=[super init])){_diagnostics=[NSMutableDictionary new];_state=[@{@"activeProfile":@"main",@"profiles":[@{@"main":[@{@"maxAge":@(-1)}mutableCopy],@"kids":[@{@"maxAge":@7}mutableCopy]}mutableCopy]}mutableCopy];_discoveryMetadata=[CandidateService new];_imdbIndex=[CandidateService new];_ratings=[CandidateService new];_browseCalls=[NSMutableArray new];_accepted=[NSMutableArray new];}return self;}
- (NSMutableDictionary *)profile{return self.state[@"profiles"][self.state[@"activeProfile"]];}
- (BOOL)restricted{return [self.profile[@"maxAge"]integerValue]>=0;}
- (BOOL)busy{return _candidateBusy;}
- (BOOL)allowed:(NSDictionary *)m{return !self.restricted||[m[@"ageAllowed"]boolValue];}
- (void)save{self.saves++;}
- (void)saveForReason:(NSString *)reason {[self save];}
- (void)report:(NSDictionary *)r{[_diagnostics addEntriesFromDictionary:r];self.reportValue=[_diagnostics copy];}
- (void)acceptDiscoveryCandidates:(NSArray *)items{[self.accepted addObjectsFromArray:items];}
- (void)browse:(NSString *)type sort:(NSString *)sort genre:(NSString *)genre year:(NSInteger)year skip:(NSUInteger)skip foreground:(BOOL)foreground done:(void(^)(id,NSString *))done{CHECK(NSThread.isMainThread&&!foreground&&skip==0);[self.browseCalls addObject:@{@"type":type,@"genre":genre?:@"",@"done":[done copy]}];}
#include "../RewindDiscoveryCandidates.inc"
@end
static NSDictionary *Title(NSString *key){return @{@"id":key,@"type":@"movie",@"name":key,@"ageAllowed":@YES,@"genres":@[@"Thriller"],@"discovery":@{@"imdb":key,@"entityID":@"Q100",@"source":@"https://www.wikidata.org/wiki/Q100",@"directors":@[@{@"id":@"Q10",@"provider":@"Wikidata"}]}};}
static CandidateStore *Store(void){CandidateStore *s=[CandidateStore new];s.discoveryHome=@{@"interestAnchors":@[Title(@"tt100")]};return s;}
static void Credit(NSDictionary *call,NSArray *items,NSDictionary *next,NSString *error){void(^done)(NSArray *,NSDictionary *,NSString *)=call[@"done"];done(items,next,error);}
static void Browse(NSDictionary *call,NSArray *items,NSString *error){void(^done)(id,NSString *)=call[@"done"];done(items,error);}
int main(){@autoreleasepool{
    CandidateStore *s=Store();[s refreshDiscoveryCandidates];CHECK(s.busy&&s.imdbIndex.paused&&s.discoveryMetadata.calls.count==1);NSDictionary *call=s.discoveryMetadata.calls[0];CHECK([call[@"owner"]isEqual:@"discovery:main"]&&![call[@"foreground"]boolValue]);[s refreshDiscoveryCandidates];CHECK(s.discoveryMetadata.calls.count==1);
    NSMutableDictionary *m=[Title(@"tt200")mutableCopy];m[@"creditRole"]=@"director";m[@"creditEntityID"]=@"Q10";Credit(call,@[m],@{@"sroffset":@8},nil);CHECK(!s.busy&&!s.imdbIndex.paused&&s.accepted.count==1);CHECK(s.discoveryMetadata.enqueued==1&&s.saves==2);CHECK([s.profile[@"discoveryFetch"][@"pages"]count]==1);CHECK([s.reportValue[@"discovery_candidates"][@"kind"]isEqual:@"credits"]);[s refreshDiscoveryCandidates];CHECK(s.discoveryMetadata.calls.count==1);
    // A later profile must not overwrite the first profile's completion proof.
    NSDictionary *regularReceipt=s.reportValue[@"discovery_candidates_by_profile"][@"main"];
    CHECK([regularReceipt[@"entity"]isEqual:@"Q10"]&&[regularReceipt[@"next"][@"sroffset"]isEqual:@8]);
    s.state[@"activeProfile"]=@"kids";[s refreshDiscoveryCandidates];Credit(s.discoveryMetadata.calls.lastObject,@[],@{},@"offline");
    CHECK([s.reportValue[@"discovery_candidates_by_profile"][@"main"]isEqual:regularReceipt]);
    CHECK([s.reportValue[@"discovery_candidates_by_profile"][@"kids"][@"failed"]boolValue]);
    // Cancellation resets busy immediately. A prior profile cannot finish a new job.
    s=Store();[s refreshDiscoveryCandidates];call=s.discoveryMetadata.calls[0];[s cancelDiscoveryCandidates];CHECK(!s.busy&&[s.discoveryMetadata.cancelled.lastObject isEqual:@"discovery:main"]);s.state[@"activeProfile"]=@"kids";[s refreshDiscoveryCandidates];CHECK(s.busy&&s.discoveryMetadata.calls.count==2);Credit(call,@[m],@{},nil);CHECK(s.busy&&s.accepted.count==0&&s.imdbIndex.paused);Credit(s.discoveryMetadata.calls[1],@[m],@{},nil);CHECK(!s.busy&&s.accepted.count==1&&s.ratings.resolved==1);
    // Scope changes without changing the profile ID also discard late acceptance.
    for(NSString *field in @[@"maxAge",@"hidden",@"discoveryPreferences"]){s=Store();[s refreshDiscoveryCandidates];s.profile[field]=[field isEqual:@"maxAge"]?@7:[field isEqual:@"hidden"]?@[@"tt200"]:@{@"languageMode":@"all"};Credit(s.discoveryMetadata.calls[0],@[m],@{},nil);CHECK(!s.busy&&!s.imdbIndex.paused&&!s.accepted.count);}
    // Catalog callbacks use the same generation guard and background lane.
    s=Store();s.profile[@"discoveryFetch"]=@{@"turn":@1};[s refreshDiscoveryCandidates];CHECK(s.browseCalls.count==1&&s.discoveryMetadata.calls.count==0);NSDictionary *old=s.browseCalls[0];[s cancelDiscoveryCandidates];s.state[@"activeProfile"]=@"kids";[s refreshDiscoveryCandidates];Browse(old,@[Title(@"tt300")],nil);CHECK(s.busy&&s.accepted.count==0);Credit(s.discoveryMetadata.calls[0],@[],@{},@"offline");CHECK(!s.busy&&!s.accepted.count);CHECK([s.reportValue[@"discovery_candidates"][@"failed"]boolValue]);
    // No anchors falls back to alternating family catalog, without leaking adult seed.
    s=Store();s.state[@"activeProfile"]=@"kids";NSMutableDictionary *adult=[Title(@"tt400")mutableCopy];adult[@"ageAllowed"]=@NO;s.discoveryHome=@{@"interestAnchors":@[adult]};[s refreshDiscoveryCandidates];CHECK(s.browseCalls.count==1&&[s.browseCalls[0][@"genre"]isEqual:@"Family"]);Browse(s.browseCalls[0],nil,@"offline");CHECK(!s.busy&&!s.accepted.count);
    // Existing likes can seed discovery before a Home interest model is published.
    s=Store();s.discoveryHome=@{};s.profile[@"liked"]=@[Title(@"tt500")];[s refreshDiscoveryCandidates];CHECK(s.discoveryMetadata.calls.count==1);[s cancelDiscoveryCandidates];
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
