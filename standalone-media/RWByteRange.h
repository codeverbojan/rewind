#pragma once
#include <stdint.h>
// Offsets stay 64-bit even when NSUInteger/pointers are 32-bit on ARMv7.
static inline bool RWRangeEnd(int64_t start,int64_t length,bool toEnd,int64_t size,int64_t *end){
    if(start<0||size<0||start>size||length<0)return false;
    *end=toEnd?size:start+(length<size-start?length:size-start);return true;
}
static inline bool RWCanStore(uint64_t size,uint64_t freeBytes,uint64_t allocated){
    const uint64_t reserve=512ULL*1024*1024;
    uint64_t remaining=size-(allocated<size?allocated:size);
    return freeBytes>=reserve&&remaining<=freeBytes-reserve;
}
static inline bool RWPieceRange(int64_t fileOffset,int64_t fileSize,int64_t offset,uint32_t length,int pieceLength,int64_t *first,int64_t *last){
    if(fileOffset<0||fileSize<=0||offset<0||offset>=fileSize||pieceLength<=0||length==0||fileOffset>INT64_MAX-fileSize)return false;
    int64_t end=0;RWRangeEnd(offset,length,false,fileSize,&end);
    *first=(fileOffset+offset)/pieceLength;*last=(fileOffset+end-1)/pieceLength;return true;
}
