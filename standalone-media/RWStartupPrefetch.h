#pragma once
#include "RWByteRange.h"
#include <vector>
#include <cmath>
// A winner's small index request has a different lifetime from active decoder
// cursors. It survives header parsing, but never extends the existing15s
// header-preparation limit or the shared64MiB wanted-piece budget.
class RWStartupPrefetch {
public:
    enum State { Inactive, Pending, Downloaded, Expired, Cancelled };
private:
    std::vector<int> pieces_;
    double began_=0;
    State state_=Inactive;
public:
    void begin(int64_t fileOffset,int64_t size,int pieceBytes,double now) {
        pieces_.clear();state_=Inactive;began_=0;
        int64_t first=0,last=0;
        if(size<=65536||pieceBytes<=0||pieceBytes>16*1024*1024||!std::isfinite(now)||
           !RWPieceRange(fileOffset,size,size-65536,65536,pieceBytes,&first,&last)||
           first<0||last>INT32_MAX||last-first>=65)return;
        for(int64_t p=first;p<=last;p++)pieces_.push_back(int(p));
        began_=now;state_=Pending;
    }
    template<class Have>void update(double now,Have have) {
        if(state_!=Pending)return;
        bool complete=true;for(int p:pieces_)if(!have(p))complete=false;
        if(complete){state_=Downloaded;pieces_.clear();}
        else if(!std::isfinite(now)||now<began_||now-began_>=15){state_=Expired;pieces_.clear();}
    }
    void cancel(){pieces_.clear();if(state_==Pending)state_=Cancelled;}
    State state()const{return state_;}
    const std::vector<int>& pieces()const{return pieces_;}
};
