#import <Foundation/Foundation.h>
#import "../RWPlaybackLifetimeProbe.h"
int main(){@autoreleasepool{
 int checks=0,failures=0;
#define C(x) do{checks++;if(!(x)){failures++;fprintf(stderr,"FAIL line%d\n",__LINE__);}}while(0)
 RWPlaybackLifetimeProbe *probe;__weak NSObject *observed;NSObject *retained;
 @autoreleasepool{NSObject *a=[NSObject new];observed=a;retained=[NSObject new];probe=[[RWPlaybackLifetimeProbe alloc]initWithObjects:@{@"player":a,@"engine":retained}];C([probe.snapshot[@"player"]intValue]==1);C([probe.snapshot[@"engine"]intValue]==1);}
 C(observed==nil);C([probe.snapshot[@"player"]intValue]==0);C([probe.snapshot[@"engine"]intValue]==1);
 retained=nil;C([probe.snapshot[@"engine"]intValue]==0);C(probe.snapshot.count==2);C([[[RWPlaybackLifetimeProbe alloc]initWithObjects:@{}]snapshot].count==0);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
