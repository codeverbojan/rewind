#import "../RWFeedArchive.h"
#import "../RWFeedStorageBudget.h"
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    NSFileManager *fm=NSFileManager.defaultManager;NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[fm createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *source=[folder stringByAppendingPathComponent:@"input"],*packed=[folder stringByAppendingPathComponent:@"archive"],*restored=[folder stringByAppendingPathComponent:@"restored"],*error=nil;
    NSMutableData *data=[NSMutableData dataWithLength:RWFeedDiskBudgetBytes];unsigned char *bytes=data.mutableBytes;for(NSUInteger i=0;i<data.length;i++)bytes[i]=(unsigned char)(i%251);[data writeToFile:source atomically:YES];
    @try{
        CHECK([RWFeedArchive pack:source to:packed limit:RWFeedDiskBudgetBytes error:&error]&&!error);CHECK([fm fileExistsAtPath:source]);CHECK([[fm attributesOfItemAtPath:packed error:nil][NSFileSize]unsignedLongLongValue]<data.length/10);
        CHECK([RWFeedArchive unpack:packed to:restored limit:RWFeedDiskBudgetBytes expected:data.length error:&error]&&!error);CHECK([[NSData dataWithContentsOfFile:restored]isEqual:data]);CHECK([fm fileExistsAtPath:packed]);
        CHECK(![RWFeedArchive unpack:packed to:restored limit:RWFeedDiskBudgetBytes expected:data.length error:&error]&&error.length);CHECK([[NSData dataWithContentsOfFile:restored]isEqual:data]);[fm removeItemAtPath:restored error:nil];
        CHECK(![RWFeedArchive unpack:packed to:restored limit:100000 expected:data.length error:&error]&&error.length);CHECK(![fm fileExistsAtPath:restored]);
        CHECK(![RWFeedArchive unpack:packed to:restored limit:RWFeedDiskBudgetBytes expected:data.length-1 error:&error]);
        NSData *valid=[NSData dataWithContentsOfFile:packed];NSMutableData *corrupt=[valid mutableCopy];((unsigned char *)corrupt.mutableBytes)[corrupt.length-8]^=1;[corrupt writeToFile:packed atomically:YES];
        CHECK(![RWFeedArchive unpack:packed to:restored limit:RWFeedDiskBudgetBytes expected:data.length error:&error]&&error.length);CHECK(![fm fileExistsAtPath:restored]);CHECK([[NSData dataWithContentsOfFile:packed]isEqual:corrupt]);
        [[valid subdataWithRange:NSMakeRange(0,valid.length-1)]writeToFile:packed atomically:YES];CHECK(![RWFeedArchive unpack:packed to:restored limit:RWFeedDiskBudgetBytes expected:data.length error:&error]);
        NSMutableData *trailing=[valid mutableCopy];[trailing appendBytes:"junk" length:4];[trailing writeToFile:packed atomically:YES];CHECK(![RWFeedArchive unpack:packed to:restored limit:RWFeedDiskBudgetBytes expected:data.length error:&error]);
        [data writeToFile:packed atomically:YES];CHECK(![RWFeedArchive unpack:packed to:restored limit:RWFeedDiskBudgetBytes expected:data.length error:&error]);
        [fm removeItemAtPath:packed error:nil];CHECK(![RWFeedArchive pack:source to:packed limit:10 error:&error]&&error.length);CHECK(![fm fileExistsAtPath:packed]);CHECK([[NSData dataWithContentsOfFile:source]isEqual:data]);
        CHECK(![RWFeedArchive pack:[folder stringByAppendingPathComponent:@"missing"] to:packed limit:100 error:&error]);CHECK(![RWFeedArchive pack:source to:source limit:100 error:&error]);
        CHECK([fm contentsOfDirectoryAtPath:folder error:nil].count==1); // No abandoned temp files on any failure.
    }@finally{[fm removeItemAtPath:folder error:nil];}
    printf("{\"checks\":%d,\"failures\":%d,\"stream_buffer_bytes\":65536}\n",checks,failures);return failures?1:0;
}}
