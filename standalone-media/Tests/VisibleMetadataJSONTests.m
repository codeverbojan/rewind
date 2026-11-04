#import <Foundation/Foundation.h>
#import "../RWMetadataBudget.h"
#import "../RWRequestCoalescer.h"
#import "../RWDiscoveryEpisodes.h"
static NSUInteger Checks,Failures;static NSMutableArray *Started;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static void Spin(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];}
static void Wait(BOOL(^done)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:3];while(!done()&&end.timeIntervalSinceNow>0)Spin(.005);CHECK(done());}
typedef void(^RWResult)(id,NSString *);
@interface MetadataProtocol:NSURLProtocol @end
@implementation MetadataProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request{return request;}
- (void)startLoading {
 @synchronized(Started){[Started addObject:self.request];}
 NSData *data=[([self.request.URL.host isEqual:@"api.tvmaze.com"]?@"[]":@"{\"query\":{\"search\":[]}}")dataUsingEncoding:NSUTF8StringEncoding];
 NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}];[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:data];[self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end
@interface JSONStore:NSObject {RWRequestCoalescer *_jsonRequests;}
@property(nonatomic,strong) NSURLSession *session;
@end
@implementation JSONStore
- (instancetype)init{if((self=[super init])){_jsonRequests=[RWRequestCoalescer new];NSURLSessionConfiguration *c=[NSURLSessionConfiguration ephemeralSessionConfiguration];c.protocolClasses=@[MetadataProtocol.class];self.session=[NSURLSession sessionWithConfiguration:c];}return self;}
- (void)report:(NSDictionary *)record{}
#include "VisibleMetadataJSONUnderTest.inc"
@end
int main(){@autoreleasepool{
 Started=[NSMutableArray new];JSONStore *store=[JSONStore new];RWMetadataBudget *budget=RWMetadataBudget.shared;__block NSUInteger completed=0;
 @try{
  budget.paused=YES;
  for(NSString *url in @[@"https://api.tvmaze.com/schedule?country=US&date=2030-01-01",@"https://api.tvmaze.com/schedule/web?date=2030-01-01",@"https://www.wikidata.org/w/api.php?action=query",@"https://www.wikidata.org/w/api.php?action=wbgetentities"]){
   [store JSON:url foreground:YES done:^(id value,NSString *error){CHECK(!error);CHECK([value isKindOfClass:NSDictionary.class]);if([url containsString:@"tvmaze"])CHECK([value[@"episodes"]isKindOfClass:NSArray.class]);completed++;}];
  }
  Spin(.08);CHECK(completed==0);@synchronized(Started){CHECK(Started.count==0);}CHECK([budget.diagnostics[@"pending"]intValue]==4);CHECK([budget.diagnostics[@"active"]intValue]==0);
  budget.paused=NO;CHECK([budget.diagnostics[@"active"]intValue]==2);CHECK([budget.diagnostics[@"pending"]intValue]==2);Wait(^BOOL{return completed==4;});
  CHECK([budget.diagnostics[@"peak_active"]intValue]==2);CHECK([budget.diagnostics[@"peak_per_host"]intValue]==1);CHECK([budget.diagnostics[@"active"]intValue]==0);CHECK([budget.diagnostics[@"pending"]intValue]==0);
  @synchronized(Started){CHECK(Started.count==4);for(NSURLRequest *request in Started)CHECK(request.timeoutInterval==8);}
 }@finally{budget.paused=NO;[store.session invalidateAndCancel];Wait(^BOOL{return [budget.diagnostics[@"active"]intValue]==0&&[budget.diagnostics[@"pending"]intValue]==0;});}
 printf("{\"checks\":%lu,\"failures\":%lu}\n",(unsigned long)Checks,(unsigned long)Failures);return Failures?1:0;
}}
