#import <Foundation/Foundation.h>
#import "../RWSkipPolicy.h"
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(x) do{checks++;if(!(x)){failures++;fprintf(stderr,"Skip policy failure at line %d\n",__LINE__);}}while(0)
NSMutableDictionary *response=[@{@"imdb_id":@"tt123",@"media_type":@"tv",@"season":@1,@"episode":@2,@"intro":@{@"start_sec":@30,@"end_sec":@90,@"confidence":@.95,@"submission_count":@4},@"recap":[NSNull null]}mutableCopy];
CHECK([RWSkipPolicy segments:response imdb:@"tt123" season:1 episode:2 duration:2400].count==1);
CHECK([RWSkipPolicy segments:response imdb:@"tt124" season:1 episode:2 duration:2400].count==0);
CHECK([RWSkipPolicy segments:response imdb:@"tt123" season:1 episode:3 duration:2400].count==0);
CHECK([RWSkipPolicy segments:response imdb:@"tt123" season:1 episode:2 duration:50].count==0);
CHECK([RWSkipPolicy segments:response imdb:@"tt123" season:1 episode:2 duration:NAN].count==0);
for(NSDictionary *bad in @[@{@"start_sec":@0,@"end_sec":@400,@"confidence":@1,@"submission_count":@4},@{@"start_sec":@90,@"end_sec":@30,@"confidence":@1,@"submission_count":@4},@{@"start_sec":@30,@"end_sec":@90,@"confidence":@.5,@"submission_count":@4},@{@"start_sec":@30,@"end_sec":@90},@{}]){response[@"intro"]=bad;CHECK([RWSkipPolicy segments:response imdb:@"tt123" season:1 episode:2 duration:2400].count==0);}
response[@"intro"]=[NSNull null];CHECK([RWSkipPolicy segments:response imdb:@"tt123" season:1 episode:2 duration:2400].count==0);
printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;}}
