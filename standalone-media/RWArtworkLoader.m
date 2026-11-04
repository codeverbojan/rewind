#import "RWArtworkLoader.h"
#import "RWArtworkDecode.h"
#import "RWArtworkPolicy.h"
#import <CommonCrypto/CommonDigest.h>
static const NSUInteger RWArtBytes=5*1024*1024, RWArtMemory=24*1024*1024, RWArtDisk=64*1024*1024;
static NSString *ArtHash(NSString *url){unsigned char hash[CC_SHA256_DIGEST_LENGTH];NSData *d=[url dataUsingEncoding:NSUTF8StringEncoding];CC_SHA256(d.bytes,(CC_LONG)d.length,hash);NSMutableString *s=[NSMutableString new];for(NSUInteger i=0;i<sizeof(hash);i++)[s appendFormat:@"%02x",hash[i]];return s;}
@interface RWArtRequest : NSObject
@property(nonatomic,copy) NSString *token;
@property(nonatomic,copy) NSArray *urls;
@property(nonatomic,copy) NSDictionary *spec;
@property(nonatomic,copy) void(^result)(NSDictionary *,BOOL);
@property(nonatomic,strong) NSDictionary *best;
@property(nonatomic,strong) NSDictionary *failure;
@property(nonatomic,assign) NSUInteger index;
@property(nonatomic,assign) double began;
@property(nonatomic,assign) double started;
@property(atomic,assign) BOOL cancelled;
@end
@implementation RWArtRequest
@end
@interface RWArtJob : NSObject
@property(nonatomic,copy) NSString *url;
@property(nonatomic,strong) NSMutableOrderedSet *tokens;
@property(nonatomic,strong) NSMutableData *data;
@property(nonatomic,strong) NSURLSessionDataTask *task;
@property(nonatomic,assign) NSInteger status;
@property(nonatomic,assign) BOOL oversized;
@end
@implementation RWArtJob
@end
@implementation RWArtworkLoader {
    dispatch_queue_t _work;NSOperationQueue *_delegates;NSURLSession *_session;
    NSString *_folder,*_resources;NSDictionary *_assets;
    NSMutableDictionary *_requests,*_jobs,*_decoded,*_disk,*_failures;
    NSMutableArray *_order;NSUInteger _memoryBytes,_diskBytes,_networkStarts,_peakJobs,_decodes,_cancelled,_coalesced,_memoryHits,_deliveries,_preemptions;
    BOOL _closed;
}
- (instancetype)initWithFolder:(NSString *)folder resources:(NSString *)resources configuration:(NSURLSessionConfiguration *)configuration {
    if((self=[super init])){_folder=[folder copy];_resources=[resources copy];_assets=@{};_requests=[NSMutableDictionary new];_jobs=[NSMutableDictionary new];_decoded=[NSMutableDictionary new];_disk=[NSMutableDictionary new];_failures=[NSMutableDictionary new];_order=[NSMutableArray new];
        _work=dispatch_queue_create("org.rewind.artwork",DISPATCH_QUEUE_SERIAL);_delegates=[NSOperationQueue new];_delegates.maxConcurrentOperationCount=1;_delegates.underlyingQueue=_work;
        NSURLSessionConfiguration *config=[configuration copy]?:[NSURLSessionConfiguration ephemeralSessionConfiguration];config.timeoutIntervalForRequest=7;config.timeoutIntervalForResource=10;config.HTTPMaximumConnectionsPerHost=2;config.URLCache=nil;config.requestCachePolicy=NSURLRequestReloadIgnoringLocalCacheData;
        _session=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:_delegates];
        dispatch_async(_work,^{[[NSFileManager defaultManager]createDirectoryAtPath:self->_folder withIntermediateDirectories:YES attributes:nil error:nil];
            for(NSString *name in [[NSFileManager defaultManager]contentsOfDirectoryAtPath:self->_folder error:nil]){if([name rangeOfString:@"^[0-9a-f]{64}$" options:NSRegularExpressionSearch].location!=0)continue;NSDictionary *a=[[NSFileManager defaultManager]attributesOfItemAtPath:[self->_folder stringByAppendingPathComponent:name] error:nil];if(![a[NSFileType]isEqual:NSFileTypeRegular])continue;NSUInteger bytes=[a[NSFileSize]unsignedIntegerValue];self->_disk[name]=@{@"bytes":@(bytes),@"at":@([a[NSFileModificationDate]timeIntervalSince1970])};self->_diskBytes+=bytes;}
            [self trimDiskFor:0];
        });
    }return self;
}
- (void)setBundledArtwork:(NSDictionary *)mapping {NSDictionary *copy=[mapping copy]?:@{};dispatch_async(_work,^{self->_assets=copy;});}
- (NSString *)loadURLs:(NSArray *)urls request:(NSDictionary *)spec result:(void(^)(NSDictionary *,BOOL))result {
    RWArtRequest *r=[RWArtRequest new];r.token=NSUUID.UUID.UUIDString;r.urls=[RWArtworkPolicy validURLs:urls];r.spec=[spec copy];r.result=result;r.began=NSProcessInfo.processInfo.systemUptime;
    dispatch_async(_work,^{if(self->_closed){[self deliver:r value:nil final:YES];return;}
        // A visible hero can displace the oldest queued thumbnail. Never allow
        // scrolling or an unhealthy provider to create an unbounded queue.
        if(self->_requests.count>=32){RWArtRequest *old=nil;for(RWArtRequest *v in self->_requests.allValues)if(![v.spec[@"role"]isEqual:@"hero"]&&(!old||v.began<old.began))old=v;if(old){[self finish:old];}else{[self deliver:r value:nil final:YES];return;}}
        self->_requests[r.token]=r;
        if([r.spec[@"role"]isEqual:@"hero"]){
            // Any already-decoded same-title image can paint a contained first
            // frame. It is provisional and never skips the ordered originals.
            for(NSDictionary *value in self->_decoded.allValues)if([r.urls containsObject:value[@"url"]]){NSMutableDictionary *preview=[value mutableCopy];NSDictionary *size=[RWArtworkPolicy sizing:r.spec sourceWidth:[value[@"decoded_width"]doubleValue] height:[value[@"decoded_height"]doubleValue]];if(!size)continue;[preview addEntriesFromDictionary:size];preview[@"source_width"]=value[@"source_width"];preview[@"source_height"]=value[@"source_height"];preview[@"cache"]=@"preview";if(!r.best||[preview[@"score"]doubleValue]>[r.best[@"score"]doubleValue])r.best=preview;}
            if(r.best)[self deliver:r value:r.best final:NO];
            if(self->_jobs.count==2){for(RWArtJob *job in self->_jobs.allValues){BOOL existingHero=NO;for(NSString *token in job.tokens){RWArtRequest *other=self->_requests[token];if([other.spec[@"role"]isEqual:@"hero"])existingHero=YES;}if(!existingHero&&![r.urls containsObject:job.url]){[job.task cancel];[self->_jobs removeObjectForKey:job.url];self->_preemptions++;break;}}}
        }
        [self pump];
    });return r.token;
}
- (void)trimDiskFor:(NSUInteger)incoming {
    if(_diskBytes+incoming<=RWArtDisk&&_disk.count<512)return;
    NSArray *old=[_disk.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a,NSString *b){return [self->_disk[a][@"at"]compare:self->_disk[b][@"at"]];}];
    for(NSString *key in old){if(_diskBytes+incoming<=RWArtDisk&&_disk.count<512)break;if([[NSFileManager defaultManager]removeItemAtPath:[_folder stringByAppendingPathComponent:key] error:nil]){_diskBytes-=[_disk[key][@"bytes"]unsignedIntegerValue];[_disk removeObjectForKey:key];}}
}
- (void)cache:(NSDictionary *)value key:(NSString *)key {
    NSUInteger cost=[value[@"decoded_bytes"]unsignedIntegerValue];if(!value||cost>RWArtMemory)return;
    _memoryBytes-=[_decoded[key][@"decoded_bytes"]unsignedIntegerValue];[_decoded removeObjectForKey:key];[_order removeObject:key];
    while(_order.count&&(_memoryBytes+cost>RWArtMemory||_order.count>=45)){NSString *old=_order[0];_memoryBytes-=[_decoded[old][@"decoded_bytes"]unsignedIntegerValue];[_decoded removeObjectForKey:old];[_order removeObjectAtIndex:0];}
    _decoded[key]=value;[_order addObject:key];_memoryBytes+=cost;
}
- (void)deliver:(RWArtRequest *)r value:(NSDictionary *)value final:(BOOL)final {
    NSMutableDictionary *result=[value mutableCopy]?:[NSMutableDictionary new];result[@"identity"]=r.spec[@"identity"]?:@"";result[@"role"]=r.spec[@"role"];result[@"target_width"]=r.spec[@"width"];result[@"target_height"]=r.spec[@"height"];result[@"point_width"]=r.spec[@"point_width"];result[@"point_height"]=r.spec[@"point_height"];result[@"screen_scale"]=r.spec[@"scale"];result[@"seconds"]=@(NSProcessInfo.processInfo.systemUptime-r.began);result[@"attempted_candidates"]=@(MIN(r.urls.count,r.index+1));result[@"last_failure"]=r.failure?:@{};result[@"final"]=@(final);result[@"queue_active"]=@(_jobs.count);result[@"memory_bytes"]=@(_memoryBytes);
    result[@"queue_wait_seconds"]=@(r.started?MAX(0,r.started-r.began):0);void(^callback)(NSDictionary *,BOOL)=r.result;if(!callback)return;_deliveries++;
    dispatch_async(dispatch_get_main_queue(),^{if(!r.cancelled)callback(result,final);});
}
- (void)detach:(RWArtRequest *)r {
    for(RWArtJob *job in [_jobs.allValues copy]){[job.tokens removeObject:r.token];if(!job.tokens.count){[job.task cancel];[_jobs removeObjectForKey:job.url];}}
}
- (void)finish:(RWArtRequest *)r {[self deliver:r value:r.best final:YES];[_requests removeObjectForKey:r.token];[self detach:r];}
- (void)accept:(NSDictionary *)value request:(RWArtRequest *)r bundledRemote:(BOOL)bundle {
    BOOL orderedOriginal=[value[@"sufficient"]boolValue]&&[r.best[@"cache"]isEqual:@"preview"];
    if(value&&(!r.best||orderedOriginal||[value[@"score"]doubleValue]>[r.best[@"score"]doubleValue]||([value[@"score"]doubleValue]==[r.best[@"score"]doubleValue]&&[r.best[@"cache"]isEqual:@"preview"]))){NSMutableDictionary *copy=[value mutableCopy];copy[@"upgraded"]=@(r.best!=nil);copy[@"candidate_index"]=@(r.index);r.best=copy;if(![value[@"sufficient"]boolValue])[self deliver:r value:r.best final:NO];}
    if([value[@"sufficient"]boolValue]){[self finish:r];return;}
    if(bundle)return; // Keep the provisional bundle image, then try its remote original.
    r.index++;if(r.index>=r.urls.count)[self finish:r];
}
- (void)pump {
    if(_closed)return;
    NSArray *pending=[_requests.allValues sortedArrayUsingComparator:^NSComparisonResult(RWArtRequest *a,RWArtRequest *b){BOOL ah=[a.spec[@"role"]isEqual:@"hero"],bh=[b.spec[@"role"]isEqual:@"hero"];if(ah!=bh)return ah?NSOrderedAscending:NSOrderedDescending;return a.began<b.began?NSOrderedAscending:a.began>b.began?NSOrderedDescending:NSOrderedSame;}];
    for(RWArtRequest *r in pending){if(!_requests[r.token])continue;BOOL joined=NO;for(RWArtJob *job in _jobs.allValues)if([job.tokens containsObject:r.token]){joined=YES;break;}if(joined)continue;
        if(r.index>=r.urls.count){[self finish:r];continue;}NSString *url=r.urls[r.index],*key=[RWArtworkPolicy variantKey:url request:r.spec];NSDictionary *cached=_decoded[key];
        if(cached){if(!r.started)r.started=NSProcessInfo.processInfo.systemUptime;_memoryHits++;[_order removeObject:key];[_order addObject:key];NSMutableDictionary *hit=[cached mutableCopy];hit[@"cache"]=@"memory";[self accept:hit request:r bundledRemote:NO];continue;}
        RWArtJob *job=_jobs[url];if(job){if(!r.started)r.started=NSProcessInfo.processInfo.systemUptime;[job.tokens addObject:r.token];_coalesced++;continue;}if(_jobs.count>=2)continue;if(!r.started)r.started=NSProcessInfo.processInfo.systemUptime;
        job=[RWArtJob new];job.url=url;job.tokens=[NSMutableOrderedSet orderedSetWithObject:r.token];_jobs[url]=job;_peakJobs=MAX(_peakJobs,_jobs.count);[self start:job];
    }
    // Completed cached fallbacks may expose another candidate. Schedule a new
    // iteration rather than recurse through a whole offline grid in one stack.
    BOOL idle=NO;for(RWArtRequest *r in _requests.allValues){BOOL joined=NO;for(RWArtJob *j in _jobs.allValues)if([j.tokens containsObject:r.token])joined=YES;if(!joined){idle=YES;break;}}
    if(idle&&_jobs.count<2)dispatch_async(_work,^{[self pump];});
}
- (void)consume:(NSData *)data job:(RWArtJob *)job origin:(NSString *)origin bundledRemote:(BOOL)bundle {
    for(NSString *token in [job.tokens.array copy]){RWArtRequest *r=_requests[token];if(!r)continue;NSString *key=[RWArtworkPolicy variantKey:job.url request:r.spec];NSDictionary *value=_decoded[key];if(!value){_decodes++;NSMutableDictionary *decoded=[[RWArtworkDecode decode:data request:r.spec]mutableCopy];if(decoded){decoded[@"url"]=job.url;decoded[@"cache"]=origin;value=decoded;if(!bundle||[decoded[@"sufficient"]boolValue])[self cache:decoded key:key];}}
        [self accept:value request:r bundledRemote:bundle];if(!bundle)[job.tokens removeObject:token];
    }
}
- (NSData *)boundedRead:(NSString *)path {NSDictionary *attrs=[[NSFileManager defaultManager]attributesOfItemAtPath:path error:nil];if(![attrs[NSFileType]isEqual:NSFileTypeRegular]||[attrs[NSFileSize]unsignedLongLongValue]>RWArtBytes)return nil;return [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];}
- (BOOL)verifyAndCache:(NSData *)data job:(RWArtJob *)job origin:(NSString *)origin {
    RWArtRequest *first=_requests[job.tokens.firstObject];if(!first)return NO;
    _decodes++;NSMutableDictionary *value=[[RWArtworkDecode decode:data request:first.spec]mutableCopy];if(!value)return NO;
    value[@"url"]=job.url;value[@"cache"]=origin;[self cache:value key:[RWArtworkPolicy variantKey:job.url request:first.spec]];return YES;
}
- (void)start:(RWArtJob *)job {
    NSDictionary *failed=_failures[job.url];if([failed[@"until"]doubleValue]>NSProcessInfo.processInfo.systemUptime){for(NSString *token in job.tokens){RWArtRequest *r=_requests[token];r.failure=failed[@"details"];}[self consume:nil job:job origin:@"cooldown" bundledRemote:NO];[_jobs removeObjectForKey:job.url];return;}
    BOOL asset=[job.url hasPrefix:@"asset:"];NSString *key=ArtHash(job.url),*file=[_folder stringByAppendingPathComponent:key];NSData *disk=asset?nil:[self boundedRead:file];
    if(disk&&[self verifyAndCache:disk job:job origin:@"disk"]){[self consume:disk job:job origin:@"disk" bundledRemote:NO];[_jobs removeObjectForKey:job.url];return;}
    if(disk&&[[NSFileManager defaultManager]removeItemAtPath:file error:nil]){_diskBytes-=[_disk[key][@"bytes"]unsignedIntegerValue];[_disk removeObjectForKey:key];}
    NSString *alias=asset?[job.url substringFromIndex:6]:_assets[job.url];
    if(!alias&&!asset){NSURLComponents *parts=[NSURLComponents componentsWithString:job.url];parts.query=nil;alias=_assets[parts.URL.absoluteString];}
    if(alias.length&&[RWArtworkPolicy validURLs:@[[@"asset:" stringByAppendingString:alias]]].count){NSData *bundled=[self boundedRead:[_resources stringByAppendingPathComponent:alias]];[self consume:bundled job:job origin:@"bundle" bundledRemote:!asset];}
    if(asset||!job.tokens.count){[_jobs removeObjectForKey:job.url];return;}
    [self startNetwork:job];
}
- (void)startNetwork:(RWArtJob *)job {
    if(!job.tokens.count)return;NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:job.url]];[request setValue:@"image/jpeg,image/png;q=0.9,*/*;q=0.1" forHTTPHeaderField:@"Accept"];
    job.data=[NSMutableData new];job.task=[_session dataTaskWithRequest:request];job.task.taskDescription=job.url;BOOL hero=NO;for(NSString *token in job.tokens){RWArtRequest *r=_requests[token];if([r.spec[@"role"]isEqual:@"hero"])hero=YES;}job.task.priority=hero?NSURLSessionTaskPriorityHigh:NSURLSessionTaskPriorityLow;_networkStarts++;[job.task resume];
}
- (RWArtJob *)jobForTask:(NSURLSessionTask *)task {RWArtJob *job=_jobs[task.taskDescription];return job.task==task?job:nil;}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void(^)(NSURLSessionResponseDisposition))completionHandler {
    RWArtJob *job=[self jobForTask:task];job.status=[response isKindOfClass:NSHTTPURLResponse.class]?[(NSHTTPURLResponse *)response statusCode]:0;job.oversized=response.expectedContentLength>(long long)RWArtBytes;
    completionHandler(job&&job.status==200&&!job.oversized?NSURLSessionResponseAllow:NSURLSessionResponseCancel);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    RWArtJob *job=[self jobForTask:task];if(!job)return;if(data.length>RWArtBytes-job.data.length){job.oversized=YES;job.data=nil;[task cancel];return;}[job.data appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    RWArtJob *job=[self jobForTask:task];if(!job)return;NSData *data=!error&&job.status==200&&!job.oversized?[job.data copy]:nil;job.data=nil;
    BOOL valid=NO;if(data.length){NSString *key=ArtHash(job.url),*path=[_folder stringByAppendingPathComponent:key];
        // Verify an image before committing compressed bytes to the disk cache.
        valid=[self verifyAndCache:data job:job origin:@"network"];if(valid){[self trimDiskFor:data.length];if(_diskBytes+data.length<=RWArtDisk&&[data writeToFile:path atomically:YES]){_diskBytes-=[_disk[key][@"bytes"]unsignedIntegerValue];_disk[key]=@{@"bytes":@(data.length),@"at":@(NSDate.date.timeIntervalSince1970)};_diskBytes+=data.length;}}
    }
    if(!valid){NSDictionary *failure=@{@"host":[NSURL URLWithString:job.url].host?:@"",@"http":@(job.status),@"error":@(error.code),@"domain":error.domain?:@"",@"bytes":@(data.length),@"oversized":@(job.oversized),@"decode_failed":@(!error&&job.status==200&&!job.oversized)};for(NSString *token in job.tokens){RWArtRequest *r=_requests[token];r.failure=failure;}if(_failures.count>=64)[_failures removeObjectForKey:_failures.allKeys.firstObject];_failures[job.url]=@{@"until":@(NSProcessInfo.processInfo.systemUptime+30),@"details":failure};}else [_failures removeObjectForKey:job.url];
    [self consume:data job:job origin:@"network" bundledRemote:NO];if(_jobs[job.url]==job)[_jobs removeObjectForKey:job.url];[self pump];
}
- (void)cancel:(NSString *)token {if(!token.length)return;dispatch_async(_work,^{RWArtRequest *r=self->_requests[token];if(r){r.cancelled=YES;self->_cancelled++;[self->_requests removeObjectForKey:token];[self detach:r];}[self pump];});}
- (void)clearMemory {dispatch_async(_work,^{for(RWArtRequest *r in self->_requests.allValues)r.cancelled=YES;[self->_requests removeAllObjects];for(RWArtJob *j in self->_jobs.allValues)[j.task cancel];[self->_jobs removeAllObjects];[self->_decoded removeAllObjects];[self->_order removeAllObjects];self->_memoryBytes=0;});}
- (void)diagnostics:(void(^)(NSDictionary *))done {dispatch_async(_work,^{NSDictionary *value=@{@"active":@(self->_jobs.count),@"queued":@(self->_requests.count),@"peak_active":@(self->_peakJobs),@"network_starts":@(self->_networkStarts),@"coalesced":@(self->_coalesced),@"decodes":@(self->_decodes),@"cancelled":@(self->_cancelled),@"hero_preemptions":@(self->_preemptions),@"memory_hits":@(self->_memoryHits),@"decoded_bytes":@(self->_memoryBytes),@"disk_bytes":@(self->_diskBytes),@"decoded_entries":@(self->_decoded.count),@"disk_entries":@(self->_disk.count),@"failure_entries":@(self->_failures.count),@"worker_off_main":@(!NSThread.isMainThread)};dispatch_async(dispatch_get_main_queue(),^{if(done)done(value);});});}
- (void)close {[self clearMemory];dispatch_async(_work,^{self->_closed=YES;[self->_session invalidateAndCancel];self->_session=nil;});}
@end
