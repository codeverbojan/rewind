#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>

// Bounded payload observations. Tracker counts and libtorrent's instantaneous
// rate cannot turn a stale connection or one burst into sustained capacity.
class RWTransferWindow {
    struct Sample { double time; int64_t bytes; };
    std::array<Sample,12> samples{};
    size_t count=0;
    bool initialized=false,active=false;
    double lastTime=0,lastProgress=0,started=0,smoothed=0,estimate=0;
    int64_t lastBytes=0;
public:
    double observe(double time,int64_t bytes) {
        if(!std::isfinite(time)||bytes<0)return estimate;
        if(!initialized||bytes<lastBytes||time-lastTime>5){
            initialized=true;active=false;count=0;estimate=smoothed=0;
            lastTime=time;lastBytes=bytes;return 0;
        }
        if(time<=lastTime||time-lastTime<.2)return estimate;
        double dt=time-lastTime;int64_t delta=bytes-lastBytes;
        if(!active&&delta>0){active=true;started=lastTime;count=1;samples[0]={lastTime,lastBytes};smoothed=double(delta)/dt;}
        if(active){
            double alpha=dt/(2.+dt);smoothed+=alpha*(double(delta)/dt-smoothed);
            if(delta>0)lastProgress=time;
            if(count==samples.size()){for(size_t i=1;i<count;i++)samples[i-1]=samples[i];count--;}
            samples[count++]={time,bytes};
            size_t oldest=0;while(oldest+1<count-1&&samples[oldest+1].time<=time-4)oldest++;
            double span=time-samples[oldest].time;
            double recent=span>0?double(bytes-samples[oldest].bytes)/span:0;
            estimate=time-lastProgress>=3?0:std::max(0.,std::min(smoothed,recent));
        }
        lastTime=time;lastBytes=bytes;return estimate;
    }
    double measuredSeconds() const {return active?std::max(0.,lastTime-started):0;}
};
