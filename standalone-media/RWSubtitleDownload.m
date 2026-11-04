#import "RWSubtitleDownload.h"
static const NSUInteger SubtitleLimit=2*1024*1024;
static BOOL HTTP(NSURL *url){return [@[@"http",@"https"]containsObject:url.scheme.lowercaseString]&&url.host.length;}
@interface RWSubtitleDownload () <NSURLSessionDataDelegate>
@property(atomic) BOOL cancelled;
@end
@implementation RWSubtitleDownload {
    NSURLSession *_session;NSURLSessionDataTask *_task;NSOperationQueue *_queue;
    NSMutableData *_bytes;BOOL _finished;NSUInteger _peak,_redirects;NSInteger _status;
    double _started;void(^_completion)(NSData *,NSString *,NSDictionary *);
}
- (instancetype)initWithURL:(NSURL *)url completion:(void(^)(NSData *,NSString *,NSDictionary *))completion {
    return [self initWithURL:url configuration:NSURLSessionConfiguration.ephemeralSessionConfiguration completion:completion];
}
- (instancetype)initWithURL:(NSURL *)url configuration:(NSURLSessionConfiguration *)configuration completion:(void(^)(NSData *,NSString *,NSDictionary *))completion {
    if((self=[super init])){
        _started=NSProcessInfo.processInfo.systemUptime;_completion=[completion copy];_bytes=[NSMutableData new];
        _queue=[NSOperationQueue new];_queue.maxConcurrentOperationCount=1;
        if(!HTTP(url)){[_queue addOperationWithBlock:^{[self finish:@"Use an HTTP or HTTPS subtitle address."];}];return self;}
        NSURLSessionConfiguration *config=[configuration copy];config.timeoutIntervalForRequest=10;config.timeoutIntervalForResource=20;config.URLCache=nil;config.HTTPCookieStorage=nil;config.URLCredentialStorage=nil;config.HTTPMaximumConnectionsPerHost=1;
        _session=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:_queue];
        NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:10];
        [request setValue:@"text/vtt,application/x-subrip,text/plain,*/*;q=0.5" forHTTPHeaderField:@"Accept"];
        _task=[_session dataTaskWithRequest:request];[_task resume];
    }return self;
}
- (void)finish:(NSString *)error {
    if(_finished)return;_finished=YES;[_task cancel];[_session invalidateAndCancel];
    NSData *data=error?nil:[_bytes copy];NSUInteger bytes=_bytes.length;_bytes=nil;
    NSDictionary *metrics=@{@"bytes":@(bytes),@"peak_buffer_bytes":@(_peak),@"limit_bytes":@(SubtitleLimit),@"http_status":@(_status),@"redirects":@(_redirects),@"seconds":@(NSProcessInfo.processInfo.systemUptime-_started),@"ok":@(error==nil)};
    void(^done)(NSData *,NSString *,NSDictionary *)=_completion;_completion=nil;
    dispatch_async(dispatch_get_main_queue(),^{if(!self.cancelled&&done)done(data,error,metrics);});
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void(^)(NSURLRequest *))done {
    if(self.cancelled||_finished){done(nil);return;}
    if(!HTTP(request.URL)||++_redirects>3){done(nil);[self finish:@"The subtitle address redirected too many times or to an unsupported address."];return;}
    done(request);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void(^)(NSURLSessionResponseDisposition))done {
    if(self.cancelled||_finished){done(NSURLSessionResponseCancel);return;}
    NSHTTPURLResponse *http=[response isKindOfClass:NSHTTPURLResponse.class]?(id)response:nil;_status=http.statusCode;
    NSString *error=nil;
    if(!http||_status!=200||!HTTP(response.URL))error=@"The subtitle file could not be downloaded.";
    else if(response.expectedContentLength>(long long)SubtitleLimit)error=@"This subtitle file is larger than 2 MB.";
    else if([response.MIMEType.lowercaseString containsString:@"text/html"]||[response.MIMEType.lowercaseString hasPrefix:@"multipart/"])error=@"This address returned a webpage instead of subtitles.";
    done(error?NSURLSessionResponseCancel:NSURLSessionResponseAllow);if(error)[self finish:error];
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if(self.cancelled||_finished)return;
    // Check decoded chunks before appending: also bounds chunked/gzip responses
    // without a trustworthy Content-Length header.
    if(data.length>SubtitleLimit-_bytes.length){[self finish:@"This subtitle file is larger than 2 MB."];return;}
    [_bytes appendData:data];_peak=MAX(_peak,_bytes.length);
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if(self.cancelled||_finished)return;
    [self finish:error?(error.code==NSURLErrorTimedOut?@"The subtitle download timed out. Try again or choose another file.":@"The subtitle file could not be downloaded."):nil];
}
- (void)cancel {
    self.cancelled=YES;[_task cancel];[_session invalidateAndCancel];
    [_queue addOperationWithBlock:^{self->_finished=YES;self->_completion=nil;self->_bytes=nil;}];
}
@end
