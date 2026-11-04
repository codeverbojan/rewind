#import "RWTrackerTrust.h"
#import <CommonCrypto/CommonDigest.h>

NSData *RWTrackerTrustedPEM(void) {
#ifdef RW_ENGINE_TESTING
    // Only separately compiled engine fixtures may use their ephemeral CA.
    // The production build never defines RW_ENGINE_TESTING.
    const char *testPath=getenv("REWIND_TRACKER_TEST_TRUST");
    if(testPath&&*testPath){
        NSString *path=@(testPath);
        NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
        if(!attrs||[attrs[NSFileSize]unsignedLongLongValue]>512*1024)return nil;
        return [NSData dataWithContentsOfFile:path];
    }
#endif
    static NSData *trusted;static dispatch_once_t once;
    dispatch_once(&once,^{
        NSString *path=[NSBundle.mainBundle pathForResource:@"tracker-roots" ofType:@"pem" inDirectory:@"Rewind"];
        NSDictionary *attrs=path?[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil]:nil;
        if(!attrs||[attrs[NSFileSize]unsignedLongLongValue]!=200116)return;
        NSData *bytes=[NSData dataWithContentsOfFile:path];if(bytes.length!=200116)return;
        unsigned char hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256(bytes.bytes,(CC_LONG)bytes.length,hash);
        NSMutableString *hex=[NSMutableString new];for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[hex appendFormat:@"%02x",hash[i]];
        if([hex isEqual:@"796f1389bfea13c0ed78f663b765baaff54a508e5483786bd6ece73c5e3e3cbe"])trusted=bytes;
    });
    return trusted;
}
