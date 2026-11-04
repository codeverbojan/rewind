#include <libtorrent/session.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/create_torrent.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/hasher.hpp>
#include <libtorrent/peer_info.hpp>
#include "../RWDiscoveryPolicy.h"
#include "../RWTransferWindow.h"
#include <chrono>
#include <thread>
#include <cstdio>
#include <csignal>
#include <unistd.h>
namespace lt=libtorrent;
using Clock=std::chrono::steady_clock;
static volatile std::sig_atomic_t interrupted=0;
static void stop(int){interrupted=1;}
static double now(){return std::chrono::duration<double>(Clock::now().time_since_epoch()).count();}
template<typename F>static bool waitFor(F f,double seconds=5){double end=now()+seconds;while(now()<end){if(interrupted)throw std::runtime_error("Interrupted");if(f())return true;std::this_thread::sleep_for(std::chrono::milliseconds(20));}return false;}
int main(int argc,char**argv){
 std::signal(SIGINT,stop);std::signal(SIGTERM,stop);
 bool ahead=argc>1&&std::string(argv[1])=="ahead";int checks=0,failures=0;
 auto check=[&](bool ok,const char *message){checks++;if(!ok){failures++;std::fprintf(stderr,"FAIL: %s\n",message);}};
 char seedFolder[]="/tmp/rewind-seed-XXXXXX",clientFolder[]="/tmp/rewind-client-XXXXXX";
 if(!mkdtemp(seedFolder)||!mkdtemp(clientFolder))return 2;
 struct Cleanup{std::string folder;~Cleanup(){unlink((folder+"/generated.bin").c_str());rmdir(folder.c_str());}}seedCleanup{seedFolder},clientCleanup{clientFolder};
 try{
  int pieceBytes=2*1024*1024;std::vector<char> data(pieceBytes,'Z');lt::file_storage files;files.add_file("generated.bin",int64_t(pieceBytes)*4);
  lt::create_torrent builder(files,pieceBytes);auto hash=lt::hasher(data.data(),data.size()).final();for(int i=0;i<4;i++)builder.set_hash(lt::piece_index_t(i),hash);
  auto info=std::make_shared<lt::torrent_info>(builder.generate());lt::settings_pack settings;
  settings.set_str(lt::settings_pack::listen_interfaces,"127.0.0.1:0");
  settings.set_bool(lt::settings_pack::enable_dht,false);settings.set_bool(lt::settings_pack::enable_lsd,false);settings.set_bool(lt::settings_pack::enable_upnp,false);settings.set_bool(lt::settings_pack::enable_natpmp,false);settings.set_bool(lt::settings_pack::enable_incoming_utp,false);settings.set_bool(lt::settings_pack::enable_outgoing_utp,false);
  settings.set_bool(lt::settings_pack::ignore_limits_on_local_network,false);settings.set_bool(lt::settings_pack::close_redundant_connections,false);settings.set_int(lt::settings_pack::connections_limit,2);settings.set_int(lt::settings_pack::unchoke_interval,3);settings.set_int(lt::settings_pack::optimistic_unchoke_interval,3);
  lt::session seedSession(settings);lt::add_torrent_params p;p.ti=info;p.save_path=seedFolder;p.flags&=~(lt::torrent_flags::paused|lt::torrent_flags::auto_managed);auto seed=seedSession.add_torrent(p);
  check(waitFor([&]{auto s=seed.status();return s.state!=lt::torrent_status::checking_files&&s.state!=lt::torrent_status::checking_resume_data;}),"Seed initializes");
  for(int i=0;i<4;i++)seed.add_piece(lt::piece_index_t(i),data.data());
  check(waitFor([&]{return seed.status().is_seeding;}),"Generated seed pieces hash verify");
  settings.set_str(lt::settings_pack::listen_interfaces,"");lt::session clientSession(settings);p.save_path=clientFolder;p.flags|=lt::torrent_flags::upload_mode|lt::torrent_flags::sequential_download;p.file_priorities.assign(1000,lt::dont_download);auto client=clientSession.add_torrent(p);
  check(waitFor([&]{auto s=client.status();return s.state!=lt::torrent_status::checking_files&&s.state!=lt::torrent_status::checking_resume_data;}),"Client initializes");
  client.prioritize_files(std::vector<lt::download_priority_t>{lt::default_priority});check(waitFor([&]{return client.get_file_priorities()==std::vector<lt::download_priority_t>{lt::default_priority};}),"Selected file priority commits");
  std::vector<lt::download_priority_t> priorities(4,lt::dont_download);priorities[0]=lt::default_priority;
  if(ahead){int next=RWProbeAheadPiece(0,0,3,false,[&](int piece){return client.have_piece(lt::piece_index_t(piece));});if(next>=0)priorities[next]=lt::default_priority;}
  client.prioritize_pieces(priorities);client.unset_flags(lt::torrent_flags::upload_mode);client.set_download_limit(256*1024);client.set_piece_deadline(lt::piece_index_t(0),0);
  check(waitFor([&]{return seedSession.listen_port()>0;}),"Only loopback seed listener is ready");
  std::printf("{\"event\":\"listener\",\"port\":%d}\n",seedSession.listen_port());std::fflush(stdout);
  client.connect_peer({lt::make_address("127.0.0.1"),seedSession.listen_port()});
  double began=now();RWTransferWindow transfer;transfer.observe(began,0);double measuredRate=0;
  bool partialObserved=false,unverifiedRejected=true;
  check(waitFor([&]{auto status=client.status();measuredRate=transfer.observe(now(),status.total_payload_download);
   bool header=client.have_piece(lt::piece_index_t(0));
   if(status.total_payload_download>65536&&!header){partialObserved=true;
    bool healthy=RWStreamingReady(header,false,status.num_peers,measuredRate,100000,transfer.measuredSeconds());
    unverifiedRejected=unverifiedRejected&&RWReadinessScore(healthy,false,0,measuredRate,100000,10000)<0;
   }
   return header;},25),"Opening piece downloads over loopback");
  check(partialObserved&&unverifiedRejected,"Live partial transfer cannot bypass whole-piece verification");
  check(measuredRate>=125000&&measuredRate<=512*1024,"Sustained estimate recognizes the controlled 256 KiB/s source");
  auto healthStatus=client.status();uint64_t reserve=RWVerifiedPrefix(0,uint64_t(info->total_size()),pieceBytes,[&](int64_t piece){return piece>=0&&piece<healthStatus.pieces.size()&&healthStatus.pieces[lt::piece_index_t(int(piece))];});
  check(RWStreamingReady(true,false,healthStatus.num_peers,measuredRate,100000,transfer.measuredSeconds(),reserve),"Verified reserve and measured live transfer qualify for streaming");
  std::printf("{\"event\":\"health\",\"measured_rate\":%.3f,\"measured_seconds\":%.3f,\"required_rate\":100000,\"partial_data_rejected\":%s}\n",measuredRate,transfer.measuredSeconds(),unverifiedRejected?"true":"false");
  double opening=now()-began;std::this_thread::sleep_for(std::chrono::milliseconds(1000));
  auto before=client.status();std::vector<lt::peer_info> peers;client.get_peer_info(peers);
  bool interested=!peers.empty()&&bool(peers[0].flags & lt::peer_info::interesting);
  bool choked=!peers.empty()&&bool(peers[0].flags & lt::peer_info::remote_choked);
  client.prioritize_pieces(std::vector<lt::download_priority_t>(4,lt::default_priority));client.set_piece_deadline(lt::piece_index_t(3),0);
  double promoted=now();auto payload=client.status().total_payload_download;
  bool resumed=waitFor([&]{return client.status().total_payload_download>payload;},12);double gap=now()-promoted;
  check(resumed,"Payload continues after promoting probe to playback");
  check(waitFor([&]{return client.have_piece(lt::piece_index_t(3));},25),"Decoder tail request completes with verified bytes");
  std::printf("{\"mode\":\"%s\",\"checks\":%d,\"failures\":%d,\"opening_seconds\":%.3f,\"probe_finished\":%s,\"interested_before_promotion\":%s,\"remote_choked\":%s,\"promotion_payload_gap_seconds\":%.3f,\"tail_complete_seconds\":%.3f}\n",ahead?"ahead":"header-only",checks,failures,opening,before.is_finished?"true":"false",interested?"true":"false",choked?"true":"false",gap,now()-promoted);
 }catch(std::exception const &e){failures++;std::fprintf(stderr,"Exception: %s\n",e.what());}
 return failures?1:0;
}
