#pragma once
#include <cmath>
// iOS9 AVPlayer may remain at rate0 after its custom-resource buffer refills.
// Use actual buffered time, not playbackBufferEmpty/likelyToKeepUp (both were
// contradictory in the physical122 failure). No repeated play() loop.
struct RWNativeBufferRecovery {
    double position=-1,lastAttempt=-1;
    unsigned attempts=0,requests=0;
    bool resume(double now,double current,double rate,bool ready,bool wantsPlay,
                bool seeking,double buffered,double remaining) {
        if(!std::isfinite(now)||!std::isfinite(current)||!std::isfinite(buffered)||!std::isfinite(remaining))return false;
        if(position<0||std::fabs(current-position)>.2){position=current;attempts=0;lastAttempt=-1;}
        if(!ready||!wantsPlay||seeking||rate!=0||attempts>=2||remaining<=.1)return false;
        double needed=remaining<5?remaining-.05:5;
        if(buffered<needed||(lastAttempt>=0&&now-lastAttempt<3))return false;
        attempts++;requests++;lastAttempt=now;return true;
    }
    bool grace(double now) const {return attempts&&lastAttempt>=0&&now>=lastAttempt&&now-lastAttempt<3;}
};
