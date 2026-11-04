#import "../RWDiscoveryMetadata.h"
@interface RWDiscoveryMetadata (RecoveryContract)
- (void)entity:(NSString *)entityID role:(NSString *)role failedImage:(NSString *)url done:(void(^)(NSDictionary *,NSString *))done;
@end
static NSUInteger Requests,Mode;static int Checks,Failures;
@interface PhotoProtocol:NSURLProtocol @end
@implementation PhotoProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)r{return YES;}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r{return r;}
- (void)startLoading {
    Requests++;NSString *host=self.request.URL.host;NSInteger status=200;NSDictionary *json;
    if([host isEqual:@"commons.wikimedia.org"]){status=Mode==1?500:200;json=@{@"query":@{@"pages":@{@"1":@{@"title":@"File:Portrait.jpg",@"imageinfo":@[@{@"thumburl":@"https://upload.wikimedia.org/portrait.jpg",@"descriptionurl":@"https://commons.wikimedia.org/wiki/File:Portrait.jpg",@"extmetadata":@{@"Artist":@{@"value":@"Test artist"},@"LicenseShortName":@{@"value":@"CC BY 4.0"}}}]}}}};}
    else if([host isEqual:@"en.wikipedia.org"])json=@{@"query":@{@"pages":@{@"1":@{@"ns":@0,@"title":@"Exact Person",@"extract":@"Verified biography remains readable during a photo outage.",@"pageprops":@{@"wikibase_item":@"Q20"}}}}};
    else json=@{@"entities":@{@"Q20":@{@"id":@"Q20",@"labels":@{@"en":@{@"value":@"Exact Person"}},@"claims":Mode==2?@{}:@{@"P18":@[@{@"mainsnak":@{@"datavalue":@{@"value":@"Portrait.jpg"}}}]},@"sitelinks":@{@"enwiki":@{@"title":@"Exact Person"}}}}};
    [self.client URLProtocol:self didReceiveResponse:[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}] cacheStoragePolicy:NSURLCacheStorageNotAllowed];[self.client URLProtocol:self didLoadData:[NSJSONSerialization dataWithJSONObject:json options:0 error:nil]];[self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end
@interface PhotoService:RWDiscoveryMetadata @end
@implementation PhotoService
+ (NSURLSessionConfiguration *)sessionConfiguration {NSURLSessionConfiguration *c=NSURLSessionConfiguration.ephemeralSessionConfiguration;c.protocolClasses=@[PhotoProtocol.class];return c;}
- (void)persist {}
@end
static void Check(BOOL b){Checks++;if(!b){Failures++;fprintf(stderr,"FAIL check %d\n",Checks);}}
static BOOL Until(BOOL(^f)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:2];while(!f()&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];return f();}
int main(){@autoreleasepool{
 PhotoService *(^service)(NSDictionary *)=^PhotoService *(NSDictionary *seed){return [[PhotoService alloc]initWithPath:@"" cached:seed?:@{} seed:@{}];};
 Mode=1;PhotoService *s=service(nil);__block NSDictionary *result=nil;
 [s entityDetails:@"Q20" role:@"person" progress:nil done:^(NSDictionary *m,NSString *error){Check(NSThread.isMainThread&&!error);result=m;}];s.paused=NO;Check(Until(^BOOL{return result!=nil;}));
 Check([result[@"biography"]hasPrefix:@"Verified biography"]);Check(![result[@"image"]length]);Check([result[@"imageFile"]isEqual:@"Portrait.jpg"]);Check([result[@"detailWarnings"]count]==1);double now=NSDate.date.timeIntervalSince1970;
 Check([result[@"expires"]doubleValue]-now>850&&[result[@"expires"]doubleValue]-now<=900);Check([result[@"detailsExpires"]doubleValue]-now<=900);
 NSUInteger before=Requests;[s entity:@"Q20" done:^(NSDictionary *m,NSString *e){Check(m&&!e);}];Check(Requests==before);[s invalidate];
 // A record written by140 may advertise a7day card expiry after photo failure.
 // An hour-old failure must retry; it must keep the verified biography/facts.
 NSMutableDictionary *legacy=[result mutableCopy];legacy[@"at"]=@(now-3600);[legacy removeObjectForKey:@"photoCheckedAt"];legacy[@"expires"]=@(now+6*86400);legacy[@"detailsExpires"]=@(now+6*86400);legacy[@"facts"]=@[@{@"label":@"Born",@"value":@"1982"}];
 for(NSNumber *details in @[@NO,@YES]){Mode=0;PhotoService *old=service(@{@"entities":@{@"Q20:person":legacy}});__block NSDictionary *fixed=nil;before=Requests;
  if(details.boolValue)[old entityDetails:@"Q20" role:@"person" progress:nil done:^(NSDictionary *m,NSString *e){fixed=m;}];else [old entity:@"Q20" done:^(NSDictionary *m,NSString *e){fixed=m;}];old.paused=NO;Check(Until(^BOOL{return fixed!=nil;}));Check(Requests>before);Check([fixed[@"image"]hasSuffix:@"portrait.jpg"]);Check([fixed[@"biography"]hasPrefix:@"Verified biography"]);Check([fixed[@"sourceURL"]hasPrefix:@"https://commons.wikimedia.org/"]);Check([fixed[@"credit"]containsString:@"CC BY 4.0"]);[old invalidate];
 }
 // Complete photo entries and explicitly absent photos keep normal caching.
 for(NSNumber *mode in @[@0,@2]){Mode=mode.unsignedIntegerValue;PhotoService *good=service(nil);__block NSDictionary *done=nil;[good entityDetails:@"Q20" role:@"person" progress:nil done:^(NSDictionary *m,NSString *e){done=m;}];good.paused=NO;Check(Until(^BOOL{return done!=nil;}));Check([done[@"expires"]doubleValue]-now>6*86400);before=Requests;[good entity:@"Q20" done:^(NSDictionary *m,NSString *e){Check(m&&!e);}];Check(Requests==before);[good invalidate];}
 // A failed URL cannot lock a verified portrait in the seven-day cache.
 BOOL supports=[PhotoService instancesRespondToSelector:@selector(entity:role:failedImage:done:)];Check(supports);
 if(supports){
  NSMutableDictionary *broken=[legacy mutableCopy];broken[@"image"]=@"https://upload.wikimedia.org/obsolete.jpg";broken[@"imageRole"]=@"portrait";broken[@"expires"]=@(now+86400);broken[@"detailsExpires"]=@(now+86400);
  Mode=0;PhotoService *repair=service(@{@"entities":@{@"Q20:person":broken}});__block NSDictionary *fixed=nil;before=Requests;
  [repair entity:@"Q20" role:@"person" failedImage:broken[@"image"] done:^(NSDictionary *m,NSString *e){Check(!e);fixed=m;}];repair.paused=NO;Check(Until(^BOOL{return fixed!=nil;}));Check(Requests>before);Check([fixed[@"image"]hasSuffix:@"portrait.jpg"]);Check([fixed[@"biography"]hasPrefix:@"Verified biography"]);Check([fixed[@"facts"]isEqual:broken[@"facts"]]);
  // A stale card reuses the repaired metadata; it cannot invalidate the new URL.
  before=Requests;fixed=nil;[repair entity:@"Q20" role:@"person" failedImage:broken[@"image"] done:^(NSDictionary *m,NSString *e){fixed=m;}];Check([fixed[@"image"]hasSuffix:@"portrait.jpg"]&&Requests==before);
  // Even a second failing image cannot cause an unbounded revalidation loop.
  fixed=nil;[repair entity:@"Q20" role:@"person" failedImage:@"https://upload.wikimedia.org/portrait.jpg" done:^(NSDictionary *m,NSString *e){Check(e.length>0);fixed=m;}];Check(Requests==before);[repair invalidate];
  // Concurrent card/header consumers must both receive the shared repair.
  Mode=0;repair=service(@{@"entities":@{@"Q20:person":broken}});__block NSUInteger deliveries=0,goodPhotos=0;before=Requests;
  for(int i=0;i<2;i++)[repair entity:@"Q20" role:@"person" failedImage:broken[@"image"] done:^(NSDictionary *m,NSString *e){deliveries++;if([m[@"image"]hasSuffix:@"portrait.jpg"]&&!e)goodPhotos++;}];repair.paused=NO;Check(Until(^BOOL{return deliveries==2;}));Check(goodPhotos==2);Check(Requests-before==2);[repair invalidate];
  // Failure keeps readable metadata, drops the known bad URL, and retries later.
  Mode=1;repair=service(@{@"entities":@{@"Q20:person":broken}});fixed=nil;[repair entity:@"Q20" role:@"person" failedImage:broken[@"image"] done:^(NSDictionary *m,NSString *e){fixed=m;}];repair.paused=NO;Check(Until(^BOOL{return fixed!=nil;}));Check(![fixed[@"image"]length]&&[fixed[@"biography"]hasPrefix:@"Verified biography"]);Check([fixed[@"expires"]doubleValue]-now<=901);before=Requests;
  [repair entity:@"Q20" role:@"person" failedImage:broken[@"image"] done:^(NSDictionary *m,NSString *e){Check(e.length>0);}];Check(Requests==before);NSDictionary *persisted=repair.entitySnapshot;[repair invalidate];
  repair=service(@{@"entities":persisted});before=Requests;[repair entity:@"Q20" role:@"person" failedImage:broken[@"image"] done:^(NSDictionary *m,NSString *e){Check(e.length>0);}];repair.paused=NO;Check(Requests==before);[repair invalidate];
  // Validate identity and input before touching a cached record or the network.
  repair=service(nil);before=Requests;for(NSString *bad in @[@"",@"Q0",@"nm123"])[repair entity:bad role:@"person" failedImage:broken[@"image"] done:^(NSDictionary *m,NSString *e){Check(!m&&e.length);}];Check(Requests==before);[repair invalidate];
 }
 printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
