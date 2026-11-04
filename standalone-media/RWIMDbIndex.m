#import "RWMetadataBudget.h"
#import "RWIMDbIndex.h"
#import "RWFeedStorageBudget.h"
#import <sqlite3.h>
#import <zlib.h>
#include <math.h>
#include <sys/stat.h>
static unsigned long long IMIDC(const char *identifier){if(!identifier)return 0;size_t length=strlen(identifier);if(length<3||length>12||identifier[0]!='t'||identifier[1]!='t')return 0;unsigned long long value=0;for(const char *s=identifier+2;*s;s++){if(*s<'0'||*s>'9')return 0;value=value*10+(*s-'0');}return value;}
static unsigned long long IMID(NSString *identifier){return [identifier isKindOfClass:NSString.class]?IMIDC(identifier.UTF8String):0;}
static unsigned long long IMSize(NSString *path){struct stat info;return path.length&&lstat(path.fileSystemRepresentation,&info)==0&&S_ISREG(info.st_mode)?(unsigned long long)info.st_size:0;}
static unsigned long long IMJSONBytes(NSString *folder){unsigned long long bytes=0;for(NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:folder error:nil])if([name.pathExtension isEqual:@"json"])bytes+=IMSize([folder stringByAppendingPathComponent:name]);return bytes;}
static unsigned long long IMMetadataBytes(NSString *folder,BOOL temporaryOnly){unsigned long long bytes=0;for(NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:folder error:nil])if(!temporaryOnly||[name hasPrefix:@".dat."])bytes+=IMSize([folder stringByAppendingPathComponent:name]);return bytes;}
@implementation RWIMDbIndex {
    NSString *_folder,*_bundled;NSDictionary *_state,*_diagnostics;NSURLSession *_session;NSURLSessionDownloadTask *_task;dispatch_queue_t _queue;double _lastAttempt;BOOL _importing,_paused;
}
+ (NSDictionary *)importGzip:(NSString *)gzipPath destination:(NSString *)destination cancelled:(BOOL(^)(void))cancelled {
    return [self importGzip:gzipPath destination:destination maximumBytes:40ULL*1024*1024 cancelled:cancelled];
}
+ (NSDictionary *)updateBudgetForFolder:(NSString *)folder bundled:(NSString *)bundled downloadBytes:(unsigned long long)downloadBytes {
    // A measured full on-device update needs ~115MiB including rollback,
    // cached torrent descriptors and write reserves. Keep a bounded128MiB
    // allowance; retain the last-good index if growth exceeds that headroom.
    const unsigned long long cap=128ULL*1024*1024;
    unsigned long long bundle=IMSize(bundled)+IMJSONBytes(bundled.stringByDeletingLastPathComponent);
    unsigned long long documents=IMJSONBytes(folder.stringByDeletingLastPathComponent)+IMJSONBytes(folder);
    unsigned long long old=IMSize([folder stringByAppendingPathComponent:@"ratings.sqlite"]);
    // Count the full shared HTTP-cache allowance, and reserve room for atomic
    // JSON writes while the old and replacement indexes coexist. Artwork's
    // separate cache and video downloads are outside the metadata budget.
    unsigned long long atomic=MAX(8ULL*1024*1024,documents),http=8ULL*1024*1024;
    unsigned long long feeds=RWFeedStorageReserveBytes;
    NSString *documentsFolder=folder.stringByDeletingLastPathComponent;
    unsigned long long torrent=IMMetadataBytes([documentsFolder stringByAppendingPathComponent:@"TorrentMetadata"],NO);
    unsigned long long temporary=IMMetadataBytes(documentsFolder,YES)+IMMetadataBytes(folder,YES);
    unsigned long long used=bundle+documents+old+downloadBytes+atomic+http+feeds+torrent+temporary;
    unsigned long long available=used<cap?MIN(40ULL*1024*1024,cap-used):0;
    return @{@"cap":@(cap),@"bundled":@(bundle),@"documents":@(documents),@"current_index":@(old),@"download":@(downloadBytes),@"atomic_reserve":@(atomic),@"http_cache_reserve":@(http),@"feed_storage_reserve":@(feeds),@"torrent_metadata":@(torrent),@"atomic_temporary":@(temporary),@"before_import":@(used),@"maximum_new_index":@(available),@"reserved_peak":@(used+available)};
}
+ (NSDictionary *)importGzip:(NSString *)gzipPath destination:(NSString *)destination maximumBytes:(unsigned long long)maximumBytes cancelled:(BOOL(^)(void))cancelled {
    NSString *temporary=[destination stringByAppendingString:@".import"];NSFileManager *fm=NSFileManager.defaultManager;[fm removeItemAtPath:temporary error:nil];
    maximumBytes=MIN(maximumBytes,40ULL*1024*1024);if(maximumBytes<8192)return @{@"ok":@NO,@"error":@"Not enough metadata update headroom",@"bytes":@0};
    gzFile input=gzopen(gzipPath.fileSystemRepresentation,"rb");if(!input)return @{@"error":@"Cannot read ratings download"};
    sqlite3 *db=NULL;sqlite3_stmt *insert=NULL;BOOL ok=sqlite3_open(temporary.fileSystemRepresentation,&db)==SQLITE_OK;NSString *error=nil;NSUInteger count=0;unsigned long long expanded=0;double started=NSProcessInfo.processInfo.systemUptime;
    if(ok){NSString *setup=[NSString stringWithFormat:@"PRAGMA page_size=4096; PRAGMA max_page_count=%llu; PRAGMA journal_mode=OFF; PRAGMA synchronous=OFF; PRAGMA cache_size=-512; CREATE TABLE ratings(id INTEGER PRIMARY KEY,r INTEGER NOT NULL,v INTEGER NOT NULL); BEGIN",maximumBytes/4096];ok=sqlite3_exec(db,setup.UTF8String,NULL,NULL,NULL)==SQLITE_OK;}
    if(ok)ok=sqlite3_prepare_v2(db,"INSERT INTO ratings VALUES(?,?,?)",-1,&insert,NULL)==SQLITE_OK;
    char line[256];if(!gzgets(input,line,sizeof(line))||strcmp(line,"tconst\taverageRating\tnumVotes\n")!=0){ok=NO;error=@"Unexpected ratings schema";}
    while(ok&&gzgets(input,line,sizeof(line))){
        expanded+=strlen(line);if(expanded>96ULL*1024*1024||count>=3000000||NSProcessInfo.processInfo.systemUptime-started>180){ok=NO;error=@"Ratings import exceeded its budget";break;}
        if(count%1000==0&&cancelled&&cancelled()){ok=NO;error=@"Paused";break;}
        char id[32],extra;double rating;unsigned long long votes;
        int fields=sscanf(line,"%31s\t%lf\t%llu %c",id,&rating,&votes,&extra);unsigned long long numeric=IMIDC(id);
        if(fields!=3||!numeric||!isfinite(rating)||rating<1||rating>10||votes<1||votes>UINT32_MAX){ok=NO;error=@"Invalid ratings record";break;}
        sqlite3_bind_int64(insert,1,(sqlite3_int64)numeric);sqlite3_bind_int(insert,2,(int)lround(rating*10));sqlite3_bind_int64(insert,3,(sqlite3_int64)votes);
        int step=sqlite3_step(insert);if(step!=SQLITE_DONE){ok=NO;error=step==SQLITE_FULL?@"Ratings update reached its disk budget":@"Could not build ratings index";break;}sqlite3_reset(insert);sqlite3_clear_bindings(insert);count++;
    }
    int zerr=Z_OK;gzerror(input,&zerr);if(zerr!=Z_OK&&zerr!=Z_STREAM_END){ok=NO;error=@"Incomplete ratings archive";}gzclose(input);
    if(insert)sqlite3_finalize(insert);if(ok)ok=sqlite3_exec(db,"COMMIT; PRAGMA user_version=1",NULL,NULL,NULL)==SQLITE_OK;if(db)sqlite3_close(db);
    unsigned long long bytes=[[[fm attributesOfItemAtPath:temporary error:nil]objectForKey:NSFileSize]unsignedLongLongValue];
    if(!count||bytes>maximumBytes){ok=NO;error=error?:@"Ratings index outside size budget";}
    if(ok&&cancelled&&cancelled()){ok=NO;error=@"Paused";}
    if(ok){if(rename(temporary.fileSystemRepresentation,destination.fileSystemRepresentation)!=0){ok=NO;error=@"Cannot replace ratings index";}}
    if(!ok)[fm removeItemAtPath:temporary error:nil];
    return @{@"ok":@(ok),@"rows":@(count),@"bytes":@(bytes),@"maximum_bytes":@(maximumBytes),@"seconds":@(NSProcessInfo.processInfo.systemUptime-started),@"error":ok?@"":error?:@"Ratings import failed"};
}
- (instancetype)initWithFolder:(NSString *)folder bundled:(NSString *)bundled {
    if((self=[super init])){_folder=folder;_bundled=bundled;_paused=YES;_queue=dispatch_queue_create("org.rewind.ratings-index",DISPATCH_QUEUE_SERIAL);[[NSFileManager defaultManager]createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
        for(NSString *name in @[@"ratings.sqlite.import",@"ratings-download.gz"])[NSFileManager.defaultManager removeItemAtPath:[folder stringByAppendingPathComponent:name] error:nil];
        NSData *data=[NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"status.json"]];id state=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;_state=[state isKindOfClass:NSDictionary.class]?state:@{};_diagnostics=@{};
        NSURLSessionConfiguration *config=[NSURLSessionConfiguration ephemeralSessionConfiguration];config.timeoutIntervalForRequest=20;config.timeoutIntervalForResource=90;config.HTTPMaximumConnectionsPerHost=1;config.HTTPAdditionalHeaders=@{@"User-Agent":@"Rewind/0.34 (personal iPad experiment)"};NSOperationQueue *delegate=[NSOperationQueue new];delegate.maxConcurrentOperationCount=1;_session=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:delegate];
    }return self;
}
- (NSDictionary *)diagnostics{return _diagnostics?:@{};}
- (void)setPaused:(BOOL)paused { @synchronized(self){if(_paused==paused)return;_paused=paused;}if(paused)[[RWMetadataBudget shared]hold:_task];else{if(_task)[[RWMetadataBudget shared]enqueue:_task foreground:NO];else [self refreshIfNeeded];} }
- (BOOL)paused {@synchronized(self){return _paused;}}
- (void)ratingsForIDs:(NSArray *)ids done:(void(^)(NSDictionary *))done {
    NSArray *requested=[ids subarrayWithRange:NSMakeRange(0,MIN((NSUInteger)525,ids.count))];NSString *current=[_folder stringByAppendingPathComponent:@"ratings.sqlite"],*bundled=_bundled;
    dispatch_async(_queue,^{@autoreleasepool{NSMutableDictionary *result=[NSMutableDictionary new];NSString *path=[[NSFileManager defaultManager]fileExistsAtPath:current]?current:bundled;sqlite3 *db=NULL;sqlite3_stmt *query=NULL;
        if(sqlite3_open_v2(path.fileSystemRepresentation,&db,SQLITE_OPEN_READONLY,NULL)==SQLITE_OK){sqlite3_exec(db,"PRAGMA cache_size=-256",NULL,NULL,NULL);
            if(sqlite3_prepare_v2(db,"SELECT r,v FROM ratings WHERE id=?",-1,&query,NULL)==SQLITE_OK)for(NSString *identifier in requested){unsigned long long value=IMID(identifier);if(!value)continue;sqlite3_bind_int64(query,1,(sqlite3_int64)value);if(sqlite3_step(query)==SQLITE_ROW)result[identifier]=@{@"rating":@(sqlite3_column_int(query,0)/10.0),@"votes":@(sqlite3_column_int64(query,1)),@"provider":@"IMDb"};sqlite3_reset(query);sqlite3_clear_bindings(query);}
        }if(query)sqlite3_finalize(query);if(db)sqlite3_close(db);dispatch_async(dispatch_get_main_queue(),^{if(done)done(result);});
    }});
}
- (void)saveState:(NSDictionary *)state {_state=state;NSData *data=[NSJSONSerialization dataWithJSONObject:state options:0 error:nil];NSString *path=[_folder stringByAppendingPathComponent:@"status.json"];dispatch_async(_queue,^{[data writeToFile:path atomically:YES];});}
- (void)refreshIfNeeded {
    double now=NSDate.date.timeIntervalSince1970;if(self.paused||_task||_importing||now-_lastAttempt<600||now-[_state[@"checked"]doubleValue]<7*86400)return;
    // Ship a current seed index; avoid downloading it again on first launch.
    if(!_state[@"checked"]&&[[NSFileManager defaultManager]fileExistsAtPath:_bundled]){NSDate *modified=[[NSFileManager defaultManager]attributesOfItemAtPath:_bundled error:nil][NSFileModificationDate];if(now-modified.timeIntervalSince1970<7*86400){[self saveState:@{@"checked":@(modified.timeIntervalSince1970)}];return;}}
    _lastAttempt=now;NSDictionary *budget=[[self class]updateBudgetForFolder:_folder bundled:_bundled downloadBytes:16ULL*1024*1024];if([budget[@"before_import"]unsignedLongLongValue]>[budget[@"cap"]unsignedLongLongValue]){_diagnostics=@{@"error":@"Keeping cached ratings: insufficient update headroom",@"disk_budget":budget};return;}
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://datasets.imdbws.com/title.ratings.tsv.gz"]];if([_state[@"etag"]isKindOfClass:NSString.class])[request setValue:_state[@"etag"] forHTTPHeaderField:@"If-None-Match"];
    _task=[_session downloadTaskWithRequest:request];[[RWMetadataBudget shared]enqueue:_task foreground:NO];
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didWriteData:(int64_t)bytes totalBytesWritten:(int64_t)total totalBytesExpectedToWrite:(int64_t)expected {
    if(total>16*1024*1024||expected>16*1024*1024)[[RWMetadataBudget shared]cancel:task];
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didFinishDownloadingToURL:(NSURL *)location {
    NSHTTPURLResponse *response=(NSHTTPURLResponse *)task.response;NSInteger status=response.statusCode;NSDictionary *headers=response.allHeaderFields;
    if(status==304){dispatch_async(dispatch_get_main_queue(),^{NSMutableDictionary *state=[self->_state mutableCopy];state[@"checked"]=@(NSDate.date.timeIntervalSince1970);[self saveState:state];});return;}
    unsigned long long bytes=[[[NSFileManager.defaultManager attributesOfItemAtPath:location.path error:nil]objectForKey:NSFileSize]unsignedLongLongValue];
    if(status!=200||bytes<100||bytes>16ULL*1024*1024)return;
    NSString *gzip=[_folder stringByAppendingPathComponent:@"ratings-download.gz"];[NSFileManager.defaultManager removeItemAtPath:gzip error:nil];if(![NSFileManager.defaultManager moveItemAtURL:location toURL:[NSURL fileURLWithPath:gzip] error:nil])return;
    dispatch_async(dispatch_get_main_queue(),^{self->_importing=YES;dispatch_async(self->_queue,^{@autoreleasepool{
        NSDictionary *budget=[[self class]updateBudgetForFolder:self->_folder bundled:self->_bundled downloadBytes:bytes];NSMutableDictionary *result=[[[self class]importGzip:gzip destination:[self->_folder stringByAppendingPathComponent:@"ratings.sqlite"] maximumBytes:[budget[@"maximum_new_index"]unsignedLongLongValue] cancelled:^BOOL{return self.paused;}]mutableCopy];result[@"disk_budget"]=budget;result[@"import_peak_with_reserves"]=@([budget[@"before_import"]unsignedLongLongValue]+[result[@"bytes"]unsignedLongLongValue]);[NSFileManager.defaultManager removeItemAtPath:gzip error:nil];
        dispatch_async(dispatch_get_main_queue(),^{self->_importing=NO;self->_diagnostics=result;if([result[@"ok"]boolValue]){NSMutableDictionary *state=[@{@"checked":@(NSDate.date.timeIntervalSince1970)}mutableCopy];NSString *etag=headers[@"Etag"]?:headers[@"ETag"]?:headers[@"etag"];if(etag.length)state[@"etag"]=etag;[self saveState:state];[[NSNotificationCenter defaultCenter]postNotificationName:@"RWIMDbIndexUpdated" object:self];}});
    }});});
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {dispatch_async(dispatch_get_main_queue(),^{[[RWMetadataBudget shared]complete:task];if(task==self->_task)self->_task=nil;if(error)self->_diagnostics=@{@"error":error.localizedDescription?:@"Ratings refresh failed"};});}
@end
