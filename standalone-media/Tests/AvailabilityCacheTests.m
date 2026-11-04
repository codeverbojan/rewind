#import "../RWAvailabilityCache.h"
#import "../RWAtomicWriter.h"
#import "../RWAvailability.h"
#import "../RWTrailerPolicy.h"
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static id Clone(id value){return [NSJSONSerialization JSONObjectWithData:[NSJSONSerialization dataWithJSONObject:value options:0 error:nil] options:NSJSONReadingMutableContainers error:nil];}
static BOOL Flush(RWAtomicWriter *writer){__block BOOL done=NO;[writer whenIdle:^{done=YES;}];NSDate *end=[NSDate dateWithTimeIntervalSinceNow:5];while(!done&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];return done;}
int main(){@autoreleasepool{
    NSDictionary *metadata=@{@"id":@"tt1234567",@"type":@"movie",@"name":@"Cache fixture",@"releaseInfo":@"2020",@"description":@"Synopsis",@"poster":@"https://example.com/poster.jpg",@"background":@"https://example.com/hero.jpg",@"imdbRating":@8.2,@"imdbVotes":@43000,@"genres":@[@"Drama"],@"cast":@[@"Actor"],@"director":@[@"Director"],@"discovery":@{@"primaryLanguage":@"en",@"cast":@[@{@"id":@"Q1",@"image":@"headshot"}],@"studio":@[@{@"id":@"Q2"}]},@"trailers":@[@{@"type":@"Trailer",@"source":@"12345678901"}],@"preview":@"https://example.com/preview.mp4",@"episodeVideoID":@"tt1234567:1:2",@"futureMetadata":@{@"mustSurvive":@YES},@"videos":@[@{@"id":@"tt1234567:1:2"}],@"links":@[@{@"name":@"Provider navigation"}],@"popularities":@{@"provider":@123},@"trailerStreams":@[@{@"ytId":@"unused"}]};
    NSDictionary *before=Clone(metadata),*compact=[RWAvailabilityCache metadata:metadata];
    NSMutableDictionary *expected=[metadata mutableCopy];[expected removeObjectsForKeys:@[@"videos",@"links",@"popularities",@"trailerStreams"]];
    CHECK([compact isEqual:expected]);CHECK([metadata isEqual:before]);
    CHECK([[RWTrailerPolicy embeddedSource:metadata]isEqual:[RWTrailerPolicy embeddedSource:compact]]);
    CHECK([RWAvailabilityCache metadata:(id)NSNull.null]==nil);
    NSMutableDictionary *mutable=[compact mutableCopy];NSDictionary *owned=[RWAvailabilityCache metadata:mutable];mutable[@"name"]=@"Changed";CHECK([owned[@"name"]isEqual:@"Cache fixture"]);
    // Exercise aliasing across user data and both profiles. Migration must not
    // mutate shared metadata, observations or any user field through an alias.
    NSDictionary *observation=@{@"meta":metadata,@"state":@"candidates",@"quality":@0,@"policy":@34,@"checked":@2000000000,@"ready_at":@2000000000,@"ready_source":@"test",@"futureObservation":@[@1,@2]};
    NSDictionary *profile=@{@"name":@"Main",@"maxAge":@(-1),@"saved":@[metadata],@"history":@{@"tt1234567":@{@"meta":metadata,@"position":@333,@"duration":@900}},@"availabilityWatch":@{@"tt1234567":@{@"meta":metadata}},@"following":@{@"tt1234567":@{@"meta":metadata}},@"sourceAvailability":@{@"tt1234567":observation},@"discoveryPreferences":@{@"worldCinema":@YES}};
    NSMutableDictionary *kids=[profile mutableCopy];kids[@"name"]=@"Kids";kids[@"maxAge"]=@7;
    NSMutableDictionary *state=[@{@"activeProfile":@"main",@"profiles":@{@"main":profile,@"kids":kids},@"history":profile[@"history"],@"saved":profile[@"saved"]}mutableCopy];NSDictionary *original=Clone(state);
    CHECK([RWAvailabilityCache compactState:state]==2);
    for(NSString *pid in @[@"main",@"kids"]){
        NSMutableDictionary *oldUser=[original[@"profiles"][pid]mutableCopy],*newUser=[state[@"profiles"][pid]mutableCopy];[oldUser removeObjectForKey:@"sourceAvailability"];[newUser removeObjectForKey:@"sourceAvailability"];CHECK([oldUser isEqual:newUser]);
        NSDictionary *updated=state[@"profiles"][pid][@"sourceAvailability"][@"tt1234567"];CHECK([updated[@"meta"]isEqual:compact]);
        NSMutableDictionary *oldStatus=[observation mutableCopy],*newStatus=[updated mutableCopy];[oldStatus removeObjectForKey:@"meta"];[newStatus removeObjectForKey:@"meta"];CHECK([oldStatus isEqual:newStatus]);
        for(NSNumber *time in @[@1999999999,@2000000100,@2000010000])for(NSNumber *quality in @[@0,@720])CHECK([[RWAvailability presentation:metadata observation:observation quality:quality.integerValue now:time.doubleValue]isEqual:[RWAvailability presentation:updated[@"meta"] observation:updated quality:quality.integerValue now:time.doubleValue]]);
    }
    CHECK([metadata isEqual:before]&&[profile isEqual:original[@"profiles"][@"main"]]);
    CHECK([state[@"history"]isEqual:original[@"history"]]&&[state[@"saved"]isEqual:original[@"saved"]]);
    id profiles=state[@"profiles"];CHECK([RWAvailabilityCache compactState:state]==0&&state[@"profiles"]==profiles);
    // Cache entries remain replaceable; applying a later observation or changing
    // a profile does not mutate the old snapshot or cross the profile boundary.
    state[@"profiles"][@"main"][@"sourceAvailability"][@"tt1234567"]=@{@"state":@"waiting",@"meta":compact};
    CHECK([state[@"profiles"][@"kids"][@"sourceAvailability"][@"tt1234567"][@"state"]isEqual:@"candidates"]);
    CHECK([observation[@"state"]isEqual:@"candidates"]);
    NSMutableDictionary *malformed=[@{@"profiles":@{@"bad":@3,@"missing":@{},@"badEntries":@{@"sourceAvailability":NSNull.null},@"mixed":@{@"sourceAvailability":@{@"null":NSNull.null,@"scalar":@4,@"badMeta":@{@"meta":@7}}}}}mutableCopy];NSDictionary *badBefore=Clone(malformed);CHECK([RWAvailabilityCache compactState:malformed]==0&&[malformed isEqual:badBefore]);
    CHECK([RWAvailabilityCache compactState:[@{}mutableCopy]]==0);
    // Real writer and JSON reload: the migration survives persistence while
    // history and saved data remain intact. No in-memory-only assertion.
    NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString],*path=[folder stringByAppendingPathComponent:@"state.json"];RWAtomicWriter *writer=[RWAtomicWriter new];
    @try{
        CHECK([writer writeJSON:state path:path]);CHECK(Flush(writer));
        NSMutableDictionary *disk=Clone([NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] options:0 error:nil]);CHECK([disk isEqual:state]);CHECK([RWAvailabilityCache compactState:disk]==0);
        CHECK([disk[@"profiles"][@"main"][@"history"]isEqual:original[@"profiles"][@"main"][@"history"]]);
        CHECK([writer.diagnostics[@"failed"]integerValue]==0&&[writer.diagnostics[@"main_thread_encodes"]integerValue]==0);
    }@finally{Flush(writer);[[NSFileManager defaultManager]removeItemAtPath:folder error:nil];}
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
