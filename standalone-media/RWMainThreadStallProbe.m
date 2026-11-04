#import "RWMainThreadStallProbe.h"
#include "RWStackReadPolicy.h"
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <pthread.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
@implementation RWMainThreadStallProbe {
    mach_port_t _mainThread;
    uint64_t _lower,_upper;
    double _began,_pulse,_lastCapture;
    BOOL _playing,_stopped;
    dispatch_source_t _timer;
    NSMutableArray *_stacks;
}
- (instancetype)initOnMainThread {
    NSAssert(NSThread.isMainThread,@"Capture the owned main thread");
    if((self=[super init])){
        _mainThread=mach_thread_self();_upper=(uintptr_t)pthread_get_stackaddr_np(pthread_self());size_t size=pthread_get_stacksize_np(pthread_self());_lower=size<=_upper?_upper-size:0;
        _began=_pulse=NSProcessInfo.processInfo.systemUptime;_stacks=[NSMutableArray new];
        dispatch_queue_t queue=dispatch_queue_create("org.local.rewind.main-stall-proof",DISPATCH_QUEUE_SERIAL);
        _timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,queue);
        dispatch_source_set_timer(_timer,dispatch_time(DISPATCH_TIME_NOW,50*NSEC_PER_MSEC),50*NSEC_PER_MSEC,10*NSEC_PER_MSEC);
        __weak RWMainThreadStallProbe *weak=self;dispatch_source_set_event_handler(_timer,^{[weak sampleIfLate];});dispatch_resume(_timer);
    }return self;
}
- (void)pulsePlaying:(BOOL)playing {@synchronized(self){_pulse=NSProcessInfo.processInfo.systemUptime;_playing=playing;}}
- (void)sampleIfLate {
    @autoreleasepool{
        double now=NSProcessInfo.processInfo.systemUptime,pulse;
        @synchronized(self){
            if(_stopped)return;
            if(now-_began>45||_stacks.count>=32){[self stop];return;}
            if(!_playing||now-_pulse<.2||now-_lastCapture<.08)return;
            pulse=_pulse;_lastCapture=now;
        }
        NSMutableDictionary *sample=[@{@"at":@(now),@"last_pulse":@(pulse),@"gap_seconds":@(now-pulse)}mutableCopy];
        thread_basic_info_data_t info={};mach_msg_type_number_t infoCount=THREAD_BASIC_INFO_COUNT;
        kern_return_t infoResult=thread_info(_mainThread,THREAD_BASIC_INFO,(thread_info_t)&info,&infoCount);
        sample[@"thread_info_result"]=@(infoResult);if(infoResult==KERN_SUCCESS){sample[@"run_state"]=@(info.run_state);sample[@"cpu_usage"]=@(info.cpu_usage);}
#if defined(__arm__) && !defined(__arm64__)
        arm_thread_state_t state={};mach_msg_type_number_t count=ARM_THREAD_STATE_COUNT;
        kern_return_t result=thread_get_state(_mainThread,ARM_THREAD_STATE,(thread_state_t)&state,&count);sample[@"state_result"]=@(result);
        if(result==KERN_SUCCESS){
            sample[@"pc"]=@(state.__pc);sample[@"lr"]=@(state.__lr);sample[@"sp"]=@(state.__sp);sample[@"fp"]=@(state.__r[7]);
            NSMutableArray *returns=[NSMutableArray new];uint32_t frame=state.__r[7];
            // Unsuspended stacks can race. Record bounded candidate frame-chain
            // return addresses; do not present these as a guaranteed unwind.
            for(int depth=0;depth<32&&RWStackFrameReadable(frame,_lower,_upper);depth++){
                uint32_t words[2]={0};vm_size_t copied=0;
                kern_return_t read=vm_read_overwrite(mach_task_self(),(vm_address_t)frame,sizeof(words),(vm_address_t)words,&copied);
                if(read!=KERN_SUCCESS||copied!=sizeof(words))break;
                [returns addObject:@(words[1])];if(!RWStackFrameFollows(words[0],frame,_lower,_upper))break;frame=words[0];
            }sample[@"candidate_returns"]=returns;
        }
#else
        sample[@"unsupported_architecture"]=@YES;
#endif
        sample[@"capture_seconds"]=@(NSProcessInfo.processInfo.systemUptime-now);
        @synchronized(self){if(!_stopped&&_stacks.count<32)[_stacks addObject:sample];}
    }
}
- (void)stop {@synchronized(self){if(_stopped)return;_stopped=YES;_playing=NO;if(_timer){dispatch_source_cancel(_timer);_timer=nil;}}}
- (NSDictionary *)evidence {
    NSArray *raw;@synchronized(self){raw=[_stacks copy];}
    NSMutableArray *samples=[NSMutableArray new];
    for(NSDictionary *entry in raw){NSMutableDictionary *value=[entry mutableCopy];NSMutableArray *symbols=[NSMutableArray new];
        NSMutableArray *addresses=[NSMutableArray new];if(entry[@"pc"])[addresses addObject:entry[@"pc"]];if(entry[@"lr"])[addresses addObject:entry[@"lr"]];[addresses addObjectsFromArray:entry[@"candidate_returns"]?:@[]];
        // Resolve symbols only after collection, never while a stall is sampled.
        for(NSNumber *address in addresses){Dl_info info={};uintptr_t pc=address.unsignedLongLongValue&~(uintptr_t)1;
            if(dladdr((void *)pc,&info)){NSString *image=info.dli_fname?[@(info.dli_fname)lastPathComponent]:@"",*symbol=info.dli_sname?@(info.dli_sname):@"";[symbols addObject:@{@"address":address,@"image":image,@"base":@((uintptr_t)info.dli_fbase),@"symbol":symbol,@"symbol_address":@((uintptr_t)info.dli_saddr)}];}
        }value[@"symbols"]=symbols;[samples addObject:value];
    }
    return @{@"samples":samples,@"limit_samples":@32,@"limit_seconds":@45,@"stack_lower":@(_lower),@"stack_upper":@(_upper),@"stopped":@(_stopped),@"thread_suspended":@NO,@"measurement":@"Read-only ARMv7 registers and bounded unsuspended frame-chain candidates; no other process or stack argument data."};
}
- (void)dealloc {[self stop];if(_mainThread!=MACH_PORT_NULL)mach_port_deallocate(mach_task_self(),_mainThread);}
@end
