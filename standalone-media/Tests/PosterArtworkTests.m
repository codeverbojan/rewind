#import <Foundation/Foundation.h>
// Real scheduling/cancellation code with deterministic time delivery. This
// proves ownership and request counts, not UIKit geometry or fling smoothness.
static NSMutableArray *Scheduled;
static void TestAfter(dispatch_time_t when,dispatch_queue_t queue,dispatch_block_t block){[Scheduled addObject:[block copy]];}
static void Drain(void){NSArray *tasks=[Scheduled copy];[Scheduled removeAllObjects];for(dispatch_block_t task in tasks)task();}
@interface ArtView:NSObject
@property(strong) id image;
@property BOOL hidden;
@end
@implementation ArtView @end
@interface RewindStore:NSObject
@property NSUInteger requests,cancellations;
@property(copy) void(^completion)(BOOL);
+ (instancetype)shared;
- (void)cancelArtwork:(ArtView *)view;
- (void)artwork:(NSArray *)urls role:(NSString *)role identity:(NSString *)identity into:(ArtView *)view completion:(void(^)(BOOL))completion;
@end
@implementation RewindStore
+ (instancetype)shared{static RewindStore *store;if(!store)store=[self new];return store;}
- (void)cancelArtwork:(ArtView *)view{self.cancellations++;}
- (void)artwork:(NSArray *)urls role:(NSString *)role identity:(NSString *)identity into:(ArtView *)view completion:(void(^)(BOOL))completion{self.requests++;self.completion=completion;}
@end
static NSString *RWID(NSDictionary *meta){return meta[@"id"];}
@interface RWPoster:NSObject {
@public ArtView *_art,*_placeholder,*_fallbackIcon;NSArray *_artURLs;BOOL _artRequested,_artScheduled,_artComplete,_landscape;NSUInteger _artAttempts,_artGeneration;double _retryAfter;
}
@property(strong) NSDictionary *meta;
@property BOOL visible,moving,defersContents,contentsPrepared;
@property NSUInteger contentBuilds;
- (void)prepareContents;
- (BOOL)artworkVisible;
- (BOOL)artworkMoving;
- (void)cancelArtwork;
- (void)loadArtwork;
- (void)loadArtworkIfVisible;
@end
@implementation RWPoster
- (instancetype)init{if((self=[super init])){_art=[ArtView new];_placeholder=[ArtView new];_fallbackIcon=[ArtView new];_artURLs=@[@"asset:poster.jpg"];self.meta=@{@"id":@"first"};}return self;}
- (void)prepareContents{if(!self.contentsPrepared){self.contentsPrepared=YES;self.contentBuilds++;}}
- (BOOL)artworkVisible{return self.visible;}
- (BOOL)artworkMoving{return self.moving;}
#define dispatch_after TestAfter
#include "../RWPosterArtwork.inc"
#undef dispatch_after
@end
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line%d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
int main(){@autoreleasepool{
    Scheduled=[NSMutableArray new];RewindStore *s=[RewindStore shared];RWPoster *p=[RWPoster new];
    [p loadArtworkIfVisible];CHECK(s.requests==0&&Scheduled.count==0);
    p.visible=YES;[p loadArtworkIfVisible];CHECK(s.requests==1&&Scheduled.count==0&&p->_placeholder.hidden);
    for(int i=0;i<100;i++)[p loadArtworkIfVisible];CHECK(s.requests==1);
    p->_art.image=@"complete";s.completion(YES);[p cancelArtwork];[p loadArtworkIfVisible];CHECK(s.requests==1&&p->_artComplete);
    // Reuse as another title while scrolling; repeated viewport notifications
    // enqueue at most one delayed request for this binding.
    [p cancelArtwork];p->_art.image=nil;p->_artComplete=NO;p.moving=YES;
    for(int i=0;i<100;i++)[p loadArtworkIfVisible];CHECK(s.requests==1&&Scheduled.count==1);
    p.visible=NO;Drain();CHECK(s.requests==1&&!p->_artScheduled);
    p.visible=YES;[p loadArtworkIfVisible];Drain();CHECK(s.requests==2&&Scheduled.count==0);
    void(^stale)(BOOL)=[s.completion copy];[p cancelArtwork];p->_artComplete=NO;stale(YES);CHECK(!p->_artComplete);
    [p loadArtworkIfVisible];CHECK(Scheduled.count==1);[p cancelArtwork];Drain();CHECK(s.requests==2&&!p->_artScheduled);
    p.moving=NO;[p loadArtworkIfVisible];CHECK(s.requests==3);
    s.completion(NO);CHECK(!p->_artRequested&&!p->_placeholder.hidden&&!p->_fallbackIcon.hidden&&Scheduled.count==1);
    [p loadArtworkIfVisible];CHECK(s.requests==3);[p cancelArtwork];Drain();CHECK(s.requests==3&&Scheduled.count==0);
    p->_retryAfter=0;[p loadArtworkIfVisible];CHECK(s.requests==4);
    // A pending dwell block holds only a weak view; a discarded card is freed.
    __weak RWPoster *released;@autoreleasepool{RWPoster *q=[RWPoster new];q.visible=YES;q.moving=YES;released=q;[q loadArtworkIfVisible];}CHECK(released==nil);Drain();CHECK(s.requests==4);
    RWPoster *deferred=[RWPoster new];deferred.visible=YES;deferred.defersContents=YES;
    for(int i=0;i<100;i++)[deferred loadArtworkIfVisible];CHECK(!deferred.contentsPrepared&&deferred.contentBuilds==0&&s.requests==4&&Scheduled.count==0);
    [deferred prepareContents];[deferred loadArtworkIfVisible];CHECK(deferred.contentBuilds==1&&s.requests==5);
    for(int i=0;i<100;i++)[deferred loadArtworkIfVisible];CHECK(deferred.contentBuilds==1&&s.requests==5);
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
