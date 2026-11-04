#include "../RWByteRange.h"
#include <assert.h>
#include <sys/types.h>
#include <stdio.h>
int main(){
    static_assert(sizeof(off_t)==8,"64-bit file offsets required");
    int64_t end=0,first=0,last=0,gb=1024LL*1024*1024;
    assert(RWRangeEnd(4*gb+37,262144,false,6*gb,&end)&&end==4*gb+37+262144);
    assert(RWRangeEnd(6*gb-100,262144,false,6*gb,&end)&&end==6*gb);
    assert(RWRangeEnd(4*gb,0,true,6*gb,&end)&&end==6*gb);
    assert(!RWRangeEnd(-1,100,false,6*gb,&end));assert(!RWRangeEnd(6*gb+1,100,false,6*gb,&end));
    assert(RWRangeEnd(INT64_MAX-5,100,false,INT64_MAX,&end)&&end==INT64_MAX);
    assert(RWPieceRange(3*gb+1,6*gb,4*gb+1024,2*1024*1024,1024*1024,&first,&last)&&first==7168&&last==7170);
    assert(RWPieceRange(0,6*gb,4*gb,1024*1024,1024*1024,&first,&last)&&first==4096&&last==4096);
    assert(!RWPieceRange(INT64_MAX-1,6*gb,0,100,1024,&first,&last));
    assert(RWCanStore(5*gb,6*gb,0));assert(!RWCanStore(5*gb,5*gb,0));
    assert(RWCanStore(5*gb,3*gb,3*gb));assert(!RWCanStore(5*gb,256*1024*1024,5*gb));
    puts("13 byte-range/storage checks passed, including offsets beyond 4 GiB and overflow boundaries.");
}
