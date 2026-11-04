#import "../RWDiscoveryEpisodes.h"
#import "../RWPackedEpisodes.h"
#import "../RWTVPolicy.h"
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
@interface CountedEpisodes:RWPackedEpisodes
@property NSUInteger reads;
@end
@implementation CountedEpisodes
- (id)objectAtIndex:(NSUInteger)i {self.reads++;return [super objectAtIndex:i];}
@end
static NSDictionary *Episode(NSString *title,int season,int number,NSString *date){return @{@"id":[NSString stringWithFormat:@"%@:%d:%d",title,season,number],@"season":@(season),@"episode":@(number),@"released":date};}
static NSDictionary *Show(NSString *title,NSArray *videos,double at,BOOL historical){NSMutableDictionary *m=[@{@"id":title,@"type":@"series",@"videos":videos,@"episodeIndexAt":@(at)}mutableCopy];if(historical)m[@"episodeIndexHistorical"]=@YES;return [RWDiscoveryEpisodes immutableShow:m];}
static BOOL Same(id a,id b){return a==b||[a isEqual:b];}
int main(){@autoreleasepool{
    NSString *key=@"tt0197000";double clock=1792962000;NSDate *now=[NSDate dateWithTimeIntervalSince1970:clock];
    NSMutableArray *many=[NSMutableArray new];for(int i=1;i<=1000;i++)[many addObject:Episode(key,1,i,@"2000-01-01")];
    CountedEpisodes *packed=[CountedEpisodes episodes:many title:key];NSDictionary *show=Show(key,packed,clock,NO);RWDiscoveryEpisodes *reader=[RWDiscoveryEpisodes new];
    CHECK([[reader episode:nil show:show history:@{} now:now][@"id"]isEqual:@"tt0197000:1:1"]);
    CHECK(packed.reads<=1);CHECK([reader.diagnostics[@"index_builds"]intValue]==0);CHECK([reader.diagnostics[@"cached_episodes"]intValue]==0);
    packed.reads=0;CHECK([[reader episode:@"tt0197000:1:1000" show:show history:@{} now:now][@"id"]isEqual:@"tt0197000:1:1000"]);CHECK(packed.reads<=1);
    NSArray *episodes=@[Episode(key,0,1,@"2000-01-01"),Episode(key,1,1,@"2200-01-01"),Episode(key,1,2,@""),Episode(key,1,3,@"2001-03-04T13:20:00.000Z"),Episode(key,1,5,@"2001-03-05"),Episode(key,2,1,@"invalid"),Episode(key,2,2,@"2003-01-01")];
    NSArray *histories=@[@{},@{@"tt777:1:1":@{@"position":@90,@"updated":@20}},@{@"tt0197000:1:3":@{@"completed":@YES,@"updated":@10}},@{@"tt0197000:1:5":@{@"position":@30,@"updated":@10}},@{@"tt0197000:1:3":@{@"progressOverride":@"unwatched",@"updated":@11}},@{@"tt0197000:99:1":@{@"position":@90,@"updated":@50}},@{@"tt0197000:0:1":@{@"position":@90,@"updated":@50}},@{@"tt0197000:1:1":@{@"completed":@YES,@"updated":@900}},@{@"tt0197000:1:3":@{@"completed":@YES,@"updated":@10},@"tt0197000:1:5":@{@"completed":@YES,@"updated":@10}},@{@"tt0197000:2:2":@{@"completed":@YES,@"updated":@20}},@{@"tt0197000:99:1":@{@"position":@0,@"updated":@50}},@{@"tt01970000:1:1":@{@"position":@90,@"updated":@50}}];
    NSArray *requested=@[@"",@"tt0197000:0:1",@"tt0197000:1:1",@"tt0197000:1:3",@"tt0197000:1:4",@"tt0197000:2:2",@"tt777:1:3",@"tt0197000:01:3",@"tt0197000:1:03",@"tt0197000:1:3junk",@"tt0197000:-1:3",@"tt0197000:1:0",@"tt0197000:1:2001",@"tt0197000:101:1",@"tt0197000:1:3:4",@"tt0197000:١:٣"];
    // Compare against the unchanged full-array selector over release/history cases.
    for(NSNumber *historical in @[@NO,@YES])for(NSNumber *age in @[@0,@86401,@(30*86400)]){
        NSDictionary *plain=Show(key,episodes,clock-age.doubleValue,historical.boolValue),*compact=Show(key,[RWPackedEpisodes episodes:episodes title:key],clock-age.doubleValue,historical.boolValue);
        for(NSDictionary *history in histories)for(NSString *wanted in requested){
            RWDiscoveryEpisodes *baseline=[RWDiscoveryEpisodes new],*fast=[RWDiscoveryEpisodes new];
            CHECK(Same([baseline episode:wanted show:plain history:history now:now],[fast episode:wanted show:compact history:history now:now]));
        }
    }
    NSDictionary *wrong=Show(@"tt777",packed,clock,NO);
    CHECK(![[RWDiscoveryEpisodes new]episode:nil show:wrong history:@{} now:now]);
    CHECK(![[RWDiscoveryEpisodes new]episode:@"tt0197000:1:1000" show:wrong history:@{} now:now]);
    // Same reader must not reuse a previous profile's choice or stale next result.
    NSDictionary *plain=Show(key,episodes,clock,NO);show=Show(key,[RWPackedEpisodes episodes:episodes title:key],clock,NO);reader=[RWDiscoveryEpisodes new];
    for(NSDictionary *history in histories){[reader invalidate:key];CHECK(Same([[RWDiscoveryEpisodes new]episode:nil show:plain history:history now:now],[reader episode:nil show:show history:history now:now]));}
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
