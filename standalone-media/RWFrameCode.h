#pragma once
#include <stdint.h>
#include <stddef.h>
// Diagnostic-only authored video: 16-bit word A000|frame, then its complement.
// Centre samples must be confidently black/white; ambiguous or corrupt codes
// are evidence failures, never guessed frame numbers.
static inline int RWDecodeFrameCode(const uint8_t *rgba,size_t width,uint8_t *levels) {
    if(!rgba||width<64||width>1024)return -1;
    uint32_t bits=0;
    for(size_t i=0;i<32;i++){
        size_t x=((2*i+1)*width)/64;
        const uint8_t *p=rgba+4*x;
        unsigned value=((unsigned)p[0]+p[1]+p[2])/3;
        if(levels)levels[i]=(uint8_t)value;
        if(value>64&&value<192)return -1;
        bits=(bits<<1)|(value>=192);
    }
    uint16_t word=(uint16_t)(bits>>16),inverse=(uint16_t)bits;
    if((word&0xf000)!=0xa000||(uint16_t)(word^inverse)!=0xffff)return -1;
    return word&0x0fff;
}
