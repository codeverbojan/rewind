#import "../RWIMDbIndex.h"
int main(int argc,char **argv){@autoreleasepool{if(argc!=3)return 2;NSDictionary *result=[RWIMDbIndex importGzip:@(argv[1]) destination:@(argv[2]) cancelled:^BOOL{return NO;}];puts([[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:result options:0 error:nil] encoding:NSUTF8StringEncoding].UTF8String);return [result[@"ok"]boolValue]?0:1;}}
