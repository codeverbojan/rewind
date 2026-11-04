#pragma once
#include <algorithm>
#include <cstdint>
#include <cstddef>
#include <cmath>
#include "RWPlaybackLimits.h"
constexpr int RWMaxTorrentPieceBytes=16*1024*1024;
constexpr int RWVerifiedPieceCacheBytes=16*1024*1024;
constexpr uint64_t RWProbeTransferBudget=32ULL*1024*1024;
// Queue enough work for the fast-source twelve-second verified reserve.
// Refilling a smaller probe once per UI poll can throttle a healthy peer.
// This is a bounded request target, not permission to skip qualification;
// whole-piece rounding still stays inside the per-candidate transfer budget.
inline uint64_t RWProbeDemandTarget(double required) {
    double bytes=std::isfinite(required)&&required>0?required*12.:0;
    return uint64_t(std::max(2.*1024*1024,std::min(8.*1024*1024,bytes)));
}
inline bool RWProbeMayExtend(uint64_t requested,uint64_t outstanding,uint64_t pieceBytes,double required) {
    return pieceBytes>0&&pieceBytes<=uint64_t(RWMaxTorrentPieceBytes)&&
        requested<=RWProbeTransferBudget&&pieceBytes<=RWProbeTransferBudget-requested&&
        outstanding<RWProbeDemandTarget(required);
}
inline double RWRequiredStreamRate(uint64_t videoBytes,double durationSeconds) {
    return durationSeconds>=60&&durationSeconds<=36000?double(videoBytes)/durationSeconds:0;
}
// Estimate the remaining transfer for a verified opening plus a short useful
// buffer. This is a transfer estimate, not a promise about unknown MP4/MKV indexes.
inline double RWStartupTransferETA(uint64_t missingOpening,uint64_t verifiedVideo,double required,double rate) {
    double desired=required>0?required*3.:512*1024.;
    double missing=std::max(double(missingOpening),std::max(0.,desired-double(verifiedVideo)));
    if(missing<=0)return 0;
    return std::isfinite(rate)&&rate>0?missing/rate:-1;
}
inline double RWReadinessScore(bool ready,bool complete,double eta,double rate,double required,double hint) {
    if(!ready)return -1;
    if(complete)return 2000000.;
    if(!std::isfinite(eta)||eta<0||!std::isfinite(rate)||rate<=0)return -1;
    double margin=required>0?std::min(4.,rate/required):1.;
    return 1000000./(1.+eta)+margin*1000.+std::max(0.,std::min(100.,hint));
}
inline bool RWStreamingReady(bool header,bool complete,int peers,double rate,double required,double measured,uint64_t verifiedAhead=0) {
    if(!header)return false;if(complete)return true;
    if(peers<=0||!std::isfinite(rate)||rate<=0||!std::isfinite(measured)||measured<2)return false;
    // Unknown duration still needs a media-derived estimate (tracked separately
    // in P04). Preserve that existing path rather than invent a bitrate here.
    if(required<=0)return true;
    if(!std::isfinite(required)||rate<required*1.25)return false;
    // A brief spike with only a verified header was enough to qualify an8GB
    // source that then stalled. Require both observed capacity and an actual
    // contiguous reserve. A very fast source can establish a larger reserve
    // sooner; ordinary candidates need a longer independent observation.
    return (measured>=6&&double(verifiedAhead)>=required*6)||
           (rate>=required*2.5&&double(verifiedAhead)>=required*12);
}
template<typename HasPiece> uint64_t RWVerifiedPrefix(int64_t offset,uint64_t size,int pieceBytes,HasPiece has) {
    if(offset<0||!size||pieceBytes<=0)return 0;
    uint64_t bytes=0,limit=std::min(size,RWProbeTransferBudget);
    int64_t piece=offset/pieceBytes;int within=int(offset%pieceBytes);
    while(bytes<limit&&has(piece)){
        bytes+=std::min<uint64_t>(limit-bytes,uint64_t(pieceBytes-within));within=0;piece++;
    }return bytes;
}
inline bool RWProbeTooSlow(double measured,double rate,double required,uint64_t missingOpening,double remaining=30) {
    if(measured<8||rate<=0)return false;
    return (required>0&&rate<required*.65)||double(missingOpening)/rate>remaining;
}
inline bool RWCanFinishOpening(double measured,double rate,double required,uint64_t missing,double remaining,double idle) {
    return measured>=2&&rate>0&&idle<3&&(required<=0||rate>=required*1.25)&&double(missing)/rate+5<remaining;
}
inline bool RWLocalCheckExpired(double elapsed,double idle,double remaining) {
    return remaining<=0||(elapsed>=16&&idle>=12);
}
// Verify enough of the actual file header to begin media preparation. The
// player still requests verified pieces and checks the actual codecs later.
inline uint32_t RWProbeHeadBytes(uint64_t size) {return uint32_t(std::min<uint64_t>(size,64*1024));}
// A cached opening cannot measure today's connection. Request one missing
// piece of this video so a partial cache can still qualify on live throughput.
template<typename HasPiece> int RWProbeMeasurementPiece(int first,int last,bool headerComplete,HasPiece has) {
    if(!headerComplete)return -1;
    for(int piece=first;piece<=last;piece++)if(!has(piece))return piece;
    return -1;
}
template<typename HasPiece> int RWProbeAheadPiece(int first,int headerLast,int videoLast,bool cachedHeader,HasPiece has) {
    // Keep one requested piece beyond a cold header so reaching the header
    // does not make the torrent "finished" and drop interest in the seed.
    return RWProbeMeasurementPiece(cachedHeader?first:headerLast+1,videoLast,true,has);
}
inline int RWProbeDeadline(size_t index,size_t headCount) {return index<headCount?int(index*200):1000+int((index-headCount)*200);}
// Monotonic, progress-sensitive deadlines shared with host tests.
inline bool RWProbeExpired(double elapsed, bool metadata, int peers, double idle,bool canFinish=false) {
    if(elapsed>=RWDiscoveryLimitSeconds||(elapsed>=40&&!canFinish)) return true;
    if(!metadata) return elapsed >= (peers>0?22:14);
    return elapsed>=16 && idle>=12;
}
