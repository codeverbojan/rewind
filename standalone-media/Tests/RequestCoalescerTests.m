#import <Foundation/Foundation.h>
#import "../RWRequestCoalescer.h"
int main(){@autoreleasepool{
    __block int checks=0,failures=0;
    void(^check)(BOOL,NSString *)=^(BOOL pass,NSString *message){checks++;if(!pass){failures++;fprintf(stderr,"FAIL: %s\n",message.UTF8String);}};
    RWRequestCoalescer *pool=[RWRequestCoalescer new];__block RWLookupResult pending=nil;__block int starts=0,callbacks=0;
    void(^start)(RWLookupResult)=^(RWLookupResult finish){starts++;pending=[finish copy];};
    RWLookupResult done=^(id value,NSString *error){callbacks++;check([value isEqual:@"movie"]&&!error,@"Each joined caller receives the same result");};
    [pool perform:@"movie:one" start:start done:done];[pool perform:@"movie:one" start:start done:done];
    check(starts==1&&callbacks==0&&pool.joinedCount==1,@"Details prefetch plus immediate Play starts one operation");
    pending(@"movie",nil);check(callbacks==2,@"Both callers complete");pending(@"movie",nil);check(callbacks==2,@"Duplicate supplier completion is ignored");
    [pool perform:@"movie:one" start:start done:^(id value,NSString *error){callbacks++;check(error!=nil,@"Errors reach waiting callers");}];
    check(starts==2,@"Completion releases the key for a subsequent refresh");pending(nil,@"offline");
    __block BOOL retried=NO;
    [pool perform:@"movie:one" start:^(RWLookupResult finish){finish(nil,@"retry");} done:^(id value,NSString *error){
        [pool perform:@"movie:one" start:^(RWLookupResult finish){finish(@"ok",nil);} done:^(id value,NSString *error){retried=[value isEqual:@"ok"];}];
    }];check(retried,@"A failure can synchronously retry without rejoining a completed request");
    NSMutableArray *completions=[NSMutableArray new];__block int independent=0;
    for(NSString *key in @[@"main:series:one",@"kids:series:one",@"main:series:two"])[pool perform:key start:^(RWLookupResult finish){independent++;[completions addObject:[finish copy]];} done:^(id value,NSString *error){}];
    check(independent==3,@"Different profiles and episodes stay independent");for(RWLookupResult finish in completions)finish(nil,nil);
    [completions removeAllObjects];__block int rejected=0;
    for(int i=0;i<65;i++)[pool perform:[NSString stringWithFormat:@"key:%d",i] start:^(RWLookupResult finish){[completions addObject:[finish copy]];} done:^(id value,NSString *error){if(error)rejected++;}];
    check(completions.count==64&&rejected==1,@"Distinct pending work has a hard bound");for(RWLookupResult finish in completions)finish(nil,nil);
    [pool perform:@"after-limit" start:^(RWLookupResult finish){finish(@YES,nil);} done:^(id value,NSString *error){check([value boolValue]&&!error,@"Capacity is released after completion");}];
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
