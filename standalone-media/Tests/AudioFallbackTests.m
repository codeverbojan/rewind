#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "../RWAudioPolicy.h"
#import "../RWMKVProbe.h"
static int checks,failures;
static void Check(BOOL pass,NSString *message){checks++;if(!pass){failures++;fprintf(stderr,"FAIL %s\n",message.UTF8String);}}
int main(int argc,char **argv){@autoreleasepool{
    AVURLAsset *asset=[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:@(argv[1])] options:nil];NSMutableArray *raw=[NSMutableArray new];
    for(AVAssetTrack *track in [asset tracksWithMediaType:AVMediaTypeAudio]){
        NSMutableArray *metadata=[NSMutableArray new];for(AVMetadataItem *m in track.metadata)[metadata addObject:@{@"space":m.keySpace?:@"",@"key":m.key?:@"",@"common":m.commonKey?:@"",@"value":m.value?:NSNull.null}];
        NSMutableDictionary *d=[[RWAudioPolicy nativeMetadata:metadata]mutableCopy];const AudioStreamBasicDescription *fmt=CMAudioFormatDescriptionGetStreamBasicDescription((__bridge CMAudioFormatDescriptionRef)track.formatDescriptions.firstObject);
        [d addEntriesFromDictionary:@{@"id":@(track.trackID),@"language":track.extendedLanguageTag?:track.languageCode?:@"",@"channels":@(fmt?fmt->mChannelsPerFrame:0),@"codec":@"AAC",@"compatible":@(fmt&&fmt->mFormatID==kAudioFormatMPEG4AAC),@"default":@(track.enabled)}];[raw addObject:d];
    }
    NSFileHandle *f=[NSFileHandle fileHandleForReadingAtPath:@(argv[2])];NSData *header=[f readDataOfLength:2*1024*1024];[f closeFile];
    NSArray *native=[RWAudioPolicy tracks:raw],*mkv=[RWMKVProbe media:header][@"audioTracks"];
    for(NSArray *tracks in @[native?:@[],mkv?:@[]]){
        Check(tracks.count==3,@"Actual file exposes all three tracks");if(tracks.count!=3)continue;
        NSDictionary *unknown=tracks[0],*description=tracks[2];Check(![unknown[@"language"]length]&&[unknown[@"default"]boolValue],@"Unlabelled default stays unknown");Check([unknown[@"label"]isEqual:@"Unknown language · 5.1"],@"Unknown-language menu label is honest");
        Check([tracks[1][@"language"]isEqual:@"fr"]&&[tracks[1][@"role"]isEqual:@"main"],@"French main remains distinct");Check([description[@"language"]isEqual:@"en"]&&[description[@"role"]isEqual:@"description"],@"Actual container metadata identifies description");
        NSDictionary *choice=[RWAudioPolicy selection:tracks preference:nil];Check([choice[@"track"][@"token"]isEqual:unknown[@"token"]],@"Default main is preferred over English description");Check([choice[@"reason"]isEqual:@"fallback"]&&[choice[@"message"]hasPrefix:@"No compatible English main track identified."],@"Missing main English fallback is explained");
        NSDictionary *explicit=[RWAudioPolicy selection:tracks preference:@{@"language":@"en",@"role":@"description",@"token":description[@"token"]}];Check([explicit[@"reason"]isEqual:@"saved_track"]&&[explicit[@"track"][@"token"]isEqual:description[@"token"]],@"Explicit description selection overrides default main");
    }
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
