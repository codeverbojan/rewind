#import "../RWLegacyStartupTrace.h"
static int checks,failures;
static void check(BOOL ok,const char *name){checks++;if(!ok){failures++;fprintf(stderr,"FAIL %s\n",name);}}
static void logAt(RWLegacyStartupTrace *t,double at,const char *format,...){va_list args;va_start(args,format);[t log:format arguments:args at:at];va_end(args);}
int main(){@autoreleasepool{
 RWLegacyStartupTrace*t=[[RWLegacyStartupTrace alloc]initAt:100];
 logAt(t,101,"opening file %s","private-name");
 logAt(t,101,"using %s module \"%s\"","access","private-name");
 logAt(t,101,"using %s module \"%s\"","decoder","https://secret");
 check([t snapshot][@"events"]&&[[t snapshot][@"events"]count]==0,"Unapproved formats and untrusted module names absent");
 logAt(t,101,"using %s module \"%s\"","decoder","avcodec");
 logAt(t,102,"Stream buffering done (%d ms in %d ms)",1200,51);
 logAt(t,103,"Decoder wait done in %d ms",3000);
 NSDictionary *before=[t snapshot];
 check([before[@"events"]count]==3,"Selected decoder and buffering milestones retained");
 check([before[@"events"][1][@"values"][@"message"]isEqual:@"Stream buffering done (1200 ms in 51 ms)"],"Numeric log values correctly copied during callback");
 logAt(t,104,"Buffering %d%%",1);logAt(t,104,"Buffering %d%%",50);
 check([[t snapshot][@"events"]count]==4&&[before[@"events"]count]==3,"Coarse buffering and immutable earlier snapshot");
 [t readBytes:100 seconds:.05 at:105];[t readBytes:200 seconds:.2 at:106];
 check([[t snapshot][@"read_bytes"]intValue]==300&&fabs([[t snapshot][@"read_seconds_sum"]doubleValue]-.25)<.0001,"Successful reads retain cumulative waiting rather than only last reset");
 [t readBytes:999 seconds:-1 at:107];[t readBytes:999 seconds:1 at:121];
 check([[t snapshot][@"read_calls"]intValue]==2,"Invalid duration and expired observation are excluded");
 [t sample:@{@"position":@0} at:107];[t sample:@{@"position":@1} at:107.1];[t sample:@{@"position":@2} at:107.3];
 check([[t snapshot][@"samples"]count]==2,"Samples limited to four per second");
 dispatch_apply(200,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^(size_t i){@autoreleasepool{[t event:@"concurrent" at:108 values:@{@"index":@(i)}];}});
 check([[t snapshot][@"events"]count]==96&&[[t snapshot][@"dropped"]intValue]>0,"Concurrent producers respect fixed event bound and count overflow");
 check([NSJSONSerialization isValidJSONObject:[t snapshot]],"Snapshot is serializable after concurrent callbacks");
 [t cancel];NSDictionary *closed=[t snapshot];[t sample:@{@"position":@3} at:109];[t readBytes:50 seconds:1 at:109];logAt(t,109,"Received first picture");
 check([closed isEqual:[t snapshot]],"Cancellation prevents late callback/read/sample mutation");
 RWLegacyStartupTrace*u=[[RWLegacyStartupTrace alloc]initAt:0];for(int i=0;i<80;i++)[u sample:@{@"position":@(i)} at:i*.25];
 check([[u snapshot][@"samples"]count]==48,"Fixed sample bound covers long startup without growing");
 logAt(u,-1,"Received first picture");logAt(u,NAN,"Received first picture");
 check([[u snapshot][@"events"]count]==0,"Invalid and pre-origin timestamps excluded");
 RWLegacyStartupTrace *v=[[RWLegacyStartupTrace alloc]initAt:0];
 const char *types[]={"video decoder","audio decoder","spu decoder","vout display","text renderer","video converter","audio converter","audio filter","audio resampler"};
 for(size_t i=0;i<sizeof(types)/sizeof(*types);i++){
  logAt(v,1,"looking for %s module matching \"%s\": %zd candidates",types[i],"https://private.invalid/token",(ssize_t)3);
  logAt(v,2,"using %s module \"%s\"",types[i],"test_module");
  NSArray *e=[v snapshot][@"events"];NSDictionary *a=e[e.count-2],*b=e.lastObject;
  check([a[@"event"]isEqual:@"module_begin"]&&[b[@"event"]isEqual:@"module_selected"]&&[a[@"values"][@"type"]isEqual:@(types[i])]&&[a[@"values"][@"thread"]isEqual:b[@"values"][@"thread"]]&&[a[@"values"][@"thread"]unsignedLongLongValue]>0,"Actual VLC capability begin/end pair retains matching thread identity");
 }
 NSData *encoded=[NSJSONSerialization dataWithJSONObject:[v snapshot] options:0 error:NULL];NSString *json=[[NSString alloc]initWithData:encoded encoding:NSUTF8StringEncoding];
 check([json rangeOfString:@"private"].location==NSNotFound&&[json rangeOfString:@"token"].location==NSNotFound,"Requested module match never retained");
 NSUInteger count=[[v snapshot][@"events"]count];
 logAt(v,3,"looking for %s module matching \"%s\": %zd candidates","access","any",(ssize_t)1);
 logAt(v,3,"looking for %s module matching \"%s\": %zd candidates","text renderer","any",(ssize_t)-1);
 logAt(v,3,"looking for %s module matching \"%s\": %zd candidates","text renderer","any",(ssize_t)4097);
 check([[v snapshot][@"events"]count]==count,"Unknown capability and impossible module counts rejected");
 logAt(v,4,"no %s modules matched","text renderer");logAt(v,4,"no %s modules","spu decoder");
 check([[v snapshot][@"events"]count]==count+2&&[[v snapshot][@"events"][count][@"event"]isEqual:@"module_unavailable"],"Unmatched and absent modules terminate trace pairs");
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
