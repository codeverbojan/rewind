// Actual app engine with generated cached bytes and no external peers.
#import <Foundation/Foundation.h>
#import "../TorrentEngine.h"
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/write_resume_data.hpp>
#include <libtorrent/hasher.hpp>
#include <libtorrent/bencode.hpp>
#include <chrono>
#include <thread>
#include <csignal>
namespace lt=libtorrent;
static volatile std::sig_atomic_t interrupted=0;
static void stop(int){interrupted=1;}
static double now(){return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();}
static void work(TorrentEngine *engine,void(^body)(void)){
    dispatch_semaphore_t done=dispatch_semaphore_create(0);
    [engine perform:^(TorrentEngine *e){body();dispatch_semaphore_signal(done);}];
    if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC)))throw std::runtime_error("Engine queue timeout");
}
struct Owner{__strong TorrentEngine *engine;~Owner(){if(engine)work(engine,^{[engine shutdown];});}};
static void emit(NSDictionary *value){NSData *d=[NSJSONSerialization dataWithJSONObject:value options:0 error:nil];printf("%s\n",[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding].UTF8String);fflush(stdout);}
int main(int argc,char **argv){@autoreleasepool{
    std::signal(SIGTERM,stop);std::signal(SIGINT,stop);int checks=0,failures=0;
    auto check=[&](bool ok,const char *message){checks++;if(!ok){failures++;fprintf(stderr,"FAIL:%s\n",message);}};
    try{
        NSString *mode=argc>1?@(argv[1]):@"clean";
        if(![@[@"clean",@"corrupt",@"tail",@"missing",@"partial"]containsObject:mode])return 2;
        const char *root=getenv("REWIND_ENGINE_FIXTURE_ROOT");if(!root||!*root)return 2;
        setenv("REWIND_ENGINE_TEST_ROOT",root,1);
        const int pieceBytes=2027520,tailBytes=65537,total=pieceBytes*2+tailBytes;
        std::vector<char> file(total);std::string hashes;
        for(int i=0;i<3;i++){int length=i==2?tailBytes:pieceBytes;std::fill(file.begin()+i*pieceBytes,file.begin()+i*pieceBytes+length,char('A'+i));hashes+=lt::hasher(file.data()+i*pieceBytes,length).final().to_string();}
        lt::entry entry;entry["info"]["name"]="generated.mp4";entry["info"]["length"]=total;entry["info"]["piece length"]=pieceBytes;entry["info"]["pieces"]=hashes;
        auto info=std::make_shared<lt::torrent_info>(entry);NSMutableString *hash=[NSMutableString new];for(unsigned char c:info->info_hash().to_string())[hash appendFormat:@"%02x",c];
        NSString *meta=[@(root)stringByAppendingPathComponent:@"TorrentMetadata"],*cache=[[@(root)stringByAppendingPathComponent:@"Torrents"]stringByAppendingPathComponent:hash];
        for(NSString *path in @[meta,cache])[NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        std::vector<char> torrent;lt::bencode(std::back_inserter(torrent),entry);
        [[NSData dataWithBytes:torrent.data() length:torrent.size()]writeToFile:[meta stringByAppendingPathComponent:[hash stringByAppendingString:@".torrent"]] atomically:YES];
        if([mode isEqual:@"corrupt"])file[100000]='X'; // outside requested first64KiB
        if([mode isEqual:@"tail"])file.back()='X'; // outside requested beginning of tail
        if(![mode isEqual:@"missing"])[[NSData dataWithBytes:file.data() length:file.size()]writeToFile:[cache stringByAppendingPathComponent:@"generated.mp4"] atomically:YES];
        lt::add_torrent_params saved;saved.info_hash=info->info_hash();saved.have_pieces.resize(3,true);
        if([mode isEqual:@"partial"]){saved.have_pieces.clear_bit(lt::piece_index_t(1));saved.have_pieces.clear_bit(lt::piece_index_t(2));saved.unfinished_pieces[lt::piece_index_t(1)]=lt::bitfield(124,false);saved.unfinished_pieces[lt::piece_index_t(1)].set_bit(0);}
        auto encoded=lt::write_resume_data_buf(saved);
        [[NSData dataWithBytes:encoded.data() length:encoded.size()]writeToFile:[cache stringByAppendingPathComponent:@"rewind.resume"] atomically:YES];
        Owner owner{[TorrentEngine new]};TorrentEngine *engine=owner.engine;
        struct Reading{__strong NSDictionary *snapshot=nil;__strong NSData *bytes=nil;bool started=false;} state;Reading *v=&state;
        double began=now();work(engine,^{NSString *error=nil;v->started=[engine startMagnet:[NSString stringWithFormat:@"magnet:?xt=urn:btih:%@",hash] fileIndex:0 publicTest:NO error:&error];});
        check(v->started,"Actual engine starts with saved metadata");
        int offset=[mode isEqual:@"tail"]?pieceBytes*2:0;
        while(now()-began<6&&!interrupted){
            work(engine,^{v->snapshot=[engine snapshot];v->bytes=[engine readVerifiedBytesAt:offset length:65536];});
            if(v->bytes.length||[v->snapshot[@"error"]length])break;
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
        }
        work(engine,^{v->snapshot=[engine snapshot];});
        check(!interrupted,"Fixture not interrupted");
        check([v->snapshot[@"resume_loaded"]boolValue],"Saved progress is accepted");
        check([v->snapshot[@"peer_payload_bytes"]longLongValue]==0,"Cache test received no peer data");
        bool bad=[@[@"corrupt",@"tail",@"missing"]containsObject:mode];
        if(bad){check(v->bytes.length==0,"Damaged or missing cached bytes never reach player");if(![mode isEqual:@"missing"])check([v->snapshot[@"error"]length]>0,"Damaged cache produces explicit failure");}
        else{check(v->bytes.length==65536&&((const char*)v->bytes.bytes)[0]=='A',"Valid cached opening is readable");
            uint64_t verified=[v->snapshot[@"verified_read_pieces"]unsignedLongLongValue];
            work(engine,^{v->bytes=[engine readVerifiedBytesAt:1000 length:32000];v->snapshot=[engine snapshot];});
            check(verified==1&&[v->snapshot[@"verified_read_pieces"]unsignedLongLongValue]==verified&&v->bytes.length==32000,"Repeated ranges reuse a checked in-memory piece");
            if([mode isEqual:@"partial"]){work(engine,^{v->bytes=[engine readVerifiedBytesAt:pieceBytes length:65536];});check(!v->bytes.length,"Unfinished piece is never served as verified");}}
        NSDictionary *first=v->snapshot;
        work(engine,^{[engine shutdown];});
        work(engine,^{NSString *error=nil;v->started=[engine startMagnet:[NSString stringWithFormat:@"magnet:?xt=urn:btih:%@",hash] fileIndex:0 publicTest:NO error:&error];});
        check(!v->started,"A fully torn-down engine refuses reuse safely");
        if([@[@"corrupt",@"tail"]containsObject:mode]){
            check(![NSFileManager.defaultManager fileExistsAtPath:[cache stringByAppendingPathComponent:@"rewind.resume"]],"Neither shutdown nor queued save restores a damaged-cache claim");
            check([NSFileManager.defaultManager fileExistsAtPath:[cache stringByAppendingPathComponent:@"generated.mp4"]],"Damaged media file is preserved for normal piece rechecking");
            owner.engine=[TorrentEngine new];engine=owner.engine;
            work(engine,^{NSString *error=nil;v->started=[engine startMagnet:[NSString stringWithFormat:@"magnet:?xt=urn:btih:%@",hash] fileIndex:0 publicTest:NO error:&error];});
            double retry=now();v->bytes=nil;
            while(now()-retry<3&&!interrupted){
                work(engine,^{v->snapshot=[engine snapshot];v->bytes=[engine readVerifiedBytesAt:offset length:65536];});
                if([v->snapshot[@"metadata"]boolValue]&&![v->snapshot[@"local_checking"]boolValue])break;
                std::this_thread::sleep_for(std::chrono::milliseconds(50));
            }
            check(v->started&&![v->snapshot[@"resume_loaded"]boolValue]&&![v->snapshot[@"local_checking"]boolValue],"Reopen finishes normal library checking without rejected resume data");
            check(!v->bytes.length&&![v->snapshot[@"video_complete"]boolValue],"Recheck does not promote corrupted piece to playable data");
        }
        emit(@{@"event":@"result",@"mode":mode,@"checks":@(checks),@"failures":@(failures),@"seconds":@(now()-began),@"returned_bytes":@(v->bytes.length),@"snapshot":v->snapshot?:@{},@"first_snapshot":first?:@{},@"scope":@"Actual production engine; generated cache and pinned resume serialization. No peers, decoder or iPad speed claim."});
        return failures?1:0;
    }catch(const std::exception &e){fprintf(stderr,"%s\n",e.what());return 3;}
}}
