#import "RWPreviewTrace.h"
@implementation RWPreviewTrace {
    NSLock *_lock;NSMutableArray *_first,*_recent,*_errors;NSUInteger _messages,_dropped;double _began;
}
- (instancetype)init {if((self=[super init])){_lock=[NSLock new];_first=[NSMutableArray new];_recent=[NSMutableArray new];_errors=[NSMutableArray new];_began=NSProcessInfo.processInfo.systemUptime;}return self;}
- (void)record:(const char *)message module:(const char *)module level:(int)level {
    double elapsed=NSProcessInfo.processInfo.systemUptime-_began;
    // Keep the callback cheap and bounded even if a decoder is noisy or the
    // preview continues playing for minutes. Errors share the same hard limit.
    [_lock lock];BOOL drop=elapsed>10||_messages>=4096;_messages++;if(drop)_dropped++;[_lock unlock];if(drop)return;
    @autoreleasepool {
        NSString *text=[[NSString alloc]initWithBytes:message length:strnlen(message,768) encoding:NSUTF8StringEncoding]?:@"[non-UTF8 decoder message]";
        static NSRegularExpression *paths,*headers;static dispatch_once_t once;dispatch_once(&once,^{
            paths=[NSRegularExpression regularExpressionWithPattern:@"(?i)(?:[a-z][a-z0-9+.-]*://|/)[^\\s\\\"'<>]*" options:0 error:nil];
            headers=[NSRegularExpression regularExpressionWithPattern:@"(?i)(?:authorization|cookie|token|signature|credential|password)\\s*[:=]" options:0 error:nil];
        });
        if([headers firstMatchInString:text options:0 range:NSMakeRange(0,text.length)])text=@"[redacted credential-bearing message]";
        else text=[paths stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0,text.length) withTemplate:@"[location]"];
        if(text.length>240)text=[[text substringToIndex:240]stringByAppendingString:@"…"];
        NSString *name=module?[[NSString alloc]initWithBytes:module length:strnlen(module,48) encoding:NSUTF8StringEncoding]:nil;
        NSDictionary *entry=@{@"seconds":@(elapsed),@"level":@(level),@"module":name?:@"unknown",@"message":text};
        [_lock lock];
        if(_first.count<16)[_first addObject:entry];else{[_recent addObject:entry];if(_recent.count>48)[_recent removeObjectAtIndex:0];}
        if(level>=3){[_errors addObject:entry];if(_errors.count>16)[_errors removeObjectAtIndex:0];}
        [_lock unlock];
    }
}
- (NSDictionary *)snapshot {[_lock lock];NSDictionary *value=@{@"first":[_first copy],@"recent":[_recent copy],@"warnings_errors":[_errors copy],@"messages":@(_messages),@"dropped":@(_dropped)};[_lock unlock];return value;}
@end
