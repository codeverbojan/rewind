#import <Foundation/Foundation.h>
#import "../TorrentEngine.h"
#include <stdexcept>
#include <cstdio>
static void work(TorrentEngine *engine,void(^body)(void)) {
    dispatch_semaphore_t done=dispatch_semaphore_create(0);
    [engine perform:^(TorrentEngine *e){body();dispatch_semaphore_signal(done);}];
    if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC)))throw std::runtime_error("Engine queue timeout");
}
static void pump(BOOL(^ready)(void)) {
    double end=NSProcessInfo.processInfo.systemUptime+15;
    while(!ready()&&NSProcessInfo.processInfo.systemUptime<end)
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.02]];
    if(!ready())throw std::runtime_error("Callback timeout");
}
struct Owner {__strong TorrentEngine *engine;~Owner(){if(engine)work(engine,^{[engine shutdown];});}};
int main(int argc,const char **argv){@autoreleasepool{
    if(argc!=3)return 2;int checks=0,failures=0;
    auto check=[&](BOOL ok,const char *label){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",label);}};
    NSString *root=@(argv[1]),*resources=@(argv[2]),*hash=@"c0ed8c16ade445c7121456d816e11be210abe43c";
    setenv("REWIND_ENGINE_TEST_ROOT",root.UTF8String,1);NSFileManager *fm=NSFileManager.defaultManager;
    NSString *cache=[root stringByAppendingPathComponent:@"Torrents"],*directory=[cache stringByAppendingPathComponent:hash];
    NSString *file=[directory stringByAppendingPathComponent:@"rewind-offline-114.mp4"],*metadata=[root stringByAppendingPathComponent:@"TorrentMetadata"];
    @try{try{
        [fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
        [fm createDirectoryAtPath:metadata withIntermediateDirectories:YES attributes:nil error:nil];
        if(![fm copyItemAtPath:[resources stringByAppendingPathComponent:@"subtitle-check.mp4"] toPath:file error:nil]||
           ![fm copyItemAtPath:[resources stringByAppendingPathComponent:[NSString stringWithFormat:@"torrents/%@.torrent",hash]] toPath:[metadata stringByAppendingPathComponent:[hash stringByAppendingPathExtension:@"torrent"]] error:nil])throw std::runtime_error("Fixture copy failed");
        Owner one{[TorrentEngine new]},two{[TorrentEngine new]};TorrentEngine *first=one.engine,*second=two.engine;
        NSString *magnet=[@"magnet:?xt=urn:btih:" stringByAppendingString:hash];__block BOOL began=NO;
        work(first,^{began=[first startMagnet:magnet fileIndex:0 publicTest:NO error:nil];});check(began,"First actual engine starts");
        __block BOOL done=NO,removed=NO;
        [TorrentEngine removeDownload:hash done:^(BOOL ok){removed=ok;done=YES;}];pump(^BOOL{return done;});
        check(!removed&&[fm fileExistsAtPath:file],"Remove refuses a live torrent cache");
        if(removed)throw std::runtime_error("Baseline reproduced active file removal; stop before further reads");
        NSString *other=@"magnet:?xt=urn:btih:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
        work(first,^{began=[first startMagnet:other fileIndex:0 publicTest:NO error:nil];});check(began,"Same session can move to a different handle");
        done=NO;[TorrentEngine removeDownload:hash done:^(BOOL ok){removed=ok;done=YES;}];pump(^BOOL{return done;});
        check(!removed&&[fm fileExistsAtPath:file],"Asynchronous old-handle removal does not release its cache early");
        work(second,^{began=[second startMagnet:magnet fileIndex:0 publicTest:NO error:nil];});check(began,"Second actual engine can protect the same cache");
        NSString *unused=[cache stringByAppendingPathComponent:@"unused"],*kept=[cache stringByAppendingPathComponent:@"kept"];
        NSData *bytes=[NSData dataWithBytes:"keep" length:4];[bytes writeToFile:unused atomically:YES];[bytes writeToFile:kept atomically:YES];
        done=NO;__block NSDictionary *report=nil;
        [TorrentEngine clearTemporary:[NSSet setWithObject:@"kept"] done:^(NSDictionary *r){report=r;done=YES;}];pump(^BOOL{return done;});
        check([fm fileExistsAtPath:file]&&[fm fileExistsAtPath:kept]&&![fm fileExistsAtPath:unused],"Clear removes only inactive unkept data");
        check([report[@"active_bytes"]longLongValue]>0&&[report[@"temporary_bytes"]longLongValue]>0,"Active temporary bytes remain honestly accounted");
        work(first,^{[first shutdown];});
        done=NO;[TorrentEngine removeDownload:hash.uppercaseString done:^(BOOL ok){removed=ok;done=YES;}];pump(^BOOL{return done;});
        check(!removed&&[fm fileExistsAtPath:file],"Closing one owner does not release another owner's cache");
        __block NSDictionary *snap=nil;double end=NSProcessInfo.processInfo.systemUptime+10;
        do{work(second,^{snap=[second snapshot];});if([snap[@"video_complete"]boolValue])break;[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];}while(NSProcessInfo.processInfo.systemUptime<end);
        check([snap[@"video_complete"]boolValue]&&[snap[@"video_verified_bytes"]longLongValue]==3058957,"Surviving engine verifies all real file pieces");
        __block NSData *read=nil;end=NSProcessInfo.processInfo.systemUptime+5;
        do{work(second,^{[second prioritizeOffset:0 length:65536];read=[second readVerifiedBytesAt:0 length:65536];});if(read.length)break;[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];}while(NSProcessInfo.processInfo.systemUptime<end);
        check(read.length==65536&&[read isEqual:[[NSData dataWithContentsOfFile:file]subdataWithRange:NSMakeRange(0,65536)]],"Verified bytes remain readable after refused deletion and cleanup");
        work(second,^{[second shutdown];});done=NO;
        [TorrentEngine removeDownload:hash done:^(BOOL ok){removed=ok;done=YES;}];pump(^BOOL{return done;});
        check(removed&&![fm fileExistsAtPath:directory],"Remove succeeds after every torrent session has stopped");
        check([fm fileExistsAtPath:kept],"Unrelated kept data survives");
    }catch(const std::exception &error){fprintf(stderr,"Exception: %s\n",error.what());if(!failures)failures++;}}
    @finally{[fm removeItemAtPath:root error:nil];}
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
