// Plain-text SRT/WebVTT only. No HTML/CSS/ASS renderer or document execution.
// A max-end segment index finds all active cues without a full scan per frame.
@interface RWSubtitleTimeline : NSArray
@property(nonatomic,strong) NSArray *items;
@property(nonatomic,strong) NSData *ends;
@property(nonatomic,assign) NSUInteger width;
- (NSString *)textAt:(double)time;
@end
static void RWSubtitleActive(NSArray *items,const double *ends,NSUInteger width,NSUInteger node,NSUInteger left,NSUInteger right,double time,NSMutableArray *out) {
    if(left>=items.count||ends[node]<=time||[items[left][@"start"]doubleValue]>time)return;
    if(right-left==1){[out addObject:items[left][@"text"]];return;}
    NSUInteger mid=left+(right-left)/2;
    RWSubtitleActive(items,ends,width,node*2,left,mid,time,out);
    RWSubtitleActive(items,ends,width,node*2+1,mid,right,time,out);
}
static NSString *RWSubtitleJoin(NSArray *parts) {
    NSMutableString *out=[NSMutableString new];NSMutableSet *seen=[NSMutableSet new];
    for(NSString *part in parts){if([seen containsObject:part])continue;[seen addObject:part];if(out.length)[out appendString:@"\n"];[out appendString:part];
        if(out.length>2048){NSRange last=[out rangeOfComposedCharacterSequenceAtIndex:2046];
            // Do not split emoji/surrogate pairs, including very long clusters.
            NSUInteger keep=NSMaxRange(last)<=2047?NSMaxRange(last):last.location;
            return [[out substringToIndex:keep]stringByAppendingString:@"…"];}}
    return out;
}
@implementation RWSubtitleTimeline
- (NSUInteger)count {return self.items.count;}
- (id)objectAtIndex:(NSUInteger)index {return self.items[index];}
- (id)copyWithZone:(NSZone *)zone {return self;}
- (NSString *)textAt:(double)time {
    if(!isfinite(time)||time<0||!self.count)return @"";
    NSMutableArray *active=[NSMutableArray new];RWSubtitleActive(self.items,(const double *)self.ends.bytes,self.width,1,0,self.width,time,active);return RWSubtitleJoin(active);
}
@end
static BOOL RWSubtitleCancelled(BOOL(^cancelled)(void)){return cancelled&&cancelled();}
static NSDictionary *RWSubtitleFailure(NSString *status,NSString *error) {return @{@"status":status,@"error":error,@"cues":@[]};}
static NSRegularExpression *RWSubtitleTimePattern(void) {
    static NSRegularExpression *r;static dispatch_once_t once;dispatch_once(&once,^{r=[NSRegularExpression regularExpressionWithPattern:@"^(?:([0-9]{2,}):)?([0-9]{2}):([0-9]{2})([.,])([0-9]{3})$" options:0 error:nil];});return r;
}
static double RWSubtitleTime(NSString *value,BOOL vtt) {
    if(value.length>20)return -1;NSTextCheckingResult *m=[RWSubtitleTimePattern()firstMatchInString:value options:0 range:NSMakeRange(0,value.length)];if(!m)return -1;
    NSInteger hours=[m rangeAtIndex:1].location==NSNotFound?0:[[value substringWithRange:[m rangeAtIndex:1]]integerValue];
    NSInteger minutes=[[value substringWithRange:[m rangeAtIndex:2]]integerValue],seconds=[[value substringWithRange:[m rangeAtIndex:3]]integerValue];
    if(hours>24||minutes>59||seconds>59||(vtt&&![[value substringWithRange:[m rangeAtIndex:4]]isEqual:@"."]))return -1;
    return hours*3600+minutes*60+seconds+[[value substringWithRange:[m rangeAtIndex:5]]integerValue]/1000.0;
}
static NSString *RWSubtitleEntity(NSString *s) {
    static NSDictionary *named;static dispatch_once_t once;dispatch_once(&once,^{named=@{@"amp":@"&",@"lt":@"<",@"gt":@">",@"nbsp":@"\u00a0",@"lrm":@"\u200e",@"rlm":@"\u200f",@"quot":@"\"",@"apos":@"'"};});
    if(named[s])return named[s];if(![s hasPrefix:@"#"]||s.length<2)return nil;
    BOOL hex=s.length>2&&([[s substringWithRange:NSMakeRange(1,1)]lowercaseString].UTF8String[0]=='x');NSUInteger start=hex?2:1;uint32_t point=0;
    for(NSUInteger i=start;i<s.length;i++){unichar c=[s characterAtIndex:i];int n=c>='0'&&c<='9'?c-'0':hex&&c>='a'&&c<='f'?c-'a'+10:hex&&c>='A'&&c<='F'?c-'A'+10:-1;if(n<0||point>0x10ffff/(hex?16:10))return nil;point=point*(hex?16:10)+n;}
    if(point<32||(point>=0x7f&&point<=0x9f)||point>0x10ffff||(point>=0xd800&&point<=0xdfff)||(point&0xffff)>=0xfffe)return nil;
    if(point<=0xffff){unichar c=(unichar)point;return [NSString stringWithCharacters:&c length:1];}
    point-=0x10000;unichar pair[]={(unichar)(0xd800+(point>>10)),(unichar)(0xdc00+(point&1023))};return [NSString stringWithCharacters:pair length:2];
}
static NSString *RWSubtitlePlain(NSString *body) {
    if(body.length>8192)return nil;NSMutableString *plain=[NSMutableString new];BOOL ass=NO;
    for(NSUInteger i=0;i<body.length;){unichar ch=[body characterAtIndex:i];
        if(ch=='{'&&i+1<body.length&&[body characterAtIndex:i+1]=='\\'){
            NSRange end=[body rangeOfString:@"}" options:0 range:NSMakeRange(i,MIN((NSUInteger)512,body.length-i))];
            if(end.location!=NSNotFound){ass=YES;i=end.location+1;continue;}}
        if(ch=='<'){
            NSRange end=[body rangeOfString:@">" options:0 range:NSMakeRange(i,MIN((NSUInteger)512,body.length-i))];
            if(end.location!=NSNotFound){NSString *tag=[body substringWithRange:NSMakeRange(i+1,end.location-i-1)];
                NSString *lower=tag.lowercaseString;if([lower hasPrefix:@"/"])lower=[lower substringFromIndex:1];
                unichar first=lower.length?[lower characterAtIndex:0]:0;
                if((first>='a'&&first<='z')||RWSubtitleTime(tag,YES)>=0){if([lower isEqual:@"br"]||[lower isEqual:@"br/"]||[lower isEqual:@"br /"])[plain appendString:@"\n"];i=end.location+1;continue;}}}
        if(ch=='&'){
            NSRange end=[body rangeOfString:@";" options:0 range:NSMakeRange(i,MIN((NSUInteger)16,body.length-i))];
            if(end.location!=NSNotFound){NSString *decoded=RWSubtitleEntity([body substringWithRange:NSMakeRange(i+1,end.location-i-1)]);if(decoded){[plain appendString:decoded];i=end.location+1;continue;}}}
        if(ass&&ch=='\\'&&i+1<body.length){unichar next=[body characterAtIndex:i+1];if(next=='N'||next=='n'||next=='h'){[plain appendString:next=='h'?@"\u00a0":@"\n"];i+=2;continue;}}
        [plain appendString:[body substringWithRange:NSMakeRange(i,1)]];i++;
    }
    plain=(id)[plain stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];return plain.length<=2048?plain:nil;
}
static NSDictionary *RWSubtitleDecode(NSData *data,NSString *format,NSString *choice) {
    if(!data.length||data.length>2*1024*1024)return RWSubtitleFailure(@"invalid",@"Subtitle files must be smaller than 2 MB.");
    const uint8_t *b=(const uint8_t *)data.bytes;BOOL utf16=data.length>=2&&((b[0]==0xff&&b[1]==0xfe)||(b[0]==0xfe&&b[1]==0xff));
    BOOL utf32=data.length>=4&&((b[0]==0xff&&b[1]==0xfe&&b[2]==0&&b[3]==0)||(b[0]==0&&b[1]==0&&b[2]==0xfe&&b[3]==0xff));
    if(utf32)return RWSubtitleFailure(@"invalid",@"This subtitle encoding is not supported. Use UTF-8 SRT or WebVTT.");
    NSUInteger bom=data.length>=3&&b[0]==0xef&&b[1]==0xbb&&b[2]==0xbf?3:0;
    BOOL rawVTT=data.length>=bom+6&&!memcmp(b+bom,"WEBVTT",6)&&(data.length==bom+6||b[bom+6]=='\n'||b[bom+6]=='\r'||b[bom+6]==' '||b[bom+6]=='\t');
    BOOL vtt=[format.lowercaseString isEqual:@"vtt"]||rawVTT;NSString *encoding=@"utf-8",*basis=@"valid_unicode",*text=nil;
    if(utf16){if(vtt)return RWSubtitleFailure(@"invalid",@"WebVTT subtitles must use UTF-8.");encoding=b[0]==0xff?@"utf-16le":@"utf-16be";basis=@"unicode_bom";text=[[NSString alloc]initWithData:[data subdataWithRange:NSMakeRange(2,data.length-2)]encoding:b[0]==0xff?NSUTF16LittleEndianStringEncoding:NSUTF16BigEndianStringEncoding];}
    else if(choice.length&&![choice isEqual:@"auto"]){
        NSDictionary *m=@{@"windows-1252":@(NSWindowsCP1252StringEncoding),@"windows-1251":@(NSWindowsCP1251StringEncoding),@"windows-1250":@(NSWindowsCP1250StringEncoding),@"utf-8":@(NSUTF8StringEncoding)};
        if(!m[choice]||(vtt&&![choice isEqual:@"utf-8"]))return RWSubtitleFailure(@"invalid",@"This text encoding is not supported for this file.");
        encoding=choice;basis=@"explicit_choice";text=[[NSString alloc]initWithData:data encoding:[m[choice]unsignedIntegerValue]];
    }else text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    if(!text){if(!vtt&&!utf16&&(!choice.length||[choice isEqual:@"auto"]))return RWSubtitleFailure(@"needs_encoding",@"This file uses an older text encoding. Choose the language group so its letters display correctly.");return RWSubtitleFailure(@"invalid",@"This file cannot be read with that text encoding.");}
    if([text hasPrefix:@"\ufeff"])text=[text substringFromIndex:1];
    BOOL header=[text hasPrefix:@"WEBVTT"]&&(text.length==6||[[NSCharacterSet whitespaceAndNewlineCharacterSet]characterIsMember:[text characterAtIndex:6]]);
    if(header&&![encoding isEqual:@"utf-8"])return RWSubtitleFailure(@"invalid",@"WebVTT subtitles must use UTF-8.");
    if(vtt&&!header)return RWSubtitleFailure(@"invalid",@"This WebVTT file is missing its header.");
    for(NSUInteger i=0;i<text.length;i++){unichar c=[text characterAtIndex:i];if(c==0xfffd||(c<32&&c!=9&&c!=10&&c!=13)||(c>=0x7f&&c<=0x9f))return RWSubtitleFailure(@"invalid",@"The subtitle text contains unreadable characters. Try another file or text encoding.");}
    return @{@"text":text,@"format":header?@"vtt":@"srt",@"encoding":encoding,@"encoding_basis":basis};
}
static void RWSubtitleBlock(NSArray *lines,BOOL vtt,NSMutableArray *cues,NSUInteger *rejected) {
    if(!lines.count)return;NSString *first=lines[0];
    if(vtt&&([first isEqual:@"NOTE"]||[first hasPrefix:@"NOTE "]||[first hasPrefix:@"NOTE\t"]||[first isEqual:@"STYLE"]||[first isEqual:@"REGION"]||[first hasPrefix:@"WEBVTT"]))return;
    NSUInteger index=[first rangeOfString:@"-->"].location!=NSNotFound?0:1;
    if(index>=lines.count)return;NSString *timing=lines[index];if(timing.length>256){(*rejected)++;return;}
    NSArray *times=[timing componentsSeparatedByString:@"-->"];if(times.count!=2){(*rejected)++;return;}
    NSString *a=[times[0]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet],*rest=[times[1]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSRange space=[rest rangeOfCharacterFromSet:NSCharacterSet.whitespaceCharacterSet];NSString *b=space.location==NSNotFound?rest:[rest substringToIndex:space.location];
    double start=RWSubtitleTime(a,vtt),end=RWSubtitleTime(b,vtt);if(start<0||end<=start||end>86400){(*rejected)++;return;}
    NSString *body=[[lines subarrayWithRange:NSMakeRange(index+1,lines.count-index-1)]componentsJoinedByString:@"\n"],*plain=RWSubtitlePlain(body);
    if(!plain.length){(*rejected)++;return;}[cues addObject:@{@"start":@(start),@"end":@(end),@"text":plain,@"order":@(cues.count)}];
}
static NSDictionary *RWSubtitleParse(NSData *data,NSString *format,NSString *choice,BOOL(^cancelled)(void)) {
    if(RWSubtitleCancelled(cancelled))return RWSubtitleFailure(@"cancelled",@"");
    NSDictionary *decoded=RWSubtitleDecode(data,format,choice);if(!decoded[@"text"])return decoded;
    NSString *text=decoded[@"text"];BOOL vtt=[decoded[@"format"]isEqual:@"vtt"];NSMutableArray *cues=[NSMutableArray new],*block=[NSMutableArray new];NSUInteger rejected=0,blockBytes=0,lines=0;BOOL oversized=NO;
    for(NSUInteger offset=0;offset<=text.length;){
        if(RWSubtitleCancelled(cancelled))return RWSubtitleFailure(@"cancelled",@"");
        if(++lines>100000)return RWSubtitleFailure(@"limit",@"This subtitle file has too many lines.");
        NSRange end=[text rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet options:0 range:NSMakeRange(offset,text.length-offset)];NSUInteger stop=end.location==NSNotFound?text.length:end.location;
        NSString *line=[text substringWithRange:NSMakeRange(offset,stop-offset)];
        if(![line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length||offset==text.length){
            if(oversized)rejected++;else RWSubtitleBlock(block,vtt,cues,&rejected);[block removeAllObjects];blockBytes=0;oversized=NO;
        }else if(!oversized){blockBytes+=line.length;if(blockBytes>9216||block.count>=128){[block removeAllObjects];oversized=YES;}else [block addObject:line];}
        if(cues.count>10000)return RWSubtitleFailure(@"limit",@"This subtitle file contains more than 10,000 captions.");
        if(end.location==NSNotFound){if(offset<text.length){offset=text.length;continue;}break;}
        offset=stop+1;if([text characterAtIndex:stop]=='\r'&&offset<text.length&&[text characterAtIndex:offset]=='\n')offset++;
    }
    if(!cues.count)return RWSubtitleFailure(@"invalid",@"This file did not contain readable subtitle timings.");
    [cues sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSComparisonResult c=[a[@"start"]compare:b[@"start"]];return c==NSOrderedSame?[a[@"order"]compare:b[@"order"]]:c;}];
    // At most32 simultaneous cues. Reject pathological files instead of keeping
    // an unbounded list or silently losing an older caption after a short cue.
    NSMutableArray *active=[NSMutableArray new];for(NSDictionary *cue in cues){if(RWSubtitleCancelled(cancelled))return RWSubtitleFailure(@"cancelled",@"");double time=[cue[@"start"]doubleValue];
        for(NSInteger i=active.count-1;i>=0;i--)if([active[i]doubleValue]<=time)[active removeObjectAtIndex:i];[active addObject:cue[@"end"]];if(active.count>32)return RWSubtitleFailure(@"limit",@"Too many subtitle captions overlap. Try another subtitle file.");}
    RWSubtitleTimeline *timeline=[RWSubtitleTimeline new];timeline.items=[cues copy];NSUInteger width=1;while(width<cues.count)width*=2;timeline.width=width;
    NSMutableData *ends=[NSMutableData dataWithLength:width*2*sizeof(double)];double *values=(double *)ends.mutableBytes;
    for(NSUInteger i=0;i<cues.count;i++)values[width+i]=[cues[i][@"end"]doubleValue];for(NSUInteger i=width-1;i>0;i--)values[i]=MAX(values[i*2],values[i*2+1]);timeline.ends=ends;
    return @{@"status":@"ok",@"cues":timeline,@"encoding":decoded[@"encoding"],@"encoding_basis":decoded[@"encoding_basis"],@"format":decoded[@"format"],@"rejected_cues":@(rejected),@"index_bytes":@(ends.length)};
}
