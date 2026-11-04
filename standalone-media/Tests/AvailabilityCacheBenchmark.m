// Explicit local fixture benchmark, not device acceptance. Never prints state.
#import "../RWAvailabilityCache.h"
#import "../RWAtomicWriter.h"
static void AliasLegacy(NSMutableDictionary *state){NSDictionary *main=state[@"profiles"][@"main"];for(NSString *key in @[@"history",@"saved",@"sources",@"intros",@"quality",@"subtitleLanguage",@"subtitlesEnabled",@"subtitleSize",@"subtitleDelay"])if(main[key])state[key]=main[key];}
static BOOL Flush(RWAtomicWriter *writer){__block BOOL done=NO;[writer whenIdle:^{done=YES;}];NSDate *end=[NSDate dateWithTimeIntervalSinceNow:5];while(!done&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.001]];return done;}
static NSUInteger Containers(id value,NSHashTable *seen){if(![value isKindOfClass:NSDictionary.class]&&![value isKindOfClass:NSArray.class])return 0;if([seen containsObject:value])return 0;[seen addObject:value];NSUInteger n=1;for(id child in [value isKindOfClass:NSDictionary.class]?[value allValues]:value)n+=Containers(child,seen);return n;}
static NSUInteger Count(id value){return Containers(value,[NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory|NSPointerFunctionsObjectPointerPersonality]);}
static NSDictionary *Stats(NSArray *samples){NSArray *ordered=[samples sortedArrayUsingSelector:@selector(compare:)];return @{@"samples":@(ordered.count),@"median_seconds":ordered[ordered.count/2],@"max_seconds":ordered.lastObject};}
static id Roundtrip(id value){return [NSJSONSerialization JSONObjectWithData:[NSJSONSerialization dataWithJSONObject:value options:0 error:nil] options:0 error:nil];}

int main(int argc,const char **argv){@autoreleasepool{
    if(argc!=2)return 2;NSData *data=[NSData dataWithContentsOfFile:@(argv[1])];if(!data||data.length>16*1024*1024)return 2;
    NSMutableDictionary *before=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil],*after=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];if(![before isKindOfClass:NSDictionary.class])return 2;
    AliasLegacy(before);AliasLegacy(after);double began=NSProcessInfo.processInfo.systemUptime;NSUInteger changed=[RWAvailabilityCache compactState:after];double compactSeconds=NSProcessInfo.processInfo.systemUptime-began;
    // Equality of every user field and observation field except the explicitly
    // unused provider keys. Unknown keys and future feature payloads survive.
    NSMutableDictionary *expected=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];AliasLegacy(expected);
    for(NSMutableDictionary *profile in [expected[@"profiles"]allValues])for(NSMutableDictionary *entry in [profile[@"sourceAvailability"]allValues])if([entry[@"meta"]isKindOfClass:NSMutableDictionary.class])[entry[@"meta"]removeObjectsForKeys:@[@"videos",@"links",@"popularities",@"trailerStreams"]];
    if(![expected isEqual:after])return 3;
    NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString],*path=[folder stringByAppendingPathComponent:@"state.json"];RWAtomicWriter *writer=[RWAtomicWriter new];NSMutableArray *oldTimes=[NSMutableArray new],*newTimes=[NSMutableArray new];int result=0;
    @try{
        for(NSUInteger pair=0;pair<12;pair++)for(NSUInteger index=0;index<2;index++){@autoreleasepool{
            // Alternate ordering to avoid always warming the compacted sample.
            BOOL compact=((pair+index)%2)==1;double start=NSProcessInfo.processInfo.systemUptime;BOOL ok=[writer writeJSON:compact?after:before path:path];double seconds=NSProcessInfo.processInfo.systemUptime-start;
            if(!ok||!Flush(writer)){result=4;break;}if(pair>=2)[compact?newTimes:oldTimes addObject:@(seconds)];
        }}
        NSDictionary *disk=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] options:0 error:nil];BOOL persisted=[disk isEqual:Roundtrip(before)]||[disk isEqual:Roundtrip(after)];if(!persisted)result=5;
        if(!result){NSDictionary *report=@{@"scope":@"Mac host only; same captured state, existing writer and legacy aliases; no iPad writes",@"input_bytes":@(data.length),@"observations_compacted":@(changed),@"migration_seconds":@(compactSeconds),@"before_json_bytes":@([NSJSONSerialization dataWithJSONObject:before options:0 error:nil].length),@"after_json_bytes":@([NSJSONSerialization dataWithJSONObject:after options:0 error:nil].length),@"before_unique_containers":@(Count(before)),@"after_unique_containers":@(Count(after)),@"before_capture":Stats(oldTimes),@"after_capture":Stats(newTimes),@"only_unused_cache_fields_changed":@YES,@"disk_roundtrip_valid":@(persisted),@"roundtrip_reference":@"Foundation direct JSON encode/decode; handles its tiny decimal representation changes",@"writer":writer.diagnostics};NSData *out=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];fwrite(out.bytes,1,out.length,stdout);printf("\n");}
    }@finally{Flush(writer);[[NSFileManager defaultManager]removeItemAtPath:folder error:nil];}
    return result;
}}
