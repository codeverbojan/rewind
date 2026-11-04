#import "RWPlaybackMetrics.h"
#include <math.h>
@implementation RWPlaybackMetrics {
    double _started,_attemptStart,_lastTime,_lastPosition,_playing,_stalling,_firstFrame,_peakRSS,_firstAdvancing,_expectedStart;
    NSUInteger _stalls,_attempts;BOOL _wasStalling;NSMutableArray *_samples;NSDictionary *_resources;
    NSMutableDictionary *_stages,*_context,*_probeRecords;NSMutableArray *_events;
    NSDictionary *_discovery,*_firstLookup;NSUInteger _probeDrops;
    NSMutableArray *_sourceOutcomes;NSUInteger _sourceOutcomeDrops,_sourceOutcomeInvalid;
    NSString *_sessionID;BOOL _lastReady,_lastWantsPlay,_lastSeeking;
}
- (instancetype)initAtUptime:(double)uptime {if((self=[super init])){_started=uptime;_lastTime=uptime;_lastPosition=NAN;_firstFrame=_firstAdvancing=-1;_samples=[NSMutableArray new];_events=[NSMutableArray new];_resources=@{};_stages=[NSMutableDictionary new];_context=[NSMutableDictionary new];_sessionID=NSUUID.UUID.UUIDString;_context[@"started_at_unix_seconds"]=@(NSDate.date.timeIntervalSince1970);}return self;}
- (NSString *)sessionID {return _sessionID;}
- (void)setContext:(NSDictionary *)context {
    if(![context isKindOfClass:NSDictionary.class]||![NSJSONSerialization isValidJSONObject:context])return;
    NSData *data=[NSJSONSerialization dataWithJSONObject:context options:0 error:nil];if(!data.length||data.length>64*1024)return;
    NSDictionary *owned=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    for(NSString *key in owned){
        if(_context[key]&&[@[@"video_id",@"profile_id",@"build",@"type",@"requested_quality",@"requested_position_seconds",@"started_at_unix_seconds"]containsObject:key])continue;
        _context[key]=owned[key];
    }
}
- (void)recordDiscovery:(NSDictionary *)discovery uptime:(double)uptime {
    if(![discovery isKindOfClass:NSDictionary.class]||!isfinite(uptime)||uptime<_started)return;
    if(!_probeRecords)_probeRecords=[NSMutableDictionary new];
    for(NSString *group in @[@"candidates",@"failures"]){
        NSUInteger visited=0;for(NSDictionary *sample in discovery[group]){
            if(++visited>12)break;NSString *hash=sample[@"infoHash"];if(![hash isKindOfClass:NSString.class]||hash.length!=40)continue;
            NSString *engine=[discovery[@"session_id"]isKindOfClass:NSString.class]?discovery[@"session_id"]:@"";
            NSString *key=[NSString stringWithFormat:@"%@:%@:%@",engine,hash,sample[@"fileIdx"]?:@(-1)];
            if(!_probeRecords[key]&&_probeRecords.count>=12){_probeDrops++;continue;}
            NSMutableDictionary *record=[_probeRecords[key]mutableCopy]?:[NSMutableDictionary new];
            for(NSString *field in @[@"infoHash",@"fileIdx",@"provider",@"quality",@"seeders_hint",@"seeds_connected",@"peers",@"tracker_peers",@"dht_peers",@"video_bytes",@"piece_bytes",@"rate_sample_seconds",@"measured_bytes_per_second",@"required_bytes_per_second_estimate",@"duration_seconds",@"duration_basis",@"duration_probe_state",@"startup_transfer_eta_seconds",@"verified_prefix_bytes",@"startup_verified_bytes",@"ready",@"selectable",@"video_complete",@"local_checking",@"focus_held",@"reason",@"timing",@"cache_at_start"])
                if(sample[field])record[field]=sample[field];
            // Preserve the engine's aggregate observer evidence after a race
            // ends. Own nested values and bound retained data per source.
            if(sample[@"peer_discovery"]){
                NSDictionary *observation=sample[@"peer_discovery"];
                NSData *data=[observation isKindOfClass:NSDictionary.class]&&[NSJSONSerialization isValidJSONObject:observation]?[NSJSONSerialization dataWithJSONObject:observation options:0 error:nil]:nil;
                NSDictionary *owned=data.length&&data.length<=32*1024?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
                if(owned){record[@"peer_discovery"]=owned;[record removeObjectForKey:@"peer_discovery_status"];}
                else{[record removeObjectForKey:@"peer_discovery"];record[@"peer_discovery_status"]=@"invalid_or_oversize";}
            }
            if(sample[@"transport"]){
                NSDictionary *observation=sample[@"transport"];
                NSData *data=[observation isKindOfClass:NSDictionary.class]&&[NSJSONSerialization isValidJSONObject:observation]?[NSJSONSerialization dataWithJSONObject:observation options:0 error:nil]:nil;
                NSDictionary *owned=data.length&&data.length<=8192?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
                if(owned){record[@"transport"]=owned;[record removeObjectForKey:@"transport_status"];}
                else{[record removeObjectForKey:@"transport"];record[@"transport_status"]=@"invalid_or_oversize";}
            }
            NSDictionary *timing=sample[@"timing"];
            if([timing[@"probe_started_uptime"]isKindOfClass:NSNumber.class])record[@"probe_started_from_play_seconds"]=@([timing[@"probe_started_uptime"]doubleValue]-_started);
            record[@"engine_session_id"]=engine;if([group isEqual:@"candidates"]&&!sample[@"reason"])[record removeObjectForKey:@"reason"];
            record[@"observed_from_play_seconds"]=@(uptime-_started);record[@"failed"]=@([group isEqual:@"failures"]);
            // These dictionaries contain only engine-owned immutable JSON.
            _probeRecords[key]=[record copy];
        }
    }
    NSMutableDictionary *summary=[NSMutableDictionary new];
    for(NSString *key in @[@"session_id",@"active",@"selected",@"exhausted",@"max_parallel",@"checked",@"total",@"source_queue_limit",@"waiting_sources",@"focus",@"dht_state_loaded"])
        if(discovery[key])summary[key]=discovery[key];
    _discovery=[summary copy];
}
// A race admits at most12 candidates and a player permits5 attempts; user
// retries can extend a session. Keep256 terminal writes (<=1MiB serialized),
// never evict earlier receipts, and report overflow rather than imply coverage.
- (void)recordSourceOutcome:(NSDictionary *)outcome engine:(NSString *)engine uptime:(double)uptime {
    if(!outcome)return; // HTTP/asset sources have no persisted swarm record.
    if(![outcome isKindOfClass:NSDictionary.class]||!isfinite(uptime)||uptime<_started){_sourceOutcomeInvalid++;return;}
    NSString *key=outcome[@"key"];NSDictionary *record=outcome[@"record"];
    if(![key isKindOfClass:NSString.class]||key.length>48||![record isKindOfClass:NSDictionary.class]||![outcome[@"success"]isKindOfClass:NSNumber.class]||![outcome[@"at"]isKindOfClass:NSNumber.class]){_sourceOutcomeInvalid++;return;}
    if(!_sourceOutcomes)_sourceOutcomes=[NSMutableArray new];
    if(_sourceOutcomes.count>=256){_sourceOutcomeDrops++;return;}
    NSMutableDictionary *entry=[NSMutableDictionary new];for(NSString *field in @[@"key",@"success",@"at",@"record",@"trimmed_keys"])if(outcome[field])entry[field]=outcome[field];
    entry[@"elapsed_seconds"]=@(uptime-_started);entry[@"sequence"]=@(_sourceOutcomes.count+1);
    entry[@"engine_session_id"]=[engine isKindOfClass:NSString.class]&&engine.length<=64?engine:@"";
    NSData *data=[NSJSONSerialization isValidJSONObject:entry]?[NSJSONSerialization dataWithJSONObject:entry options:0 error:nil]:nil;
    if(!data.length||data.length>4096){_sourceOutcomeInvalid++;return;}
    [_sourceOutcomes addObject:[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]];
}
- (void)setExpectedStartPosition:(double)position {if(isfinite(position)&&position>=0){_expectedStart=position;_context[@"effective_start_position_seconds"]=@(position);}}
- (void)recordLookupObservation:(NSDictionary *)observation quality:(NSInteger)quality uptime:(double)uptime {
    if(![observation[@"foreground"]boolValue]||!isfinite(uptime)||uptime<_started)return;
    if(![observation[@"requested_quality"]isKindOfClass:NSNumber.class]||[observation[@"requested_quality"]integerValue]!=quality)return;
    for(NSString *key in @[@"video_id",@"profile_id",@"type"])
        if(!_context[key]||![observation[key]isEqual:_context[key]])return;
    if(![observation[@"lookup_id"]isKindOfClass:NSString.class]||[observation[@"lookup_id"]length]>64)return;
    [self setContext:@{@"source_lookup":observation}];
    [self recordEvent:@"source_lookup_observed" values:_context[@"source_lookup"] uptime:uptime];
}
- (void)noteSeek {_lastSeeking=YES;_lastPosition=NAN;_wasStalling=NO;}
- (void)markStage:(NSString *)stage uptime:(double)uptime {if(stage.length&&stage.length<=64&&_stages.count<32&&!_stages[stage]&&isfinite(uptime)&&uptime>=_started)_stages[stage]=@(uptime-_started);}
- (void)recordEvent:(NSString *)event values:(NSDictionary *)values uptime:(double)uptime {
    if(!event.length||event.length>64||!isfinite(uptime)||uptime<_started)return;
    if(_events.count>=64)[_events removeObjectAtIndex:0];
    NSDictionary *entry=@{@"event":event,@"elapsed_seconds":@(uptime-_started),@"values":[values copy]?:@{}};
    [_events addObject:entry];if(!_firstLookup&&[event isEqual:@"source_lookup_completed"])_firstLookup=entry;
}
- (void)beginAttemptAtUptime:(double)uptime {_attempts++;_attemptStart=uptime;_lastTime=uptime;_lastPosition=NAN;_wasStalling=NO;_lastReady=_lastWantsPlay=_lastSeeking=NO;}
- (void)recordAtUptime:(double)uptime position:(double)position ready:(BOOL)ready wantsPlay:(BOOL)wantsPlay frameVisible:(BOOL)frameVisible {
    [self recordAtUptime:uptime position:position ready:ready wantsPlay:wantsPlay frameVisible:frameVisible seeking:NO];
}
- (void)recordAtUptime:(double)uptime position:(double)position ready:(BOOL)ready wantsPlay:(BOOL)wantsPlay frameVisible:(BOOL)frameVisible seeking:(BOOL)seeking {
    if(!isfinite(uptime)||uptime<_lastTime)return;
    if(frameVisible&&_firstFrame<0){_firstFrame=uptime-_started;[self markStage:@"first_frame" uptime:uptime];}
    // Even a short seek between samples invalidates the next movement interval.
    if(seeking)_lastSeeking=YES;
    double elapsed=uptime-_lastTime;if(elapsed<.4)return;
    double delta=position-_lastPosition;
    // A suspended app or a seek is not continuous decoding or a stall.
    BOOL interval=elapsed<=3&&isfinite(position)&&isfinite(_lastPosition)&&!seeking&&!_lastSeeking;
    BOOL advanced=interval&&delta>.05&&delta<=elapsed*2+1;
    BOOL playing=advanced&&ready&&_lastReady&&wantsPlay&&_lastWantsPlay&&frameVisible&&(_firstAdvancing>=0||position>=_expectedStart-.5);
    if(playing&&position>=_expectedStart-.5&&_firstAdvancing<0){_firstAdvancing=uptime-_started;[self markStage:@"advancing_playback" uptime:uptime];}
    BOOL stalled=interval&&_firstAdvancing>=0&&ready&&_lastReady&&wantsPlay&&_lastWantsPlay&&fabs(delta)<=.05;
    if(playing)_playing+=MIN(elapsed,delta);
    if(stalled){_stalling+=elapsed;if(!_wasStalling)_stalls++;}
    _wasStalling=stalled;_lastTime=uptime;_lastPosition=position;
    _lastReady=ready;_lastWantsPlay=wantsPlay;_lastSeeking=seeking;
}
- (void)recordResources:(NSDictionary *)resources {
    _resources=[resources copy];double rss=[resources[@"resident_bytes"]doubleValue];if(isfinite(rss))_peakRSS=MAX(_peakRSS,rss);
    NSMutableDictionary *sample=[resources mutableCopy];sample[@"elapsed_seconds"]=@(_lastTime-_started);sample[@"position"]=@(isfinite(_lastPosition)?_lastPosition:0);sample[@"session_id"]=_sessionID;
    if(_samples.count>=720)[_samples removeObjectAtIndex:0];[_samples addObject:sample];
}
- (NSArray *)samples {return [_samples copy];}
- (NSDictionary *)snapshot {return @{@"schema_version":@4,@"source_outcomes":[_sourceOutcomes copy]?:@[],@"source_outcome_limit":@256,@"source_outcome_drops":@(_sourceOutcomeDrops),@"source_outcome_invalid":@(_sourceOutcomeInvalid),@"source_outcome_complete":@(!_sourceOutcomeDrops&&!_sourceOutcomeInvalid),@"first_source_lookup":_firstLookup?:@{},@"torrent_discovery":_discovery?:@{},@"torrent_probes":[_probeRecords.allValues copy]?:@[],@"probe_record_limit":@12,@"probe_record_drops":@(_probeDrops),@"session_id":_sessionID,@"context":[_context copy],@"events":[_events copy],@"attempts":@(_attempts),@"elapsed_seconds":@(_lastTime-_started),@"first_frame_seconds":@(_firstFrame),@"first_advancing_playback_seconds":@(_firstAdvancing),@"startup_stages_seconds":[_stages copy],@"timing_basis":@"Seconds since Play was requested; retries included. first_frame means display-ready content, not advancing playback. advancing_playback requires verified media, visible content and movement at the effective start position outside seeking.",@"playing_seconds_estimate":@(_playing),@"stall_seconds_estimate":@(_stalling),@"stall_events":@(_stalls),@"peak_resident_bytes":@(_peakRSS),@"latest_resources":_resources,@"sample_count":@(_samples.count),@"sample_limit":@720,@"audio_audibility":@"Requires listener confirmation"};}
@end
