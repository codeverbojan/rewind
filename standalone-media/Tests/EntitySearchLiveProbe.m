// Explicit research command only; never part of offline run_checks.py.
#import "../RWDiscoveryMetadata.h"
@interface RWDiscoveryMetadata (ProbePrivate)
- (void)fetch:(NSString *)url generation:(NSUInteger)generation done:(void(^)(NSDictionary *,NSString *))done;
@end
@interface LiveSearchProbe:RWDiscoveryMetadata
@property(nonatomic,strong) NSMutableArray *requests;
@end
@implementation LiveSearchProbe
- (void)fetch:(NSString *)url generation:(NSUInteger)g done:(void(^)(NSDictionary *,NSString *))done {double started=NSDate.date.timeIntervalSince1970;[super fetch:url generation:g done:^(NSDictionary *json,NSString *error){[self.requests addObject:@{@"url":url,@"seconds":@(NSDate.date.timeIntervalSince1970-started),@"decoded_bytes":self.diagnostics[@"bytes"]?:@0,@"error":error?:@""}];done(json,error);}];}
@end
int main(int argc,const char **argv){@autoreleasepool{LiveSearchProbe *s=[[LiveSearchProbe alloc]initWithPath:@"" cached:@{} seed:@{}];s.paused=NO;NSMutableArray *runs=[NSMutableArray new];for(NSArray *test in @[@[@"Anne Hathaway",@"People",@"Q36301"],@[@"A24",@"Studios",@"Q16248298"],@[@"Bad Robot",@"Studios",@"Q798768"],@[@"Christopher Nolan",@"People",@"Q25191"]]){__block BOOL done=NO;__block NSDictionary *result=nil;s.requests=[NSMutableArray new];double began=NSDate.date.timeIntervalSince1970;[s searchEntities:test[0] kind:test[1] continuation:nil done:^(NSArray *items,NSDictionary *next,NSString *error){NSMutableArray *brief=[NSMutableArray new];for(NSDictionary *m in items)[brief addObject:@{@"id":m[@"id"],@"name":m[@"name"],@"roles":m[@"roles"]}];result=@{@"query":test[0],@"kind":test[1],@"expected":test[2],@"matches":brief,@"next":next?:@{},@"error":error?:@"",@"seconds":@(NSDate.date.timeIntervalSince1970-began),@"requests":[s.requests copy]};done=YES;}];NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:12];while(!done&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];if(result)[runs addObject:result];else{[s cancelEntitySearch];[runs addObject:@{@"query":test[0],@"error":@"Harness observation deadline"}];}}
    [s cancelPending];NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"scope":@"Host live provider probe, not iPad latency or UIKit acceptance",@"runs":runs} options:NSJSONWritingPrettyPrinted error:nil];if(argc>1)[data writeToFile:[NSString stringWithUTF8String:argv[1]] atomically:YES];for(NSDictionary *r in runs)printf("%s: %lu matches, %.2f s, %lu calls, %s\n",[r[@"query"]UTF8String],(unsigned long)[r[@"matches"]count],[r[@"seconds"]doubleValue],(unsigned long)[r[@"requests"]count],[r[@"error"]UTF8String]);return 0;
}}
