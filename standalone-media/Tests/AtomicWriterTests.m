#import <Foundation/Foundation.h>
#import "../RWAtomicWriter.h"
int main(){@autoreleasepool{
    __block int checks=0,failures=0;void(^check)(BOOL,NSString*)=^(BOOL pass,NSString *message){checks++;if(!pass){failures++;fprintf(stderr,"FAIL: %s\n",message.UTF8String);}};
    NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    RWAtomicWriter *writer=[RWAtomicWriter new];NSString *state=[folder stringByAppendingPathComponent:@"state.json"],*metrics=[folder stringByAppendingPathComponent:@"diagnostics/metrics.json"];
    @try {
        __block BOOL idle=NO;[writer whenIdle:^{idle=YES;}];check(idle,@"An idle writer completes immediately");idle=NO;
        // Queue many successive saves without yielding main: the disk worker
        // must retain the newest position, even if the initial write finishes.
        for(int i=0;i<200;i++)[writer write:[[NSString stringWithFormat:@"%d",i]dataUsingEncoding:NSUTF8StringEncoding] path:state];
        [writer write:[@"metrics"dataUsingEncoding:NSUTF8StringEncoding] path:metrics];
        __block BOOL callbackMain=NO;[writer whenIdle:^{idle=YES;callbackMain=NSThread.isMainThread;}];
        double deadline=NSProcessInfo.processInfo.systemUptime+5;
        while(!idle&&NSProcessInfo.processInfo.systemUptime<deadline)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
        check(idle&&callbackMain,@"Flush completes on main within a bounded wait");
        check([[NSString stringWithContentsOfFile:state encoding:NSUTF8StringEncoding error:nil]isEqual:@"199"],@"The latest position wins over 199 earlier saves");
        check([[NSString stringWithContentsOfFile:metrics encoding:NSUTF8StringEncoding error:nil]isEqual:@"metrics"],@"Independent destinations and missing directories work");
        [writer write:[@"next"dataUsingEncoding:NSUTF8StringEncoding] path:state];idle=NO;[writer whenIdle:^{idle=YES;}];deadline=NSProcessInfo.processInfo.systemUptime+5;
        while(!idle&&NSProcessInfo.processInfo.systemUptime<deadline)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
        check(idle&&[[NSString stringWithContentsOfFile:state encoding:NSUTF8StringEncoding error:nil]isEqual:@"next"],@"Saving after a completed flush is ordered correctly");
        // Regression for the physical 0.37 crash: metadata JSON is encoded on
        // a utility queue, then submitted here. Catch the assertion so the old
        // implementation fails this check without killing the whole harness.
        __block BOOL backgroundReturned=NO,backgroundThrew=NO;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0),^{
            @try{[writer write:[@"background metadata"dataUsingEncoding:NSUTF8StringEncoding] path:metrics];}
            @catch(NSException *exception){backgroundThrew=YES;}
            dispatch_async(dispatch_get_main_queue(),^{backgroundReturned=YES;});
        });
        deadline=NSProcessInfo.processInfo.systemUptime+5;
        while(!backgroundReturned&&NSProcessInfo.processInfo.systemUptime<deadline)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
        check(backgroundReturned&&!backgroundThrew,@"A metadata save from a background queue must not throw");
        idle=NO;[writer whenIdle:^{idle=YES;}];deadline=NSProcessInfo.processInfo.systemUptime+5;
        while(!idle&&NSProcessInfo.processInfo.systemUptime<deadline)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
        check(idle&&[[NSString stringWithContentsOfFile:metrics encoding:NSUTF8StringEncoding error:nil]isEqual:@"background metadata"],@"The real background metadata save reaches disk");
        __block BOOL producersDone=NO;dispatch_group_t group=dispatch_group_create();
        for(int producer=0;producer<4;producer++)dispatch_group_async(group,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
            NSString *file=[folder stringByAppendingPathComponent:[NSString stringWithFormat:@"producer-%d.json",producer]];
            for(int i=0;i<250;i++){@autoreleasepool{[writer write:[[NSString stringWithFormat:@"%d:%d",producer,i]dataUsingEncoding:NSUTF8StringEncoding] path:file];}}
        });
        dispatch_group_notify(group,dispatch_get_main_queue(),^{producersDone=YES;});
        deadline=NSProcessInfo.processInfo.systemUptime+5;
        while(!producersDone&&NSProcessInfo.processInfo.systemUptime<deadline)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
        idle=NO;dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0),^{[writer whenIdle:^{callbackMain=NSThread.isMainThread;idle=YES;}];});
        deadline=NSProcessInfo.processInfo.systemUptime+5;
        while(!idle&&NSProcessInfo.processInfo.systemUptime<deadline)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
        check(producersDone&&idle&&callbackMain,@"Concurrent producers and a background flush finish on main");
        for(int producer=0;producer<4;producer++){NSString *file=[folder stringByAppendingPathComponent:[NSString stringWithFormat:@"producer-%d.json",producer]];check([[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil]isEqual:[NSString stringWithFormat:@"%d:249",producer]],@"Every producer retains its last snapshot");}
        // Mutating the caller's buffer after submission cannot change the file.
        NSMutableData *mutable=[[@"original"dataUsingEncoding:NSUTF8StringEncoding]mutableCopy];[writer write:mutable path:metrics];[mutable setData:[@"changed"dataUsingEncoding:NSUTF8StringEncoding]];
        idle=NO;[writer whenIdle:^{idle=YES;}];deadline=NSProcessInfo.processInfo.systemUptime+5;
        while(!idle&&NSProcessInfo.processInfo.systemUptime<deadline)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
        check(idle&&[[NSString stringWithContentsOfFile:metrics encoding:NSUTF8StringEncoding error:nil]isEqual:@"original"],@"Input data is snapshotted before submission returns");
    }@finally{[[NSFileManager defaultManager]removeItemAtPath:folder error:nil];}
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
