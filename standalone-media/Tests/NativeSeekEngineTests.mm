// Real AVPlayer + production resource loader/engine, generated local movie.
// Trace subclasses observe calls only. They do not change range/cache decisions.
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "../TorrentEngine.h"
#import "../TorrentLoader.h"
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/write_resume_data.hpp>
#include <libtorrent/hasher.hpp>
#include <libtorrent/bencode.hpp>
#include <csignal>
static volatile std::sig_atomic_t interrupted=0;static void stop(int){interrupted=1;}
static double now(){return NSProcessInfo.processInfo.systemUptime;}
static void work(TorrentEngine *engine,void(^body)(void)){dispatch_semaphore_t done=dispatch_semaphore_create(0);[engine perform:^(TorrentEngine *e){body();dispatch_semaphore_signal(done);}];if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC)))throw std::runtime_error("Engine queue timeout");}
static void emit(NSDictionary *d){NSData *data=[NSJSONSerialization dataWithJSONObject:d options:0 error:nil];printf("%s\n",[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding].UTF8String);fflush(stdout);}
@interface TraceEngine:TorrentEngine
@property(nonatomic) uint64_t calls,delivered,misses;
@property(nonatomic,strong) NSMutableDictionary *ranges;
@end
@implementation TraceEngine
- (NSData *)readVerifiedBytesAt:(int64_t)offset length:(NSUInteger)length {
    self.calls++;NSData *data=[super readVerifiedBytesAt:offset length:length];self.delivered+=data.length;if(!data.length)self.misses++;
    if(!self.ranges)self.ranges=[NSMutableDictionary new];NSString *key=[NSString stringWithFormat:@"%lld",offset/(1024*1024)];
    if(self.ranges[key]||self.ranges.count<128)self.ranges[key]=@([self.ranges[key]unsignedLongLongValue]+data.length);
    return data;
}
@end
@interface TraceLoader:TorrentLoader
@property(nonatomic,strong) NSMutableArray *events;
@property(nonatomic) NSUInteger starts,cancels;
@end
@implementation TraceLoader
- (BOOL)resourceLoader:(AVAssetResourceLoader *)loader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)request {
    if(!self.events)self.events=[NSMutableArray new];self.starts++;
    if(self.events.count<64)[self.events addObject:@{@"event":@"start",@"offset":@(request.dataRequest.requestedOffset),@"length":@(request.dataRequest.requestedLength),@"to_end":@(request.dataRequest.requestsAllDataToEndOfResource),@"time":@(now())}];
    return [super resourceLoader:loader shouldWaitForLoadingOfRequestedResource:request];
}
- (void)resourceLoader:(AVAssetResourceLoader *)loader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)request {
    self.cancels++;if(self.events.count<64)[self.events addObject:@{@"event":@"cancel",@"offset":@(request.dataRequest.requestedOffset),@"current":@(request.dataRequest.currentOffset),@"time":@(now())}];
    [super resourceLoader:loader didCancelLoadingRequest:request];
}
@end
struct Owner{__strong TraceEngine *engine;__strong TraceLoader *loader;__strong AVPlayer *player;~Owner(){[player pause];[player replaceCurrentItemWithPlayerItem:nil];[loader stop];if(engine)work(engine,^{[engine shutdown];});}};
int main(int argc,char **argv){@autoreleasepool{
    std::signal(SIGINT,stop);std::signal(SIGTERM,stop);int checks=0,failures=0;auto check=[&](bool b,const char *why){checks++;if(!b){failures++;fprintf(stderr,"FAIL:%s\n",why);}};
    try{
        const char *root=getenv("REWIND_ENGINE_FIXTURE_ROOT"),*movie=getenv("REWIND_ENGINE_MOVIE");if(!root||!movie)return 2;setenv("REWIND_ENGINE_TEST_ROOT",root,1);
        NSData *file=[NSData dataWithContentsOfFile:@(movie) options:NSDataReadingMappedIfSafe error:nil];if(file.length<32*1024*1024)throw std::runtime_error("Generated fixture too short");
        const int pieceBytes=1024*1024;int pieces=int((file.length+pieceBytes-1)/pieceBytes);std::string hashes;
        for(int i=0;i<pieces;i++){size_t offset=size_t(i)*pieceBytes,length=std::min<size_t>(pieceBytes,file.length-offset);hashes+=libtorrent::hasher((const char*)file.bytes+offset,length).final().to_string();}
        libtorrent::entry entry;entry["info"]["name"]="generated.mp4";entry["info"]["length"]=int64_t(file.length);entry["info"]["piece length"]=pieceBytes;entry["info"]["pieces"]=hashes;
        auto info=std::make_shared<libtorrent::torrent_info>(entry);NSMutableString *hash=[NSMutableString new];for(unsigned char c:info->info_hash().to_string())[hash appendFormat:@"%02x",c];
        NSString *meta=[@(root)stringByAppendingPathComponent:@"TorrentMetadata"],*cache=[[@(root)stringByAppendingPathComponent:@"Torrents"]stringByAppendingPathComponent:hash];
        for(NSString *p in @[meta,cache])[NSFileManager.defaultManager createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];
        [NSFileManager.defaultManager copyItemAtPath:@(movie) toPath:[cache stringByAppendingPathComponent:@"generated.mp4"] error:nil];
        std::vector<char> bytes;libtorrent::bencode(std::back_inserter(bytes),entry);[[NSData dataWithBytes:bytes.data() length:bytes.size()]writeToFile:[meta stringByAppendingPathComponent:[hash stringByAppendingString:@".torrent"]] atomically:YES];
        libtorrent::add_torrent_params saved;saved.info_hash=info->info_hash();saved.have_pieces.resize(pieces,true);auto resume=libtorrent::write_resume_data_buf(saved);[[NSData dataWithBytes:resume.data() length:resume.size()]writeToFile:[cache stringByAppendingPathComponent:@"rewind.resume"] atomically:YES];
        Owner owner;owner.engine=[TraceEngine new];TraceEngine *engine=owner.engine;__block BOOL started=NO;__block NSDictionary *snapshot=nil;
        work(engine,^{NSString *error=nil;started=[engine startMagnet:[NSString stringWithFormat:@"magnet:?xt=urn:btih:%@",hash] fileIndex:0 publicTest:NO error:&error];});check(started,"Actual engine accepts generated metadata");
        owner.loader=[[TraceLoader alloc]initWithEngine:engine name:@"generated.mp4" size:file.length];owner.player=[AVPlayer playerWithPlayerItem:[owner.loader playerItem]];owner.player.muted=YES;
        AVPlayer *player=owner.player;__block BOOL forwardDone=NO,backwardDone=NO;int phase=0;BOOL pausedOK=NO;
        double began=now(),playing=-1,observed=0,lastSnapshot=0;NSMutableArray *timeline=[NSMutableArray new];
        while(now()-began<65&&!interrupted){
            [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
            if(owner.player.currentItem.status==AVPlayerItemStatusFailed)break;
            if(owner.player.currentItem.status==AVPlayerItemStatusReadyToPlay){if(playing<0)playing=now();[owner.player play];}
            observed=CMTimeGetSeconds(owner.player.currentTime);
            if(now()-lastSnapshot>=2){lastSnapshot=now();work(engine,^{snapshot=[engine snapshot];});[timeline addObject:@{@"elapsed":@(now()-began),@"position":@(isfinite(observed)?observed:0),@"read_pieces":snapshot[@"verified_read_pieces"]?:@0,@"read_bytes":snapshot[@"verified_read_bytes"]?:@0}];}
            if(phase==0&&observed>=8){
                [player pause];double paused=CMTimeGetSeconds(player.currentTime);[[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.5]];
                pausedOK=fabs(CMTimeGetSeconds(player.currentTime)-paused)<.15;phase=1;
                [player seekToTime:CMTimeMakeWithSeconds(45,600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished){forwardDone=finished;[player play];}];
            }else if(phase==1&&forwardDone&&observed>=46){
                phase=2;[player seekToTime:CMTimeMakeWithSeconds(4,600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished){backwardDone=finished;[player play];}];
            }else if(phase==2&&backwardDone&&observed>=24&&observed<30)break;
        }
        [owner.player pause];work(engine,^{snapshot=[engine snapshot];});
        __block NSDictionary *trace=nil;TraceLoader *loader=owner.loader;
        work(engine,^{trace=@{@"calls":@(engine.calls),@"delivered":@(engine.delivered),@"misses":@(engine.misses),@"ranges":engine.ranges?:@{},@"starts":@(loader.starts),@"cancels":@(loader.cancels),@"events":loader.events?:@[],@"loader_diagnostics":[loader respondsToSelector:@selector(diagnostics)]?loader.diagnostics?:@{}:@{}};});
        check(!interrupted&&observed>=24,"Muted real AVPlayer advances for24seconds");check([snapshot[@"peer_payload_bytes"]longLongValue]==0,"Playback uses only generated local cache");check(![snapshot[@"cache_integrity_failed"]boolValue],"Generated movie passes integrity checks");
        check(pausedOK,"Pause preserves position");check(forwardDone&&backwardDone&&phase==2&&observed>=24&&observed<30,"Forward/backward seeks complete and resumed picture advances");
        emit(@{@"event":@"result",@"checks":@(checks),@"failures":@(failures),@"seconds":@(now()-began),@"startup_seconds":@(playing<0?-1:playing-began),@"position":@(isfinite(observed)?observed:0),@"movie_bytes":@(file.length),@"error":owner.player.currentItem.error.localizedDescription?:@"",@"snapshot":snapshot?:@{},@"trace":trace,@"timeline":timeline,@"scope":@"Muted Mac AVPlayer, actual resource loader and torrent engine with fully cached generated movie. No iPad timing claim."});return failures?1:0;
    }catch(const std::exception &e){fprintf(stderr,"%s\n",e.what());return 3;}
}}
