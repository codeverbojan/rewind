#import <Foundation/Foundation.h>
#import "../RWSubtitlePolicy.h"
#import "../RWMKVProbe.h"
static int checks,failures;
static void Check(BOOL ok,NSString *s){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",s.UTF8String);}}
static NSDictionary *Header(int number,NSString *lang,BOOL forced){return @{@"containerNumber":@(number),@"uid":[@(number*100)stringValue],@"codec":@"S_TEXT/UTF8",@"language":lang,@"legacyLanguage":lang,@"languageDeclared":@YES,@"name":@"",@"forced":@(forced),@"sdh":@NO,@"enabled":@YES};}
static NSDictionary *Runtime(int number,NSString *lang){return @{@"id":@(number),@"language":lang,@"codec":@"subt",@"name":@""};}
int main(int argc,char **argv){@autoreleasepool{
    NSDictionary *en=Header(9,@"en",NO),*fr=Header(3,@"fr",NO),*forced=Header(10,@"en",YES);
    NSArray *mapped=[RWSubtitlePolicy mapMKV:@[en,fr]runtime:@[Runtime(41,@"fr"),Runtime(72,@"eng")]];
    Check(mapped.count==2&&[mapped[0][@"id"]intValue]==41&&[mapped[1][@"descriptor"][@"language"]isEqual:@"en"],@"Unsorted headers bind actual noncontiguous ES IDs");
    NSString *token=mapped[1][@"descriptor"][@"token"];
    mapped=[RWSubtitlePolicy mapMKV:@[en,fr]runtime:@[Runtime(80,@"en"),Runtime(90,@"fr")]];
    Check(mapped.count==2&&[mapped[0][@"mapping"]isEqual:@"unique_metadata"]&&[mapped[0][@"id"]intValue]==80,@"Metadata-only fallback when runtime order differs");
    Check([mapped[0][@"descriptor"][@"token"]isEqual:token],@"Track identity survives different runtime IDs");
    mapped=[RWSubtitlePolicy mapMKV:@[forced,en]runtime:@[Runtime(80,@"en"),Runtime(90,@"en")]];
    Check(mapped.count==2&&![mapped[0][@"descriptor"][@"forced"]boolValue]&&[mapped[1][@"descriptor"][@"forced"]boolValue],@"Complete matching track order preserves forced flag");
    Check(![RWSubtitlePolicy mapMKV:@[forced,en]runtime:@[Runtime(80,@"en")]].count,@"Partial identical-language list cannot guess forced track");
    Check(![RWSubtitlePolicy mapMKV:@[en,fr]runtime:@[Runtime(80,@"en"),Runtime(80,@"fr")]].count,@"Duplicate runtime IDs rejected");
    Check(![RWSubtitlePolicy mapMKV:@[Header(0,@"en",NO)]runtime:@[Runtime(80,@"en")]].count,@"Missing container identity cannot persist exact offsets");
    NSMutableDictionary *unknown=[en mutableCopy];unknown[@"language"]=@"";unknown[@"languageDeclared"]=@NO;
    mapped=[RWSubtitlePolicy mapMKV:@[unknown]runtime:@[Runtime(80,@"en")]];Check(mapped.count==1&&![mapped[0][@"descriptor"][@"language"]length],@"VLC default English does not manufacture missing language metadata");
    NSMutableDictionary *bad=[Runtime(80,@"en")mutableCopy];bad[@"codec"]=@"bdpg";Check(![RWSubtitlePolicy mapMKV:@[en]runtime:@[bad]].count,@"PGS cannot inherit text track identity");
    bad=[en mutableCopy];bad[@"enabled"]=@NO;Check(![RWSubtitlePolicy mapMKV:@[bad]runtime:@[Runtime(80,@"en")]].count,@"Disabled container track excluded");
    bad=[en mutableCopy];bad[@"language"]=@"fr";mapped=[RWSubtitlePolicy mapMKV:@[bad]runtime:@[Runtime(80,@"en")]];Check([mapped.firstObject[@"descriptor"][@"language"]isEqual:@"fr"],@"BCP47 takes precedence while legacy declaration binds old VLC");
    if(argc>1){NSData *data=[NSData dataWithContentsOfFile:@(argv[1])];if(data.length>2*1024*1024)data=[data subdataWithRange:NSMakeRange(0,2*1024*1024)];NSArray *tracks=[RWMKVProbe media:data][@"subtitleTracks"];
        Check(tracks.count==2,@"Actual bundled MKV header exposes both subtitle tracks");
        NSMutableSet *languages=[NSMutableSet new],*identities=[NSMutableSet new];for(NSDictionary *track in tracks){[languages addObject:track[@"language"]];[identities addObject:track[@"containerNumber"]];Check([track[@"uid"]length]>0&&[track[@"enabled"]boolValue],@"Real track UID and enabled metadata present");}
        Check([languages containsObject:@"en"]&&[languages containsObject:@"fr"]&&identities.count==2,@"Actual English and French header identities distinct");
    }
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
