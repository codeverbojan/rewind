#include "../RWStackReadPolicy.h"
#include <stdio.h>
static int checks,failures;
static void check(bool ok){checks++;if(!ok)failures++;}
int main(){
 check(!RWStackFrameReadable(0,0,0));check(!RWStackFrameReadable(0,0,7));
 check(RWStackFrameReadable(0x1000,0x1000,0x3000));check(RWStackFrameReadable(0x2ff8,0x1000,0x3000));
 check(!RWStackFrameReadable(0x2ffc,0x1000,0x3000));check(!RWStackFrameReadable(0x1001,0x1000,0x3000));
 check(!RWStackFrameReadable(0xffc,0x1000,0x3000));check(!RWStackFrameReadable(0x1000,0x3000,0x1000));
 check(!RWStackFrameReadable(0x1000,0x1000,0x1000+16*1024*1024+4));
 check(!RWStackFrameReadable(UINT64_MAX-3,UINT64_MAX-100,UINT64_MAX));
 check(RWStackFrameFollows(0x1010,0x1000,0x1000,0x3000));check(!RWStackFrameFollows(0x1000,0x1000,0x1000,0x3000));
 check(!RWStackFrameFollows(0x1000,0x1010,0x1000,0x3000));check(!RWStackFrameFollows(0x20000,0x1000,0x1000,0x30000));
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}
