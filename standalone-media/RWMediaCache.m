#import "RWMediaCache.h"
#include <sys/stat.h>
static uint64_t Allocated(NSString *path){
    struct stat st={};if(lstat(path.fileSystemRepresentation,&st)!=0||S_ISLNK(st.st_mode))return 0;
    if(S_ISREG(st.st_mode))return (uint64_t)st.st_blocks*512;
    if(!S_ISDIR(st.st_mode))return 0;
    uint64_t bytes=0;for(NSString *name in [[NSFileManager defaultManager]contentsOfDirectoryAtPath:path error:nil])bytes+=Allocated([path stringByAppendingPathComponent:name]);return bytes;
}
@implementation RWMediaCache
+ (uint64_t)allocatedBytesAt:(NSString *)path {return Allocated(path);}
+ (NSDictionary *)trimRoot:(NSString *)root pinned:(NSSet *)pinned budget:(uint64_t)budget {
    return [self trimRoot:root pinned:pinned active:[NSSet set] budget:budget];
}
+ (NSDictionary *)trimRoot:(NSString *)root pinned:(NSSet *)pinned active:(NSSet *)active budget:(uint64_t)budget {
    // The engine supplies active session directories. Do not confuse serial
    // command execution with libtorrent's asynchronous disk jobs being idle.
    NSFileManager *fm=[NSFileManager defaultManager];NSMutableArray *entries=[NSMutableArray new];uint64_t total=0,kept=0,reclaimed=0,inUse=0;NSUInteger removed=0;
    for(NSString *name in [fm contentsOfDirectoryAtPath:root error:nil]){
        NSString *path=[root stringByAppendingPathComponent:name];struct stat st={};if(lstat(path.fileSystemRepresentation,&st)||S_ISLNK(st.st_mode))continue;
        uint64_t size=Allocated(path);BOOL busy=[active containsObject:name];if(busy)inUse+=size;if([pinned containsObject:name]){kept+=size;continue;}total+=size;if(busy)continue;
        [entries addObject:@{@"path":path,@"bytes":@(size),@"date":@(st.st_mtime)}];
    }
    [entries sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"date"]compare:b[@"date"]];}];
    NSDictionary *disk=[fm attributesOfFileSystemForPath:root error:nil];uint64_t free=[disk[NSFileSystemFreeSize]unsignedLongLongValue];
    for(NSDictionary *entry in entries){if(total<=budget&&free>=1024ULL*1024*1024)break;uint64_t bytes=[entry[@"bytes"]unsignedLongLongValue];
        if([fm removeItemAtPath:entry[@"path"] error:nil]){total-=bytes;free+=bytes;reclaimed+=bytes;removed++;}
    }
    return @{@"temporary_bytes":@(total),@"kept_bytes":@(kept),@"active_bytes":@(inUse),@"reclaimed_bytes":@(reclaimed),@"removed_entries":@(removed),@"budget_bytes":@(budget)};
}
@end
