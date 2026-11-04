#import <Foundation/Foundation.h>
#import "../RWSubtitlePolicy.h"
@interface RewindStore:NSObject
@property(nonatomic,strong) NSMutableDictionary *state,*profiles;
@property(nonatomic) NSUInteger saves;
+ (instancetype)shared;
- (NSMutableDictionary *)profile;
- (void)save;
@end
@implementation RewindStore
+ (instancetype)shared {static RewindStore *s;static dispatch_once_t once;dispatch_once(&once,^{s=[RewindStore new];s.state=[@{@"activeProfile":@"a"}mutableCopy];s.profiles=[@{@"a":[@{@"subtitleLanguage":@"en",@"subtitlesEnabled":@YES,@"subtitleDelay":@7}mutableCopy],@"b":[@{@"subtitleLanguage":@"fr",@"subtitlesEnabled":@YES}mutableCopy]}mutableCopy];});return s;}
- (NSMutableDictionary *)profile {return self.profiles[self.state[@"activeProfile"]];}
- (void)save {self.saves++;}
@end
@interface RewindPlayer:NSObject
@property(nonatomic,strong) NSString *subtitleProfileID,*videoID,*subtitleContentDigest,*subtitleEncodingChoice;
@property(nonatomic,strong) NSDictionary *source,*subtitleDescriptor,*subtitleAddedFile;
@property(nonatomic,strong) NSMutableDictionary *subtitleProfileSnapshot,*transientSubtitlePreferences;
@property(nonatomic) BOOL transient,closing;
@property(nonatomic) double subtitleDelay;
@end
@implementation RewindPlayer
#include "../RewindSubtitleState.inc"
@end
static int checks,failures;
static void Check(BOOL ok,NSString *s){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",s.UTF8String);}}
static RewindPlayer *Player(void){RewindPlayer *p=[RewindPlayer new];p.videoID=@"tt123:1:1";p.source=@{@"infoHash":@"0123456789abcdef0123456789abcdef01234567",@"resolvedFileIdx":@3};[p captureSubtitlePreferences];return p;}
int main(){@autoreleasepool{
    RewindStore *s=RewindStore.shared;RewindPlayer *p=Player();
    Check(![p subtitlePreferences][@"subtitleDelay"]&&[s.profile[@"subtitleDelay"]intValue]==7,@"Legacyglobaldelaypreservedbutnotinnewplayersnapshot");
    p.subtitleDescriptor=[RWSubtitlePolicy descriptor:@{@"language":@"ru",@"sdh":@YES}kind:@"external" locator:@"https://subs.test/release.srt"];p.subtitleContentDigest=[RWSubtitlePolicy digest:[@"bytesA" dataUsingEncoding:NSUTF8StringEncoding]];p.subtitleEncodingChoice=@"windows-1251";p.subtitleDelay=1.5;
    [p rememberSubtitleChoice:YES];[p rememberSubtitleAdjustment];NSString *key=[p subtitleAdjustmentKey];
    Check([s.profile[@"subtitleSelections"]count]==1&&[s.profile[@"subtitleAdjustments"]count]==1,@"Realplayerusesnormalsavedprofilemaps");
    NSDictionary *d=p.subtitleDescriptor;NSString *hash=p.subtitleContentDigest;
    NSData *json=[NSJSONSerialization dataWithJSONObject:s.profiles options:0 error:nil];s.profiles=[[NSJSONSerialization JSONObjectWithData:json options:NSJSONReadingMutableContainers error:nil]mutableCopy];
    p=Player();p.subtitleDescriptor=d;p.subtitleContentDigest=hash;Check([[p subtitlePreference][@"token"]isEqual:d[@"token"]]&&[[p subtitlePreference][@"sdh"]boolValue],@"ExacttracklanguageSDHsurviveJSONprocessboundary");
    Check([[p subtitleAdjustment][@"delay"]doubleValue]==1.5&&[[p subtitleAdjustment][@"encoding"]isEqual:@"windows-1251"],@"Exactcaptionencodinganddelayrestore");
    p.subtitleContentDigest=[RWSubtitlePolicy digest:[@"bytesB" dataUsingEncoding:NSUTF8StringEncoding]];Check(![p subtitleAdjustment].count,@"SameURLchangedcaptioncannotinheritdelayorencoding");p.subtitleContentDigest=hash;
    p.videoID=@"tt123:1:2";Check(![p subtitleAdjustment].count&&![[p subtitlePreference]objectForKey:@"token"],@"Nextepisodekeepsitsownsubtitlepreference");p.videoID=@"tt123:1:1";
    NSDictionary *a=[s.profiles[@"a"]copy],*b=[s.profiles[@"b"]copy];NSUInteger saves=s.saves;s.state[@"activeProfile"]=@"b";
    [p setSubtitlePreference:@"subtitleSize" value:@28];[p rememberSubtitleChoice:NO];p.subtitleDelay=3;[p rememberSubtitleAdjustment];
    Check(s.saves==saves&&[s.profiles[@"a"]isEqual:a]&&[s.profiles[@"b"]isEqual:b],@"Delayedcallbackafterprofileswitchwritesneitherprofile");
    RewindPlayer *other=Player();Check(![other subtitlePreference][@"token"]&&[[other subtitlePreference][@"language"]isEqual:@"fr"],@"Otherprofileusesownlanguageandnooldtrack");
    s.state[@"activeProfile"]=@"a";p=Player();p.transient=YES;p.subtitleDescriptor=d;p.subtitleContentDigest=hash;p.subtitleEncodingChoice=@"auto";p.subtitleDelay=-1;
    [p rememberSubtitleAdjustment];[p rememberSubtitleChoice:NO];[p setSubtitlePreference:@"subtitleSize" value:@28];
    Check(s.saves==saves&&[s.profiles[@"a"]isEqual:a]&&[[p subtitleAdjustment][@"delay"]doubleValue]==-1,@"Transientdiagnosticchangesstaylocal");
    p=Player();[p setSubtitlesEnabled:NO];Check(![[p subtitlePreference][@"enabled"]boolValue]&&[s.profile[@"subtitlesEnabled"]boolValue],@"TitleOffsavedwithoutturningoffothersglobally");
    p.videoID=@"tt123:1:2";Check(![p subtitlePreference][@"token"],@"Offhasnoexacttokenforanotheritem");
    p=Player();p.closing=YES;saves=s.saves;[p setSubtitlePreference:@"subtitleSize" value:@20];Check(s.saves==saves,@"Closingplayersuppressessaves");
    Check([s.profile[@"subtitleAdjustments"]objectForKey:key]!=nil&&[s.profile[@"subtitleDelay"]intValue]==7,@"Originalscopedoffsetandlegacyvaluepreserved");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
