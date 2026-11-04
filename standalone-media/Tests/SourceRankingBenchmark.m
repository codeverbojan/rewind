#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import "../RWSourcePolicy.h"
int main(int argc,const char **argv){@autoreleasepool{
    [RWSourcePolicy setLegacyEnabled:YES];[RWSourcePolicy setNativeSurroundEnabled:YES];NSMutableArray *reports=[NSMutableArray new];
    for(int i=1;i<argc;i++){
        NSDictionary *fixture=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[i])] options:0 error:nil];
        NSMutableArray *times=[NSMutableArray new];NSString *digest=nil;NSUInteger count=0;
        for(int sample=0;sample<21;sample++){@autoreleasepool{
            double start=NSProcessInfo.processInfo.systemUptime;NSMutableArray *sources=[NSMutableArray new];
            for(NSDictionary *raw in fixture[@"streams"]){NSDictionary *s=[RWSourcePolicy normalize:raw provider:@"Fixture"];if(s)[sources addObject:s];}
            NSArray *ranked=[RWSourcePolicy rank:sources quality:0 freeBytes:0];count=sources.count;
            double ms=(NSProcessInfo.processInfo.systemUptime-start)*1000;if(sample)[times addObject:@(ms)];
            if(sample==20){NSData *data=[NSJSONSerialization dataWithJSONObject:ranked options:NSJSONWritingSortedKeys error:nil];unsigned char sum[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,sum);NSMutableString *hex=[NSMutableString new];for(int n=0;n<CC_SHA256_DIGEST_LENGTH;n++)[hex appendFormat:@"%02x",sum[n]];digest=hex;}
        }}
        [times sortUsingSelector:@selector(compare:)];[reports addObject:@{@"fixture":@(argv[i]).lastPathComponent,@"source_count":@(count),@"samples":@20,@"median_ms":@(([times[9]doubleValue]+[times[10]doubleValue])/2),@"worst_ms":times.lastObject,@"ranked_output_sha256":digest?:@""}];
    }
    puts([[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:@{@"scope":@"Host normalization/ranking CPU time; not an iPad timing",@"fixtures":reports} options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding].UTF8String);return 0;
}}
