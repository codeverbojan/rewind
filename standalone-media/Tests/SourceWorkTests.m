#import <Foundation/Foundation.h>
#import "../RWSourceWork.h"
static int checks,failures;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
static BOOL Wait(BOOL(^done)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:3];while(!done()&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];return done();}
int main(){@autoreleasepool{
    NSMutableString *name=[@"Original" mutableCopy];NSMutableArray *children=[NSMutableArray arrayWithObject:name];NSMutableDictionary *input=[@{@"children":children}mutableCopy];
    NSDictionary *snapshot=[RWSourceWork snapshot:input];[name setString:@"Changed"];[children removeAllObjects];[input removeAllObjects];
    CHECK([snapshot[@"children"]isEqual:@[@"Original"]]);CHECK(![snapshot isKindOfClass:NSMutableDictionary.class]);CHECK(![snapshot[@"children"]isKindOfClass:NSMutableArray.class]);
    CHECK(![RWSourceWork snapshot:[NSDate date]]);CHECK(![RWSourceWork snapshot:@{@1:@"value"}]);
    id deep=@1;for(int i=0;i<40;i++)deep=@[deep];CHECK(![RWSourceWork snapshot:deep]);
    NSMutableArray *oversized=[NSMutableArray new];for(int i=0;i<200001;i++)[oversized addObject:@1];CHECK(![RWSourceWork snapshot:oversized]);
    RWSourceWork *queue=[RWSourceWork new];dispatch_semaphore_t gate=dispatch_semaphore_create(0);
    __block NSUInteger callbacks=0,mainTasks=0;NSMutableArray *order=[NSMutableArray new];__block BOOL valid=YES;
    [queue submitForeground:NO valid:^BOOL{CHECK(NSThread.isMainThread);return YES;} task:^id{if(NSThread.isMainThread)mainTasks++;dispatch_semaphore_wait(gate,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC));return @"active";} done:^(id value,NSString *error){CHECK(NSThread.isMainThread&&!error);callbacks++;[order addObject:value];}];
    [queue submitForeground:NO valid:^BOOL{CHECK(NSThread.isMainThread);return YES;} task:^id{if(NSThread.isMainThread)mainTasks++;return @"background";} done:^(id value,NSString *error){CHECK(NSThread.isMainThread&&!error);callbacks++;[order addObject:value];}];
    [queue submitForeground:YES valid:^BOOL{CHECK(NSThread.isMainThread);return YES;} task:^id{if(NSThread.isMainThread)mainTasks++;return @"foreground";} done:^(id value,NSString *error){CHECK(NSThread.isMainThread&&!error);callbacks++;[order addObject:value];}];
    [queue submitForeground:NO valid:^BOOL{CHECK(NSThread.isMainThread);return valid;} task:^id{return @"must not run";} done:^(id value,NSString *error){CHECK(NSThread.isMainThread&&!value&&error.length);callbacks++;}];
    valid=NO;dispatch_semaphore_signal(gate);CHECK(Wait(^BOOL{return callbacks==4;}));
    CHECK([order isEqual:@[@"active",@"foreground",@"background"]]);CHECK(mainTasks==0);CHECK([queue.diagnostics[@"skipped"]intValue]==1);
    // A cancellation after computation starts must suppress its late output.
    dispatch_semaphore_t lateGate=dispatch_semaphore_create(0);__block BOOL lateValid=YES,lateDone=NO;
    [queue submitForeground:YES valid:^BOOL{return lateValid;} task:^id{dispatch_semaphore_wait(lateGate,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC));return @"late";} done:^(id value,NSString *error){CHECK(!value&&error.length&&NSThread.isMainThread);lateDone=YES;}];
    lateValid=NO;dispatch_semaphore_signal(lateGate);CHECK(Wait(^BOOL{return lateDone;}));
    // One active job +15 waiting is the entire capacity, including failed jobs.
    RWSourceWork *bounded=[RWSourceWork new];dispatch_semaphore_t capacityGate=dispatch_semaphore_create(0);__block NSUInteger finished=0,rejected=0;
    [bounded submitForeground:NO valid:^BOOL{return YES;} task:^id{dispatch_semaphore_wait(capacityGate,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC));return @1;} done:^(id value,NSString *error){finished++;}];
    for(NSUInteger i=0;i<20;i++)[bounded submitForeground:NO valid:^BOOL{return YES;} task:^id{return @1;} done:^(id value,NSString *error){if(error)rejected++;finished++;}];
    CHECK(rejected==5&&[bounded.diagnostics[@"peak"]intValue]==16);CHECK([bounded.diagnostics[@"pending"]intValue]==15);
    dispatch_semaphore_signal(capacityGate);CHECK(Wait(^BOOL{return finished==21;}));CHECK(![bounded.diagnostics[@"active"]boolValue]&&[bounded.diagnostics[@"pending"]intValue]==0);
    __block BOOL nilDone=NO;[bounded submitForeground:YES valid:^BOOL{return YES;} task:^id{return nil;} done:^(id value,NSString *error){CHECK(!value&&error.length);nilDone=YES;}];CHECK(Wait(^BOOL{return nilDone;}));
    CHECK([bounded.diagnostics[@"main_tasks"]intValue]==0);CHECK([bounded.diagnostics[@"completed"]intValue]==17);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
