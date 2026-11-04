#import <Foundation/Foundation.h>
enum {UIControlStateNormal=0};
static NSString *RWString(id v){return [v isKindOfClass:NSString.class]?v:@"";}
@interface Surface:NSObject
@property(copy) NSString *text;
- (void)setTitle:(NSString *)s forState:(NSInteger)state;
@end
@implementation Surface
- (void)setTitle:(NSString *)s forState:(NSInteger)state{self.text=s;}
@end
@interface Metrics:NSObject
@property(strong) NSMutableArray *events,*outcomes;
- (void)recordSourceOutcome:(NSDictionary *)o engine:(NSString *)e uptime:(double)t;
- (void)markStage:(NSString *)s uptime:(double)t;
- (void)setContext:(NSDictionary *)d;
- (void)recordDiscovery:(NSDictionary *)d uptime:(double)t;
- (void)recordEvent:(NSString *)s values:(NSDictionary *)d uptime:(double)t;
- (void)beginAttemptAtUptime:(double)t;
@end
@implementation Metrics
- (instancetype)init{if((self=[super init])){_events=[NSMutableArray new];_outcomes=[NSMutableArray new];}return self;}
- (void)recordSourceOutcome:(NSDictionary *)o engine:(NSString *)e uptime:(double)t{if(o)[self.outcomes addObject:o];}
- (void)markStage:(NSString *)s uptime:(double)t{}
- (void)setContext:(NSDictionary *)d{}
- (void)recordDiscovery:(NSDictionary *)d uptime:(double)t{}
- (void)recordEvent:(NSString *)s values:(NSDictionary *)d uptime:(double)t{[self.events addObject:@{@"event":s,@"values":d}];}
- (void)beginAttemptAtUptime:(double)t{}
@end
@interface RewindStore:NSObject
@property(strong) NSDictionary *state;
@property(strong) NSMutableArray *failures;
+ (instancetype)shared;
- (void)report:(NSDictionary *)d;
- (NSDictionary *)sourceFailed:(NSDictionary *)d;
@end
@implementation RewindStore
+ (instancetype)shared{static RewindStore *s;if(!s){s=[self new];s.state=@{};s.failures=[NSMutableArray new];}return s;}
- (void)report:(NSDictionary *)d{}
- (NSDictionary *)sourceFailed:(NSDictionary *)d{[self.failures addObject:d];return @{@"receipt":@(self.failures.count)};}
@end
@interface Engine:NSObject
@property NSInteger pauses;
- (void)pause;
@end
@implementation Engine
- (void)pause{self.pauses++;}
@end
@interface TorrentLoader:NSObject
- (instancetype)initWithEngine:(id)e name:(id)n size:(int64_t)s;
- (id)playerItem;
@end
@implementation TorrentLoader
- (instancetype)initWithEngine:(id)e name:(id)n size:(int64_t)s{return [super init];}
- (id)playerItem{return @"item";}
@end
@interface Player:NSObject
@property(strong) NSMutableSet *deadSwarms,*triedSources;
@property(strong) NSArray *ranked,*next;
@property(strong) NSDictionary *source,*lastTorrentSnapshot;
@property(strong) Surface *loadingTitle,*loadingDetail,*keepButton,*statusLabel;
@property(strong) Metrics *metrics;
@property(strong) Engine *engine;
@property(strong) id player,legacy;
@property(strong) TorrentLoader *loader;
@property NSInteger quality,starts,unavailable,updates;
@property BOOL discovering,sourceLookupPending,exerciseRecovery;
@property double attemptStarted,lastDownloadProgress;
@property int64_t lastPayload;
- (void)startNextSource;
- (void)showUnavailable:(NSString *)message;
- (void)updatePlayback;
- (void)failSource:(NSString *)message;
- (void)prepareLegacy:(id)value;
- (void)prepareItem:(id)item;
@end
@implementation Player
- (instancetype)init{if((self=[super init])){_deadSwarms=[NSMutableSet new];_triedSources=[NSMutableSet new];_metrics=[Metrics new];_engine=[Engine new];_loadingTitle=[Surface new];_loadingDetail=[Surface new];_keepButton=[Surface new];_statusLabel=[Surface new];}return self;}
- (void)startNextSource{self.starts++;self.next=[self remainingSources];}
- (void)showUnavailable:(NSString *)message{self.unavailable++;}
- (void)updatePlayback{self.updates++;}
- (void)failSource:(NSString *)message{self.unavailable++;}
- (void)prepareLegacy:(id)value{self.legacy=@YES;}
- (void)prepareItem:(id)item{self.player=item;}
#include "../RewindTorrentSelection.inc"
@end
int main(){@autoreleasepool{__block int checks=0,failures=0;void(^check)(BOOL)=^(BOOL ok){checks++;if(!ok){failures++;fprintf(stderr,"FAIL selection %d\n",checks);}};
NSDictionary *torrent=@{@"infoHash":@"0123456789012345678901234567890123456789",@"url":@"magnet:?xt=urn:btih:0123456789012345678901234567890123456789",@"fileIdx":@5},*direct=@{@"url":@"https://webtorrent.io/torrents/Sintel/Sintel.mp4"};
NSDictionary *ended=@{@"exhausted":@YES,@"failures":@[torrent]};
for(NSNumber *pending in @[@NO,@YES]){Player *p=[Player new];p.ranked=@[torrent,direct];p.sourceLookupPending=pending.boolValue;p.discovering=YES;
 [p consumeRace:ended snapshot:nil selected:nil];check(p.starts==1);check(p.unavailable==0);check([p.next isEqual:@[direct]]);check(!p.discovering&&p.engine.pauses==1);check(p.metrics.outcomes.count==1);check([p.metrics.events.lastObject[@"values"][@"remaining_direct"]integerValue]==1);
}
Player *spent=[Player new];spent.ranked=@[torrent,direct];[spent.triedSources addObject:[spent sourceKey:direct]];[spent consumeRace:ended snapshot:nil selected:nil];check(spent.starts==1&&spent.next.count==0);check(spent.deadSwarms.count==1);
Player *selected=[Player new];selected.ranked=@[torrent,direct];[selected consumeRace:@{@"selected":@YES,@"exhausted":@NO} snapshot:nil selected:torrent];check(selected.starts==0&&[selected.source isEqual:torrent]);check(selected.engine.pauses==0);
Player *busy=[Player new];busy.ranked=@[torrent,direct];busy.discovering=YES;[busy consumeRace:@{@"exhausted":@NO} snapshot:nil selected:nil];check(busy.starts==0&&busy.discovering&&busy.updates==1);
NSUInteger previous=RewindStore.shared.failures.count;[spent consumeRace:ended snapshot:nil selected:nil];check(RewindStore.shared.failures.count==previous);check(spent.metrics.outcomes.count==1);
Player *local=[Player new];[local consumeRace:@{@"exhausted":@YES,@"failures":@[@{@"infoHash":torrent[@"infoHash"],@"local_checking":@YES}]} snapshot:nil selected:nil];check(RewindStore.shared.failures.count==previous);
NSMutableDictionary *badFile=[torrent mutableCopy];badFile[@"filename"]=@"Wrong.S01E02.mkv";
NSMutableDictionary *goodFile=[badFile mutableCopy];goodFile[@"filename"]=@"Right.S01E01.mkv";
NSMutableDictionary *fileFailure=[badFile mutableCopy];fileFailure[@"failure_scope"]=@"file";
Player *variants=[Player new];variants.ranked=@[badFile,goodFile,direct];
[variants consumeRace:@{@"exhausted":@YES,@"failures":@[fileFailure]} snapshot:nil selected:nil];
check(variants.starts==1&&[variants.next isEqual:@[goodFile,direct]]);check(variants.deadSwarms.count==0);check(RewindStore.shared.failures.count==previous);
[variants consumeRace:@{@"exhausted":@YES,@"failures":@[fileFailure]} snapshot:nil selected:nil];
check(variants.triedSources.count==1&&[variants.next isEqual:@[goodFile,direct]]);
NSMutableDictionary *globalFailure=[fileFailure mutableCopy];globalFailure[@"failure_scope"]=@"swarm";
[variants consumeRace:@{@"exhausted":@YES,@"failures":@[globalFailure]} snapshot:nil selected:nil];
check(variants.deadSwarms.count==1&&[variants.next isEqual:@[direct]]);check(RewindStore.shared.failures.count==previous+1);
NSMutableDictionary *resolved=[torrent mutableCopy];resolved[@"resolvedFileIdx"]=@5;resolved[@"resolvedFilename"]=@"Show.S01E01.mkv";resolved[@"requestedVideoID"]=@"tt123:1:1";
Player *observed=[Player new];[observed consumeRace:@{@"selected":@YES} snapshot:nil selected:resolved];
NSDictionary *selection=observed.metrics.events.lastObject[@"values"];check([selection[@"resolved_file_index"]isEqual:@5]&&[selection[@"requested_video_id"]isEqual:@"tt123:1:1"]&&[selection[@"resolved_filename"]isEqual:@"Show.S01E01.mkv"]);
NSUInteger beforeFixture=RewindStore.shared.failures.count;
Player *fixture=[Player new];fixture.exerciseRecovery=YES;fixture.ranked=@[torrent];
[fixture consumeRace:ended snapshot:nil selected:nil];
check(RewindStore.shared.failures.count==beforeFixture&&fixture.metrics.outcomes.count==0);
check(fixture.deadSwarms.count==1&&fixture.starts==1);
printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;}}
