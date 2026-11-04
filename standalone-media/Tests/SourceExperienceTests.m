#import "../RWSourceExperience.h"
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(x) do{checks++;if(!(x)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    NSDictionary *s=@{@"infoHash":@"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",@"fileIdx":@2,@"measured_bytes_per_second":@200000,@"video_bytes":@1000000,@"tap_to_advancing_seconds":@4};
    NSMutableDictionary *other=[s mutableCopy];other[@"fileIdx"]=@3;
    CHECK(![[RWSourceExperience keyForSource:s]isEqual:[RWSourceExperience keyForSource:other]]);
    CHECK(![RWSourceExperience keyForSource:@{@"infoHash":@"bad"}]);
    NSDictionary *r=[RWSourceExperience record:nil source:s success:YES now:100];
    CHECK([[RWSourceExperience hints:r now:120][@"localSuccess"]boolValue]);
    CHECK([RWSourceExperience hints:r now:120][@"previousSourceObservation"]!=nil);
    CHECK([RWSourceExperience hints:r now:2000][@"previousSourceObservation"]==nil);
    CHECK(![[RWSourceExperience hints:r now:22000][@"localSuccess"]boolValue]);
    CHECK(![[RWSourceExperience hints:r now:90][@"localSuccess"]boolValue]);
    other=[s mutableCopy];other[@"metadata"]=@NO;other[@"reason"]=@"No usable startup data";
    r=[RWSourceExperience record:r source:other success:NO now:150];
    CHECK([[RWSourceExperience hints:r now:160][@"localFailure"]boolValue]);
    CHECK(![[RWSourceExperience hints:r now:160][@"localSuccess"]boolValue]);
    CHECK(![[RWSourceExperience hints:r now:241][@"localFailure"]boolValue]);
    other[@"reason"]=@"This codec is unsupported";r=[RWSourceExperience record:nil source:other success:NO now:150];
    CHECK([[RWSourceExperience hints:r now:86400][@"localFailure"]boolValue]);
    CHECK(![[RWSourceExperience hints:r now:8*86400][@"localFailure"]boolValue]);
    other[@"reason"]=@"Not enough free space";r=[RWSourceExperience record:nil source:other success:NO now:150];
    CHECK(![[RWSourceExperience hints:r now:160][@"localFailure"]boolValue]);
    other[@"reason"]=@"Measured transfer is too slow";r=[RWSourceExperience record:nil source:other success:NO now:150];
    CHECK([[RWSourceExperience hints:r now:400][@"localFailure"]boolValue]);
    CHECK(![[RWSourceExperience hints:r now:451][@"localFailure"]boolValue]);
    for(int i=0;i<20;i++)r=[RWSourceExperience record:r source:s success:YES now:500+i];
    CHECK([r[@"samples"]count]==6&&[r[@"success_count"]intValue]==20&&!r[@"failure"]);
    NSMutableDictionary *history=[NSMutableDictionary new];for(int i=0;i<150;i++)history[@(i).stringValue]=@{@"updated":@(i)};
    [RWSourceExperience trim:history];CHECK(history.count==128&&!history[@"0"]&&history[@"149"]);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
