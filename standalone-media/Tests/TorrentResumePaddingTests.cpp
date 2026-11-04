#ifndef RW_RESUME_UNDER_TEST
#define RW_RESUME_UNDER_TEST "../RWTorrentResume.h"
#endif
#include RW_RESUME_UNDER_TEST
#include <libtorrent/read_resume_data.hpp>
#include <libtorrent/write_resume_data.hpp>
#include <libtorrent/entry.hpp>
#include <cstdio>
namespace lt=libtorrent;
int main(){int checks=0,failures=0;auto check=[&](bool ok,const char *message){++checks;if(!ok){++failures;std::fprintf(stderr,"FAIL: %s\n",message);}};
 for(int pieceBytes:{2027520,989184,8*1024*1024}){
  lt::entry entry;entry["info"]["name"]="generated.mp4";entry["info"]["length"]=int64_t(pieceBytes)*2+32769;
  entry["info"]["piece length"]=pieceBytes;entry["info"]["pieces"]=std::string(60,'x');
  lt::error_code error;auto info=std::make_shared<lt::torrent_info>(entry);
  lt::add_torrent_params base;base.ti=info;base.info_hash=info->info_hash();base.save_path="expected/path";base.trackers={"https://expected.invalid/announce"};
  lt::add_torrent_params progress;progress.info_hash=base.info_hash;progress.have_pieces.resize(3,false);progress.have_pieces.set_bit(lt::piece_index_t(0));
  int blocks=pieceBytes/16384+(pieceBytes%16384!=0),padded=(blocks+7)/8*8;
  progress.unfinished_pieces[lt::piece_index_t(1)]=lt::bitfield(blocks,false);
  progress.unfinished_pieces[lt::piece_index_t(1)].set_bit(0);
  progress.unfinished_pieces[lt::piece_index_t(1)].set_bit(blocks-1);
  // The pinned writer uses the full normal-piece block count for the last
  // piece too; only the three real tail blocks may be set.
  progress.unfinished_pieces[lt::piece_index_t(2)]=lt::bitfield(blocks,false);
  progress.unfinished_pieces[lt::piece_index_t(2)].set_bit(2);
  auto bytes=lt::write_resume_data_buf(progress);auto decoded=lt::read_resume_data(bytes,error);
  check(!error&&decoded.unfinished_pieces[lt::piece_index_t(1)].size()==padded,"Pinned serialization expands partial masks to whole bytes");
  auto target=base;bool ok=RWRestoreTorrentProgress(target,decoded);
  check(ok,"Valid zero-padded saved masks restore");
  if(ok){
   check(target.unfinished_pieces[lt::piece_index_t(1)].size()==blocks,"Padding is normalized to real normal-piece blocks");
   check(target.unfinished_pieces[lt::piece_index_t(1)][0]&&target.unfinished_pieces[lt::piece_index_t(1)][blocks-1],"First and final valid partial blocks survive");
   check(target.unfinished_pieces[lt::piece_index_t(2)].size()==3&&target.unfinished_pieces[lt::piece_index_t(2)][2],"Short tail mask keeps only real tail blocks");
   check(target.have_pieces[lt::piece_index_t(0)]&&!target.have_pieces[lt::piece_index_t(1)],"Partial blocks do not become verified pieces");
   check(target.save_path==base.save_path&&target.trackers==base.trackers&&target.flags==base.flags,"Restore preserves caller paths, trackers and flags");
  }
  auto reject=[&](lt::add_torrent_params bad,const char *message){auto untouched=base;check(!RWRestoreTorrentProgress(untouched,bad)&&untouched.have_pieces.empty()&&untouched.unfinished_pieces.empty()&&untouched.save_path==base.save_path,message);};
  auto bad=decoded;bad.unfinished_pieces[lt::piece_index_t(1)].resize(padded+8,false);reject(bad,"Extra serialized bytes are rejected atomically");
  if(padded>blocks){bad=decoded;bad.unfinished_pieces[lt::piece_index_t(1)].set_bit(blocks);reject(bad,"Nonzero byte padding is rejected atomically");}
  bad=decoded;bad.unfinished_pieces[lt::piece_index_t(2)].set_bit(3);reject(bad,"Out-of-file tail blocks are rejected");
  bad=decoded;bad.unfinished_pieces[lt::piece_index_t(3)]=lt::bitfield(8,false);reject(bad,"Out-of-range piece index rejected");
  bad=decoded;bad.unfinished_pieces[lt::piece_index_t(-1)]=lt::bitfield(8,false);reject(bad,"Negative piece index rejected");
  bad=decoded;bad.info_hash=lt::sha1_hash();reject(bad,"Wrong torrent hash rejected");
  bad=decoded;bad.have_pieces.resize(4,false);reject(bad,"Oversize verified-piece flags rejected");
  auto shortSaved=decoded;shortSaved.have_pieces.resize(1);target=base;
  check(RWRestoreTorrentProgress(target,shortSaved)&&target.have_pieces.size()==1,"Interrupted verification keeps its exact short prefix");
 }
 std::printf("{\"checks\":%d,\"failures\":%d,\"scope\":\"Pinned libtorrent serialization, non-byte-aligned blocks and invalid saved progress; no network\"}\n",checks,failures);return failures?1:0;
}
