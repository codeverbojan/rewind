// P03 actual pinned-engine metadata/storage acceptance. All paths and bytes
// belong to one disposable fixture; no public peers, device or user files.
#import <Foundation/Foundation.h>
#import "../TorrentEngine.h"
#include <libtorrent/session.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/hasher.hpp>
#include <libtorrent/bencode.hpp>
#include <chrono>
#include <thread>
#include <csignal>
#include <sys/stat.h>
#include <unistd.h>
namespace lt=libtorrent;
static volatile std::sig_atomic_t interrupted=0;
static void stop(int){interrupted=1;}
static double now(){return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();}
template<class F>static bool until(F f,double seconds){double end=now()+seconds;while(now()<end){if(interrupted)throw std::runtime_error("Interrupted");if(f())return true;std::this_thread::sleep_for(std::chrono::milliseconds(100));}return false;}
static void work(TorrentEngine *e,void(^body)(void)){dispatch_semaphore_t done=dispatch_semaphore_create(0);[e perform:^(TorrentEngine *unused){body();dispatch_semaphore_signal(done);}];if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC)))throw std::runtime_error("Engine queue timeout");}
struct Owner{__strong TorrentEngine *engine;~Owner(){if(engine)work(engine,^{[engine shutdown];});}};
static void emit(NSDictionary *d){NSData *b=[NSJSONSerialization dataWithJSONObject:d options:0 error:nil];printf("%s\n",[[NSString alloc]initWithData:b encoding:NSUTF8StringEncoding].UTF8String);fflush(stdout);}
static void mkdir(NSString *p){NSError *error=nil;if(![NSFileManager.defaultManager createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:&error])throw std::runtime_error(error.description.UTF8String);}
static lt::entry file(int64_t bytes,std::vector<std::string> path){lt::entry e;e["length"]=bytes;for(auto &c:path)e["path"].list().push_back(c);return e;}
int main(int argc,char **argv){@autoreleasepool{
 std::signal(SIGINT,stop);std::signal(SIGTERM,stop);int checks=0,failures=0;
 auto check=[&](bool value,const char *why){checks++;if(!value){failures++;fprintf(stderr,"FAIL:%s\n",why);}};
 try{
  NSString *mode=argc>1?@(argv[1]):@"regular";
  if(![@[@"regular",@"unicode",@"peer-regular",@"peer-traversal",@"partfile-link",@"resume-link",@"metadata-link",@"declared-link",@"raw-traversal",@"raw-absolute",@"file-link",@"folder-link",@"hash-link",@"piece-limit",@"file-count",@"space-limit",@"wrong-hash"]containsObject:mode])return 2;
  const char *folder=getenv("REWIND_ENGINE_FIXTURE_ROOT");if(!folder)return 2;
  NSString *base=@(folder),*client=[base stringByAppendingPathComponent:@"client"],*seedPath=[base stringByAppendingPathComponent:@"seed"],*cache=[client stringByAppendingPathComponent:@"TorrentMetadata"],*protectedDir=[base stringByAppendingPathComponent:@"protected"];
  for(NSString *p in @[client,seedPath,cache,protectedDir])mkdir(p);
  setenv("REWIND_ENGINE_TEST_ROOT",client.UTF8String,1);setenv("REWIND_ENGINE_QUALIFICATION_MODE","fast",1);
  const int defaultPiece=256*1024;int pieceBytes=[mode isEqual:@"piece-limit"]?32*1024*1024:defaultPiece;
  int64_t size=4*1024*1024;
  if([mode isEqual:@"space-limit"]){pieceBytes=16*1024*1024;size=[[[NSFileManager defaultManager]attributesOfFileSystemForPath:client error:nil][NSFileSystemFreeSize]longLongValue]+1024LL*1024*1024;}
  lt::entry entry;auto &info=entry["info"];info["name"]="Fixture";info["piece length"]=pieceBytes;
  std::vector<std::string> path={"Generated.mkv"};if([mode isEqual:@"unicode"])path={"Film – 日本語 Česky.mkv"};
  if([mode isEqual:@"raw-traversal"]||[mode isEqual:@"peer-traversal"])path={"..","escaped.mkv"};
  if([mode isEqual:@"raw-absolute"])path={std::string(protectedDir.UTF8String)+"/absolute.mkv"};
  info["files"].list().push_back(file(size,path));
  if([mode isEqual:@"declared-link"]){auto f=file(0,{"link.mkv"});f["attr"]="l";f["symlink path"].list().push_back("Generated.mkv");info["files"].list().push_back(f);}
  if([mode isEqual:@"file-count"])for(int i=0;i<1000;i++)info["files"].list().push_back(file(0,{"empty"+std::to_string(i)+".txt"}));
  std::vector<char> data(std::min<int64_t>(pieceBytes,size),'A');std::string pieces;
  std::string fullHash=lt::hasher(data.data(),int(data.size())).final().to_string();for(int64_t offset=0;offset<size;offset+=pieceBytes){int n=int(std::min<int64_t>(pieceBytes,size-offset));pieces+=(n==int(data.size())?fullHash:lt::hasher(data.data(),n).final().to_string());}info["pieces"]=pieces;
  std::vector<char> encoded;lt::bencode(std::back_inserter(encoded),entry);
  lt::error_code parseError;auto torrent=std::make_shared<lt::torrent_info>(encoded.data(),int(encoded.size()),parseError);
  check(!parseError,"Generated metadata is parseable by pinned libtorrent");if(parseError)throw std::runtime_error(parseError.message());
  NSMutableString *hash=[NSMutableString new];for(unsigned char c:torrent->info_hash().to_string())[hash appendFormat:@"%02x",c];
  NSString *magnetHash=hash;if([mode isEqual:@"wrong-hash"])magnetHash=@"0123456789012345678901234567890123456789";
  if(![mode hasPrefix:@"peer-"])[[NSData dataWithBytes:encoded.data() length:encoded.size()]writeToFile:[cache stringByAppendingPathComponent:[magnetHash stringByAppendingString:@".torrent"]] atomically:YES];
  NSString *torrentRoot=[client stringByAppendingPathComponent:@"Torrents"],*swarm=[torrentRoot stringByAppendingPathComponent:magnetHash];mkdir(torrentRoot);
  if([mode isEqual:@"hash-link"])check(symlink(protectedDir.fileSystemRepresentation,swarm.fileSystemRepresentation)==0,"Create owned cache-directory symlink");else mkdir(swarm);
  NSString *video=@(torrent->files().file_path(lt::file_index_t(0),swarm.UTF8String).c_str());
  NSString *guard=[protectedDir stringByAppendingPathComponent:@"guard.bin"];
  NSData *guardBytes=[@"unchanged-owned-fixture-sentinel" dataUsingEncoding:NSUTF8StringEncoding];[guardBytes writeToFile:guard atomically:YES];
  if([mode isEqual:@"folder-link"]){check(symlink(protectedDir.fileSystemRepresentation,video.stringByDeletingLastPathComponent.fileSystemRepresentation)==0,"Create owned folder symlink");}
  if([mode isEqual:@"file-link"]){mkdir(video.stringByDeletingLastPathComponent);NSString *target=[protectedDir stringByAppendingPathComponent:@"existing.mkv"];NSMutableData *all=[NSMutableData dataWithLength:4*1024*1024];memset(all.mutableBytes,'A',all.length);[all writeToFile:target atomically:YES];check(symlink(target.fileSystemRepresentation,video.fileSystemRepresentation)==0,"Create owned video-file symlink");}
  if([mode isEqual:@"partfile-link"]||[mode isEqual:@"resume-link"]){NSString *name=[mode isEqual:@"resume-link"]?@"rewind.resume":[NSString stringWithFormat:@".%@.parts",hash];check(symlink(guard.fileSystemRepresentation,[swarm stringByAppendingPathComponent:name].fileSystemRepresentation)==0,"Create owned cache control-file symlink");}
  if([mode isEqual:@"metadata-link"]){NSString *saved=[cache stringByAppendingPathComponent:[hash stringByAppendingString:@".torrent"]],*target=[protectedDir stringByAppendingPathComponent:@"saved.torrent"];check([NSFileManager.defaultManager moveItemAtPath:saved toPath:target error:nil],"Move fixture metadata into owned protected folder");check(symlink(target.fileSystemRepresentation,saved.fileSystemRepresentation)==0,"Create owned metadata symlink");}
  bool metadataOnly=[@[@"declared-link",@"piece-limit",@"file-count",@"space-limit",@"wrong-hash"]containsObject:mode];
  std::unique_ptr<lt::session> seeder;int port=0;
  if(!metadataOnly){
   lt::settings_pack s;s.set_str(lt::settings_pack::listen_interfaces,"127.0.0.1:0");s.set_bool(lt::settings_pack::enable_dht,false);s.set_bool(lt::settings_pack::enable_lsd,false);s.set_bool(lt::settings_pack::enable_upnp,false);s.set_bool(lt::settings_pack::enable_natpmp,false);s.set_bool(lt::settings_pack::enable_incoming_utp,false);s.set_bool(lt::settings_pack::enable_outgoing_utp,false);s.set_bool(lt::settings_pack::close_redundant_connections,false);s.set_int(lt::settings_pack::stop_tracker_timeout,0);
   seeder.reset(new lt::session(s));lt::add_torrent_params p;p.ti=torrent;p.save_path=seedPath.UTF8String;p.flags&=~(lt::torrent_flags::paused|lt::torrent_flags::auto_managed);auto seed=seeder->add_torrent(p);
   if(!until([&]{auto x=seed.status();return x.state!=lt::torrent_status::checking_files&&x.state!=lt::torrent_status::checking_resume_data;},5))throw std::runtime_error("Seed checking timed out");
   for(int i=0;i<torrent->num_pieces();i++)seed.add_piece(lt::piece_index_t(i),data.data());
   if(!until([&]{return seed.status().is_seeding&&seeder->listen_port()>0;},8))throw std::runtime_error("Seed unavailable");
   port=seeder->listen_port();emit(@{@"event":@"listener",@"port":@(port)});
  }
  Owner owner{[TorrentEngine new]};TorrentEngine *engine=owner.engine;
  struct State{__strong NSDictionary *snapshot=nil;__strong NSData *bytes=nil;__strong NSString *error=nil;BOOL started=NO;}state;State *v=&state;
  NSString *magnet=[NSString stringWithFormat:@"magnet:?xt=urn:btih:%@%@",magnetHash,port?[NSString stringWithFormat:@"&x.pe=127.0.0.1:%d",port]:@""];
  double began=now();work(engine,^{NSString *error=nil;v->started=[engine startMagnet:magnet fileIndex:0 publicTest:NO error:&error];v->error=error;});
  bool expectReject=![@[@"regular",@"unicode",@"peer-regular"]containsObject:mode];
  bool settled=until([&]{work(engine,^{v->snapshot=[engine snapshot];if(!metadataOnly){[engine prioritizeOffset:0 length:65536];v->bytes=[engine readVerifiedBytesAt:0 length:65536];}});return !v->started||[v->snapshot[@"error"]length]||v->bytes.length==65536;},metadataOnly?5:20);
  if([mode isEqual:@"wrong-hash"]){check(![v->snapshot[@"metadata"]boolValue]&&engine.videoSize==0,"Mismatched saved metadata never acquires a video identity");}
  else if(expectReject){check(settled,"Invalid metadata/path reaches bounded rejection");check(!v->started||[v->snapshot[@"error"]length],"Unsafe or over-limit torrent is rejected before playback");check(v->bytes.length==0,"Rejected input cannot deliver playable bytes");}
  else{check(settled&&v->bytes.length==65536,"Ordinary file serves verified bytes");if(v->bytes.length)check(std::all_of((const char*)v->bytes.bytes,(const char*)v->bytes.bytes+v->bytes.length,[](char c){return c=='A';}),"Ordinary data matches independent byte oracle");}
  work(engine,^{[engine shutdown];});
  check([[NSData dataWithContentsOfFile:guard]isEqual:guardBytes],"Owned sentinel is unchanged");
  NSArray *protectedFiles=[NSFileManager.defaultManager contentsOfDirectoryAtPath:protectedDir error:nil];
  check(protectedFiles.count==([@[@"file-link",@"metadata-link"]containsObject:mode]?2:1),"No downloads escape into the owned protected directory");
  emit(@{@"event":@"result",@"mode":mode,@"checks":@(checks),@"failures":@(failures),@"seconds":@(now()-began),@"started":@(v->started),@"error":v->error?:@"",@"snapshot":v->snapshot?:@{},@"bytes_delivered":@(v->bytes.length),@"library_path":@(torrent->files().file_path(lt::file_index_t(0)).c_str()),@"protected_files":protectedFiles?:@[],@"scope":@"Actual host engine and owned generated bytes; direct metadata/read admission, not decoder performance."});return failures?1:0;
 }catch(const std::exception &e){fprintf(stderr,"%s\n",e.what());return 3;}
}}
