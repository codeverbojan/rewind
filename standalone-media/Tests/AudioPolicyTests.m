#import <Foundation/Foundation.h>
#import "../RWAudioPolicy.h"
#import "../RWMKVProbe.h"
static int checks,failures;
static void Check(BOOL ok,NSString *message){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",message.UTF8String);}}
static NSDictionary *Track(int index,NSString *lang,NSString *name,int channels,BOOL ok){return @{@"id":@(index),@"language":lang,@"name":name,@"channels":@(channels),@"compatible":@(ok),@"codec":@"AAC"};}
static NSDictionary *Pick(NSArray *tracks,NSDictionary *p){return [RWAudioPolicy selection:[RWAudioPolicy tracks:tracks] preference:p];}
static NSData *UIntData(uint64_t n){uint8_t bytes[8];int length=0;do{bytes[7-length++]=n&255;n>>=8;}while(n);return [NSData dataWithBytes:bytes+8-length length:length];}
static NSData *Element(uint64_t tag,NSData *data){NSMutableData *out=[UIntData(tag)mutableCopy];uint64_t size=data.length;int n=1;while(size>=((1ULL<<(7*n))-1))n++;uint8_t b[8];for(int i=n-1;i>=0;i--){b[i]=size&255;size>>=8;}b[0]|=1<<(8-n);[out appendBytes:b length:n];[out appendData:data];return out;}
static NSData *Join(NSArray *fields){NSMutableData *d=[NSMutableData new];for(NSData *f in fields)[d appendData:f];return d;}
static NSData *String(NSString *s){return [s dataUsingEncoding:NSUTF8StringEncoding];}
static NSData *Audio(NSString *language,NSString *bcp,NSString *name,BOOL commentary,BOOL description,BOOL enabled,NSString *codec,int channels){
    uint8_t rate[]={0x47,0x2c,0x44,0}; // 44100, IEEE754 big endian.
    NSMutableArray *f=[@[
        Element(0x83,UIntData(2)),Element(0x86,String(codec)),Element(0xB9,UIntData(enabled)),
        Element(0x88,UIntData(1)),Element(0x55AF,UIntData(commentary)),Element(0x55AC,UIntData(description)),
        Element(0x536E,String(name)),Element(0xE1,Join(@[Element(0x9F,UIntData(channels)),Element(0xB5,[NSData dataWithBytes:rate length:4])]))]mutableCopy];
    if(language)[f addObject:Element(0x22B59C,String(language))];if(bcp)[f addObject:Element(0x22B59D,String(bcp))];return Element(0xAE,Join(f));
}
// Extract the original, valid H264 video track; all audio metadata is authored
// independently of the production parser and contains no media payload.
static uint64_t Var(NSData *d,NSUInteger *p,BOOL id){const uint8_t *b=d.bytes;uint8_t mask=128;int n=1;while(!(b[*p]&mask)){mask>>=1;n++;}uint64_t v=id?b[*p]:b[*p]&~mask;(*p)++;while(--n)v=v*256+b[(*p)++];return v;}
static NSData *Find(NSData *d,uint64_t wanted){NSUInteger p=0;while(p<d.length){uint64_t tag=Var(d,&p,YES),n=Var(d,&p,NO);n=MIN(n,d.length-p);if(tag==wanted)return [d subdataWithRange:NSMakeRange(p,n)];p+=n;}return nil;}
static NSData *Header(NSData *video,NSArray *audio){NSMutableArray *tracks=[NSMutableArray arrayWithObject:Element(0xAE,video)];[tracks addObjectsFromArray:audio];return Element(0x18538067,Element(0x1654AE6B,Join(tracks)));}
int main(int argc,char **argv){@autoreleasepool{
    NSDictionary *fr=Track(0,@"fra",@"French main",2,YES),*en=Track(1,@"en-GB",@"English main",6,YES),*comment=Track(2,@"eng",@"Director commentary",2,YES);
    Check([Pick(@[fr,en,comment],nil)[@"track"][@"id"]intValue]==1,@"English main wins over French stereo and English commentary");
    Check([Pick(@[en,comment,fr],nil)[@"track"][@"id"]intValue]==1,@"Selection is independent of non-tied input ordering");
    Check([Pick(@[fr,en,comment],@{@"language":@"fr"})[@"track"][@"id"]intValue]==0,@"Explicit French preference is respected");
    Check([Pick(@[fr,en,comment],@{@"role":@"commentary"})[@"track"][@"id"]intValue]==2,@"Explicit commentary preference is respected");
    NSMutableDictionary *desc=[Track(3,@"eng",@"English",2,YES)mutableCopy];desc[@"description"]=@YES;
    Check([Pick(@[desc,en],nil)[@"track"][@"id"]intValue]==1,@"Accessibility flag does not displace main audio");
    Check([Pick(@[desc,en],@{@"role":@"description"})[@"track"][@"id"]intValue]==3,@"Description can be explicitly selected");
    NSMutableDictionary *disabled=[en mutableCopy];disabled[@"enabled"]=@NO;
    Check([Pick(@[disabled,fr],nil)[@"track"][@"id"]intValue]==0,@"Disabled English cannot enter playback");
    NSDictionary *unsupported=Track(1,@"eng",@"English",8,YES);
    Check([Pick(@[unsupported,fr],nil)[@"track"][@"id"]intValue]==0,@"Channel bound cannot be overridden by language");
    Check([Pick(@[Track(1,@"eng",@"English",2,NO),fr],nil)[@"message"]containsString:@"Using French"],@"Unsupported English yields an honest French fallback");
    Check(!Pick(@[unsupported],nil)[@"track"],@"All-unsupported result has no selection");
    NSDictionary *unknown=Track(8,@"und",@"Unknown",2,YES);
    Check([Pick(@[unknown],nil)[@"message"]containsString:@"Unknown language"],@"Unknown metadata is not advertised as English");
    NSDictionary *aliases=@{@"ENG":@"en",@"en_US":@"en",@"eng-GB":@"en",@"fre":@"fr",@"fra-CA":@"fr",@"ger":@"de",@"deu":@"de",@"mkd":@"mk",@"mac":@"mk",@"und":@"",@"mul":@"",@"English 5.1":@"",@"../en":@""};
    for(NSString *key in aliases)Check([[RWAudioPolicy language:key]isEqual:aliases[key]],[@"Language normalization: " stringByAppendingString:key]);
    Check([[RWAudioPolicy language:NSNull.null]isEqual:@""],@"Malformed language is unknown");
    NSArray *normalized=[RWAudioPolicy tracks:@[fr,en,comment,desc]];
    Check([[RWAudioPolicy tracks:normalized]isEqual:normalized],@"Normalization preserves flags, tokens and role");
    Check([RWAudioPolicy tracks:@[en,en]].count==0,@"Ambiguous duplicate track IDs rejected");
    Check([RWAudioPolicy tracks:@[NSNull.null,@{@"id":@0.5},@{@"id":@(-1)}]].count==0,@"Malformed and fractional IDs rejected");
    NSMutableArray *many=[NSMutableArray new];for(int i=0;i<129;i++)[many addObject:Track(i,@"eng",@"English",2,YES)];
    Check([RWAudioPolicy tracks:many].count==0,@"Track-list work bounded to 128");
    NSString *hash=@"0123456789abcdef0123456789abcdef01234567";
    NSString *key=[RWAudioPolicy mediaKey:@{@"infoHash":hash,@"fileIdx":@2}],*other=[RWAudioPolicy mediaKey:@{@"infoHash":hash,@"fileIdx":@3}];
    Check(key.length==64&&![key isEqual:other],@"File index is part of exact torrent identity");
    Check([[RWAudioPolicy mediaKey:@{@"infoHash":hash,@"fileIdx":@0,@"resolvedFileIdx":@2}]isEqual:key],@"Resolved index supersedes provider hint");
    Check(![RWAudioPolicy mediaKey:@{@"infoHash":hash,@"fileIdx":@0.5}].length,@"Fractional media index rejected");
    Check(![RWAudioPolicy mediaKey:@{@"infoHash":hash,@"url":@"magnet:opaque"}].length,@"Unresolved torrent cannot persist a raw track choice");
    NSString *urlKey=[RWAudioPolicy mediaKey:@{@"url":@"https://media.invalid/film.mp4?token=private"}];
    Check(urlKey.length==64&&![urlKey containsString:@"private"],@"Raw media credentials are not persisted");
    NSDictionary *saved=[RWAudioPolicy selectionsBySaving:normalized[0] mediaKey:key videoID:@"show:1:1" existing:nil now:100];
    NSDictionary *profile=@{@"audioSelections":saved},*pref=[RWAudioPolicy preferenceInProfile:profile videoID:@"show:1:1" mediaKey:key];
    Check([pref[@"token"]isEqual:normalized[0][@"token"]],@"Exact media restores explicit track token");
    Check([[RWAudioPolicy selection:normalized preference:pref][@"track"][@"id"]intValue]==0,@"Saved foreign track overrides automatic English");
    NSDictionary *newRelease=[RWAudioPolicy preferenceInProfile:profile videoID:@"show:1:1" mediaKey:other];
    Check(!newRelease[@"token"]&&[newRelease[@"language"]isEqual:@"fr"],@"New release keeps language intent, never old track ID");
    Check(![RWAudioPolicy preferenceInProfile:profile videoID:@"show:1:2" mediaKey:key][@"token"],@"Episode preference does not leak to another episode");
    Check([[RWAudioPolicy preferenceInProfile:@{} videoID:@"show:1:1" mediaKey:key][@"language"]isEqual:@"en"],@"Different profile keeps English default");
    NSDictionary *roundtrip=[NSJSONSerialization JSONObjectWithData:[NSJSONSerialization dataWithJSONObject:profile options:0 error:nil] options:0 error:nil];
    Check([[RWAudioPolicy preferenceInProfile:roundtrip videoID:@"show:1:1" mediaKey:key]isEqual:pref],@"Choice survives actual JSON persistence boundary");
    for(int i=0;i<90;i++)saved=[RWAudioPolicy selectionsBySaving:normalized[0] mediaKey:key videoID:[NSString stringWithFormat:@"title%d",i] existing:saved now:101+i];
    Check(saved.count==64&&saved[@"title89"]&&!saved[@"title0"],@"Oldest choices evicted at 64-title bound");
    NSMutableDictionary *poison=[saved[@"title89"]mutableCopy];poison[@"extra"]=@[@"unbounded payload"];
    saved=[RWAudioPolicy selectionsBySaving:normalized[1] mediaKey:key videoID:@"new" existing:@{@"old":poison,@"broken":NSNull.null} now:999];
    Check(!saved[@"old"][@"extra"]&&!saved[@"broken"],@"Untrusted persisted entries sanitized");
    Check(![RWAudioPolicy selectionsBySaving:normalized[0] mediaKey:@"bad" videoID:@"x" existing:nil now:1],@"Invalid identity cannot write preference");
    NSData *original=argc>1?[NSData dataWithContentsOfFile:@(argv[1])]:nil;
    NSData *video=Find(Find(Find(original,0x18538067),0x1654AE6B),0xAE);
    Check(video.length>0,@"Fixture uses real H264 SPS header");
    NSData *french=Audio(@"fre",nil,@"French main",NO,NO,YES,@"A_AAC",2),*english=Audio(@"eng",nil,@"English main",NO,NO,YES,@"A_AAC",6);
    NSData *dual=Header(video,@[french,english]);NSDictionary *probe=[RWMKVProbe media:dual];
    Check([probe[@"audioTrackIndex"]intValue]==1&&[probe[@"audioChannels"]intValue]==6,@"Production MKV probe chooses English second with 5.1");
    Check([probe[@"audioSampleRate"]intValue]==44100,@"Chosen track retains its own sample rate");
    Check([[RWMKVProbe media:dual audioPreference:@{@"language":@"fr"}][@"audioTrackIndex"]intValue]==0,@"MKV respects explicit French language");
    Check([[RWMKVProbe media:Header(video,@[Audio(@"eng",@"fr-CA",@"Main",NO,NO,YES,@"A_AAC",2),english])][@"audioTrackIndex"]intValue]==1,@"BCP47 overrides contradictory ISO tag");
    Check([[RWMKVProbe media:Header(video,@[Audio(@"eng",nil,@"Main",YES,NO,YES,@"A_AAC",2),english])][@"audioTrackIndex"]intValue]==1,@"Explicit commentary flag overrides innocent track name");
    Check([[RWMKVProbe media:Header(video,@[Audio(@"eng",nil,@"Main",NO,YES,YES,@"A_AAC",2),english])][@"audioTrackIndex"]intValue]==1,@"Explicit description flag overrides innocent track name");
    Check([[RWMKVProbe media:Header(video,@[Audio(@"eng",nil,@"Main",NO,NO,NO,@"A_AAC",2),french])][@"audioTrackIndex"]intValue]==1,@"Disabled English excluded by actual MKV parser");
    Check([[RWMKVProbe media:Header(video,@[Audio(@"eng",nil,@"Main",NO,NO,YES,@"A_DTS",2),french])][@"audioTrackIndex"]intValue]==1,@"Unsupported DTS remains excluded");
    NSDictionary *noTag=[RWMKVProbe media:Header(video,@[Audio(nil,nil,@"",NO,NO,YES,@"A_AAC",2)])];
    Check([noTag[@"audioSelection"][@"track"][@"language"]isEqual:@""],@"Missing MKV language stays unknown despite schema default");
    NSData *invalidBCP=Header(video,@[Audio(@"eng",@"not a tag",@"",NO,NO,YES,@"A_AAC",2)]);
    Check([[RWMKVProbe media:invalidBCP][@"audioSelection"][@"track"][@"language"]isEqual:@""],@"Invalid overriding BCP47 cannot fall back to misleading English");
    NSString *path=argc>2?@(argv[2]):nil;if(path)[dual writeToFile:path atomically:YES];
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
