#ifdef RW_LEGACY_POLICY
#include "../versions/0.234/RWDiscoveryPolicy.h"
#else
#include "../RWDiscoveryPolicy.h"
#endif
#include "../RWTransferWindow.h"
#include <cstdio>
static bool ready(double rate,double required,double seconds,uint64_t prefix,bool complete=false){
#ifdef RW_LEGACY_POLICY
    return RWStreamingReady(true,complete,2,rate,required,seconds);
#else
    return RWStreamingReady(true,complete,2,rate,required,seconds,prefix);
#endif
}
int main(){int checks=0,failures=0;auto check=[&](bool ok,const char *message){checks++;if(!ok){failures++;std::fprintf(stderr,"FAIL:%s\n",message);}};
    check(!ready(1785474,1295997,2.991,2*1024*1024),"Observed234 short sample with only a small reserve must not qualify");
    check(!ready(400000,300000,8,65536),"Long observation still needs an actual playable reserve");
    check(ready(400000,300000,6,1800000),"Sustained source with six seconds of verified data qualifies");
    check(!ready(400000,300000,5.99,1800000),"Marginal rate does not use the brief fast-source path");
    check(ready(1200000,300000,2,3600000),"Fast source with a larger reserve avoids a fixed six-second wait");
    check(!ready(1200000,300000,2,3599999),"Fast speed alone cannot substitute for missing reserve bytes");
    check(!ready(1000000,300000,1.99,4000000),"Fast lane still measures an independent transfer window");
    check(ready(0,300000,0,0,true),"Completed file remains available offline");
    check(!ready(INFINITY,300000,9,4000000),"Nonfinite speed cannot qualify");
    check(!ready(1000000,NAN,9,4000000),"Nonfinite required rate cannot qualify");
    RWTransferWindow burst;burst.observe(0,0);int64_t bytes=0;bool accepted=false;
    for(int t=1;t<=9;t++){bytes+=t<=3?1800000:100000;double rate=burst.observe(t,bytes);accepted|=ready(rate,1295997,burst.measuredSeconds(),bytes);}
    check(!accepted,"Three-second burst followed by insufficient delivery is never admitted");
    RWTransferWindow fast;fast.observe(0,0);int first=0;
    for(int t=1;t<=6;t++){double rate=fast.observe(t,int64_t(t)*4000000);if(ready(rate,250000,fast.measuredSeconds(),uint64_t(t)*4000000)&&!first)first=t;}
    check(first==2,"Steadily fast source is admitted after two seconds");
#ifndef RW_LEGACY_POLICY
    int calls=0;
    check(RWVerifiedPrefix(100,1000,512,[&](int64_t p){calls++;return p<2;})==924&&calls==3,"Prefix stops at first hole with exact file offset");
    check(RWVerifiedPrefix(100,400,512,[](int64_t){return true;})==400,"Prefix never counts bytes from following file");
    check(RWVerifiedPrefix(0,1ULL<<32,16384,[](int64_t){return true;})==RWProbeTransferBudget,"Prefix walk remains bounded for enormous cached files");
    check(RWVerifiedPrefix(-1,1000,512,[](int64_t){return true;})==0,"Negative offset rejected");
    check(RWVerifiedPrefix(0,1000,0,[](int64_t){return true;})==0,"Zero piece size rejected");
    check(RWVerifiedPrefix(2048,100,512,[](int64_t p){return p==4;})==100,"Later episode prefix starts at its own offset");
#endif
    std::printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}
