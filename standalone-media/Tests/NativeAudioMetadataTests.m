#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "../RWAudioPolicy.h"
static int checks,failures;
static void Check(BOOL ok,NSString *message){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",message.UTF8String);}}
int main(int argc,char **argv){@autoreleasepool{
    AVURLAsset *asset=[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:@(argv[1])] options:nil];NSMutableArray *descriptors=[NSMutableArray new];BOOL commonAbsent=YES;
    for(AVAssetTrack *track in [asset tracksWithMediaType:AVMediaTypeAudio]){
        NSMutableArray *metadata=[NSMutableArray new];for(AVMetadataItem *m in track.metadata)[metadata addObject:@{@"space":m.keySpace?:@"",@"key":m.key?:@"",@"common":m.commonKey?:@"",@"value":m.value?:NSNull.null}];
        NSDictionary *labels=[RWAudioPolicy nativeMetadata:metadata];const AudioStreamBasicDescription *format=CMAudioFormatDescriptionGetStreamBasicDescription((__bridge CMAudioFormatDescriptionRef)track.formatDescriptions.firstObject);
        NSMutableDictionary *d=[labels mutableCopy];[d addEntriesFromDictionary:@{@"id":@(track.trackID),@"language":track.extendedLanguageTag?:track.languageCode?:@"",@"channels":@(format?format->mChannelsPerFrame:0),@"codec":@"AAC",@"compatible":@(format&&format->mFormatID==kAudioFormatMPEG4AAC)}];[descriptors addObject:d];commonAbsent=commonAbsent&&!track.commonMetadata.count;
    }
    Check(descriptors.count==3,@"Actual MP4 has three audio tracks");Check(commonAbsent,@"Fixture reproduces missing commonMetadata title");
    NSArray *tracks=[RWAudioPolicy tracks:descriptors];Check([tracks[2][@"role"]isEqual:@"commentary"],@"Raw ISO kind/name establishes commentary role");
    NSDictionary *selected=[RWAudioPolicy selection:tracks preference:nil][@"track"];
    Check([selected[@"language"]isEqual:@"en"]&&[selected[@"channels"]intValue]==6&&[selected[@"role"]isEqual:@"main"],@"Real AVFoundation metadata yields English main 5.1 over commentary stereo");
    Check([tracks[0][@"label"]isEqual:@"French · Stereo"],@"Real French track label normalized");
    NSData *name=[@"Director commentary"dataUsingEncoding:NSUTF8StringEncoding];NSDictionary *entry=@{@"space":@"uiso",@"key":@1851878757,@"value":name};
    Check([[RWAudioPolicy nativeMetadata:@[entry]][@"name"]isEqual:@"Director commentary"],@"Known ISO name is decoded");
    Check(![RWAudioPolicy nativeMetadata:@[@{@"space":@"other",@"key":@1851878757,@"value":name}]][@"name"],@"Unrelated metadata namespace ignored");
    Check(![RWAudioPolicy nativeMetadata:@[@{@"space":@"uiso",@"key":@1851878757,@"value":[NSMutableData dataWithLength:513]}]][@"name"],@"Name decoding bounded before allocation");
    unsigned char invalid[]={0xff,0xff};Check(![RWAudioPolicy nativeMetadata:@[@{@"space":@"uiso",@"key":@1851878757,@"value":[NSData dataWithBytes:invalid length:2]}]][@"name"],@"Malformed UTF8 metadata cannot invent a label");
    const char kind[]={0,0,0,0,'u','r','n',':','m','p','e','g',':','d','a','s','h',':','r','o','l','e',':','2','0','1','1',0,'c','o','m','m','e','n','t','a','r','y',0};
    NSData *valid=[NSData dataWithBytes:kind length:sizeof(kind)];NSDictionary *raw=@{@"space":@"uiso",@"key":@1802071652,@"value":valid};
    Check([[RWAudioPolicy nativeMetadata:@[raw]][@"commentary"]boolValue],@"Role flag alone works without a descriptive name");
    for(NSUInteger i=0;i<valid.length;i++)Check(![[RWAudioPolicy nativeMetadata:@[@{@"space":@"uiso",@"key":@1802071652,@"value":[valid subdataWithRange:NSMakeRange(0,i)]}]][@"commentary"]boolValue],@"Every truncated role value rejected");
    NSMutableData *corrupt=[valid mutableCopy];((uint8_t *)corrupt.mutableBytes)[0]=1;Check(![[RWAudioPolicy nativeMetadata:@[@{@"space":@"uiso",@"key":@1802071652,@"value":corrupt}]][@"commentary"]boolValue],@"Unsupported FullBox version ignored");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
