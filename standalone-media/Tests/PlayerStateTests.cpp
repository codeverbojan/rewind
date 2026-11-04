#include "../RWPlayerState.h"
#include <cstdio>
int main(){int checks=0,failures=0;auto check=[&](bool ok,const char *name){checks++;if(!ok){failures++;std::fprintf(stderr,"FAIL: %s\n",name);}};RWPlaybackMotion s;s.reset(0);
check(s.spinner(0,0,false,false,true,false,false),"Show loader until first frame");
for(int i=1;i<=10;i++)check(!s.spinner(i,i,true,true,true,false,false),"Advancing playback removes spinner even with stale iOS buffer flag");
check(!s.spinner(11,10,true,true,true,false,false),"Short frame gap does not flash spinner");
check(s.spinner(12,10,true,true,true,false,false),"Real stall shows feedback");
check(!s.spinner(13,11,true,true,true,false,false),"Recovery clears feedback");
check(!s.spinner(16,11,true,true,false,false,false),"Paused player is not buffering");
check(!s.spinner(17,11,true,true,true,true,false),"Scrubbing is not a playback stall");
check(!s.spinner(18,11,false,false,true,false,true),"Exhausted sources do not spin forever");
check(!RWPlaybackStalled(false,true,false,22),"Verified tracks without a first frame must not trigger the playback-stall watchdog");
check(RWPlaybackStalled(true,true,false,22),"A real stall after playback begins still rotates the source");
check(!RWPlaybackStalled(true,false,false,30),"User pause is not a stall");
check(!RWPlaybackStalled(true,true,true,30),"A user seek is not counted as stalled playback");
check(!RWNativeSeekExpired(true,true,119),"Pending seek retains bounded data-loading window");
check(RWNativeSeekExpired(true,true,120),"A stuck asynchronous seek cannot wait forever");
check(!RWNativeSeekExpired(true,false,130),"Paused intent does not fail source during pending seek");
check(!RWNativeSeekExpired(false,true,130),"Completed seek returns to ordinary playback policy");
check(!RWInitialWaitExpired(55,22,0),"The reported live episode can continue buffering while payload advances");
check(!RWInitialWaitExpired(90,10,0),"An extended healthy opening leaves time for actual media preparation");
check(RWInitialWaitExpired(150,10,0),"Media verification cannot reset the total first-frame deadline");
check(RWInitialWaitExpired(100,60,0),"A single source cannot consume unlimited time through trickle payload");
check(RWInitialWaitExpired(55,22,13),"A source with no new payload still has a bounded idle deadline");
check(RWSourceUpdateDecision(true,true,false,false,false,3,0)==RWSourceUpdate::Append,"Fresh episode results join the saved-source race");
check(RWSourceUpdateDecision(true,false,false,false,true,3,0)==RWSourceUpdate::Keep,"Fresh results do not replace a decoder already opening or playing");
check(RWSourceUpdateDecision(true,false,true,false,false,5,1)==RWSourceUpdate::Start,"New candidates start when the saved source failed during lookup");
check(RWSourceUpdateDecision(true,false,false,true,false,25,1)==RWSourceUpdate::Start,"Late sources recover an exhausted cached-source attempt within the existing budget");
check(RWSourceUpdateDecision(false,false,true,false,false,5,1)==RWSourceUpdate::Unavailable,"Failed saved source alone cannot cause an automatic retry loop");
check(RWSourceUpdateDecision(false,false,false,true,false,25,1)==RWSourceUpdate::Keep,"A repeated provider result cannot resurrect exhausted sources");
check(RWSourceUpdateDecision(true,false,false,true,false,151,1)==RWSourceUpdate::Keep,"Late sources do not reset the total startup deadline");
check(RWSourceUpdateDecision(true,false,true,false,false,20,5)==RWSourceUpdate::Unavailable,"Late sources respect the maximum number of playback attempts");
std::printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;}
