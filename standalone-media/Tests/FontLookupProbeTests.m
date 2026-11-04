#import "../RWFontLookupProbe.h"
#include <unistd.h>
static int checks,failures;
static void check(BOOL x,const char *name){checks++;if(!x){failures++;fprintf(stderr,"FAIL %s\n",name);}}
static BOOL await(RWFontLookupProbe *p,double limit){double began=NSProcessInfo.processInfo.systemUptime;while([[p snapshot][@"worker_running"]boolValue]&&NSProcessInfo.processInfo.systemUptime-began<limit)usleep(10000);return ![[p snapshot][@"worker_running"]boolValue];}
int main(){@autoreleasepool{
 RWFontLookupProbe *a=[RWFontLookupProbe new];check([[a snapshot][@"status"]isEqual:@"idle"]&&![[a snapshot][@"worker_running"]boolValue],"Construction does not start worker");
 check([a start],"Explicit first start admitted");check(![a start],"Duplicate start rejected");[a cancel];
 check([[a snapshot][@"status"]isEqual:@"cancelled"],"Cancellation immediately visible");check(![a start],"Cancelled probe cannot restart");check(await(a,10),"Cancelled worker terminates between calls");
 NSDictionary *cancelled=[a snapshot];usleep(10000);check([cancelled isEqual:[a snapshot]],"Terminal cancelled snapshot stable; late worker cannot republish data");
 RWFontLookupProbe *b=[RWFontLookupProbe new];check([b start]&&await(b,40),"Bounded serial lookup completes or records failure");NSDictionary *r=[b snapshot];
 check([@[@"complete",@"incomplete"]containsObject:r[@"status"]],"Terminal diagnostic status explicit");
 check([r[@"cases"]count]<=6&&[r[@"case_limit"]intValue]==6,"Fixed case bound");
 for(NSDictionary *row in r[@"cases"]){
  check([@[@"Helvetica Neue",@"Arial",@"ArialMT"]containsObject:row[@"family"]],"Only fixed public system-font names queried");
  check([row[@"file_reads"]count]<=64,"Fixed matched descriptor bound");
  for(NSDictionary *file in row[@"file_reads"]){
   check([file[@"descriptors_examined"]intValue]<=256&&[file[@"file_id"]intValue]<64,"Inner enumeration and anonymous identifiers bounded");
   if([row[@"status"]isEqual:@"complete"])check([file[@"descriptors_examined"]isEqual:file[@"descriptors_in_file"]],"Pinned VLC scans every descriptor and retains the last matching index");
  }
 }
 NSData *data=[NSJSONSerialization dataWithJSONObject:r options:0 error:NULL];NSString *json=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
 check(data&&[json rangeOfString:@"/System/"].location==NSNotFound&&[json rangeOfString:@"file:"].location==NSNotFound,"No system file paths or URLs retained");
 [b cancel];check([r isEqual:[b snapshot]],"Cancelling already-finished probe retains its evidence");
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
