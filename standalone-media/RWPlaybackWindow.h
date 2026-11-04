#pragma once
#include "RWByteRange.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <vector>
// This bounds wanted transfer, not filesystem allocation: an old filesystem
// may allocate a whole file when the decoder reads its closing index.
constexpr uint64_t RWPlaybackWantedBudget=64ULL*1024*1024;
class RWPlaybackWindow {
    struct Request {int64_t offset;uint32_t length;double seen;};
    std::vector<Request> requests;
public:
    void clear(){requests.clear();}
    void request(int64_t offset,uint32_t length,double now) {
        if(offset<0||length==0||!std::isfinite(now))return;
        requests.erase(std::remove_if(requests.begin(),requests.end(),[&](const Request &r){
            return now-r.seen>2||now<r.seen||(offset>=r.offset&&offset-r.offset<int64_t(r.length))||(r.offset>=offset&&r.offset-offset<int64_t(length));
        }),requests.end());
        requests.push_back({offset,std::min<uint32_t>(length,4*1024*1024),now});
        if(requests.size()>4)requests.erase(requests.begin());
    }
    std::vector<int> plan(int64_t fileOffset,int64_t size,int pieceBytes,double bitrate,double now,const std::vector<int>& startup={}) const {
        std::vector<int> result;
        if(pieceBytes<=0||pieceBytes>16*1024*1024||size<=0||fileOffset<0||fileOffset>INT64_MAX-size||!std::isfinite(now))return result;
        uint64_t budget=RWPlaybackWantedBudget/uint64_t(pieceBytes);
        auto add=[&](int64_t piece){if(piece<0||piece>INT32_MAX||result.size()>=budget)return;
            if(std::find(result.begin(),result.end(),int(piece))==result.end())result.push_back(int(piece));};
        // Every current reader gets its immediately blocked piece before any
        // reader gets speculative data. This preserves simultaneous index reads.
        for(auto it=requests.rbegin();it!=requests.rend();++it)if(now>=it->seen&&now-it->seen<=2&&it->offset<size)add((fileOffset+it->offset)/pieceBytes);
        for(auto it=requests.rbegin();it!=requests.rend();++it){
            if(now<it->seen||now-it->seen>2)continue;int64_t first=0,last=0;
            if(RWPieceRange(fileOffset,size,it->offset,it->length,pieceBytes,&first,&last))for(int64_t p=first;p<=last;p++)add(p);
        }
        // Actual reader ranges come first, then the winner's bounded index,
        // then speculative forward data. All share the same whole-piece cap.
        int64_t fileFirst=fileOffset/pieceBytes,fileLast=(fileOffset+size-1)/pieceBytes;
        for(int piece:startup)if(piece>=fileFirst&&piece<=fileLast)add(piece);
        double target=std::isfinite(bitrate)&&bitrate>0?bitrate*20:8*1024*1024;
        uint32_t ahead=uint32_t(std::max(8.*1024*1024,std::min(32.*1024*1024,target)));
        for(auto it=requests.rbegin();it!=requests.rend();++it){
            if(now<it->seen||now-it->seen>2)continue;int64_t first=0,last=0;
            if(RWPieceRange(fileOffset,size,it->offset,ahead,pieceBytes,&first,&last))for(int64_t p=first;p<=last;p++)add(p);
        }
        return result;
    }
};
