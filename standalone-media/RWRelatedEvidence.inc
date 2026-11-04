// Detail-page evidence is independent of Home's discovery/novelty ordering.
// Genre-derived moods are not a second independent vote for the same genre.
static NSSet *RelatedGenres(NSDictionary *meta){
    NSMutableArray *labels=[NSMutableArray new];
    for(NSString *field in @[@"genres",@"genre"]){NSUInteger n=0;for(id v in RA(meta[field])){if(n++==24)break;if(RT(v).length&&RT(v).length<=100)[labels addObject:v];}}
    NSUInteger n=0;for(id raw in RA(RD(meta[@"discovery"])[@"genres"])){if(n++==12)break;NSString *label=RT(RD(raw)[@"name"]);if(label.length&&label.length<=100)[labels addObject:label];}
    NSMutableSet *out=[NSMutableSet new];
    for(NSString *label in labels){NSString *s=[NSString stringWithFormat:@" %@ ",[[label lowercaseString]stringByReplacingOccurrencesOfString:@"-" withString:@" "]];
        for(NSString *genre in @[@"action",@"adventure",@"comedy",@"crime",@"documentary",@"drama",@"family",@"fantasy",@"horror",@"music",@"musical",@"mystery",@"romance",@"sport",@"thriller",@"war",@"western"])
            if([s containsString:[NSString stringWithFormat:@" %@ ",genre]])[out addObject:genre];
        if([s containsString:@" sci fi "]||[s containsString:@" science fiction "]||[s containsString:@" scifi "])[out addObject:@"sci-fi"];
        if([s containsString:@" animation "]||[s containsString:@" animated "]||[s containsString:@" anime "])[out addObject:@"animation"];
        if([s containsString:@" romantic "])[out addObject:@"romance"];
        if([s containsString:@" biography "]||[s containsString:@" biographical "]||[s containsString:@" biopic "])[out addObject:@"biography"];
        if([s containsString:@" history "]||[s containsString:@" historical "])[out addObject:@"history"];
        if([s containsString:@" children "]||[s containsString:@" children's "]||[s containsString:@" kids "])[out addObject:@"family"];
    }return out;
}
static NSSet *RelatedIDs(NSDictionary *meta,NSString *field){
    NSMutableSet *ids=[NSMutableSet new];NSUInteger n=0;for(id raw in RA(RD(meta[@"discovery"])[field])){if(n++==24)break;NSDictionary *ref=RD(raw);NSString *key=RT(ref[@"id"]);if(!VerifiedID(key))continue;
        // Share the same evidence gate as Home; labels alone are not classification.
        if([field isEqual:@"franchises"]&&![RWDiscoveryMetadataPolicy isNarrativeFranchise:ref])continue;
        [ids addObject:key];}return ids;
}
static NSSet *RelatedIntersection(NSSet *a,NSSet *b){NSMutableSet *out=[a mutableCopy];[out intersectSet:b];return out;}
static NSDictionary *RelatedRecord(NSDictionary *meta){NSMutableDictionary *primary=[meta mutableCopy];primary[@"discovery"]=@{};NSSet *all=RelatedGenres(meta),*main=RelatedGenres(primary);if(!main.count)main=all;return @{@"genres":all,@"primary":main,@"directors":RelatedIDs(meta,@"directors"),@"themes":RelatedIDs(meta,@"themes"),@"cast":RelatedIDs(meta,@"cast"),@"franchises":RelatedIDs(meta,@"franchises")};}
static NSDictionary *RelatedEvidenceRecords(NSDictionary *candidate,NSDictionary *anchor,NSDictionary *candidateRecord,NSDictionary *anchorRecord){
    NSSet *a=anchorRecord[@"genres"],*b=candidateRecord[@"genres"],*common=RelatedIntersection(a,b),*primaryA=anchorRecord[@"primary"],*primaryB=candidateRecord[@"primary"],*primaryCommon=RelatedIntersection(primaryA,primaryB);
    NSMutableSet *specific=[primaryCommon mutableCopy];[specific minusSet:[NSSet setWithArray:@[@"drama",@"comedy",@"adventure",@"action",@"family",@"animation"]]];
    NSSet *directors=RelatedIntersection(anchorRecord[@"directors"],candidateRecord[@"directors"]);
    NSSet *themes=RelatedIntersection(anchorRecord[@"themes"],candidateRecord[@"themes"]);
    NSSet *cast=RelatedIntersection(anchorRecord[@"cast"],candidateRecord[@"cast"]);
    NSSet *franchises=candidateRecord[@"franchises"],*sharedFranchise=RelatedIntersection(anchorRecord[@"franchises"],franchises);
    BOOL known=a.count&&b.count,animationMismatch=known&&([a containsObject:@"animation"]!=[b containsObject:@"animation"]),documentaryMismatch=known&&([a containsObject:@"documentary"]!=[b containsObject:@"documentary"]);
    BOOL horrorMismatch=known&&([primaryA containsObject:@"horror"]!=[primaryB containsObject:@"horror"]),comedyMismatch=known&&([primaryA containsObject:@"comedy"]!=[primaryB containsObject:@"comedy"]),familyMismatch=known&&([a containsObject:@"family"]!=[b containsObject:@"family"]);
    double overlap=(primaryA.count+primaryB.count-primaryCommon.count)?(double)primaryCommon.count/(primaryA.count+primaryB.count-primaryCommon.count):0;
    BOOL genreEvidence=specific.count>0||(primaryCommon.count>=2&&overlap>=.66),corroboration=primaryCommon.count>0&&(themes.count>=2||cast.count>=2);
    BOOL eligible=directors.count||sharedFranchise.count||genreEvidence||corroboration;
    NSString *reason=sharedFranchise.count?@"franchise":directors.count?@"director":genreEvidence?@"genre-combination":corroboration?@"corroborated-context":@"insufficient-context";
    NSMutableSet *focus=[primaryA mutableCopy];[focus intersectSet:[NSSet setWithArray:@[@"sci-fi",@"fantasy",@"horror",@"mystery",@"crime",@"romance",@"western",@"war",@"sport",@"musical",@"documentary"]]];
    if(focus.count&&primaryB.count&&!RelatedIntersection(focus,primaryB).count&&!(directors.count||sharedFranchise.count||(themes.count>=2&&primaryCommon.count))){eligible=NO;reason=@"primary-context-mismatch";}
    // A shared broad theme cannot turn a children's cartoon into a close match
    // for live-action science fiction. Adult animation can still bridge formats
    // with a specific shared genre combination AND an actual shared theme.
    if(animationMismatch&&!(sharedFranchise.count||(primaryCommon.count>=2&&specific.count&&themes.count&&!familyMismatch))){eligible=NO;reason=@"animation-context-mismatch";}
    if(documentaryMismatch&&!sharedFranchise.count){eligible=NO;reason=@"documentary-context-mismatch";}
    if(horrorMismatch&&!(directors.count||sharedFranchise.count||themes.count>=2)){eligible=NO;reason=@"horror-context-mismatch";}
    if(![RT(anchor[@"type"])isEqual:RT(candidate[@"type"])]||!RID(anchor).length||[RID(anchor)isEqual:RID(candidate)]){eligible=NO;reason=@"identity-or-type";}
    double score=.40+.13*MIN((NSUInteger)2,primaryCommon.count)+.14*overlap+.035*MIN((NSUInteger)2,themes.count)+.02*MIN((NSUInteger)2,cast.count);
    if(directors.count)score=MAX(score,.86);if(sharedFranchise.count)score=MAX(score,.93);
    if(comedyMismatch&&!directors.count&&!sharedFranchise.count)score*=.80;
    if(familyMismatch&&!directors.count&&!sharedFranchise.count)score*=.80;
    if(animationMismatch)score*=.90;
    return @{@"eligible":@(eligible),@"score":@(eligible?MIN(.98,score):0),@"reason":reason,@"shared_genres":[common.allObjects sortedArrayUsingSelector:@selector(compare:)],@"anchor_primary_genres":[primaryA.allObjects sortedArrayUsingSelector:@selector(compare:)],@"candidate_primary_genres":[primaryB.allObjects sortedArrayUsingSelector:@selector(compare:)],@"anchor_genres":[a.allObjects sortedArrayUsingSelector:@selector(compare:)],@"candidate_genres":[b.allObjects sortedArrayUsingSelector:@selector(compare:)],@"shared_directors":[directors.allObjects sortedArrayUsingSelector:@selector(compare:)],@"shared_themes":[themes.allObjects sortedArrayUsingSelector:@selector(compare:)],@"shared_cast_count":@(cast.count),@"shared_franchises":[sharedFranchise.allObjects sortedArrayUsingSelector:@selector(compare:)],@"franchises":[franchises.allObjects sortedArrayUsingSelector:@selector(compare:)],@"animation_mismatch":@(animationMismatch),@"documentary_mismatch":@(documentaryMismatch),@"comedy_mismatch":@(comedyMismatch),@"family_mismatch":@(familyMismatch)};
}

static NSDictionary *RelatedEvidence(NSDictionary *candidate,NSDictionary *anchor){return RelatedEvidenceRecords(candidate,anchor,RelatedRecord(candidate),RelatedRecord(anchor));}
static NSDictionary *CachedRelatedRecord(NSDictionary *meta,NSMutableDictionary *cache){
    NSMapTable *records=cache[@"relatedRecords"];if(!records){records=[NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory|NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsStrongMemory];cache[@"relatedRecords"]=records;}
    NSDictionary *record=[records objectForKey:meta];if(!record){record=RelatedRecord(meta);[records setObject:record forKey:meta];}return record;
}
static NSDictionary *CachedRelatedEvidence(NSDictionary *candidate,NSDictionary *anchor,NSMutableDictionary *cache){return RelatedEvidenceRecords(candidate,anchor,CachedRelatedRecord(candidate,cache),CachedRelatedRecord(anchor,cache));}
