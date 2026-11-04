#include "../RWProbeFocus.h"
#include "../RWDiscoveryPolicy.h"
#include <cstdio>
int main(){int checks=0,failures=0;auto check=[&](bool b){checks++;if(!b)failures++;};
 RWFocusCandidate a;a.valid=true;a.rate=200000;a.required=300000;a.measured=4;
 RWFocusCandidate b=a;b.required=600000;std::vector<RWFocusCandidate> p{a,b};
 check(RWChooseProbeFocus(p,false,false,40)==0);check(RWChooseProbeFocus(p,true,false,40)==-1);check(RWChooseProbeFocus(p,false,true,40)==-1);check(RWChooseProbeFocus(p,false,false,11)==-1);
 check(RWChooseProbeFocus({a},false,false,40)==-1);p[1].healthy=true;check(RWChooseProbeFocus(p,false,false,40)==-1);p[1].healthy=false;p[1].complete=true;check(RWChooseProbeFocus(p,false,false,40)==-1);
 p={a,b};p[0].measured=3;check(RWChooseProbeFocus(p,false,false,40)==-1);p[1].measured=3;check(RWChooseProbeFocus(p,false,false,40)==-1);
 p={a,b};p[1].rate=0;check(RWChooseProbeFocus(p,false,false,40)==-1);p[1].rate=NAN;check(RWChooseProbeFocus(p,false,false,40)==-1);p[1].rate=INFINITY;check(RWChooseProbeFocus(p,false,false,40)==-1);
 p={a,b};p[0].checking=true;check(RWChooseProbeFocus(p,false,false,40)==-1);p={a,b};p[0].required=0;check(RWChooseProbeFocus(p,false,false,40)==-1);
 // Measured late-peer failure: all current throughput cannot sustain the
 // older candidate. Throttling the other connection cannot establish health.
 p={a,b};p[0].rate=120000;p[0].required=600000;p[1].rate=20000;p[1].required=200000;
 check(RWChooseProbeFocus(p,false,false,40)==-1);
 // An adequate connection waiting for its opening piece keeps its rate sample.
 p={a,b};p[0].rate=400000;check(RWChooseProbeFocus(p,false,false,40)==-1);
 // A younger stronger candidate must not be held for an older weaker one.
 p={a,b};p[0].rate=400000;p[0].required=600000;p[1].rate=350000;p[1].required=300000;p[1].measured=3;
 check(RWChooseProbeFocus(p,false,false,40)==-1);
 p[1].measured=4;check(RWChooseProbeFocus(p,false,false,40)==1);
 // Shared bandwidth can genuinely support one of the competing candidates.
 p={a,a,a};check(RWChooseProbeFocus(p,false,false,40)==0);
 check(!RWStreamingReady(true,false,3,300000,300000,6,1800000));check(RWStreamingReady(true,false,3,375000,300000,6,1800000));check(!RWStreamingReady(false,false,3,600000,300000,6,1800000));check(!RWStreamingReady(true,false,3,600000,300000,1,1800000));
 check(RWProbeFocusUnproductive(4,3,120000,600000,120000));
 check(!RWProbeFocusUnproductive(3.9,3,120000,600000,120000));
 check(!RWProbeFocusUnproductive(4,2,120000,600000,120000));
 check(!RWProbeFocusUnproductive(4,3,400000,300000,200000));
 check(!RWProbeFocusUnproductive(4,3,190000,600000,120000));
 check(!RWProbeFocusUnproductive(4,3,390000,600000,400000));
 check(RWProbeFocusUnproductive(6,3,190000,600000,120000));
 check(!RWProbeFocusUnproductive(5.99,3,190000,600000,120000));
 check(!RWProbeFocusUnproductive(6,2.99,190000,600000,120000));
 check(!RWProbeFocusUnproductive(6,3,390000,600000,120000));
 check(RWProbeFocusUnproductive(6,0,0,600000,120000));
 check(!RWProbeFocusUnproductive(4,0,0,600000,120000));
 check(!RWProbeFocusUnproductive(NAN,3,0,600000,120000));
 check(!RWProbeFocusUnproductive(4,3,NAN,600000,120000));
 check(!RWProbeFocusUnproductive(4,3,0,0,120000));
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;}
