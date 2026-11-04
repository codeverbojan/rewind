#import <Foundation/Foundation.h>
#import "../RWAudioPolicy.h"
static int checks,failures;
static void check(BOOL ok,const char *why){checks++;if(!ok){failures++;fprintf(stderr,"FAIL:%s\n",why);}}
static NSDictionary *track(int i,NSString *language,NSString *name,BOOL def){return @{@"id":@(i),@"language":language,@"name":name,@"channels":@6,@"compatible":@YES,@"default":@(def),@"codec":@"AAC"};}
static NSDictionary *pick(NSArray *a,NSDictionary *p){return [RWAudioPolicy selection:[RWAudioPolicy tracks:a] preference:p];}
int main(){@autoreleasepool{
 NSDictionary *named=track(0,@"und",@"angielski [oryginalny]",NO),*polish=track(1,@"pol",@"Polski",YES),*tagged=track(2,@"eng",@"Main",NO);
 NSDictionary *selected=pick(@[named,polish],nil);NSArray *normalized=[RWAudioPolicy tracks:@[named,polish]];
 check([selected[@"track"][@"id"]intValue]==0,"Observed untagged English-name main beats default Polish");
 check([normalized[0][@"language"]isEqual:@""],"The actual missing language tag stays unknown");
 check([normalized[0][@"language_hint"]isEqual:@"en"]&&[normalized[0][@"language_evidence"]isEqual:@"track_name"],"Name inference has explicit provenance");
 check([normalized[0][@"label"]containsString:@"track name"],"Menu distinguishes name evidence from a language tag");
 check([selected[@"reason"]isEqual:@"preferred_language_name"]&&[selected[@"message"]length]>0,"Automatic fallback exposes inference honestly");
 check([pick(@[named,tagged],nil)[@"track"][@"id"]intValue]==2,"Tagged English wins over a name hint");
 check([pick(@[named,polish],@{@"language":@"pl"})[@"track"][@"id"]intValue]==1,"Explicit profile language is respected");
 for(NSString *name in @[@"English",@"English [Original] AAC 5.1",@" ANGIELSKI [oryginalny] "]){NSDictionary *r=pick(@[track(0,@"und",name,NO),polish],nil);check([r[@"track"][@"id"]intValue]==0,"Bounded explicit language-name forms are recognized");}
 for(NSString *name in @[@"Englishman",@"No English",@"English / French",@"English and French",@"English songs",@"Track 2 English",@"original",@"angielski film",@"English [unknown qualifiers]"]){
  NSDictionary *r=pick(@[track(0,@"und",name,NO),polish],nil);check([r[@"track"][@"id"]intValue]==1,"Ambiguous or unrelated title text is not an English language hint");
 }
 NSDictionary *contradiction=track(0,@"fra",@"English",NO);NSArray *a=[RWAudioPolicy tracks:@[contradiction,polish]];
 check([a[0][@"language"]isEqual:@"fr"]&&![a[0][@"language_hint"]length],"Real tag overrides contradictory track name");
 check([pick(@[contradiction,polish],nil)[@"track"][@"id"]intValue]==1,"Contradictory name does not gain English preference");
 NSMutableDictionary *comment=[named mutableCopy];comment[@"name"]=@"English commentary";
 check([pick(@[comment,polish],nil)[@"track"][@"id"]intValue]==1,"Name-only English commentary does not replace main dialogue");
 check([pick(@[comment,polish],@{@"role":@"commentary"})[@"track"][@"id"]intValue]==0,"Explicit commentary remains selectable");
 NSMutableDictionary *description=[named mutableCopy];description[@"description"]=@YES;
 check([pick(@[description,polish],nil)[@"track"][@"id"]intValue]==1,"Description role is not promoted over main");
 check([pick(@[description,polish],@{@"role":@"description"})[@"track"][@"id"]intValue]==0,"Explicit description can use a name hint");
 NSMutableDictionary *bad=[named mutableCopy];bad[@"channels"]=@8;
 check([pick(@[bad,polish],nil)[@"track"][@"id"]intValue]==1,"Language hint never overrides decoder/channel bounds");
 bad=[named mutableCopy];bad[@"compatible"]=@NO;check([pick(@[bad,polish],nil)[@"track"][@"id"]intValue]==1,"Unsupported codec cannot win by name");
 check([[RWAudioPolicy tracks:normalized]isEqual:normalized],"Repeated normalization keeps provenance and stable identity");
 NSMutableDictionary *spoof=[track(0,@"und",@"Unlabelled main",NO) mutableCopy];spoof[@"language_hint"]=@"en";spoof[@"language_evidence"]=@"tag";
 check(![[RWAudioPolicy tracks:@[spoof]][0][@"language_hint"]length],"Supplied inference fields cannot manufacture language evidence");
 check([pick(@[spoof,polish],nil)[@"track"][@"id"]intValue]==1,"Spoofed hint cannot outrank the real default");
 NSString *hash=[@"a" stringByPaddingToLength:40 withString:@"a" startingAtIndex:0],*key=[RWAudioPolicy mediaKey:@{@"infoHash":hash,@"fileIdx":@0}];
 NSDictionary *saved=[RWAudioPolicy selectionsBySaving:normalized[1] mediaKey:key videoID:@"episode" existing:nil now:100];
 NSDictionary *profile=@{@"audioSelections":saved},*pref=[RWAudioPolicy preferenceInProfile:profile videoID:@"episode" mediaKey:key];
 check([[RWAudioPolicy selection:normalized preference:pref][@"track"][@"id"]intValue]==1,"Exact saved Polish choice beats inferred English");
 saved=[RWAudioPolicy selectionsBySaving:normalized[0] mediaKey:key videoID:@"episode" existing:nil now:100];
 NSData *bytes=[NSJSONSerialization dataWithJSONObject:@{@"audioSelections":saved} options:0 error:nil];profile=[NSJSONSerialization JSONObjectWithData:bytes options:0 error:nil];
 pref=[RWAudioPolicy preferenceInProfile:profile videoID:@"episode" mediaKey:key];
 check([[RWAudioPolicy selection:normalized preference:pref][@"reason"]isEqual:@"saved_track"],"Exact manual name-only selection survives JSON restart");
 check([profile[@"audioSelections"][@"episode"][@"language"]isEqual:@""],"Inferred language is not persisted as an authoritative tag");
 check(![RWAudioPolicy preferenceInProfile:@{} videoID:@"episode" mediaKey:key][@"token"],"Saved token stays within its profile");
 NSDictionary *result=@{@"checks":@(checks),@"failures":@(failures),@"unknown_token":normalized[0][@"token"],@"observed_selection":selected};NSData *json=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];puts([[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding].UTF8String);return failures?1:0;
}}
