#import <Foundation/Foundation.h>
#import "../RWAudioPolicy.h"
static NSString *AVMediaTypeAudio=@"audio";
@interface AVAssetTrack:NSObject
@property(nonatomic,strong) NSString *mediaType;
@end
@implementation AVAssetTrack @end
@interface AVPlayerItemTrack:NSObject
@property(nonatomic,strong) AVAssetTrack *assetTrack;
@property(nonatomic) BOOL enabled;
@end
@implementation AVPlayerItemTrack @end
@interface AVPlayerItem:NSObject
@property(nonatomic,strong) NSArray *tracks;
@end
@implementation AVPlayerItem @end
@interface AVPlayer:NSObject
@property(nonatomic,strong) AVPlayerItem *currentItem;
@property(nonatomic) BOOL muted;
@property(nonatomic) float volume;
@end
@implementation AVPlayer @end
@interface RewindStore:NSObject
@property(nonatomic,strong) NSMutableDictionary *state,*profiles;
@property(nonatomic) NSUInteger saves;
+ (instancetype)shared;
- (NSMutableDictionary *)profile;
- (void)save;
@end
@implementation RewindStore
+ (instancetype)shared {static RewindStore *store;static dispatch_once_t once;dispatch_once(&once,^{store=[RewindStore new];store.state=[@{@"activeProfile":@"a"}mutableCopy];store.profiles=[@{@"a":[NSMutableDictionary new],@"b":[NSMutableDictionary new]}mutableCopy];});return store;}
- (NSMutableDictionary *)profile{return self.profiles[self.state[@"activeProfile"]];}
- (void)save{self.saves++;}
@end
@interface RewindPlayer:NSObject
@property(nonatomic,strong) NSString *audioProfileID,*videoID;
@property(nonatomic,strong) NSMutableDictionary *audioProfileSnapshot;
@property(nonatomic,strong) NSDictionary *source,*audioSelection;
@property(nonatomic,strong) NSArray *audioChoices;
@property(nonatomic,strong) AVPlayer *player;
@property(nonatomic) BOOL transient,closing;
@end
@implementation RewindPlayer
#include "../RewindAudio.inc"
@end
static int checks,failures;
static void Check(BOOL ok,NSString *message){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",message.UTF8String);}}
static RewindPlayer *Player(void){RewindPlayer *p=[RewindPlayer new];p.videoID=@"episode:1:2";p.source=@{@"infoHash":@"0123456789abcdef0123456789abcdef01234567",@"fileIdx":@3};[p captureAudioPreferences];return p;}
int main(){@autoreleasepool{
    RewindStore *store=RewindStore.shared;NSDictionary *track=[RWAudioPolicy tracks:@[@{@"id":@2,@"name":@"French",@"language":@"fr",@"codec":@"AAC",@"channels":@2,@"compatible":@YES}]].firstObject;
    RewindPlayer *p=Player();Check([[p audioPreference][@"language"]isEqual:@"en"],@"New player starts with English");
    p.transient=YES;[p rememberAudioChoice:track];
    Check([[p audioPreference][@"language"]isEqual:@"fr"],@"Diagnostic selection survives within the player");
    Check(!store.saves&&![store profile][@"audioSelections"],@"Transient player never writes real preference");
    p=Player();[p rememberAudioChoice:track];Check(store.saves==1,@"Explicit selection performs one normal save");
    NSData *json=[NSJSONSerialization dataWithJSONObject:store.profiles options:0 error:nil];
    store.profiles=[[NSJSONSerialization JSONObjectWithData:json options:NSJSONReadingMutableContainers error:nil]mutableCopy];
    p=Player();Check([[p audioPreference][@"token"]isEqual:track[@"token"]],@"New player recovers persisted choice from JSON");
    p.source=@{@"infoHash":p.source[@"infoHash"],@"fileIdx":@4};
    Check(![p audioPreference][@"token"]&&[[p audioPreference][@"language"]isEqual:@"fr"],@"Changed file keeps only language/role intent");
    NSDictionary *before=[store.profiles[@"a"]copy];store.state[@"activeProfile"]=@"b";[p rememberAudioChoice:track];
    Check(store.saves==1&&[store.profiles[@"a"]isEqual:before]&&![store profile][@"audioSelections"],@"Late callback after profile switch writes neither profile");
    RewindPlayer *b=Player();Check([[b audioPreference][@"language"]isEqual:@"en"],@"Other profile does not inherit French choice");
    b.closing=YES;[b rememberAudioChoice:track];Check(store.saves==1,@"Closing player suppresses stale save");
    b.closing=NO;b.source=@{@"infoHash":p.source[@"infoHash"]};[b rememberAudioChoice:track];Check(store.saves==1,@"Unresolved file cannot persist choice");
    b=Player();b.player=[AVPlayer new];b.player.currentItem=[AVPlayerItem new];NSMutableArray *items=[NSMutableArray new];
    for(int i=0;i<3;i++){AVPlayerItemTrack *t=[AVPlayerItemTrack new];t.assetTrack=[AVAssetTrack new];t.assetTrack.mediaType=AVMediaTypeAudio;t.enabled=YES;[items addObject:t];}
    b.player.currentItem.tracks=items;NSDictionary *choice=@{@"descriptor":track,@"track":items[1]};b.audioChoices=@[choice];
    Check([b selectNativeAudio:choice remember:YES],@"Normal native manual-selection action succeeds");
    Check(![items[0]enabled]&&[items[1]enabled]&&![items[2]enabled],@"All other audio tracks disabled, including incompatible ones");
    Check(store.saves==2&&[[b audioPreference][@"language"]isEqual:@"fr"],@"Successful manual native action saves its actual choice");
    Check(b.player.volume==1&&!b.player.muted,@"Selected track audible at player output setting");
    Check(![b selectNativeAudio:@{@"descriptor":track,@"track":items[0]} remember:YES]&&store.saves==2,@"Stale/unknown menu choice is rejected");
    b.player.currentItem.tracks=@[items[0]];Check(![b selectNativeAudio:choice remember:YES]&&store.saves==2,@"Previous-source item cannot alter new player");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
