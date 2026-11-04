#import "../RWReminderPolicy.h"
static int Checks,Failures;
#define C(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line%d\n",__LINE__);}}while(0)
int main(){@autoreleasepool{
 NSDate *now=[NSDate dateWithTimeIntervalSince1970:2000000000];NSString *title=@"tt0369179",*video=@"tt0369179:2:1";
 NSDictionary *ep=@{@"id":video,@"season":@2,@"episode":@1,@"released":@"2004-09-20T00:00:00Z"};
 NSDictionary *meta=@{@"id":title,@"type":@"series",@"name":@"Two and a Half Men"},*show=@{@"id":title,@"type":@"series",@"name":@"Two and a Half Men",@"videos":@[ep]};
 NSMutableDictionary *profile=[@{@"maxAge":@(-1),@"hidden":@[],@"history":@{},@"episodeNotifications":@YES,@"following":@{title:@{@"meta":meta}},@"episodeUpdates":@{title:@{@"episode":ep}},@"availabilityWatch":@{title:@{@"videoID":video}},@"availabilityUpdates":@{title:meta}}mutableCopy];
 NSMutableDictionary *state=[@{@"activeProfile":@"kids",@"profiles":@{@"main":profile,@"kids":@{@"maxAge":@0}}}mutableCopy];
 NSDictionary *payload=[RWReminderPolicy payload:@"episode" profile:@"main" title:title video:video];C(payload);C([payload[@"rewindEpisodeUpdate"]boolValue]);C([payload[@"rewindReminder"][@"profileID"]isEqual:@"main"]);
 NSDictionary *(^target)(NSDictionary *)=^NSDictionary *(NSDictionary *p){return [RWReminderPolicy destination:p state:state show:show rating:@{@"minimumAge":@15} now:now];};
 NSDictionary *dest=target(payload);C([dest[@"profileID"]isEqual:@"main"]);C([dest[@"videoID"]isEqual:video]);C([dest[@"episode"]isEqual:ep]);C([state[@"activeProfile"]isEqual:@"kids"]);
 for(NSDictionary *change in @[@{@"schema":@2},@{@"notificationID":@"invalid"},@{@"profileID":@"absent"},@{@"titleID":@"tt99999"},@{@"videoID":@"tt0369179:3:99"},@{@"kind":@"url"}]){NSMutableDictionary *p=[payload mutableCopy],*body=[p[@"rewindReminder"]mutableCopy];[body addEntriesFromDictionary:change];p[@"rewindReminder"]=body;C(!target(p));}
 for(NSDictionary *change in @[@{@"hidden":@[title]},@{@"episodeNotifications":@NO},@{@"following":@{}},@{@"history":@{video:@{@"completed":@YES}}},@{@"maxAge":@0},@{@"maxAge":@(-5)},@{@"maxAge":@19}]){NSDictionary *before=[profile copy];[profile addEntriesFromDictionary:change];C(!target(payload));[profile setDictionary:before];}
 profile[@"maxAge"]=@12;C(![RWReminderPolicy destination:payload state:state show:show rating:nil now:now]);C([RWReminderPolicy destination:payload state:state show:show rating:@{@"minimumAge":@7} now:now]);profile[@"maxAge"]=@(-1);
 C(![RWReminderPolicy destination:payload state:state show:show rating:nil now:[NSDate dateWithTimeIntervalSince1970:1000000000]]);
 NSDictionary *available=[RWReminderPolicy payload:@"availability" profile:@"main" title:title video:video];C([target(available)[@"kind"]isEqual:@"availability"]);
 profile[@"availabilityWatch"]=@{};C(!target(available));profile[@"availabilityWatch"]=@{title:@{@"videoID":@"wrong"}};C(!target(available));profile[@"availabilityWatch"]=@{title:@{@"videoID":video}};profile[@"availabilityUpdates"]=@{};C(!target(available));
 profile[@"availabilityUpdates"]=@{title:meta};
 NSDictionary *cold=[RWReminderPolicy destination:available state:state show:nil rating:nil now:now];C([cold[@"videoID"]isEqual:video]);C([cold[@"meta"]isEqual:meta]);C(![cold[@"episode"]count]);
 NSDictionary *coldEpisode=[RWReminderPolicy destination:payload state:state show:nil rating:nil now:now];C([coldEpisode[@"meta"][@"videos"]isEqual:@[ep]]);
 profile[@"history"]=@{video:@{@"completed":@YES}};C(!target(available));profile[@"history"]=@{};
 profile[@"availabilityWatch"]=@{title:@{}};C(!target(available));profile[@"availabilityWatch"]=@{title:@{@"videoID":video}};
 for(id malformed in @[@{},@{@"rewindReminder":@[]},@{@"rewindEpisodeUpdate":@YES}])C(!target(malformed));
 C(![RWReminderPolicy payload:@"other" profile:@"main" title:title video:video]);C(![RWReminderPolicy payload:@"episode" profile:@"" title:title video:video]);C(![RWReminderPolicy payload:@"episode" profile:@"main" title:title video:@""]);
 printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
