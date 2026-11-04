#include "../RWPreparationPolicy.h"
#include <cstdio>
int main(){int checks=0,failures=0;auto check=[&](bool ok,const char *message){checks++;if(!ok){failures++;std::fprintf(stderr,"FAIL: %s\n",message);}};
    for(int bytes:{1024*1024,4*1024*1024,8*1024*1024,16*1024*1024}){
        auto p=RWPrepareOpening(0,2LL*1024*1024*1024,bytes,RWPreparationByteBudget);
        check(p.allowed&&p.first==0&&p.headerLast==0&&p.last==1,"Opening has a verification piece and a bounded lookahead");
        check(p.fileEnd<=RWPreparationByteBudget&&p.transferBound<=RWPreparationByteBudget,"Large movies cannot cause an unbounded prefix request");
    }
    auto crossing=RWPrepareOpening(8*1024*1024-100,175686637,8*1024*1024,RWPreparationByteBudget);
    check(crossing.allowed&&crossing.headerLast==1&&crossing.last==2,"Unaligned episode verifies both header pieces before its lookahead");
    auto expensive=RWPrepareOpening(16*1024*1024-100,175686637,16*1024*1024,RWPreparationByteBudget);
    check(!expensive.allowed,"A 48 MiB whole-piece request remains metadata-only within a 32 MiB budget");
    auto later=RWPrepareOpening(40LL*1024*1024*1024,175686637,8*1024*1024,RWPreparationByteBudget);
    check(later.allowed&&later.first>4000&&later.fileEnd==16*1024*1024,"Later pack episodes use file-relative bounds and 64-bit global offsets");
    auto tiny=RWPrepareOpening(0,4096,1024*1024,RWPreparationByteBudget);
    check(tiny.allowed&&tiny.last==0&&tiny.fileEnd==4096,"A short file never requests data from the next file");
    check(!RWPrepareOpening(INT64_MAX-20,100,1024*1024,RWPreparationByteBudget).allowed,"Overflowing file boundaries are rejected");
    check(!RWPrepareOpening(0,100,0,RWPreparationByteBudget).allowed,"Invalid piece sizes are rejected");
    check(!RWPrepareOpening(0,100,32*1024*1024,RWPreparationByteBudget).allowed,"Preloading preserves the decoder's piece-memory ceiling");
    check(!RWPrepareOpening(0,10000000,8*1024*1024,8*1024*1024).allowed,"Remaining session budget includes the interest-maintaining piece");
    check(RWPreparationMayTransfer(1000,1000,2ULL*1024*1024*1024,1,RWPreparationByteBudget),"Healthy foreground preparation can transfer");
    check(!RWPreparationMayTransfer(RWPreparationByteBudget,0,2ULL*1024*1024*1024,1,RWPreparationByteBudget),"Payload budget stops additional requests");
    check(!RWPreparationMayTransfer(0,RWPreparationByteBudget,2ULL*1024*1024*1024,1,RWPreparationByteBudget),"Physical allocation growth independently stops requests");
    check(!RWPreparationMayTransfer(0,0,512ULL*1024*1024,1,RWPreparationByteBudget),"Low free disk prevents speculative transfer");
    check(!RWPreparationMayTransfer(0,0,2ULL*1024*1024*1024,20,RWPreparationByteBudget),"Payload preloading has a bounded time window");
    std::printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}
