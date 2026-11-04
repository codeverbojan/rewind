#import "RWLocalCatalog.h"
#import "RWDiscoveryEpisodes.h"
#import "RWEpisodeCatalog.h"
@implementation RWLocalCatalog
+ (void)loadDocuments:(NSString *)documents resources:(NSString *)resources done:(void(^)(NSDictionary *))done {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0),^{@autoreleasepool{
        double began=NSProcessInfo.processInfo.systemUptime;NSUInteger bytes=0;
        NSDictionary *files=@{@"episodeCatalog":@[@"rewind-episode-catalog.json",@""],@"upcoming":@[@"rewind-upcoming.json",@""],@"shows":@[@"rewind-series.json",@""],@"family":@[@"",@"family-catalog.json"],@"artwork":@[@"",@"artwork-map.json"],@"publishers":@[@"",@"publisher-sources.json"],@"catalog":@[@"rewind-catalog.json",@"catalog.json"],@"fresh":@[@"rewind-current-catalog.json",@"current-catalog.json"],@"curated":@[@"",@"curated.json"],@"open":@[@"",@"open-films.json"],@"candidates":@[@"discovery-candidates.json",@"discovery-catalog.json"],@"home":@[@"discovery-home.json",@""],@"metadata":@[@"discovery-metadata.json",@""],@"metadataSeed":@[@"",@"discovery-metadata.json"]};
        NSMutableDictionary *result=[NSMutableDictionary new];
        for(NSString *key in files){NSArray *names=files[key];NSDictionary *value=nil;
            for(NSUInteger i=0;i<2&&!value;i++){if(![names[i]length])continue;NSString *path=[(i?resources:documents)stringByAppendingPathComponent:names[i]];
                unsigned long long size=[[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil][NSFileSize]unsignedLongLongValue];if(size>8ULL*1024*1024)continue;
                NSData *data=[NSData dataWithContentsOfFile:path];if(data.length>8*1024*1024)continue;bytes+=data.length;
                id parsed=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;if([parsed isKindOfClass:NSDictionary.class])value=parsed;
            }
            if([key isEqual:@"shows"]){NSMutableDictionary *owned=[NSMutableDictionary new];for(NSString *identifier in value){NSDictionary *show=[RWDiscoveryEpisodes immutableShow:value[identifier]];owned[identifier]=show?:value[identifier];}value=[owned copy];}
            result[key]=[key isEqual:@"episodeCatalog"]?[[RWEpisodeCatalog alloc]initWithSnapshot:value now:NSDate.date.timeIntervalSince1970]:(value?:@{});
        }
        result[@"metrics"]=@{@"read_parse_seconds":@(NSProcessInfo.processInfo.systemUptime-began),@"bytes":@(bytes),@"off_main":@(!NSThread.isMainThread)};
        dispatch_async(dispatch_get_main_queue(),^{done(result);});
    }});
}
@end
