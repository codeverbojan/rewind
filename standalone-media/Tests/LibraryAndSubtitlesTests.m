#import <Foundation/Foundation.h>
#import "../RWLibraryPolicy.h"
#import "../RWSubtitles.h"
#import "../RWMediaCache.h"
#include <unistd.h>
int main(){@autoreleasepool{__block int checks=0,failures=0;void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *label){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",label.UTF8String);}};
NSDictionary *a=@{@"id":@"a",@"genres":@[@"Action"],@"imdbRating":@9},*b=@{@"id":@"b",@"genres":@[@"Action"]},*c=@{@"id":@"c",@"genres":@[@"Comedy"]},*d=@{@"id":@"d",@"genres":@[@"Action"]};
NSArray *out=[RWLibraryPolicy recommend:@[a,b,b,c,d] current:a history:@[@{@"meta":b,@"position":@60}] saved:@[] hidden:@[@"d"] limit:20];check(out.count==1&&[out[0][@"id"]isEqual:@"c"],@"Current, already-watched, duplicate and hidden titles excluded");
out=[RWLibraryPolicy recommend:@[b,c,d] current:a history:@[] saved:@[] hidden:@[] limit:2];check(out.count==2&&[out[0][@"id"]isEqual:@"b"],@"Current film genres influence recommendations");
check([RWLibraryPolicy recommend:@[] current:nil history:@[] saved:@[] hidden:@[] limit:10].count==0,@"Empty profile is safe");
NSData *srt=[@"2\r\n00:00:03,000 --> 00:00:04,500\r\nLater\r\n\r\n1\r\n00:00:01,000 --> 00:00:02,000\r\n<i>Hello</i>\r\n" dataUsingEncoding:NSUTF8StringEncoding];NSArray *cues=[RWSubtitles parse:srt];check(cues.count==2,@"SRT parses CRLF and sorts cues");check([[RWSubtitles textIn:cues at:1.2]isEqual:@"Hello"],@"Formatting stripped and active cue selected");check([[RWSubtitles textIn:cues at:2.4]isEqual:@""],@"Subtitles clear between cues");check([[RWSubtitles textIn:cues at:3.2]isEqual:@"Later"],@"Seeking chooses correct cue");check([RWSubtitles parse:[@"00:00:04,000 --> 00:00:02,000\nBad" dataUsingEncoding:NSUTF8StringEncoding]].count==0,@"Reversed timings rejected");check([RWSubtitles parse:[@"WEBVTT\n\n00:01.000 --> 00:02.000 align:start\nCaption" dataUsingEncoding:NSUTF8StringEncoding]].count==1,@"WebVTT settings and short timestamps accepted");
check([RWSubtitles language:@"en-US" matches:@"en"],@"Regional English subtitles preferred");
check([RWSubtitles language:@"eng" matches:@"en"],@"Three-letter English language code accepted");
check([RWSubtitles language:@"English (SDH)" matches:@"en"],@"English accessibility subtitle label accepted");
check(![RWSubtitles language:@"French" matches:@"en"],@"Different language not auto-selected");
check(![RWSubtitles language:nil matches:@"en"],@"Unknown language not guessed");
check(![RWSubtitles language:@"engagement" matches:@"en"],@"Language prefix does not match unrelated word");
for(NSString *label in @[@"fr",@"fra",@"fre",@"French - [French]",@"fr-CA"])check([RWSubtitles language:label matches:@"fr"],@"French aliases select the same language");
check([RWSubtitles language:@"fra" matches:@"fr-CA"],@"Regional preference canonicalized");
check([RWSubtitles language:@"deu" matches:@"de"],@"German alias");check([RWSubtitles language:@"spa" matches:@"es"],@"Spanish alias");
check([RWSubtitles language:@"ita" matches:@"it"],@"Italian alias");check([RWSubtitles language:@"por" matches:@"pt"],@"Portuguese alias");
check(![RWSubtitles language:@"franchise" matches:@"fr"],@"Unrelated prefix rejected");check(![RWSubtitles language:@"" matches:@""],@"Missing language stays unknown");
check([RWSubtitles fileName:@"Movie.2020.en.srt" matchesLanguage:@"en"],@"File language suffix recognized");
check([RWSubtitles fileName:@"Movie.ENG.SDH.srt" matchesLanguage:@"en"],@"Accessibility suffix retains English language");
check(![RWSubtitles fileName:@"English.Patient.fr.srt" matchesLanguage:@"en"],@"Title word must not override explicit French suffix");
check(![RWSubtitles fileName:@"Engagement.srt" matchesLanguage:@"en"],@"Unrelated word is not an English code");
NSArray *provided=[RWSubtitles providedBySource:@{@"subtitles":@[@{@"url":@"https://example.test/captions.srt",@"lang":@"en"},@{@"url":@"file:///etc/passwd"},NSNull.null,@{@"url":@"https:"},@{@"url":@"javascript:alert(1)"}]} meta:@{@"subtitles":@[@{@"url":@"https://example.test/captions.srt",@"name":@"Duplicate"},@{@"url":@"http://example.test/french.vtt",@"name":@"French"}]} allowBundled:NO];
check(provided.count==2,@"Provided choices deduplicate and reject invalid protocols");check([provided[0][@"name"]isEqual:@"en"],@"Language label fallback retained");
NSDictionary *fixture=@{@"subtitles":@[@{@"url":@"asset:subtitle-check.en.srt",@"lang":@"en"},@{@"url":@"asset:../private.srt"}]};
check(![RWSubtitles providedBySource:fixture meta:@{} allowBundled:NO].count,@"Normal metadata cannot load bundled test resources");check([RWSubtitles providedBySource:fixture meta:@{} allowBundled:YES].count==1,@"Diagnostic fixture permits only the named bundled subtitle");
NSMutableArray *large=[NSMutableArray new];for(int i=0;i<100;i++)[large addObject:@{@"url":[NSString stringWithFormat:@"https://example.test/%d.srt",i]}];check([RWSubtitles providedBySource:@{@"subtitles":large} meta:@{} allowBundled:NO].count==32,@"Provided language menu stays bounded");
NSFileManager *fm=[NSFileManager defaultManager];NSString *base=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];NSString *root=[base stringByAppendingPathComponent:@"Torrents"];[fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
@try{NSMutableData *data=[NSMutableData dataWithLength:64*1024];arc4random_buf(data.mutableBytes,data.length);NSString *outside=[base stringByAppendingPathComponent:@"outside"];[data writeToFile:outside atomically:YES];[data writeToFile:[root stringByAppendingPathComponent:@"temporary"] atomically:YES];[data writeToFile:[root stringByAppendingPathComponent:@"pinned"] atomically:YES];symlink(outside.fileSystemRepresentation,[root stringByAppendingPathComponent:@"link"].fileSystemRepresentation);
 NSDictionary *report=[RWMediaCache trimRoot:root pinned:[NSSet setWithObject:@"pinned"] budget:0];check(![fm fileExistsAtPath:[root stringByAppendingPathComponent:@"temporary"]],@"Only temporary download evicted at zero budget");check([fm fileExistsAtPath:[root stringByAppendingPathComponent:@"pinned"]],@"Pinned download survives cleanup");check([fm fileExistsAtPath:outside],@"Cleanup does not follow symlinks outside the cache");check([report[@"removed_entries"]intValue]==1,@"Cleanup reports actual evictions");
 NSString *active=[root stringByAppendingPathComponent:@"active"],*other=[root stringByAppendingPathComponent:@"other"];NSMutableData *bytes=[NSMutableData dataWithLength:65536];arc4random_buf(bytes.mutableBytes,bytes.length);[bytes writeToFile:active atomically:YES];[bytes writeToFile:other atomically:YES];
 uint64_t allocated=[RWMediaCache allocatedBytesAt:active];NSSet *busy=[NSSet setWithObject:@"active"],*pins=[NSSet setWithObject:@"pinned"];
 NSDictionary *r=[RWMediaCache trimRoot:root pinned:pins active:busy budget:0];
 check([fm fileExistsAtPath:active]&&![fm fileExistsAtPath:other],@"Live unkept data survives while idle data is evicted");
 check([r[@"temporary_bytes"]unsignedLongLongValue]==allocated&&[r[@"active_bytes"]unsignedLongLongValue]==allocated,@"Protected temporary allocation remains in cache accounting");
 r=[RWMediaCache trimRoot:root pinned:[NSSet setWithArray:@[@"active",@"pinned"]] active:busy budget:0];
 check([r[@"temporary_bytes"]unsignedLongLongValue]==0&&[r[@"active_bytes"]unsignedLongLongValue]==allocated,@"An active kept file is accounted as kept without duplicate temporary bytes");
 r=[RWMediaCache trimRoot:root pinned:pins active:[NSSet set] budget:0];
 check(![fm fileExistsAtPath:active]&&[r[@"active_bytes"]unsignedLongLongValue]==0,@"Releasing the final owner makes temporary data evictable");
}
@finally{[fm removeItemAtPath:base error:nil];}
printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;}}
