#import "../RWPeerTransport.h"
static int checks=0,failures=0;
static void check(bool ok,const char *why){checks++;if(!ok){failures++;fprintf(stderr,"FAIL:%s\n",why);}}
int main(){@autoreleasepool{
    namespace lt=libtorrent;std::vector<lt::peer_info> peers(4);
    peers[0].flags=lt::peer_info::seed|lt::peer_info::interesting|lt::peer_info::remote_choked;
    peers[1].flags=lt::peer_info::seed|lt::peer_info::connecting|lt::peer_info::utp_socket;
    peers[2].flags=lt::peer_info::seed|lt::peer_info::handshake;
    peers[3].flags=lt::peer_info::seed|lt::peer_info::interesting|lt::peer_info::utp_socket;
    peers[3].payload_down_speed=300000;peers[3].download_queue_length=8;peers[3].requests_in_buffer=2;peers[3].read_state=lt::peer_info::bw_network;peers[3].pending_disk_bytes=16384;
    peers[0].read_state=lt::peer_info::bw_limit;peers[0].write_state=lt::peer_info::bw_limit;
    NSDictionary *r=RWPeerTransport::Summarize(peers),*tcp=r[@"tcp"],*utp=r[@"utp"];
    check([tcp[@"sockets"]intValue]==2&&[utp[@"sockets"]intValue]==2,"All socket entries counted separately from established peers");
    check([tcp[@"established"]intValue]==1&&[utp[@"established"]intValue]==1,"Handshaking and connecting seeds excluded from established count");
    check([tcp[@"seeds_established"]intValue]==1&&[utp[@"seeds_established"]intValue]==1,"Seed counts exclude pending connections");
    check([tcp[@"choked_established"]intValue]==1&&[tcp[@"unchoked_interested"]intValue]==0,"Connected but choked seed cannot be counted as ready to serve");
    check([utp[@"unchoked_interested"]intValue]==1&&[utp[@"transferring_established"]intValue]==1,"Unchoked interested seed with payload distinguished");
    check([utp[@"requests_pending"]intValue]==8&&[utp[@"requests_unsent"]intValue]==2,"Sent/pending and socket-buffer requests kept distinct");
    check([tcp[@"read_bandwidth_wait"]intValue]==1&&[tcp[@"write_bandwidth_wait"]intValue]==1,"Library bandwidth wait flags retained");
    check([utp[@"read_network_wait"]intValue]==1&&[utp[@"pending_disk_bytes"]intValue]==16384,"Network wait and pending disk bytes are distinct");
    peers[3].read_state=lt::peer_info::bw_disk|lt::peer_info::bw_limit;
    NSDictionary *overlap=RWPeerTransport::Summarize(peers)[@"utp"];
    check([overlap[@"read_disk_wait"]intValue]==1&&[overlap[@"read_bandwidth_wait"]intValue]==1,"Independent bandwidth flags may overlap");
    check([utp[@"read_disk_wait"]intValue]==0,"Published snapshot owns its numeric values");
    peers.resize(70);r=RWPeerTransport::Summarize(peers);
    check([r[@"socket_scan_truncated"]boolValue]&&[r[@"socket_count"]intValue]==70,"Bounded scan reports overflow honestly");
    check([r[@"tcp"][@"sockets"]intValue]+[r[@"utp"][@"sockets"]intValue]==64,"Socket scan never exceeds64");
    check([NSJSONSerialization dataWithJSONObject:r options:0 error:nil].length<8192,"Bounded telemetry fits saved per-source budget");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
