// Opt-in diagnostic for the pinned VLCOpenGLES2VideoView. Read the framebuffer
// immediately BEFORE its existing presentRenderbuffer implementation; never
// seek, step, resume, repaint, replace the drawable, or alter GL state.
#import <objc/runtime.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#include "RWFrameCode.h"
@interface RWLegacyPresentationTrace : NSObject
@property(nonatomic,strong) NSMutableDictionary *frames;
@property(nonatomic,copy) NSString *directory;
@property(nonatomic) double began;
@property(nonatomic) NSUInteger reads;
@property(nonatomic) BOOL cancelled;
@property(nonatomic,strong) dispatch_queue_t queue;
@property(nonatomic) BOOL frameClock;
@property(nonatomic,strong) NSMutableArray *clockFrames;
@property(nonatomic,strong) NSMutableDictionary *pendingFrame;
- (void)capture;
- (void)didPresent;
- (NSDictionary *)clockEvidence;
- (NSDictionary *)snapshot;
@end
@implementation RWLegacyPresentationTrace
- (instancetype)init {if((self=[super init])){_frames=[NSMutableDictionary new];_began=NSProcessInfo.processInfo.systemUptime;_queue=dispatch_queue_create("org.local.rewind.presentation-proof",DISPATCH_QUEUE_SERIAL);}return self;}
- (NSDictionary *)snapshot {@synchronized(self){return @{ @"frames":[_frames copy],@"reads":@(_reads),@"cancelled":@(_cancelled),@"began":@(_began),@"frame_clock":@(_frameClock),@"clock_frames":@(_clockFrames.count)};}}
- (NSDictionary *)clockEvidence {@synchronized(self){return @{@"began":@(_began),@"frames":[_clockFrames copy]?:@[],@"limit_frames":@720,@"limit_seconds":@30};}}
- (void)didPresent {
    double now=NSProcessInfo.processInfo.systemUptime;
    @synchronized(self){if(_pendingFrame){_pendingFrame[@"present_returned"]=@(now);[_clockFrames addObject:[_pendingFrame copy]];_pendingFrame=nil;}}
}
- (void)captureClock {
    double now=NSProcessInfo.processInfo.systemUptime;
    @synchronized(self){if(_cancelled||_reads>=720||now-_began>30)return;_reads++;}
    GLint width=0,height=0;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER,GL_RENDERBUFFER_WIDTH,&width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER,GL_RENDERBUFFER_HEIGHT,&height);
    GLenum status=glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSMutableDictionary *entry=[@{@"before_read":@(now),@"width":@(width),@"height":@(height),@"framebuffer_status":@(status),@"frame":@(-1)}mutableCopy];
    if(EAGLContext.currentContext&&status==GL_FRAMEBUFFER_COMPLETE&&width>=64&&width<=1024&&height>0&&height<=1024){
        uint8_t pixels[4096]={0},levels[32]={0};
        // One centre row, <=4096 bytes. No GL state change, PNG, seek or redraw.
        glReadPixels(0,height/2,width,1,GL_RGBA,GL_UNSIGNED_BYTE,pixels);
        double end=NSProcessInfo.processInfo.systemUptime;
        int code=RWDecodeFrameCode(pixels,width,levels);NSMutableArray *values=[NSMutableArray new];
        for(int i=0;i<32;i++)[values addObject:@(levels[i])];
        entry[@"levels"]=values;entry[@"frame"]=@(code);entry[@"pixel_bytes"]=@(width*4);entry[@"read_seconds"]=@(end-now);
    }
    @synchronized(self){_pendingFrame=entry;}
}
- (void)capture {
    if(_frameClock){[self captureClock];return;}
    @autoreleasepool {
        double now=NSProcessInfo.processInfo.systemUptime;NSUInteger index;
        @synchronized(self){if(_cancelled||_reads>=3||now-_began>4||now-_began<_reads*.35)return;index=_reads++;}
        NSString *name=[NSString stringWithFormat:@"device-exercise-presentation-52-%lu.png",(unsigned long)index];
        GLint binding=0,renderbuffer=0;glGetIntegerv(GL_FRAMEBUFFER_BINDING,&binding);glGetIntegerv(GL_RENDERBUFFER_BINDING,&renderbuffer);GLenum framebufferStatus=glCheckFramebufferStatus(GL_FRAMEBUFFER);
        GLint width=0,height=0;glGetRenderbufferParameteriv(GL_RENDERBUFFER,GL_RENDERBUFFER_WIDTH,&width);glGetRenderbufferParameteriv(GL_RENDERBUFFER,GL_RENDERBUFFER_HEIGHT,&height);
        if(!EAGLContext.currentContext||width<1||height<1||width>1024||height>1024){@synchronized(self){_frames[name]=@{@"status":@"failed_dimensions",@"width":@(width),@"height":@(height)};}return;}
        NSUInteger stride=(NSUInteger)width*4,size=stride*height;NSMutableData *pixels=[NSMutableData dataWithLength:size];
        // RGBA byte rows are a multiple of four, preserving VLC's pack state.
        glReadPixels(0,0,width,height,GL_RGBA,GL_UNSIGNED_BYTE,pixels.mutableBytes);
        double readEnd=NSProcessInfo.processInfo.systemUptime;
        NSUInteger nonblack=0,nonopaque=0;const unsigned char *raw=(const unsigned char *)pixels.bytes;for(NSUInteger offset=0;offset<size;offset+=4){if(raw[offset]||raw[offset+1]||raw[offset+2])nonblack++;if(raw[offset+3]!=255)nonopaque++;}
        NSDictionary *entry=@{@"status":@"pending",@"framebuffer":@(binding),@"renderbuffer":@(renderbuffer),@"framebuffer_status":@(framebufferStatus),@"raw_nonblack_pixels":@(nonblack),@"raw_nonopaque_pixels":@(nonopaque),@"file":name,@"at":@(now),@"since_armed":@(now-_began),@"width":@(width),@"height":@(height),@"read_seconds":@(readEnd-now),@"pixel_bytes":@(size)};
        @synchronized(self){_frames[name]=entry;}
        dispatch_async(_queue,^{@autoreleasepool{
            @synchronized(self){if(self->_cancelled)return;}
            // GL's origin is bottom-left. Reverse rows in the exported copy only.
            // The VLC drawable is opaque. Its unused alpha must not make the
            // PNG transparent or discard otherwise valid RGB during encoding.
            NSMutableData *upright=[NSMutableData dataWithLength:size];for(GLint row=0;row<height;row++)memcpy((char *)upright.mutableBytes+row*stride,(const char *)pixels.bytes+(height-1-row)*stride,stride);
            CGColorSpaceRef color=CGColorSpaceCreateDeviceRGB();CGContextRef context=CGBitmapContextCreate(upright.mutableBytes,width,height,8,stride,color,kCGImageAlphaNoneSkipLast|kCGBitmapByteOrder32Big);CGColorSpaceRelease(color);
            CGImageRef frame=context?CGBitmapContextCreateImage(context):NULL;NSData *png=frame?UIImagePNGRepresentation([UIImage imageWithCGImage:frame]):nil;
            if(frame)CGImageRelease(frame);if(context)CGContextRelease(context);
            BOOL ok=png.length>0&&png.length<2*1024*1024&&[png writeToFile:[self.directory stringByAppendingPathComponent:name] atomically:YES];
            NSMutableDictionary *finished=[entry mutableCopy];finished[@"status"]=ok?@"complete":@"failed_export";finished[@"png_bytes"]=@(png.length);
            @synchronized(self){self->_frames[name]=finished;}
        }});
    }
}
@end
static char RWPresentationTraceKey;
static IMP RWOriginalPresentation;
static void RWObservedPresentation(id view,SEL selector) {
    RWLegacyPresentationTrace *trace=objc_getAssociatedObject(view,&RWPresentationTraceKey);[trace capture];
    ((void(*)(id,SEL))RWOriginalPresentation)(view,selector);
    [trace didPresent];
}
static UIView *RWPresentationView(UIView *view,Class type){if([view isKindOfClass:type])return view;for(UIView *child in view.subviews){UIView *found=RWPresentationView(child,type);if(found)return found;}return nil;}
static RWLegacyPresentationTrace *RWArmPresentation(UIView *surface,NSString *directory,BOOL frameClock) {
    NSCAssert(NSThread.isMainThread,@"Attach diagnostic on main thread");
    Class type=NSClassFromString(@"VLCOpenGLES2VideoView");UIView *view=type?RWPresentationView(surface,type):nil;if(!view)return nil;
    SEL selector=NSSelectorFromString(@"presentRenderbuffer");Method method=class_getInstanceMethod(type,selector);if(!method)return nil;
    NSMethodSignature *signature=[type instanceMethodSignatureForSelector:selector];if(signature.numberOfArguments!=2||strcmp(signature.methodReturnType,@encode(void)))return nil;
    static dispatch_once_t once;dispatch_once(&once,^{RWOriginalPresentation=method_getImplementation(method);method_setImplementation(method,(IMP)RWObservedPresentation);});
    if(method_getImplementation(method)!=(IMP)RWObservedPresentation)return nil;
    RWLegacyPresentationTrace *trace=[RWLegacyPresentationTrace new];trace.directory=directory;trace.clockFrames=frameClock?[NSMutableArray new]:nil;trace.frameClock=frameClock;
    objc_setAssociatedObject(view,&RWPresentationTraceKey,trace,OBJC_ASSOCIATION_RETAIN_NONATOMIC);return trace;
}
