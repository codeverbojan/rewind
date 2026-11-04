#import <Foundation/Foundation.h>
#import "../RWSourcePolicy.h"
#import "../RWAvailability.h"
static int checks,failures;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
int main(int argc,char **argv){@autoreleasepool{
    NSMutableArray *sets=[NSMutableArray new];
    for(int arg=1;arg<argc;arg++){
        NSData *data=[NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[arg]]];NSDictionary *json=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];NSMutableArray *sources=[NSMutableArray new];
        for(id raw in json[@"streams"]){NSDictionary *s=[RWSourcePolicy normalize:raw provider:@"Torrentio"];if(s)[sources addObject:s];}CHECK(sources.count>0);[sets addObject:sources];
    }
    NSMutableArray *synthetic=[NSMutableArray new];NSUInteger index=0;
    for(NSString *file in @[@"Film.720p.WEBRip.x264.AAC.mp4",@"Film.1080p.BluRay.x264.AAC.mp4",@"Film.480p.WEBRip.x264.AAC.mp4",@"Film.720p.WEBRip.x264.AC3.5.1.mkv",@"Film.720p.WEBRip.x264.AAC5.1.mp4",@"Film.720p.CAM.x264.AAC.mp4",@"Film.1080p.WEBRip.HEVC.AAC.mp4",@"Film.2160p.WEBRip.x264.AAC.mp4"]){[synthetic addObject:@{@"url":[NSString stringWithFormat:@"https://example.invalid/%lu",(unsigned long)index++],@"filename":file,@"seeders":@10}];}
    NSMutableDictionary *duplicate=[synthetic[0]mutableCopy];duplicate[@"metadataURL"]=@"https://example.invalid/metadata";duplicate[@"seeders"]=@100;[synthetic addObject:duplicate];[synthetic addObject:NSNull.null];[sets addObject:synthetic];[sets addObject:@[]];
    for(int legacy=0;legacy<2;legacy++)for(int surround=0;surround<2;surround++){
        [RWSourcePolicy setLegacyEnabled:legacy];[RWSourcePolicy setNativeSurroundEnabled:surround];NSDictionary *caps=[RWSourcePolicy capabilities];
        for(NSNumber *quality in @[@0,@480,@720,@1080])for(NSArray *sources in sets){
            NSDictionary *analysis=[RWSourcePolicy analysis:sources quality:quality.integerValue capabilities:caps];
            CHECK([analysis[@"eligible"]isEqual:[RWSourcePolicy rank:sources quality:quality.integerValue freeBytes:0]]);
            CHECK([analysis[@"qualities"]isEqual:[RWSourcePolicy qualities:sources]]);
            NSMutableDictionary *rejections=[NSMutableDictionary new];
            for(id source in sources){NSDictionary *entry=[RWSourcePolicy evaluate:source quality:quality.integerValue freeBytes:0];NSString *reason=entry[@"rejection"];if(reason.length)rejections[reason]=@([rejections[reason]intValue]+1);}
            CHECK([analysis[@"rejections"]isEqual:rejections]);
            for(int complete=0;complete<2;complete++)for(NSString *error in @[@"",@"Offline"]){
                CHECK([[RWAvailability observe:sources complete:complete error:error quality:quality.integerValue now:100]isEqual:[RWAvailability observeAnalysis:analysis complete:complete error:error quality:quality.integerValue now:100]]);
            }
        }
    }
    [RWSourcePolicy setLegacyEnabled:NO];[RWSourcePolicy setNativeSurroundEnabled:NO];NSDictionary *before=[RWSourcePolicy capabilities];NSDictionary *expected=[RWSourcePolicy analysis:synthetic quality:0 capabilities:before];
    [RWSourcePolicy setLegacyEnabled:YES];[RWSourcePolicy setNativeSurroundEnabled:YES];CHECK([[RWSourcePolicy analysis:synthetic quality:0 capabilities:before]isEqual:expected]);
    [RWSourcePolicy setLegacyEnabled:NO];[RWSourcePolicy setNativeSurroundEnabled:NO];CHECK(![before isEqual:[RWSourcePolicy capabilities]]);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
