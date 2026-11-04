// Per-pass, local content model. It learns no collaborative population model.
// Keep separate interests rather than averaging unrelated films into one taste.
static void PrepareInterests(NSArray *items,NSDictionary *profile,double now,NSMutableDictionary *cache){
    if(cache[@"interestGroups"])return;
    NSMutableDictionary *frequency=[NSMutableDictionary new];NSMutableSet *seen=[NSMutableSet new];NSUInteger documents=0;BOOL kids=RN(profile[@"maxAge"])>=0;
    for(id raw in items){NSDictionary *m=RD(raw);NSString *key=RID(m);if(!key.length||![@[@"movie",@"series"]containsObject:RT(m[@"type"])]||[seen containsObject:key]||(kids&&![m[@"ageAllowed"]boolValue]))continue;[seen addObject:key];if(documents==500)break;documents++;
        for(NSString *f in CachedFeatures(m,cache))frequency[f]=@([frequency[f]unsignedIntegerValue]+1);
    }
    NSMutableDictionary *weights=[NSMutableDictionary new];for(NSString *f in frequency){double rarity=.5+MIN(1.5,log((documents+1.0)/([frequency[f]doubleValue]+1.0)));weights[f]=@(FeatureWeight(f)*rarity);}cache[@"featureWeights"]=weights;
    NSArray *signals=[RWRecommendationSignals select:profile now:now allows:nil];NSMutableArray *groups=[NSMutableArray new];NSUInteger noFeatures=0;
    for(NSDictionary *raw in signals){NSMutableDictionary *signal=[raw mutableCopy];NSSet *features=CachedFeatures(signal[@"meta"],cache);if(!features.count){noFeatures++;continue;}signal[@"features"]=features;signal[@"vector"]=Vector(features,cache);
        NSMutableDictionary *best=nil;double bestSimilarity=.22;
        for(NSMutableDictionary *group in groups){NSArray *members=group[@"members"];NSDictionary *seed=members.firstObject;double similarity=CompareVectors(signal[@"vector"],seed[@"vector"],YES);if(similarity>bestSimilarity){best=group;bestSimilarity=similarity;}}
        if(!best){best=[@{@"id":RID(signal[@"meta"]),@"members":[NSMutableArray new],@"weight":@0}mutableCopy];[groups addObject:best];}
        [best[@"members"]addObject:signal];best[@"weight"]=@([best[@"weight"]doubleValue]+[signal[@"weight"]doubleValue]);
    }
    [groups sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSComparisonResult order=[b[@"weight"]compare:a[@"weight"]];return order==NSOrderedSame?[a[@"id"]compare:b[@"id"]]:order;}];
    NSUInteger rawGroups=groups.count;if(groups.count>6)[groups removeObjectsInRange:NSMakeRange(6,groups.count-6)];cache[@"interestGroups"]=groups;
    cache[@"interestSummary"]=@{@"signals":@(signals.count),@"clusters":@(groups.count),@"omitted_clusters":@(rawGroups-groups.count),@"signals_without_features":@(noFeatures),@"feature_vocabulary":@(frequency.count),@"documents":@(documents),@"model":@"local-content-v51"};
}
static NSDictionary *TasteEvidence(NSSet *features,NSMutableDictionary *cache){
    double best=0;NSString *identity=@"";RWRecommendationFeatureVector *vector=Vector(features,cache);
    for(NSDictionary *group in cache[@"interestGroups"]){double weighted=0,total=0,peak=0;
        for(NSDictionary *signal in group[@"members"]){double weight=[signal[@"weight"]doubleValue],similarity=CompareVectors(vector,signal[@"vector"],YES);weighted+=weight*similarity;total+=weight;peak=MAX(peak,similarity);}
        double support=MIN(1,total/3),affinity=(.65*peak+.35*(total?weighted/total:0))*support;
        if(affinity>best){best=affinity;identity=group[@"id"];}
    }return @{@"affinity":@(best),@"interest":best>=.1?identity:@""};
}
static NSArray *InterestAnchors(NSMutableDictionary *cache,NSString *type,BOOL likesOnly){
    NSMutableArray *anchors=[NSMutableArray new];
    for(NSDictionary *group in cache[@"interestGroups"]){for(NSDictionary *signal in group[@"members"]){NSDictionary *meta=signal[@"meta"];if(type.length&&![meta[@"type"]isEqual:type])continue;if(likesOnly&&![signal[@"kind"]isEqual:@"liked"])continue;
        NSMutableDictionary *brief=[NSMutableDictionary new];for(NSString *key in @[@"id",@"imdb_id",@"name",@"type",@"genres",@"discovery",@"discoveryLikedAt",@"discoverySavedAt",@"ageAllowed"])if(meta[key])brief[key]=meta[key];[anchors addObject:brief];break;
    }}return anchors;
}
