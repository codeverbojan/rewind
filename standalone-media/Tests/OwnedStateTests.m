#import "../RWAtomicWriter.h"
#import "../RWAvailabilityCache.h"
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static BOOL Flush(RWAtomicWriter *writer){__block BOOL done=NO;[writer whenIdle:^{done=YES;}];NSDate *end=[NSDate dateWithTimeIntervalSinceNow:5];while(!done&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.001]];return done;}
static id Read(NSString *path){return [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] options:0 error:nil];}
static id Nest(id value,NSUInteger depth){for(NSUInteger i=0;i<depth;i++)value=@[value];return value;}
int main(){@autoreleasepool{
    NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString],*path=[folder stringByAppendingPathComponent:@"state.json"];
    RWAtomicWriter *writer=[RWAtomicWriter new];
    @try{
        NSMutableString *name=[@"Original" mutableCopy],*key=[@"field" mutableCopy];NSMutableArray *cast=[NSMutableArray arrayWithObject:name];NSMutableDictionary *nested=[@{key:cast,@"null":NSNull.null}mutableCopy];
        NSDictionary *input=@{@"nested":nested,@"alias":nested},*owned=[RWAtomicWriter immutableJSON:input];
        CHECK(owned!=input&&[owned isEqual:input]);CHECK([RWAtomicWriter isOwnedJSON:owned]);CHECK(![RWAtomicWriter isOwnedJSON:input]);CHECK([RWAtomicWriter immutableJSON:owned]==owned);
        CHECK(owned[@"nested"]==owned[@"alias"]);CHECK(![RWAtomicWriter isOwnedJSON:[owned mutableCopy]]);
        [name setString:@"Changed"];[cast addObject:@"Second"];nested[@"null"]=@4;[key setString:@"renamed"];
        CHECK([owned[@"nested"][@"field"]isEqual:@[@"Original"]]);CHECK(owned[@"nested"][@"null"]==NSNull.null);
        NSMutableDictionary *history=[@{@"position":@123}mutableCopy],*state=[@{@"meta":owned,@"history":history}mutableCopy];
        CHECK([writer writeJSON:state path:path]);history[@"position"]=@456;state[@"meta"]=@{};CHECK(Flush(writer));
        CHECK([Read(path)[@"meta"]isEqual:owned]&&[Read(path)[@"history"][@"position"]intValue]==123);
        CHECK([writer writeJSON:state path:path]);history[@"position"]=@789;CHECK(Flush(writer));CHECK([Read(path)[@"history"][@"position"]intValue]==456);
        // A mutable copy of an owned root must go through normal capture.
        NSMutableDictionary *edited=[owned mutableCopy];edited[@"new"]=cast;CHECK([writer writeJSON:edited path:path]);[cast removeAllObjects];CHECK(Flush(writer));CHECK([Read(path)[@"new"]count]==2);
        CHECK(![RWAtomicWriter immutableJSON:@{@"bad":NSDate.date}]);CHECK(![RWAtomicWriter immutableJSON:@{@"bad":@(NAN)}]);CHECK(![RWAtomicWriter immutableJSON:@{@1:@"bad key"}]);
        NSMutableArray *cycle=[NSMutableArray new];id alias=cycle;[cycle addObject:alias];CHECK(![RWAtomicWriter immutableJSON:cycle]);[cycle removeAllObjects];
        // Preserve the128 edge-depth limit even when an owned subtree would
        // otherwise skip traversal. Also cover shared deep graphs and empties.
        id deep=[RWAtomicWriter immutableJSON:Nest(@1,120)];CHECK(deep!=nil);CHECK([writer writeJSON:Nest(deep,8) path:path]);CHECK(Flush(writer));CHECK(![writer writeJSON:Nest(deep,9) path:path]);
        CHECK(![RWAtomicWriter immutableJSON:Nest(deep,9)]);CHECK([RWAtomicWriter immutableJSON:@[]]!=nil);CHECK([RWAtomicWriter immutableJSON:@{}]!=nil);
        id shared=@1;for(int i=0;i<20;i++)shared=@[shared,shared];CHECK([RWAtomicWriter immutableJSON:shared]!=nil);
        NSMutableArray *genres=[NSMutableArray arrayWithObject:@"Drama"];NSDictionary *meta=@{@"id":@"fixture",@"genres":genres,@"futureField":@{@"keep":NSNull.null}};
        NSDictionary *entry=@{@"meta":meta,@"checked":@123};NSDictionary *profile=@{@"history":@{@"title":@{@"meta":meta,@"position":@99}},@"saved":@[meta],@"sourceAvailability":@{@"title":entry}};
        NSMutableDictionary *store=[@{@"profiles":@{@"main":profile,@"kids":profile}}mutableCopy];
        CHECK([RWAvailabilityCache prepareSnapshots:store]==2);CHECK([store[@"profiles"][@"main"]isEqual:profile]);CHECK([store[@"profiles"][@"main"][@"history"]isEqual:profile[@"history"]]);
        id profiles=store[@"profiles"];CHECK([RWAvailabilityCache prepareSnapshots:store]==0&&profiles==store[@"profiles"]);
        NSDictionary *cached=store[@"profiles"][@"main"][@"sourceAvailability"][@"title"][@"meta"];CHECK([RWAtomicWriter isOwnedJSON:cached]);
        [genres addObject:@"Comedy"];CHECK([cached[@"genres"]count]==1);CHECK([store[@"profiles"][@"main"][@"saved"][0][@"genres"]count]==2);
        CHECK([writer writeJSON:store path:path]);CHECK(Flush(writer));CHECK([Read(path)[@"profiles"][@"main"][@"sourceAvailability"][@"title"][@"meta"]isEqual:cached]);
        NSDictionary *fresh=[RWAvailabilityCache metadata:meta];CHECK([RWAtomicWriter isOwnedJSON:fresh]&&[fresh[@"genres"]count]==2);CHECK([RWAvailabilityCache metadata:fresh]==fresh);
        NSMutableDictionary *bad=[@{@"profiles":@{@"bad":@3,@"mixed":@{@"sourceAvailability":@{@"bad":NSNull.null,@"meta":@{@"meta":@7},@"invalid":@{@"meta":@{@"date":NSDate.date}}}}}}mutableCopy];
        CHECK([RWAvailabilityCache prepareSnapshots:bad]==0);CHECK(![writer writeJSON:bad path:path]);
        CHECK([writer.diagnostics[@"failed"]intValue]==0&&[writer.diagnostics[@"main_thread_encodes"]intValue]==0);
    }@finally{Flush(writer);[[NSFileManager defaultManager]removeItemAtPath:folder error:nil];}
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
