#import "../RWIMDbIndex.h"
int main(int argc,char **argv){@autoreleasepool{if(argc!=3)return 2;int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    NSString *archive=[NSString stringWithUTF8String:argv[1]],*bundled=[NSString stringWithUTF8String:argv[2]],*folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString],*index=[folder stringByAppendingPathComponent:@"RatingsIndex"];
    NSFileManager *fm=NSFileManager.defaultManager;[fm createDirectoryAtPath:index withIntermediateDirectories:YES attributes:nil error:nil];NSString *current=[index stringByAppendingPathComponent:@"ratings.sqlite"];CHECK([fm copyItemAtPath:bundled toPath:current error:nil]);
    unsigned long long archiveBytes=[[fm attributesOfItemAtPath:archive error:nil][NSFileSize]unsignedLongLongValue];NSDictionary *budget=[RWIMDbIndex updateBudgetForFolder:index bundled:bundled downloadBytes:archiveBytes];
    CHECK([budget[@"feed_storage_reserve"]unsignedLongLongValue]>=6ULL*1024*1024);
    NSDictionary *result=[RWIMDbIndex importGzip:archive destination:current maximumBytes:[budget[@"maximum_new_index"]unsignedLongLongValue] cancelled:nil];CHECK([result[@"ok"]boolValue]);CHECK([result[@"rows"]integerValue]>1000000);CHECK([result[@"bytes"]unsignedLongLongValue]<=[budget[@"maximum_new_index"]unsignedLongLongValue]);
    unsigned long long peak=[budget[@"before_import"]unsignedLongLongValue]+[result[@"bytes"]unsignedLongLongValue];CHECK(peak<=100ULL*1024*1024);CHECK(![fm fileExistsAtPath:[current stringByAppendingString:@".import"]]);[fm removeItemAtPath:folder error:nil];CHECK(![fm fileExistsAtPath:folder]);
    NSDictionary *report=@{@"checks":@(checks),@"failures":@(failures),@"import":result,@"budget":budget,@"peak_with_reserves":@(peak)};puts([[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:report options:0 error:nil] encoding:NSUTF8StringEncoding].UTF8String);return failures?1:0;
}}
