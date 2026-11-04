#include "../RWProbeTiming.h"
#include <cstdio>
int main(){int checks=0,failures=0;auto check=[&](bool b){checks++;failures+=!b;};RWProbeTiming t;t.begin(10);
t.observe(10,true,false,true,false,false,false);t.observe(11,true,false,true,false,false,false);t.observe(12,false,true,true,true,false,true);t.observe(13,false,false,true,true,true,true);
check(t.checkingSeconds==2);check(t.heldSeconds==1);check(t.metadata==0&&t.peer==2&&t.payload==3&&t.opening==2);
t.observe(20,true,true,true,true,true,true);check(t.unknownSeconds==7&&t.checkingSeconds==2&&t.heldSeconds==1);t.observe(19,true,true,true,true,true,true);check(t.last==20);t.observe(NAN,true,true,true,true,true,true);check(t.last==20);t.observe(21,false,false,true,true,true,true);check(t.checkingSeconds==3&&t.heldSeconds==2);t.begin(30);check(t.metadata==-1&&t.checkingSeconds==0&&t.last==-1);t.observe(29,true,true,true,true,true,true);check(t.last==-1);t.begin(30);t.observe(31,false,false,false,false,false,false);check(t.unknownSeconds==1);printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;}
