#pragma once
// Opt-in diagnostics only. No peer endpoints, identifiers or policy mutations.
#import <Foundation/Foundation.h>
#include <libtorrent/peer_info.hpp>
#include <libtorrent/session.hpp>
#include <libtorrent/peer_class.hpp>
#include <vector>
#include <algorithm>
namespace RWPeerTransport {
namespace lt=libtorrent;
struct Counts {
    int sockets=0,connecting=0,handshaking=0,established=0,seeds=0,choked=0,interested=0,unchokedInterested=0,transferring=0;
    int requests=0,unsent=0,timeouts=0,readLimited=0,writeLimited=0,diskWaiting=0,networkWaiting=0;
    long long payloadRate=0,sendBuffer=0,sendQuota=0,receiveQuota=0,pendingDisk=0;
    void add(const lt::peer_info &p){
        sockets++;bool connect=bool(p.flags & lt::peer_info::connecting),handshake=bool(p.flags & lt::peer_info::handshake);
        connecting+=connect;handshaking+=handshake;
        if(!connect&&!handshake){established++;seeds+=bool(p.flags & lt::peer_info::seed);
            bool interest=bool(p.flags & lt::peer_info::interesting),choke=bool(p.flags & lt::peer_info::remote_choked);
            interested+=interest;choked+=choke;unchokedInterested+=interest&&!choke;transferring+=p.payload_down_speed>0;
        }
        requests+=std::max(0,p.download_queue_length);unsent+=std::max(0,p.requests_in_buffer);timeouts+=std::max(0,p.timed_out_requests);
        readLimited+=bool(p.read_state & lt::peer_info::bw_limit);writeLimited+=bool(p.write_state & lt::peer_info::bw_limit);
        diskWaiting+=bool(p.read_state & lt::peer_info::bw_disk);networkWaiting+=bool(p.read_state & lt::peer_info::bw_network);
        payloadRate+=std::max(0,p.payload_down_speed);sendBuffer+=std::max(0,p.used_send_buffer);sendQuota+=std::max(0,p.send_quota);receiveQuota+=std::max(0,p.receive_quota);pendingDisk+=std::max(0,p.pending_disk_bytes);
    }
    NSDictionary *json()const{return @{@"sockets":@(sockets),@"connecting":@(connecting),@"handshaking":@(handshaking),@"established":@(established),@"seeds_established":@(seeds),@"choked_established":@(choked),@"interested_established":@(interested),@"unchoked_interested":@(unchokedInterested),@"transferring_established":@(transferring),@"requests_pending":@(requests),@"requests_unsent":@(unsent),@"requests_timed_out":@(timeouts),@"read_bandwidth_wait":@(readLimited),@"write_bandwidth_wait":@(writeLimited),@"read_disk_wait":@(diskWaiting),@"read_network_wait":@(networkWaiting),@"payload_bytes_per_second":@(payloadRate),@"send_buffer_bytes":@(sendBuffer),@"send_quota_bytes":@(sendQuota),@"receive_quota_bytes":@(receiveQuota),@"pending_disk_bytes":@(pendingDisk)};}
};
inline NSDictionary *Summarize(const std::vector<lt::peer_info> &peers){
    Counts tcp,utp;size_t count=std::min(peers.size(),size_t(64));
    for(size_t i=0;i<count;i++)((peers[i].flags & lt::peer_info::utp_socket)?utp:tcp).add(peers[i]);
    return @{@"tcp":tcp.json(),@"utp":utp.json(),@"socket_count":@(peers.size()),@"socket_scan_limit":@64,@"socket_scan_truncated":@(count<peers.size())};
}
inline NSDictionary *SessionLimits(lt::session &session){
    auto global=session.get_peer_class(lt::session::global_peer_class_id),tcp=session.get_peer_class(lt::session::tcp_peer_class_id);
    return @{@"global_download_bytes_per_second":@(global.download_limit),@"global_upload_bytes_per_second":@(global.upload_limit),@"tcp_download_bytes_per_second":@(tcp.download_limit),@"tcp_upload_bytes_per_second":@(tcp.upload_limit)};
}
inline NSDictionary *Capture(lt::torrent_handle handle,NSDictionary *limits){
    double began=NSProcessInfo.processInfo.systemUptime;std::vector<lt::peer_info> peers;handle.get_peer_info(peers);
    NSMutableDictionary *result=[Summarize(peers)mutableCopy];result[@"session_limits"]=limits?:@{};
    result[@"torrent_download_bytes_per_second"]=@(handle.download_limit());result[@"torrent_connection_limit"]=@(handle.max_connections());
    result[@"sample_uptime"]=@(began);result[@"sample_ms"]=@((NSProcessInfo.processInfo.systemUptime-began)*1000);
    return [result copy];
}
}
