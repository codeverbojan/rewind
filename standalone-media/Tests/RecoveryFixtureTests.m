#import "../RWDeviceExercise.h"
#import "../RWSourcePolicy.h"
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(x) do{checks++;if(!(x)){failures++;fprintf(stderr,"FAIL line%d\n",__LINE__);}}while(0)
 NSDictionary *source=[RWDeviceExercise recoverySource];
 NSDictionary *normalized=[RWSourcePolicy normalize:source provider:@"Owned USB test seed"];
 CHECK(normalized!=nil);CHECK([RWDeviceExercise isRecoverySource:normalized]);
 NSDictionary *meta=@{@"id":@"rw:recovery-mkv",@"type":@"movie",@"name":@"MKV recovery check"};
 NSArray *sources=[RWSourcePolicy sources:@[source] withMeta:meta videoID:@"rw:recovery-mkv:preview"];
 CHECK(sources.count==1);CHECK([RWDeviceExercise isRecoverySource:sources.firstObject]);
 CHECK([sources.firstObject[@"filename"]isEqual:@"rewind-recovery.mkv"]);
 CHECK([sources.firstObject[@"url"]rangeOfString:@"x.pe="].location==NSNotFound);
 for(NSString *backend in @[@"native",@"mkv"]){NSDictionary *fixture=[RWDeviceExercise lifecycleSource:backend];NSDictionary *n=[RWSourcePolicy normalize:fixture provider:@"Owned USB test seed"];CHECK(n!=nil);CHECK([RWDeviceExercise isLifecycleSource:n backend:backend]);NSString *video=[NSString stringWithFormat:@"rw:lifecycle-%@:preview",backend];NSArray *list=[RWSourcePolicy sources:@[fixture]withMeta:@{@"id":video,@"type":@"movie",@"name":@"Torrent lifecycle check"}videoID:video];CHECK(list.count==1);CHECK([RWDeviceExercise isLifecycleSource:list.firstObject backend:backend]);}
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
