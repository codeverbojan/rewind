#import <Foundation/Foundation.h>
#import "../TorrentEngine.h"
#include <libtorrent/session.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/create_torrent.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/hasher.hpp>
#include <libtorrent/bencode.hpp>
#include <chrono>
#include <thread>
#include <csignal>
#include <cstdio>
namespace lt=libtorrent;
static volatile std::sig_atomic_t interrupted=0;static void stop(int){interrupted=1;}
static double clockNow(){return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();}
template<typename F>static bool waitFor(F f,double seconds){double end=clockNow()+seconds;while(clockNow()<end){if(interrupted)throw std::runtime_error("Interrupted");if(f())return true;std::this_thread::sleep_for(std::chrono::milliseconds(250));}return false;}
static void work(TorrentEngine *engine,void(^body)(void)){dispatch_semaphore_t done=dispatch_semaphore_create(0);[engine perform:^(TorrentEngine *e){body();dispatch_semaphore_signal(done);}];if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC)))throw std::runtime_error("Engine queue timeout");}
struct EngineOwner {__strong TorrentEngine *engine;~EngineOwner(){if(engine)work(engine,^{[engine shutdown];});}};
static void emit(NSDictionary *d){NSData *data=[NSJSONSerialization dataWithJSONObject:d options:0 error:nil];printf("%s\n",[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding].UTF8String);fflush(stdout);}
int main(int argc,const char **argv){@autoreleasepool{std::signal(SIGINT,stop);std::signal(SIGTERM,stop);int checks=0,failures=0;auto check=[&](bool b,const char *why){checks++;if(!b){failures++;fprintf(stderr,"FAIL:%s\n",why);}};
 try{
  NSString *mode=argc>1?@(argv[1]):@"focus";bool lopsided=[mode isEqual:@"lopsided"];bool slow=[mode isEqual:@"slow"],single=[mode isEqual:@"single"],cancel=[mode isEqual:@"cancel"],dead=[mode isEqual:@"dead"];if(!lopsided&&!slow&&!single&&!cancel&&!dead&&![mode isEqual:@"focus"])return 2;
  const char *root=getenv("REWIND_ENGINE_FIXTURE_ROOT");if(!root||!*root)return 2;NSString *client=[@(root)stringByAppendingPathComponent:@"client"],*seedPath=[@(root)stringByAppendingPathComponent:@"seed"],*cache=[client stringByAppendingPathComponent:@"TorrentMetadata"];
  for(NSString *p in @[client,seedPath,cache])[NSFileManager.defaultManager createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];setenv("REWIND_ENGINE_TEST_ROOT",client.UTF8String,1);setenv("REWIND_ENGINE_FOCUS_TEST","1",1);
  lt::settings_pack settings;settings.set_str(lt::settings_pack::listen_interfaces,"127.0.0.1:0");settings.set_bool(lt::settings_pack::enable_dht,false);settings.set_bool(lt::settings_pack::enable_lsd,false);settings.set_bool(lt::settings_pack::enable_upnp,false);settings.set_bool(lt::settings_pack::enable_natpmp,false);settings.set_bool(lt::settings_pack::close_redundant_connections,false);settings.set_bool(lt::settings_pack::enable_incoming_utp,false);settings.set_bool(lt::settings_pack::enable_outgoing_utp,false);settings.set_int(lt::settings_pack::unchoke_interval,1);settings.set_int(lt::settings_pack::optimistic_unchoke_interval,1);settings.set_int(lt::settings_pack::stop_tracker_timeout,0);
  lt::session seedSession(settings);std::vector<lt::torrent_handle> seeds;std::vector<std::shared_ptr<lt::torrent_info>> infos;constexpr int pieceBytes=4*1024*1024,pieces=16;constexpr int64_t size=int64_t(pieceBytes)*pieces;
  int amount=lopsided?2:cancel?4:single?1:3;
  for(int i=0;i<amount;i++){std::vector<char> data(pieceBytes,char('A'+i));lt::file_storage files;files.add_file("candidate"+std::to_string(i)+".mp4",size);lt::create_torrent b(files,pieceBytes);auto hash=lt::hasher(data.data(),data.size()).final();for(int p=0;p<pieces;p++)b.set_hash(lt::piece_index_t(p),hash);auto info=std::make_shared<lt::torrent_info>(b.generate());infos.push_back(info);lt::add_torrent_params params;params.ti=info;params.save_path=seedPath.UTF8String;params.flags&=~(lt::torrent_flags::paused|lt::torrent_flags::auto_managed);auto seed=seedSession.add_torrent(params);seeds.push_back(seed);if(lopsided)seed.set_upload_limit(i==0?120000:20000);if(!waitFor([&]{auto s=seed.status();return s.state!=lt::torrent_status::checking_files&&s.state!=lt::torrent_status::checking_resume_data;},5))throw std::runtime_error("Seed check timeout");for(int p=0;p<pieces;p++)seed.add_piece(lt::piece_index_t(p),data.data());std::vector<char> encoded;lt::bencode(std::back_inserter(encoded),b.generate());NSMutableString *hex=[NSMutableString new];for(unsigned char c:info->info_hash().to_string())[hex appendFormat:@"%02x",c];[[NSData dataWithBytes:encoded.data() length:encoded.size()]writeToFile:[cache stringByAppendingPathComponent:[hex stringByAppendingString:@".torrent"]] atomically:YES];}
  if(!waitFor([&]{for(auto s:seeds)if(!s.status().is_seeding)return false;return seedSession.listen_port()>0;},8))throw std::runtime_error("Fixture seed not ready");int port=seedSession.listen_port();emit(@{@"event":@"listener",@"port":@(port)});
  NSMutableArray *sources=[NSMutableArray new];for(int i=0;i<amount;i++){NSMutableString *hex=[NSMutableString new];for(unsigned char c:infos[i]->info_hash().to_string())[hex appendFormat:@"%02x",c];NSString *magnet=[NSString stringWithFormat:@"magnet:?xt=urn:btih:%@%@",hex,dead?@"":[NSString stringWithFormat:@"&x.pe=127.0.0.1:%d",port]];[sources addObject:@{@"url":magnet,@"infoHash":hex,@"fileIdx":@0,@"filename":[NSString stringWithFormat:@"candidate%d.mp4",i],@"provider":@"Generated loopback fixture",@"durationHintSeconds":@(double(size)/(lopsided?(i==0?600000.:200000.):slow?1000000.:300000.)),@"score":@90}];}
  EngineOwner owner{[TorrentEngine new]};TorrentEngine *engine=owner.engine;struct Readings {__strong NSDictionary *race=nil,*snapshot=nil;__strong NSData *opening=nil;} readings;Readings *v=&readings;double began=clockNow();work(engine,^{[engine startCandidates:cancel?[sources subarrayWithRange:NSMakeRange(0,3)]:sources];});NSMutableArray *observations=[NSMutableArray new];bool appended=false,focused=false,ramped=false;
  bool terminal=waitFor([&]{work(engine,^{v->race=[engine discoverySnapshot];});[observations addObject:v->race?:@{}];focused=focused||[v->race[@"focus"][@"active"]boolValue];
   // The second seed recovers as soon as the first focus starts. Identical
   // external event in baseline/candidate; no simulated engine decisions.
   if(lopsided&&focused&&!ramped){seeds[1].set_upload_limit(500000);ramped=true;emit(@{@"event":@"seed_recovered",@"seconds":@(clockNow()-began)});}

   if(cancel&&focused&&!appended){NSString *before=v->race[@"session_id"];work(engine,^{[engine appendCandidates:@[sources[0],sources[3]]];v->race=[engine discoverySnapshot];});check([v->race[@"total"]intValue]==4&&[v->race[@"torrent_start_count"]intValue]==3,"Append stays queued and duplicate does not create a handle");check([v->race[@"session_id"]isEqual:before],"Append shares existing session");work(engine,^{[engine startCandidates:@[sources[3]]];v->race=[engine discoverySnapshot];});check(![v->race[@"focus"][@"attempted"]boolValue]&&[v->race[@"focus"][@"events"]count]==0,"Cancellation resets focus state for new title");appended=true;}
   return [v->race[@"selected"]boolValue]||[v->race[@"exhausted"]boolValue];},55);
  check(terminal,"Actual discovery state machine finishes within fixture deadline");check([v->race[@"session_count"]intValue]==1,"One discovery session");
  if(slow||dead){check(![v->race[@"selected"]boolValue],"Insufficient or absent delivery cannot qualify");check([v->race[@"exhausted"]boolValue],"Unusable candidates exhaust instead of spinning");}
  else{check([v->race[@"selected"]boolValue],"Production engine selects a usable stream");if([v->race[@"selected"]boolValue]){bool readable=waitFor([&]{work(engine,^{[engine prioritizeOffset:0 length:65536];v->opening=[engine readVerifiedBytesAt:0 length:65536];v->snapshot=[engine snapshot];});return v->opening.length==65536;},5);check(readable,"Winning handle serves verified opening bytes");check(std::max(0,[v->snapshot[@"download_limit"]intValue])==std::max(0,[observations.firstObject[@"candidates"][0][@"download_limit"]intValue]),"Winner's original bandwidth limit restored");}}
  if(lopsided||[mode isEqual:@"focus"]||slow||cancel)check(focused,"Actual engine enters bounded focus");else check(!focused,"Single or inactive candidate does not trigger focus");
  if(!cancel){check([v->race[@"torrent_start_count"]intValue]==amount,"No replacement torrent starts");NSArray *events=v->race[@"focus"][@"events"]?:@[];if(focused){check(events.count==2,"Exactly one focus start/end");check([events.lastObject[@"seconds"]doubleValue]<=13,"Focus interval bounded");}}
  emit(@{@"event":@"result",@"mode":mode,@"checks":@(checks),@"failures":@(failures),@"seconds":@(clockNow()-began),@"focus_seen":@(focused),@"race":v->race?:@{},@"observations":observations,@"snapshot":v->snapshot?:@{},@"scope":@"Actual engine transitions and verified generated bytes on shared600000B/s loopback; no decoder/iPad claim; lopsided recovery occurs on focus entry for both variants"});return failures?1:0;
 }catch(const std::exception &e){fprintf(stderr,"%s\n",e.what());return 3;}
}}
