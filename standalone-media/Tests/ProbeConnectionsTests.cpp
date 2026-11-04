#include "../RWProbeConnections.h"
#include <cstdio>
int main(){int checks=0,failures=0;auto check=[&](bool value,const char*message){checks++;if(!value){failures++;std::fprintf(stderr,"FAIL:%s\n",message);}};
 using RWProbeConnections::Target;
 check(Target(false,12,12,1)==13,"Saturated probe can attempt a newly available peer");
 check(Target(false,12,12,300)==13,"Large peer lists cannot expand beyond one spare");
 check(Target(false,12,11,300)==12,"Available initial slots need no expansion");
 check(Target(false,12,12,0)==12,"No extra slot without a queued peer");
 check(Target(false,12,12,-1)==12,"Unknown candidate count cannot expand");
 check(Target(true,12,12,300)==12,"Background preparation retains its original limit");
 check(Target(false,13,13,300)==13,"Repeated saturation cannot grow the limit again");
 check(Target(false,13,2,300)==13,"Recovery never disconnects established peers by shrinking");
 check(Target(false,40,40,300)==40,"Selected player's connection limit is unchanged");
 check(Target(false,0,12,300)==0&&Target(false,-1,12,300)==-1,"Other limits are never rewritten");
 check(Target(false,12,12,300)*3==39,"Three probes retain headroom under global40");
 std::printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;}
