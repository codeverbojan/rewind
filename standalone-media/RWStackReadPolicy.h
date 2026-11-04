#pragma once
#include <stdint.h>
static inline int RWStackFrameReadable(uint64_t frame,uint64_t lower,uint64_t upper) {
    return upper>=8&&upper>lower&&upper-lower<=16*1024*1024&&frame>=lower&&frame<=upper-8&&(frame&3)==0;
}
static inline int RWStackFrameFollows(uint64_t next,uint64_t current,uint64_t lower,uint64_t upper) {
    return next>current&&next-current<=65536&&RWStackFrameReadable(next,lower,upper);
}
