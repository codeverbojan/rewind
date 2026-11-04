#import "../RWLocalCatalog.h"
#import "../RWDiscoveryEpisodes.h"
#import "../RWEpisodeCatalog.h"
int main(){@autoreleasepool{__block int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    NSString *root=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString],*docs=[root stringByAppendingPathComponent:@"Documents"],*resources=[root stringByAppendingPathComponent:@"Resources"];
    for(NSString *folder in @[docs,resources])[NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    void(^write)(NSString *,id)=^(NSString *path,id value){[[NSJSONSerialization dataWithJSONObject:value options:0 error:nil]writeToFile:path atomically:YES];};
    write([resources stringByAppendingPathComponent:@"catalog.json"],@{@"movie":@[@{@"id":@"seed"}]});
    write([docs stringByAppendingPathComponent:@"rewind-catalog.json"],@{@"movie":@[@{@"id":@"cached"}]});
    write([resources stringByAppendingPathComponent:@"current-catalog.json"],@{@"movie":@[@{@"id":@"fallback"}]});
    [@"corrupt" writeToFile:[docs stringByAppendingPathComponent:@"rewind-current-catalog.json"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    write([docs stringByAppendingPathComponent:@"rewind-state.json"],@{@"activeProfile":@"kids"});
    write([docs stringByAppendingPathComponent:@"discovery-home.json"],@{@"profiles":@{@"kids":@{@"page":@{@"rows":@[]}}}});
    write([docs stringByAppendingPathComponent:@"rewind-series.json"],@{@"show":@{@"videos":@[@{@"id":@"show:1:1"}]} ,@"tt1":@{@"id":@"tt1",@"videos":@[@{@"id":@"tt1:1:1",@"season":@1,@"episode":@1,@"released":@"2000-01-01"}]}});
    RWEpisodeCatalog *catalog=[[RWEpisodeCatalog alloc]initWithSnapshot:@{} now:NSDate.date.timeIntervalSince1970];[catalog accept:@{@"id":@"tt2",@"type":@"series",@"videos":@[@{@"id":@"tt2:1:1",@"season":@1,@"episode":@1,@"released":@"2000-01-01"}]} now:NSDate.date.timeIntervalSince1970];
    write([docs stringByAppendingPathComponent:@"rewind-episode-catalog.json"],catalog.snapshot);
    NSData *state=[NSData dataWithContentsOfFile:[docs stringByAppendingPathComponent:@"rewind-state.json"]];__block BOOL done=NO;
    [RWLocalCatalog loadDocuments:docs resources:resources done:^(NSDictionary *result){
        CHECK(NSThread.isMainThread);CHECK([result[@"episodeCatalog"]isKindOfClass:RWEpisodeCatalog.class]);CHECK([result[@"episodeCatalog"]show:@"tt2" now:NSDate.date.timeIntervalSince1970]);CHECK(![result[@"episodeCatalog"]show:@"tt1" now:NSDate.date.timeIntervalSince1970]);CHECK([result[@"metrics"][@"off_main"]boolValue]);
        CHECK([result[@"catalog"][@"movie"][0][@"id"]isEqual:@"cached"]);CHECK([result[@"fresh"][@"movie"][0][@"id"]isEqual:@"fallback"]);
        CHECK([result[@"shows"][@"show"][@"videos"]count]==1);CHECK(result[@"home"][@"profiles"][@"kids"]!=nil);
        RWDiscoveryEpisodes *first=[RWDiscoveryEpisodes new],*second=[RWDiscoveryEpisodes new];NSDictionary *show=result[@"shows"][@"tt1"];CHECK(show!=nil);
        [first episode:nil show:show history:@{} now:NSDate.date];[second episode:nil show:show history:@{} now:NSDate.date];CHECK([second.diagnostics[@"index_hits"]intValue]==1);CHECK([second.diagnostics[@"owned_inputs"]intValue]==1);
        CHECK(!result[@"state"]);CHECK(![result[@"metadata"]count]);CHECK([result[@"metrics"][@"bytes"]integerValue]>0);done=YES;
    }];
    CHECK(!done);NSDate *limit=[NSDate dateWithTimeIntervalSinceNow:5];while(!done&&limit.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    CHECK(done);CHECK([state isEqual:[NSData dataWithContentsOfFile:[docs stringByAppendingPathComponent:@"rewind-state.json"]]]);
    [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
