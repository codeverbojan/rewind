// Actual pinned torrent engine + resource loader + Mac AVPlayer. Each delivered
// byte is compared with the independent generated file. No engine rules replaced.
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import "../TorrentEngine.h"
#import "../TorrentLoader.h"
#include <libtorrent/session.hpp>
#include <libtorrent/alert_types.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/write_resume_data.hpp>
#include <libtorrent/hasher.hpp>
#include <libtorrent/bencode.hpp>
#include <csignal>
#include <atomic>
#include <memory>
#include <cstring>
#include <unistd.h>
namespace lt=libtorrent;
static volatile std::sig_atomic_t interrupted=0;static void stop(int){interrupted=1;}
static double now(){return NSProcessInfo.processInfo.systemUptime;}
static void pump(double seconds){[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];}
template<class F>static bool until(F f,double bound){double end=now()+bound;while(now()<end){if(interrupted)throw std::runtime_error("Interrupted");if(f())return true;pump(.05);}return f();}
static void work(TorrentEngine *engine,void(^body)(void)){dispatch_semaphore_t done=dispatch_semaphore_create(0);[engine perform:^(TorrentEngine *e){body();dispatch_semaphore_signal(done);}];if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC)))throw std::runtime_error("Engine queue timeout");}
static void emit(NSDictionary *d){NSData *data=[NSJSONSerialization dataWithJSONObject:d options:0 error:nil];if(!data)throw std::runtime_error("Invalid result JSON");fwrite(data.bytes,1,data.length,stdout);putchar('\n');fflush(stdout);}
@interface OracleEngine:TorrentEngine
@property(nonatomic,strong) NSData *oracle;
@property(nonatomic) uint64_t reads,bytes,mismatches;
@end
@implementation OracleEngine
-(NSData *)readVerifiedBytesAt:(int64_t)offset length:(NSUInteger)length{
 NSData *data=[super readVerifiedBytesAt:offset length:length];self.reads++;self.bytes+=data.length;
 if(data.length&&(offset<0||uint64_t(offset)>self.oracle.length||data.length>self.oracle.length-uint64_t(offset)||memcmp(data.bytes,(const char *)self.oracle.bytes+offset,data.length)))self.mismatches++;
 return data;
}
@end
struct Owner{__strong OracleEngine *engine=nil;__strong TorrentLoader *loader=nil;__strong AVPlayer *player=nil;~Owner(){[player pause];[player replaceCurrentItemWithPlayerItem:nil];[loader stop];if(engine)work(engine,^{[engine shutdown];});}};
int main(int argc,char **argv){@autoreleasepool{
 std::signal(SIGINT,stop);std::signal(SIGTERM,stop);int checks=0,failures=0;auto check=[&](bool ok,const char *message){checks++;if(!ok){failures++;fprintf(stderr,"FAIL:%s\n",message);}};
 NSMutableDictionary *result=[NSMutableDictionary new];NSMutableArray *timeline=[NSMutableArray new],*seedEvents=[NSMutableArray new];result[@"seed_events"]=seedEvents;
 try{
  if(argc!=4)return 2;NSString *cache=@(argv[1]);BOOL prepared=!strcmp(argv[2],"prepared");double sustain=atof(argv[3]);if(![@[@"cold",@"partial",@"complete"]containsObject:cache]||(!prepared&&strcmp(argv[2],"direct"))||(sustain!=8&&sustain!=120))return 2;
  const char *folder=getenv("REWIND_ENGINE_FIXTURE_ROOT"),*input=getenv("REWIND_ENGINE_MOVIE");if(!folder||!input)return 2;
  NSString *client=[@(folder)stringByAppendingPathComponent:@"client"],*seedPath=[@(folder)stringByAppendingPathComponent:@"seed"];for(NSString *p in @[client,seedPath])[NSFileManager.defaultManager createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];
  setenv("REWIND_ENGINE_TEST_ROOT",client.UTF8String,1);setenv("REWIND_ENGINE_BENCHMARK_MODE","cache-study",1);
  NSData *movie=[NSData dataWithContentsOfFile:@(input) options:NSDataReadingMappedIfSafe error:nil];if(movie.length<32*1024*1024)throw std::runtime_error("Missing generated180s movie");
  const int pieceBytes=1024*1024,pieces=int((movie.length+pieceBytes-1)/pieceBytes);std::string hashes;
  for(int i=0;i<pieces;i++){size_t at=size_t(i)*pieceBytes,len=std::min<size_t>(pieceBytes,movie.length-at);hashes+=lt::hasher((const char*)movie.bytes+at,len).final().to_string();}
  lt::entry entry;entry["info"]["name"]="generated.mp4";entry["info"]["length"]=int64_t(movie.length);entry["info"]["piece length"]=pieceBytes;entry["info"]["pieces"]=hashes;auto info=std::make_shared<lt::torrent_info>(entry);
  NSMutableString *hash=[NSMutableString new];for(unsigned char c:info->info_hash().to_string())[hash appendFormat:@"%02x",c];
  NSString *meta=[client stringByAppendingPathComponent:@"TorrentMetadata"],*path=[[client stringByAppendingPathComponent:@"Torrents"]stringByAppendingPathComponent:hash];
  BOOL complete=[cache isEqual:@"complete"],partial=[cache isEqual:@"partial"];
  if(partial||complete){
   for(NSString *p in @[meta,path])[NSFileManager.defaultManager createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];std::vector<char> encoded;lt::bencode(std::back_inserter(encoded),entry);[[NSData dataWithBytes:encoded.data() length:encoded.size()]writeToFile:[meta stringByAppendingPathComponent:[hash stringByAppendingString:@".torrent"]] atomically:YES];
   FILE *f=fopen([path stringByAppendingPathComponent:@"generated.mp4"].fileSystemRepresentation,"wb");if(!f)throw std::runtime_error("Cannot create owned fixture cache");size_t prefix=complete?movie.length:4*pieceBytes;bool wrote=fwrite(movie.bytes,1,prefix,f)==prefix&&ftruncate(fileno(f),movie.length)==0;wrote=fclose(f)==0&&wrote;if(!wrote)throw std::runtime_error("Cache write failed");
   lt::add_torrent_params saved;saved.info_hash=info->info_hash();saved.have_pieces.resize(pieces,complete);if(partial)for(int i=0;i<4;i++)saved.have_pieces.set_bit(lt::piece_index_t(i));auto data=lt::write_resume_data_buf(saved);[[NSData dataWithBytes:data.data() length:data.size()]writeToFile:[path stringByAppendingPathComponent:@"rewind.resume"] atomically:YES];
  }
  lt::settings_pack settings;settings.set_str(lt::settings_pack::listen_interfaces,"127.0.0.1:0");settings.set_bool(lt::settings_pack::enable_dht,false);settings.set_bool(lt::settings_pack::enable_lsd,false);settings.set_bool(lt::settings_pack::enable_upnp,false);settings.set_bool(lt::settings_pack::enable_natpmp,false);settings.set_bool(lt::settings_pack::enable_incoming_utp,false);settings.set_bool(lt::settings_pack::enable_outgoing_utp,false);settings.set_int(lt::settings_pack::unchoke_interval,1);settings.set_int(lt::settings_pack::optimistic_unchoke_interval,1);settings.set_int(lt::settings_pack::stop_tracker_timeout,0);
  settings.set_int(lt::settings_pack::alert_mask,lt::alert::connect_notification|lt::alert::peer_notification|lt::alert::status_notification|lt::alert::error_notification);
  lt::session seedSession(settings);double seedStarted=now();auto observeSeed=[&]{std::vector<lt::alert *> alerts;seedSession.pop_alerts(&alerts);for(auto *a:alerts)if(lt::alert_cast<lt::peer_disconnected_alert>(a)||lt::alert_cast<lt::peer_connect_alert>(a))[seedEvents addObject:@{@"seconds":@(now()-seedStarted),@"message":@(a->message().c_str())}];};lt::add_torrent_params seedParams;seedParams.ti=info;seedParams.save_path=seedPath.UTF8String;seedParams.flags&=~(lt::torrent_flags::paused|lt::torrent_flags::auto_managed);auto seed=seedSession.add_torrent(seedParams);
  if(!until([&]{auto s=seed.status();return s.state!=lt::torrent_status::checking_files&&s.state!=lt::torrent_status::checking_resume_data;},5))throw std::runtime_error("Seed initialization timeout");
  for(int i=0;i<pieces;i++)seed.add_piece(lt::piece_index_t(i),(const char*)movie.bytes+size_t(i)*pieceBytes);
  if(!until([&]{return seed.status().is_seeding&&seedSession.listen_port()>0;},8))throw std::runtime_error("Seed hash verification failed");int port=seedSession.listen_port();emit(@{@"event":@"listener",@"port":@(port)});seed.set_upload_limit(1024*1024);
  // Complete-cache cases intentionally have no peer, establishing offline reuse.
  if(complete)seed.pause();NSString *url=complete?[NSString stringWithFormat:@"magnet:?xt=urn:btih:%@",hash]:[NSString stringWithFormat:@"magnet:?xt=urn:btih:%@&x.pe=127.0.0.1:%d",hash,port];
  NSDictionary *source=@{@"url":url,@"infoHash":hash,@"fileIdx":@0,@"filename":@"generated.mp4",@"durationHintSeconds":@180,@"score":@100,@"provider":@"Generated controlled peer"};
  Owner owner;owner.engine=[OracleEngine new];owner.engine.oracle=movie;OracleEngine *engine=owner.engine;struct State{__strong NSDictionary *race=nil,*prep=nil,*snapshot=nil;}state;State *v=&state;
  double detail=now(),pressed=detail,selected=-1;
  if(prepared){
   // Reproduce the existing controller's one-second admission delay inside
   // five seconds of detail dwell; engine API itself remains production code.
   until([&]{return now()-detail>=1;},1.1);work(engine,^{[engine startPreparingCandidates:@[source]];});
   until([&]{observeSeed();work(engine,^{[engine setPreparationPayloadAllowed:YES];v->race=[engine discoverySnapshot];v->prep=[engine preparationSnapshot];});return now()-detail>=5;},4.2);
   pressed=now();__block BOOL adopted=NO;work(engine,^{adopted=[engine adoptPreparation];});check(adopted,"Detail handoff retains the same engine");
  }else work(engine,^{[engine startCandidates:@[source]];});
  BOOL qualified=until([&]{observeSeed();work(engine,^{v->race=[engine discoverySnapshot];});return [v->race[@"selected"]boolValue]||[v->race[@"exhausted"]boolValue];},35)&&[v->race[@"selected"]boolValue];selected=now();
  [result addEntriesFromDictionary:@{@"cache":cache,@"path":prepared?@"prepared":@"direct",@"sustain_target":@(sustain),@"detail_dwell_seconds":@(pressed-detail),@"selection_seconds":@(selected-pressed),@"race":v->race?:@{},@"preparation":v->prep?:@{}}];check(qualified,"Source satisfies ordinary production qualification");if(!qualified)throw std::runtime_error("Source did not qualify within35s controlled bound");
  if(prepared){check([v->prep[@"session_id"]isEqual:v->race[@"session_id"]],"Preparation session identity is retained");check([v->prep[@"torrent_start_count"]isEqual:v->race[@"torrent_start_count"]],"Preparation does not create another torrent handle");check([v->prep[@"payload_bytes"]unsignedLongLongValue]<=32ULL*1024*1024,"Preparation stays within32MiB budget");}
  owner.loader=[[TorrentLoader alloc]initWithEngine:engine name:@"generated.mp4" size:movie.length];AVPlayerItem *item=[owner.loader playerItem];AVPlayerItemVideoOutput *output=[[AVPlayerItemVideoOutput alloc]initWithPixelBufferAttributes:@{(NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)}];[item addOutput:output];owner.player=[AVPlayer playerWithPlayerItem:item];owner.player.muted=YES;AVPlayer *player=owner.player;
  double first=-1,firstPosition=-1,lastPosition=0,lastMotion=now(),firstFramePTS=-1,lastFramePTS=-1;NSUInteger frames=0,stalls=0,frameStalls=0;BOOL inStall=NO,inFrameStall=NO,playSent=NO,dimensionsCorrect=YES;double lastFrameMotion=now();double lastSample=0;__block NSUInteger byteFailures=0;
  double bound=pressed+55+sustain;
  while(now()<bound&&!interrupted){
   pump(.03);observeSeed();if(item.status==AVPlayerItemStatusFailed)break;if(item.status==AVPlayerItemStatusReadyToPlay&&!playSent){[player play];playSent=YES;lastMotion=now();}
   CMTime at=player.currentTime;double pos=CMTimeGetSeconds(at);if(!isfinite(pos))pos=0;
   if([output hasNewPixelBufferForItemTime:at]){CMTime display=kCMTimeInvalid;CVPixelBufferRef frame=[output copyPixelBufferForItemTime:at itemTimeForDisplay:&display];if(frame){double pts=CMTimeGetSeconds(display);if(isfinite(pts)){if(firstFramePTS<0)firstFramePTS=pts;if(pts>lastFramePTS+.01){lastFrameMotion=now();inFrameStall=NO;}lastFramePTS=pts;frames++;}dimensionsCorrect=dimensionsCorrect&&CVPixelBufferGetWidth(frame)==1280&&CVPixelBufferGetHeight(frame)==720;CVPixelBufferRelease(frame);}}
   if(first<0&&frames>=2&&lastFramePTS>firstFramePTS+.2&&pos>.25&&player.rate>0){first=now();firstPosition=pos;lastPosition=pos;lastMotion=now();emit(@{@"event":@"advancing",@"seconds":@(first-pressed),@"decoded_frame_pts":@(lastFramePTS)});}
   if(first>=0){if(pos>lastPosition+.01){lastPosition=pos;lastMotion=now();inStall=NO;}else if(now()-lastMotion>1&&!inStall){stalls++;inStall=YES;}}
   if(first>=0&&now()-lastFrameMotion>1&&!inFrameStall){frameStalls++;inFrameStall=YES;}
   if(now()-lastSample>=1){lastSample=now();work(engine,^{v->snapshot=[engine snapshot];byteFailures=engine.mismatches;});check(![v->snapshot[@"cache_integrity_failed"]boolValue],"Cache integrity remains valid");check([v->snapshot[@"playback_wanted_byte_bound"]unsignedLongLongValue]<=64ULL*1024*1024,"Playback request window remains bounded");[timeline addObject:@{@"elapsed":@(now()-pressed),@"position":@(pos),@"frame_pts":@(lastFramePTS),@"rate":@(player.rate),@"payload":v->snapshot[@"peer_payload_bytes"]?:@0,@"verified_read_bytes":v->snapshot[@"verified_read_bytes"]?:@0}];}
   if(first>=0&&now()-first>=sustain&&pos-firstPosition>=sustain-.5)break;
  }
  double end=now(),position=CMTimeGetSeconds(player.currentTime);[player pause];check(first>=0&&end-first>=sustain&&position-firstPosition>=sustain-.5,"Actual decoded video sustains requested observation");check(stalls==0,"Healthy controlled peer has no playback stall over1second");check(!byteFailures,"Every delivered byte matches independently generated input");
  check(dimensionsCorrect,"All observed decoded frames have expected dimensions");check(lastFramePTS-firstFramePTS>=sustain-.5,"Decoded frame timestamps cover sustained interval");check(frameStalls==0,"Decoded frames keep advancing without a one-second freeze");
  double paused=position;pump(.4);check(fabs(CMTimeGetSeconds(player.currentTime)-paused)<.15,"Pause preserves position");
  auto seekDone=std::make_shared<std::atomic<bool>>(false);[player seekToTime:CMTimeMakeWithSeconds(150,600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL ok){seekDone->store(ok);if(ok)[player play];}];double seekBegan=now();BOOL seekFrame=NO;
  BOOL seekOK=until([&]{CMTime t=player.currentTime;double pos=CMTimeGetSeconds(t);if([output hasNewPixelBufferForItemTime:t]){CMTime pts=kCMTimeInvalid;CVPixelBufferRef f=[output copyPixelBufferForItemTime:t itemTimeForDisplay:&pts];if(f){double time=CMTimeGetSeconds(pts);if(isfinite(time)&&time>=150&&time<158)seekFrame=YES;CVPixelBufferRelease(f);}}return seekDone->load()&&seekFrame&&pos>=151;},20);
  check(seekOK,"Seek resumes with an actual decoded frame at requested range");double forwardSeconds=now()-seekBegan;
  [player pause];auto backDone=std::make_shared<std::atomic<bool>>(false);BOOL backFrame=NO;double backBegan=now();[player seekToTime:CMTimeMakeWithSeconds(15,600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL ok){backDone->store(ok);if(ok)[player play];}];
  BOOL backOK=until([&]{CMTime t=player.currentTime;double pos=CMTimeGetSeconds(t);if([output hasNewPixelBufferForItemTime:t]){CMTime pts=kCMTimeInvalid;CVPixelBufferRef f=[output copyPixelBufferForItemTime:t itemTimeForDisplay:&pts];if(f){double time=CMTimeGetSeconds(pts);if(isfinite(time)&&time>=15&&time<23)backFrame=YES;CVPixelBufferRelease(f);}}return backDone->load()&&backFrame&&pos>=16&&pos<23;},20);
  check(backOK,"Backward seek resumes with decoded frame from correct range");double backwardSeconds=now()-backBegan;
  [player pause];work(engine,^{v->snapshot=[engine snapshot];});if(complete)check([v->snapshot[@"peer_payload_bytes"]longLongValue]==0,"Complete cache requires no peer payload");
  __block NSDictionary *oracle=nil;work(engine,^{oracle=@{@"reads":@(engine.reads),@"bytes":@(engine.bytes),@"mismatches":@(engine.mismatches)};});check([oracle[@"mismatches"]unsignedLongLongValue]==0,"Seek data also matches exact oracle bytes");
  [result addEntriesFromDictionary:@{@"advancing_seconds":@(first<0?-1:first-pressed),@"detail_to_advancing_seconds":@(first<0?-1:first-detail),@"observed_playing_seconds":@(first<0?0:end-first),@"position":@(isfinite(position)?position:0),@"frames_observed":@(frames),@"first_frame_pts":@(firstFramePTS),@"last_frame_pts":@(lastFramePTS),@"stalls":@(stalls),@"frame_stalls":@(frameStalls),@"seek_seconds":@(forwardSeconds),@"seek_frame":@(seekFrame),@"backward_seek_seconds":@(backwardSeconds),@"backward_seek_frame":@(backFrame),@"error":item.error.localizedDescription?:@"",@"snapshot":v->snapshot?:@{},@"oracle":oracle,@"loader":owner.loader.diagnostics?:@{}}];
 }catch(const std::exception &e){failures++;result[@"exception"]=@(e.what());fprintf(stderr,"Exception:%s\n",e.what());}
 result[@"event"]=@"result";result[@"checks"]=@(checks);result[@"failures"]=@(failures);result[@"timeline"]=timeline;result[@"scope"]=@"Actual production engine/loader and Mac AVPlayer decoder; generated180s movie, loopback peer capped1MiB/s. Five-second detail dwell models1s admission then4s engine preparation. No iPad timing, audibility or full app UI claim.";emit(result);return failures?1:0;
}}
