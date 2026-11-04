#import "RWFeedArchive.h"
#include <zlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>

static BOOL Transfer(NSString *source,NSString *destination,unsigned long long limit,unsigned long long expected,BOOL pack,NSString **error) {
    NSFileManager *fm=NSFileManager.defaultManager;
    if(error)*error=nil;
    if(!limit||[source isEqual:destination]||[fm fileExistsAtPath:destination]){if(error)*error=@"Couldn’t reserve a browsing cache file.";return NO;}
    NSString *temporary=[destination stringByAppendingFormat:@".%@.partial",NSUUID.UUID.UUIDString];
    FILE *input=fopen(source.fileSystemRepresentation,"rb"),*output=NULL;
    int fd=input?open(temporary.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL,0600):-1;
    if(fd>=0){output=fdopen(fd,"wb");if(!output)close(fd);}
    z_stream stream={0};BOOL initialized=NO,ok=input&&output;int result=Z_OK;unsigned long long written=0;
    unsigned char inBuffer[32768],outBuffer[32768];
    if(ok){result=pack?deflateInit2(&stream,Z_BEST_SPEED,Z_DEFLATED,31,8,Z_DEFAULT_STRATEGY):inflateInit2(&stream,31);initialized=result==Z_OK;ok=initialized;}
    while(ok&&result!=Z_STREAM_END){
        if(!stream.avail_in){size_t n=fread(inBuffer,1,sizeof(inBuffer),input);if(ferror(input)){ok=NO;break;}stream.next_in=inBuffer;stream.avail_in=(uInt)n;}
        stream.next_out=outBuffer;stream.avail_out=sizeof(outBuffer);uLong consumed=stream.total_in;
        result=pack?deflate(&stream,feof(input)?Z_FINISH:Z_NO_FLUSH):inflate(&stream,Z_NO_FLUSH);
        size_t n=sizeof(outBuffer)-stream.avail_out;
        if((result!=Z_OK&&result!=Z_STREAM_END)||n>limit-written){ok=NO;break;}
        if(n&&fwrite(outBuffer,1,n,output)!=n){ok=NO;break;}written+=n;
        if(result!=Z_STREAM_END&&!n&&stream.total_in==consumed&&feof(input)){ok=NO;break;}
    }
    if(ok&&!pack){ // Exactly one complete gzip member; CRC, length and EOF all matter.
        ok=written==expected&&!stream.avail_in&&fgetc(input)==EOF&&!ferror(input);
    }
    if(initialized){int ended=pack?deflateEnd(&stream):inflateEnd(&stream);if(ended!=Z_OK)ok=NO;}
    if(input&&fclose(input))ok=NO;
    if(output&&fclose(output))ok=NO;
    if(ok)ok=[fm moveItemAtPath:temporary toPath:destination error:nil];
    if(!ok){[fm removeItemAtPath:temporary error:nil];if(error)*error=pack?@"Couldn’t compact this browsing list.":@"Couldn’t restore this browsing list. Its saved copy was kept.";}
    return ok;
}
@implementation RWFeedArchive
+ (BOOL)pack:(NSString *)source to:(NSString *)destination limit:(unsigned long long)limit error:(NSString **)error {return Transfer(source,destination,limit,0,YES,error);}
+ (BOOL)unpack:(NSString *)source to:(NSString *)destination limit:(unsigned long long)limit expected:(unsigned long long)expected error:(NSString **)error {return Transfer(source,destination,limit,expected,NO,error);}
@end
