#import "RWOfflineMedia.h"
#include <sys/stat.h>
static BOOL OMHash(NSString *s){return [s isKindOfClass:NSString.class]&&s.length==40&&[s rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdef0123456789"]invertedSet]].location==NSNotFound;}
static NSDictionary *OMStat(NSString *path,NSString *root){
    NSString *base=root.stringByStandardizingPath,*target=path.stringByStandardizingPath;if(![target hasPrefix:[base stringByAppendingString:@"/"]])return nil;
    NSString *relative=[target substringFromIndex:base.length+1];NSString *cursor=base;struct stat st={};
    for(NSString *component in relative.pathComponents){cursor=[cursor stringByAppendingPathComponent:component];if(lstat(cursor.fileSystemRepresentation,&st)||S_ISLNK(st.st_mode))return nil;}
    if(!S_ISREG(st.st_mode)||st.st_size<=0)return nil;
    return @{@"relative":relative,@"size":@((unsigned long long)st.st_size),@"inode":@((unsigned long long)st.st_ino),@"mtime":@((long long)st.st_mtimespec.tv_sec),@"mtimeNS":@((long long)st.st_mtimespec.tv_nsec)};
}
@implementation RWOfflineMedia
+ (NSDictionary *)certificateForPath:(NSString *)path root:(NSString *)root hash:(NSString *)hash fileIndex:(NSInteger)fileIndex {
    if(!OMHash(hash)||fileIndex < -1)return nil;NSDictionary *attributes=OMStat(path,root);if(![attributes[@"relative"]hasPrefix:[hash stringByAppendingString:@"/"]])return nil;
    NSMutableDictionary *proof=[attributes mutableCopy];proof[@"hash"]=hash;proof[@"fileIndex"]=@(fileIndex);proof[@"version"]=@1;proof[@"verifiedAt"]=@(NSDate.date.timeIntervalSince1970);return proof;
}
+ (BOOL)validate:(NSDictionary *)certificate root:(NSString *)root hash:(NSString *)hash fileIndex:(NSInteger)fileIndex {
    if(![certificate isKindOfClass:NSDictionary.class]||[certificate[@"version"]integerValue]!=1||!OMHash(hash)||![certificate[@"hash"]isEqual:hash]||[certificate[@"fileIndex"]integerValue]!=fileIndex)return NO;
    NSString *relative=certificate[@"relative"];if(![relative isKindOfClass:NSString.class]||relative.isAbsolutePath||[relative.pathComponents containsObject:@".."]||![relative hasPrefix:[hash stringByAppendingString:@"/"]])return NO;
    NSDictionary *actual=OMStat([root stringByAppendingPathComponent:relative],root);if(!actual)return NO;for(NSString *key in @[@"size",@"inode",@"mtime",@"mtimeNS"])if(![actual[key]isEqual:certificate[key]])return NO;return YES;
}
@end
