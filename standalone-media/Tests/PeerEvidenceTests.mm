#import <Foundation/Foundation.h>
#define RW_PEER_EVIDENCE_IMPLEMENTATION 1
#include "../RWPeerEvidence.h"
using namespace RWPeerEvidence;
static NSMutableArray*checks;
static void Check(NSString*name,bool pass){[checks addObject:@{@"case":name,@"passed":@(pass)}];}
static RWTrackerObservation Event(void const*owner,std::string const&url,unsigned kind,unsigned count=0,unsigned peer=1){
    RWTrackerObservation e{};e.version=1;e.kind=kind;e.torrent=owner;e.url=url.data();e.url_length=uint32_t(url.size());e.count=count;
    e.address_length=4;e.address[0]=192;e.address[1]=0;e.address[2]=2;e.address[3]=uint8_t(peer);e.port=uint16_t(6000+peer);return e;
}
int main(){@autoreleasepool{
    checks=[NSMutableArray new];int owner=0,other=0;auto state=std::make_shared<State>();Check(@"Owner registration",Register(&owner,state));
    std::string a="https://tracker.example/a?opaque=PrivateFixtureSecret",b="https://tracker.example/b?pass=OtherFixtureSecret";
    auto response=Event(&owner,a,RWTrackerResponse,4);Check(@"Observer registered",RWObserveTracker(&response));
    auto start=Event(&owner,a,RWTrackerDNSStarted);RWObserveTracker(&start);
    response=Event(&owner,b,RWTrackerResponse,1);RWObserveTracker(&response);
    auto epb=Event(&owner,b,RWTrackerEndpoint,1,2);RWObserveTracker(&epb);
    auto epa=Event(&owner,a,RWTrackerEndpoint,1,1);RWObserveTracker(&epa);
    auto resolved=Event(&owner,a,RWTrackerDNSResolved);RWObserveTracker(&resolved);
    auto keya=Key(epa.address,4,epa.port,0),keyb=Key(epb.address,4,epb.port,0);
    state->discovered(keya,1,false);state->discovered(keyb,1,false);state->connected(keya);state->handshake(keya);state->payload(keya,1000);state->disconnected(keya);
    NSDictionary*s=Snapshot(state);NSArray*ts=s[@"trackers"];
    Check(@"Delayed DNS endpoint retains tracker A",[ts[0][@"payload_bytes"]unsignedLongLongValue]==1000&&[ts[1][@"payload_bytes"]unsignedLongLongValue]==0);
    Check(@"Reported entries separate from unique peers",[ts[0][@"reported_peer_entries"]intValue]==4&&[ts[0][@"peers"]intValue]==1);
    Check(@"DNS lifecycle recorded",[ts[0][@"dns_started"]intValue]==1&&[ts[0][@"dns_resolved"]intValue]==1);
    Check(@"Unproductive tracker has no useful peers",[ts[1][@"peers"]intValue]==1&&[ts[1][@"useful_peers"]intValue]==0);
    Check(@"Connection and handshake distinct",[ts[0][@"connections"]intValue]==1&&[ts[0][@"handshakes"]intValue]==1);
    Check(@"Disconnected payload retained",[ts[0][@"disconnections"]intValue]==1&&[ts[0][@"payload_bytes"]intValue]==1000);
    // Same endpoint later returned by B and DHT/PEX: overlapping membership,
    // never a second copy of the actual payload in unique totals.
    double lateStart=Clock()-state->created;auto duplicate=Event(&owner,b,RWTrackerEndpoint,1,1);RWObserveTracker(&duplicate);RWObserveTracker(&duplicate);
    state->discovered(keya,2|4,false);state->connected(keya);state->payload(keya,500);state->disconnected(keya);
    s=Snapshot(state);ts=s[@"trackers"];
    Check(@"Duplicate endpoint deduplicated",[ts[1][@"peers"]intValue]==2);
    Check(@"Late tracker receives only subsequent bytes",[ts[0][@"payload_bytes"]intValue]==1500&&[ts[1][@"payload_bytes"]intValue]==500);
    Check(@"Late tracker excluded payload stays explicit",[ts[1][@"payload_before_discovery"]intValue]==1000);
    Check(@"Late tracker cannot claim an earlier connection",[ts[1][@"connections"]intValue]==1);
    Check(@"Late tracker first payload follows discovery",[ts[1][@"first_payload_seconds"]doubleValue]>=lateStart);
    Check(@"Unique payload not double counted",[s[@"unique"][@"payload_bytes"]intValue]==1500&&[s[@"unique"][@"peers"]intValue]==2);
    Check(@"DHT and PEX overlap retained",[s[@"routes"][@"dht"][@"payload_bytes"]intValue]==500&&[s[@"routes"][@"pex"][@"payload_bytes"]intValue]==500&&[s[@"overlapping_peers"]intValue]==1);
    Check(@"Reconnect adds connection without new peer",[ts[0][@"connected_peers"]intValue]==1&&[ts[0][@"connections"]intValue]==2&&[ts[0][@"disconnections"]intValue]==2);
    Check(@"Tracker identifiers reveal no URL",[ts[0][@"tracker_id"]intValue]==1&&[ts[1][@"tracker_id"]intValue]==2&&ts[0][@"url"]==nil);
    NSData*json=[NSJSONSerialization dataWithJSONObject:s options:0 error:nil];NSString*text=[[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding];
    Check(@"No credentials or endpoint text serialized",[text rangeOfString:@"PrivateFixtureSecret"].location==NSNotFound&&[text rangeOfString:@"OtherFixtureSecret"].location==NSNotFound&&[text rangeOfString:@"192.0.2"].location==NSNotFound&&[text rangeOfString:@"tracker.example"].location==NSNotFound);
    auto independent=std::make_shared<State>();Register(&other,independent);independent->discovered(keya,4,false);independent->payload(keya,7);
    Check(@"Torrent states isolated",[Snapshot(independent)[@"unique"][@"payload_bytes"]intValue]==7&&[Snapshot(state)[@"unique"][@"payload_bytes"]intValue]==1500);
    Check(@"Owner cannot be silently replaced",!Register(&owner,independent));Unregister(&owner,independent);Check(@"Wrong owner cleanup cannot erase state",Lookup(&owner)==state);
    auto filtered=Event(&owner,a,RWTrackerEndpoint,1,3);RWObserveTracker(&filtered);auto keyf=Key(filtered.address,4,filtered.port,0);state->discovered(keyf,1,true);
    s=Snapshot(state);Check(@"Filtered peer stays distinct from accepted",[s[@"unique"][@"filtered_observations"]intValue]==1&&[s[@"unique"][@"accepted"]intValue]==2);
    auto bad=Event(&owner,a,RWTrackerDNSFailed);RWObserveTracker(&bad);response=Event(&owner,a,RWTrackerResponse,0);response.stopped=1;RWObserveTracker(&response);
    s=Snapshot(state);Check(@"DNS failure recorded",[s[@"trackers"][0][@"dns_failed"]intValue]==1);Check(@"Stopped replies labelled",[s[@"trackers"][0][@"stopped_responses"]intValue]==1);
    auto bounded=std::make_shared<State>();int limitOwner=0;Register(&limitOwner,bounded);
    for(unsigned i=0;i<300;i++){auto e=Event(&limitOwner,a,RWTrackerEndpoint,1,i);RWObserveTracker(&e);bounded->payload(Key(e.address,4,e.port,0),1);}
    s=Snapshot(bounded);Check(@"Endpoint memory bounded",[s[@"unique"][@"peers"]intValue]==256&&[s[@"endpoint_overflow_events"]intValue]>0);
    Check(@"Overflow payload remains visible",[s[@"unattributed_payload_bytes"]intValue]==44&&[s[@"unique"][@"payload_bytes"]intValue]==256);
    for(unsigned i=0;i<40;i++){std::string u="https://x.invalid/"+std::to_string(i);auto e=Event(&limitOwner,u,RWTrackerResponse);RWObserveTracker(&e);}
    s=Snapshot(bounded);Check(@"Tracker map bounded",[s[@"trackers"]count]==16&&[s[@"tracker_overflow_events"]intValue]>0);
    std::string giant(2049,'x');auto giantEvent=Event(&owner,giant,RWTrackerResponse);Check(@"Oversized tracker cannot allocate",!RWObserveTracker(&giantEvent));
    Check(@"Counters saturate",Add(UINT64_MAX-5,10)==UINT64_MAX);
    auto invalid=Event(&owner,a,RWTrackerResponse);invalid.version=2;Check(@"Unknown observer ABI rejected",!RWObserveTracker(&invalid));
    Unregister(&owner,state);Check(@"Removed torrent cannot receive observations",!RWObserveTracker(&response));Unregister(&other,independent);Unregister(&limitOwner,bounded);
    std::vector<int> owners(MaxTorrents+1);std::vector<std::shared_ptr<State>> states;
    for(size_t i=0;i<MaxTorrents;i++){states.push_back(std::make_shared<State>());Register(&owners[i],states.back());}
    Check(@"Registry bounded",!Register(&owners.back(),std::make_shared<State>()));
    for(size_t i=0;i<MaxTorrents;i++)Unregister(&owners[i],states[i]);
    Check(@"Registry cleaned",registry().states.empty());
    unsigned failures=0;for(NSDictionary*c in checks)if(![c[@"passed"]boolValue])++failures;
    NSData*result=[NSJSONSerialization dataWithJSONObject:@{@"checks":@(checks.count),@"failures":@(failures),@"cases":checks} options:0 error:nil];puts([[NSString alloc]initWithData:result encoding:NSUTF8StringEncoding].UTF8String);return failures?1:0;
}}
