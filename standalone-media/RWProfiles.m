#import "RWProfiles.h"
#import <CommonCrypto/CommonKeyDerivation.h>
#import <Security/Security.h>
static NSArray *Keys(){return @[@"history",@"saved",@"hidden",@"liked",@"intros",@"sources",@"quality",@"subtitleLanguage",@"subtitlesEnabled",@"subtitleSize",@"subtitleDelay",@"audioLanguage",@"audioSelections",@"subtitleForced",@"subtitleSDH",@"subtitleSelections",@"subtitleAdjustments",@"subtitleLinks",@"autoplayTrailers",@"following",@"episodeUpdates",@"episodeNotifications",@"selectedSeasons",@"unfollowedShows",@"sourceAvailability",@"availabilityWatch",@"availabilityUpdates",@"discoveryPreferences",@"discoveryExposures",@"discoveryFetch"];}
@implementation RWProfiles
+ (NSMutableDictionary *)make:(NSString *)name age:(NSInteger)age {
    return [@{@"name":name.length?name:@"Viewer",@"maxAge":@(age),@"history":[NSMutableDictionary new],@"saved":[NSMutableArray new],@"hidden":[NSMutableArray new],@"liked":[NSMutableArray new],@"intros":[NSMutableDictionary new],@"sources":[NSMutableDictionary new],@"quality":@0,@"subtitleLanguage":@"en",@"subtitlesEnabled":@YES,@"subtitleSize":@24,@"subtitleDelay":@0,@"autoplayTrailers":@YES,@"following":[NSMutableDictionary new],@"episodeUpdates":[NSMutableDictionary new],@"selectedSeasons":[NSMutableDictionary new],@"episodeNotifications":@NO,@"unfollowedShows":[NSMutableArray new],@"sourceAvailability":[NSMutableDictionary new],@"availabilityWatch":[NSMutableDictionary new],@"availabilityUpdates":[NSMutableDictionary new],@"discoveryPreferences":[@{@"languageMode":@"english_first",@"worldCinema":@YES,@"excludeBollywood":@NO,@"worldMinRating":@7.5}mutableCopy],@"discoveryExposures":[NSMutableDictionary new]}mutableCopy];
}
+ (void)prepare:(NSMutableDictionary *)state {
    if(![state[@"profiles"]isKindOfClass:NSDictionary.class]||![state[@"profiles"]count]){
        NSMutableDictionary *main=[self make:@"Main" age:-1];for(NSString *k in Keys())if(state[k])main[k]=state[k];
        state[@"profiles"]=[NSMutableDictionary dictionaryWithObject:main forKey:@"main"];state[@"activeProfile"]=@"main";
    }
    NSMutableDictionary *profiles=[state[@"profiles"]mutableCopy];state[@"profiles"]=profiles;
    for(NSString *key in [profiles.allKeys copy]){
        NSDictionary *old=profiles[key];if(![old isKindOfClass:NSDictionary.class]){[profiles removeObjectForKey:key];continue;}
        NSInteger age=[old[@"maxAge"]isKindOfClass:NSNumber.class]?[old[@"maxAge"]integerValue]:0;
        if(age < -1 || age > 18)age=0;
        NSMutableDictionary *p=[self make:[old[@"name"]isKindOfClass:NSString.class]?old[@"name"]:@"Viewer" age:age];
        for(NSString *k in Keys())if(old[k])p[k]=old[k];
        for(NSString *k in @[@"history",@"intros",@"sources",@"following",@"episodeUpdates",@"selectedSeasons",@"sourceAvailability",@"availabilityWatch",@"availabilityUpdates",@"discoveryPreferences",@"discoveryExposures",@"discoveryFetch"])p[k]=[p[k]isKindOfClass:NSDictionary.class]?[p[k]mutableCopy]:[NSMutableDictionary new];
        // Preserve optional playback maps through the same cold-start normalization.
        // Do not add empty maps to unrelated existing profiles.
        for(NSString *k in @[@"audioSelections",@"subtitleSelections",@"subtitleAdjustments",@"subtitleLinks"])if(p[k]){if([p[k]isKindOfClass:NSDictionary.class])p[k]=[p[k]mutableCopy];else [p removeObjectForKey:k];}
        for(NSString *k in @[@"saved",@"hidden",@"liked",@"unfollowedShows"])p[k]=[p[k]isKindOfClass:NSArray.class]?[p[k]mutableCopy]:[NSMutableArray new];profiles[key]=p;
    }
    if(!profiles.count)profiles[@"main"]=[self make:@"Main" age:-1];
    // A visible Kids choice is available immediately; preserve every existing
    // profile, age limit and history when upgrading an older installation.
    if([state[@"profilePickerVersion"]integerValue]<25){
        BOOL hasKids=NO;for(NSDictionary *p in profiles.allValues)if([p[@"maxAge"]integerValue]>=0)hasKids=YES;
        if(!hasKids&&profiles.count<6){NSString *key=profiles[@"kids"]?NSUUID.UUID.UUIDString:@"kids";profiles[key]=[self make:@"Kids" age:12];profiles[key][@"autoplayTrailers"]=@NO;}
        state[@"profilePickerVersion"]=@25;
    }
    if([state[@"discoveryPreferencesVersion"]integerValue]<34){
        NSString *preferred=profiles[@"main"]?@"main":state[@"activeProfile"];if(!profiles[preferred?:@""]||[profiles[preferred][@"maxAge"]integerValue]>=0){preferred=nil;for(NSString *candidate in [profiles.allKeys sortedArrayUsingSelector:@selector(compare:)])if([profiles[candidate][@"maxAge"]integerValue]<0){preferred=candidate;break;}}
        if(preferred&&[profiles[preferred][@"maxAge"]integerValue]<0)profiles[preferred][@"discoveryPreferences"]=[@{@"languageMode":@"english_first",@"worldCinema":@YES,@"excludeBollywood":@YES,@"worldMinRating":@7.5}mutableCopy];
        state[@"discoveryPreferencesVersion"]=@34;
    }
    if(![state[@"activeProfile"]isKindOfClass:NSString.class]||!profiles[state[@"activeProfile"]])state[@"activeProfile"]=profiles[@"main"]?@"main":[profiles.allKeys sortedArrayUsingSelector:@selector(compare:)].firstObject;
}
+ (NSMutableDictionary *)active:(NSMutableDictionary *)state {return state[@"profiles"][state[@"activeProfile"]];}
+ (BOOL)requiresPINFrom:(NSDictionary *)from to:(NSDictionary *)to {return NO;}
+ (BOOL)validPIN:(NSString *)pin {return [pin isKindOfClass:NSString.class]&&pin.length>=4&&pin.length<=6&&[pin rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"].invertedSet].location==NSNotFound;}
+ (NSData *)derive:(NSString *)pin salt:(NSData *)salt {
    if(![self validPIN:pin]||salt.length!=16)return nil;NSMutableData *key=[NSMutableData dataWithLength:32];NSData *password=[pin dataUsingEncoding:NSUTF8StringEncoding];
    int status=CCKeyDerivationPBKDF(kCCPBKDF2,(const char *)password.bytes,password.length,(const uint8_t *)salt.bytes,salt.length,kCCPRFHmacAlgSHA256,50000,(uint8_t *)key.mutableBytes,key.length);return status==0?key:nil;
}
+ (NSDictionary *)credential:(NSString *)pin {
    NSMutableData *salt=[NSMutableData dataWithLength:16];if(SecRandomCopyBytes(kSecRandomDefault,salt.length,(uint8_t *)salt.mutableBytes)!=errSecSuccess)return nil;NSData *key=[self derive:pin salt:salt];return key?@{@"salt":[salt base64EncodedStringWithOptions:0],@"hash":[key base64EncodedStringWithOptions:0]}:nil;
}
+ (BOOL)verifyPIN:(NSString *)pin credential:(NSDictionary *)credential {
    if(![credential[@"salt"]isKindOfClass:NSString.class]||![credential[@"hash"]isKindOfClass:NSString.class])return NO;
    NSData *salt=[[NSData alloc]initWithBase64EncodedString:credential[@"salt"] options:0],*expected=[[NSData alloc]initWithBase64EncodedString:credential[@"hash"] options:0],*actual=[self derive:pin salt:salt];
    if(actual.length!=32||expected.length!=32)return NO;const uint8_t *a=(const uint8_t *)actual.bytes,*b=(const uint8_t *)expected.bytes;uint8_t difference=0;for(int i=0;i<32;i++)difference|=a[i]^b[i];return difference==0;
}
@end
