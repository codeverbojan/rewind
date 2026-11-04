#import <Foundation/Foundation.h>
#import "../RWTVPolicy.h"
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    NSDictionary *a=@{@"id":@"tt1:1:1",@"season":@1,@"episode":@1,@"released":@"2000-01-01"};
    NSDictionary *b=@{@"id":@"tt1:1:2",@"season":@1,@"episode":@2,@"released":@"2000-01-02"};
    NSDictionary *c=@{@"id":@"tt1:2:1",@"season":@2,@"episode":@1,@"released":@"2001-01-01"};
    NSDictionary *future=@{@"id":@"tt1:2:2",@"season":@2,@"episode":@2,@"released":@"2200-01-01"};
    NSDictionary *show=@{@"id":@"tt1",@"type":@"series",@"videos":@[future,c,b,a]};NSDate *now=[NSDate dateWithTimeIntervalSince1970:1792607000];
    NSMutableDictionary *history=[NSMutableDictionary new];
    CHECK([[RWTVPolicy nextEpisode:show history:history now:now][@"id"]isEqual:a[@"id"]]);
    history[a[@"id"]]=@{@"position":@30,@"completed":@NO,@"updated":@1};
    CHECK([[RWTVPolicy nextEpisode:show history:history now:now][@"id"]isEqual:a[@"id"]]);
    // The existing menu writes position=1 when marking watched. It must still
    // advance beyond this explicit latest choice, including a season boundary.
    history[b[@"id"]]=@{@"position":@1,@"completed":@YES,@"updated":@2};
    CHECK([[RWTVPolicy nextEpisode:show history:history now:now][@"id"]isEqual:c[@"id"]]);
    history[c[@"id"]]=@{@"position":@1,@"completed":@YES,@"updated":@3};
    CHECK(![RWTVPolicy nextEpisode:show history:history now:now]);
    history[b[@"id"]]=@{@"position":@0,@"completed":@NO,@"updated":@5,@"progressOverride":@"unwatched"};
    CHECK([[RWTVPolicy nextEpisode:show history:history now:now][@"id"]isEqual:b[@"id"]]);
    CHECK([[RWTVPolicy nextEpisode:show history:@{} now:now][@"id"]isEqual:a[@"id"]]);
    NSDictionary *(^record)(NSString *,double,BOOL,double)=^NSDictionary *(NSString *identifier,double position,BOOL completed,double at){return @{@"meta":@{@"id":@"tt1",@"type":@"series"},@"videoID":identifier,@"position":@(position),@"completed":@(completed),@"updated":@(at)};};
    NSDictionary *paused=record(a[@"id"],30,NO,1),*finished=record(b[@"id"],1200,YES,2),*newer=record(c[@"id"],40,NO,3),*shortStart=record(c[@"id"],1,NO,4);
    CHECK([RWTVPolicy continuingRecords:@[paused,finished]].count==0);
    CHECK([[RWTVPolicy continuingRecords:@[paused,newer]]isEqual:@[newer]]);
    CHECK([[RWTVPolicy continuingRecords:@[paused,shortStart]]isEqual:@[paused]]);
    NSMutableDictionary *unwatched=[record(b[@"id"],0,NO,5)mutableCopy];unwatched[@"progressOverride"]=@"unwatched";
    CHECK([RWTVPolicy continuingRecords:@[paused,unwatched]].count==0);
    NSDictionary *film=@{@"meta":@{@"id":@"ttfilm",@"type":@"movie"},@"videoID":@"ttfilm",@"position":@20,@"updated":@6};
    CHECK([[RWTVPolicy continuingRecords:@[paused,finished,film]]isEqual:@[film]]);
    CHECK(![RWTVPolicy continuingRecords:@[]].count);
    // Changed release metadata cannot make a future episode resumable.
    history[b[@"id"]]=@{@"position":@1,@"completed":@YES,@"updated":@2};
    history[future[@"id"]]=@{@"position":@30,@"completed":@NO,@"updated":@4};
    CHECK(![RWTVPolicy nextEpisode:show history:history now:now]);
    CHECK([[RWTVPolicy episodeAfter:a[@"id"] show:show now:now][@"id"]isEqual:b[@"id"]]);
    CHECK([[RWTVPolicy episodeAfter:b[@"id"] show:show now:now][@"id"]isEqual:c[@"id"]]);
    CHECK(![RWTVPolicy episodeAfter:c[@"id"] show:show now:now]);
    CHECK(![RWTVPolicy episodeAfter:future[@"id"] show:show now:now]);
    CHECK(![RWTVPolicy episodeAfter:@"other:1:2" show:show now:now]);
    CHECK(![RWTVPolicy episodeAfter:@"" show:show now:now]);
    CHECK(![RWTVPolicy episodeAfter:a[@"id"] show:@{@"id":@"tt1",@"type":@"movie",@"videos":@[a,b]} now:now]);
    NSMutableDictionary *changed=[show mutableCopy],*unknown=[b mutableCopy];[unknown removeObjectForKey:@"released"];changed[@"videos"]=@[a,unknown,c];
    CHECK(![RWTVPolicy episodeAfter:a[@"id"] show:changed now:now]);
    unknown[@"released"]=@"2200-01-01";CHECK(![RWTVPolicy episodeAfter:a[@"id"] show:changed now:now]);
    changed[@"videos"]=@[a,@{@"id":@"other:1:2",@"season":@1,@"episode":@2,@"released":@"2000-01-01"},c];
    CHECK([[RWTVPolicy episodeAfter:a[@"id"] show:changed now:now][@"id"]isEqual:c[@"id"]]);
    CHECK(![RWTVPolicy episodeAfter:a[@"id"] show:nil now:now]);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
