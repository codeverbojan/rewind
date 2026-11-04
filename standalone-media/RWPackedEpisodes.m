#import "RWPackedEpisodes.h"
#include <stdint.h>
static void Put16(NSMutableData *d,NSUInteger x){uint8_t b[2]={(uint8_t)x,(uint8_t)(x>>8)};[d appendBytes:b length:2];}
static void Put32(NSMutableData *d,NSUInteger x){uint8_t b[4]={(uint8_t)x,(uint8_t)(x>>8),(uint8_t)(x>>16),(uint8_t)(x>>24)};[d appendBytes:b length:4];}
static NSUInteger Get16(const uint8_t *b){return (NSUInteger)b[0]|((NSUInteger)b[1]<<8);}
static NSUInteger Get32(const uint8_t *b){return Get16(b)|(Get16(b+2)<<16);}
static BOOL Title(NSString *s){return [s isKindOfClass:NSString.class]&&s.length<=32&&[s rangeOfString:@"^tt[0-9]+$" options:NSRegularExpressionSearch].location==0&&[[s substringFromIndex:2]longLongValue]>0;}
@implementation RWPackedEpisodes {NSString *_title;NSData *_offsets,*_data;NSUInteger _count;}
- (instancetype)initWithTitle:(NSString *)title offsets:(NSData *)offsets data:(NSData *)data {
    if((self=[super init])){_title=[title copy];_offsets=[offsets copy];_data=[data copy];_count=offsets.length/4-1;}return self;
}
+ (instancetype)episodes:(NSArray *)ordered title:(NSString *)title {
    if(!Title(title)||!ordered.count||ordered.count>4096)return nil;
    NSMutableData *offsets=[NSMutableData new],*data=[NSMutableData new];NSUInteger previous=0;BOOL first=YES;
    for(NSDictionary *e in ordered){
        NSUInteger s=[e[@"season"]unsignedIntegerValue],n=[e[@"episode"]unsignedIntegerValue],order=s*10000+n;NSString *release=e[@"released"];
        if(s>100||n<1||n>2000||(!first&&order<=previous)||![e[@"id"]isEqual:[NSString stringWithFormat:@"%@:%lu:%lu",title,(unsigned long)s,(unsigned long)n]]||![release isKindOfClass:NSString.class]||release.length>40)return nil;
        NSData *date=[release dataUsingEncoding:NSUTF8StringEncoding];if(!date||date.length>160)return nil;
        Put32(offsets,data.length);Put16(data,s);Put16(data,n);Put16(data,date.length);[data appendData:date];previous=order;first=NO;
    }Put32(offsets,data.length);
    return [[self alloc]initWithTitle:title offsets:offsets data:data];
}
+ (instancetype)archive:(NSDictionary *)archive title:(NSString *)title {
    if(!Title(title)||![archive isKindOfClass:NSDictionary.class]||![archive[@"offsets"]isKindOfClass:NSString.class]||![archive[@"data"]isKindOfClass:NSString.class])return nil;
    NSString *indices=archive[@"offsets"],*content=archive[@"data"];
    // Bound encoded data BEFORE allocating/decoding. No compression bombs.
    if(indices.length>21852||content.length>906584)return nil;
    NSData *offsets=[[NSData alloc]initWithBase64EncodedString:indices options:0],*data=[[NSData alloc]initWithBase64EncodedString:content options:0];
    if(offsets.length<8||offsets.length>4097*4||offsets.length%4||data.length>4096*166)return nil;
    NSUInteger count=offsets.length/4-1,previous=0;const uint8_t *o=(const uint8_t *)offsets.bytes,*b=(const uint8_t *)data.bytes;
    if(Get32(o)!=0||Get32(o+count*4)!=data.length)return nil;
    for(NSUInteger i=0;i<count;i++){@autoreleasepool{
        NSUInteger start=Get32(o+i*4),end=Get32(o+(i+1)*4);if(start>data.length||end>data.length||end<start||end-start<6)return nil;
        NSUInteger s=Get16(b+start),n=Get16(b+start+2),len=Get16(b+start+4),order=s*10000+n;
        if(s>100||n<1||n>2000||(i&&order<=previous)||len>160||end-start!=6+len)return nil;
        NSString *date=[[NSString alloc]initWithBytes:b+start+6 length:len encoding:NSUTF8StringEncoding];if(!date||date.length>40)return nil;previous=order;
    }}return [[self alloc]initWithTitle:title offsets:offsets data:data];
}
- (NSUInteger)count {return _count;}
- (NSString *)titleIdentifier {return _title;}
- (NSDictionary *)episodeForID:(NSString *)identifier {
    if(![identifier isKindOfClass:NSString.class]||identifier.length>64)return nil;
    NSArray *parts=[identifier componentsSeparatedByString:@":"];if(parts.count!=3||![parts[0]isEqual:_title])return nil;
    NSInteger season=[parts[1]integerValue],episode=[parts[2]integerValue];
    if(season<0||season>100||episode<1||episode>2000||![identifier isEqual:[NSString stringWithFormat:@"%@:%ld:%ld",_title,(long)season,(long)episode]])return nil;
    NSUInteger wanted=season*10000+episode,lo=0,hi=_count;const uint8_t *o=(const uint8_t *)_offsets.bytes,*b=(const uint8_t *)_data.bytes;
    while(lo<hi){NSUInteger mid=lo+(hi-lo)/2,start=Get32(o+mid*4),order=Get16(b+start)*10000+Get16(b+start+2);
        if(order<wanted)lo=mid+1;else if(order>wanted)hi=mid;else return [self objectAtIndex:mid];
    }return nil;
}
- (id)objectAtIndex:(NSUInteger)index {
    if(index>=_count)[NSException raise:NSRangeException format:@"Episode index out of range"];
    const uint8_t *o=(const uint8_t *)_offsets.bytes,*b=(const uint8_t *)_data.bytes;NSUInteger start=Get32(o+index*4),s=Get16(b+start),n=Get16(b+start+2),len=Get16(b+start+4);
    NSString *date=[[NSString alloc]initWithBytes:b+start+6 length:len encoding:NSUTF8StringEncoding];
    return @{@"id":[NSString stringWithFormat:@"%@:%lu:%lu",_title,(unsigned long)s,(unsigned long)n],@"season":@(s),@"episode":@(n),@"released":date};
}
- (id)copyWithZone:(NSZone *)zone {return self;}
- (id)mutableCopyWithZone:(NSZone *)zone {NSMutableArray *out=[[NSMutableArray allocWithZone:zone]initWithCapacity:_count];for(NSUInteger i=0;i<_count;i++)[out addObject:[self objectAtIndex:i]];return out;}
- (NSDictionary *)archive {return @{@"offsets":[_offsets base64EncodedStringWithOptions:0],@"data":[_data base64EncodedStringWithOptions:0]};}
- (NSUInteger)storageBytes {return _offsets.length+_data.length+128+[_title lengthOfBytesUsingEncoding:NSUTF8StringEncoding];}
@end
