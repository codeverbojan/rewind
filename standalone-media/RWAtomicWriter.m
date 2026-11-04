#import "RWAtomicWriter.h"
#import <math.h>
#import <objc/runtime.h>

// Only immutableJSON: can attach this private provenance marker. No global
// cache retains metadata, and mutableCopy never inherits ownership. The stored
// tree height preserves the depth limit when an owned graph is nested later.
static char RWOwnedJSONHeight;

// Capture JSON containers by value on their owning thread. Core Foundation
// avoids per-element Objective-C enumeration/build/copy churn on ARMv7. The
// identity map is local to one capture; it never treats a mutable live object
// as immutable across saves. Completed aliases share the same owned snapshot.
typedef struct {CFTypeID string,number,boolean,nullValue,array,dictionary;} RWJSONTypes;
static CFTypeRef CaptureJSON(CFTypeRef value, CFMutableDictionaryRef copies, const RWJSONTypes *types, NSUInteger depth) {
    if(!value||depth>128)return NULL;CFTypeID type=CFGetTypeID(value);
    if(type==types->string)return CFStringCreateCopy(kCFAllocatorDefault,(CFStringRef)value);
    if(type==types->number){double n=0;CFNumberGetValue((CFNumberRef)value,kCFNumberDoubleType,&n);return isfinite(n)?CFRetain(value):NULL;}
    if(type==types->boolean||type==types->nullValue)return CFRetain(value);
    if(type==types->dictionary||type==types->array){NSNumber *height=objc_getAssociatedObject((__bridge id)value,&RWOwnedJSONHeight);if(height)return depth+height.unsignedIntegerValue<=128?CFRetain(value):NULL;}
    CFTypeRef previous=CFDictionaryGetValue(copies,value);if(previous)return CFRetain(previous);
    CFTypeRef captured=NULL;
    if(type==types->dictionary){
        CFDictionaryRef dictionary=(CFDictionaryRef)value;CFIndex count=CFDictionaryGetCount(dictionary);
        const void *local[64];const void **storage=count<=16?local:(const void **)calloc((size_t)count*4,sizeof(void *));if(!storage)return NULL;
        const void **keys=storage,**values=storage+count,**ownedKeys=storage+count*2,**ownedValues=storage+count*3;
        CFDictionaryGetKeysAndValues(dictionary,keys,values);CFIndex completed=0;
        for(;completed<count;completed++){
            if(CFGetTypeID(keys[completed])!=types->string)break;
            CFTypeRef child=CaptureJSON(values[completed],copies,types,depth+1);if(!child)break;
            ownedKeys[completed]=CFStringCreateCopy(kCFAllocatorDefault,(CFStringRef)keys[completed]);ownedValues[completed]=child;
        }
        if(completed==count)captured=CFDictionaryCreate(kCFAllocatorDefault,ownedKeys,ownedValues,count,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
        for(CFIndex i=0;i<completed;i++){CFRelease(ownedKeys[i]);CFRelease(ownedValues[i]);}if(storage!=local)free(storage);
    }else if(type==types->array){
        CFArrayRef array=(CFArrayRef)value;CFIndex count=CFArrayGetCount(array);
        const void *local[32];const void **values=count<=32?local:(const void **)calloc((size_t)count,sizeof(void *));if(!values)return NULL;CFIndex completed=0;
        for(;completed<count;completed++){values[completed]=CaptureJSON(CFArrayGetValueAtIndex(array,completed),copies,types,depth+1);if(!values[completed])break;}
        if(completed==count)captured=CFArrayCreate(kCFAllocatorDefault,values,count,&kCFTypeArrayCallBacks);
        for(CFIndex i=0;i<completed;i++)CFRelease(values[i]);if(values!=local)free(values);
    }
    if(captured)CFDictionarySetValue(copies,value,captured);return captured;
}

static NSUInteger JSONHeight(CFTypeRef value,CFMutableDictionaryRef heights,const RWJSONTypes *types) {
    CFTypeID type=CFGetTypeID(value);if(type!=types->dictionary&&type!=types->array)return 0;
    const void *cached=CFDictionaryGetValue(heights,value);if(cached)return (NSUInteger)(uintptr_t)cached-1;
    NSUInteger height=0;
    if(type==types->array){CFIndex count=CFArrayGetCount((CFArrayRef)value);for(CFIndex i=0;i<count;i++)height=MAX(height,1+JSONHeight(CFArrayGetValueAtIndex((CFArrayRef)value,i),heights,types));}
    else{CFDictionaryRef dictionary=(CFDictionaryRef)value;CFIndex count=CFDictionaryGetCount(dictionary);const void *local[32];const void **values=count<=32?local:(const void **)calloc((size_t)count,sizeof(void *));if(!values)return 129;CFDictionaryGetKeysAndValues(dictionary,NULL,values);for(CFIndex i=0;i<count;i++)height=MAX(height,1+JSONHeight(values[i],heights,types));if(values!=local)free(values);}
    CFDictionarySetValue(heights,value,(const void *)(uintptr_t)(height+1));return height;
}

@interface RWAtomicWrite : NSObject
@property(nonatomic,strong) NSData *data;
@property(nonatomic,strong) id json;
@end
@implementation RWAtomicWrite
@end

@implementation RWAtomicWriter {
    dispatch_queue_t _queue;
    NSMutableDictionary *_pending;
    NSMutableArray *_completions;
    NSLock *_lock;
    BOOL _writing;
    NSUInteger _submitted,_coalesced,_written,_failed,_encodes,_mainEncodes,_pendingPeak;
    double _encodeSeconds,_encodeMax;
}
+ (instancetype)shared {static RWAtomicWriter *writer;static dispatch_once_t once;dispatch_once(&once,^{writer=[self new];});return writer;}
+ (BOOL)isOwnedJSON:(id)object {return object&&objc_getAssociatedObject(object,&RWOwnedJSONHeight)!=nil;}
+ (id)immutableJSON:(id)object {
    if(![object isKindOfClass:NSDictionary.class]&&![object isKindOfClass:NSArray.class])return nil;
    if([self isOwnedJSON:object])return object;
    CFMutableDictionaryRef copies=CFDictionaryCreateMutable(kCFAllocatorDefault,0,NULL,&kCFTypeDictionaryValueCallBacks);
    RWJSONTypes types={CFStringGetTypeID(),CFNumberGetTypeID(),CFBooleanGetTypeID(),CFNullGetTypeID(),CFArrayGetTypeID(),CFDictionaryGetTypeID()};
    id owned=CFBridgingRelease(CaptureJSON((__bridge CFTypeRef)object,copies,&types,0));CFRelease(copies);if(!owned)return nil;
    CFMutableDictionaryRef heights=CFDictionaryCreateMutable(kCFAllocatorDefault,0,NULL,NULL);
    NSUInteger height=JSONHeight((__bridge CFTypeRef)owned,heights,&types);CFRelease(heights);if(height>128)return nil;
    objc_setAssociatedObject(owned,&RWOwnedJSONHeight,@(height),OBJC_ASSOCIATION_RETAIN_NONATOMIC);return owned;
}
- (instancetype)init {if((self=[super init])){_queue=dispatch_queue_create("org.local.rewind.files",DISPATCH_QUEUE_SERIAL);_pending=[NSMutableDictionary new];_completions=[NSMutableArray new];_lock=[NSLock new];}return self;}
- (void)write:(NSData *)data path:(NSString *)path {
    if(!data||!path.length)return;
    // Capture mutable caller input before returning. Only bookkeeping is locked;
    // JSON encoding and disk I/O never hold up the main thread through this lock.
    RWAtomicWrite *job=[RWAtomicWrite new];job.data=[data copy];[self submit:job path:path];
}
- (BOOL)writeJSON:(id)object path:(NSString *)path {
    if(!path.length||(![object isKindOfClass:NSDictionary.class]&&![object isKindOfClass:NSArray.class]))return NO;
    // Raw pointer keys are safe for this synchronous call: the caller owns the
    // entire input graph until capture returns. Only snapshot values are retained.
    CFMutableDictionaryRef copies=CFDictionaryCreateMutable(kCFAllocatorDefault,0,NULL,&kCFTypeDictionaryValueCallBacks);
    RWJSONTypes types={CFStringGetTypeID(),CFNumberGetTypeID(),CFBooleanGetTypeID(),CFNullGetTypeID(),CFArrayGetTypeID(),CFDictionaryGetTypeID()};
    id snapshot=CFBridgingRelease(CaptureJSON((__bridge CFTypeRef)object,copies,&types,0));CFRelease(copies);if(!snapshot)return NO;
    RWAtomicWrite *job=[RWAtomicWrite new];job.json=snapshot;[self submit:job path:path];return YES;
}
- (void)submit:(RWAtomicWrite *)job path:(NSString *)path {
    NSString *destination=[path copy];
    [_lock lock];_submitted++;if(_pending[destination])_coalesced++;_pending[destination]=job;_pendingPeak=MAX(_pendingPeak,_pending.count);BOOL start=!_writing;_writing=YES;[_lock unlock];
    if(start)dispatch_async(_queue,^{[self drain];});
}
- (NSData *)encodeJSON:(id)object {return [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];}
- (NSDictionary *)diagnostics {
    [_lock lock];NSDictionary *result=@{@"submitted":@(_submitted),@"coalesced":@(_coalesced),@"written":@(_written),@"failed":@(_failed),@"json_encodes":@(_encodes),@"main_thread_encodes":@(_mainEncodes),@"encode_seconds":@(_encodeSeconds),@"encode_max_seconds":@(_encodeMax),@"pending_destinations":@(_pending.count),@"pending_peak":@(_pendingPeak),@"busy":@(_writing)};[_lock unlock];return result;
}
- (void)whenIdle:(void (^)(void))completion {
    if(!completion)return;[_lock lock];BOOL busy=_writing;
    if(busy)[_completions addObject:[completion copy]];[_lock unlock];
    if(!busy){if(NSThread.isMainThread)completion();else dispatch_async(dispatch_get_main_queue(),completion);}
}
- (void)drain {
    for(;;){@autoreleasepool{
        [_lock lock];
        if(!_pending.count){
            _writing=NO;NSArray *callbacks=[_completions copy];[_completions removeAllObjects];[_lock unlock];
            if(callbacks.count)dispatch_async(dispatch_get_main_queue(),^{for(void (^callback)(void) in callbacks)callback();});
            return;
        }
        NSDictionary *batch=[_pending copy];[_pending removeAllObjects];[_lock unlock];
        for(NSString *path in batch){
            RWAtomicWrite *job=batch[path];NSData *data=job.data;
            if(job.json){double began=NSProcessInfo.processInfo.systemUptime;data=[self encodeJSON:job.json];double elapsed=NSProcessInfo.processInfo.systemUptime-began;[_lock lock];_encodes++;_mainEncodes+=NSThread.isMainThread;_encodeSeconds+=elapsed;_encodeMax=MAX(_encodeMax,elapsed);[_lock unlock];}
            BOOL ok=NO;if(data){[[NSFileManager defaultManager]createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];ok=[data writeToFile:path atomically:YES];}
            [_lock lock];if(ok)_written++;else _failed++;[_lock unlock];
        }
    }}
}
@end
