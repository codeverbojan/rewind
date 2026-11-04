#include "../RWOpeningEstimate.h"
#include "../RWDiscoveryPolicy.h"
#include <cstdio>
int main(){int checks=0,failures=0;auto check=[&](bool ok,const char *why){checks++;if(!ok){failures++;fprintf(stderr,"FAIL:%s\n",why);}};
 RWOpeningEstimate forecast;
 check(!forecast.observe(0,false,true,true).lateConfirmed,"An initial adverse prediction is not a proven lost source");
 check(!forecast.observe(1,false,true,true).lateConfirmed,"One-second jitter remains provisional");
 check(!forecast.observe(3.99,false,true,true).lateConfirmed,"Confirm only a full rate window");
 check(forecast.observe(4,false,true,true).lateConfirmed,"Sustained bad prediction still rejects within bound");
 check(forecast.observe(5,true,false,true).canFinish,"Positive estimate is retained");
 check(forecast.observe(6,false,false,true).canFinish,"One pessimistic forecast does not kill the final source");
 check(forecast.observe(8.99,false,false,true).canFinish,"Recent capacity evidence has bounded grace");
 check(!forecast.observe(9,false,false,true).canFinish,"Four-second-old evidence expires");
 forecast.observe(10,true,false,true);
 check(!forecast.observe(11,false,true,false).canFinish,"New alternatives or lost viability remove grace immediately");
 check(forecast.observe(12,false,true,false).lateConfirmed,"Ordinary multi-source rejection unchanged");
 forecast.observe(13,true,false,true);
 check(!forecast.observe(17,false,true,true).canFinish,"Unobserved gaps do not grant historical capacity");
 check(!forecast.observe(17,false,true,true).lateConfirmed,"Unobserved gap does not count as four seconds of failures");
 forecast.observe(18,true,false,true);
 check(!forecast.observe(1,false,true,true).canFinish,"Clock reset discards previous connection state");
 check(forecast.observe(NAN,false,true,true).lateConfirmed,"Invalid time retains original immediate-rejection behavior");
 RWOpeningEstimate alternating;bool rejected=false,retained=true;
 for(int i=0;i<80;i++){double now=double(i)*.25;bool good=i%4!=0;auto r=alternating.observe(now,good,!good,true);rejected|=r.lateConfirmed;if(i>0)retained=retained&&r.canFinish;}
 check(retained,"Observed alternating viable rate does not falsely expire");
 check(!rejected,"Short rate oscillations never accumulate into a continuous failure");
 RWOpeningEstimate newSource;check(!newSource.observe(100,false,false,true).canFinish,"A fresh source cannot inherit earlier confidence");
 check(RWProbeExpired(100,true,1,0,true),"Recent forecast cannot extend overall100second bound");
 check(!RWStreamingReady(false,false,1,200000,100000,90,0),"Recent forecast cannot admit an unverified opening");
 check(RWProbeTooSlow(12,60000,100000,16000000,88),"Insufficient bitrate retains immediate rejection");
 check(!newSource.observe(101,false,false,false).canFinish,"Loss of fresh payload removes forecast grace");
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}
