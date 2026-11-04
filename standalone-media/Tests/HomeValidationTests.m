#import "../RWHomePreparation.h"
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSDictionary *Film(NSString *name,BOOL eligible){return @{@"id":@"film",@"name":name,@"type":@"movie",@"released":@"2020-01-01",@"ageAllowed":@YES,@"discovery":@{@"primaryLanguage":@"en",@"languageSource":@"verified",@"industry":@"other"},@"availability":@{@"discovery_eligible":@(eligible),@"hero_eligible":@NO}};}
static NSDictionary *Batch(NSDictionary *title,NSDictionary *scope,NSString *profile,double time){return [RWHomePreparation prepare:@{@"hero":title,@"rows":@[],@"ratingPriors":@[@6.5,@6.5]} snapshot:scope ratings:@{} profileID:profile now:time];}
static RWHomeValidation *Pass(NSDictionary *a,NSDictionary *b,NSDictionary *scope,NSString *profile,double time){return [[RWHomeValidation alloc]initWithRanked:a fallback:b snapshot:scope ratings:@{} profileID:profile priors:@[@6.5,@6.5] now:time];}
int main(){@autoreleasepool{
    double now=2000000000;NSDictionary *raw=Film(@"Original",YES);
    NSDictionary *scope=@{@"quality":@0,@"family":@[],@"shows":@{},@"metadata":@{},@"ageRatings":@{},@"offline":@{},@"offlineAt":@0,@"profile":@{@"maxAge":@(-1),@"discoveryPreferences":@{},@"history":@{},@"sourceAvailability":@{}}};
    NSDictionary *ranked=Batch(raw,scope,@"main",now),*fallback=Batch(raw,scope,@"main",now);
    RWHomeValidation *pass=Pass(ranked,fallback,scope,@"main",now);
    CHECK([pass.diagnostics[@"dependency_checks"]integerValue]==0); // No eager title scan.
    NSDictionary *entry=[pass entryForTitle:raw now:now];CHECK(entry==ranked[@"entries"][@"film"]);CHECK([entry[@"regular"]boolValue]);CHECK([pass.diagnostics[@"dependency_checks"]integerValue]==1);CHECK([pass.diagnostics[@"fallback_hits"]integerValue]==0);
    CHECK([pass entryForTitle:raw now:now+1]==entry);CHECK([pass.diagnostics[@"title_hits"]integerValue]==1);CHECK([pass.diagnostics[@"dependency_checks"]integerValue]==1);
    NSMutableDictionary *copy=[raw mutableCopy];CHECK([pass entryForTitle:copy now:now+1]==entry);CHECK([pass.diagnostics[@"decision_hits"]integerValue]==1);CHECK([pass.diagnostics[@"dependency_checks"]integerValue]==1);
    CHECK([pass entryForPreparedMetadata:entry[@"meta"] now:now+1]==entry);CHECK(![pass entryForPreparedMetadata:raw now:now+1]);
    // Pointer hits still recheck clocks, including a deadline during one pass.
    CHECK(![pass entryForTitle:raw now:now+300]);CHECK(![pass entryForPreparedMetadata:entry[@"meta"] now:now+300]);CHECK(![pass entryForTitle:raw now:now-1]);CHECK(![pass entryForTitle:raw now:NAN]);
    // An expired ranked record may use a still-current fallback.
    pass=Pass(Batch(raw,scope,@"main",now-301),fallback,scope,@"main",now);CHECK([pass entryForTitle:raw now:now]==fallback[@"entries"][@"film"]);CHECK([pass.diagnostics[@"dependency_checks"]integerValue]==1);
    // Source-content identity is independent of the title identifier. A newer
    // unavailable release must not inherit an older same-ID positive decision.
    NSDictionary *revised=Film(@"Changed title",NO),*revisedBatch=Batch(revised,scope,@"main",now);
    pass=Pass(ranked,revisedBatch,scope,@"main",now);NSDictionary *negative=[pass entryForTitle:revised now:now];CHECK(negative==revisedBatch[@"entries"][@"film"]);CHECK(![negative[@"regular"]boolValue]);CHECK([pass.diagnostics[@"dependency_checks"]integerValue]==1);
    CHECK([pass entryForTitle:raw now:now]==ranked[@"entries"][@"film"]);CHECK([pass entryForPreparedMetadata:negative[@"meta"] now:now]==negative); // Two raw versions never alias in the per-pass cache.
    copy=[raw mutableCopy];copy[@"poster"]=@"https://example.test/new.jpg";CHECK(![Pass(ranked,fallback,scope,@"main",now)entryForTitle:copy now:now]);
    copy=[raw mutableCopy];copy[@"released"]=@"2035-01-01";CHECK(![Pass(ranked,fallback,scope,@"main",now)entryForTitle:copy now:now]);
    copy=[raw mutableCopy];copy[@"type"]=@"series";CHECK(![Pass(ranked,fallback,scope,@"main",now)entryForTitle:copy now:now]);
    // Negative decisions stay authoritative; a second cache cannot turn them on.
    pass=Pass(revisedBatch,ranked,scope,@"main",now);CHECK(![[pass entryForTitle:revised now:now][@"regular"]boolValue]);CHECK([pass.diagnostics[@"fallback_hits"]integerValue]==0);
    // Scope and dependency changes reject only the obsolete candidate. The
    // updated cache is still usable without retrying the old dependency check.
    NSMutableDictionary *updated=[scope mutableCopy];updated[@"metadata"]=@{@"film":@{@"language":@"updated"}};NSDictionary *fresh=Batch(raw,updated,@"main",now);
    pass=Pass(ranked,fresh,updated,@"main",now);CHECK([pass entryForTitle:raw now:now]==fresh[@"entries"][@"film"]);CHECK([pass.diagnostics[@"dependency_checks"]integerValue]==2);
    CHECK(![Pass(ranked,fallback,scope,@"kids",now)entryForTitle:raw now:now]);
    for(NSString *field in @[@"quality",@"family",@"profile"]){updated=[scope mutableCopy];updated[field]=[field isEqual:@"quality"]?@720:[field isEqual:@"family"]?@[raw]:@{@"maxAge":@7};CHECK(![Pass(ranked,fallback,updated,@"main",now)entryForTitle:raw now:now]);}
    for(NSString *field in @[@"sourceAvailability",@"history"]){updated=[scope mutableCopy];NSMutableDictionary *profile=[scope[@"profile"]mutableCopy];profile[field]=@{@"film":@{@"checked":@(now)}};updated[@"profile"]=profile;
        NSDictionary *resolved=[Pass(ranked,fallback,updated,@"main",now)entryForTitle:raw now:now];CHECK([field isEqual:@"history"]?resolved!=nil:resolved==nil);}
    CHECK(![Pass(nil,nil,scope,@"main",now)entryForTitle:raw now:now]);CHECK([Pass(nil,fallback,scope,@"main",now)entryForTitle:raw now:now]);CHECK(![pass entryForTitle:nil now:now]);
    // A new UI pass does not carry validation decisions over mutable owner data.
    updated=[scope mutableCopy];updated[@"offline"]=@{@"film":@{@"at":@(now)}};CHECK(![Pass(ranked,nil,updated,@"main",now)entryForTitle:raw now:now]);
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
