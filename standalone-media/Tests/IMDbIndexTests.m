#import "../RWIMDbIndex.h"
#import <zlib.h>
#import <sqlite3.h>
static void Archive(NSString *path,NSString *text){gzFile f=gzopen(path.fileSystemRepresentation,"wb");NSData *d=[text dataUsingEncoding:NSUTF8StringEncoding];gzwrite(f,d.bytes,(unsigned int)d.length);gzclose(f);}
static void Sized(NSString *path,unsigned long long bytes){[NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];[NSFileManager.defaultManager createFileAtPath:path contents:nil attributes:nil];NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:path];[h truncateFileAtOffset:bytes];[h closeFile];}
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];NSString *gzip=[folder stringByAppendingPathComponent:@"ratings.gz"],*dbpath=[folder stringByAppendingPathComponent:@"ratings.sqlite"];
    Archive(gzip,@"tconst\taverageRating\tnumVotes\ntt6751668\t8.5\t1204073\ntt1375666\t8.8\t2881605\n");
    NSDictionary *result=[RWIMDbIndex importGzip:gzip destination:dbpath cancelled:nil];CHECK([result[@"ok"]boolValue]&&[result[@"rows"]intValue]==2);
    NSData *original=[NSData dataWithContentsOfFile:dbpath];sqlite3 *db;sqlite3_stmt *query;sqlite3_open_v2(dbpath.fileSystemRepresentation,&db,SQLITE_OPEN_READONLY,NULL);sqlite3_prepare_v2(db,"SELECT r,v FROM ratings WHERE id=1375666",-1,&query,NULL);CHECK(sqlite3_step(query)==SQLITE_ROW);CHECK(sqlite3_column_int(query,0)==88&&sqlite3_column_int(query,1)==2881605);sqlite3_finalize(query);sqlite3_close(db);
    CHECK(![[RWIMDbIndex importGzip:gzip destination:dbpath cancelled:^BOOL{return YES;}][@"ok"]boolValue]);CHECK([[NSData dataWithContentsOfFile:dbpath]isEqual:original]);
    Archive(gzip,@"tconst\taverageRating\tnumVotes\ntt1\t99\t50\n");CHECK(![[RWIMDbIndex importGzip:gzip destination:dbpath cancelled:nil][@"ok"]boolValue]);CHECK([[NSData dataWithContentsOfFile:dbpath]isEqual:original]);
    Archive(gzip,@"tconst\taverageRating\tnumVotes\ntt1\t8.0\t50\ntt1\t8.1\t60\n");CHECK(![[RWIMDbIndex importGzip:gzip destination:dbpath cancelled:nil][@"ok"]boolValue]);CHECK([[NSData dataWithContentsOfFile:dbpath]isEqual:original]);
    Archive(gzip,@"wrong schema\n");CHECK(![[RWIMDbIndex importGzip:gzip destination:dbpath cancelled:nil][@"ok"]boolValue]);CHECK(![NSFileManager.defaultManager fileExistsAtPath:[dbpath stringByAppendingString:@".import"]]);
    NSMutableString *many=[@"tconst\taverageRating\tnumVotes\n" mutableCopy];for(int i=1;i<=2000;i++)[many appendFormat:@"tt%07d\t8.0\t50\n",i];Archive(gzip,many);
    NSDictionary *limited=[RWIMDbIndex importGzip:gzip destination:dbpath maximumBytes:8192 cancelled:nil];CHECK(![limited[@"ok"]boolValue]);CHECK([limited[@"error"]containsString:@"disk budget"]);CHECK([limited[@"bytes"]unsignedLongLongValue]<=8192);CHECK([[NSData dataWithContentsOfFile:dbpath]isEqual:original]);CHECK(![NSFileManager.defaultManager fileExistsAtPath:[dbpath stringByAppendingString:@".import"]]);
    CHECK(![[RWIMDbIndex importGzip:gzip destination:dbpath maximumBytes:8191 cancelled:nil][@"ok"]boolValue]);CHECK([[NSData dataWithContentsOfFile:dbpath]isEqual:original]);
    NSString *bundle=[folder stringByAppendingPathComponent:@"Bundle"],*documents=[folder stringByAppendingPathComponent:@"Documents"],*index=[documents stringByAppendingPathComponent:@"RatingsIndex"];
    for(NSString *d in @[bundle,index])[NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *bundled=[bundle stringByAppendingPathComponent:@"imdb-ratings.sqlite"],*current=[index stringByAppendingPathComponent:@"ratings.sqlite"];
    [original writeToFile:bundled atomically:YES];[original writeToFile:current atomically:YES];[[@"{}" dataUsingEncoding:NSUTF8StringEncoding]writeToFile:[documents stringByAppendingPathComponent:@"catalog.json"] atomically:YES];
    NSDictionary *budget=[RWIMDbIndex updateBudgetForFolder:index bundled:bundled downloadBytes:1024];CHECK([budget[@"bundled"]unsignedLongLongValue]==original.length&&[budget[@"documents"]integerValue]==2);CHECK([budget[@"current_index"]unsignedLongLongValue]==original.length);CHECK([budget[@"reserved_peak"]unsignedLongLongValue]<=100ULL*1024*1024);
    // Sparse files exercise the full atomic-update calculation without RAM use.
    NSFileHandle *large=[NSFileHandle fileHandleForWritingAtPath:current];[large truncateFileAtOffset:90ULL*1024*1024];[large closeFile];budget=[RWIMDbIndex updateBudgetForFolder:index bundled:bundled downloadBytes:16ULL*1024*1024];CHECK([budget[@"maximum_new_index"]unsignedLongLongValue]==0);CHECK([budget[@"before_import"]unsignedLongLongValue]>[budget[@"cap"]unsignedLongLongValue]);
    // Exact sizes from the210 physical first update: a subsequent replacement
    // must fit with both last-good and replacement DBs plus ALL metadata caches.
    Sized(bundled,23531520);Sized([bundle stringByAppendingPathComponent:@"seed.json"],1698264);
    Sized(current,23572480);Sized([documents stringByAppendingPathComponent:@"catalog.json"],8095148);
    NSString *torrent=[documents stringByAppendingPathComponent:@"TorrentMetadata"];
    Sized([torrent stringByAppendingPathComponent:@"owned.torrent"],7157872);
    Sized([documents stringByAppendingPathComponent:@".dat.nosync-owned"],817223);
    budget=[RWIMDbIndex updateBudgetForFolder:index bundled:bundled downloadBytes:8719225];
    CHECK([budget[@"torrent_metadata"]unsignedLongLongValue]==7157872);
    CHECK([budget[@"atomic_temporary"]unsignedLongLongValue]==817223);
    CHECK([budget[@"maximum_new_index"]unsignedLongLongValue]>=23572480);
    CHECK([budget[@"before_import"]unsignedLongLongValue]+23572480<=[budget[@"cap"]unsignedLongLongValue]);
    CHECK([budget[@"cap"]unsignedLongLongValue]==128ULL*1024*1024);
    CHECK([budget[@"before_import"]unsignedLongLongValue]==25229784+8095148+23572480+8719225+8388608+8388608+6422528+7157872+817223);
    unsigned long long realBudget=[budget[@"maximum_new_index"]unsignedLongLongValue];
    // Do not follow symlinks outside the metadata folder or count directory inode sizes.
    [NSFileManager.defaultManager createSymbolicLinkAtPath:[torrent stringByAppendingPathComponent:@"outside"] withDestinationPath:current error:nil];
    [NSFileManager.defaultManager createDirectoryAtPath:[torrent stringByAppendingPathComponent:@"directory"] withIntermediateDirectories:YES attributes:nil error:nil];
    budget=[RWIMDbIndex updateBudgetForFolder:index bundled:bundled downloadBytes:8719225];CHECK([budget[@"maximum_new_index"]unsignedLongLongValue]==realBudget);
    // Both normal and failure bounds remain strict as unrelated metadata grows.
    Sized([torrent stringByAppendingPathComponent:@"pressure.torrent"],130ULL*1024*1024);
    budget=[RWIMDbIndex updateBudgetForFolder:index bundled:bundled downloadBytes:8719225];CHECK([budget[@"maximum_new_index"]unsignedLongLongValue]==0);
    // Local candidate+anchor+feedback lookup remains bounded at 525 records.
    CHECK([[RWIMDbIndex importGzip:gzip destination:dbpath cancelled:nil][@"ok"]boolValue]);RWIMDbIndex *lookup=[[RWIMDbIndex alloc]initWithFolder:folder bundled:dbpath];NSMutableArray *requested=[NSMutableArray new];for(int i=1;i<=600;i++)[requested addObject:[NSString stringWithFormat:@"tt%07d",i]];
    __block NSDictionary *found=nil;__block BOOL onMain=NO;[lookup ratingsForIDs:requested done:^(NSDictionary *value){found=value;onMain=NSThread.isMainThread;}];NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];while(!found&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];
    CHECK(onMain&&found.count==525);CHECK(found[@"tt0000525"]&&!found[@"tt0000526"]);
    [NSFileManager.defaultManager removeItemAtPath:folder error:nil];CHECK(![NSFileManager.defaultManager fileExistsAtPath:folder]);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
