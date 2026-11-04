// Actual metadata selection, torrent race, and independently recognizable file
// bytes. These are source/file identity tests, not a video decoder benchmark.
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
#include <algorithm>
namespace lt=libtorrent;
static volatile std::sig_atomic_t interrupted=0;
static void stop(int){interrupted=1;}
static double now(){return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();}
template<class F>static bool until(F f,double seconds){double end=now()+seconds;while(now()<end){if(interrupted)throw std::runtime_error("Interrupted");if(f())return true;std::this_thread::sleep_for(std::chrono::milliseconds(100));}return false;}
static void work(TorrentEngine *e,void(^body)(void)){dispatch_semaphore_t done=dispatch_semaphore_create(0);[e perform:^(TorrentEngine *unused){body();dispatch_semaphore_signal(done);}];if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC)))throw std::runtime_error("Engine queue timeout");}
struct Owner{__strong TorrentEngine *engine;~Owner(){if(engine)work(engine,^{[engine shutdown];});}};
static void emit(NSDictionary *d){NSData *bytes=[NSJSONSerialization dataWithJSONObject:d options:0 error:nil];printf("%s\n",[[NSString alloc]initWithData:bytes encoding:NSUTF8StringEncoding].UTF8String);fflush(stdout);}
int main(int argc,char **argv){@autoreleasepool{
 std::signal(SIGINT,stop);std::signal(SIGTERM,stop);int checks=0,failures=0;
 auto check=[&](bool value,const char *why){checks++;if(!value){failures++;fprintf(stderr,"FAIL:%s\n",why);}};
 try{
  NSString *mode=argc>1?@(argv[1]):@"correct";
  if(![@[@"correct",@"wrong-episode",@"named-file",@"episode-number",@"ambiguous",@"duplicate-variant",@"filename-mismatch",@"same-index-variant",@"late-variant",@"prepared-variant"]containsObject:mode])return 2;
  bool reject=[@[@"wrong-episode",@"ambiguous",@"filename-mismatch"]containsObject:mode];
  const char *folder=getenv("REWIND_ENGINE_FIXTURE_ROOT");if(!folder)return 2;
  NSString *client=[@(folder)stringByAppendingPathComponent:@"client"],*seedPath=[@(folder)stringByAppendingPathComponent:@"seed"],*cache=[client stringByAppendingPathComponent:@"TorrentMetadata"];
  for(NSString *p in @[client,seedPath,cache])[NSFileManager.defaultManager createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];
  setenv("REWIND_ENGINE_TEST_ROOT",client.UTF8String,1);setenv("REWIND_ENGINE_QUALIFICATION_MODE","fast",1);
  std::string first="Generated.Show.S01E01.mkv",second=[mode isEqual:@"ambiguous"]?"Generated.Show.S01E01.Alternate.mkv":"Generated.Show.S01E02.mkv";
  const int pieceBytes=256*1024,firstPieces=16,secondPieces=32;
  lt::file_storage files;files.add_file("Season 1/"+first,int64_t(firstPieces)*pieceBytes);files.add_file("Season 1/"+second,int64_t(secondPieces)*pieceBytes);
  lt::create_torrent builder(files,pieceBytes);std::vector<char> a(pieceBytes,'A'),b(pieceBytes,'B');
  for(int p=0;p<firstPieces+secondPieces;p++)builder.set_hash(lt::piece_index_t(p),lt::hasher((p<firstPieces?a:b).data(),pieceBytes).final());
  auto info=std::make_shared<lt::torrent_info>(builder.generate());NSMutableString *hash=[NSMutableString new];for(unsigned char c:info->info_hash().to_string())[hash appendFormat:@"%02x",c];
  std::vector<char> encoded;lt::bencode(std::back_inserter(encoded),builder.generate());[[NSData dataWithBytes:encoded.data() length:encoded.size()]writeToFile:[cache stringByAppendingPathComponent:[hash stringByAppendingString:@".torrent"]] atomically:YES];
  lt::settings_pack settings;settings.set_str(lt::settings_pack::listen_interfaces,"127.0.0.1:0");settings.set_bool(lt::settings_pack::enable_dht,false);settings.set_bool(lt::settings_pack::enable_lsd,false);settings.set_bool(lt::settings_pack::enable_upnp,false);settings.set_bool(lt::settings_pack::enable_natpmp,false);settings.set_bool(lt::settings_pack::close_redundant_connections,false);settings.set_bool(lt::settings_pack::enable_incoming_utp,false);settings.set_bool(lt::settings_pack::enable_outgoing_utp,false);settings.set_int(lt::settings_pack::unchoke_interval,1);settings.set_int(lt::settings_pack::stop_tracker_timeout,0);
  lt::session seeder(settings);lt::add_torrent_params params;params.ti=info;params.save_path=seedPath.UTF8String;params.flags&=~(lt::torrent_flags::paused|lt::torrent_flags::auto_managed);auto seed=seeder.add_torrent(params);
  if(!until([&]{auto s=seed.status();return s.state!=lt::torrent_status::checking_files&&s.state!=lt::torrent_status::checking_resume_data;},5))throw std::runtime_error("Seed check timeout");
  for(int p=0;p<firstPieces+secondPieces;p++)seed.add_piece(lt::piece_index_t(p),(p<firstPieces?a:b).data());
  if(!until([&]{return seed.status().is_seeding&&seeder.listen_port()>0;},8))throw std::runtime_error("Seed unavailable");
  seed.set_upload_limit(4000000);int port=seeder.listen_port();emit(@{@"event":@"listener",@"port":@(port)});
  NSMutableDictionary *source=[@{@"url":[NSString stringWithFormat:@"magnet:?xt=urn:btih:%@&x.pe=127.0.0.1:%d",hash,port],@"infoHash":hash,@"fileIdx":@0,@"filename":@(first.c_str()),@"requestedVideoID":@"tt123456:1:1",@"provider":@"Generated identity fixture",@"durationHintSeconds":@120,@"score":@100}mutableCopy];
  if([mode isEqual:@"wrong-episode"]){source[@"fileIdx"]=@1;source[@"filename"]=@(second.c_str());}
  if([mode isEqual:@"named-file"])[source removeObjectForKey:@"fileIdx"];
  if([mode isEqual:@"episode-number"]||[mode isEqual:@"ambiguous"]){[source removeObjectForKey:@"fileIdx"];[source removeObjectForKey:@"filename"];}
  if([mode isEqual:@"filename-mismatch"])source[@"filename"]=@(second.c_str());
  NSArray *sources=@[source];
  bool late=[mode isEqual:@"late-variant"],preparing=[mode isEqual:@"prepared-variant"];
  if([mode isEqual:@"duplicate-variant"]||[mode isEqual:@"same-index-variant"]||late||preparing){NSMutableDictionary *invalid=[source mutableCopy];
   if([mode isEqual:@"same-index-variant"])invalid[@"filename"]=@(second.c_str());else invalid[@"fileIdx"]=@99;
   sources=late?@[invalid]:@[invalid,source];}
  Owner owner{[TorrentEngine new]};TorrentEngine *engine=owner.engine;struct State{__strong NSDictionary *race=nil,*snapshot=nil,*chosen=nil,*prepared=nil;__strong NSData *bytes=nil;BOOL adopted=NO;}state;State *v=&state;double began=now();
  work(engine,^{if(preparing){[engine startPreparingCandidates:sources];[engine setPreparationPayloadAllowed:YES];}else [engine startCandidates:sources];});
  if(late){
   work(engine,^{v->prepared=[engine discoverySnapshot];[engine appendCandidates:@[source]];v->race=[engine discoverySnapshot];});
   check([v->prepared[@"exhausted"]boolValue]&&[v->race[@"exhausted"]boolValue],"Late append cannot resurrect a completed race");
   // The normal player consumes exhaustion, filters the failed locator and
   // starts remaining candidates when provider results arrive. Exercise that
   // documented start contract rather than appending to a terminal race.
   work(engine,^{[engine startCandidates:@[source]];});
  }
  if(preparing){
   bool metadata=until([&]{work(engine,^{[engine discoverySnapshot];v->prepared=[engine preparationSnapshot];});for(NSDictionary *c in v->prepared[@"discovery"][@"candidates"])if([c[@"metadata"]boolValue]&&[c[@"fileIdx"]intValue]==0)return true;return false;},8);
   check(metadata,"Preparation retains the valid locator after rejecting the bad one");
   work(engine,^{v->adopted=[engine adoptPreparation];});check(v->adopted,"Player adopts the same prepared engine");
   emit(@{@"event":@"prepared_handoff",@"snapshot":v->prepared?:@{},@"adopted":@(v->adopted)});
  }
  bool terminal=until([&]{work(engine,^{v->race=[engine discoverySnapshot];});return [v->race[@"selected"]boolValue]||[v->race[@"exhausted"]boolValue];},25);
  check(terminal,"Actual source race reaches a bounded terminal result");check([v->race[@"session_count"]intValue]==1,"One engine session");
  check([v->race[@"max_parallel"]intValue]<=3,"Existing probe bound retained");
  BOOL selected=[v->race[@"selected"]boolValue];
  if(late||preparing){check([v->race[@"session_id"]isEqual:v->prepared[@"session_id"]],"Late results/preparation keep the original engine session");
   check([v->race[@"torrent_start_count"]intValue]==2,"Exactly the bad and good locators start, with no handoff restart");}
  if(reject)check(!selected&&[v->race[@"exhausted"]boolValue],"Contradictory or ambiguous episode cannot qualify");
  else check(selected,"The intended available file remains selectable");
  if(selected){
   bool ready=until([&]{work(engine,^{v->chosen=engine.selectedSource;[engine prioritizeOffset:0 length:65536];v->bytes=[engine readVerifiedBytesAt:0 length:65536];v->snapshot=[engine snapshot];});return v->bytes.length==65536;},3);
   check(ready,"Selected handle serves hash-verified opening bytes");
   if(!reject)check(ready&&std::all_of((const char*)v->bytes.bytes,(const char*)v->bytes.bytes+v->bytes.length,[](char c){return c=='A';}),"Selected bytes belong to requested episode1, not larger episode2");
  }
  emit(@{@"event":@"result",@"mode":mode,@"checks":@(checks),@"failures":@(failures),@"seconds":@(now()-began),@"expected_rejection":@(reject),@"race":v->race?:@{},@"snapshot":v->snapshot?:@{},@"chosen":v->chosen?:@{},@"scope":@"Actual engine metadata/race and independent A/B byte oracle; generated data is not a decodable movie or proof of semantic title truth."});return failures?1:0;
 }catch(const std::exception &e){fprintf(stderr,"%s\n",e.what());return 3;}
}}
