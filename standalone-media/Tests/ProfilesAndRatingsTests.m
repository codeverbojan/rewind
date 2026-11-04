#import <Foundation/Foundation.h>
#import "../RWProfiles.h"
#import "../RWRatingPolicy.h"
static NSDictionary *Statement(id value){return @{@"mainsnak":@{@"datavalue":@{@"value":value}},@"rank":@"normal"};}
int main(int argc,char **argv){@autoreleasepool{__block int checks=0,failures=0;void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *label){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",label.UTF8String);}};
NSMutableDictionary *state=[@{@"history":[@{@"tt1":@{@"position":@42}}mutableCopy],@"saved":[@[@{@"id":@"tt1"}]mutableCopy],@"subtitleLanguage":@"en"}mutableCopy];
[RWProfiles prepare:state];check([[RWProfiles active:state][@"history"]count]==1,@"Upgrade preserves existing watch history");check([[RWProfiles active:state][@"saved"]count]==1,@"Upgrade preserves saved titles");check([[RWProfiles active:state][@"maxAge"]intValue]==-1,@"Existing main profile remains unrestricted");
check([state[@"profiles"]count]==2&&[state[@"profiles"][@"kids"][@"maxAge"]intValue]==12,@"Upgrade creates immediately usable Kids choice with visible age limit");
check(![state[@"profiles"][@"kids"][@"history"]count]&&! [state[@"profiles"][@"kids"][@"autoplayTrailers"]boolValue],@"Kids starts without adult history or autoplay previews");
[RWProfiles prepare:state];check([state[@"profiles"]count]==2,@"Relaunch never duplicates the default Kids profile");
state[@"profiles"][@"kids"]=[RWProfiles make:@"Kids" age:10];state[@"activeProfile"]=@"kids";[RWProfiles active:state][@"history"][@"tt2"]=@{@"position":@9};[RWProfiles active:state][@"subtitleSize"]=@28;
check(![RWProfiles active:state][@"history"][@"tt1"],@"Child history does not expose main history");check(!state[@"profiles"][@"main"][@"history"][@"tt2"],@"Child progress cannot overwrite main progress");
[RWProfiles prepare:state];check([state[@"activeProfile"]isEqual:@"kids"]&&[[RWProfiles active:state][@"subtitleSize"]intValue]==28,@"Active profile and subtitle preferences survive migration again");
check(![RWProfiles requiresPINFrom:state[@"profiles"][@"kids"] to:state[@"profiles"][@"main"]],@"Requested one-tap profile switching needs no PIN");
check(![RWProfiles requiresPINFrom:state[@"profiles"][@"kids"] to:[RWProfiles make:@"Teen" age:15]],@"Choosing another profile does not initiate PIN setup");
check(![RWProfiles requiresPINFrom:state[@"profiles"][@"kids"] to:[RWProfiles make:@"Young" age:7]],@"Switching to stricter profile does not need PIN");
check([RWProfiles validPIN:@"1234"]&&! [RWProfiles validPIN:@"123"]&&![RWProfiles validPIN:@"1234x"],@"PIN requires 4–6 ASCII digits");
NSDictionary *pin=[RWProfiles credential:@"123456"];check([RWProfiles verifyPIN:@"123456" credential:pin],@"Correct parent PIN verifies");check(![RWProfiles verifyPIN:@"654321" credential:pin],@"Wrong parent PIN is rejected");check(![RWProfiles verifyPIN:@"123456" credential:@{}],@"Missing credentials do not unlock profiles");
check(![[pin description]containsString:@"123456"]&&![[RWProfiles credential:@"123456"]isEqual:pin],@"PIN stored as salted derivation, never plaintext");
NSDictionary *entity=@{@"id":@"Q123",@"claims":@{@"P345":@[Statement(@"tt123")],@"P1657":@[Statement(@{@"id":@"Q18665339"})]}};
NSDictionary *rating=[RWRatingPolicy recordForEntity:entity imdb:@"tt123"];
check([rating[@"minimumAge"]intValue]==13,@"PG-13 resolves to age group 13");check(![RWRatingPolicy allows:rating age:12]&&[RWRatingPolicy allows:rating age:13],@"Age boundary is enforced");
check(![RWRatingPolicy recordForEntity:entity imdb:@"tt124"],@"Similar title cannot bypass exact IMDb identity");
check(![RWRatingPolicy allows:nil age:17]&&[RWRatingPolicy allows:nil age:-1],@"Unrated hidden only in restricted profiles");
NSMutableDictionary *claims=[entity[@"claims"]mutableCopy];claims[@"P2629"]=@[Statement(@{@"id":@"Q4550895"})];NSDictionary *mixed=@{@"id":@"Q123",@"claims":claims};
check([[[RWRatingPolicy recordForEntity:mixed imdb:@"tt123"]objectForKey:@"minimumAge"]intValue]==15,@"Highest age across known rating systems wins");
claims[@"P2629"]=@[Statement(@{@"id":@"QUnknown"})];check(![RWRatingPolicy allows:[RWRatingPolicy recordForEntity:@{@"id":@"Q123",@"claims":claims} imdb:@"tt123"] age:18],@"Unrecognized rating cannot be silently ignored");
claims[@"P2629"]=@[[NSNull null]];check(![RWRatingPolicy allows:[RWRatingPolicy recordForEntity:@{@"id":@"Q123",@"claims":claims} imdb:@"tt123"] age:18],@"Malformed rating fails closed without a crash");
check(![RWRatingPolicy allows:(id)[NSNull null] age:10],@"Malformed cache entry is blocked");
double now=1792872000;
check([RWRatingPolicy needsLookup:nil type:@"movie" now:now],@"A missing film classification can be looked up");
check(![RWRatingPolicy needsLookup:@{@"minimumAge":@(-1),@"checked":@(now)} type:@"movie" now:now],@"Recent unknown film respects the one-day negative cache");
check([RWRatingPolicy needsLookup:@{@"minimumAge":@(-1),@"checked":@(now-86400)} type:@"movie" now:now],@"Unknown film becomes eligible exactly at the cache boundary");
check([RWRatingPolicy needsLookup:@{@"minimumAge":@(-1),@"checked":@(now),@"publisherAttempted":@YES} type:@"series" now:now],@"Old series policy gets one publisher upgrade attempt");
check(![RWRatingPolicy needsLookup:@{@"minimumAge":@(-1),@"checked":@(now),@"publisherPolicy":@3} type:@"series" now:now],@"Current series policy respects the same negative-cache boundary");
check([RWRatingPolicy needsLookup:@{@"minimumAge":@(-1),@"checked":@(now-86400),@"publisherPolicy":@3} type:@"series" now:now],@"Expired current series classification can be looked up again");
check(![RWRatingPolicy needsLookup:@{@"minimumAge":@10,@"checked":@(now-29*86400)} type:@"series" now:now],@"Known ratings keep the thirty-day freshness interval");
check([RWRatingPolicy needsLookup:@{@"minimumAge":@10,@"checked":@(now-30*86400)} type:@"movie" now:now],@"Expired known rating is refreshed by the service");
if(argc>1){NSData *data=[NSData dataWithContentsOfFile:@(argv[1])];NSDictionary *real=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];NSDictionary *toy=[RWRatingPolicy recordForEntity:real[@"tt0114709"] imdb:@"tt0114709"];
check([RWRatingPolicy allows:toy age:0],@"Verified Toy Story entity supplies a general-audience rating");check(![RWRatingPolicy allows:[RWRatingPolicy recordForEntity:real[@"tt0892769"] imdb:@"tt0892769"] age:7],@"PG title stays out of younger profile");check(![RWRatingPolicy allows:[RWRatingPolicy recordForEntity:real[@"tt8050740"] imdb:@"tt8050740"] age:0],@"Unrated series not inferred safe from its name or genre");}
state[@"profiles"][@"kids"][@"following"][@"tt123"]=@{@"seen":@[@"tt123:1:1"]};state[@"profiles"][@"kids"][@"episodeNotifications"]=@YES;state[@"profiles"][@"kids"][@"selectedSeasons"][@"tt123"]=@12;
[RWProfiles prepare:state];check(!state[@"profiles"][@"main"][@"following"][@"tt123"],@"Followed shows stay separate by profile");check([state[@"profiles"][@"kids"][@"selectedSeasons"][@"tt123"]intValue]==12,@"Selected season persists through relaunch migration");check([state[@"profiles"][@"kids"][@"episodeNotifications"]boolValue]&&![state[@"profiles"][@"main"][@"episodeNotifications"]boolValue],@"Notification preferences stay separate");
NSDictionary *publisher=@{@"imdb":@"tt7678620",@"label":@"TV-Y",@"source":@"https://www.disneyplus.com/browse/entity-fa6973b9-e7cf-49fb-81a2-d4908e4bf694"};
check([RWRatingPolicy allows:[RWRatingPolicy recordForPublisher:publisher imdb:@"tt7678620"] age:0],@"Exact publisher-rated preschool show is visible at the general audience limit");
check(![RWRatingPolicy recordForPublisher:publisher imdb:@"tt0073966"],@"Older adult show with the same name cannot inherit the preschool rating");
NSMutableDictionary *badPublisher=[publisher mutableCopy];badPublisher[@"source"]=@"https://www.disneyplus.com.evil.invalid/title";check(![RWRatingPolicy recordForPublisher:badPublisher imdb:@"tt7678620"],@"Lookalike publisher domain cannot grant a kids rating");
badPublisher=[publisher mutableCopy];badPublisher[@"label"]=@"Family";check(![RWRatingPolicy recordForPublisher:badPublisher imdb:@"tt7678620"],@"Family genre alone cannot grant an age rating");
NSDictionary *film=@{@"imdb":@"tt1727587",@"type":@"movie",@"region":@"US",@"label":@"PG",@"source":@"https://tv.apple.com/us/movie/sintel/umc.cmc.7f0aon834g9pnswy2qm3e7b3f"};
NSDictionary *filmRating=[RWRatingPolicy recordForPublisher:film imdb:@"tt1727587"];
check([RWRatingPolicy allows:filmRating age:12],@"Verified US publisher film rating admits Sintel to the older Kids profile");
check(![RWRatingPolicy allows:filmRating age:9]&&[RWRatingPolicy allows:filmRating age:10],@"Publisher PG uses the existing conservative Rewind age-ten policy");
check([filmRating[@"label"]isEqual:@"PG"]&&[filmRating[@"source"]isEqual:film[@"source"]],@"Rating retains its actual label and attribution");
for(NSString *label in @[@"G",@"PG",@"PG-13",@"R",@"NC-17"]){NSMutableDictionary *candidate=[film mutableCopy];candidate[@"label"]=label;NSDictionary *result=[RWRatingPolicy recordForPublisher:candidate imdb:@"tt1727587"];NSInteger age=[@{@"G":@0,@"PG":@10,@"PG-13":@13,@"R":@17,@"NC-17":@18}[label]integerValue];check(result&&[result[@"minimumAge"]integerValue]==age,@"US film categories match the existing policy");}
for(id label in @[@"Family",@"Unrated",NSNull.null,@[],@{}]){NSMutableDictionary *candidate=[film mutableCopy];candidate[@"label"]=label;check(![RWRatingPolicy recordForPublisher:candidate imdb:@"tt1727587"],@"Missing or malformed film classification never grants eligibility");}
for(NSString *field in @[@"region",@"type"]){NSMutableDictionary *candidate=[film mutableCopy];[candidate removeObjectForKey:field];check(![RWRatingPolicy recordForPublisher:candidate imdb:@"tt1727587"],@"Film classification requires explicit medium and jurisdiction");}
for(NSString *source in @[@"https://tv.apple.com/gb/movie/sintel/id",@"https://tv.apple.com/us/show/sintel/id",@"https://tv.apple.com/us/movie/",@"https://tv.apple.com.evil.invalid/us/movie/sintel/id",@"http://tv.apple.com/us/movie/sintel/id",@"https://www.disneyplus.com/us/movie/sintel/id"]){NSMutableDictionary *candidate=[film mutableCopy];candidate[@"source"]=source;check(![RWRatingPolicy recordForPublisher:candidate imdb:@"tt1727587"],@"Unsupported region, resource, or publisher cannot reinterpret a film rating");}
check(![RWRatingPolicy recordForPublisher:film imdb:@"tt0114709"],@"Sintel rating cannot be assigned to a different movie");
printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;}}
