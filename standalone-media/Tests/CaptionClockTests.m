#import "../RWCaptionClock.h"
#include <math.h>
static int checks,failures;
static void check(BOOL pass){checks++;if(!pass){failures++;fprintf(stderr,"Failed check %d\n",checks);}}
static BOOL near(double a,double b){return fabs(a-b)<.000001;}
int main(){@autoreleasepool{
 RWCaptionClock *c=[RWCaptionClock new];check(!c.buffering);
 check(near([c positionForReported:3 uptime:10 eligible:YES],3));
 [c setRunning:YES];[c sample:3 uptime:10];check(near([c positionForReported:3 uptime:10.1 eligible:YES],3));
 [c sample:3.25 uptime:10.25];check(near([c positionForReported:3.25 uptime:10.35 eligible:YES],3.35));
 for(int i=0;i<=29;i++)check(near([c positionForReported:3.25 uptime:10.25+i*.01 eligible:YES],3.25+i*.01));
 check(near([c positionForReported:3.25 uptime:10.56 eligible:YES],3.25));
 check(near([c positionForReported:3.25 uptime:10.2 eligible:YES],3.25));
 check(near([c positionForReported:3.5 uptime:10.4 eligible:YES],3.5));
 check(near([c positionForReported:3.25 uptime:10.4 eligible:NO],3.25));
 [c setRequestedPlaying:NO];[c sample:3.5 uptime:10.5];check(near([c positionForReported:3.5 uptime:10.6 eligible:YES],3.5));
 [c setRequestedPlaying:YES];[c sample:3.5 uptime:11];check(near([c positionForReported:3.5 uptime:11.1 eligible:YES],3.5));
 [c sample:3.75 uptime:11.25];check(near([c positionForReported:3.75 uptime:11.35 eligible:YES],3.85));
 [c setBuffering:YES];check(c.buffering);check(near([c positionForReported:3.75 uptime:11.4 eligible:YES],3.75));
 [c sample:3.75 uptime:11.5];[c setBuffering:NO];check(!c.buffering);[c sample:4 uptime:12];check(near([c positionForReported:4 uptime:12.1 eligible:YES],4));
 [c sample:4.25 uptime:12.25];check(near([c positionForReported:4.25 uptime:12.35 eligible:YES],4.35));
 [c invalidate];[c sample:20 uptime:13];check(near([c positionForReported:20 uptime:13.1 eligible:YES],20));
 [c sample:20.25 uptime:13.25];check(near([c positionForReported:20.25 uptime:13.35 eligible:YES],20.35));
 [c sample:2 uptime:13.5];check(near([c positionForReported:2 uptime:13.6 eligible:YES],2));
 [c sample:2.25 uptime:13.75];check(near([c positionForReported:2.25 uptime:13.85 eligible:YES],2.35));
 [c sample:2.25 uptime:14];check(near([c positionForReported:2.25 uptime:14.1 eligible:YES],2.25));
 [c sample:2.5 uptime:15];check(near([c positionForReported:2.5 uptime:15.1 eligible:YES],2.5));
 [c sample:2.75 uptime:15.25];[c sample:3.25 uptime:15.5];check(near([c positionForReported:3.25 uptime:15.6 eligible:YES],3.25));
 [c sample:3.5 uptime:15.75];check(near([c positionForReported:3.5 uptime:15.85 eligible:YES],3.6));
 [c setRunning:NO];check(near([c positionForReported:3.5 uptime:15.85 eligible:YES],3.5));
 [c setRunning:YES];[c sample:4 uptime:16];[c sample:4.25 uptime:16.25];
 check(near([c positionForReported:4.25 uptime:NAN eligible:YES],4.25));
 [c sample:NAN uptime:16.5];check(near([c positionForReported:4.25 uptime:16.55 eligible:YES],4.25));
 [c sample:4.5 uptime:17];[c sample:4.75 uptime:17.25];[c sample:5 uptime:17.2];check(near([c positionForReported:5 uptime:17.3 eligible:YES],5));
 RWCaptionClock *other=[RWCaptionClock new];check(near([other positionForReported:5 uptime:17.3 eligible:YES],5));
 // Cross-thread readers/events retain bounded, finite output and safe lifetime.
 dispatch_apply(200,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^(size_t i){if(i%3==0)[other invalidate];else if(i%3==1)[other sample:5 uptime:20];else (void)[other positionForReported:5 uptime:20.1 eligible:YES];});
 check(near([other positionForReported:5 uptime:20.1 eligible:YES],5));
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
