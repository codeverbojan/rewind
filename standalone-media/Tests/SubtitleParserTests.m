#import <Foundation/Foundation.h>
#import "../RWSubtitles.h"
#include <math.h>
static int checks=0,failures=0;
static void Check(BOOL ok,NSString *s){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",s.UTF8String);}}
static NSString *SRT(NSString *s){return [NSString stringWithFormat:@"1\n00:00:01,000 --> 00:00:05,000\n%@",s];}
static NSDictionary *Parse(NSString *s){return [RWSubtitles parse:[s dataUsingEncoding:NSUTF8StringEncoding]format:@"" encoding:@"auto" cancelled:nil];}
static NSString *At(NSDictionary *r,double t){return [RWSubtitles textIn:r[@"cues"] at:t];}
int main(){@autoreleasepool{
    NSString *sample=SRT(@"Café — Привет");
    for(NSNumber *encoding in @[@(NSUTF8StringEncoding),@(NSUTF16LittleEndianStringEncoding),@(NSUTF16BigEndianStringEncoding)]){
        NSData *body=[sample dataUsingEncoding:encoding.unsignedIntegerValue];NSMutableData *bytes=[NSMutableData new];
        if(encoding.unsignedIntegerValue==NSUTF16LittleEndianStringEncoding){uint8_t bom[]={255,254};[bytes appendBytes:bom length:2];}
        if(encoding.unsignedIntegerValue==NSUTF16BigEndianStringEncoding){uint8_t bom[]={254,255};[bytes appendBytes:bom length:2];}[bytes appendData:body];
        Check([[RWSubtitles textIn:[RWSubtitles parse:bytes]at:2]isEqual:@"Café — Привет"],@"Unicode UTF8/UTF16 BOM content");
        if(encoding.unsignedIntegerValue!=NSUTF8StringEncoding)Check([RWSubtitles parse:bytes format:@"vtt" encoding:@"auto" cancelled:nil][@"cues"]&&![[RWSubtitles parse:bytes format:@"vtt" encoding:@"auto" cancelled:nil][@"cues"]count],@"WebVTT rejects UTF16");
    }
    NSData *invalidVTT=[@"WEBVTT\n\n00:01.000 --> 00:05.000\nCafé" dataUsingEncoding:NSWindowsCP1252StringEncoding];
    Check([[RWSubtitles parse:invalidVTT format:@"" encoding:@"auto" cancelled:nil][@"status"]isEqual:@"invalid"],@"VTT byte header requires UTF8 even without filename");
    NSArray *legacy=@[@[@"windows-1252",@(NSWindowsCP1252StringEncoding),@"Café"],@[@"windows-1251",@(NSWindowsCP1251StringEncoding),@"Привет мир"],@[@"windows-1250",@(NSWindowsCP1250StringEncoding),@"Příliš žluťoučký"]];
    for(NSArray *item in legacy){NSData *bytes=[SRT(item[2]) dataUsingEncoding:[item[1]unsignedIntegerValue]];NSDictionary *r=[RWSubtitles parse:bytes format:@"srt" encoding:@"auto" cancelled:nil];Check([r[@"status"]isEqual:@"needs_encoding"]&&!At(r,2).length,@"Ambiguous legacy bytes never guessed as western text");r=[RWSubtitles parse:bytes format:@"srt" encoding:item[0] cancelled:nil];Check([At(r,2)isEqual:item[2]]&&[r[@"encoding_basis"]isEqual:@"explicit_choice"],@"Explicit supported legacy mapping");}
    Check([At(Parse(@"\ufeffWEBVTT\r\n\r\n00:01.000 --> 00:05.000 align:start\r\nTom &amp; Jerry &lt;3 &#233; &#x1F642; &nbsp; &lrm;"),2)isEqual:@"Tom & Jerry <3 é 🙂 \u00a0 \u200e"],@"WebVTT named numeric and supplementary entities");
    Check([At(Parse(SRT(@"&amp;lt;b&amp;gt; &unknown; &#0; &#xD800; &#x110000;")),2)isEqual:@"&lt;b&gt; &unknown; &#0; &#xD800; &#x110000;"],@"Single entity pass, invalid values inert");
    Check([At(Parse(SRT(@"{\\an8}<i>Hello</i>\\NWorld <b>again</b>")),2)isEqual:@"Hello\nWorld again"],@"ASS override and supported formatting plain text");
    Check([At(Parse(SRT(@"2 < 3 > 1 and <font color='red'>red</font><br>line")),2)isEqual:@"2 < 3 > 1 and red\nline"],@"Literal comparison survives tags");
    Check([At(Parse(@"WEBVTT\n\nNOTE hidden\n00:01.000 --> 00:02.000\nBad\n\nSTYLE\n::cue {color:red}\n\nREGION\nid:a\n\nid1\n00:01.000 --> 00:05.000\n<v Alice><c.green>Hello</c><00:02.000> there"),2)isEqual:@"Hello there"],@"VTT comments styles regions identifiers voices and timestamps");
    NSDictionary *overlap=Parse(@"1\n00:00:01,000 --> 00:00:10,000\nLong line\n\n2\n00:00:02,000 --> 00:00:03,000\nShort line");
    Check([At(overlap,2.5)isEqual:@"Long line\nShort line"],@"Both active cues rendered");Check([At(overlap,4)isEqual:@"Long line"],@"Older cue survives newer short cue");Check(!At(overlap,10).length,@"End time exclusive");Check(!At(overlap,NAN).length&&!At(overlap,-1).length&&!At(overlap,INFINITY).length,@"Invalid player clock safe");
    Check([At(Parse(@"1\n00:00:01,000 --> 00:00:02,000\nOne\n\n2\n00:00:02,000 --> 00:00:03,000\nTwo"),2)isEqual:@"Two"],@"Touching cue boundaries");
    for(NSString *t in @[@"00:99:00,000",@"00:00:60,000",@"0:01,000",@"00:00:01,00",@"-01:00:00,000",@"25:00:00,000",@"1e0:00:00,000"]){NSString *s=[NSString stringWithFormat:@"1\n%@ --> 24:00:00,000\nBad",t];Check(![Parse(s)[@"cues"]count],@"Invalid time rejected");}
    Check(![Parse(@"WEBVTT\n\n00:01,000 --> 00:02,000\nBad")[@"cues"]count],@"WebVTT comma timestamps rejected");
    Check([[Parse(SRT(@"OK"))objectForKey:@"format"]isEqual:@"srt"],@"SRT auto detection");
    Check(![[RWSubtitles parse:[SRT(@"OK")dataUsingEncoding:NSUTF8StringEncoding]format:@"vtt" encoding:@"auto" cancelled:nil][@"cues"]count],@"Known VTT requires header");
    for(NSData *bad in @[[NSData data], [NSMutableData dataWithLength:2*1024*1024+1], [SRT(@"bad\ufffd")dataUsingEncoding:NSUTF8StringEncoding], [SRT(@"bad\x01")dataUsingEncoding:NSUTF8StringEncoding]])Check(![RWSubtitles parse:bad].count,@"Bounds replacement/control bytes rejected");
    uint8_t corrupt[]={0xff,0xfe,0,0,0x41};Check(![RWSubtitles parse:[NSData dataWithBytes:corrupt length:sizeof(corrupt)]].count,@"UTF32 rejected explicitly");
    Check([Parse(SRT([@"x" stringByPaddingToLength:2049 withString:@"x" startingAtIndex:0]))[@"status"]isEqual:@"invalid"],@"Per cue text cap");
    NSMutableString *crowded=[NSMutableString new];for(int i=0;i<33;i++)[crowded appendFormat:@"%d\n00:00:01,000 --> 00:00:10,000\nLine %d\n\n",i,i];Check([Parse(crowded)[@"status"]isEqual:@"limit"],@"Concurrent cue budget enforced");
    NSMutableString *large=[NSMutableString new];for(int i=0;i<10000;i++)[large appendFormat:@"%d\n%02d:%02d:%02d,000 --> %02d:%02d:%02d,000\nCaption %d\n\n",i,i/3600,(i/60)%60,i%60,(i+1)/3600,((i+1)/60)%60,(i+1)%60,i];
    double began=NSProcessInfo.processInfo.systemUptime;NSDictionary *many=Parse(large);double parseSeconds=NSProcessInfo.processInfo.systemUptime-began;
    Check([many[@"cues"]count]==10000&&[many[@"index_bytes"]unsignedIntegerValue]<=262144,@"10K cues bounded index");
    began=NSProcessInfo.processInfo.systemUptime;BOOL lookups=YES;for(int i=0;i<10000;i++)if(![At(many,i+.5)isEqual:[NSString stringWithFormat:@"Caption %d",i]])lookups=NO;double lookupSeconds=NSProcessInfo.processInfo.systemUptime-began;Check(lookups,@"10K forward lookups against independent known text");
    for(int i=9999;i>=0;i-=37)Check([At(many,i+.5)isEqual:[NSString stringWithFormat:@"Caption %d",i]],@"Backward seeks preserve cue identity");
    [large appendString:SRT(@"Extra")];Check([Parse(large)[@"status"]isEqual:@"limit"],@"More than10K cues rejected rather than silently truncated");
    __block int polls=0;NSDictionary *cancelled=[RWSubtitles parse:[large dataUsingEncoding:NSUTF8StringEncoding]format:@"srt" encoding:@"auto" cancelled:^BOOL{return ++polls>20;}];Check([cancelled[@"status"]isEqual:@"cancelled"]&&![cancelled[@"cues"]count],@"Cancellation yields no partial subtitle");
    // Independent scan oracle for nested, crossing and equal-start intervals.
    NSMutableString *random=[NSMutableString new];NSMutableArray *oracle=[NSMutableArray new];srand(242);
    for(int i=0;i<80;i++){int a=rand()%500,b=a+1+rand()%20;NSString *label=[NSString stringWithFormat:@"L%d",i];[oracle addObject:@{@"start":@(a),@"end":@(b),@"text":label,@"order":@(i)}];[random appendFormat:@"%d\n00:%02d:%02d,000 --> 00:%02d:%02d,000\n%@\n\n",i,a/60,a%60,b/60,b%60,label];}
    [oracle sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSComparisonResult n=[a[@"start"]compare:b[@"start"]];return n==NSOrderedSame?[a[@"order"]compare:b[@"order"]]:n;}];NSDictionary *indexed=Parse(random);
    for(int t=0;t<520;t++){NSMutableArray *expected=[NSMutableArray new];for(NSDictionary *cue in oracle)if(t>=[cue[@"start"]intValue]&&t<[cue[@"end"]intValue])[expected addObject:cue[@"text"]];Check([At(indexed,t)isEqual:[expected componentsJoinedByString:@"\n"]],@"Indexed overlaps match independent scan oracle");}
    printf("{\"checks\":%d,\"failures\":%d,\"parse_10000_seconds\":%.6f,\"lookup_10000_seconds\":%.6f}\n",checks,failures,parseSeconds,lookupSeconds);return failures?1:0;
}}
