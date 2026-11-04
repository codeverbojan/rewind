#import <Foundation/Foundation.h>
#import "../TorrentEngine.h"
#include <libtorrent/session.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/entry.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/create_torrent.hpp>
#include <libtorrent/hasher.hpp>
#include <libtorrent/bencode.hpp>
#include <chrono>
#include <thread>
#include <csignal>
namespace lt=libtorrent;
static volatile std::sig_atomic_t interrupted=0;static void stop(int){interrupted=1;}
static double clockNow(){return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();}
template<typename F>static bool waitFor(F f,double seconds){double end=clockNow()+seconds;while(clockNow()<end){if(interrupted)throw std::runtime_error("Interrupted");if(f())return true;std::this_thread::sleep_for(std::chrono::milliseconds(100));}return false;}
static void work(TorrentEngine *engine,void(^body)(void)){dispatch_semaphore_t done=dispatch_semaphore_create(0);[engine perform:^(TorrentEngine *e){body();dispatch_semaphore_signal(done);}];if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC)))throw std::runtime_error("Engine queue timeout");}
struct Owner{__strong TorrentEngine *engine;~Owner(){if(engine)work(engine,^{[engine shutdown];});}};
static void emit(NSDictionary *d){NSData *data=[NSJSONSerialization dataWithJSONObject:d options:0 error:nil];printf("%s\n",[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding].UTF8String);fflush(stdout);}
int main(int argc,char **argv){@autoreleasepool{
 std::signal(SIGINT,stop);std::signal(SIGTERM,stop);int checks=0,failures=0;auto check=[&](bool ok,const char *why){checks++;if(!ok){failures++;fprintf(stderr,"FAIL:%s\n",why);}};
 try{
  NSString *mode=argc>1?@(argv[1]):@"burst";bool burst=[mode isEqual:@"burst"],deadline=[mode isEqual:@"deadline"],fast=[mode isEqual:@"fast"],steady=[mode isEqual:@"steady"];
  if(!burst&&!deadline&&!fast&&!steady)return 2;const char *folder=getenv("REWIND_ENGINE_FIXTURE_ROOT");if(!folder||!*folder)return 2;
  NSString *client=[@(folder)stringByAppendingPathComponent:@"client"],*seedPath=[@(folder)stringByAppendingPathComponent:@"seed"],*meta=[client stringByAppendingPathComponent:@"TorrentMetadata"];
  for(NSString *p in @[client,seedPath,meta])[NSFileManager.defaultManager createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];setenv("REWIND_ENGINE_TEST_ROOT",client.UTF8String,1);
  setenv(deadline?"REWIND_ENGINE_FOCUS_TEST":"REWIND_ENGINE_QUALIFICATION_MODE",deadline?"1":"fast",1);
  lt::settings_pack settings;settings.set_str(lt::settings_pack::listen_interfaces,"127.0.0.1:0");settings.set_bool(lt::settings_pack::enable_dht,false);settings.set_bool(lt::settings_pack::enable_lsd,false);settings.set_bool(lt::settings_pack::enable_upnp,false);settings.set_bool(lt::settings_pack::enable_natpmp,false);settings.set_bool(lt::settings_pack::close_redundant_connections,false);settings.set_bool(lt::settings_pack::enable_incoming_utp,false);settings.set_bool(lt::settings_pack::enable_outgoing_utp,false);settings.set_int(lt::settings_pack::unchoke_interval,1);settings.set_int(lt::settings_pack::optimistic_unchoke_interval,1);settings.set_int(lt::settings_pack::stop_tracker_timeout,0);
  lt::session seedSession(settings);std::vector<lt::torrent_handle> seeds;std::vector<std::shared_ptr<lt::torrent_info>> infos;NSMutableArray *hashes=[NSMutableArray new],*sources=[NSMutableArray new];
  const int pieceBytes=1024*1024,pieces=64;const int64_t size=int64_t(pieceBytes)*pieces;int amount=deadline?3:burst?2:1;
  for(int i=0;i<amount;i++){
   std::vector<char> data(pieceBytes,char('A'+i));lt::file_storage files;files.add_file("generated"+std::to_string(i)+".mp4",size);lt::create_torrent b(files,pieceBytes);auto sha=lt::hasher(data.data(),data.size()).final();for(int p=0;p<pieces;p++)b.set_hash(lt::piece_index_t(p),sha);auto info=std::make_shared<lt::torrent_info>(b.generate());infos.push_back(info);
   lt::add_torrent_params params;params.ti=info;params.save_path=seedPath.UTF8String;params.flags&=~(lt::torrent_flags::paused|lt::torrent_flags::auto_managed);auto seed=seedSession.add_torrent(params);seeds.push_back(seed);
   if(!waitFor([&]{auto s=seed.status();return s.state!=lt::torrent_status::checking_files&&s.state!=lt::torrent_status::checking_resume_data;},5))throw std::runtime_error("Seed check timeout");for(int p=0;p<pieces;p++)seed.add_piece(lt::piece_index_t(p),data.data());
   NSMutableString *hex=[NSMutableString new];for(unsigned char c:info->info_hash().to_string())[hex appendFormat:@"%02x",c];[hashes addObject:hex];std::vector<char> encoded;lt::bencode(std::back_inserter(encoded),b.generate());[[NSData dataWithBytes:encoded.data() length:encoded.size()]writeToFile:[meta stringByAppendingPathComponent:[hex stringByAppendingString:@".torrent"]] atomically:YES];
   seed.set_upload_limit(deadline?0:burst?(i==0?1800000:1):fast?4000000:400000);
  }
  if(!waitFor([&]{for(auto s:seeds)if(!s.status().is_seeding)return false;return seedSession.listen_port()>0;},8))throw std::runtime_error("Seed unavailable");int port=seedSession.listen_port();emit(@{@"event":@"listener",@"port":@(port)});
  for(int i=0;i<amount;i++){double required=deadline?300000:burst?(i==0?1000000:250000):fast?250000:300000;[sources addObject:@{@"url":[NSString stringWithFormat:@"magnet:?xt=urn:btih:%@&x.pe=127.0.0.1:%d",hashes[i],port],@"infoHash":hashes[i],@"fileIdx":@0,@"filename":[NSString stringWithFormat:@"generated%d.mp4",i],@"provider":@"Generated controlled peer",@"durationHintSeconds":@(size/required),@"seeders":@(burst&&i==0?10000:1),@"score":@(burst&&i==0?100:10)}];}
  Owner owner{[TorrentEngine new]};TorrentEngine *engine=owner.engine;struct State{__strong NSDictionary *race=nil,*snapshot=nil;__strong NSData *bytes=nil;}state;State *v=&state;
  double began=clockNow();bool slowApplied=false,steadyEnabled=false,heldPoll=false;NSMutableArray *observations=[NSMutableArray new];
  auto external=[&]{double elapsed=clockNow()-began;
   if(burst&&!steadyEnabled&&elapsed>=4){seeds[1].set_upload_limit(750000);steadyEnabled=true;emit(@{@"event":@"steady_peer_enabled",@"seconds":@(elapsed)});}
   if(burst&&!slowApplied&&seeds[0].status().total_payload_upload>=5*1024*1024){seeds[0].set_upload_limit(100000);slowApplied=true;emit(@{@"event":@"burst_budget_used",@"seconds":@(elapsed)});}
  };
  work(engine,^{[engine startCandidates:sources];});
  bool terminal=waitFor([&]{external();work(engine,^{v->race=[engine discoverySnapshot];});[observations addObject:v->race?:@{}];
   if(deadline&&!heldPoll&&[v->race[@"focus"][@"active"]boolValue]){
    heldPoll=true;double until=clockNow()+15;while(clockNow()<until){if(interrupted)throw std::runtime_error("Interrupted");std::this_thread::sleep_for(std::chrono::milliseconds(100));}
    work(engine,^{v->race=[engine discoverySnapshot];});[observations addObject:v->race?:@{}];return true;
   }
   return [v->race[@"selected"]boolValue]||[v->race[@"exhausted"]boolValue];},45);
  double selectedAt=clockNow()-began;check(terminal,"Discovery finishes in bounded fixture");check([v->race[@"session_count"]intValue]==1,"Same discovery session retained");
  if(deadline){NSArray *events=v->race[@"focus"][@"events"];check(heldPoll&&events.count==2,"Focus begins and ends while UI polling is suspended");check([events.lastObject[@"seconds"]doubleValue]<=13,"Focus releases within13seconds without UI polls");for(NSDictionary *sample in v->race[@"candidates"])check(![sample[@"focus_held"]boolValue]&&[sample[@"download_limit"]intValue]<=0,"Competitor limits restored after deadline");}
  else{
   check([v->race[@"selected"]boolValue],"Source qualifies");__block NSDictionary *chosen=nil;work(engine,^{chosen=engine.selectedSource;});int index=chosen[@"infoHash"]?(int)[hashes indexOfObject:chosen[@"infoHash"]]:-1;
   check(index>=0&&index<amount,"Winner belongs to requested sources");if(burst)check(index==1,"Brief high-seed burst loses to sustainable peer");
   if(index>=0&&index<amount){
   double needed=deadline?300000:burst?(index==0?1000000:250000):fast?250000:300000;double play=clockNow();int64_t consumed=0;double starved=0,last=play;
   while(clockNow()-play<15&&!interrupted){external();double time=clockNow(),target=needed*(time-play),dt=time-last;last=time;
    if(consumed+65536<=target){int64_t offset=consumed;work(engine,^{[engine prioritizeOffset:offset length:65536];v->bytes=[engine readVerifiedBytesAt:offset length:65536];v->snapshot=[engine snapshot];});if(v->bytes.length)consumed+=v->bytes.length;else starved+=dt;}
    std::this_thread::sleep_for(std::chrono::milliseconds(20));
   }
   bool keptUp=consumed>=needed*14;check(keptUp,"Verified-byte consumer keeps up with independent media requirement");check(starved<1,"Sustained controlled reader avoids starvation");
   emit(@{@"event":@"consumer",@"selected_index":@(index),@"required":@(needed),@"consumed_bytes":@(consumed),@"seconds":@(clockNow()-play),@"starved_seconds":@(starved),@"kept_up":@(keptUp)});
   }
  }
  emit(@{@"event":@"result",@"mode":mode,@"checks":@(checks),@"failures":@(failures),@"selection_seconds":@(selectedAt),@"seconds":@(clockNow()-began),@"race":v->race?:@{},@"observations":observations,@"snapshot":v->snapshot?:@{},@"scope":@"Actual engine and controlled loopback peers; generated bytes paced at independently declared consumption rate, no decoder/iPad performance claim."});return failures?1:0;
 }catch(const std::exception &e){fprintf(stderr,"%s\n",e.what());return 3;}
}}
