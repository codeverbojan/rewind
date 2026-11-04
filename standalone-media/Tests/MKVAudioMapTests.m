#import <Foundation/Foundation.h>
#import "../RWMKVAudioMap.h"
#import "../RWAudioPolicy.h"
static int checks,failures;
static void Check(BOOL ok,NSString *message){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",message.UTF8String);}}
static NSDictionary *Header(int ordinal,int number,NSString *language,NSString *role){NSMutableDictionary *t=[[RWAudioPolicy tracks:@[@{@"id":@(ordinal),@"language":language,@"name":@"",@"codec":@"A_AAC",@"channels":@2,@"compatible":@YES,@"role":role}]].firstObject mutableCopy];[t addEntriesFromDictionary:@{@"containerNumber":@(number),@"sampleRate":@48000,@"inputSampleRate":@48000,@"legacyLanguage":language,@"languageDeclared":@YES}];return t;}
static NSDictionary *Runtime(int id,NSString *language){return @{@"id":@(id),@"language":language,@"name":@"",@"codec":@"mp4a",@"channels":@2,@"sampleRate":@48000};}
int main(){@autoreleasepool{
    NSDictionary *en=Header(0,8,@"en",@"main"),*fr=Header(1,3,@"fr",@"main");NSArray *mapped=[RWMKVAudioMap mapHeader:@[en,fr] runtime:@[Runtime(41,@"fr"),Runtime(72,@"eng")]];
    Check(mapped.count==2,@"Noncontiguous runtime IDs map without assuming ordinal identity");
    NSDictionary *chosen=[RWAudioPolicy selection:mapped preference:nil][@"track"];
    Check([chosen[@"runtime_id"]intValue]==72&&[chosen[@"id"]intValue]==0,@"Unsorted container header resolves English to actual runtime ID72");
    Check([chosen[@"token"]isEqual:en[@"token"]],@"Runtime IDs do not alter persistent exact-track token");
    NSArray *reversed=[RWMKVAudioMap mapHeader:@[en,fr] runtime:@[Runtime(41,@"eng"),Runtime(72,@"fr")]];
    Check([reversed[0][@"runtime_id"]intValue]==41&&[reversed[0][@"mapping"]isEqual:@"unique_metadata"],@"Order disagreement falls back only to unique metadata");
    NSDictionary *comment=Header(2,9,@"en",@"commentary");
    mapped=[RWMKVAudioMap mapHeader:@[comment,en] runtime:@[Runtime(10,@"en"),Runtime(12,@"en")]];
    Check(mapped.count==2&&[[RWAudioPolicy selection:mapped preference:nil][@"track"][@"runtime_id"]intValue]==10,@"Equal language/codec tracks retain explicit commentary flag through complete ordered mapping");
    mapped=[RWMKVAudioMap mapHeader:@[comment,en,fr] runtime:@[Runtime(10,@"en")]];
    Check(!mapped.count,@"Partial ambiguous list cannot invent track role");
    mapped=[RWMKVAudioMap mapHeader:@[comment,en,fr] runtime:@[Runtime(10,@"fr")]];
    Check(mapped.count==1&&[mapped[0][@"id"]intValue]==1,@"Unique surviving track can map after another demux track is omitted");
    NSMutableDictionary *bad=[Runtime(10,@"en")mutableCopy];bad[@"channels"]=@8;
    Check(![RWMKVAudioMap mapHeader:@[en] runtime:@[bad]].count,@"Runtime/header channel mismatch rejected");
    bad[@"channels"]=@2;bad[@"codec"]=@"dts ";Check(![RWMKVAudioMap mapHeader:@[en] runtime:@[bad]].count,@"DTS does not borrow AAC compatibility");
    bad[@"codec"]=@"mp4a";bad[@"sampleRate"]=@96000;Check(![RWMKVAudioMap mapHeader:@[en] runtime:@[bad]].count,@"Runtime sample-rate bound retained");
    bad[@"sampleRate"]=@48000;bad[@"name"]=@"Unexpected name";Check(![RWMKVAudioMap mapHeader:@[en] runtime:@[bad]].count,@"Contradictory track name rejected");
    NSMutableDictionary *bcp=[fr mutableCopy];bcp[@"legacyLanguage"]=@"en";
    mapped=[RWMKVAudioMap mapHeader:@[bcp] runtime:@[Runtime(10,@"eng")]];
    Check(mapped.count==1&&[mapped[0][@"language"]isEqual:@"fr"],@"New BCP47 header overrides old demux language without losing binding");
    NSMutableDictionary *unknown=[Header(0,2,@"",@"main")mutableCopy];unknown[@"languageDeclared"]=@NO;
    mapped=[RWMKVAudioMap mapHeader:@[unknown] runtime:@[Runtime(10,@"eng")]];
    Check(mapped.count==1&&[mapped[0][@"language"]isEqual:@""],@"Demux schema-default English cannot turn missing tag into known language");
    NSMutableDictionary *disabled=[en mutableCopy];disabled[@"compatible"]=@NO;
    Check(![RWMKVAudioMap mapHeader:@[disabled] runtime:@[Runtime(10,@"eng")]].count,@"Unplayable/disabled header remains excluded");
    Check(![RWMKVAudioMap mapHeader:@[en,fr] runtime:@[Runtime(10,@"eng"),Runtime(10,@"fr")]].count,@"Duplicate runtime ID rejected");
    NSMutableArray *large=[NSMutableArray new];for(int i=0;i<129;i++)[large addObject:Runtime(i,@"eng")];Check(![RWMKVAudioMap mapHeader:@[en] runtime:large].count,@"Runtime mapping bounded to128");
    Check(![RWMKVAudioMap mapHeader:@[NSNull.null] runtime:@[Runtime(10,@"eng")]].count,@"Malformed header rejected safely");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
