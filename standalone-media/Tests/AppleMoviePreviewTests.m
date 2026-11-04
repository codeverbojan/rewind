#import "../RWApplePreviewPolicy.h"
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
static NSData *D(NSString *folder,NSString *name){return [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:name]];}
int main(int argc,const char **argv){@autoreleasepool{
 NSString *folder=@(argv[1]),*identifier=@"umc.cmc.zgc43vpna42wfgfi645em0sm";
 NSDictionary *meta=@{@"id":@"tt27165187",@"type":@"movie",@"name":@"The End of Oak Street",@"releaseInfo":@"2026"};
 NSData *html=D(folder,@"oak.html");NSString *text=[[NSString alloc]initWithData:html encoding:NSUTF8StringEncoding];
 NSDictionary *preview=[RWApplePreviewPolicy preview:html showID:identifier meta:meta];
 CHECK(preview);CHECK([preview[@"previewID"]isEqual:@"umc.cmc.5lxwhasafmiqqodksk3w0nnbt"]);CHECK([preview[@"duration"]integerValue]==140);CHECK([preview[@"movieID"]isEqual:identifier]);CHECK(!preview[@"showID"]);
 for(NSDictionary *changes in @[@{@"name":@"Another Movie"},@{@"releaseInfo":@"2025"},@{@"releaseInfo":@""},@{@"type":@"series"}]){NSMutableDictionary *m=[meta mutableCopy];[m addEntriesFromDictionary:changes];CHECK(![RWApplePreviewPolicy preview:html showID:identifier meta:m]);}
 CHECK(![RWApplePreviewPolicy preview:html showID:@"umc.cmc.1vrwat5k1ucm5k42q97ioqyq3" meta:meta]);
 for(NSArray *edit in @[@[@"targetType=Movie",@"targetType=Show"],@[@"uts.col.Trailers.",@"uts.col.Related."],@[@"\"requiresPlaybackId\":false",@"\"requiresPlaybackId\":true"],@[@"canonical-header-",@"related-header-"],@[@"\"duration\":140",@"\"duration\":900"],@[@"/us/movie/",@"/gb/movie/"]]){
  NSString *altered=[text stringByReplacingOccurrencesOfString:edit[0] withString:edit[1]];
  NSDictionary *r=[RWApplePreviewPolicy preview:[altered dataUsingEncoding:NSUTF8StringEncoding] showID:identifier meta:meta];
  if([edit[0]isEqual:@"\"duration\":140"]){CHECK(![r[@"previewID"]isEqual:preview[@"previewID"]]);}else CHECK(!r);
 }
 NSString *master=[[NSString alloc]initWithData:D(folder,@"oak-master.m3u8") encoding:NSUTF8StringEncoding];
 NSDictionary *variant=preview?[RWApplePreviewPolicy variant:master base:[NSURL URLWithString:preview[@"url"]]]:nil;
 CHECK(variant);CHECK([variant[@"width"]integerValue]<=1280&&[variant[@"height"]integerValue]<=720);CHECK([variant[@"codecs"]containsString:@"avc1."]&&[variant[@"codecs"]containsString:@"mp4a.40.2"]);
 if(argc>2&&preview&&variant)[[NSJSONSerialization dataWithJSONObject:@{@"preview":preview,@"variant":variant} options:NSJSONWritingPrettyPrinted error:nil]writeToFile:@(argv[2]) atomically:YES];
 printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
