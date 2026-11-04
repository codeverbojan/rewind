#import <Foundation/Foundation.h>
#import "../RWAtomicWriter.h"
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
static BOOL Until(BOOL(^ready)(void)){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:5];while(!ready()&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];return ready();}
static void Flush(RWAtomicWriter *writer){__block BOOL done=NO;[writer whenIdle:^{CHECK(NSThread.isMainThread);done=YES;}];CHECK(Until(^BOOL{return done;}));}
static id Read(NSString *path){return [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] options:0 error:nil];}
// Hold a real encoding after snapshot capture, deterministically testing both
// ownership and the queue/flush ordering rather than hoping for a thread race.
@interface RWAtomicWriter (Encoding)
- (NSData *)encodeJSON:(id)object;
@end
@interface HeldWriter:RWAtomicWriter
@property(nonatomic,strong) dispatch_semaphore_t entered,gate;
@property(nonatomic) BOOL hold;
@end
@implementation HeldWriter
- (NSData *)encodeJSON:(id)object {
    if(self.hold){self.hold=NO;dispatch_semaphore_signal(self.entered);dispatch_semaphore_wait(self.gate,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC));}
    return [super encodeJSON:object];
}
@end
int main(){@autoreleasepool{
    NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];NSString *path=[folder stringByAppendingPathComponent:@"state.json"],*other=[folder stringByAppendingPathComponent:@"other.json"];
    HeldWriter *writer=[HeldWriter new];writer.entered=dispatch_semaphore_create(0);writer.gate=dispatch_semaphore_create(0);writer.hold=YES;
    @try {
        NSMutableString *name=[@"Original" mutableCopy];NSMutableArray *saved=[NSMutableArray arrayWithObject:name];NSMutableDictionary *history=[@{@"position":@123,@"duration":@600,@"completed":@NO,@"optional":NSNull.null}mutableCopy];
        // An immutable root can still contain mutable descendants and aliases.
        NSDictionary *value=@{@"profiles":@{@"main":@{@"history":history,@"saved":saved},@"kids":@{@"history":@{},@"maxAge":@7}},@"history":history};
        CHECK([writer writeJSON:value path:path]);CHECK(dispatch_semaphore_wait(writer.entered,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC))==0);
        history[@"position"]=@999;[name setString:@"Changed"];[saved removeAllObjects];
        __block BOOL flushed=NO;[writer whenIdle:^{flushed=YES;}];CHECK(!flushed);
        dispatch_semaphore_signal(writer.gate);CHECK(Until(^BOOL{return flushed;}));NSDictionary *disk=Read(path);
        CHECK([disk[@"profiles"][@"main"][@"history"][@"position"]intValue]==123);
        CHECK([disk[@"history"]isEqual:disk[@"profiles"][@"main"][@"history"]]);
        CHECK([disk[@"profiles"][@"main"][@"saved"]isEqual:@[@"Original"]]);
        CHECK(disk[@"history"][@"optional"]==NSNull.null&&![disk[@"history"][@"completed"]boolValue]);
        CHECK([disk[@"profiles"][@"kids"][@"maxAge"]intValue]==7);
        CHECK([writer.diagnostics[@"json_encodes"]intValue]==1&&[writer.diagnostics[@"main_thread_encodes"]intValue]==0);

        writer.hold=YES;CHECK([writer writeJSON:@{@"old":@YES} path:path]);CHECK(dispatch_semaphore_wait(writer.entered,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC))==0);
        BOOL allAccepted=YES;for(int i=0;i<200;i++)allAccepted&=[writer writeJSON:@{@"position":@(i)} path:path];CHECK(allAccepted);
        [writer write:[@"raw replacement" dataUsingEncoding:NSUTF8StringEncoding] path:other];
        CHECK([writer writeJSON:@{@"last":@YES} path:other]);
        CHECK([writer.diagnostics[@"pending_destinations"]intValue]==2);
        flushed=NO;[writer whenIdle:^{flushed=YES;}];CHECK(!flushed);dispatch_semaphore_signal(writer.gate);CHECK(Until(^BOOL{return flushed;}));
        CHECK([Read(path)[@"position"]intValue]==199&&[Read(other)[@"last"]boolValue]);
        CHECK([writer.diagnostics[@"coalesced"]intValue]>=200&&[writer.diagnostics[@"json_encodes"]intValue]==4);
        CHECK([writer writeJSON:@{@"earlier":@YES} path:path]);[writer write:[@"latest bytes" dataUsingEncoding:NSUTF8StringEncoding] path:path];Flush(writer);
        CHECK([[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]isEqual:@"latest bytes"]);
        // Rejected objects must leave a previously good file intact.
        CHECK(![writer writeJSON:@{@"bad":NSDate.date} path:path]);CHECK(![writer writeJSON:@{@"bad":@(NAN)} path:path]);CHECK(![writer writeJSON:@{@1:@"bad key"} path:path]);CHECK(![writer writeJSON:@"scalar" path:path]);
        NSMutableArray *cycle=[NSMutableArray new];id alias=cycle;[cycle addObject:alias];CHECK(![writer writeJSON:cycle path:path]);[cycle removeAllObjects];Flush(writer);
        CHECK([[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]isEqual:@"latest bytes"]);
        // Background producers own their input graphs too; no main-only writer.
        __block BOOL produced=NO;dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSMutableDictionary *input=[@{@"position":@456}mutableCopy];[writer writeJSON:input path:path];input[@"position"]=@0;dispatch_async(dispatch_get_main_queue(),^{produced=YES;});});
        CHECK(Until(^BOOL{return produced;}));Flush(writer);CHECK([Read(path)[@"position"]intValue]==456);
        CHECK([writer.diagnostics[@"failed"]intValue]==0&&[writer.diagnostics[@"main_thread_encodes"]intValue]==0);
        // Exercise both heap-backed capture paths, including partial rejection.
        NSMutableDictionary *wide=[NSMutableDictionary new];NSMutableArray *longArray=[NSMutableArray new];
        for(int i=0;i<100;i++){wide[[NSString stringWithFormat:@"k%d",i]]=@(i);[longArray addObject:@(i)];}wide[@"items"]=longArray;
        CHECK([writer writeJSON:wide path:path]);wide[@"k0"]=@999;longArray[50]=@999;Flush(writer);
        CHECK([Read(path)[@"k0"]intValue]==0&&[Read(path)[@"items"][50]intValue]==50);
        longArray[75]=NSDate.date;CHECK(![writer writeJSON:wide path:path]);Flush(writer);CHECK([Read(path)[@"items"][75]intValue]==75);
    }@finally{dispatch_semaphore_signal(writer.gate);Flush(writer);[[NSFileManager defaultManager]removeItemAtPath:folder error:nil];}
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
