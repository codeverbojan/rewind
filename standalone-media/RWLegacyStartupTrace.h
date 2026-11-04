#import <Foundation/Foundation.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <pthread.h>

static BOOL RWStartupModuleType(const char *type) {
    if(!type)return NO;
    const char *allowed[]={"decoder","video decoder","audio decoder","spu decoder","video output","vout display","text renderer","video converter","audio converter","audio filter","audio resampler","audio output","demux","stream_filter"};
    for(size_t i=0;i<sizeof(allowed)/sizeof(*allowed);i++)if(!strcmp(type,allowed[i]))return YES;
    return NO;
}
static NSNumber *RWStartupThread(void) {uint64_t tid=0;pthread_threadid_np(NULL,&tid);return @(tid);}

// Diagnostic-only, per-player evidence. No URLs, filenames, track names or
// arbitrary decoder log messages are retained. No VLC calls under this lock.
@interface RWLegacyStartupTrace : NSObject
- (instancetype)initAt:(double)began;
- (void)event:(NSString *)name at:(double)at values:(NSDictionary *)values;
- (void)log:(const char *)format arguments:(va_list)args at:(double)at;
- (void)readBytes:(NSInteger)bytes seconds:(double)seconds at:(double)at;
- (void)sample:(NSDictionary *)sample at:(double)at;
- (NSDictionary *)snapshot;
- (void)cancel;
@end
@implementation RWLegacyStartupTrace {
    double _began,_lastSample,_readSeconds,_maxReadSeconds;
    NSUInteger _dropped,_reads,_bytes;BOOL _cancelled;
    NSMutableArray *_events,*_samples;
}
- (instancetype)initAt:(double)began {if((self=[super init])){_began=began;_lastSample=-1;_events=[NSMutableArray new];_samples=[NSMutableArray new];}return self;}
- (BOOL)accept:(double)at {return !_cancelled&&isfinite(at)&&at>=_began&&at-_began<=20;}
- (void)event:(NSString *)name at:(double)at values:(NSDictionary *)values {
    @synchronized(self){if(![self accept:at]||name.length>40)return;if(_events.count>=96){_dropped++;return;}
        [_events addObject:@{@"event":name,@"seconds":@(at-_began),@"values":[values copy]?:@{}}];}
}
- (void)log:(const char *)format arguments:(va_list)args at:(double)at {
    if(!format)return;NSString *kind=nil;
    if(!strcmp(format,"Stream buffering done (%d ms in %d ms)"))kind=@"stream_buffered";
    else if(!strcmp(format,"Decoder wait done in %d ms"))kind=@"decoder_wait_done";
    else if(!strcmp(format,"Buffering %d%%")){
        va_list copy;va_copy(copy,args);int percent=va_arg(copy,int);va_end(copy);
        if(percent!=0&&percent!=25&&percent!=50&&percent!=75&&percent!=100)return;
        [self event:@"buffering" at:at values:@{@"percent":@(percent)}];return;
    }
    else if(!strcmp(format,"ES_OUT_RESET_PCR called"))kind=@"clock_reset";
    else if(!strcmp(format,"waiting decoder fifos to empty"))kind=@"decoder_drain";
    else if(!strcmp(format,"Received first picture"))kind=@"first_picture";
    else if(!strcmp(format,"looking for %s module matching \"%s\": %zd candidates")){
        va_list copy;va_copy(copy,args);const char *type=va_arg(copy,const char *);(void)va_arg(copy,const char *);ssize_t count=va_arg(copy,ssize_t);va_end(copy);
        if(!RWStartupModuleType(type)||count<0||count>4096)return;
        // The requested match string is intentionally neither dereferenced nor saved.
        [self event:@"module_begin" at:at values:@{@"type":@(type),@"candidates":@(count),@"thread":RWStartupThread()}];return;
    }
    else if(!strcmp(format,"no %s modules matched")||!strcmp(format,"no %s modules")){
        va_list copy;va_copy(copy,args);const char *type=va_arg(copy,const char *);va_end(copy);
        if(!RWStartupModuleType(type))return;
        [self event:@"module_unavailable" at:at values:@{@"type":@(type),@"thread":RWStartupThread()}];return;
    }
    else if(!strcmp(format,"using %s module \"%s\"")){
        va_list copy;va_copy(copy,args);const char *type=va_arg(copy,const char *),*module=va_arg(copy,const char *);va_end(copy);
        if(!type||!module||strlen(module)>48||strspn(module,"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- ")!=strlen(module))return;
        if(!RWStartupModuleType(type))return;
        [self event:@"module_selected" at:at values:@{@"type":@(type),@"module":@(module),@"thread":RWStartupThread()}];return;
    }
    else return;
    char message[128]={};va_list copy;va_copy(copy,args);vsnprintf(message,sizeof(message),format,copy);va_end(copy);
    [self event:kind at:at values:@{@"message":@(message)}];
}
- (void)readBytes:(NSInteger)bytes seconds:(double)seconds at:(double)at {
    @synchronized(self){if(![self accept:at]||!isfinite(seconds)||seconds<0)return;
        _reads++;if(bytes>0)_bytes+=(NSUInteger)bytes;_readSeconds+=seconds;_maxReadSeconds=MAX(_maxReadSeconds,seconds);
        if(_reads==1||seconds>=.1)[self event:@"input_read" at:at values:@{@"bytes":@(bytes),@"duration_seconds":@(seconds)}];}
}
- (void)sample:(NSDictionary *)sample at:(double)at {
    @synchronized(self){if(![self accept:at]||_samples.count>=48||(_lastSample>=0&&at-_lastSample<.25))return;_lastSample=at;
        [_samples addObject:@{@"seconds":@(at-_began),@"values":[sample copy]}];}
}
- (NSDictionary *)snapshot {@synchronized(self){return @{@"events":[_events copy],@"samples":[_samples copy],@"dropped":@(_dropped),@"cancelled":@(_cancelled),@"read_calls":@(_reads),@"read_bytes":@(_bytes),@"read_seconds_sum":@(_readSeconds),@"read_seconds_max":@(_maxReadSeconds),@"window_seconds":@20,@"event_limit":@96,@"sample_limit":@48};}}
- (void)cancel {@synchronized(self){_cancelled=YES;}}
@end
