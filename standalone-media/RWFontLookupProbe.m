#import "RWFontLookupProbe.h"
#import <CoreText/CoreText.h>
#include <string.h>
static double RWFontNow(void){return NSProcessInfo.processInfo.systemUptime;}
@implementation RWFontLookupProbe {
    BOOL _started,_cancelled,_running;double _began,_elapsed;NSDictionary *_result;
}
- (instancetype)init {if((self=[super init]))_result=@{@"status":@"idle",@"cases":@[]};return self;}
- (BOOL)allowed {@synchronized(self){return !_cancelled&&RWFontNow()-_began<30;}}
- (void)cancel {@synchronized(self){if(!_running)return;_cancelled=YES;_result=@{@"status":@"cancelled",@"cases":@[]};}}
- (NSDictionary *)snapshot {@synchronized(self){NSMutableDictionary *v=[_result mutableCopy];v[@"worker_running"]=@(_running);v[@"seconds"]=@(_running?RWFontNow()-_began:_elapsed);v[@"case_limit"]=@6;v[@"matched_limit"]=@64;v[@"file_descriptor_limit"]=@256;v[@"window_seconds"]=@30;return [v copy];}}
- (NSDictionary *)lookup:(NSString *)family round:(NSUInteger)round {
    double began=RWFontNow(),at=began;NSMutableArray *descriptors=[NSMutableArray new];
    for(id key in @[(__bridge id)kCTFontFamilyNameAttribute,(__bridge id)kCTFontDisplayNameAttribute,(__bridge id)kCTFontNameAttribute]){
        id descriptor=CFBridgingRelease(CTFontDescriptorCreateWithAttributes((__bridge CFDictionaryRef)@{key:family}));
        if(!descriptor)return @{@"status":@"descriptor_create_failed",@"family":family};[descriptors addObject:descriptor];
    }
    double setup=RWFontNow()-at;at=RWFontNow();
    CTFontCollectionRef collection=CTFontCollectionCreateWithFontDescriptors((__bridge CFArrayRef)descriptors,NULL);
    if(!collection)return @{@"status":@"collection_create_failed",@"family":family};
    double creation=RWFontNow()-at;at=RWFontNow();
    NSArray *matched=CFBridgingRelease(CTFontCollectionCreateMatchingFontDescriptors(collection));CFRelease(collection);
    double matching=RWFontNow()-at;NSMutableArray *files=[NSMutableArray new];NSMutableDictionary *fileIDs=[NSMutableDictionary new];
    NSString *status=@"complete";if(!matched)status=@"matching_failed";else if(matched.count>64)status=@"matched_limit";
    if([status isEqual:@"complete"]){for(id raw in matched){@autoreleasepool{
        if(![self allowed]){status=@"interrupted";break;}
        CTFontDescriptorRef descriptor=(__bridge CTFontDescriptorRef)raw;at=RWFontNow();
        NSURL *url=CFBridgingRelease(CTFontDescriptorCopyAttribute(descriptor,kCTFontURLAttribute));
        NSString *path=CFBridgingRelease(url?CFURLCopyFileSystemPath((__bridge CFURLRef)url,kCFURLPOSIXPathStyle):NULL);
        double pathSeconds=RWFontNow()-at;
        if(![url isKindOfClass:NSURL.class]||!url.isFileURL||![path hasPrefix:@"/System/Library/Fonts/"]){status=@"non_system_font";break;}
        NSNumber *fileID=fileIDs[path];if(!fileID){fileID=@(fileIDs.count);fileIDs[path]=fileID;}
        at=RWFontNow();const char *utf8=path.fileSystemRepresentation;
        CFURLRef reopened=CFURLCreateFromFileSystemRepresentation(NULL,(const UInt8 *)utf8,strlen(utf8),false);
        NSArray *contents=CFBridgingRelease(reopened?CTFontManagerCreateFontDescriptorsFromURL(reopened):NULL);if(reopened)CFRelease(reopened);
        double enumeration=RWFontNow()-at;NSInteger index=-1;NSUInteger examined=0;at=RWFontNow();
        if(!contents)status=@"file_descriptors_failed";else if(contents.count>256)status=@"file_descriptor_limit";
        else {NSString *target=family.lowercaseString;for(id item in contents){
            if(![self allowed]){status=@"interrupted";break;}
            CTFontDescriptorRef d=(__bridge CTFontDescriptorRef)item;
            NSString *fn=CFBridgingRelease(CTFontDescriptorCopyAttribute(d,kCTFontFamilyNameAttribute));
            NSString *pn=CFBridgingRelease(CTFontDescriptorCopyAttribute(d,kCTFontNameAttribute));
            NSString *dn=CFBridgingRelease(CTFontDescriptorCopyAttribute(d,kCTFontDisplayNameAttribute));
            // Pinned VLC scans the complete file and keeps the last match.
            examined++;if((fn&&[target caseInsensitiveCompare:fn]==NSOrderedSame)||(pn&&[target caseInsensitiveCompare:pn]==NSOrderedSame)||(dn&&[target caseInsensitiveCompare:dn]==NSOrderedSame)){index=(NSInteger)examined-1;}
        }}
        double names=RWFontNow()-at;at=RWFontNow();BOOL bold=NO,italic=NO;
        if(index>=0){NSDictionary *traits=CFBridgingRelease(CTFontDescriptorCopyAttribute(descriptor,kCTFontTraitsAttribute));bold=[traits[(__bridge id)kCTFontWeightTrait]doubleValue]>.23;italic=[traits[(__bridge id)kCTFontSlantTrait]doubleValue]>.03;}
        double traitsSeconds=RWFontNow()-at;
        [files addObject:@{@"file_id":fileID,@"path_seconds":@(pathSeconds),@"enumeration_seconds":@(enumeration),@"name_scan_seconds":@(names),@"traits_seconds":@(traitsSeconds),@"descriptors_in_file":@(contents.count),@"descriptors_examined":@(examined),@"matched_index":@(index),@"bold":@(bold),@"italic":@(italic)}];
        if(![status isEqual:@"complete"])break;
    }}}
    if(![self allowed]&&[status isEqual:@"complete"])status=@"interrupted";
    return @{@"status":status,@"family":family,@"round":@(round),@"seconds":@(RWFontNow()-began),@"descriptor_setup_seconds":@(setup),@"collection_create_seconds":@(creation),@"matching_seconds":@(matching),@"matched_descriptors":@(matched.count),@"unique_files":@(fileIDs.count),@"file_reads":[files copy]};
}
- (BOOL)start {
    @synchronized(self){if(_started||_cancelled)return NO;_started=YES;_running=YES;_began=RWFontNow();_result=@{@"status":@"running",@"cases":@[]};}
    static dispatch_queue_t queue;static dispatch_once_t once;dispatch_once(&once,^{queue=dispatch_queue_create("org.local.rewind.font-probe",DISPATCH_QUEUE_SERIAL);});
    dispatch_async(queue,^{@autoreleasepool{
        NSMutableArray *rows=[NSMutableArray new];BOOL completed=YES;
        for(NSUInteger round=0;round<2&&completed;round++)for(NSString *font in @[@"Helvetica Neue",@"Arial",@"ArialMT"]){
            if(![self allowed]){completed=NO;break;}
            NSDictionary *row=[self lookup:font round:round];[rows addObject:row];if(![row[@"status"]isEqual:@"complete"]){completed=NO;break;}
        }
        @synchronized(self){_elapsed=RWFontNow()-_began;_running=NO;if(!_cancelled)_result=@{@"status":completed?@"complete":@"incomplete",@"cases":[rows copy],@"elapsed_seconds":@(RWFontNow()-_began),@"scope":@"Read-only reconstruction of pinned VLC CoreText lookup; excludes FreeType face loading and playback. Calls are non-preemptible; cancellation/deadline checked between calls."};}
    }});return YES;
}
@end
