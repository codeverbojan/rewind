#import "../RWMetadataBudget.h"
// Deterministic task doubles test the scheduler's suspend/resume counts without
// creating a server or depending on public provider response times.
@interface BudgetTask:NSObject
@property(nonatomic,strong) NSURLRequest *originalRequest;
@property(nonatomic,assign) NSURLSessionTaskState state;
@property(nonatomic,assign) NSUInteger resumes,suspends,cancels;
@end
@implementation BudgetTask
- (void)resume {self.resumes++;self.state=NSURLSessionTaskStateRunning;}
- (void)suspend {self.suspends++;self.state=NSURLSessionTaskStateSuspended;}
- (void)cancel {self.cancels++;self.state=NSURLSessionTaskStateCanceling;}
@end
static BudgetTask *Task(NSString *host){BudgetTask *t=[BudgetTask new];t.originalRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:[@"https://" stringByAppendingFormat:@"%@/metadata",host]]];t.state=NSURLSessionTaskStateSuspended;return t;}
static void QueueTask(RWMetadataBudget *gate,BudgetTask *task,BOOL foreground){[gate enqueue:(NSURLSessionTask *)task foreground:foreground];}
static void Complete(RWMetadataBudget *gate,BudgetTask *task){task.state=NSURLSessionTaskStateCompleted;[gate complete:(NSURLSessionTask *)task];}
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    RWMetadataBudget *gate=[RWMetadataBudget new];BudgetTask *a=Task(@"a.test"),*same=Task(@"a.test"),*b=Task(@"b.test"),*c=Task(@"c.test");QueueTask(gate,a,NO);QueueTask(gate,same,NO);QueueTask(gate,b,NO);QueueTask(gate,c,NO);
    CHECK(a.resumes==1&&b.resumes==1&&!same.resumes&&!c.resumes);CHECK([gate.diagnostics[@"active"]integerValue]==2);CHECK([gate.diagnostics[@"hosts"][@"a.test"]integerValue]==1);
    [gate cancel:(NSURLSessionTask *)a];CHECK(!same.resumes&&[gate.diagnostics[@"cancelling"]integerValue]==1);Complete(gate,a);CHECK(same.resumes==1&&!c.resumes);Complete(gate,b);CHECK(c.resumes==1);
    BudgetTask *urgent=Task(@"a.test");QueueTask(gate,urgent,YES);CHECK(same.suspends==1&&urgent.resumes==1);CHECK([gate.diagnostics[@"active"]integerValue]==2);Complete(gate,urgent);CHECK(same.resumes==2);
    gate.paused=YES;CHECK([gate.diagnostics[@"active"]integerValue]==0&&same.suspends==2&&c.suspends==1);gate.paused=YES;CHECK(same.suspends==2);BudgetTask *queued=Task(@"d.test");QueueTask(gate,queued,YES);CHECK(!queued.resumes);[gate cancel:(NSURLSessionTask *)queued];CHECK(queued.cancels==1);gate.paused=NO;CHECK(same.resumes==3&&c.resumes==2&&!queued.resumes);
    [gate hold:(NSURLSessionTask *)same];CHECK(same.suspends==3&&[gate.diagnostics[@"held"]integerValue]==1);Complete(gate,c);CHECK(same.resumes==3);QueueTask(gate,same,NO);CHECK(same.resumes==4);QueueTask(gate,same,NO);CHECK(same.resumes==4);Complete(gate,same);Complete(gate,same);CHECK([gate.diagnostics[@"active"]integerValue]==0&&[gate.diagnostics[@"pending"]integerValue]==0);
    gate.paused=YES;NSMutableArray *large=[NSMutableArray new];for(int i=0;i<65;i++){BudgetTask *t=Task([NSString stringWithFormat:@"%d.test",i]);[large addObject:t];QueueTask(gate,t,NO);}CHECK([gate.diagnostics[@"pending"]integerValue]==64);CHECK([large[64]cancels]==1&&[gate.diagnostics[@"rejected"]integerValue]==1);for(BudgetTask *t in large)[gate cancel:(NSURLSessionTask *)t];CHECK([gate.diagnostics[@"pending"]integerValue]==0);
    CHECK([gate.diagnostics[@"peak_active"]integerValue]<=2&&[gate.diagnostics[@"peak_per_host"]integerValue]<=1);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
