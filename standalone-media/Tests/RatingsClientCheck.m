#import <Foundation/Foundation.h>
#import "../RWRatings.h"
int main(){@autoreleasepool{NSString *path=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];__block BOOL done=NO;__block BOOL ok=NO;RWRatings *ratings=[[RWRatings alloc]initWithCache:path bundled:@"/nonexistent-rewind-fixture"];
 id token=[[NSNotificationCenter defaultCenter]addObserverForName:@"RWRatingsUpdated" object:ratings queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){NSDictionary *g=[ratings rating:@"tt0114709"],*r=[ratings rating:@"tt0095016"];ok=g&&r&&[g[@"minimumAge"]intValue]==0&&[r[@"minimumAge"]intValue]>=17;done=YES;}];
 @try{[ratings resolve:@[@{@"id":@"tt0114709"},@{@"id":@"tt0095016"}]];NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:45];while(!done&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
 printf("{\"live_lookup_finished\":%s,\"exact_imdb_ratings_verified\":%s}\n",done?"true":"false",ok?"true":"false");}
 @finally{[[NSNotificationCenter defaultCenter]removeObserver:token];[[NSFileManager defaultManager]removeItemAtPath:path error:nil];}
 return ok?0:1;}}
