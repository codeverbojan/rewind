#include "../RWTorrentResume.h"
#include "../RWDiscoveryPolicy.h"
#include <libtorrent/session.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/create_torrent.hpp>
#include <libtorrent/hasher.hpp>
#include <libtorrent/alert_types.hpp>
#include <libtorrent/read_resume_data.hpp>
#include <libtorrent/write_resume_data.hpp>
#include <libtorrent/bencode.hpp>
#include <chrono>
#include <thread>
#include <cstdio>
#include <unistd.h>
namespace lt=libtorrent;
using Clock=std::chrono::steady_clock;
static bool waitFor(std::function<bool()> check){auto end=Clock::now()+std::chrono::seconds(5);while(Clock::now()<end){if(check())return true;std::this_thread::sleep_for(std::chrono::milliseconds(10));}return false;}
int main(){int checks=0,failures=0;auto check=[&](bool pass,const char *text){checks++;if(!pass){failures++;std::fprintf(stderr,"FAIL: %s\n",text);}};
 char folder[]="/tmp/rewind-resume-XXXXXX";if(!mkdtemp(folder))return 2;std::string root=folder,file=root+"/generated.bin";
 struct Cleanup{std::string file,root;~Cleanup(){unlink(file.c_str());rmdir(root.c_str());}}cleanup{file,root};
 try{
 const int pieceBytes=8*1024*1024;std::vector<char> bytes(pieceBytes,'A');
 lt::file_storage files;files.add_file("generated.bin",int64_t(pieceBytes)*3);lt::create_torrent builder(files,pieceBytes);
 auto hash=lt::hasher(bytes.data(),bytes.size()).final();for(int i=0;i<3;i++)builder.set_hash(lt::piece_index_t(i),hash);
 auto info=std::make_shared<lt::torrent_info>(builder.generate());
 lt::settings_pack settings;settings.set_str(lt::settings_pack::listen_interfaces,"");settings.set_bool(lt::settings_pack::enable_dht,false);settings.set_bool(lt::settings_pack::enable_lsd,false);settings.set_bool(lt::settings_pack::enable_upnp,false);settings.set_bool(lt::settings_pack::enable_natpmp,false);settings.set_bool(lt::settings_pack::enable_outgoing_tcp,false);settings.set_bool(lt::settings_pack::enable_outgoing_utp,false);settings.set_int(lt::settings_pack::alert_mask,lt::alert::storage_notification|lt::alert::error_notification|lt::alert::status_notification);
 lt::add_torrent_params base;base.ti=info;base.info_hash=info->info_hash();base.save_path=root;base.flags&=~(lt::torrent_flags::paused|lt::torrent_flags::auto_managed);
 lt::add_torrent_params saved;
 {
  lt::session session(settings);auto handle=session.add_torrent(base);
  check(waitFor([&]{auto s=handle.status();return s.state!=lt::torrent_status::checking_files&&s.state!=lt::torrent_status::checking_resume_data;}),"New torrent initializes without network");
  handle.add_piece(lt::piece_index_t(0),bytes.data());
  check(waitFor([&]{return handle.have_piece(lt::piece_index_t(0));}),"Generated 8 MiB piece is hash verified by libtorrent");
  bytes[0]='B';handle.add_piece(lt::piece_index_t(1),bytes.data());bytes[0]='A';
  check(waitFor([&]{return handle.status().total_failed_bytes>=pieceBytes;}),"Corrupt piece fails verification");
  check(!handle.have_piece(lt::piece_index_t(1)),"Unverified piece is never marked available");
  session.pause();handle.save_resume_data(lt::torrent_handle::flush_disk_cache);
  check(waitFor([&]{std::vector<lt::alert*> alerts;session.pop_alerts(&alerts);for(auto a:alerts)if(auto resume=lt::alert_cast<lt::save_resume_data_alert>(a)){saved=resume->params;return true;}return false;}),"Flushed progress arrives asynchronously from the real library");
 }
 auto encoded=lt::write_resume_data_buf(saved);lt::error_code ec;auto decoded=lt::read_resume_data(encoded,ec);
 check(!ec&&decoded.have_pieces[lt::piece_index_t(0)]&&!decoded.have_pieces[lt::piece_index_t(1)],"Serialization preserves verified and failed piece distinction");
 auto resumed=base;
 check(RWRestoreTorrentProgress(resumed,decoded),"Expected hash restores progress");
 check(resumed.save_path==base.save_path&&resumed.flags==base.flags&&resumed.trackers==base.trackers&&resumed.url_seeds.empty(),"Resume cannot replace path, flags, trackers or web-seed policy");
 auto wrong=decoded;wrong.info_hash=lt::sha1_hash();check(!RWRestoreTorrentProgress(resumed,wrong),"Different torrent hash cannot restore data");
 auto malformed=decoded;malformed.have_pieces.resize(100,true);check(!RWRestoreTorrentProgress(resumed,malformed),"Oversized piece bitfield is rejected");
 auto partial=decoded;partial.unfinished_pieces[lt::piece_index_t(2)]=lt::bitfield(pieceBytes/16384,false);partial.unfinished_pieces[lt::piece_index_t(2)].set_bit(0);
 auto partialTarget=base;check(RWRestoreTorrentProgress(partialTarget,partial)&&partialTarget.unfinished_pieces.count(lt::piece_index_t(2))==1&&partialTarget.unfinished_pieces[lt::piece_index_t(2)][0]&&!partialTarget.have_pieces[lt::piece_index_t(2)],"Unfinished blocks remain unfinished, not promoted to verified data");
 {
  lt::session session(settings);auto handle=session.add_torrent(resumed);
  check(waitFor([&]{auto s=handle.status();return s.state!=lt::torrent_status::checking_files&&s.state!=lt::torrent_status::checking_resume_data;}),"Saved progress passes the library's fast resume check");
  check(handle.have_piece(lt::piece_index_t(0))&&!handle.have_piece(lt::piece_index_t(1)),"Reopened torrent retains only its verified piece");
  check(RWProbeMeasurementPiece(0,2,true,[&](int p){return handle.have_piece(lt::piece_index_t(p));})==1,"Real resumed cache selects a missing piece for live throughput measurement");
  handle.read_piece(lt::piece_index_t(0));
  check(waitFor([&]{std::vector<lt::alert*> alerts;session.pop_alerts(&alerts);for(auto a:alerts)if(auto read=lt::alert_cast<lt::read_piece_alert>(a))return !read->error&&read->size==pieceBytes&&read->buffer[0]=='A'&&read->buffer[pieceBytes-1]=='A';return false;}),"Resumed verified bytes can be read intact through the app's library API");
 }
 // Model an interrupted download with 64 completed blocks of the next piece.
 // The serialized state must preserve them without claiming a playable piece.
 {FILE *f=std::fopen(file.c_str(),"r+b");if(!f)throw std::runtime_error("Cannot open generated partial file");
  std::fseek(f,2*pieceBytes,SEEK_SET);auto wrote=std::fwrite(bytes.data(),1,1024*1024,f);std::fclose(f);
  check(wrote==1024*1024,"Generated partial piece is flushed to the test file");}
 partial.unfinished_pieces[lt::piece_index_t(2)].set_all();
 for(int block=64;block<pieceBytes/16384;block++)partial.unfinished_pieces[lt::piece_index_t(2)].clear_bit(block);
 auto partialBytes=lt::write_resume_data_buf(partial);auto partialSaved=lt::read_resume_data(partialBytes,ec);partialTarget=base;
 check(!ec&&RWRestoreTorrentProgress(partialTarget,partialSaved),"Serialized partial blocks restore through the actual app helper");
 {
  lt::session session(settings);auto handle=session.add_torrent(partialTarget);
  check(waitFor([&]{std::vector<lt::partial_piece_info> queue;handle.get_download_queue(queue);for(auto &p:queue)if(int(p.piece_index)==2&&p.finished==64)return true;return false;}),"Library reuses all 64 interrupted blocks without network traffic");
  check(!handle.have_piece(lt::piece_index_t(2)),"Restored partial data cannot be read as a verified piece");
  handle.add_piece(lt::piece_index_t(2),bytes.data());
  check(waitFor([&]{return handle.have_piece(lt::piece_index_t(2));}),"Completed resumed piece still passes the library hash check");
 }
 // A short have-pieces bitfield is the library's on-disk representation of
 // interrupted local verification. Continue checking the remaining pieces.
 auto interrupted=decoded;interrupted.have_pieces.resize(1);auto checkTarget=base;
 check(RWRestoreTorrentProgress(checkTarget,interrupted),"An interrupted-check checkpoint keeps its short verified prefix");
 {
  lt::session session(settings);auto handle=session.add_torrent(checkTarget);
  check(waitFor([&]{auto s=handle.status();return s.state!=lt::torrent_status::checking_files&&s.state!=lt::torrent_status::checking_resume_data;}),"Interrupted checking resumes and completes with the real library");
  check(handle.have_piece(lt::piece_index_t(0))&&handle.have_piece(lt::piece_index_t(2)),"Previously checked prefix and newly checked valid piece are retained");
  check(!handle.have_piece(lt::piece_index_t(1)),"Unchecked corrupt data is not trusted by resumed checking");
 }
 unlink(file.c_str());
 {
  lt::session session(settings);auto handle=session.add_torrent(resumed);
  check(waitFor([&]{auto s=handle.status();return s.state!=lt::torrent_status::checking_files&&s.state!=lt::torrent_status::checking_resume_data;}),"Removed cache finishes validation");
  check(!handle.have_piece(lt::piece_index_t(0)),"Stale resume data does not make a deleted file playable");
 }
 }catch(std::exception const &e){failures++;std::fprintf(stderr,"Exception: %s\n",e.what());}
 std::printf("{\"checks\":%d,\"failures\":%d,\"scope\":\"Real libtorrent 1.2.20, generated 8 MiB pieces, no networking\"}\n",checks,failures);return failures?1:0;
}
