- (void)kidsHome {
    RewindStore *store=[RewindStore shared];CGFloat w=[self width];__weak RewindController *weak=self;
    BOOL onlyShows=[self.filter isEqual:@"Series"],onlyMovies=[self.filter isEqual:@"Movies"];
    NSArray *allowed=[store allowedItems:store.familyCatalog];NSMutableArray *films=[NSMutableArray new],*shows=[NSMutableArray new];
    for(NSDictionary *meta in allowed){if([meta[@"type"]isEqual:@"series"])[shows addObject:meta];else[films addObject:meta];}
    UILabel *eyebrow=[self label:[NSString stringWithFormat:@"%@’S KIDS SPACE",[RWString(store.profile[@"name"])uppercaseString]] x:33 y:22 width:w-66 size:12 weight:UIFontWeightBold color:0xa6d6b8];RWTracking(eyebrow,1.4);
    [self label:@"Big stories. Little adventures." x:32 y:54 width:w-64 size:w<900?32:38 weight:UIFontWeightBold color:0xf5f2eb];
    NSInteger age=[store.profile[@"maxAge"]integerValue];[self label:age==0?@"General audience · films and shows":[NSString stringWithFormat:@"For ages %ld and under · films and shows",(long)age] x:33 y:108 width:w-66 size:14 weight:UIFontWeightRegular color:0xa9b9b2];
    NSArray *features=onlyMovies?films:(shows.count?shows:films);CGFloat y=154;
    if(features.count){NSDictionary *hero=features[self.heroIndex%features.count];[self.displayedIDs addObject:RWID(hero)];
        UIView *stage=RWPanel(CGRectMake(32,y,w-64,280));stage.clipsToBounds=YES;stage.backgroundColor=RWColor(0x193a39);[self.content addSubview:stage];
        UIImageView *art=[[UIImageView alloc]initWithFrame:CGRectMake((w-64)*.38,0,(w-64)*.62,280)];art.contentMode=UIViewContentModeScaleAspectFill;art.clipsToBounds=YES;[stage addSubview:art];[store artwork:[RWArtworkPolicy URLsForMeta:hero landscape:YES] role:@"hero" identity:RWID(hero) into:art completion:nil];UIView *shade=[[UIView alloc]initWithFrame:stage.bounds];RWShade(shade,YES);[stage addSubview:shade];
        UILabel *tag=RWLabel(@"A LITTLE FAVOURITE",11,UIFontWeightBold,RWColor(0xc6edb6));RWTracking(tag,1.3);tag.frame=CGRectMake(24,24,300,20);[stage addSubview:tag];
        UILabel *title=RWLabel(RWString(hero[@"name"]),34,UIFontWeightBold,RWColor(0xf5f2eb));title.numberOfLines=2;title.frame=CGRectMake(22,62,MIN(390,w*.55),95);[stage addSubview:title];
        UILabel *rating=RWLabel(RWString([store.ratings rating:RWID(hero)][@"label"]),13,UIFontWeightMedium,RWColor(0xc4d8cf));rating.frame=CGRectMake(24,166,340,24);[stage addSubview:rating];
        RWButton *open=[RWButton text:[hero[@"type"]isEqual:@"series"]?@"Explore show":@"Explore film" action:^{[weak showDetails:hero];}];[open appearance:YES];open.backgroundColor=RWColor(0xc6edb6);[open icon:@"play"];open.frame=CGRectMake(24,210,176,48);[stage addSubview:open];y+=311;
    }
    NSMutableArray *continuing=[NSMutableArray new];for(NSDictionary *record in store.continuingHistory){BOOL series=[record[@"meta"][@"type"]isEqual:@"series"];if(onlyShows&&!series||onlyMovies&&series)continue;NSMutableDictionary *meta=[record[@"meta"]mutableCopy];meta[@"historyRecord"]=record;[continuing addObject:meta];}
    y=[self row:@"Keep watching" subtitle:nil movies:continuing y:y landscape:YES];
    if(!onlyMovies)y=[self row:@"Favourite shows" subtitle:@"Friends to come back to" movies:shows y:y landscape:NO];
    if(!onlyShows)y=[self row:@"Family movie time" subtitle:@"Stories to watch together" movies:films y:y landscape:NO];
    y=[self row:@"My favourites" subtitle:nil movies:store.saved y:y landscape:NO];
    if(!allowed.count){[self label:@"Finding stories for this age group…" x:33 y:y width:w-66 size:22 weight:UIFontWeightSemibold color:0xf5f2eb];y+=60;}
    self.content.contentSize=CGSizeMake(w,y+24);
    if(!self.reviewMode){NSMutableArray *visible=[NSMutableArray new];NSUInteger unknown=0,overAge=0;for(NSDictionary *meta in allowed){NSDictionary *rating=[store.ratings rating:RWID(meta)];if(!rating||[rating[@"minimumAge"]integerValue]<0)unknown++;else if([rating[@"minimumAge"]integerValue]>age)overAge++;[visible addObject:@{@"id":RWID(meta),@"minimum_age":rating[@"minimumAge"]?:@(-1)}];}[store report:@{@"kids_catalog":@{@"age_limit":@(age),@"films":@(films.count),@"shows":@(shows.count),@"unrated_visible":@(unknown),@"over_age_visible":@(overAge),@"visible":visible}}];}
}
