#import <Foundation/Foundation.h>
#import "../RWSubtitlePolicy.h"
static int checks,failures;
static void Check(BOOL ok,NSString *s){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",s.UTF8String);}}
static NSDictionary *Entry(NSString *name,NSString *match,BOOL sdh){return @{@"descriptor":[RWSubtitlePolicy descriptor:@{@"language":@"en",@"sdh":@(sdh),@"name":name}kind:@"torrent" locator:name],@"match":match};}
int main(){@autoreleasepool{
    NSDictionary *pref=@{@"enabled":@YES,@"language":@"en",@"forced":@NO,@"sdh":@NO};
    NSDictionary *exact=Entry(@"Exact release",@"release_filename",NO),*episode=Entry(@"Other cut of episode",@"episode",NO),*unknown=Entry(@"Generic",@"unknown",NO);
    Check([[RWSubtitlePolicy select:@[episode,exact]preference:pref]isEqual:exact],@"Exact release must beat earlier episode-only candidate");
    Check([[RWSubtitlePolicy select:@[exact,episode]preference:pref]isEqual:exact],@"Provider order cannot reverse release confidence");
    NSMutableDictionary *sdh=[pref mutableCopy];sdh[@"sdh"]=@YES;
    Check([[RWSubtitlePolicy select:@[Entry(@"Other cut SDH",@"episode",YES),exact]preference:sdh]isEqual:exact],@"Filename release evidence must not be displaced by weaker SDH match");
    Check(![RWSubtitlePolicy select:@[unknown]preference:pref],@"Unknown pack sidecar remains manual");
    NSMutableDictionary *manual=[pref mutableCopy];manual[@"token"]=episode[@"descriptor"][@"token"];
    Check([[RWSubtitlePolicy select:@[exact,episode]preference:manual]isEqual:episode],@"Explicit exact saved track still overrides automatic ranking");
    NSDictionary *source=@{@"resolvedFilename":@"Show.S01E01.Release.mkv"};
    for(NSString *name in @[@"Show.S01E01.Release.Directors.Cut.en.srt",@"Show.S01E01.Release.OtherGroup.en.srt"])
        Check([[RWSubtitlePolicy sidecarMatch:@{@"filename":name}videoID:@"tt1:1:1" source:source]isEqual:@"episode"],@"Arbitrary release suffix is not a matching subtitle-language suffix");
    Check([[RWSubtitlePolicy sidecarMatch:@{@"filename":@"Show.S01E01.Release.en.forced.srt"}videoID:@"tt1:1:1" source:source]isEqual:@"release_filename"],@"Exact stem plus recognized language/role is release evidence");
    Check([[RWSubtitlePolicy sidecarMatch:@{@"filename":@"Show.S01E02.Release.en.srt"}videoID:@"tt1:1:1" source:source]isEqual:@"conflict"],@"Wrong episode stays excluded");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
