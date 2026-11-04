#pragma once
#include <cmath>
#include <algorithm>
// A changing transfer ETA is a prediction, not a failed piece or disconnected
// peer. Confirm adverse forecasts over one existing four-second rate window.
// No global discovery/idle/hash/readiness bound is changed.
class RWOpeningEstimate {
    double last=-1,good=-1,late=-1;
public:
    struct Result {bool canFinish=false,lateConfirmed=false;double adverseSeconds=0,goodAge=-1;};
    Result observe(double now,bool rawCanFinish,bool rawLate,bool reliable) {
        Result r;r.canFinish=rawCanFinish;r.lateConfirmed=rawLate;
        if(!std::isfinite(now))return r;
        if(last>=0&&(now<last||now-last>3)){good=late=-1;}
        last=now;
        if(!reliable){good=late=-1;return r;}
        if(rawCanFinish)good=now;
        if(rawLate){if(late<0)late=now;}else late=-1;
        r.adverseSeconds=late>=0?std::max(0.,now-late):0;
        r.goodAge=good>=0?now-good:-1;
        r.lateConfirmed=rawLate&&r.adverseSeconds>=4;
        r.canFinish=rawCanFinish||(r.goodAge>=0&&r.goodAge<4);
        return r;
    }
};
