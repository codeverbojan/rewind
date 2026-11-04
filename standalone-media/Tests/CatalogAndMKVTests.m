#import <Foundation/Foundation.h>
#import "../RWCatalogPolicy.h"
#import "../RWMKVProbe.h"
#import "../RWSourcePolicy.h"
static int checks,failures;
static void check(BOOL ok,NSString *message){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",message.UTF8String);}}
int main(int argc,char **argv){@autoreleasepool{
    NSDate *now=[NSDate dateWithTimeIntervalSince1970:1792540800];
    NSDictionary *old=@{@"id":@"old",@"name":@"Old",@"releaseInfo":@"1999",@"released":@"1999-05-10",@"imdbRating":@"8.4",@"genres":@[@"Comedy"]};
    NSDictionary *newer=@{@"id":@"new",@"name":@"New",@"releaseInfo":@"2026",@"released":@"2026-09-10",@"imdbRating":@"7.1",@"genres":@[@"Comedy"]};
    NSDictionary *future=@{@"id":@"future",@"name":@"Future",@"releaseInfo":@"2027",@"released":@"2027-01-10",@"imdbRating":@"9.1"};
    NSDictionary *unknown=@{@"id":@"unknown",@"name":@"Unknown",@"releaseInfo":@"2026",@"imdbRating":NSNull.null,@"genres":NSNull.null};
    NSArray *all=@[old,newer,newer,future,unknown,NSNull.null];
    check([RWCatalogPolicy filter:all genre:nil year:0 rating:0 sort:@"Popular" now:now].count==3,@"Exclude future titles, duplicates and malformed records");
    check([RWCatalogPolicy filter:all genre:@"Comedy" year:2026 rating:7 sort:@"Popular" now:now].count==1,@"Combined genre/year/rating constraints");
    check([RWCatalogPolicy filter:all genre:nil year:0 rating:8 sort:@"Popular" now:now].count==1,@"Unknown ratings cannot pass a minimum");
    check([[RWCatalogPolicy filter:all genre:nil year:0 rating:0 sort:@"Newest" now:now][0][@"id"]isEqual:@"new"],@"Newest orders release dates");
    check([[RWCatalogPolicy filter:all genre:nil year:0 rating:0 sort:@"Top rated" now:now][0][@"id"]isEqual:@"old"],@"Top rating sorts numerically");
    check([[RWCatalogPolicy URLForType:@"movie" sort:@"Newest" genre:nil year:0 skip:0 now:now]containsString:@"year/genre=2026"],@"Newest requests this year's catalog");
    check([[RWCatalogPolicy URLForType:@"series" sort:@"Popular" genre:@"Sci-Fi" year:1999 skip:50 now:now]containsString:@"year/genre=1999&skip=50"],@"Year filter changes the actual provider query");
    check([[RWCatalogPolicy URLForType:@"movie" sort:@"Top rated" genre:@"Comedy" year:0 skip:0 now:now]containsString:@"imdbRating/genre=Comedy"],@"Top-rated genre uses the supported catalog");
    check(![RWCatalogPolicy URLForType:@"../bad" sort:nil genre:nil year:0 skip:0 now:now],@"Type injection rejected");
    check(![RWCatalogPolicy URLForType:@"movie" sort:nil genre:nil year:2027 skip:0 now:now],@"Future year rejected");
    check(![RWCatalogPolicy URLForType:@"movie" sort:nil genre:nil year:1800 skip:0 now:now],@"Invalid year rejected");
    NSDictionary *source=@{@"url":@"magnet:example",@"filename":@"Show.S01E01.720p.WEB-DL.H264.AC3.mkv"};
    [RWSourcePolicy setLegacyEnabled:NO];check(![[RWSourcePolicy evaluate:source quality:0 freeBytes:0][@"eligible"]boolValue],@"MKV cannot be enabled before the device check");
    [RWSourcePolicy setLegacyEnabled:YES];check([[RWSourcePolicy evaluate:source quality:720 freeBytes:0][@"eligible"]boolValue],@"Qualified engine admits MKV for an actual media probe");
    for(NSString *bad in @[@"Show.720p.WEB-DL.HEVC.mkv",@"Show.2160p.WEB-DL.H264.mkv",@"Show.1080p.HDCAM.H264.mkv",@"Show.720p.WEB-DL.H264.10bit.mkv"]){check(![[RWSourcePolicy evaluate:@{@"filename":bad} quality:0 freeBytes:0][@"eligible"]boolValue],@"MKV path retains codec/resolution/origin limits");}
    check(![[RWSourcePolicy evaluate:source quality:1080 freeBytes:0][@"eligible"]boolValue],@"MKV respects fixed quality");[RWSourcePolicy setLegacyEnabled:NO];
    NSData *mkv=argc>1?[NSData dataWithContentsOfFile:@(argv[1])]:nil;NSDictionary *probe=[RWMKVProbe video:mkv];
    NSDictionary *sound=[RWMKVProbe media:mkv];
    check([sound[@"legacyAudioDecodable"]boolValue]&&[sound[@"audioChannels"]intValue]==1,@"Actual mono AAC is parsed without VLC preparse");
    check([sound[@"audioSampleRate"]intValue]==44100&&[sound[@"audioTrackIndex"]intValue]==0,@"Big-endian audio rate and selected audio index are read");
    NSData *surround=argc>2?[NSData dataWithContentsOfFile:@(argv[2])]:nil;NSDictionary *six=[RWMKVProbe media:surround];
    check([six[@"audioChannels"]intValue]==6&&[six[@"audioSampleRate"]intValue]==48000&&[six[@"legacyAudioDecodable"]boolValue],@"The six-channel callback test passes track-header limits");
    check(![RWSourcePolicy mediaRejection:six quality:360],@"Video and audio header checks agree for the callback test");
    NSMutableData *unsupported=[surround mutableCopy];NSData *aac=[@"A_AAC"dataUsingEncoding:NSASCIIStringEncoding];NSRange codec=[unsupported rangeOfData:aac options:0 range:NSMakeRange(0,MIN(unsupported.length,(NSUInteger)2048))];
    check(codec.location!=NSNotFound,@"Audio codec mutation uses an actual track header");
    if(codec.location!=NSNotFound)[unsupported replaceBytesInRange:codec withBytes:"A_DTS"];
    check(![[RWMKVProbe media:unsupported][@"legacyAudioDecodable"]boolValue],@"Unsupported DTS cannot enter through the callback path");
    const uint8_t sixBytes[]={0x9F,0x81,0x06};NSData *channelTag=[NSData dataWithBytes:sixBytes length:3];NSMutableData *eight=[surround mutableCopy];NSRange channel=[eight rangeOfData:channelTag options:0 range:NSMakeRange(0,MIN(eight.length,(NSUInteger)2048))];
    check(channel.location!=NSNotFound,@"Channel mutation locates the six-channel field");
    if(channel.location!=NSNotFound){uint8_t value=8;[eight replaceBytesInRange:NSMakeRange(channel.location+2,1) withBytes:&value];}
    check(![[RWMKVProbe media:eight][@"legacyAudioDecodable"]boolValue],@"Eight-channel layout remains outside the supported bound");
    BOOL audioSafe=YES;@try{for(int n=1;n<1024;n++){[RWMKVProbe media:[surround subdataWithRange:NSMakeRange(0,MIN((NSUInteger)n,surround.length))]];}}@catch(NSException *e){audioSafe=NO;}
    check(audioSafe,@"Truncated video and audio track headers never read past available bytes");
    check([probe[@"width"]intValue]==640&&[probe[@"height"]intValue]==360,@"SPS proves real test-video dimensions");
    check([probe[@"profile"]intValue]==66&&[probe[@"level"]intValue]>0,@"H264 profile and level read from SPS");
    check([probe[@"fps"]doubleValue]>23.9&&[probe[@"fps"]doubleValue]<24.1,@"MKV DefaultDuration supplies frame rate");
    check(![RWMKVProbe video:[NSData data]],@"Empty header rejected");
    check(![RWMKVProbe video:[mkv subdataWithRange:NSMakeRange(0,MIN((NSUInteger)20,mkv.length))]],@"Truncated header waits for more data");
    check(![RWMKVProbe video:[NSMutableData dataWithLength:2*1024*1024+1]],@"Header parsing is memory bounded");
    BOOL safe=YES;@try{for(int n=1;n<512;n++){NSData *shortHeader=[mkv subdataWithRange:NSMakeRange(0,MIN((NSUInteger)n,mkv.length))];[RWMKVProbe video:shortHeader];}}@catch(NSException *e){safe=NO;}check(safe,@"Every short prefix handles incomplete EBML safely");
    NSMutableDictionary *actual=[probe mutableCopy];actual[@"legacyAudioDecodable"]=@YES;check(![RWSourcePolicy mediaRejection:actual quality:360],@"Actual MKV sample passes the same video limits");actual[@"width"]=@3840;check([RWSourcePolicy mediaRejection:actual quality:0]!=nil,@"Decoded audio support does not bypass UHD limits");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
