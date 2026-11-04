#pragma once
#include <cmath>
// Observed intervals, not exact disk/peer event durations. Long polling gaps
// remain unknown rather than being charged to cache validation or the network.
struct RWProbeTiming {
    double start=0,last=-1,checkingSeconds=0,heldSeconds=0,unknownSeconds=0;
    double metadata=-1,peer=-1,payload=-1,opening=-1;
    bool wasChecking=false,wasHeld=false;
    void begin(double now){*this=RWProbeTiming();start=now;}
    void observe(double now,bool checking,bool held,bool hasMetadata,bool hasPeer,bool hasPayload,bool hasOpening){
        if(!std::isfinite(now)||now<start||(last>=0&&now<last))return;
        if(last<0)unknownSeconds+=now-start;
        if(last>=0){double delta=now-last;if(delta<=3){if(wasChecking)checkingSeconds+=delta;if(wasHeld)heldSeconds+=delta;}else unknownSeconds+=delta;}
        double elapsed=now-start;
        if(hasMetadata&&metadata<0)metadata=elapsed;
        if(hasPeer&&peer<0)peer=elapsed;
        if(hasPayload&&payload<0)payload=elapsed;
        if(hasOpening&&opening<0)opening=elapsed;
        last=now;wasChecking=checking;wasHeld=held;
    }
};
