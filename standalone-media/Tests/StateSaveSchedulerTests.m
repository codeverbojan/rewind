#import "../RWStateSaveScheduler.h"
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
static void Wait(double seconds){NSDate *until=[NSDate dateWithTimeIntervalSinceNow:seconds];while(until.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];}
int main(){@autoreleasepool{
    __block int writes=0,current=0,saved=0;RWStateSaveScheduler *scheduler=[[RWStateSaveScheduler alloc]initWithPersist:^{CHECK(NSThread.isMainThread);writes++;saved=current;}];
    // A network burst is one current-state capture, not 200 old snapshots.
    for(int i=0;i<200;i++){current=i;[scheduler requestDeferred:YES];}CHECK(writes==0&&scheduler.pending);Wait(1.1);CHECK(writes==1&&saved==199&&!scheduler.pending);
    current=200;[scheduler requestDeferred:YES];CHECK(scheduler.pending);current=201;[scheduler requestDeferred:NO];CHECK(writes==2&&saved==201&&!scheduler.pending);
    // The old timer must not fire after a user edit or app-closing flush.
    Wait(1.1);CHECK(writes==2);current=202;[scheduler requestDeferred:NO];CHECK(writes==3&&saved==202);
    // Background observations arriving after a flush get their own deadline.
    [scheduler requestDeferred:YES];current=203;Wait(.55);[scheduler requestDeferred:YES];current=204;Wait(.55);CHECK(writes==4&&saved==204&&!scheduler.pending);
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
