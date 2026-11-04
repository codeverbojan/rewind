// Reviewed public-film aliases only. Never merge remakes or unrelated same-name
// titles. Search presentation retains the public ID/source and all policy fields.
static NSString *RWSearchCanonical(NSDictionary *m) {
    if(![m[@"type"]isEqual:@"movie"])return nil;
    NSString *identifier=Text(m[@"id"]),*name=Normal(m[@"name"]);NSInteger year=[Text(m[@"releaseInfo"])integerValue];
    if(( [identifier isEqual:@"rw:sintel"]||[identifier isEqual:@"tt1727587"])&&[name isEqual:@"sintel"]&&year==2010)return @"tt1727587";
    if(([identifier isEqual:@"rw:cosmos"]||[identifier isEqual:@"tt4957236"])&&([name isEqual:@"cosmos laundromat"]||[name isEqual:@"cosmos laundromat first cycle"])&&year==2015)return @"tt4957236";
    return nil;
}
static NSArray *RWSearchUnique(NSArray *items) {
    NSMutableArray *out=[NSMutableArray new];NSMutableDictionary *positions=[NSMutableDictionary new];
    for(id raw in items){if(![raw isKindOfClass:NSDictionary.class]||!Text(raw[@"id"]).length)continue;
        NSDictionary *m=raw;NSString *canonical=RWSearchCanonical(m),*key=[NSString stringWithFormat:@"%@:%@:%@",canonical?@"reviewed":@"literal",Text(m[@"type"]),canonical?:Text(m[@"id"])];NSNumber *position=positions[key];
        if(!position){positions[key]=@(out.count);[out addObject:m];continue;}
        if(!canonical)continue;NSDictionary *old=out[position.unsignedIntegerValue];BOOL publicOld=[Text(old[@"id"])hasPrefix:@"rw:"],publicNew=[Text(m[@"id"])hasPrefix:@"rw:"];
        NSDictionary *base=publicOld?old:m,*display=publicOld?m:old;
        if(publicOld==publicNew){if(publicOld&&![old[@"source"]isKindOfClass:NSDictionary.class]&&[m[@"source"]isKindOfClass:NSDictionary.class]){NSMutableDictionary *full=[m mutableCopy];for(NSString *field in @[@"imdb_id",@"poster",@"background",@"imdbRating",@"imdbVotes",@"runtime"])if(old[field])full[field]=old[field];out[position.unsignedIntegerValue]=full;}continue;}
        NSMutableDictionary *merged=[base mutableCopy];merged[@"imdb_id"]=canonical;
        // Only cosmetic fields cross the reviewed identity boundary. No source,
        // subtitle, watch history, availability, rating-policy or age fields.
        for(NSString *field in @[@"poster",@"background",@"imdbRating",@"imdbVotes",@"runtime"]){id value=display[field];if(([value isKindOfClass:NSString.class]&&[value length])||[value isKindOfClass:NSNumber.class])merged[field]=value;}
        out[position.unsignedIntegerValue]=merged;
    }return out;
}
