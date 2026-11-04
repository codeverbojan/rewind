#include "../RWNativeBufferRecovery.h"
#include <cstdio>
#include <initializer_list>
int main(){int checks=0,failures=0;
auto check=[&](bool ok,const char *why){checks++;if(!ok){failures++;std::fprintf(stderr,"FAIL: %s\n",why);}};
RWNativeBufferRecovery p;
// Actual122 failure: seek completed, rate0 and buffer grew while iOS9's
// likelyToKeepUp stayed false. Neither that flag nor bufferEmpty is an input.
for(double buffered:{.0463,.9083,2.1623,3.2903,3.6253})
 check(!p.resume(110,482.7387,0,true,true,false,buffered,200),"Do not restart with an inadequate buffer");
check(p.resume(128,482.7387,0,true,true,false,5.0393,200),"Restart when actual five-second buffer arrives");
check(p.requests==1&&p.attempts==1&&p.grace(130),"Short grace lets the requested play advance");
check(!p.resume(130,482.7387,0,true,true,false,8,200),"Do not repeatedly play every tick");
check(p.resume(131,482.7387,0,true,true,false,8,200),"One bounded retry if first play did not advance");
check(!p.resume(134,482.7387,0,true,true,false,8,200)&&!p.grace(134),"Two failed resumes return to the watchdog");
check(!p.resume(135,485,1,true,true,false,8,200)&&p.attempts==0,"Actual advancing playback resets stall episode");
check(p.resume(140,485,0,true,true,false,8,200),"A later independent stall may recover");
for(int guard=0;guard<4;guard++){
 RWNativeBufferRecovery g;
 check(!g.resume(10,100,guard==3?1:0,guard!=0,guard!=1,guard==2,10,200),"Never override not-ready, pause, seek or already-playing state");
 check(g.requests==0,"Denied resumes do not consume attempts");
}
RWNativeBufferRecovery end;
check(!end.resume(1,99,0,true,true,false,.5,1),"Incomplete final second still buffers");
check(end.resume(2,99,0,true,true,false,1,1),"Final short tail may resume without five full seconds");
check(!end.resume(5,100,0,true,true,false,1,0),"Ended media must not restart itself");
RWNativeBufferRecovery invalid;
check(!invalid.resume(NAN,100,0,true,true,false,10,100),"Invalid clock rejected");
check(!invalid.resume(1,NAN,0,true,true,false,10,100),"Invalid position rejected");
check(!invalid.resume(1,100,0,true,true,false,NAN,100),"Invalid range rejected");
check(!invalid.resume(1,100,0,true,true,false,10,INFINITY),"Unknown remaining time rejected");
check(!invalid.resume(1,100,0,true,true,false,-1,100),"Negative buffer rejected");
check(!invalid.grace(100),"No grace before a resume request");
std::printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;}
