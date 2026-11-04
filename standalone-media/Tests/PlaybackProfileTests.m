#import <Foundation/Foundation.h>
#import "../RWProfiles.h"
static int checks,failures;
static void Check(BOOL ok,NSString *s){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",s.UTF8String);}}
int main(){@autoreleasepool{
    NSMutableDictionary *profile=[RWProfiles make:@"Viewer" age:-1];
    NSDictionary *preferences=@{@"subtitleLinks":@{@"identity":@{@"url":@"https://example.org/captions.srt",@"updated":@100}},@"audioLanguage":@"fr",@"audioSelections":@{@"title":@{@"token":@"example"}},@"subtitleForced":@YES,@"subtitleSDH":@YES,@"subtitleSelections":@{@"episode":@{@"enabled":@NO}},@"subtitleAdjustments":@{@"identity":@{@"delay":@0.5,@"encoding":@"windows-1251"}}};
    [profile addEntriesFromDictionary:preferences];profile[@"history"][@"kept"]=@{@"position":@42};
    NSMutableDictionary *state=[@{@"profiles":@{@"main":profile,@"other":[RWProfiles make:@"Other" age:-1]},@"activeProfile":@"main",@"profilePickerVersion":@25,@"discoveryPreferencesVersion":@34}mutableCopy];
    NSData *data=[NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
    state=[[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil]mutableCopy];
    [RWProfiles prepare:state];
    for(NSString *key in preferences)Check([[RWProfiles active:state][key]isEqual:preferences[key]],[key stringByAppendingString:@" survives actual application profile normalization"]);
    Check([[RWProfiles active:state][@"history"][@"kept"][@"position"]intValue]==42,@"Existing viewing position preserved");
    for(NSString *key in preferences)Check(!state[@"profiles"][@"other"][key],@"Absent preference not injected into unrelated profile");
    [RWProfiles prepare:state];Check([[RWProfiles active:state][@"subtitleSelections"]isEqual:preferences[@"subtitleSelections"]],@"Repeated normalization retains title choice");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
