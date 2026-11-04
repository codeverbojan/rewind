#import <Foundation/Foundation.h>
// Execute production scheduling with deterministic delivery. UIKit geometry,
// cell construction time and scrolling are measured separately on the iPad.
static NSMutableArray *Pending;
static void After(dispatch_time_t time,dispatch_queue_t queue,dispatch_block_t block){[Pending addObject:[block copy]];}
static void Deliver(void){NSArray *blocks=[Pending copy];[Pending removeAllObjects];for(dispatch_block_t block in blocks)block();}
static NSUInteger InvalidSettles;
@interface RWUIProbe:NSObject
+ (instancetype)shared;
- (void)work:(NSString *)kind started:(double)started;
@end
@implementation RWUIProbe
+ (instancetype)shared {static RWUIProbe *p;static dispatch_once_t once;dispatch_once(&once,^{p=[self new];});return p;}
- (void)work:(NSString *)kind started:(double)started {if(started<=0)InvalidSettles++;}
@end
@interface RWHomeView:NSObject {
@public NSUInteger _contentGeneration;BOOL _contentScheduled;double _contentStarted;
}
@property BOOL visible,active;
@property NSUInteger missing,built;
- (BOOL)canPrepareContent;
- (BOOL)hasPendingVisibleContent;
- (void)prepareNextVisibleContent;
- (void)scheduleContentPreparation;
- (void)cancelContentPreparation;
@end
@implementation RWHomeView
- (BOOL)canPrepareContent{return self.visible&&self.active;}
- (BOOL)hasPendingVisibleContent{return self.missing>0;}
- (void)prepareNextVisibleContent{if(self.missing){self.missing--;self.built++;}}
#define dispatch_after After
#include "../RWHomeContentScheduling.inc"
#undef dispatch_after
@end
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
int main(){@autoreleasepool{
    Pending=[NSMutableArray new];RWHomeView *s=[RWHomeView new];s.active=YES;s.missing=7;
    [s scheduleContentPreparation];CHECK(Pending.count==0&&s.built==0);
    s.visible=YES;for(int i=0;i<100;i++)[s scheduleContentPreparation];CHECK(Pending.count==1&&s.built==0);
    Deliver();CHECK(s.built==1&&s.missing==6&&Pending.count==1);
    for(int i=0;i<6;i++){NSUInteger before=s.built;Deliver();CHECK(s.built==before+1);}
    CHECK(s.built==7&&Pending.count==0&&!s->_contentScheduled);
    [s scheduleContentPreparation];CHECK(Pending.count==1);Deliver();CHECK(Pending.count==0&&s.built==7);
    // Scrolling away or backgrounding before delivery does no view work.
    s.missing=3;[s scheduleContentPreparation];s.visible=NO;Deliver();CHECK(s.built==7&&Pending.count==0);
    s.visible=YES;[s scheduleContentPreparation];s.active=NO;Deliver();CHECK(s.built==7&&Pending.count==0);
    s.active=YES;[s scheduleContentPreparation];[s cancelContentPreparation];Deliver();CHECK(s.built==7&&Pending.count==0&&s->_contentStarted==0);
    // A stale callback cannot clear the scheduled flag or build cells for a
    // new binding/window. New delivery always uses the current visible model.
    [s scheduleContentPreparation];[s cancelContentPreparation];s.missing=1;[s scheduleContentPreparation];
    dispatch_block_t stale=Pending.firstObject;[Pending removeObjectAtIndex:0];stale();CHECK(s->_contentScheduled&&s.built==7);
    Deliver();CHECK(s.built==8&&s.missing==0&&Pending.count==0);
    __weak RWHomeView *released;@autoreleasepool{RWHomeView *temporary=[RWHomeView new];temporary.visible=YES;temporary.active=YES;temporary.missing=9;released=temporary;[temporary scheduleContentPreparation];}
    CHECK(released==nil);Deliver();CHECK(Pending.count==0);
    s.missing=1;[s scheduleContentPreparation];s.missing=0;s->_contentStarted=0;Deliver();CHECK(InvalidSettles==0&&Pending.count==0);
    NSUInteger before=s.built;[s scheduleContentPreparation];CHECK(Pending.count==1);s.missing=1;Deliver();CHECK(s.built==before+1&&Pending.count==0);
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
