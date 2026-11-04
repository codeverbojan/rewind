#pragma once
#include <vector>
#include <cmath>
// One bounded remeasurement of an existing connection. Aggregate throughput
// only selects an experiment; it never qualifies a stream for playback.
constexpr double RWProbeFocusSeconds=12;
constexpr double RWProbeFocusObservationSeconds=4;
constexpr int RWProbeHeldBytesPerSecond=1024;
// Restore competitors when exclusive bandwidth does not improve a clearly
// insufficient connection. This ends the experiment, not the torrent; normal
// measured readiness and slow-source rejection still decide its fate.
inline bool RWProbeFocusUnproductive(double elapsed,double measured,double rate,double required,double previous) {
    if(!std::isfinite(elapsed)||!std::isfinite(measured)||!std::isfinite(rate)||!std::isfinite(required)||!std::isfinite(previous)||elapsed<RWProbeFocusObservationSeconds||rate<0||required<=0||previous<=0)return false;
    if(rate==0&&elapsed>=6)return true;
    if(elapsed>=6&&measured>=3&&rate<required*.65)return true;
    return measured>=3&&rate<required*.65&&rate<previous*1.25;
}
struct RWFocusCandidate {
    bool valid=false,healthy=false,complete=false,checking=false;
    double rate=0,required=0,measured=0;
};
inline int RWChooseProbeFocus(const std::vector<RWFocusCandidate>& probes,bool preparing,bool attempted,double remaining) {
    if(preparing||attempted||remaining<RWProbeFocusSeconds)return -1;
    size_t transferring=0;int best=-1;double margin=-1,totalRate=0;
    for(const auto &p:probes){
        if(p.healthy||p.complete)return -1;
        if(p.valid&&!p.checking&&p.rate>0&&std::isfinite(p.rate)&&p.measured>=2){
            transferring++;totalRate+=p.rate;
            // Sufficient delivery can still be waiting on a whole opening
            // piece. Resetting its measurement for focus only delays readiness.
            if(p.measured>=4&&std::isfinite(p.required)&&p.required>0&&p.rate>=p.required*1.25)return -1;
        }
    }
    if(transferring<2)return -1;
    for(size_t i=0;i<probes.size();i++){const auto &p=probes[i];
        if(!p.valid||p.checking||!std::isfinite(p.rate)||!std::isfinite(p.required)||p.rate<=0||p.required<=0||p.measured<4)continue;
        double ratio=p.rate/p.required;if(ratio>margin){margin=ratio;best=int(i);}
    }
    if(best<0||!std::isfinite(totalRate)||totalRate<probes[size_t(best)].required*1.25)return -1;
    // Do not throttle a newer, more promising connection merely because the
    // older slow one reached the four-second observation threshold first.
    for(const auto &p:probes)if(p.valid&&!p.checking&&std::isfinite(p.rate)&&std::isfinite(p.required)&&p.rate>0&&p.required>0&&p.measured>=2&&p.measured<4&&p.rate/p.required>margin)return -1;
    return best;
}
