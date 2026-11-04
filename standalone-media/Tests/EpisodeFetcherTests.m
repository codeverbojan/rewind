#import "../RWEpisodeFetcher.h"
#import "../RWMetadataBudget.h"
#import "../RWReminderPolicy.h"
static NSMutableArray *Pending,*Started;static NSUInteger Active,Peak;static BOOL WrongIdentity;
@interface EpisodeProtocol:NSURLProtocol
@property(nonatomic,assign) BOOL stopped;
@end
@implementation EpisodeProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)r{return [r.URL.host isEqual:@"v3-cinemeta.strem.io"];}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r{return r;}
- (void)startLoading {@synchronized(EpisodeProtocol.class){[Pending addObject:self];[Started addObject:self.request.URL.absoluteString];Active++;Peak=MAX(Peak,Active);}}
- (void)stopLoading {@synchronized(EpisodeProtocol.class){if(!self.stopped){self.stopped=YES;Active--;[Pending removeObject:self];}}}
- (void)finish {
    @synchronized(EpisodeProtocol.class){if(self.stopped)return;self.stopped=YES;Active--;[Pending removeObject:self];}
    NSString *identifier=self.request.URL.lastPathComponent.stringByDeletingPathExtension;
    NSDictionary *meta=@{@"id":WrongIdentity?@"tt9999999":identifier,@"type":@"series",@"videos":@[@{@"id":[identifier stringByAppendingString:@":1:1"],@"season":@1,@"episode":@1,@"released":@"2020-01-01"}]};
    NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"meta":meta} options:0 error:nil];NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:data];[self.client URLProtocolDidFinishLoading:self];
}
@end
static void Spin(double s){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:s];while(end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];}
static void FinishOne(void){EpisodeProtocol *p;@synchronized(EpisodeProtocol.class){p=Pending.firstObject;}[p finish];Spin(.03);}
int main(){@autoreleasepool{__block int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    Pending=[NSMutableArray new];Started=[NSMutableArray new];NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;config.protocolClasses=@[EpisodeProtocol.class];NSURLSession *session=[NSURLSession sessionWithConfiguration:config];RWMetadataBudget *budget=[RWMetadataBudget new];budget.paused=YES;
    __block NSUInteger completions=0,accepted=0;__block NSDictionary *last;__block BOOL ready=NO;void(^done)(NSDictionary *)=^(NSDictionary *m){CHECK(NSThread.isMainThread);completions++;last=m;};
    RWEpisodeFetcher *fetch=[[RWEpisodeFetcher alloc]initWithSession:session budget:budget];
    [fetch startWhenReady:^BOOL{return ready;} identifiers:^NSArray *{return @[@"tt1234567",@"tt1234567",NSNull.null,@"http://other",@"tt2345678",@"tt3456789",@"tt4567890",@"tt5678901"];} background:YES timeout:2 accept:^(NSDictionary *m){CHECK(NSThread.isMainThread);accepted++;} done:done];
    Spin(.12);CHECK(!Started.count&&!completions);ready=YES;Spin(.12);CHECK(Started.count==1&&budget.paused);CHECK([budget.diagnostics[@"active"]intValue]==0);
    for(int i=0;i<4;i++)FinishOne();CHECK(accepted==4&&completions==1&&Started.count==4);CHECK(Peak==1&&Active==0);CHECK([last[@"requests"]intValue]==4&&[last[@"catalog_wait_seconds"]doubleValue]>=.1);CHECK(![last[@"errors"]count]);
    fetch=[[RWEpisodeFetcher alloc]initWithSession:session budget:budget];[fetch startWhenReady:^BOOL{return YES;} identifiers:^NSArray *{return @[@"tt1234567"];} background:NO timeout:2 accept:^(NSDictionary *m){accepted++;} done:done];Spin(.04);CHECK(Started.count==4);budget.paused=NO;Spin(.04);CHECK(Started.count==5);FinishOne();CHECK(completions==2&&accepted==5);
    WrongIdentity=YES;fetch=[[RWEpisodeFetcher alloc]initWithSession:session budget:budget];[fetch startWhenReady:^BOOL{return YES;} identifiers:^NSArray *{return @[@"tt1234567"];} background:YES timeout:2 accept:^(NSDictionary *m){accepted++;} done:done];Spin(.03);FinishOne();CHECK(accepted==5&&completions==3&&[last[@"errors"]containsObject:@"invalid_show"]);WrongIdentity=NO;
    fetch=[[RWEpisodeFetcher alloc]initWithSession:session budget:budget];[fetch startWhenReady:^BOOL{return NO;} identifiers:^NSArray *{return @[@"tt1234567"];} background:YES timeout:.08 accept:nil done:done];Spin(.15);CHECK(completions==4&&[last[@"errors"]containsObject:@"deadline"]&&[last[@"requests"]intValue]==0);
    fetch=[[RWEpisodeFetcher alloc]initWithSession:session budget:budget];[fetch startWhenReady:nil identifiers:^NSArray *{return @[@"tt1234567",@"tt2345678"];} background:YES timeout:2 accept:^(NSDictionary *m){accepted++;} done:done];Spin(.03);[fetch cancel];[fetch cancel];Spin(.04);CHECK(completions==5&&accepted==5&&Active==0&&[last[@"errors"]containsObject:@"cancelled"]);
    fetch=[[RWEpisodeFetcher alloc]initWithSession:session budget:budget];[fetch startWhenReady:nil identifiers:^NSArray *{return @[@"tt1234567"];} background:YES timeout:.08 accept:nil done:done];Spin(.15);CHECK(completions==6&&Active==0&&[last[@"errors"]containsObject:@"deadline"]);
    NSDictionary *movie=@{@"type":@"movie"},*series=@{@"type":@"series"},*scheduled=@{@"type":@"series",@"scheduledEpisode":@{}};
    CHECK([[[RWReminderPolicy presentation:scheduled mode:@"Waiting" following:YES watching:NO alerts:YES]objectForKey:@"kind"]isEqual:@"availability"]);
    CHECK([[[RWReminderPolicy presentation:scheduled mode:@"Coming soon" following:NO watching:YES alerts:NO]objectForKey:@"kind"]isEqual:@"episode"]);
    CHECK([[[RWReminderPolicy presentation:series mode:@"Coming soon" following:YES watching:NO alerts:YES]objectForKey:@"kind"]isEqual:@"availability"]);
    CHECK([[[RWReminderPolicy presentation:series mode:@"Following" following:YES watching:YES alerts:YES]objectForKey:@"kind"]isEqual:@"manage"]);
    CHECK([[[RWReminderPolicy presentation:movie mode:@"Following" following:NO watching:YES alerts:NO]objectForKey:@"title"]isEqual:@"Reminder set"]);
    CHECK([[[RWReminderPolicy presentation:scheduled mode:@"Coming soon" following:YES watching:NO alerts:NO]objectForKey:@"enable"]boolValue]);
    CHECK(![[[RWReminderPolicy presentation:scheduled mode:@"Coming soon" following:YES watching:NO alerts:YES]objectForKey:@"enable"]boolValue]);
    [session invalidateAndCancel];Spin(.05);CHECK(Active==0&&Pending.count==0);
    printf("{\"checks\":%d,\"failures\":%d,\"peak\":%lu,\"completion_callbacks\":%lu}\n",checks,failures,(unsigned long)Peak,(unsigned long)completions);return failures?1:0;
}}
