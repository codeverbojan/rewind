#import "../RWHomeRailPolicy.h"
static int checks,failures;
#define C(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSDictionary *Reload(NSDictionary *value){return [NSJSONSerialization JSONObjectWithData:[NSJSONSerialization dataWithJSONObject:value options:0 error:nil] options:0 error:nil];}
int main(){@autoreleasepool{
    double now=1792956100;NSDictionary *row=@{@"id":@"for-you-series",@"mediaType":@"series",@"recipe":@"for-you"};
    NSArray *providers=[RWHomeRailPolicy providers:row restricted:YES];C(providers.count==3);
    C([providers[0][@"sort"]isEqual:@"Top rated"]&&[providers[0][@"genre"]isEqual:@"Family"]);
    C([providers[1][@"sort"]isEqual:@"Popular"]&&[providers[1][@"genre"]isEqual:@"Family"]);
    C([providers[2][@"sort"]isEqual:@"Popular"]&&[providers[2][@"genre"]isEqual:@"Animation"]);
    NSDictionary *legacy=@{@"page":@22,@"skip":@99,@"exhaustedAt":@(now-1)};
    NSDictionary *(^plan)(NSDictionary *,double)=^NSDictionary *(NSDictionary *cursor,double time){return [RWHomeRailPolicy catalogPage:row cursor:cursor restricted:YES now:time];};
    NSDictionary *p=plan(legacy,now),*before=Reload(p);C([p[@"request"][@"key"]isEqual:providers[1][@"key"]]);C([p[@"request"][@"skip"]integerValue]==0);
    C([p[@"cursor"][@"catalogs"][providers[0][@"key"]][@"skip"]integerValue]==99);C(!p[@"cursor"][@"exhaustedAt"]);
    NSDictionary *cursor=[RWHomeRailPolicy advanceCatalogPage:p received:50 now:now];C([p isEqual:before]);
    p=plan(Reload(cursor),now);C([p[@"request"][@"key"]isEqual:providers[2][@"key"]]);C([p[@"request"][@"skip"]integerValue]==0);
    cursor=[RWHomeRailPolicy advanceCatalogPage:p received:50 now:now];p=plan(cursor,now);
    C([p[@"request"][@"key"]isEqual:providers[1][@"key"]]&&[p[@"request"][@"skip"]integerValue]==50);
    C([cursor[@"catalogs"][providers[2][@"key"]][@"skip"]integerValue]==50);
    // Only an actual empty response ends that catalog. An unchanged cursor
    // plans the same request; transient failure uses the separate defer path.
    NSDictionary *retry=Reload(cursor);C([plan(retry,now)[@"request"]isEqual:p[@"request"]]);
    cursor=[RWHomeRailPolicy advanceCatalogPage:p received:0 now:now];p=plan(cursor,now);
    C([p[@"request"][@"key"]isEqual:providers[2][@"key"]]&&[p[@"request"][@"skip"]integerValue]==50);
    cursor=[RWHomeRailPolicy advanceCatalogPage:p received:0 now:now+1];p=plan(cursor,now+1);C(!p[@"request"]);C([cursor[@"exhaustedAt"]doubleValue]==now-1);
    C(!plan(cursor,now+21598)[@"request"]);p=plan(cursor,now+21599);
    C([p[@"request"][@"key"]isEqual:providers[0][@"key"]]&&[p[@"request"][@"skip"]integerValue]==0);
    C([p[@"cursor"][@"catalogs"][providers[2][@"key"]][@"skip"]integerValue]==50);
    C([[RWHomeRailPolicy advanceCatalogPage:p received:101 now:now+21599]isEqual:p[@"cursor"]]);
    // Invalid disk fields are bounded and cannot introduce another endpoint.
    NSMutableDictionary *bad=[cursor mutableCopy];bad[@"nextCatalog"]=@999;bad[@"page"]=@(-1);
    bad[@"catalogs"]=@{providers[0][@"key"]:@{@"skip":@(-5),@"exhaustedAt":@"invalid"},@"attacker":@{@"skip":@99999}};
    p=plan(bad,now);C([p[@"cursor"][@"catalogs"]count]==3);C([p[@"request"][@"skip"]integerValue]==0);C([p[@"cursor"][@"page"]integerValue]==0);
    C(!p[@"cursor"][@"catalogs"][@"attacker"]);C([NSJSONSerialization dataWithJSONObject:p[@"cursor"] options:0 error:nil].length<1024);
    for(id corrupt in @[NSNull.null,@"bad",@[]]){p=plan((id)corrupt,now);C(p[@"request"]!=nil);}
    C([[RWHomeRailPolicy providers:row restricted:NO]count]==2);
    NSDictionary *category=@{@"mediaType":@"series",@"recipe":@"category",@"providerGenre":@"Animation"};
    NSArray *animation=[RWHomeRailPolicy providers:category restricted:YES];C(animation.count==4);
    C([animation[0][@"genre"]isEqual:@"Family"]&&[animation[1][@"genre"]isEqual:@"Family"]);
    C(animation.count>=4&&[animation[2][@"genre"]isEqual:@"Animation"]&&[animation[3][@"genre"]isEqual:@"Animation"]);
    // New family catalogs must not reset already fetched Animation offsets.
    NSDictionary *oldTheme=@{@"catalogPolicy":@1,@"nextCatalog":@0,@"catalogs":@{@"series|Top rated|Animation":@{@"skip":@150},@"series|Popular|Animation":@{@"skip":@100}}};
    NSDictionary *themePage=[RWHomeRailPolicy catalogPage:category cursor:oldTheme restricted:YES now:now];
    C([themePage[@"request"][@"genre"]isEqual:@"Family"]&&[themePage[@"request"][@"skip"]integerValue]==0);
    C([themePage[@"cursor"][@"catalogs"][@"series|Top rated|Animation"][@"skip"]integerValue]==150);
    C([themePage[@"cursor"][@"catalogs"][@"series|Popular|Animation"][@"skip"]integerValue]==100);
    NSDictionary *legacyTheme=[RWHomeRailPolicy catalogPage:category cursor:@{@"skip":@99,@"exhaustedAt":@(now-1)} restricted:YES now:now];
    C([legacyTheme[@"request"][@"genre"]isEqual:@"Family"]&&[legacyTheme[@"request"][@"skip"]integerValue]==0);
    C([legacyTheme[@"cursor"][@"catalogs"][@"series|Top rated|Animation"][@"skip"]integerValue]==99);
    C([[RWHomeRailPolicy providers:category restricted:NO]count]==2);
    NSDictionary *recent=@{@"mediaType":@"series",@"recipe":@"new"};C([[RWHomeRailPolicy providers:recent restricted:YES]count]==1);
    C(![RWHomeRailPolicy catalogPage:@{@"mediaType":@"hero"} cursor:@{} restricted:YES now:now][@"request"]);
    C([legacy[@"skip"]integerValue]==99&&[legacy[@"exhaustedAt"]doubleValue]==now-1);
    // Two local-only batches yield a turn to this row's own catalog. The
    // counter survives disk serialization and resets only on a received page.
    NSDictionary *local=[RWHomeRailPolicy cursorAfterLocalPage:@{}];C(![RWHomeRailPolicy shouldBrowseBeforeCheckingLocal:row cursor:local restricted:NO now:now]);
    local=[RWHomeRailPolicy cursorAfterLocalPage:local];C([RWHomeRailPolicy shouldBrowseBeforeCheckingLocal:row cursor:Reload(local) restricted:NO now:now]);
    p=[RWHomeRailPolicy catalogPage:row cursor:local restricted:NO now:now];NSDictionary *received=[RWHomeRailPolicy advanceCatalogPage:p received:50 now:now];
    C(![RWHomeRailPolicy shouldBrowseBeforeCheckingLocal:row cursor:received restricted:NO now:now]);C([received[@"skip"]integerValue]==50);
    C([RWHomeRailPolicy shouldBrowseBeforeCheckingLocal:row cursor:@{@"page":@17} restricted:NO now:now]);
    C(![RWHomeRailPolicy shouldBrowseBeforeCheckingLocal:row cursor:@{@"page":@17,@"skip":@50} restricted:NO now:now]);
    NSMutableDictionary *endedLocal=[cursor mutableCopy];endedLocal[@"localOnlyPages"]=@2;C(![RWHomeRailPolicy shouldBrowseBeforeCheckingLocal:row cursor:endedLocal restricted:YES now:now+2]);
    for(int i=0;i<5;i++)local=[RWHomeRailPolicy cursorAfterLocalPage:local];C([local[@"localOnlyPages"]integerValue]==2);
    C(![RWHomeRailPolicy shouldBrowseBeforeCheckingLocal:@{@"mediaType":@"hero"} cursor:local restricted:NO now:now]);
    // Reproduce the actual Kids cursor: Animation300 fails, while Family350
    // is still available. Neither failed offsets nor exhausted siblings reset.
    NSDictionary *device=@{@"catalogPolicy":@1,@"nextCatalog":@2,@"catalogs":@{
        providers[0][@"key"]:@{@"skip":@99,@"exhaustedAt":@(now-10)},
        providers[1][@"key"]:@{@"skip":@350},providers[2][@"key"]:@{@"skip":@300}}};
    p=plan(device,now);before=Reload(p);C([p[@"request"][@"skip"]integerValue]==300);
    NSDictionary *failed=[RWHomeRailPolicy deferCatalogPage:p now:now];C([p isEqual:before]);
    p=plan(Reload(failed),now+1);C([p[@"request"][@"key"]isEqual:providers[1][@"key"]]);C([p[@"request"][@"skip"]integerValue]==350&&!p[@"deferred"]);
    C([failed[@"catalogs"][providers[2][@"key"]][@"skip"]integerValue]==300&&!failed[@"catalogs"][providers[2][@"key"]][@"exhaustedAt"]);
    C([failed[@"catalogs"][providers[0][@"key"]][@"exhaustedAt"]doubleValue]==now-10);
    NSDictionary *both=[RWHomeRailPolicy deferCatalogPage:p now:now+1];p=plan(Reload(both),now+59);
    C(p[@"request"]&&[p[@"deferred"]boolValue]&&[p[@"retryAt"]doubleValue]==now+60&&!p[@"cursor"][@"exhaustedAt"]);
    p=plan(both,now+60);C(!p[@"deferred"]&&[p[@"request"][@"key"]isEqual:providers[2][@"key"]]&&[p[@"request"][@"skip"]integerValue]==300);
    NSDictionary *success=[RWHomeRailPolicy advanceCatalogPage:p received:50 now:now+60];
    C([success[@"catalogs"][providers[2][@"key"]][@"skip"]integerValue]==350&&!success[@"catalogs"][providers[2][@"key"]][@"failedAt"]);
    // Future, stale and malformed disk failure dates cannot hide a catalog.
    for(id stamp in @[@(now+1),@(now-60),@"bad",NSNull.null]){
        NSMutableDictionary *corrupt=[device mutableCopy],*states=[device[@"catalogs"]mutableCopy];states[providers[2][@"key"]]=@{@"skip":@300,@"failedAt":stamp};corrupt[@"catalogs"]=states;
        p=plan(corrupt,now);C(!p[@"deferred"]&&[p[@"request"][@"skip"]integerValue]==300&&!p[@"cursor"][@"catalogs"][providers[2][@"key"]][@"failedAt"]);
    }
    C([NSJSONSerialization dataWithJSONObject:both options:0 error:nil].length<1024);
    C([[RWHomeRailPolicy deferCatalogPage:@{@"cursor":device} now:now]isEqual:device]);
    C([[RWHomeRailPolicy deferCatalogPage:plan(device,now) now:0]isEqual:plan(device,now)[@"cursor"]]);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
