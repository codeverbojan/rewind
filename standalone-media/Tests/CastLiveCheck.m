#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import "../RWCast.h"
#import "../RWAtomicWriter.h"
int main(void){@autoreleasepool{
    NSString *path=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    RWCast *client=[[RWCast alloc]initWithCache:path];NSMutableArray *results=[NSMutableArray new];int failures=0;
    @try{for(NSDictionary *meta in @[
        @{@"id":@"tt37510326",@"name":@"The Social Reckoning",@"type":@"movie",@"releaseInfo":@"2026",@"moviedb_id":@1281331},
        @{@"id":@"tt1375666",@"name":@"Inception",@"type":@"movie",@"releaseInfo":@"2010",@"moviedb_id":@27205},
        @{@"id":@"tt0369179",@"name":@"Two and a Half Men",@"type":@"series"}]){
        __block BOOL done=NO;__block NSArray *people=nil;double began=NSProcessInfo.processInfo.systemUptime;
        [client resolve:meta done:^(NSArray *value){people=value;done=YES;}];
        NSDate *end=[NSDate dateWithTimeIntervalSinceNow:17];while(!done&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.02]];
        NSUInteger photos=0;for(NSDictionary *person in people)if([person[@"image"]length])photos++;
        NSMutableDictionary *row=[@{@"title":meta[@"name"],@"people":@(people.count),@"photos":@(photos),@"seconds":@(NSProcessInfo.processInfo.systemUptime-began),@"failure":client.lastFailure}mutableCopy];
        if(photos){NSDictionary *person=people.firstObject;row[@"first_person"]=person[@"name"];row[@"provider"]=person[@"provider"];
            NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;config.timeoutIntervalForResource=5;NSURLSession *session=[NSURLSession sessionWithConfiguration:config];__block BOOL imageDone=NO;
            NSURLSessionDataTask *task=[session dataTaskWithURL:[NSURL URLWithString:person[@"image"]]completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){CGImageSourceRef source=data?CGImageSourceCreateWithData((__bridge CFDataRef)data,NULL):NULL;CGImageRef image=source?CGImageSourceCreateImageAtIndex(source,0,NULL):NULL;NSDictionary *picture=@{@"decoded":@(image!=NULL),@"width":@(image?CGImageGetWidth(image):0),@"height":@(image?CGImageGetHeight(image):0),@"bytes":@(data.length),@"http":@([(NSHTTPURLResponse *)response statusCode])};if(image)CGImageRelease(image);if(source)CFRelease(source);dispatch_async(dispatch_get_main_queue(),^{row[@"portrait"]=picture;imageDone=YES;});}];[task resume];
            NSDate *imageEnd=[NSDate dateWithTimeIntervalSinceNow:6];while(!imageDone&&imageEnd.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.02]];[session invalidateAndCancel];if(![row[@"portrait"][@"decoded"]boolValue])failures++;
        }else failures++;[results addObject:row];[client cancel];
    }}@finally{[client cancel];__block BOOL idle=NO;[[RWAtomicWriter shared]whenIdle:^{idle=YES;}];NSDate *end=[NSDate dateWithTimeIntervalSinceNow:2];while(!idle&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.02]];[NSFileManager.defaultManager removeItemAtPath:path error:nil];}
    puts([[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:@{@"results":results,@"failures":@(failures)} options:NSJSONWritingPrettyPrinted error:nil]encoding:NSUTF8StringEncoding].UTF8String);return failures?1:0;
}}
