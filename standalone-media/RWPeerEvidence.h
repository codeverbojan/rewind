#pragma once
#import <Foundation/Foundation.h>
#include "RWTrackerObserverABI.h"
#include <libtorrent/version.hpp>
#include <libtorrent/extensions.hpp>
#include <libtorrent/torrent_handle.hpp>
#include <libtorrent/peer_connection_handle.hpp>
#include <libtorrent/peer_connection.hpp>
#include <libtorrent/alert_types.hpp>
#include <libtorrent/stat.hpp>
#include <map>
#include <array>
#include <algorithm>
#include <mutex>
#include <memory>
#include <chrono>
#include <limits>
#include <cstring>
static_assert(LIBTORRENT_VERSION_NUM==10220,"Review observer boundary and peer statistics ABI before upgrade");
namespace RWPeerEvidence {
namespace lt=libtorrent;
constexpr size_t MaxPeers=256,MaxTrackers=16,MaxTorrents=32,MaxURL=2048;
inline double Clock(){return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();}
inline uint64_t Add(uint64_t a,uint64_t b){return b>UINT64_MAX-a?UINT64_MAX:a+b;}
// Binary address key is private to memory, never serialized.
inline std::string Key(uint8_t const*ip,unsigned length,uint16_t port,uint32_t scope){
    if(length!=4&&length!=16)return {};
    std::string k(1,char(length));k.append((char const*)ip,length);k.push_back(char(port>>8));k.push_back(char(port));
    for(int shift:{24,16,8,0})k.push_back(char(scope>>shift));return k;
}
inline std::string Key(lt::tcp::endpoint const&e){
    if(e.address().is_v4()){auto bytes=e.address().to_v4().to_bytes();return Key(bytes.data(),4,e.port(),0);}
    auto a=e.address().to_v6();auto bytes=a.to_bytes();return Key(bytes.data(),16,e.port(),a.scope_id());
}
struct Origin {
    uint64_t payload=0,connections=0,handshakes=0,disconnections=0,filtered=0;
    double firstConnected=-1,firstPayload=-1;
};
struct Peer {
    std::array<Origin,MaxTrackers> trackerOrigins;std::array<Origin,6> routeOrigins;
    uint16_t trackers=0;uint32_t routes=0;
    bool accepted=false;uint64_t filtered=0,connections=0,handshakes=0,disconnections=0,payload=0;
    double firstConnected=-1,firstPayload=-1;
};
inline Origin Baseline(Peer const&p){Origin o;o.payload=p.payload;o.connections=p.connections;o.handshakes=p.handshakes;o.disconnections=p.disconnections;o.filtered=p.filtered;return o;}
struct Tracker {
    std::string url;uint64_t requests=0,errors=0,responses=0,stopped=0,reported=0,dnsStarted=0,dnsResolved=0,dnsFailed=0;
    double firstResponse=-1;
};
struct Connection;
struct State {
    std::vector<std::weak_ptr<Connection>> live;uint64_t connectionOverflow=0;
    void flush(std::string const&key);
    void track(std::shared_ptr<Connection>const&connection);
    void rotatePending();
    bool rotateEnabled=false;double rotateUpdated=0,lastRotation=-1,lastRotatedAge=0;unsigned rotations=0;
    std::mutex mutex;std::map<std::string,Peer> peers;std::vector<Tracker> trackers;
    uint64_t endpointOverflow=0,trackerOverflow=0,unattributedPayload=0,unknownOriginEvents=0;
    double created=Clock();
    Peer* peer(std::string const&key){
        if(key.empty()){++unknownOriginEvents;return nullptr;}
        auto found=peers.find(key);if(found!=peers.end())return &found->second;
        if(peers.size()>=MaxPeers){++endpointOverflow;return nullptr;}
        return &peers.emplace(key,Peer{}).first->second;
    }
    int tracker(char const*url,size_t length){
        if(!url||length==0||length>MaxURL){++trackerOverflow;return -1;}
        for(size_t i=0;i<trackers.size();i++)if(trackers[i].url.size()==length&&!memcmp(trackers[i].url.data(),url,length))return int(i);
        if(trackers.size()>=MaxTrackers){++trackerOverflow;return -1;}
        Tracker t;t.url.assign(url,length);trackers.push_back(std::move(t));return int(trackers.size()-1);
    }
    bool observe(RWTrackerObservation const&e){
        std::lock_guard<std::mutex> lock(mutex);int id=tracker(e.url,e.url_length);if(id<0)return false;
        auto &t=trackers[size_t(id)];
        if(e.kind==RWTrackerResponse){++t.responses;t.reported=Add(t.reported,e.count);t.stopped+=e.stopped!=0;if(t.firstResponse<0)t.firstResponse=Clock()-created;}
        else if(e.kind==RWTrackerEndpoint){auto *p=peer(Key(e.address,e.address_length,e.port,e.scope));if(p&&!(p->trackers&(1u<<id))){p->trackerOrigins[size_t(id)]=Baseline(*p);p->trackers|=uint16_t(1u<<id);}}
        else if(e.kind==RWTrackerDNSStarted)++t.dnsStarted;
        else if(e.kind==RWTrackerDNSResolved)++t.dnsResolved;
        else if(e.kind==RWTrackerDNSFailed)++t.dnsFailed;
        return true;
    }
    void announce(char const*url,bool error){
        std::lock_guard<std::mutex> lock(mutex);size_t length=url?strnlen(url,MaxURL+1):0;int id=tracker(url,length);
        if(id>=0){if(error)++trackers[size_t(id)].errors;else ++trackers[size_t(id)].requests;}
    }
    void discovered(std::string const&key,uint32_t routes,bool filtered){
        std::lock_guard<std::mutex> lock(mutex);auto*p=peer(key);if(!p)return;for(unsigned i=0;i<6;i++)if((routes&(1u<<i))&&!(p->routes&(1u<<i)))p->routeOrigins[i]=Baseline(*p);p->routes|=routes;
        if(filtered)++p->filtered;else p->accepted=true;
    }
    void connected(std::string const&key){
        std::lock_guard<std::mutex> lock(mutex);auto*p=peer(key);if(!p)return;++p->connections;double now=Clock()-created;if(p->firstConnected<0)p->firstConnected=now;
        for(size_t i=0;i<MaxTrackers;i++)if((p->trackers&(1u<<i))&&p->trackerOrigins[i].firstConnected<0)p->trackerOrigins[i].firstConnected=now;
        for(unsigned i=0;i<6;i++)if((p->routes&(1u<<i))&&p->routeOrigins[i].firstConnected<0)p->routeOrigins[i].firstConnected=now;
    }
    void handshake(std::string const&key){std::lock_guard<std::mutex> lock(mutex);auto*p=peer(key);if(p)++p->handshakes;}
    void payload(std::string const&key,uint64_t delta){
        if(!delta)return;std::lock_guard<std::mutex> lock(mutex);auto*p=peer(key);
        if(!p){unattributedPayload=Add(unattributedPayload,delta);return;}p->payload=Add(p->payload,delta);double now=Clock()-created;if(p->firstPayload<0)p->firstPayload=now;
        for(size_t i=0;i<MaxTrackers;i++)if((p->trackers&(1u<<i))&&p->trackerOrigins[i].firstPayload<0)p->trackerOrigins[i].firstPayload=now;
        for(unsigned i=0;i<6;i++)if((p->routes&(1u<<i))&&p->routeOrigins[i].firstPayload<0)p->routeOrigins[i].firstPayload=now;
    }
    void disconnected(std::string const&key){std::lock_guard<std::mutex> lock(mutex);auto*p=peer(key);if(p)++p->disconnections;}
};
struct Registry{std::mutex mutex;std::map<void const*,std::weak_ptr<State>> states;};
inline Registry& registry(){static Registry r;return r;}
inline std::shared_ptr<State> Lookup(void const*owner){auto&r=registry();std::lock_guard<std::mutex>lock(r.mutex);auto found=r.states.find(owner);return found==r.states.end()?nullptr:found->second.lock();}
inline bool Register(void const*owner,std::shared_ptr<State>const&s){
    auto&r=registry();std::lock_guard<std::mutex>lock(r.mutex);
    for(auto it=r.states.begin();it!=r.states.end();)if(it->second.expired())it=r.states.erase(it);else ++it;
    if(r.states.size()>=MaxTorrents||r.states.count(owner))return false;r.states.emplace(owner,s);return true;
}
inline void Unregister(void const*owner,std::shared_ptr<State>const&s){auto&r=registry();std::lock_guard<std::mutex>lock(r.mutex);auto it=r.states.find(owner);if(it!=r.states.end()&&it->second.lock()==s)r.states.erase(it);}
// Network-thread callbacks only. No payload is copied and no protocol is handled.
struct Connection final:lt::peer_plugin {
    lt::peer_connection_handle connection;std::shared_ptr<State>state;std::string key;uint64_t seen=0;bool tcp=false,handshaken=false,ended=false;
    double began=Clock();
    Connection(lt::peer_connection_handle c,std::shared_ptr<State>s):connection(c),state(s),key(Key(c.remote())){if(!c.is_connecting())on_connected();}
    void sample(){
        auto c=connection.native_handle();if(!c)return;
        int64_t total=c->statistics().total_payload_download();if(total<0)return;
        uint64_t now=uint64_t(total);if(now>seen){state->payload(key,now-seen);seen=now;}
    }
    void on_connected()override{try{if(!tcp){tcp=true;state->connected(key);}}catch(...){} }
    bool on_handshake(lt::span<char const>)override{try{if(!handshaken){handshaken=true;state->handshake(key);}}catch(...){}return true;}
    bool on_piece(lt::peer_request const&,lt::span<char const>)override{try{sample();}catch(...){}return false;}
    void tick()override{try{sample();}catch(...){} }
    void on_disconnect(lt::error_code const&)override{try{if(!ended){sample();ended=true;state->disconnected(key);}}catch(...){} }
};
inline void State::flush(std::string const&key){
    // Network-thread only; sample partial payload before assigning a new origin.
    for(auto const&weak:live)if(auto connection=weak.lock())if(connection->key==key)connection->sample();
}
inline void State::track(std::shared_ptr<Connection>const&connection){
    live.erase(std::remove_if(live.begin(),live.end(),[](std::weak_ptr<Connection>const&w){return w.expired();}),live.end());
    if(live.size()<64)live.push_back(connection);else{std::lock_guard<std::mutex>lock(mutex);++connectionOverflow;}
}
// Only the discovery controller may arm this, with a fresh saturated/queued/
// zero-payload status. Network-thread rechecks protect established
// and uTP connections. Two replacements maximum; normal timeouts stay unchanged.
inline void State::rotatePending(){
    double now=Clock();{std::lock_guard<std::mutex>lock(mutex);if(!rotateEnabled||now-rotateUpdated>2||rotations>=2||(lastRotation>=0&&now-lastRotation<2))return;}
    std::shared_ptr<Connection> oldest;unsigned occupied=0;
    for(auto const&weak:live)if(auto c=weak.lock()){
        auto handle=c->connection;if(!handle.native_handle()||handle.is_disconnecting())continue;++occupied;
        // A connected but remotely choked peer does not make the other
        // pending attempts productive. Keep that established peer intact.
        if(c->seen||handle.native_handle()->statistics().total_payload_download()>0)return;
        lt::peer_info info;handle.get_peer_info(info);
        if(!handle.is_connecting()){
            if(c->handshaken&&(info.flags & lt::peer_info::remote_choked))continue;
            return;
        }
        if(!handle.is_outgoing()||c->handshaken)return;
        if(!(info.flags&lt::peer_info::utp_socket)&&now-c->began>=5&&handle.can_disconnect(lt::errors::timed_out)&&(!oldest||c->began<oldest->began))oldest=c;
    }
    if(occupied<13||!oldest)return;
    {std::lock_guard<std::mutex>lock(mutex);if(!rotateEnabled||now-rotateUpdated>2)return;++rotations;lastRotation=now;lastRotatedAge=now-oldest->began;}
    oldest->connection.disconnect(lt::errors::timed_out,lt::operation_t::connect);
}
inline void SetProbeTurnover(lt::torrent_handle const&handle,bool enabled){
    if(!handle.is_valid())return;auto s=Lookup(handle.native_handle().get());if(!s)return;
    std::lock_guard<std::mutex>lock(s->mutex);s->rotateEnabled=enabled;s->rotateUpdated=Clock();
}
struct Torrent final:lt::torrent_plugin {
    void const*owner;std::shared_ptr<State>state;
    Torrent(void const*o,std::shared_ptr<State>s):owner(o),state(s){}
    ~Torrent(){Unregister(owner,state);}
    void tick()override{try{state->rotatePending();}catch(...){} }
    void on_add_peer(lt::tcp::endpoint const&e,lt::peer_source_flags_t src,lt::add_peer_flags_t flags)override{
        try{auto key=Key(e);state->flush(key);state->discovered(key,uint32_t(static_cast<uint8_t>(src)),bool(flags & lt::torrent_plugin::filtered));}catch(...){}
    }
    std::shared_ptr<lt::peer_plugin>new_connection(lt::peer_connection_handle const&c)override{
        try{auto connection=std::make_shared<Connection>(c,state);state->track(connection);return connection;}catch(...){return {};}
    }
};
struct Session final:lt::plugin {
    lt::feature_flags_t implemented_features()override{return alert_feature;}
    std::shared_ptr<lt::torrent_plugin>new_torrent(lt::torrent_handle const&h,void*)override{
        try{auto owner=h.native_handle().get();auto s=std::make_shared<State>();if(!Register(owner,s))return {};return std::make_shared<Torrent>(owner,s);}catch(...){return {};}
    }
    void on_alert(lt::alert const*a)override{
        try{
            if(auto p=lt::alert_cast<lt::tracker_announce_alert>(a)){auto s=Lookup(p->handle.native_handle().get());if(s)s->announce(p->tracker_url(),false);}
            else if(auto p=lt::alert_cast<lt::tracker_error_alert>(a)){auto s=Lookup(p->handle.native_handle().get());if(s)s->announce(p->tracker_url(),true);}
        }catch(...){}
    }
};
struct Totals{uint64_t peers=0,accepted=0,filtered=0,connected=0,connections=0,handshakes=0,disconnections=0,useful=0,payload=0,earlierPayload=0;double firstConnected=-1,firstPayload=-1;
    void add(Peer const&p,Origin const*origin=nullptr){
        uint64_t bytes=p.payload-(origin?origin->payload:0),count=p.connections-(origin?origin->connections:0);
        double firstConnection=origin?origin->firstConnected:p.firstConnected,firstData=origin?origin->firstPayload:p.firstPayload;
        ++peers;accepted+=p.accepted;filtered=Add(filtered,p.filtered-(origin?origin->filtered:0));connected+=count>0;connections=Add(connections,count);
        handshakes=Add(handshakes,p.handshakes-(origin?origin->handshakes:0));disconnections=Add(disconnections,p.disconnections-(origin?origin->disconnections:0));useful+=bytes>0;payload=Add(payload,bytes);earlierPayload=Add(earlierPayload,origin?origin->payload:0);
        if(firstConnection>=0&&(firstConnected<0||firstConnection<firstConnected))firstConnected=firstConnection;
        if(firstData>=0&&(firstPayload<0||firstData<firstPayload))firstPayload=firstData;
    }
};
inline NSMutableDictionary* Dictionary(Totals const&t){return [@{@"peers":@(t.peers),@"accepted":@(t.accepted),@"filtered_observations":@(t.filtered),@"connected_peers":@(t.connected),@"connections":@(t.connections),@"handshakes":@(t.handshakes),@"disconnections":@(t.disconnections),@"useful_peers":@(t.useful),@"payload_bytes":@(t.payload),@"payload_before_discovery":@(t.earlierPayload),@"first_connection_seconds":@(t.firstConnected),@"first_payload_seconds":@(t.firstPayload)}mutableCopy];}
inline NSDictionary* Snapshot(std::shared_ptr<State>const&s){
    if(!s)return @{@"available":@NO};std::lock_guard<std::mutex>lock(s->mutex);
    Totals total,unknown;Totals byTracker[MaxTrackers],byRoute[6];uint64_t overlap=0,trackerUnknown=0;
    for(auto const&item:s->peers){auto const&p=item.second;total.add(p);unsigned origins=0;
        for(size_t i=0;i<s->trackers.size();i++)if(p.trackers&(1u<<i)){byTracker[i].add(p,&p.trackerOrigins[i]);++origins;}
        for(unsigned i=0;i<6;i++)if(p.routes&(1u<<i)){byRoute[i].add(p,&p.routeOrigins[i]);if(i!=0)++origins;}
        if((p.routes&1)&&!p.trackers)++trackerUnknown;if(!p.trackers&&!p.routes)unknown.add(p);if(origins>1)++overlap;
    }
    NSMutableArray*trackers=[NSMutableArray new];
    for(size_t i=0;i<s->trackers.size();i++){auto const&t=s->trackers[i];auto*d=Dictionary(byTracker[i]);
        [d addEntriesFromDictionary:@{@"tracker_id":@(i+1),@"requests":@(t.requests),@"errors":@(t.errors),@"responses":@(t.responses),@"stopped_responses":@(t.stopped),@"reported_peer_entries":@(t.reported),@"dns_started":@(t.dnsStarted),@"dns_resolved":@(t.dnsResolved),@"dns_failed":@(t.dnsFailed),@"first_response_seconds":@(t.firstResponse)}];[trackers addObject:d];}
    NSArray*names=@[@"tracker",@"dht",@"pex",@"lsd",@"resume",@"incoming"];NSMutableDictionary*routes=[NSMutableDictionary new];for(unsigned i=0;i<6;i++)routes[names[i]]=Dictionary(byRoute[i]);
    return @{@"probe_connection_turnover":@{@"enabled":@(s->rotateEnabled),@"replacements":@(s->rotations),@"last_pending_age_seconds":@(s->lastRotatedAge)},@"available":@YES,@"unique":Dictionary(total),@"trackers":trackers,@"routes":routes,@"unknown":Dictionary(unknown),@"overlapping_peers":@(overlap),@"tracker_origin_unknown_peers":@(trackerUnknown),@"peer_record_bytes":@(sizeof(Peer)),@"endpoint_overflow_events":@(s->endpointOverflow),@"tracker_overflow_events":@(s->trackerOverflow),@"unknown_origin_events":@(s->unknownOriginEvents),@"connection_overflow_events":@(s->connectionOverflow),@"unattributed_payload_bytes":@(s->unattributedPayload),@"endpoint_limit":@(MaxPeers),@"tracker_limit":@(MaxTrackers),@"payload_basis":@"Received payload after origin discovery; not hash-verified or exclusive causal attribution",@"time_basis":@"Seconds since torrent observer registration"};
}
inline NSDictionary* Snapshot(lt::torrent_handle const&h){return Snapshot(Lookup(h.native_handle().get()));}
}
#ifdef RW_PEER_EVIDENCE_IMPLEMENTATION
extern "C" bool RWObserveTracker(RWTrackerObservation const*e){
    try{if(!e||e->version!=1)return false;auto s=RWPeerEvidence::Lookup(e->torrent);if(s&&e->kind==RWTrackerEndpoint)s->flush(RWPeerEvidence::Key(e->address,e->address_length,e->port,e->scope));return s&&s->observe(*e);}catch(...){return false;}
}
#endif
