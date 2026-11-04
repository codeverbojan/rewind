#import "RWReminderPolicy.h"
#import "RWTVPolicy.h"
#import "RWRatingPolicy.h"
static NSDictionary *RD(id value){return [value isKindOfClass:NSDictionary.class]?value:@{};}
static NSString *RT(id value){return [value isKindOfClass:NSString.class]?value:@"";}
static BOOL RI(id value){NSString *s=RT(value);return s.length>0&&s.length<=160&&[s rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location==NSNotFound;}
@implementation RWReminderPolicy
+ (NSDictionary *)payload:(NSString *)kind profile:(NSString *)profile title:(NSString *)title video:(NSString *)video {
    if(![@[@"episode",@"availability"]containsObject:kind]||!RI(profile)||!RI(title)||([kind isEqual:@"episode"]&&!RI(video)))return nil;
    return @{([kind isEqual:@"episode"]?@"rewindEpisodeUpdate":@"rewindAvailabilityUpdate"):@YES,@"rewindReminder":@{@"schema":@1,@"notificationID":NSUUID.UUID.UUIDString,@"kind":kind,@"profileID":profile,@"titleID":title,@"videoID":RT(video)}};
}
+ (NSDictionary *)destination:(NSDictionary *)userInfo state:(NSDictionary *)state show:(NSDictionary *)show rating:(NSDictionary *)rating now:(NSDate *)now {
    NSDictionary *p=RD(RD(userInfo)[@"rewindReminder"]);NSString *kind=RT(p[@"kind"]),*owner=RT(p[@"profileID"]),*title=RT(p[@"titleID"]),*video=RT(p[@"videoID"]);
    if(![p[@"schema"]isEqual:@1]||![[NSUUID alloc]initWithUUIDString:RT(p[@"notificationID"]) ]||!RI(owner)||!RI(title)||![@[@"episode",@"availability"]containsObject:kind])return nil;
    NSDictionary *profile=RD(RD(state[@"profiles"])[owner]);if(![profile[@"maxAge"]isKindOfClass:NSNumber.class]||[profile[@"maxAge"]integerValue]<-1||[profile[@"maxAge"]integerValue]>18||[profile[@"hidden"]containsObject:title]||![RWRatingPolicy allows:rating age:[profile[@"maxAge"]integerValue]])return nil;
    NSDictionary *meta=nil,*episode=nil;
    if([kind isEqual:@"episode"]){
        NSDictionary *follow=RD(RD(profile[@"following"])[title]);if(!follow.count||![profile[@"episodeNotifications"]boolValue]||!RI(video)||[RD(RD(profile[@"history"])[video])[@"completed"]boolValue])return nil;
        meta=[show[@"id"]isEqual:title]?show:RD(follow[@"meta"]);if(![meta[@"type"]isEqual:@"series"])return nil;
        for(NSDictionary *e in [RWTVPolicy episodes:meta])if([e[@"id"]isEqual:video]){episode=e;break;}
        if(!episode){NSDictionary *e=RD(RD(RD(profile[@"episodeUpdates"])[title])[@"episode"]);if([e[@"id"]isEqual:video])episode=e;}
        if(!episode||![RWTVPolicy released:episode now:now]||[episode[@"season"]integerValue]<1||[episode[@"episode"]integerValue]<1)return nil;
    }else{
        NSDictionary *watch=RD(RD(profile[@"availabilityWatch"])[title]);meta=RD(RD(profile[@"availabilityUpdates"])[title]);
        if(!watch.count||!meta.count||![@[@"movie",@"series"]containsObject:meta[@"type"]?:@""]||([RT(watch[@"videoID"])length]&&![watch[@"videoID"]isEqual:video]))return nil;
        if([meta[@"type"]isEqual:@"series"]){
            if(!RI(video)||![watch[@"videoID"]isEqual:video]||[RD(RD(profile[@"history"])[video])[@"completed"]boolValue])return nil;
            if([show[@"id"]isEqual:title]){for(NSDictionary *e in [RWTVPolicy episodes:show])if([e[@"id"]isEqual:video]){episode=e;break;}if(!episode||![RWTVPolicy released:episode now:now])return nil;meta=show;}
            // A cold app may have evicted full episode metadata. Open the exact
            // title and let its normal details request resolve this video ID;
            // never substitute a different episode while it loads.
        }
    }
    if(![meta[@"id"]isEqual:title])return nil;
    if(episode&&![RWTVPolicy episodes:meta].count){NSMutableDictionary *brief=[meta mutableCopy];brief[@"videos"]=@[episode];meta=brief;}
    return @{@"profileID":owner,@"meta":meta,@"episode":episode?:@{},@"videoID":video,@"kind":kind};
}
+ (NSDictionary *)presentation:(NSDictionary *)meta mode:(NSString *)mode following:(BOOL)following watching:(BOOL)watching alerts:(BOOL)alerts {
    BOOL series=[meta[@"type"]isEqual:@"series"],episode=series&&[mode isEqual:@"Coming soon"]&&[meta[@"scheduledEpisode"]isKindOfClass:NSDictionary.class];
    if(series&&[mode isEqual:@"Following"])return @{@"kind":@"manage",@"title":@"Reminders",@"icon":@"more-horizontal",@"enable":@NO};
    if(episode)return @{@"kind":@"episode",@"title":following?(alerts?@"Reminder set":@"Enable alerts"):@"Remind me",@"icon":following&&alerts?@"check":@"plus",@"enable":@(!following||!alerts)};
    return @{@"kind":@"availability",@"title":watching?@"Reminder set":@"Remind me",@"icon":watching?@"check":@"plus",@"enable":@(!watching)};
}
@end
