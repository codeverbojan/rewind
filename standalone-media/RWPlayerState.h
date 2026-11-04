#pragma once
#include <cmath>
#include "RWPlaybackLimits.h"
inline bool RWInitialWaitExpired(double total,double attempt,double idle) {
    return total>=RWStartupLimitSeconds || attempt>=RWSourceOpeningLimitSeconds || (attempt>=18&&idle>=12);
}
inline bool RWPlaybackStalled(bool started,bool wantsPlay,bool seeking,double idle) {
    return started&&wantsPlay&&!seeking&&idle>20;
}
inline bool RWNativeSeekExpired(bool pending,bool wantsPlay,double elapsed) {
    return pending&&wantsPlay&&elapsed>=120;
}
enum class RWSourceUpdate { Keep, Append, Start, Unavailable };
inline RWSourceUpdate RWSourceUpdateDecision(bool remaining,bool discovering,bool waiting,
                                            bool exhausted,bool active,double elapsed,int attempts) {
    // Provider completions must not replace an opening/playing decoder, reset
    // the startup budget, or resurrect candidates already tried this session.
    if(active)return RWSourceUpdate::Keep;
    if(discovering)return remaining?RWSourceUpdate::Append:RWSourceUpdate::Keep;
    bool budget=elapsed<RWStartupLimitSeconds&&attempts<5;
    if(waiting)return remaining&&budget?RWSourceUpdate::Start:RWSourceUpdate::Unavailable;
    if(exhausted&&remaining&&budget)return RWSourceUpdate::Start;
    return RWSourceUpdate::Keep;
}
struct RWPlaybackMotion {
    double position=-1, advancedAt=0;
    void reset(double now){position=-1;advancedAt=now;}
    bool spinner(double now,double current,bool verified,bool frame,bool wantsPlay,bool seeking,bool exhausted){
        if(std::isfinite(current)&&(position<0||std::fabs(current-position)>.05)){position=current;advancedAt=now;}
        if(exhausted||!wantsPlay||seeking)return false;
        if(!verified||!frame)return true;
        // iOS 9 may keep playbackBufferEmpty true while video advances normally.
        return now-advancedAt>=1.5;
    }
};
