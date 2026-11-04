// Actual TorrentLoader + pinned engine. Request doubles replay concurrent iOS9
// ranges; independently compare EVERY delivered byte against the generated file.
// This is not an AVPlayer or device timing benchmark.
#import <Foundation/Foundation.h>
#import "../TorrentLoader.h"
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/write_resume_data.hpp>
#include <libtorrent/hasher.hpp>
#include <libtorrent/bencode.hpp>
#include <csignal>
#include <unistd.h>
static volatile std::sig_atomic_t interrupted=0;static void stop(int){interrupted=1;}
static double now(){return NSProcessInfo.processInfo.systemUptime;}
static void work(TorrentEngine *engine,void(^body)(void)){dispatch_semaphore_t done=dispatch_semaphore_create(0);[engine perform:^(TorrentEngine *e){body();dispatch_semaphore_signal(done);}];if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC)))throw std::runtime_error("Engine queue timeout");}
static void emit(NSDictionary *d){NSData *data=[NSJSONSerialization dataWithJSONObject:d options:0 error:nil];printf("%s\n",[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding].UTF8String);fflush(stdout);}
@interface TorrentLoader (Replay)
- (void)pump;
@end
@interface ControlledLoader:TorrentLoader
@property(nonatomic) BOOL manual;
- (void)tick;
@end
@implementation ControlledLoader
- (void)pump{if(self.manual)[super pump];}
- (void)tick{self.manual=YES;[self pump];self.manual=NO;}
@end
@interface ReplayEngine:TorrentEngine
@property(nonatomic) NSUInteger readCalls,returnedBytes;
@end
@implementation ReplayEngine
- (NSData *)readVerifiedBytesAt:(int64_t)offset length:(NSUInteger)length {
    self.readCalls++;NSData *data=[super readVerifiedBytesAt:offset length:length];self.returnedBytes+=data.length;return data;
}
@end
@interface ReplayData:NSObject
@property(nonatomic) int64_t requestedOffset,currentOffset,expectedEnd;
@property(nonatomic) NSInteger requestedLength;
@property(nonatomic) BOOL requestsAllDataToEndOfResource,correct;
@property(nonatomic,strong) NSData *oracle;
@property(nonatomic) uint64_t bytes,callbacks;
- (void)respondWithData:(NSData *)data;
@end
@implementation ReplayData
- (void)respondWithData:(NSData *)data{
    if(!data.length||self.currentOffset<0||self.currentOffset>self.expectedEnd||data.length>(uint64_t)(self.expectedEnd-self.currentOffset)||self.currentOffset+data.length>self.oracle.length){self.correct=NO;return;}
    if(memcmp(data.bytes,(const char*)self.oracle.bytes+self.currentOffset,data.length))self.correct=NO;
    self.currentOffset+=data.length;self.bytes+=data.length;self.callbacks++;
}
@end
@interface ReplayRequest:NSObject
@property(nonatomic,strong) ReplayData *dataRequest;
@property(nonatomic,getter=isCancelled) BOOL cancelled;
@property(nonatomic,getter=isFinished) BOOL finished;
@property(nonatomic,strong) NSError *error;
@property(nonatomic) BOOL premature;
- (id)contentInformationRequest;
- (void)finishLoading;
- (void)finishLoadingWithError:(NSError *)error;
@end
@implementation ReplayRequest
- (id)contentInformationRequest{return nil;}
- (void)finishLoading{self.premature=self.dataRequest&&self.dataRequest.currentOffset!=self.dataRequest.expectedEnd;self.finished=YES;}
- (void)finishLoadingWithError:(NSError *)error{self.finished=YES;self.error=error;}
@end
static ReplayRequest *request(NSData *oracle,int64_t start,int64_t length,BOOL toEnd){
    ReplayRequest *r=[ReplayRequest new];ReplayData *d=[ReplayData new];d.oracle=oracle;d.requestedOffset=start;d.currentOffset=start;d.requestedLength=length;d.requestsAllDataToEndOfResource=toEnd;d.correct=YES;
    d.expectedEnd=start<0||start>(int64_t)oracle.length?-1:toEnd?(int64_t)oracle.length:start+MIN(length,(int64_t)oracle.length-start);r.dataRequest=d;return r;
}
struct Owner{__strong TorrentEngine *engine;__strong ControlledLoader *loader;~Owner(){[loader stop];if(engine)work(engine,^{[engine shutdown];});}};
int main(int argc,char **argv){@autoreleasepool{
    std::signal(SIGINT,stop);std::signal(SIGTERM,stop);__block int checks=0,failures=0;auto check=^(bool b,const char *why){checks++;if(!b){failures++;fprintf(stderr,"FAIL:%s\n",why);}};
    try{
        const char *root=getenv("REWIND_ENGINE_FIXTURE_ROOT"),*movie=getenv("REWIND_ENGINE_MOVIE");if(!root||!movie)return 2;setenv("REWIND_ENGINE_TEST_ROOT",root,1);
        NSData *file=[NSData dataWithContentsOfFile:@(movie) options:NSDataReadingMappedIfSafe error:nil];if(file.length<32*1024*1024)throw std::runtime_error("Generated fixture too short");
        const int pieceBytes=2*1024*1024;int pieces=int((file.length+pieceBytes-1)/pieceBytes);std::string hashes;
        for(int i=0;i<pieces;i++){size_t offset=size_t(i)*pieceBytes,length=std::min<size_t>(pieceBytes,file.length-offset);hashes+=libtorrent::hasher((const char*)file.bytes+offset,length).final().to_string();}
        libtorrent::entry entry;entry["info"]["name"]="generated.mp4";entry["info"]["length"]=int64_t(file.length);entry["info"]["piece length"]=pieceBytes;entry["info"]["pieces"]=hashes;
        auto info=std::make_shared<libtorrent::torrent_info>(entry);NSMutableString *hash=[NSMutableString new];for(unsigned char c:info->info_hash().to_string())[hash appendFormat:@"%02x",c];
        NSString *meta=[@(root)stringByAppendingPathComponent:@"TorrentMetadata"],*cache=[[@(root)stringByAppendingPathComponent:@"Torrents"]stringByAppendingPathComponent:hash];
        for(NSString *p in @[meta,cache])[NSFileManager.defaultManager createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];
        [NSFileManager.defaultManager copyItemAtPath:@(movie) toPath:[cache stringByAppendingPathComponent:@"generated.mp4"] error:nil];
        std::vector<char> bytes;libtorrent::bencode(std::back_inserter(bytes),entry);[[NSData dataWithBytes:bytes.data() length:bytes.size()]writeToFile:[meta stringByAppendingPathComponent:[hash stringByAppendingString:@".torrent"]] atomically:YES];
        libtorrent::add_torrent_params saved;saved.info_hash=info->info_hash();saved.have_pieces.resize(pieces,true);auto resume=libtorrent::write_resume_data_buf(saved);[[NSData dataWithBytes:resume.data() length:resume.size()]writeToFile:[cache stringByAppendingPathComponent:@"rewind.resume"] atomically:YES];
        Owner owner;owner.engine=[ReplayEngine new];ReplayEngine *engine=(id)owner.engine;__block BOOL started=NO;__block NSDictionary *snapshot=nil;
        work(engine,^{NSString *error=nil;started=[engine startMagnet:[NSString stringWithFormat:@"magnet:?xt=urn:btih:%@",hash] fileIndex:0 publicTest:NO error:&error];});check(started,"Actual engine accepts generated metadata");

        NSString *mode=argc>1?@(argv[1]):@"overlap";
        owner.loader=[[ControlledLoader alloc]initWithEngine:engine name:@"generated.mp4" size:file.length];ControlledLoader *loader=owner.loader;
        AVURLAsset *requestAsset=[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:@(movie)] options:nil];
        NSMutableArray *all=[NSMutableArray new];__block ReplayRequest *cancelled=nil,*invalid=nil,*tail=nil,*late=nil;
        void(^add)(ReplayRequest *)=^(ReplayRequest *r){[all addObject:r];[loader resourceLoader:requestAsset.resourceLoader shouldWaitForLoadingOfRequestedResource:(id)r];};
        work(engine,^{
            if([mode isEqual:@"overlap"]){for(int i=0;i<18;i++)add(request(file,int64_t(i)*2*1024*1024+137*i,0,YES));}
            else add(request(file,0,0,YES));
            if([mode isEqual:@"ranges"]){
                add(request(file,2*1024*1024-37,131071,NO));
                add(request(file,40*1024*1024+19,65537,NO));
                tail=request(file,file.length-10000,30000,NO);add(tail);
                invalid=request(file,INT64_MAX,65536,NO);add(invalid);
                add(request(file,file.length,0,NO));
                cancelled=request(file,17*1024*1024,0,YES);add(cancelled);
            }
        });
        double began=now();NSUInteger ticks=0;__block BOOL done=NO;__block uint64_t cancelledBytes=0;NSMutableArray *timeline=[NSMutableArray new];
        __block NSUInteger maxReads=0,maxReturned=0;
        while(now()-began<100&&!interrupted&&!done){@autoreleasepool{
            work(engine,^{
                if(ticks==40&&![mode isEqual:@"single"]){late=request(file,1024*1024+7,0,YES);add(late);add(request(file,43*1024*1024+11,131073,NO));}
                if(ticks==20&&cancelled){cancelled.cancelled=YES;cancelledBytes=cancelled.dataRequest.bytes;[loader resourceLoader:requestAsset.resourceLoader didCancelLoadingRequest:(id)cancelled];}
                NSUInteger beforeReads=engine.readCalls,beforeBytes=engine.returnedBytes;[loader tick];
                maxReads=MAX(maxReads,engine.readCalls-beforeReads);maxReturned=MAX(maxReturned,engine.returnedBytes-beforeBytes);
                if(ticks%100==0){snapshot=[engine snapshot];[timeline addObject:@{@"tick":@(ticks),@"hash_bytes":snapshot[@"verified_read_bytes"]?:@0,@"returned_bytes":snapshot[@"read_delivered_bytes"]?:@0}];}
                done=YES;for(ReplayRequest *r in all)if(!r.finished&&!r.cancelled)done=NO;
            });ticks++;usleep(2000);
        }}
        work(engine,^{snapshot=[engine snapshot];});
        uint64_t delivered=0;for(ReplayRequest *r in all){check(r.finished||r.cancelled,"Every admitted request completes or is explicitly cancelled");check(r.dataRequest.correct,"Every returned byte matches independent source and requested range");check(!r.premature,"No request reports EOF before its actual range end");if(r!=invalid&&!r.cancelled)check(!r.error,"Valid requests do not fail");delivered+=r.dataRequest.bytes;}
        check(done&&!interrupted,"All ranges complete inside bounded run");check(![snapshot[@"cache_integrity_failed"]boolValue],"All piece integrity checks preserved");
        if(cancelled)check(cancelled.dataRequest.bytes==cancelledBytes,"Cancellation stops further delivery");
        if(invalid)check(invalid.error!=nil&&invalid.dataRequest.bytes==0,"Overflowing range is rejected without data");
        if(tail)check(tail.dataRequest.bytes==10000,"Finite tail request clips to actual EOF");
        if(getenv("REWIND_EXPECT_BOUNDED")){check(maxReads<=2,"No more than two unique engine reads per pump");check(maxReturned<=512*1024,"No more than512KiB engine bytes per pump");}
        emit(@{@"event":@"result",@"mode":mode,@"checks":@(checks),@"failures":@(failures),@"seconds":@(now()-began),@"ticks":@(ticks),@"requests":@(all.count),@"delivered":@(delivered),@"max_reads_per_pump":@(maxReads),@"max_engine_bytes_per_pump":@(maxReturned),@"snapshot":snapshot?:@{},@"timeline":timeline,@"scope":@"Actual production loader/engine with request doubles and generated local cache; accelerated ticks, not real AVPlayer timing."});return failures?1:0;
    }catch(const std::exception &e){fprintf(stderr,"%s\n",e.what());return 3;}
}}
