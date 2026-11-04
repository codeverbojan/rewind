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
        NSDictionary *named=tracks[0],*polish=tracks[1];Check(![named[@"language"]length]&&![named[@"default"]boolValue],@"Container preserves unknown nondefault language");
        Check([named[@"name"]isEqual:@"angielski [oryginalny]"]&&[named[@"language_hint"]isEqual:@"en"],@"Actual container track name provides hint");
        Check([polish[@"language"]isEqual:@"pl"]&&[polish[@"default"]boolValue],@"Other track is explicitly Polish/default");
        NSDictionary *choice=[RWAudioPolicy selection:tracks preference:nil];Check([choice[@"track"][@"token"]isEqual:named[@"token"]]&&[choice[@"reason"]isEqual:@"preferred_language_name"],@"Actual metadata selects name-only English main over default Polish");
        NSDictionary *manual=[RWAudioPolicy selection:tracks preference:@{@"token":polish[@"token"]}];Check([manual[@"track"][@"token"]isEqual:polish[@"token"]]&&[manual[@"reason"]isEqual:@"saved_track"],@"Manual Polish remains authoritative");

    }
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
