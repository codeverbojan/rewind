#import "../RWOfflineMedia.h"
#import "../RWAvailability.h"
static int checks,failures;static void Check(BOOL ok){checks++;if(!ok)failures++;}
int main(){@autoreleasepool{
 NSString *root=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString],*hash=@"1234567890123456789012345678901234567890",*dir=[root stringByAppendingPathComponent:hash],*path=[dir stringByAppendingPathComponent:@"video.mp4"];NSFileManager *fm=NSFileManager.defaultManager;[fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];[@"verified file content" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
 NSDictionary *p=[RWOfflineMedia certificateForPath:path root:root hash:hash fileIndex:2];Check(p.count>0);Check([RWOfflineMedia validate:p root:root hash:hash fileIndex:2]);Check(![RWOfflineMedia validate:p root:root hash:hash fileIndex:3]);Check(![RWOfflineMedia validate:p root:root hash:@"ffffffffffffffffffffffffffffffffffffffff" fileIndex:2]);
 NSMutableDictionary *bad=[p mutableCopy];bad[@"relative"]=@"../outside.mp4";Check(![RWOfflineMedia validate:bad root:root hash:hash fileIndex:2]);bad=[p mutableCopy];bad[@"size"]=@1;Check(![RWOfflineMedia validate:bad root:root hash:hash fileIndex:2]);
 [@"changed" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];Check(![RWOfflineMedia validate:p root:root hash:hash fileIndex:2]);[fm removeItemAtPath:path error:nil];Check(![RWOfflineMedia validate:p root:root hash:hash fileIndex:2]);
 [fm createSymbolicLinkAtPath:path withDestinationPath:@"/etc/hosts" error:nil];Check(![RWOfflineMedia certificateForPath:path root:root hash:hash fileIndex:2]);
 double now=NSDate.date.timeIntervalSince1970;NSDictionary *m=@{@"id":@"tt123",@"type":@"movie"},*observation=@{@"policy":@34,@"quality":@0,@"offline_valid":@YES,@"offline_at":@(now)};
 Check([[RWAvailability presentation:m observation:observation now:now][@"state"]isEqual:@"offline"]);Check([[RWAvailability presentation:m observation:observation now:now][@"hero_eligible"]boolValue]);Check(![[RWAvailability presentation:m observation:observation quality:720 now:now][@"hero_eligible"]boolValue]);
 bad=[observation mutableCopy];bad[@"failed_at"]=@(now+1);Check(![[RWAvailability presentation:m observation:bad now:now+2][@"hero_eligible"]boolValue]);
 [fm removeItemAtPath:root error:nil];printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
