// Real production engine and bounded loopback peer. Delay only the closing
// piece; compare exact requested bytes with the independently generated movie.
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
#include <cstring>
namespace lt=libtorrent;
static volatile std::sig_atomic_t interrupted=0;
static void stop(int){interrupted=1;}
static double now(){return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();}
template<class F>static bool until(F f,double seconds){double end=now()+seconds;while(now()<end){if(interrupted)throw std::runtime_error("Interrupted");if(f())return true;std::this_thread::sleep_for(std::chrono::milliseconds(100));}return false;}
static void work(TorrentEngine *e,void(^body)(void)){dispatch_semaphore_t done=dispatch_semaphore_create(0);[e perform:^(TorrentEngine *unused){body();dispatch_semaphore_signal(done);}];if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC)))throw std::runtime_error("Engine queue timeout");}
struct Owner{__strong TorrentEngine *engine;~Owner(){if(engine)work(engine,^{[engine shutdown];});}};
static void emit(NSDictionary *d){NSData *data=[NSJSONSerialization dataWithJSONObject:d options:0 error:nil];printf("%s\n",[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding].UTF8String);fflush(stdout);}
int main(int argc,char **argv){@autoreleasepool{
 std::signal(SIGINT,stop);std::signal(SIGTERM,stop);int checks=0,failures=0;
 auto check=[&](bool value,const char *why){checks++;if(!value){failures++;fprintf(stderr,"FAIL:%s\n",why);}};
 try{
  NSString *mode=argc>1?@(argv[1]):@"delayed";BOOL delayed=[mode isEqual:@"delayed"],available=[mode isEqual:@"available"],cancel=[mode isEqual:@"cancel"],absent=[mode isEqual:@"absent"];
  if(!delayed&&!available&&!cancel&&!absent)return 2;
  const char *folder=getenv("REWIND_ENGINE_FIXTURE_ROOT"),*input=getenv("REWIND_ENGINE_MOVIE");if(!folder||!input)return 2;
  NSData *movie=[NSData dataWithContentsOfFile:@(input) options:NSDataReadingMappedIfSafe error:nil];if(movie.length<32*1024*1024)throw std::runtime_error("Missing generated MKV");
  NSString *client=[@(folder)stringByAppendingPathComponent:@"client"],*seedPath=[@(folder)stringByAppendingPathComponent:@"seed"],*meta=[client stringByAppendingPathComponent:@"TorrentMetadata"];
  for(NSString *p in @[client,seedPath,meta])[NSFileManager.defaultManager createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];
  setenv("REWIND_ENGINE_TEST_ROOT",client.UTF8String,1);setenv("REWIND_ENGINE_QUALIFICATION_MODE","fast",1);
  const int pieceBytes=8*1024*1024,pieces=int((movie.length+pieceBytes-1)/pieceBytes);lt::file_storage files;files.add_file("generated.mkv",movie.length);lt::create_torrent builder(files,pieceBytes);
  for(int p=0;p<pieces;p++){size_t offset=size_t(p)*pieceBytes,length=std::min<size_t>(pieceBytes,movie.length-offset);builder.set_hash(lt::piece_index_t(p),lt::hasher((const char*)movie.bytes+offset,length).final());}
  auto info=std::make_shared<lt::torrent_info>(builder.generate());NSMutableString *hash=[NSMutableString new];for(unsigned char c:info->info_hash().to_string())[hash appendFormat:@"%02x",c];
  std::vector<char> encoded;lt::bencode(std::back_inserter(encoded),builder.generate());[[NSData dataWithBytes:encoded.data() length:encoded.size()]writeToFile:[meta stringByAppendingPathComponent:[hash stringByAppendingString:@".torrent"]] atomically:YES];
  lt::settings_pack settings;settings.set_str(lt::settings_pack::listen_interfaces,"127.0.0.1:0");
  settings.set_bool(lt::settings_pack::enable_dht,false);settings.set_bool(lt::settings_pack::enable_lsd,false);settings.set_bool(lt::settings_pack::enable_upnp,false);settings.set_bool(lt::settings_pack::enable_natpmp,false);
  settings.set_bool(lt::settings_pack::close_redundant_connections,false);settings.set_bool(lt::settings_pack::enable_incoming_utp,false);settings.set_bool(lt::settings_pack::enable_outgoing_utp,false);
  settings.set_int(lt::settings_pack::unchoke_interval,1);settings.set_int(lt::settings_pack::optimistic_unchoke_interval,1);settings.set_int(lt::settings_pack::stop_tracker_timeout,0);
  lt::session seedSession(settings);lt::add_torrent_params params;params.ti=info;params.save_path=seedPath.UTF8String;params.flags&=~(lt::torrent_flags::paused|lt::torrent_flags::auto_managed);auto seed=seedSession.add_torrent(params);
  if(!until([&]{auto s=seed.status();return s.state!=lt::torrent_status::checking_files&&s.state!=lt::torrent_status::checking_resume_data;},5))throw std::runtime_error("Seed check timeout");
  for(int p=0;p<pieces-(available?0:1);p++)seed.add_piece(lt::piece_index_t(p),(const char*)movie.bytes+size_t(p)*pieceBytes);
  if(!until([&]{return seedSession.listen_port()>0&&seed.status().num_pieces>=pieces-(available?0:1);},8))throw std::runtime_error("Seed unavailable");
  seed.set_upload_limit(4000000);int port=seedSession.listen_port();emit(@{@"event":@"listener",@"port":@(port)});
  NSDictionary *source=@{@"url":[NSString stringWithFormat:@"magnet:?xt=urn:btih:%@&x.pe=127.0.0.1:%d",hash,port],@"infoHash":hash,@"fileIdx":@0,@"filename":@"generated.mkv",@"provider":@"Generated controlled peer",@"durationHintSeconds":@72,@"seeders":@1,@"score":@100};
  Owner owner{[TorrentEngine new]};TorrentEngine *engine=owner.engine;struct State{__strong NSDictionary *race=nil,*snapshot=nil;__strong NSData *bytes=nil;}state;State *v=&state;double began=now();
  work(engine,^{[engine startCandidates:@[source]];});
  bool chosen=until([&]{work(engine,^{v->race=[engine discoverySnapshot];});return [v->race[@"selected"]boolValue]||[v->race[@"exhausted"]boolValue];},35)&&[v->race[@"selected"]boolValue];
  check(chosen,"Ordinary production qualification selects generated MKV");if(!chosen)throw std::runtime_error("No selected source");
  double selected=now();BOOL released=available,reset=NO;NSUInteger headers=0;NSMutableArray *observations=[NSMutableArray new];double hold=absent?16.5:6.5,last=-1;
  while(now()-selected<hold&&!interrupted){double elapsed=now()-selected;
   if(!released&&!absent&&elapsed>=3.5){seed.add_piece(lt::piece_index_t(pieces-1),(const char*)movie.bytes+size_t(pieces-1)*pieceBytes);released=YES;emit(@{@"event":@"index_piece_available",@"seconds_after_selection":@(elapsed)});}
   if(cancel&&!reset&&elapsed>=1){work(engine,^{[engine resetPlaybackRequests];});reset=YES;}
   // Header reads on the selected file remain active while decoder setup runs.
   work(engine,^{[engine prioritizeOffset:0 length:256*1024];v->bytes=[engine readVerifiedBytesAt:0 length:64*1024];v->snapshot=[engine snapshot];});
   if(v->bytes.length){headers++;check(v->bytes.length==64*1024&&!memcmp(v->bytes.bytes,movie.bytes,v->bytes.length),"Every delivered header matches generated bytes");}
   check([v->snapshot[@"playback_wanted_byte_bound"]unsignedLongLongValue]<=64ULL*1024*1024,"Wanted transfer stays inside64MiB");
   if(elapsed-last>=1){last=elapsed;[observations addObject:@{@"seconds_after_selection":@(elapsed),@"snapshot":v->snapshot}];}
   std::this_thread::sleep_for(std::chrono::milliseconds(200));
  }
  check(headers>0,"Verified header data arrived during setup");
  const int64_t tail=movie.length-32*1024;
  // readVerified is asynchronous even for downloaded pieces. Allow disk/hash
  // completion WITHOUT requesting network priority before judging prefetch.
  BOOL beforeDemand=until([&]{work(engine,^{v->bytes=[engine readVerifiedBytesAt:tail length:32*1024];v->snapshot=[engine snapshot];});return v->bytes.length==32*1024;},.8);
  double demand=now();
  if(cancel||absent){check(!beforeDemand,"Cancelled or unavailable index is not fetched by speculative work");if(absent&&v->snapshot[@"startup_prefetch_active"])check(![v->snapshot[@"startup_prefetch_active"]boolValue],"Absent startup prefetch expires within existing15s header bound");}
  else{
   check(beforeDemand,"Closing index is already verified when decoder first needs it");
   bool readable=until([&]{work(engine,^{[engine prioritizeOffset:tail length:32*1024];v->bytes=[engine readVerifiedBytesAt:tail length:32*1024];v->snapshot=[engine snapshot];});return v->bytes.length==32*1024;},8);
   check(readable&&!memcmp(v->bytes.bytes,(const char*)movie.bytes+tail,32*1024),"Actual demanded index matches independent original bytes");
  }
  check(!interrupted,"Fixture was not interrupted");
  emit(@{@"event":@"result",@"mode":mode,@"checks":@(checks),@"failures":@(failures),@"selection_seconds":@(selected-began),@"index_ready_before_demand":@(beforeDemand),@"index_wait_seconds":@(now()-demand),@"seconds":@(now()-began),@"race":v->race,@"snapshot":v->snapshot,@"observations":observations,@"scope":@"Actual engine/loopback peer/generated MKV and independent byte oracle. Header and index demand are controlled, not an actual decoder or iPad startup benchmark."});return failures?1:0;
 }catch(const std::exception &e){fprintf(stderr,"%s\n",e.what());return 3;}
}}
