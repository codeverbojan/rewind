#import "RWMKVProbe.h"
#import "RWAudioPolicy.h"
#import <CoreMedia/CoreMedia.h>
#include <math.h>
#include <string.h>
static BOOL Var(const uint8_t *b,NSUInteger end,NSUInteger *pos,BOOL id,uint64_t *out){
    if(*pos>=end||!b[*pos])return NO;uint8_t mask=0x80;NSUInteger n=1;while(!(b[*pos]&mask)){n++;mask>>=1;}
    if(n>(id?4:8)||n>end-*pos)return NO;uint64_t v=id?b[*pos]:(b[*pos]&~mask);(*pos)++;
    for(NSUInteger i=1;i<n;i++)v=(v<<8)|b[(*pos)++];*out=v;return YES;
}
static BOOL Find(const uint8_t *b,NSUInteger begin,NSUInteger end,uint64_t wanted,NSRange *found){
    NSUInteger p=begin;for(NSUInteger i=0;i<10000&&p<end;i++){uint64_t id=0,n=0;if(!Var(b,end,&p,YES,&id)||!Var(b,end,&p,NO,&n))return NO;
        if(id==wanted){if(n>end-p&&id!=0x18538067)return NO;*found=NSMakeRange(p,(NSUInteger)MIN(n,(uint64_t)(end-p)));return YES;}
        if(n>end-p)return NO;p+=(NSUInteger)n;
    }return NO;
}
static NSData *Field(NSData *data,NSRange scope,uint64_t id){NSRange r;if(!Find((const uint8_t *)data.bytes,scope.location,NSMaxRange(scope),id,&r))return nil;return [data subdataWithRange:r];}
static uint64_t MKVUnsigned(NSData *d){if(d.length>8)return 0;const uint8_t *b=(const uint8_t *)d.bytes;uint64_t v=0;for(NSUInteger i=0;i<d.length;i++)v=v*256+b[i];return v;}
static double MKVFloat(NSData *d){uint64_t bits=MKVUnsigned(d);if(d.length==8){double value;memcpy(&value,&bits,8);return value;}if(d.length==4){uint32_t word=(uint32_t)bits;float value;memcpy(&value,&word,4);return value;}return NAN;}
static NSString *MKVText(NSData *d,NSUInteger limit){return d.length&&d.length<=limit?([[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]?:@""):@"";}
@implementation RWMKVProbe
+ (NSDictionary *)media:(NSData *)header {return [self media:header audioPreference:nil];}
+ (NSDictionary *)media:(NSData *)header audioPreference:(NSDictionary *)preference {
    NSDictionary *video=[self video:header];if(!video)return nil;
    NSMutableDictionary *media=[video mutableCopy];const uint8_t *bytes=(const uint8_t *)header.bytes;NSRange segment,tracks;
    if(!Find(bytes,0,header.length,0x18538067,&segment)||!Find(bytes,segment.location,NSMaxRange(segment),0x1654AE6B,&tracks))return nil;
    NSUInteger pos=tracks.location;NSInteger audioIndex=0;NSMutableArray *audioTracks=[NSMutableArray new],*subtitleTracks=[NSMutableArray new];NSMutableDictionary *rates=[NSMutableDictionary new],*details=[NSMutableDictionary new];
    for(int i=0;i<128&&pos<NSMaxRange(tracks);i++){
        uint64_t id,n;if(!Var(bytes,NSMaxRange(tracks),&pos,YES,&id)||!Var(bytes,NSMaxRange(tracks),&pos,NO,&n)||n>NSMaxRange(tracks)-pos)return nil;
        NSRange track=NSMakeRange(pos,(NSUInteger)n);pos+=(NSUInteger)n;if(id!=0xAE)continue;
        uint64_t type=MKVUnsigned(Field(header,track,0x83));
        if(type==17){NSData *bcp=Field(header,track,0x22B59D),*legacy=Field(header,track,0x22B59C),*enabled=Field(header,track,0xB9);
            [subtitleTracks addObject:@{@"containerNumber":@(MKVUnsigned(Field(header,track,0xD7))),@"uid":[@(MKVUnsigned(Field(header,track,0x73C5)))stringValue],@"codec":MKVText(Field(header,track,0x86),64),@"name":MKVText(Field(header,track,0x536E),512),@"language":[RWAudioPolicy language:MKVText(bcp?:legacy,64)],@"legacyLanguage":[RWAudioPolicy language:MKVText(legacy,64)],@"languageDeclared":@(bcp!=nil||legacy!=nil),@"forced":@(MKVUnsigned(Field(header,track,0x55AA))==1),@"sdh":@(MKVUnsigned(Field(header,track,0x55AB))==1),@"enabled":@(!enabled||MKVUnsigned(enabled)==1)}];continue;}
        if(type!=2)continue;
        NSInteger index=audioIndex++;NSRange settings;if(!Find(bytes,track.location,NSMaxRange(track),0xE1,&settings))continue;
        NSString *codec=[[NSString alloc]initWithData:Field(header,track,0x86) encoding:NSASCIIStringEncoding];
        NSData *channelData=Field(header,settings,0x9F),*rateData=Field(header,settings,0xB5),*outputData=Field(header,settings,0x78B5);
        uint64_t channels=channelData?MKVUnsigned(channelData):1;double rate=rateData?MKVFloat(rateData):8000,output=outputData?MKVFloat(outputData):rate;
        BOOL supported=[@[@"A_AAC",@"A_AAC/MPEG4/LC",@"A_AC3",@"A_EAC3",@"A_MPEG/L3",@"A_MPEG/L2"]containsObject:codec?:@""];
        NSData *enabled=Field(header,track,0xB9),*primary=Field(header,track,0x88);
        NSData *bcp=Field(header,track,0x22B59D),*legacy=Field(header,track,0x22B59C);
        // Missing language remains unknown even though Matroska's schema default
        // is English: a missing tag is not evidence of the spoken language.
        NSString *language=MKVText(bcp?:legacy,64);
        BOOL compatible=supported&&channels>0&&channels<=6&&isfinite(rate)&&rate>0&&rate<=48000&&isfinite(output)&&output>0&&output<=48000;
        [audioTracks addObject:@{@"id":@(index),@"language":language,@"name":MKVText(Field(header,track,0x536E),512),@"codec":codec?:@"",@"channels":@(channels),@"compatible":@(compatible),@"enabled":@(!enabled||MKVUnsigned(enabled)==1),@"default":@(!primary||MKVUnsigned(primary)==1),@"commentary":@(MKVUnsigned(Field(header,track,0x55AF))==1),@"description":@(MKVUnsigned(Field(header,track,0x55AC))==1)}];
        if(isfinite(output)&&output>0)rates[@(index).stringValue]=@(output);
        details[@(index).stringValue]=@{@"containerNumber":@(MKVUnsigned(Field(header,track,0xD7))),@"sampleRate":@(isfinite(output)?output:0),@"inputSampleRate":@(isfinite(rate)?rate:0),@"legacyLanguage":[RWAudioPolicy language:MKVText(legacy,64)],@"languageDeclared":@(legacy!=nil||bcp!=nil)};
    }
    if(pos<NSMaxRange(tracks))return nil;
    NSMutableArray *described=[NSMutableArray new];for(NSDictionary *t in [RWAudioPolicy tracks:audioTracks]){NSMutableDictionary *d=[t mutableCopy];[d addEntriesFromDictionary:details[[t[@"id"]stringValue]]];[described addObject:d];}
    media[@"audioTracks"]=described;media[@"audioRates"]=rates;media[@"subtitleTracks"]=subtitleTracks;
    return [self selectAudioInMedia:media preference:preference];
}
+ (NSDictionary *)selectAudioInMedia:(NSDictionary *)media preference:(NSDictionary *)preference {
    if(!media)return nil;NSMutableDictionary *result=[media mutableCopy];
    for(NSString *key in @[@"audioCodec",@"audioChannels",@"audioSampleRate",@"audioTrackIndex"])[result removeObjectForKey:key];
    NSDictionary *selection=[RWAudioPolicy selection:media[@"audioTracks"] preference:preference],*track=selection[@"track"];
    result[@"audioSelection"]=selection;result[@"legacyAudioDecodable"]=@(track!=nil);
    if(track){result[@"audioCodec"]=track[@"codec"];result[@"audioChannels"]=track[@"channels"];result[@"audioTrackIndex"]=track[@"id"];result[@"audioSampleRate"]=media[@"audioRates"][[track[@"id"]stringValue]]?:@0;}
    return result;
}

+ (NSDictionary *)video:(NSData *)header {
    if(!header.length||header.length>2*1024*1024)return nil;const uint8_t *bytes=(const uint8_t *)header.bytes;NSRange segment,tracks;
    if(!Find(bytes,0,header.length,0x18538067,&segment)||!Find(bytes,segment.location,NSMaxRange(segment),0x1654AE6B,&tracks))return nil;
    NSUInteger pos=tracks.location;for(int i=0;i<128&&pos<NSMaxRange(tracks);i++){uint64_t id,n;if(!Var(bytes,NSMaxRange(tracks),&pos,YES,&id)||!Var(bytes,NSMaxRange(tracks),&pos,NO,&n)||n>NSMaxRange(tracks)-pos)return nil;NSRange track=NSMakeRange(pos,(NSUInteger)n);pos+=(NSUInteger)n;
        if(id!=0xAE||MKVUnsigned(Field(header,track,0x83))!=1)continue;
        NSString *codec=[[NSString alloc]initWithData:Field(header,track,0x86) encoding:NSASCIIStringEncoding];if(!codec.length||codec.length>64)return nil;
        if(![codec isEqual:@"V_MPEG4/ISO/AVC"])return @{@"videoCodec":@"unsupported",@"containerVideoCodec":codec};
        NSData *avcc=Field(header,track,0x63A2);const uint8_t *b=(const uint8_t *)avcc.bytes;NSUInteger size=avcc.length;if(size<8||b[0]!=1)return nil;
        const uint8_t *sets[64];size_t sizes[64];NSUInteger cursor=6,count=0;unsigned sps=b[5]&31;
        if(!sps)return nil;
        for(unsigned group=0;group<2;group++){unsigned total=group?((cursor<size)?b[cursor++]:0):sps;if(!total||total>32)return nil;
            for(unsigned j=0;j<total;j++){if(cursor+2>size||count>=64)return nil;NSUInteger len=((NSUInteger)b[cursor]<<8)|b[cursor+1];cursor+=2;if(!len||len>size-cursor)return nil;sets[count]=b+cursor;sizes[count++]=len;cursor+=len;}
        }
        // Read profile/level from the SPS, not the container's claims.
        if(sizes[0]<4||(sets[0][0]&31)!=7)return nil;
        CMFormatDescriptionRef format=NULL;OSStatus status=CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,count,sets,sizes,(b[4]&3)+1,&format);
        if(status!=noErr||!format)return nil;CMVideoDimensions d=CMVideoFormatDescriptionGetDimensions(format);CFRelease(format);
        uint64_t nanoseconds=MKVUnsigned(Field(header,track,0x23E383));
        return @{@"videoCodec":@"avc1",@"containerVideoCodec":codec,@"width":@(d.width),@"height":@(d.height),@"profile":@(sets[0][1]),@"level":@(sets[0][3]),@"fps":@(nanoseconds?1e9/(double)nanoseconds:0)};
    }return nil;
}
@end
