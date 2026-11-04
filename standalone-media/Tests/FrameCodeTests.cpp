#include "../RWFrameCode.h"
#include <stdio.h>
#include <vector>
static int checks,failures;
static void check(bool ok){checks++;if(!ok)failures++;}
int main(){
 for(int width: {640,768,1024})for(int frame:{0,1,23,127,511,719,4095}){
  std::vector<uint8_t> row(width*4,0);uint32_t word=0xa000|frame,code=(word<<16)|(word^0xffff);
  for(int x=0;x<width;x++){int cell=x*32/width;for(int c=0;c<3;c++)row[x*4+c]=(code>>(31-cell)&1)?235:16;}
  uint8_t levels[32]={0};check(RWDecodeFrameCode(row.data(),width,levels)==frame);
  int center=width/64;row[4*center]=row[4*center+1]=row[4*center+2]=120;check(RWDecodeFrameCode(row.data(),width,nullptr)==-1);
  row[4*center]=row[4*center+1]=row[4*center+2]=16;check(RWDecodeFrameCode(row.data(),width,nullptr)==-1);
 }
 check(RWDecodeFrameCode(nullptr,640,nullptr)==-1);uint8_t row[4096]={0};check(RWDecodeFrameCode(row,63,nullptr)==-1);check(RWDecodeFrameCode(row,1025,nullptr)==-1);check(RWDecodeFrameCode(row,640,nullptr)==-1);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}
