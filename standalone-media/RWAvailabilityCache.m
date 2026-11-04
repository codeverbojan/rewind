#import "RWAvailabilityCache.h"
#import "RWAtomicWriter.h"

static BOOL HasUnusedFields(id meta) {
    return [meta isKindOfClass:NSDictionary.class]&&(meta[@"videos"]||meta[@"links"]||meta[@"popularities"]||meta[@"trailerStreams"]);
}

@implementation RWAvailabilityCache
+ (NSDictionary *)metadata:(NSDictionary *)metadata {
    if(![metadata isKindOfClass:NSDictionary.class])return nil;
    // videos was already omitted from availability records. Episode selection
    // uses the owned show cache. Trailer playback consumes trailers/preview,
    // not trailerStreams. Provider links/popularities have no runtime reader.
    NSMutableDictionary *result=nil;
    for(NSString *key in @[@"videos",@"links",@"popularities",@"trailerStreams"]){
        if(!metadata[key])continue;
        if(!result)result=[metadata mutableCopy];
        [result removeObjectForKey:key];
    }
    NSDictionary *projected=result?[result copy]:[metadata copy];
    // Invalid values remain unsealed so the writer rejects the save, rather
    // than silently dropping unfamiliar metadata or corrupting a good file.
    return [RWAtomicWriter immutableJSON:projected]?:projected;
}
+ (NSUInteger)prepareSnapshots:(NSMutableDictionary *)state {
    NSDictionary *profiles=state[@"profiles"];if(![profiles isKindOfClass:NSDictionary.class])return 0;
    NSMutableDictionary *updatedProfiles=nil;NSUInteger prepared=0;
    for(NSString *profileID in profiles){
        NSDictionary *profile=profiles[profileID];if(![profile isKindOfClass:NSDictionary.class])continue;
        NSDictionary *entries=profile[@"sourceAvailability"];if(![entries isKindOfClass:NSDictionary.class])continue;
        NSMutableDictionary *updatedEntries=nil;
        for(NSString *videoID in entries){
            NSDictionary *entry=entries[videoID];if(![entry isKindOfClass:NSDictionary.class])continue;
            NSDictionary *meta=entry[@"meta"];if(![meta isKindOfClass:NSDictionary.class]||[RWAtomicWriter isOwnedJSON:meta])continue;
            NSDictionary *owned=[RWAtomicWriter immutableJSON:meta];if(!owned)continue;
            if(!updatedEntries)updatedEntries=[entries mutableCopy];
            NSMutableDictionary *updatedEntry=[entry mutableCopy];updatedEntry[@"meta"]=owned;
            updatedEntries[videoID]=[updatedEntry copy];prepared++;
        }
        if(!updatedEntries)continue;if(!updatedProfiles)updatedProfiles=[profiles mutableCopy];
        NSMutableDictionary *updatedProfile=[profile mutableCopy];updatedProfile[@"sourceAvailability"]=updatedEntries;updatedProfiles[profileID]=updatedProfile;
    }
    if(updatedProfiles)state[@"profiles"]=updatedProfiles;return prepared;
}
+ (NSUInteger)compactState:(NSMutableDictionary *)state {
    NSDictionary *profiles=state[@"profiles"];if(![profiles isKindOfClass:NSDictionary.class])return 0;
    NSMutableDictionary *updatedProfiles=nil;NSUInteger compacted=0;
    for(NSString *profileID in profiles){
        NSDictionary *profile=profiles[profileID];if(![profile isKindOfClass:NSDictionary.class])continue;
        NSDictionary *entries=profile[@"sourceAvailability"];if(![entries isKindOfClass:NSDictionary.class])continue;
        NSMutableDictionary *updatedEntries=nil;
        for(NSString *videoID in entries){
            NSDictionary *entry=entries[videoID];if(![entry isKindOfClass:NSDictionary.class])continue;
            if(!HasUnusedFields(entry[@"meta"]))continue;
            NSDictionary *meta=[self metadata:entry[@"meta"]];
            if(!updatedEntries)updatedEntries=[entries mutableCopy];
            NSMutableDictionary *updatedEntry=[entry mutableCopy];updatedEntry[@"meta"]=meta;
            updatedEntries[videoID]=[updatedEntry copy];compacted++;
        }
        if(!updatedEntries)continue;
        if(!updatedProfiles)updatedProfiles=[profiles mutableCopy];
        NSMutableDictionary *updatedProfile=[profile mutableCopy];updatedProfile[@"sourceAvailability"]=updatedEntries;
        updatedProfiles[profileID]=updatedProfile;
    }
    if(updatedProfiles)state[@"profiles"]=updatedProfiles;
    return compacted;
}
@end
