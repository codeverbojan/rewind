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
#include <unistd.h>
#include <fcntl.h>
namespace lt=libtorrent;
static volatile std::sig_atomic_t interrupted=0;
static void stop(int){interrupted=1;}
static double now(){return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();}
template<typename F>static bool waitFor(F f,double seconds){double end=now()+seconds;while(now()<end){if(interrupted)throw std::runtime_error("Interrupted");if(f())return true;std::this_thread::sleep_for(std::chrono::milliseconds(250));}return false;}
static void work(TorrentEngine *engine,void(^body)(void)){
    dispatch_semaphore_t done=dispatch_semaphore_create(0);
    [engine perform:^(TorrentEngine *e){body();dispatch_semaphore_signal(done);}];
    if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC)))throw std::runtime_error("Engine queue timeout");
}
struct EngineOwner {__strong TorrentEngine *engine;~EngineOwner(){if(engine)work(engine,^{[engine shutdown];});}};
int main(){@autoreleasepool{
    std::signal(SIGINT,stop);std::signal(SIGTERM,stop);int checks=0,failures=0;
    auto check=[&](bool ok,const char *message){checks++;if(!ok){failures++;std::fprintf(stderr,"FAIL: %s\n",message);}};
    const char *root=getenv("REWIND_ENGINE_FIXTURE_ROOT");if(!root||!*root)return 2;
    struct Cleanup{std::string root;~Cleanup(){[[NSFileManager defaultManager]removeItemAtPath:@(root.c_str()) error:nil];}}cleanup{root};
    try{
        NSString *client=[@(root)stringByAppendingPathComponent:@"client"],*seedPath=[@(root)stringByAppendingPathComponent:@"seed"];
        for(NSString *path in @[client,seedPath])[[NSFileManager defaultManager]createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        setenv("REWIND_ENGINE_TEST_ROOT",client.UTF8String,1);
        const char *benchmark=getenv("REWIND_ENGINE_BENCHMARK_MODE");int pieceMiB=benchmark&&getenv("REWIND_ENGINE_PIECE_MIB")?atoi(getenv("REWIND_ENGINE_PIECE_MIB")):1;if(pieceMiB!=1&&pieceMiB!=4&&pieceMiB!=8)throw std::runtime_error("Invalid fixture piece size");int pieceBytes=pieceMiB*1024*1024,pieceCount=64/pieceMiB;std::vector<char> bytes(pieceBytes,'R');lt::file_storage files;
        if(getenv("REWIND_ENGINE_STORAGE_CHECK")){files.add_file("fixture/fixture.mp4",64LL*1024*1024-65536);files.add_file("fixture/english.srt",65536);}
        else files.add_file("fixture.mp4",64LL*1024*1024);
        lt::create_torrent builder(files,pieceBytes);builder.set_priv(false);auto hash=lt::hasher(bytes.data(),bytes.size()).final();for(int i=0;i<pieceCount;i++)builder.set_hash(lt::piece_index_t(i),hash);
        auto info=std::make_shared<lt::torrent_info>(builder.generate());
        lt::settings_pack settings;settings.set_str(lt::settings_pack::listen_interfaces,"127.0.0.1:0");
        settings.set_bool(lt::settings_pack::enable_dht,false);settings.set_bool(lt::settings_pack::enable_lsd,false);settings.set_bool(lt::settings_pack::enable_upnp,false);settings.set_bool(lt::settings_pack::enable_natpmp,false);
        settings.set_bool(lt::settings_pack::close_redundant_connections,false);settings.set_bool(lt::settings_pack::enable_incoming_utp,false);settings.set_bool(lt::settings_pack::enable_outgoing_utp,false);
        settings.set_int(lt::settings_pack::unchoke_interval,3);settings.set_int(lt::settings_pack::optimistic_unchoke_interval,3);settings.set_int(lt::settings_pack::stop_tracker_timeout,0);
        lt::session seedSession(settings);lt::add_torrent_params params;params.ti=info;params.save_path=seedPath.UTF8String;params.flags&=~(lt::torrent_flags::paused|lt::torrent_flags::auto_managed);auto seed=seedSession.add_torrent(params);
        check(waitFor([&]{auto s=seed.status();return s.state!=lt::torrent_status::checking_files&&s.state!=lt::torrent_status::checking_resume_data;},5),"Fixture seed initializes");
        for(int i=0;i<pieceCount;i++)seed.add_piece(lt::piece_index_t(i),bytes.data());
        check(waitFor([&]{return seed.status().is_seeding&&seedSession.listen_port()>0;},5),"Generated fixture is verified and available only on loopback");
        int port=seedSession.listen_port();std::printf("{\"event\":\"listener\",\"port\":%d}\n",port);std::fflush(stdout);
        NSMutableString *hex=[NSMutableString new];for(unsigned char c:info->info_hash().to_string())[hex appendFormat:@"%02x",c];
        NSString *magnet=[NSString stringWithFormat:@"magnet:?xt=urn:btih:%@&x.pe=127.0.0.1:%d",hex,port];
        NSDictionary *source=@{@"url":magnet,@"infoHash":hex,@"fileIdx":@0,@"filename":@"fixture.mp4",@"provider":@"Generated local fixture",@"durationHintSeconds":@3600,@"score":@100};
#include "PreparationCacheChecks.inc"
#include "PreparationStorageChecks.inc"
#include "PreparationQualificationChecks.inc"
        if(benchmark){
            NSString *mode=@(benchmark);BOOL cold=[mode isEqual:@"cold"],metadataOnly=[mode isEqual:@"metadata5"];
            double dwell=cold?0:[mode isEqual:@"preload10"]?10:5;
            if(![@[@"cold",@"metadata5",@"preload5",@"preload10"]containsObject:mode])throw std::runtime_error("Invalid benchmark mode");
            EngineOwner owner{[TorrentEngine new]};TorrentEngine *engine=owner.engine;
            struct Bench {__strong NSDictionary *race=nil,*prepared=nil,*snapshot=nil;__strong NSData *bytes=nil;};Bench value;Bench *v=&value;
            double detail=now(),pressed=detail;
            if(cold)work(engine,^{[engine startCandidates:@[source]];});
            else{
                work(engine,^{[engine startPreparingCandidates:@[source]];[engine setPreparationPayloadAllowed:!metadataOnly];});
                waitFor([&]{work(engine,^{v->race=[engine discoverySnapshot];v->prepared=[engine preparationSnapshot];});return now()-detail>=dwell;},dwell+2);
                pressed=now();__block BOOL adopted=NO;work(engine,^{adopted=[engine adoptPreparation];});if(!adopted)throw std::runtime_error("Benchmark preparation adoption failed");
            }
            bool selected=waitFor([&]{work(engine,^{v->race=[engine discoverySnapshot];});return [v->race[@"selected"]boolValue];},35);
            double qualified=now()-pressed;bool readable=false;
            if(selected)readable=waitFor([&]{work(engine,^{[engine prioritizeOffset:0 length:65536];v->bytes=[engine readVerifiedBytesAt:0 length:65536];v->snapshot=[engine snapshot];});return v->bytes.length==65536;},5);
            NSDictionary *result=@{@"event":@"benchmark",@"mode":mode,@"piece_mib":@(pieceMiB),@"rate_limit_bytes_per_second":@(1024*1024),@"cache_state":@"empty client directory",@"detail_dwell_seconds":@(pressed-detail),@"tap_to_qualified_seconds":@(qualified),@"tap_to_readable_seconds":@(now()-pressed),@"detail_to_readable_seconds":@(now()-detail),@"prepared_payload_bytes":v->prepared[@"payload_bytes"]?:@0,@"prepared_allocated_growth_bytes":v->prepared[@"allocated_growth_bytes"]?:@0,@"total_payload_bytes":v->snapshot[@"peer_payload_bytes"]?:@0,@"allocated_video_bytes":v->snapshot[@"allocated_video_bytes"]?:@0,@"actual_wanted_bytes":v->snapshot[@"wanted_bytes"]?:@0,@"window_byte_bound":v->snapshot[@"playback_wanted_byte_bound"]?:@0,@"selected":@(selected),@"readable":@(readable),@"session_reused":@(cold||[v->prepared[@"session_id"]isEqual:v->race[@"session_id"]]),@"scope":@"Host engine/data readiness; no video decoding or iPad startup claim"};
            NSData *json=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];std::printf("%s\n",[[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding].UTF8String);std::fflush(stdout);
            return selected&&readable?0:1;
        }
        EngineOwner owner{[TorrentEngine new]};TorrentEngine *engine=owner.engine;
        work(engine,^{[engine startPreparingCandidates:@[source]];});
        struct Readings {__strong NSDictionary *race=nil,*preparation=nil,*snapshot=nil;__strong NSData *opening=nil;};Readings readings;Readings *values=&readings;
        auto poll=[&]{work(engine,^{values->race=[engine discoverySnapshot];values->preparation=[engine preparationSnapshot];});};
        bool metadata=waitFor([&]{poll();for(NSDictionary *candidate in values->race[@"candidates"])if([candidate[@"metadata"]boolValue])return true;return false;},20);
        check(metadata,"Actual engine exchanges magnet metadata before payload is enabled");
        if(!metadata){NSData *debug=[NSJSONSerialization dataWithJSONObject:values->race options:0 error:nil];std::fprintf(stderr,"Metadata diagnostic: %s\n",[[NSString alloc]initWithData:debug encoding:NSUTF8StringEncoding].UTF8String);throw std::runtime_error("Fixture metadata did not arrive");}
        check([values->preparation[@"payload_bytes"]longLongValue]==0,"Metadata-only preparation transfers no film payload");
        work(engine,^{[engine setPreparationPayloadAllowed:YES];});
        bool ready=waitFor([&]{poll();return [values->race[@"prepared_ready"]boolValue];},25);
        check(ready,"Actual engine preloads a verified opening with live throughput");
        if(!ready){NSData *debug=[NSJSONSerialization dataWithJSONObject:values->preparation options:0 error:nil];std::fprintf(stderr,"Preparation diagnostic: %s\n",[[NSString alloc]initWithData:debug encoding:NSUTF8StringEncoding].UTF8String);throw std::runtime_error("Fixture prefix did not become ready");}
        __block BOOL selected=NO;work(engine,^{selected=engine.selectedSource!=nil;});
        check(!selected,"Preparation never promotes itself into an unrestricted video download");
        check([values->preparation[@"payload_bytes"]longLongValue]<=2LL*pieceBytes,"Only the header and interest-maintaining piece are wanted");
        check([values->preparation[@"allocated_growth_bytes"]longLongValue]<3LL*pieceBytes,"Physical growth stays near the bounded prefix, not the full file");
        NSString *session=values->preparation[@"session_id"];NSNumber *starts=values->preparation[@"torrent_start_count"];long long before=[values->preparation[@"payload_bytes"]longLongValue];
        work(engine,^{[engine setPreparationPayloadAllowed:NO];});
        poll();check(![values->preparation[@"payload_allowed"]boolValue],"Trailer priority suspends further speculative requests");
        __block BOOL adopted=NO;double pressed=now();work(engine,^{adopted=[engine adoptPreparation];});
        check(adopted,"Play adopts the prepared engine");
        bool playingReady=waitFor([&]{poll();return [values->race[@"selected"]boolValue];},20);
        check(playingReady,"Prepared source qualifies for actual player handoff");
        check([values->race[@"session_id"]isEqual:session]&&[values->race[@"torrent_start_count"]isEqual:starts],"Handoff creates neither a new libtorrent session nor a second torrent handle");
        work(engine,^{values->snapshot=[engine snapshot];values->opening=[engine readVerifiedBytesAt:0 length:64*1024];});
        waitFor([&]{work(engine,^{values->opening=[engine readVerifiedBytesAt:0 length:64*1024];});return values->opening.length>0;},3);
        check(values->opening.length==64*1024&&((const char *)values->opening.bytes)[0]=='R',"Player can read the same verified opening bytes after handoff");
        check([values->snapshot[@"peer_payload_bytes"]longLongValue]>=before,"Handoff preserves payload accounting and useful downloaded data");
        double handoffReady=now()-pressed;
        check([values->snapshot[@"playback_wanted_byte_bound"]longLongValue]<=9LL*pieceBytes&&[values->snapshot[@"video_total_bytes"]longLongValue]==64LL*pieceBytes,"Winning a source enables a bounded read window, not the full video");
        work(engine,^{[engine resetPlaybackRequests];[engine prioritizeOffset:32LL*pieceBytes length:65536];values->snapshot=[engine snapshot];});
        check([values->snapshot[@"requested_video_offset"]longLongValue]==32LL*pieceBytes&&[values->snapshot[@"playback_wanted_byte_bound"]longLongValue]<=9LL*pieceBytes,"Seek replaces stale opening deadlines with a bounded target window");
        bool seekRead=waitFor([&]{work(engine,^{[engine prioritizeOffset:32LL*pieceBytes length:65536];values->opening=[engine readVerifiedBytesAt:32LL*pieceBytes length:65536];});return values->opening.length==65536;},15);
        check(seekRead&&((const char *)values->opening.bytes)[0]=='R',"Player can read verified data at the seek target without restarting its torrent");
        std::printf("{\"event\":\"result\",\"checks\":%d,\"failures\":%d,\"preloaded_payload_bytes\":%lld,\"handoff_ready_seconds\":%.3f,\"session_reused\":%s}\n",checks,failures,before,handoffReady,[values->race[@"session_id"]isEqual:session]?"true":"false");
    }catch(const std::exception &e){failures++;std::fprintf(stderr,"Exception: %s\n",e.what());}
    return failures?1:0;
}}
