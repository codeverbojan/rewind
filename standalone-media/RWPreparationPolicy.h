#pragma once
#include "RWByteRange.h"
#include <algorithm>
#include <cstdint>
constexpr uint64_t RWPreparationByteBudget=32ULL*1024*1024;
constexpr double RWPreparationTransferSeconds=20;
constexpr double RWPreparationLifetimeSeconds=45;
struct RWPreparationRange {int first=-1,headerLast=-1,last=-1;uint64_t transferBound=0,fileEnd=0;bool allowed=false;};
inline RWPreparationRange RWPrepareOpening(int64_t fileOffset,int64_t size,int pieceBytes,uint64_t budget) {
    RWPreparationRange r;int64_t first=0,last=0;
    if(pieceBytes<=0||pieceBytes>16*1024*1024||budget>RWPreparationByteBudget||!RWPieceRange(fileOffset,size,0,uint32_t(std::min<int64_t>(size,65536)),pieceBytes,&first,&last)||last>INT32_MAX)return r;
    int64_t videoLast=(fileOffset+size-1)/pieceBytes;
    r.first=int(first);r.headerLast=int(last);r.last=int(std::min(videoLast,last+1));
    r.transferBound=uint64_t(r.last-r.first+1)*uint64_t(pieceBytes);
    r.fileEnd=uint64_t(std::min<int64_t>(size,(int64_t(r.last)+1)*pieceBytes-fileOffset));
    r.allowed=r.transferBound<=budget&&r.fileEnd<=budget;return r;
}
inline bool RWPreparationMayTransfer(uint64_t payload,uint64_t allocatedGrowth,uint64_t freeBytes,double elapsed,uint64_t budget) {
    return budget>0&&budget<=RWPreparationByteBudget&&payload<budget&&allocatedGrowth<budget&&freeBytes>=1024ULL*1024*1024&&elapsed>=0&&elapsed<RWPreparationTransferSeconds;
}
