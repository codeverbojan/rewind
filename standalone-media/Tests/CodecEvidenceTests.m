#import <Foundation/Foundation.h>
#import "../RWSourcePolicy.h"
#import "../RWSourceExperience.h"
#import "../RWMKVProbe.h"
static int checks,failures;
static void check(BOOL ok,const char *name){checks++;if(!ok){failures++;fprintf(stderr,"FAIL %s\n",name);}}
static NSData *element(const unsigned char *id,NSUInteger n,NSData *value){NSMutableData *d=[NSMutableData dataWithBytes:id length:n];unsigned char size=0x80|value.length;NSCAssert(value.length<127,@"Small independent EBML fixture");[d appendBytes:&size length:1];[d appendData:value];return d;}
static NSData *header(NSString *codec){unsigned char typeID=0x83,codecID=0x86,entryID=0xae;unsigned char tracksID[]={0x16,0x54,0xae,0x6b},segmentID[]={0x18,0x53,0x80,0x67},type=1;
 NSMutableData *entry=[element(&typeID,1,[NSData dataWithBytes:&type length:1])mutableCopy];if(codec)[entry appendData:element(&codecID,1,[codec dataUsingEncoding:NSASCIIStringEncoding])];
 return element(segmentID,4,element(tracksID,4,element(&entryID,1,entry)));}
int main(){@autoreleasepool{
 NSDictionary *probe=[RWMKVProbe video:header(@"V_MPEGH/ISO/HEVC")];
 check([probe[@"videoCodec"]isEqual:@"unsupported"],"real EBML HEVC recognized as unsupported");
 check([probe[@"containerVideoCodec"]isEqual:@"V_MPEGH/ISO/HEVC"],"actual codec identifier retained");
 NSDictionary *assessment=[RWSourcePolicy mediaAssessment:probe quality:0];
 check([assessment[@"status"]isEqual:@"incompatible"]&&[assessment[@"code"]isEqual:@"codec_unsupported"],"known nonH264 beats absent dimensions");
 check([assessment[@"evidence"][@"containerVideoCodec"]isEqual:@"V_MPEGH/ISO/HEVC"],"saved rejection retains observed codec ID");
 check(![RWMKVProbe video:header(nil)],"missing CodecID is incomplete not known unsupported");
 check(![RWMKVProbe video:header(@"")],"empty CodecID cannot create durable rejection");
 check([[RWSourcePolicy mediaAssessment:@{} quality:0][@"status"]isEqual:@"unknown"],"empty probe remains unknown");
 NSDictionary *source=@{@"infoHash":@"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",@"fileIdx":@0,@"resolvedFileIdx":@0,@"filename":@"Claimed.H264.1080p.WEB-DL.AAC.mkv"};
 [RWSourcePolicy setLegacyEnabled:YES];NSString *cap=[RWSourcePolicy mediaCapabilityKey:[RWSourcePolicy capabilities]];
 NSDictionary *record=[RWSourceExperience record:nil source:source success:NO assessment:assessment capability:cap now:100];
 check([record[@"media_incompatibility"][@"code"]isEqual:@"codec_unsupported"],"actual probe persists typed rejection");
 NSDictionary *restored=[NSJSONSerialization JSONObjectWithData:[NSJSONSerialization dataWithJSONObject:record options:0 error:nil] options:0 error:nil];
 NSDictionary *ranked=[RWSourceExperience sourceForRanking:source record:restored capability:cap now:105];
 check([[RWSourcePolicy evaluate:ranked quality:0 freeBytes:0][@"verifiedMediaRejectionApplied"]boolValue],"actual local exclusion explicitly reported");
 check(![[RWSourcePolicy evaluate:ranked quality:0 freeBytes:0][@"eligible"]boolValue],"same file skipped after serialize and reload despite H264 filename");
 NSMutableDictionary *other=[source mutableCopy];other[@"fileIdx"]=@1;
 other[@"verifiedMediaRejectionApplied"]=@YES;check(![[RWSourcePolicy evaluate:other quality:0 freeBytes:0][@"verifiedMediaRejectionApplied"]boolValue],"raw flag cannot impersonate a checked exclusion");
 check([[RWSourcePolicy evaluate:[RWSourceExperience sourceForRanking:other record:restored capability:cap now:105] quality:0 freeBytes:0][@"eligible"]boolValue],"other file stays eligible");
 check([[RWSourcePolicy evaluate:[RWSourceExperience sourceForRanking:source record:restored capability:cap now:100+7*86400] quality:0 freeBytes:0][@"eligible"]boolValue],"expiry restores eligibility");
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
