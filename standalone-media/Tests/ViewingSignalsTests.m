#import "../RWViewingSignals.h"
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    NSDictionary *metrics=@{@"session_id":@"a",@"playing_seconds_estimate":@5};
    NSMutableDictionary *r=[[RWViewingSignals merge:nil metrics:metrics duration:7200]mutableCopy];r[@"duration"]=@7200;r[@"position"]=@7195;r[@"completed"]=@YES;
    CHECK(![RWViewingSignals meaningful:r]);CHECK(![RWViewingSignals finished:r]);
    CHECK([[RWViewingSignals merge:r metrics:metrics duration:7200][@"watchSeconds"]doubleValue]==5);
    NSDictionary *later=@{@"session_id":@"a",@"playing_seconds_estimate":@310};
    [r addEntriesFromDictionary:[RWViewingSignals merge:r metrics:later duration:7200]];
    CHECK([r[@"watchSeconds"]doubleValue]==310);CHECK([RWViewingSignals meaningful:r]);CHECK(![RWViewingSignals finished:r]);
    CHECK([[RWViewingSignals merge:r metrics:@{@"session_id":@"a",@"playing_seconds_estimate":@300} duration:7200][@"watchSeconds"]doubleValue]==310);
    CHECK([[RWViewingSignals merge:r metrics:@{@"session_id":@"b",@"playing_seconds_estimate":@30} duration:7200][@"watchSeconds"]doubleValue]==340);
    CHECK(![RWViewingSignals meaningful:@{@"position":@7200,@"duration":@7200,@"completed":@YES}]);
    CHECK(![RWViewingSignals meaningful:@{@"watchSeconds":@400,@"duration":@7200}]);
    CHECK([RWViewingSignals finished:@{@"watchSeconds":@5500,@"duration":@7200,@"completed":@YES,@"watchSignalVersion":@1}]);
    CHECK(![RWViewingSignals finished:@{@"watchSeconds":@5500,@"duration":@7200,@"completed":@NO,@"watchSignalVersion":@1}]);
    CHECK([RWViewingSignals meaningful:@{@"watchSeconds":@45,@"duration":@120,@"watchSignalVersion":@1}]);
    CHECK([[RWViewingSignals merge:nil metrics:@{} duration:0]count]==0);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
