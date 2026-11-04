#import <Foundation/Foundation.h>
#import "../RWSourceExperience.h"
#import "../RWSourcePolicy.h"
#import "../RWPlaybackMetrics.h"
@interface Store:NSObject
@property(strong) NSMutableDictionary *state;
@property NSUInteger saves;
- (void)saveForReason:(NSString *)reason;
@end
@implementation Store
- (instancetype)init{if((self=[super init]))_state=[NSMutableDictionary new];return self;}
- (void)saveForReason:(NSString *)reason{_saves++;}
#include "../RewindSourceExperience.inc"
@end
static int checks,failures;
static void check(BOOL b,const char *name){checks++;if(!b){failures++;fprintf(stderr,"FAIL %s\n",name);}}
static NSDictionary *video(){return @{@"width":@1920,@"height":@1080,@"fps":@24,@"videoCodec":@"avc1",@"profile":@100,@"level":@41,@"aacStereo":@YES};}
static NSMutableDictionary *source(int i){return [@{@"infoHash":[NSString stringWithFormat:@"%040x",i+1],@"fileIdx":@0,@"resolvedFileIdx":@0,@"filename":@"Film.1080p.WEB-DL.H264.AAC.mp4",@"url":@"magnet:test"}mutableCopy];}
int main(){@autoreleasepool{
 [RWSourcePolicy setLegacyEnabled:YES];NSDictionary *cap=[RWSourcePolicy capabilities];NSString *capkey=[RWSourcePolicy mediaCapabilityKey:cap];NSMutableDictionary *m=[video()mutableCopy];
 check([[RWSourcePolicy mediaAssessment:m quality:0][@"status"]isEqual:@"compatible"],"ordinary compatible media");
 NSArray *cases=@[@[@"width",@0,@"unknown",@"dimensions_unknown"],@[@"width",@3840,@"incompatible",@"dimensions_exceeded"],@[@"videoCodec",@"",@"unknown",@"codec_unknown"],@[@"videoCodec",@"hvc1",@"incompatible",@"codec_unsupported"],@[@"fps",@0,@"unknown",@"frame_rate_unknown"],@[@"fps",@60,@"incompatible",@"frame_rate_exceeded"],@[@"profile",@0,@"unknown",@"h264_parameters_unknown"],@[@"profile",@110,@"incompatible",@"h264_unsupported"],@[@"level",@0,@"unknown",@"h264_parameters_unknown"],@[@"level",@51,@"incompatible",@"h264_unsupported"],@[@"aacStereo",@NO,@"policy",@"audio_unavailable"]];
 for(NSArray *c in cases){m=[video()mutableCopy];m[c[0]]=c[1];NSDictionary *a=[RWSourcePolicy mediaAssessment:m quality:0];check([a[@"status"]isEqual:c[2]]&&[a[@"code"]isEqual:c[3]],"typed media assessment");}
 check([[RWSourcePolicy mediaAssessment:video() quality:720][@"status"]isEqual:@"policy"],"quality mismatch is a request policy");
 m=[video()mutableCopy];m[@"width"]=@3840;m[@"height"]=@2160;NSDictionary *oversize=[RWSourcePolicy mediaAssessment:m quality:0];NSMutableDictionary *s=source(1);
 NSDictionary *r=[RWSourceExperience record:nil source:s success:NO assessment:oversize capability:capkey now:100];
 NSDictionary *decorated=[RWSourceExperience sourceForRanking:s record:r capability:capkey now:200];
 check(decorated[@"localMediaRejection"]!=nil,"exact resolved torrent file gets local proof");
 check(![[RWSourcePolicy evaluate:decorated quality:0 freeBytes:0][@"eligible"]boolValue],"verified oversize skipped on a later request");
 check(![[RWSourcePolicy evaluate:decorated quality:1080 freeBytes:0][@"eligible"]boolValue],"verified oversize remains skipped for selected quality");
 NSMutableDictionary *other=[s mutableCopy];other[@"fileIdx"]=@1;
 check(![RWSourceExperience sourceForRanking:other record:r capability:capkey now:200][@"localMediaRejection"],"other file is not excluded");
 other=[s mutableCopy];[other removeObjectForKey:@"fileIdx"];
 check(![RWSourceExperience sourceForRanking:other record:r capability:capkey now:200][@"localMediaRejection"],"implicit file selection is not a proven match");
 check(![RWSourceExperience sourceForRanking:s record:r capability:@"changed" now:200][@"localMediaRejection"],"capability changes discard exclusion");
 check(![RWSourceExperience sourceForRanking:s record:r capability:capkey now:100+7*86400][@"localMediaRejection"],"proof expires at seven days");
 check(![RWSourceExperience sourceForRanking:s record:r capability:capkey now:99][@"localMediaRejection"],"clock rollback cannot prolong proof");
 other=[s mutableCopy];[other removeObjectForKey:@"resolvedFileIdx"];
 NSDictionary *unresolved=[RWSourceExperience record:nil source:other success:NO assessment:oversize capability:capkey now:100];check(!unresolved[@"media_incompatibility"],"unverified file index never creates proof");
 NSMutableDictionary *injected=[decorated mutableCopy];injected[@"infoHash"]=source(2)[@"infoHash"];
 check([[RWSourcePolicy evaluate:injected quality:0 freeBytes:0][@"eligible"]boolValue],"proof bound to original hash at policy boundary");
 injected=[decorated mutableCopy];NSMutableDictionary *proof=[injected[@"localMediaRejection"]mutableCopy];proof[@"evidence"]=video();injected[@"localMediaRejection"]=proof;
 check([[RWSourcePolicy evaluate:injected quality:0 freeBytes:0][@"eligible"]boolValue],"claimed incompatible code must match facts");
 check(![RWSourceExperience sourceForRanking:decorated record:nil capability:capkey now:200][@"localMediaRejection"],"stale cache decoration removed without local record");
 check(![RWSourcePolicy normalize:decorated provider:@"Test"][@"localMediaRejection"],"provider proof stripped");
 m=[video()mutableCopy];m[@"width"]=@0;NSDictionary *unknown=[RWSourcePolicy mediaAssessment:m quality:0];
 NSDictionary *ur=[RWSourceExperience record:nil source:s success:NO assessment:unknown capability:capkey now:100];check([ur[@"failure_kind"]isEqual:@"metadata"]&&!ur[@"media_incompatibility"],"unknown facts get transient metadata failure");
 check([[RWSourcePolicy evaluate:[RWSourceExperience sourceForRanking:s record:ur capability:capkey now:101] quality:0 freeBytes:0][@"eligible"]boolValue],"unknown media remains eligible");
 NSDictionary *qr=[RWSourceExperience record:nil source:s success:NO assessment:[RWSourcePolicy mediaAssessment:video() quality:720] capability:capkey now:100];
 check(!qr[@"media_incompatibility"]&&![[RWSourceExperience hints:qr now:101][@"localFailure"]boolValue],"quality mismatch does not poison Auto rank");
 NSDictionary *ok=[RWSourceExperience record:r source:s success:YES now:201];check(!ok[@"media_incompatibility"],"confirmed successful playback clears stale exclusion");
 Store *store=[Store new];NSDictionary *receipt=[store sourceFailed:s mediaAssessment:oversize];NSString *key=[RWSourceExperience keyForSource:s];
 check([receipt[@"record"]isEqual:store.state[@"sourceExperience"][key]],"receipt equals actual persisted record");
 check([receipt[@"key"]isEqual:key]&&!receipt[@"url"]&&store.saves==1,"actual save has canonical source identity");
 check(![[RWSourcePolicy rank:[store withSourceExperience:@[s]] quality:0 freeBytes:0]count],"real store to rank excludes exact incompatible file");
 [store sourceSucceeded:s];check([[RWSourcePolicy rank:[store withSourceExperience:@[s]] quality:0 freeBytes:0]count]==1,"real success restores eligibility");
 RWPlaybackMetrics *metrics=[[RWPlaybackMetrics alloc]initAtUptime:0];
 for(int i=0;i<150;i++){
  NSMutableDictionary *candidate=source(i);candidate[@"reason"]=@"No peers";candidate[@"url"]=@"https://secret.invalid/?token=private";
  NSDictionary *o=[store sourceFailed:candidate];[metrics recordSourceOutcome:o engine:@"race-1" uptime:1+i];
  [metrics recordDiscovery:@{@"session_id":@"race-1",@"failures":@[candidate]} uptime:1+i];
 }
 NSDictionary *snap=[metrics snapshot];check([snap[@"torrent_probes"]count]==12&&[snap[@"probe_record_drops"]intValue]>0,"reproduce rolling probe saturation");
 check([snap[@"source_outcomes"]count]==150&&[snap[@"source_outcome_complete"]boolValue],"all terminal writes survive rolling probe saturation");
 NSMutableDictionary *replayed=[NSMutableDictionary new];for(NSDictionary *o in snap[@"source_outcomes"]){replayed[o[@"key"]]=o[@"record"];[replayed removeObjectsForKeys:o[@"trimmed_keys"]];}
 check([replayed isEqual:store.state[@"sourceExperience"]],"independent journal replay matches entire trimmed source history");
 NSData *json=[NSJSONSerialization dataWithJSONObject:snap options:0 error:nil];check([[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding].length>0,"journal serializes");
 // Probe records contain controlled error prose; neither journal nor store leaks URLs.
 NSString *journal=[[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:snap[@"source_outcomes"] options:0 error:nil] encoding:NSUTF8StringEncoding];check(![journal containsString:@"secret.invalid"]&&! [journal containsString:@"private"],"terminal journal excludes source URL and token");
 NSMutableDictionary *nested=[@{@"failure_count":@1}mutableCopy];NSMutableDictionary *outcome=[@{@"key":key,@"success":@NO,@"at":@100,@"record":nested,@"trimmed_keys":@[]}mutableCopy];[metrics recordSourceOutcome:outcome engine:@"race-2" uptime:200];NSDictionary *before=[metrics snapshot];nested[@"failure_count"]=@77;
 check([before[@"source_outcomes"][150][@"record"][@"failure_count"]intValue]==1,"receipt owns nested mutable input");
 for(int i=151;i<270;i++)[metrics recordSourceOutcome:receipt engine:@"race-3" uptime:201+i];
 snap=[metrics snapshot];check([snap[@"source_outcomes"]count]==256&&[snap[@"source_outcome_drops"]intValue]==14&&! [snap[@"source_outcome_complete"]boolValue],"bounded journal overflow explicit");
 check([before[@"source_outcomes"]count]==151,"published journal snapshot does not grow");
 RWPlaybackMetrics *bad=[[RWPlaybackMetrics alloc]initAtUptime:0];[bad recordSourceOutcome:@{@"bad":@YES} engine:nil uptime:1];[bad recordSourceOutcome:receipt engine:nil uptime:NAN];
 NSMutableDictionary *huge=[receipt mutableCopy];huge[@"record"]=@{@"text":[@"x" stringByPaddingToLength:5000 withString:@"x" startingAtIndex:0]};[bad recordSourceOutcome:huge engine:nil uptime:1];
 check([bad snapshot][@"source_outcome_invalid"]&&[[bad snapshot][@"source_outcome_invalid"]intValue]==3&&![[bad snapshot][@"source_outcome_complete"]boolValue],"invalid oversized receipts never silently imply complete coverage");
 check(![RWSourceExperience keyForSource:@{@"infoHash":s[@"infoHash"],@"fileIdx":@0.5}],"fractional index cannot alias a proven file");
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
