#import "RWRemoteMKVProbe.h"
#import "RWMKVProbe.h"
@interface RWRemoteMKVProbe () <NSURLSessionDataDelegate>
@property(atomic) BOOL cancelled;
@end
@implementation RWRemoteMKVProbe {
    NSURLSession *_session;NSURLSessionDataTask *_task;NSOperationQueue *_queue;
    NSMutableData *_bytes;NSURL *_resolved;BOOL _finished;
    void(^_completion)(NSDictionary *,NSURL *,NSString *);
}
- (instancetype)initWithURL:(NSURL *)url completion:(void(^)(NSDictionary *,NSURL *,NSString *))completion {
    return [self initWithURL:url configuration:NSURLSessionConfiguration.ephemeralSessionConfiguration completion:completion];
}
- (instancetype)initWithURL:(NSURL *)url configuration:(NSURLSessionConfiguration *)configuration completion:(void(^)(NSDictionary *,NSURL *,NSString *))completion {
    if((self=[super init])){
        _bytes=[NSMutableData new];_resolved=url;_completion=[completion copy];_queue=[NSOperationQueue new];_queue.maxConcurrentOperationCount=1;
        configuration.timeoutIntervalForRequest=6;configuration.timeoutIntervalForResource=10;configuration.URLCache=nil;
        _session=[NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:_queue];
        NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:6];
        [request setValue:@"bytes=0-2097151" forHTTPHeaderField:@"Range"];[request setValue:@"identity" forHTTPHeaderField:@"Accept-Encoding"];
        _task=[_session dataTaskWithRequest:request];[_task resume];
    }return self;
}
- (void)finish:(NSDictionary *)media error:(NSString *)error {
    if(_finished)return;_finished=YES;[_task cancel];[_session invalidateAndCancel];_bytes=nil;
    void(^done)(NSDictionary *,NSURL *,NSString *)=_completion;_completion=nil;NSURL *resolved=_resolved;
    dispatch_async(dispatch_get_main_queue(),^{if(!self.cancelled&&done)done(media,resolved,error);});
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))done {
    NSHTTPURLResponse *http=[response isKindOfClass:NSHTTPURLResponse.class]?(id)response:nil;
    BOOL valid=http&&(http.statusCode==200||http.statusCode==206);
    if(valid&&http.statusCode==206){NSString *range=nil;for(id key in http.allHeaderFields)if([[key description]caseInsensitiveCompare:@"Content-Range"]==NSOrderedSame)range=[http.allHeaderFields[key]description];
        NSRegularExpression *pattern=[NSRegularExpression regularExpressionWithPattern:@"^bytes 0-[0-9]+/(?:[0-9]+|\\*)$" options:NSRegularExpressionCaseInsensitive error:nil];
        valid=range&&[pattern firstMatchInString:range options:0 range:NSMakeRange(0,range.length)]!=nil;
    }
    NSString *mime=response.MIMEType.lowercaseString;if([mime containsString:@"text/html"]||[mime containsString:@"json"])valid=NO;
    if(self.cancelled||_finished||!valid){done(NSURLSessionResponseCancel);if(!self.cancelled)[self finish:nil error:http.statusCode==401||http.statusCode==403?@"This stream address has expired or requires access.":@"This address did not return a usable video header."];return;}
    _resolved=response.URL;done(NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if(_finished||self.cancelled)return;NSUInteger remaining=2*1024*1024-_bytes.length;
    [_bytes appendBytes:data.bytes length:MIN(remaining,data.length)];
    NSDictionary *media=[RWMKVProbe media:_bytes];
    if(media)[self finish:media error:nil];
    else if(_bytes.length>=2*1024*1024)[self finish:nil error:@"This stream's video header exceeds the inspection limit."];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if(_finished||self.cancelled)return;[self finish:nil error:error?@"The stream header could not be loaded. Try a fresh source.":@"This stream did not contain a supported MKV header."];
}
- (void)cancel {self.cancelled=YES;[_task cancel];[_session invalidateAndCancel];[_queue addOperationWithBlock:^{self->_completion=nil;self->_bytes=nil;}];}
@end
