#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
// Incremental container-header walk. Caller supplies only hash-verified bytes
// at offset(); payload is skipped by its declared bounded container size.
// At most64 headers/64 bytes each; torrent whole-piece cost is bounded by caller.
class RWMediaDuration {
public:
    enum Format { MP4, Matroska, Unsupported };
    enum State { Waiting, Known, Unavailable };
private:
    Format format;State state_=Waiting;uint64_t size,cursor=0,end;
    unsigned steps=0;bool movie=false,segment=false,info=false;
    double duration_=0,ticks=0;uint64_t scale=1000000;
    static uint64_t be(const uint8_t *b,size_t n){uint64_t x=0;while(n--)x=(x<<8)|*b++;return x;}
    static bool vint(const uint8_t *b,size_t n,size_t &p,bool id,uint64_t &v,bool &unknown){
        if(p>=n||!b[p])return false;uint8_t mask=128;size_t len=1;while(!(b[p]&mask)){mask>>=1;len++;}
        if(len>(id?4:8)||len>n-p)return false;
        v=id?b[p]:(b[p]&~mask);p++;for(size_t i=1;i<len;i++)v=(v<<8)|b[p++];
        unknown=!id&&v==((uint64_t(1)<<(len*7))-1);return true;
    }
    void known(double seconds){if(std::isfinite(seconds)&&seconds>0&&seconds<=36000){duration_=seconds;state_=Known;}else state_=Unavailable;}
    void finishInfo(){known(ticks*double(scale)/1e9);}
public:
    RWMediaDuration(Format f,uint64_t bytes):format(f),size(bytes),end(bytes){if(f==Unsupported||bytes<8)state_=Unavailable;}
    State state() const{return state_;}
    uint64_t offset() const{return cursor;}
    size_t length() const{return state_==Waiting?size_t(std::min<uint64_t>(64,end-cursor)):0;}
    double seconds() const{return duration_;}
    unsigned headers() const{return steps;}
    void unavailable(){state_=Unavailable;}
    void consume(const uint8_t *b,size_t n){
        if(state_!=Waiting)return;if(!b||n<length()){return;}
        if(++steps>64||cursor>=end){state_=Unavailable;return;}
        if(format==MP4){
            if(n<8){state_=Unavailable;return;}uint64_t bytes=be(b,4);uint64_t type=be(b+4,4);size_t header=8;
            if(bytes==1){if(n<16){state_=Unavailable;return;}bytes=be(b+8,8);header=16;}
            if(bytes==0)bytes=end-cursor;
            if(bytes<header||bytes>end-cursor){state_=Unavailable;return;}
            if(!movie&&type==0x6d6f6f76){movie=true;end=cursor+bytes;cursor+=header;}
            else if(movie&&type==0x6d766864){
                if(n<=header){state_=Unavailable;return;}unsigned version=b[header];size_t needed=version==0?20:version==1?32:0;
                if(!needed||needed>bytes-header||needed>n-header){state_=Unavailable;return;}
                uint64_t timescale=be(b+header+(version?20:12),4),duration=be(b+header+(version?24:16),version?8:4);
                if(!timescale||duration==(version?UINT64_MAX:UINT32_MAX)){state_=Unavailable;return;}known(double(duration)/double(timescale));return;
            }else cursor+=bytes;
        }else{
            size_t p=0;uint64_t id=0,bytes=0;bool unused=false,unknown=false;
            if(!vint(b,n,p,true,id,unused)||!vint(b,n,p,false,bytes,unknown)){state_=Unavailable;return;}
            if(unknown){if(id!=0x18538067||segment){state_=Unavailable;return;}bytes=end-cursor-p;}
            if(p>end-cursor||bytes>end-cursor-p){state_=Unavailable;return;}
            if(!segment&&id==0x18538067){segment=true;end=cursor+p+bytes;cursor+=p;}
            else if(segment&&!info&&id==0x1549a966){info=true;end=cursor+p+bytes;cursor+=p;}
            else if(info&&(id==0x4489||id==0x2ad7b1)){
                if(bytes>8||bytes>n-p||!bytes){state_=Unavailable;return;}uint64_t bits=be(b+p,size_t(bytes));
                if(id==0x2ad7b1){if(!bits){state_=Unavailable;return;}scale=bits;}
                else if(bytes==8){std::memcpy(&ticks,&bits,8);}
                else if(bytes==4){uint32_t word=uint32_t(bits);float f;std::memcpy(&f,&word,4);ticks=f;}
                else {state_=Unavailable;return;}
                cursor+=p+bytes;
            }else cursor+=p+bytes;
        }
        if(cursor>=end){if(info)finishInfo();else state_=Unavailable;}
        else if(steps>=64)state_=Unavailable;
    }
};
