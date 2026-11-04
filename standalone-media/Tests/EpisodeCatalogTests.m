#import "../RWEpisodeCatalog.h"
#import "../RWPackedEpisodes.h"
#import "../RWTVPolicy.h"
#import "../RWDiscoveryEpisodes.h"
#import "../RWHomeDeferredPreparation.h"
#import "../RWHomePreparation.h"
#import "../RWAvailability.h"
#import "../RWRecommendationPolicy.h"
static int checks,failures;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSDictionary *Show(int number,int count){NSString *key=[NSString stringWithFormat:@"tt%d",number];NSMutableArray *videos=[NSMutableArray new];for(int i=1;i<=count;i++){int s=(i-1)/1000+1,e=(i-1)%1000+1;[videos addObject:@{@"id":[key stringByAppendingFormat:@":%d:%d",s,e],@"season":@(s),@"episode":@(e),@"released":@"2000-01-01",@"thumbnail":@"https://example.com/unused.jpg",@"overview":@"Not needed for selection"}];}return @{@"id":key,@"type":@"series",@"name":@"Family show",@"genres":@[@"Family"],@"videos":videos};}
static NSDictionary *RoundTrip(NSDictionary *m){return [NSJSONSerialization JSONObjectWithData:[NSJSONSerialization dataWithJSONObject:m options:0 error:nil] options:0 error:nil];}
int main(){@autoreleasepool{
    double now=1792620400;NSDictionary *full=Show(1,3);RWEpisodeCatalog *c=[[RWEpisodeCatalog alloc]initWithSnapshot:nil now:now];
    for(NSString *identifier in @[@"tt0852863",@"tt0369179",@"tt0000001"]){NSDictionary *realID=@{@"id":identifier,@"type":@"series",@"videos":@[@{@"id":[identifier stringByAppendingString:@":1:1"],@"season":@1,@"episode":@1,@"released":@"2000-01-01"}]};CHECK([c accept:realID now:now]);CHECK([c show:identifier now:now]!=nil);}
    CHECK([c accept:full now:now]);NSDictionary *small=[c show:@"tt1" now:now];CHECK([small[@"videos"]count]==3&&small.count==4);CHECK(!small[@"name"]&&!small[@"videos"][0][@"thumbnail"]);CHECK([small[@"videos"][0]count]==4);
    CHECK([c showsByAddingDetails:@{@"tt1":full} now:now][@"tt1"]==full);CHECK([c showsByAddingDetails:@{} now:now][@"tt1"]==small);
    NSDictionary *history=@{@"tt1:1:1":@{@"completed":@YES,@"updated":@(now-2)}};
    CHECK([[[[RWDiscoveryEpisodes alloc]init]episode:nil show:small history:@{} now:[NSDate dateWithTimeIntervalSince1970:now]][@"id"]isEqual:@"tt1:1:1"]);
    CHECK([[[[RWDiscoveryEpisodes alloc]init]episode:nil show:small history:history now:[NSDate dateWithTimeIntervalSince1970:now]][@"id"]isEqual:@"tt1:1:2"]);
    CHECK([[[[RWDiscoveryEpisodes alloc]init]episode:nil show:small history:@{} now:[NSDate dateWithTimeIntervalSince1970:now]][@"id"]isEqual:@"tt1:1:1"]);
    RWEpisodeCatalog *reloaded=[[RWEpisodeCatalog alloc]initWithSnapshot:RoundTrip(c.snapshot) now:now+10];CHECK([[reloaded show:@"tt1" now:now+10]isEqual:small]);CHECK([[reloaded show:@"tt1" now:now+10][@"episodeIndexAt"]doubleValue]==now);
    CHECK(![reloaded show:@"tt1" now:now-1]);CHECK([reloaded show:@"tt1" now:now+86399]);CHECK([[reloaded show:@"tt1" now:now+86400][@"episodeIndexHistorical"]boolValue]);
    RWDiscoveryEpisodes *late=[RWDiscoveryEpisodes new];CHECK([late episode:nil show:small history:@{} now:[NSDate dateWithTimeIntervalSince1970:now+86399]]);CHECK(![late episode:nil show:small history:@{} now:[NSDate dateWithTimeIntervalSince1970:now+86400]]);
    CHECK([[[RWEpisodeCatalog alloc]initWithSnapshot:c.snapshot now:now+86400]show:@"tt1" now:now+86400]!=nil);
    // Real Home preparation: full-detail eviction preserves the exact canonical
    // episode, never a stale title hint or another profile's viewing position.
    NSMutableDictionary *title=[full mutableCopy];[title removeObjectForKey:@"videos"];title[@"episodeVideoID"]=@"tt1:99:99";
    NSDictionary *positive=[RWAvailability ready:@{} sourceKey:@"fixture" quality:0 now:now];
    NSMutableDictionary *profile=[@{@"maxAge":@7,@"history":@{},@"hidden":@[],@"sourceAvailability":@{@"tt1:1:1":positive}}mutableCopy];
    NSMutableDictionary *input=[@{@"profile":profile,@"shows":@{@"tt1":full},@"family":@[title],@"quality":@0,@"ageRatings":@{@"cache":@{@"tt1":@{@"minimumAge":@6}}}}mutableCopy];
    NSDictionary *home=@{@"rows":@[@{@"items":@[title]}]};NSDictionary *p=[RWHomeDeferredPreparation prepare:home snapshot:input ratings:@{} profileID:@"kids" now:now];CHECK([p[@"entries"][@"tt1"][@"regular"]boolValue]);
    input[@"shows"]=[c showsByAddingDetails:@{} now:now];CHECK(![RWHomePreparation usable:p snapshot:input ratings:@{} profileID:@"kids" priors:nil now:now][@"entries"][@"tt1"]);
    p=[RWHomeDeferredPreparation prepare:home snapshot:input ratings:@{} profileID:@"kids" now:now];CHECK([p[@"entries"][@"tt1"][@"regular"]boolValue]);CHECK([p[@"entries"][@"tt1"][@"videoID"]isEqual:@"tt1:1:1"]);
    profile[@"history"]=history;p=[RWHomeDeferredPreparation prepare:home snapshot:input ratings:@{} profileID:@"kids" now:now];CHECK([p[@"entries"][@"tt1"][@"videoID"]isEqual:@"tt1:1:2"]);CHECK(![p[@"entries"][@"tt1"][@"regular"]boolValue]);
    profile[@"history"]=@{};input[@"ageRatings"]=@{};p=[RWHomeDeferredPreparation prepare:home snapshot:input ratings:@{} profileID:@"kids" now:now];CHECK(![p[@"entries"][@"tt1"][@"regular"]boolValue]);
    input[@"ageRatings"]=@{@"cache":@{@"tt1":@{@"minimumAge":@12}}};p=[RWHomeDeferredPreparation prepare:home snapshot:input ratings:@{} profileID:@"kids" now:now];CHECK(![p[@"entries"][@"tt1"][@"regular"]boolValue]);
    input[@"ageRatings"]=@{@"cache":@{@"tt1":@{@"minimumAge":@6}}};profile[@"hidden"]=@[@"tt1"];p=[RWHomeDeferredPreparation prepare:home snapshot:input ratings:@{} profileID:@"kids" now:now];CHECK(![RWRecommendationPolicy rank:@[p[@"entries"][@"tt1"][@"meta"]] current:nil profile:profile world:NO requireAvailability:YES now:now limit:12].count);profile[@"hidden"]=@[];
    profile[@"sourceAvailability"]=@{@"tt1:1:1":[RWAvailability ready:@{} sourceKey:@"fixture" quality:0 now:now+86398]};
    p=[RWHomeDeferredPreparation prepare:home snapshot:input ratings:@{} profileID:@"kids" now:now+86399];CHECK([p[@"entries"][@"tt1"][@"regular"]boolValue]);CHECK([p[@"entries"][@"tt1"][@"validUntil"]doubleValue]<=now+86400);
    CHECK(![RWHomePreparation usable:p snapshot:input ratings:@{} profileID:@"kids" priors:nil now:now+86400][@"entries"][@"tt1"]);
    p=[RWHomeDeferredPreparation prepare:home snapshot:input ratings:@{} profileID:@"kids" now:now+86400];CHECK(![p[@"entries"][@"tt1"][@"regular"]boolValue]);CHECK(![p[@"entries"][@"tt1"][@"videoID"]length]);
    // A raw worker snapshot still expires at24h; a newly captured historical
    // view may use exact already-released identities with fresh source evidence.
    input[@"shows"]=[c showsByAddingDetails:@{} now:now+86400];
    NSDictionary *historical=input[@"shows"][@"tt1"];CHECK([historical[@"episodeIndexHistorical"]boolValue]);CHECK([historical[@"episodeIndexAt"]doubleValue]==now);
    p=[RWHomeDeferredPreparation prepare:home snapshot:input ratings:@{} profileID:@"kids" now:now+86400];CHECK([p[@"entries"][@"tt1"][@"regular"]boolValue]);CHECK([p[@"entries"][@"tt1"][@"videoID"]isEqual:@"tt1:1:1"]);
    CHECK([historical[@"videos"]count]==3);CHECK([c show:@"tt1" now:now+29*86400]);CHECK(![c show:@"tt1" now:now+30*86400]);
    // Never refresh the receipt timestamp while loading a persisted old index.
    RWEpisodeCatalog *aged=[[RWEpisodeCatalog alloc]initWithSnapshot:RoundTrip(reloaded.snapshot) now:now+2*86400];NSDictionary *agedShow=[aged show:@"tt1" now:now+2*86400];CHECK([agedShow[@"episodeIndexAt"]doubleValue]==now);CHECK([agedShow[@"episodeIndexHistorical"]boolValue]);
    NSDictionary *missingHistory=@{@"tt1:2:1":@{@"position":@90,@"updated":@(now+1)}};
    CHECK(![[RWDiscoveryEpisodes new]episode:nil show:agedShow history:missingHistory now:[NSDate dateWithTimeIntervalSince1970:now+2*86400]]);
    // Only episodes already released at the original receipt become history.
    NSMutableDictionary *mixed=[Show(3,3)mutableCopy];NSMutableArray *mixedEpisodes=[mixed[@"videos"]mutableCopy];
    mixedEpisodes[1]=@{@"id":@"tt3:1:2",@"season":@1,@"episode":@2,@"released":@"2026-10-24"};
    mixedEpisodes[2]=@{@"id":@"tt3:1:3",@"season":@1,@"episode":@3,@"released":@""};mixed[@"videos"]=mixedEpisodes;
    RWEpisodeCatalog *pastOnly=[[RWEpisodeCatalog alloc]initWithSnapshot:@{} now:now];[pastOnly accept:mixed now:now];
    NSDictionary *past=[pastOnly show:@"tt3" now:now+4*86400];CHECK([past[@"videos"]count]==1);CHECK([past[@"videos"][0][@"id"]isEqual:@"tt3:1:1"]);
    CHECK(![[RWDiscoveryEpisodes new]episode:@"tt3:1:2" show:past history:@{} now:[NSDate dateWithTimeIntervalSince1970:now+4*86400]]);
    CHECK(![[RWDiscoveryEpisodes new]episode:nil show:past history:@{@"tt3:1:1":@{@"completed":@YES}} now:[NSDate dateWithTimeIntervalSince1970:now+4*86400]]);
    [pastOnly accept:mixed now:now+4*86400];CHECK(![[pastOnly show:@"tt3" now:now+4*86400][@"episodeIndexHistorical"]boolValue]);CHECK([[pastOnly show:@"tt3" now:now+4*86400][@"videos"]count]==3);
    NSMutableDictionary *future=[Show(2,1)mutableCopy],*ep=[future[@"videos"][0]mutableCopy];ep[@"released"]=@"2200-01-01";future[@"videos"]=@[ep];[c accept:future now:now];CHECK(![[RWDiscoveryEpisodes new]episode:nil show:[c show:@"tt2" now:now] history:@{} now:[NSDate dateWithTimeIntervalSince1970:now]]);
    [c accept:@{@"id":@"tt1",@"type":@"series",@"videos":@[]} now:now+1];CHECK(![c show:@"tt1" now:now+1]);
    // Corrupt disk data never crashes or synthesizes a fresh receipt time.
    for(id stamp in @[NSNull.null,@"123",@0,@(now+1),@(now-30*86400)]){NSMutableDictionary *bad=[small mutableCopy];bad[@"episodeIndexAt"]=stamp;RWEpisodeCatalog *broken=[[RWEpisodeCatalog alloc]initWithSnapshot:@{@"version":@1,@"shows":@{@"tt1":bad}} now:now];CHECK([broken.diagnostics[@"shows"]intValue]==0);}
    CHECK([[[RWEpisodeCatalog alloc]initWithSnapshot:@{@"version":@1,@"shows":@{@"tt2":small}} now:now].diagnostics[@"shows"]intValue]==0);
    // The shared profile catalog must retain more than64complete series under
    // the same1MiB bound, rather than repeatedly recovering lost identities.
    c=[[RWEpisodeCatalog alloc]initWithSnapshot:@{} now:now];for(int i=1;i<=80;i++)[c accept:Show(i,100) now:now+i];
    CHECK([c.diagnostics[@"shows"]intValue]==80);CHECK([c show:@"tt1" now:now+80]&&[c show:@"tt80" now:now+80]);
    CHECK([c.diagnostics[@"estimated_bytes"]intValue]<=1024*1024);
    RWEpisodeCatalog *many=[[RWEpisodeCatalog alloc]initWithSnapshot:RoundTrip(c.snapshot) now:now+90];CHECK([many.diagnostics[@"shows"]intValue]==80);
    CHECK([[many show:@"tt1" now:now+90][@"videos"]count]==100);
    c=[[RWEpisodeCatalog alloc]initWithSnapshot:@{} now:now];for(int i=1;i<=6;i++)[c accept:Show(i,2000) now:now+i];
    CHECK([c.diagnostics[@"shows"]intValue]==6);CHECK([c.diagnostics[@"episodes"]intValue]==12000);
    CHECK([c.diagnostics[@"estimated_bytes"]intValue]<=1024*1024);CHECK([NSJSONSerialization dataWithJSONObject:c.snapshot options:0 error:nil].length<=2*1024*1024);
    CHECK(![c accept:Show(9,4097) now:now+9]);CHECK(![c show:@"tt9" now:now+9]);
    // Exact dictionary semantics, immutable ownership and serializable snapshots.
    NSMutableArray *original=[NSMutableArray new];for(NSDictionary *e in [RWTVPolicy episodes:Show(55,100)])[original addObject:@{@"id":e[@"id"],@"season":e[@"season"],@"episode":e[@"episode"],@"released":e[@"released"]}];RWPackedEpisodes *pack=[RWPackedEpisodes episodes:original title:@"tt55"];
    CHECK(pack.count==100);CHECK([pack isEqualToArray:original]);CHECK([pack copy]==pack);
    NSMutableArray *mutable=[pack mutableCopy];[mutable removeLastObject];CHECK(mutable.count==99&&pack.count==100);
    CHECK([[RWPackedEpisodes archive:RoundTrip(pack.archive) title:@"tt55"]isEqualToArray:original]);
    CHECK([[NSJSONSerialization JSONObjectWithData:[NSJSONSerialization dataWithJSONObject:pack options:0 error:nil] options:0 error:nil]isEqual:original]);
    __unsafe_unretained id buffer[2];[pack getObjects:buffer range:NSMakeRange(98,2)];CHECK([buffer[0]isEqual:original[98]]&&[buffer[1]isEqual:original[99]]);
    BOOL threw=NO;@try{[pack objectAtIndex:100];}@catch(NSException *e){threw=[e.name isEqual:NSRangeException];}CHECK(threw);
    NSMutableDictionary *ownedInput=[Show(55,1)mutableCopy];ownedInput[@"videos"]=pack;NSDictionary *owned=[RWDiscoveryEpisodes immutableShow:ownedInput];[ownedInput removeAllObjects];CHECK(owned[@"videos"]==pack);
    // Reject malformed persisted buffers; never accept a truncated/partial index.
    NSDictionary *valid=pack.archive;
    for(NSString *field in @[@"offsets",@"data"]){for(id value in @[NSNull.null,@3,@"!invalid",@"",[@"A" stringByPaddingToLength:1000000 withString:@"A" startingAtIndex:0]]){NSMutableDictionary *bad=[valid mutableCopy];bad[field]=value;CHECK(![RWPackedEpisodes archive:bad title:@"tt55"]);}}
    NSMutableData *offsets=[[[NSData alloc]initWithBase64EncodedString:valid[@"offsets"] options:0]mutableCopy];((uint8_t *)offsets.mutableBytes)[0]=1;
    CHECK(![RWPackedEpisodes archive:@{@"offsets":[offsets base64EncodedStringWithOptions:0],@"data":valid[@"data"]} title:@"tt55"]);
    NSMutableData *raw=[[[NSData alloc]initWithBase64EncodedString:valid[@"data"] options:0]mutableCopy];((uint8_t *)raw.mutableBytes)[0]=101;
    CHECK(![RWPackedEpisodes archive:@{@"offsets":valid[@"offsets"],@"data":[raw base64EncodedStringWithOptions:0]} title:@"tt55"]);
    CHECK(![RWPackedEpisodes archive:valid title:@"invalid"]);
    //256 complete show cap still evicts oldest receipts deterministically.
    RWEpisodeCatalog *bounded=[[RWEpisodeCatalog alloc]initWithSnapshot:@{} now:now];for(int i=1;i<=260;i++)[bounded accept:Show(i,1) now:now+i];
    CHECK([bounded.diagnostics[@"shows"]intValue]==256);CHECK(![bounded show:@"tt4" now:now+260]&&[bounded show:@"tt5" now:now+260]);
    NSMutableDictionary *oversized=[bounded.snapshot[@"shows"]mutableCopy];oversized[@"extra"]=oversized.allValues.firstObject;
    CHECK([[[RWEpisodeCatalog alloc]initWithSnapshot:@{@"version":@2,@"shows":oversized} now:now+260].diagnostics[@"shows"]intValue]==0);
    // Byte and episode caps bound dense catalog data and its persisted encoding.
    bounded=[[RWEpisodeCatalog alloc]initWithSnapshot:@{} now:now];for(int i=1;i<=40;i++){@autoreleasepool{[bounded accept:Show(i,2000) now:now+i];}}
    CHECK([bounded.diagnostics[@"episodes"]intValue]<=32768);CHECK([bounded.diagnostics[@"estimated_bytes"]intValue]<=1024*1024);
    CHECK([NSJSONSerialization dataWithJSONObject:bounded.snapshot options:0 error:nil].length<=2*1024*1024);
    RWDiscoveryEpisodes *selection=[RWDiscoveryEpisodes new];for(int i=25;i<=40;i++){@autoreleasepool{[selection episode:nil show:[bounded show:[NSString stringWithFormat:@"tt%d",i] now:now+40] history:@{} now:[NSDate dateWithTimeIntervalSince1970:now+40]];CHECK([selection.diagnostics[@"cached_episodes"]intValue]<=4096);}}
    [selection removeAll];CHECK([selection.diagnostics[@"cached_episodes"]intValue]==0);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
