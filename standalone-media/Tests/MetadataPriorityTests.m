#import "../RWDiscoveryMetadata.h"
#import "../RWAtomicWriter.h"
static NSMutableArray *Queries;static int Checks,Failures;
#define C(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
@interface PriorityProtocol:NSURLProtocol @end
@implementation PriorityProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)r{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r{return r;}
- (void)startLoading {
 NSString *url=self.request.URL.absoluteString.stringByRemovingPercentEncoding;NSRange range=[url rangeOfString:@"P345="];if(range.location!=NSNotFound){NSString *key=[url substringFromIndex:range.location+5];[Queries addObject:[[key componentsSeparatedByString:@"&"]firstObject]];}
 NSHTTPURLResponse *r=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}];[self.client URLProtocol:self didReceiveResponse:r cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:[@"{\"query\":{\"search\":[]}}" dataUsingEncoding:NSUTF8StringEncoding]];[self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading{}
@end
@interface PriorityMetadata:RWDiscoveryMetadata @end
@implementation PriorityMetadata
+ (NSURLSessionConfiguration *)sessionConfiguration{NSURLSessionConfiguration *c=[NSURLSessionConfiguration ephemeralSessionConfiguration];c.protocolClasses=@[PriorityProtocol.class];return c;}
@end
static void Wait(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:4];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];C(ready());}
int main(){@autoreleasepool{
 Queries=[NSMutableArray new];NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];NSMutableArray *items=[NSMutableArray new];for(int i=0;i<60;i++)[items addObject:@{@"id":[NSString stringWithFormat:@"tt%d",1000+i],@"type":@"movie"}];
 PriorityMetadata *s=[[PriorityMetadata alloc]initWithPath:[folder stringByAppendingPathComponent:@"a"] bundled:@""];[s enqueue:items];[s enqueue:items];C(Queries.count==0);
 NSArray *priority=@[items[20],items[0],items[50],items[51],items[52]];[s prioritizeTitles:priority];C([s isResolvingItems:@[items[50],items[51]]]);C(![s isResolvingItems:@[items[52]]]);C(Queries.count==0);s.paused=NO;Wait(^BOOL{return ![s isResolvingItems:items];});
 C(Queries.count==24);C([[NSSet setWithArray:Queries]count]==24);C([[Queries subarrayWithRange:NSMakeRange(0,MIN((NSUInteger)4,Queries.count))]isEqual:(@[@"tt1020",@"tt1000",@"tt1050",@"tt1051"])]);C(![Queries containsObject:@"tt1023"]);C(![Queries containsObject:@"tt1022"]);NSUInteger before=Queries.count;[s prioritizeTitles:[priority subarrayWithRange:NSMakeRange(0,4)]];C(Queries.count==before);[s invalidate];
 [Queries removeAllObjects];s=[[PriorityMetadata alloc]initWithPath:[folder stringByAppendingPathComponent:@"b"] bundled:@""];[s enqueue:items];__block int calls=0;[s resolve:items[55] done:^(NSDictionary *r,NSString *e){calls++;C(!r&&e.length);}];[s prioritizeTitles:@[items[8],items[55],items[8],items[9]]];s.paused=NO;Wait(^BOOL{return ![s isResolvingItems:items];});C(calls==1);C([Queries.firstObject isEqual:@"tt1055"]);C(Queries.count==13);C([Queries[1]isEqual:@"tt1008"]);C([Queries[2]isEqual:@"tt1009"]);[s invalidate];
 s=[[PriorityMetadata alloc]initWithPath:[folder stringByAppendingPathComponent:@"c"] bundled:@""];[s prioritizeTitles:@[items[1]]];C([s isResolvingItems:@[items[1]]]);[s cancelPending];C(![s isResolvingItems:@[items[1]]]);[s invalidate];[s prioritizeTitles:@[items[2]]];C(![s isResolvingItems:@[items[2]]]);
 __block BOOL idle=NO;[[RWAtomicWriter shared]whenIdle:^{idle=YES;}];Wait(^BOOL{return idle;});[NSFileManager.defaultManager removeItemAtPath:folder error:nil];C(![NSFileManager.defaultManager fileExistsAtPath:folder]);printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
