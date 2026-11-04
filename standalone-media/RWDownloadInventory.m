#import "RWDownloadInventory.h"
#import "RWDiscoverySnapshot.h"
#import "RWOfflineMedia.h"
#include <sys/stat.h>
#include <errno.h>
#include <math.h>
static NSDictionary *DD(id x){return [x isKindOfClass:NSDictionary.class]?x:@{};}
static NSString *DS(id x){return [x isKindOfClass:NSString.class]?x:@"";}
static double DN(id x){double n=[x respondsToSelector:@selector(doubleValue)]?[x doubleValue]:0;return isfinite(n)?MAX(0,n):0;}
@implementation RWDownloadInventory
+ (NSDictionary *)snapshotRoot:(NSString *)root history:(NSArray *)history gate:(NSDictionary *)gate pinned:(NSSet *)pinned {
    double start=NSProcessInfo.processInfo.systemUptime;NSMutableArray *items=[NSMutableArray new];NSString *error=nil;struct stat rootStat={};int result=lstat(root.fileSystemRepresentation,&rootStat);BOOL exists=result==0&&S_ISDIR(rootStat.st_mode)&&!S_ISLNK(rootStat.st_mode);
    if((result&&errno!=ENOENT)||(!result&&!exists))error=@"Couldn’t read saved videos. Try again.";
    NSMutableArray *metas=[NSMutableArray new];for(id raw in history){NSDictionary *meta=DD(DD(raw)[@"meta"]);if(meta.count)[metas addObject:meta];}
    NSMutableSet *allowed=[NSMutableSet new];for(NSDictionary *m in [RWDiscoverySnapshot filter:metas snapshot:gate])if(DS(m[@"id"]).length)[allowed addObject:m[@"id"]];
    NSArray *sorted=[history sortedArrayUsingComparator:^NSComparisonResult(id a,id b){double left=DN(DD(a)[@"updated"]),right=DN(DD(b)[@"updated"]);return left>right?NSOrderedAscending:left<right?NSOrderedDescending:[DS(DD(a)[@"videoID"])compare:DS(DD(b)[@"videoID"])];}];
    NSMutableSet *seen=[NSMutableSet new];NSUInteger inspected=0;
    if(exists)for(id raw in sorted){NSDictionary *r=DD(raw),*source=DD(r[@"source"]),*meta=DD(r[@"meta"]);NSString *videoID=DS(r[@"videoID"]),*hash=DS(source[@"infoHash"]).lowercaseString;
        if(!videoID.length||[seen containsObject:videoID]||![allowed containsObject:DS(meta[@"id"])]||![DS(source[@"url"])hasPrefix:@"magnet:"]||hash.length!=40||[hash rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"]invertedSet]].location!=NSNotFound)continue;
        struct stat st={};inspected++;NSString *path=[root stringByAppendingPathComponent:hash];if(lstat(path.fileSystemRepresentation,&st)||S_ISLNK(st.st_mode)||!S_ISDIR(st.st_mode))continue;
        [seen addObject:videoID];NSInteger index=[source[@"fileIdx"]isKindOfClass:NSNumber.class]?[source[@"fileIdx"]integerValue]:-1;BOOL offline=[RWOfflineMedia validate:DD(source[@"offlineCertificate"]) root:root hash:hash fileIndex:index];
        NSMutableDictionary *brief=[NSMutableDictionary new];for(NSString *key in @[@"id",@"type",@"name",@"background",@"poster",@"releaseInfo",@"genres",@"season",@"episode"])if(meta[key])brief[key]=meta[key];
        [items addObject:@{@"videoID":videoID,@"hash":hash,@"meta":brief,@"position":@(DN(r[@"position"])),@"duration":@(DN(r[@"duration"])),@"updated":@(DN(r[@"updated"])),@"reportedBytes":@(DN(source[@"downloadBytes"])),@"offlineVerified":@(offline),@"kept":@([pinned containsObject:hash])}];
    }
    NSDictionary *space=[NSFileManager.defaultManager attributesOfFileSystemForPath:root.stringByDeletingLastPathComponent error:nil];
    return @{@"items":items,@"freeBytes":space[NSFileSystemFreeSize]?:@0,@"spaceKnown":@(space[NSFileSystemFreeSize]!=nil),@"error":error?:@"",@"metrics":@{@"worker_seconds":@(NSProcessInfo.processInfo.systemUptime-start),@"off_main":@(!NSThread.isMainThread),@"inspected_folders":@(inspected),@"history_records":@(history.count),@"visible_records":@(items.count)}};
}
@end
