- (BOOL)hasBrowseFilters{return self.browseGenre.length||self.browseYear||self.browseRating>0||![self.browseSort?:@"Popular" isEqual:@"Popular"];}
- (NSString *)browseContext {return [NSString stringWithFormat:@"%@:%@:%@:%@:%ld:%.1f",[RewindStore shared].state[@"activeProfile"],self.filter,self.browseSort,self.browseGenre?:@"",(long)self.browseYear,self.browseRating];}
- (void)resetBrowse {
    [self.browseFeed close:nil];self.browseFeed=nil;self.browsePendingRatings=@[];self.browseGeneration++;self.browseGenre=nil;self.browseYear=0;self.browseRating=0;self.browseSort=@"Popular";self.browseSkip=0;self.browseLocalOffset=0;self.browseResults=@[];self.browseBusy=NO;self.browseError=nil;
}
- (void)fetchBrowse {
    self.browseGeneration++;self.browseSkip=0;self.browseResults=@[];self.browsePendingRatings=@[];self.browseBusy=NO;self.browseEmptyPages=0;self.browseHasMore=YES;
    [self.browseFeed close:nil];NSString *context=[self browseContext];
    NSString *folder=[NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES)[0]stringByAppendingPathComponent:@"RewindFeeds"];
    self.browseFeed=[[RWFeedStore alloc]initWithFolder:folder context:context];[self render];[self fetchNextBrowse:YES];
}
- (void)fetchNextBrowse:(BOOL)manual {
    if(self.browseBusy||!self.browseHasMore||!self.browseFeed)return;if(!manual&&self.browseEmptyPages>=3)return;if(manual)self.browseEmptyPages=0;
    if([self.filter isEqual:@"All"])self.filter=@"Movies";
    NSUInteger generation=self.browseGeneration,offset=self.browseSkip;self.browseBusy=YES;self.browseError=nil;
    NSString *type=[self.filter isEqual:@"Series"]?@"series":@"movie",*profile=RWString([RewindStore shared].state[@"activeProfile"]);RWFeedStore *feed=self.browseFeed;__weak RewindController *weak=self;[self updateBrowseGrid];
    [[RewindStore shared]browse:type sort:self.browseSort genre:self.browseGenre year:self.browseYear skip:offset done:^(id result,NSString *error){
        if(!weak||generation!=weak.browseGeneration||![profile isEqual:[RewindStore shared].state[@"activeProfile"]])return;
        weak.browseError=error;weak.browseBatchCount=[result count];if(error){weak.browseBusy=NO;[weak updateBrowseGrid];return;}
        NSArray *filtered=[RWCatalogPolicy filter:result?:@[] genre:weak.browseGenre year:weak.browseYear rating:weak.browseRating sort:weak.browseSort now:NSDate.date];RewindStore *store=[RewindStore shared];
        if(store.restricted){[store.ratings resolve:filtered];NSMutableArray *pending=[weak.browsePendingRatings mutableCopy]?:[NSMutableArray new];for(NSDictionary *m in filtered)if(![store allowed:m])[pending addObject:m];if(pending.count>100)[pending removeObjectsInRange:NSMakeRange(0,pending.count-100)];weak.browsePendingRatings=pending;}
        [feed append:[store allowedItems:filtered] done:^(NSUInteger added,NSString *writeError){
            if(!weak||generation!=weak.browseGeneration||feed!=weak.browseFeed||![profile isEqual:store.state[@"activeProfile"]])return;
            weak.browseBusy=NO;weak.browseError=writeError;if(!writeError){weak.browseSkip=offset+[result count];weak.browseHasMore=[result count]>0&&weak.browseSkip<=10000;weak.browseEmptyPages=added?0:weak.browseEmptyPages+1;}
            [store report:@{@"browse_feed":feed.diagnostics}];[weak updateBrowseGrid];[weak appendNewlyRatedBrowse];
        }];
    }];
}
- (void)appendNewlyRatedBrowse {
    if(self.browseBusy||!self.browseFeed||!self.browsePendingRatings.count)return;RewindStore *store=[RewindStore shared];NSArray *allowed=[store allowedItems:self.browsePendingRatings];if(!allowed.count)return;
    NSMutableArray *pending=[self.browsePendingRatings mutableCopy];[pending removeObjectsInArray:allowed];self.browsePendingRatings=pending;NSUInteger generation=self.browseGeneration;RWFeedStore *feed=self.browseFeed;__weak RewindController *weak=self;self.browseBusy=YES;
    [feed append:allowed done:^(NSUInteger added,NSString *error){if(generation!=weak.browseGeneration||feed!=weak.browseFeed)return;weak.browseBusy=NO;weak.browseError=error;if(error){NSMutableArray *retry=[weak.browsePendingRatings mutableCopy]?:[NSMutableArray new];[retry addObjectsFromArray:allowed];if(retry.count>100)[retry removeObjectsInRange:NSMakeRange(0,retry.count-100)];weak.browsePendingRatings=retry;}[weak updateBrowseGrid];}];
}
- (void)updateBrowseGrid {
    if(!self.feedGrid||!self.browseFeed||![self.page isEqual:@"Home"]||![self hasBrowseFilters])return;
    [self.feedGrid updateFeed:self.browseFeed loading:self.browseBusy more:self.browseHasMore error:self.browseError cursor:self.browseSkip automatic:self.browseEmptyPages<3];
}
- (void)browseChanged{self.content.accessibilityIdentifier=@"";[self fetchBrowse];}
- (void)filterMenu:(NSString *)kind anchor:(UIView *)anchor {
    __weak RewindController *weak=self;NSArray *values=nil;
    if([kind isEqual:@"Genre"])values=@[@"All genres",@"Action",@"Adventure",@"Animation",@"Comedy",@"Crime",@"Documentary",@"Drama",@"Family",@"Fantasy",@"History",@"Horror",@"Music",@"Mystery",@"Romance",@"Sci-Fi",@"Thriller",@"War",@"Western"];
    if([kind isEqual:@"Sort"])values=@[@"Popular",@"Newest",@"Top rated"];
    if([kind isEqual:@"Rating"])values=@[@"Any rating",@"6+",@"7+",@"8+"];
    if([kind isEqual:@"Year"]){NSInteger year=[[NSCalendar currentCalendar]component:NSCalendarUnitYear fromDate:NSDate.date];NSMutableArray *years=[NSMutableArray arrayWithObject:@"All years"];for(int i=0;i<8;i++)[years addObject:[@(year-i)stringValue]];[years addObject:@"Another year…"];values=years;}
    UIAlertController *a=[UIAlertController alertControllerWithTitle:kind message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for(NSString *value in values)[a addAction:[UIAlertAction actionWithTitle:value style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        if([value isEqual:@"Another year…"]){UIAlertController *input=[UIAlertController alertControllerWithTitle:@"Release year" message:@"Enter a year from 1900 to this year." preferredStyle:UIAlertControllerStyleAlert];[input addTextFieldWithConfigurationHandler:^(UITextField *f){f.keyboardType=UIKeyboardTypeNumberPad;f.placeholder=@"e.g. 1999";}];[input addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[input addAction:[UIAlertAction actionWithTitle:@"Apply" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){NSInteger year=input.textFields.firstObject.text.integerValue,current=[[NSCalendar currentCalendar]component:NSCalendarUnitYear fromDate:NSDate.date];if(year<1900||year>current){RWAlert(weak,@"Invalid year",@"Enter a release year between 1900 and this year.");return;}weak.browseYear=year;[weak browseChanged];}]];[weak presentViewController:input animated:YES completion:nil];return;}
        if([kind isEqual:@"Genre"])weak.browseGenre=[value isEqual:@"All genres"]?nil:value;
        if([kind isEqual:@"Sort"]){weak.browseSort=value;if([value isEqual:@"Newest"]&&!weak.browseYear)weak.browseYear=[[NSCalendar currentCalendar]component:NSCalendarUnitYear fromDate:NSDate.date];}
        if([kind isEqual:@"Year"]){weak.browseYear=value.integerValue;if(!weak.browseYear&&[weak.browseSort isEqual:@"Newest"])weak.browseSort=@"Popular";}
        if([kind isEqual:@"Rating"])weak.browseRating=value.doubleValue;
        [weak browseChanged];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=anchor;a.popoverPresentationController.sourceRect=anchor.bounds;[self presentViewController:a animated:YES completion:nil];
}
- (CGFloat)browseBar:(CGFloat)y {
    CGFloat w=[self width];__weak RewindController *weak=self;NSArray *keys=@[@"Genre",@"Year",@"Sort",@"Rating"];
    NSArray *titles=@[self.browseGenre?:@"All genres",self.browseYear?[@(self.browseYear)stringValue]:@"All years",self.browseSort?:@"Popular",self.browseRating?[NSString stringWithFormat:@"IMDb %.0f+",self.browseRating]:@"Any rating"];
    CGFloat widths[]={165,135,155,155},x=32;
    for(NSUInteger i=0;i<keys.count;i++){NSString *key=keys[i];__block __weak RWButton *anchor=nil;RWButton *b=[self button:titles[i] x:x y:y width:widths[i] primary:NO action:^{[weak filterMenu:key anchor:anchor];}];anchor=b;[b icon:@"chevron-down"];b.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightMedium];x+=widths[i]+10;}
    if([self hasBrowseFilters]){RWButton *clear=[self button:@"Reset" x:w-92 y:y width:60 primary:NO action:^{[weak resetBrowse];[weak render];}];clear.backgroundColor=UIColor.clearColor;clear.layer.borderWidth=0;}
    return y+68;
}
- (void)filteredBrowsePage {
    NSString *title=[self.filter isEqual:@"Series"]?@"Find your next series":@"Find your next film";
    [self heading:title subtitle:@"Browse by genre, release year and rating."];CGFloat y=[self browseBar:128];__weak RewindController *weak=self;
    self.feedGrid=[[RWPosterCollection alloc]initWithFrame:CGRectMake(0,y,[self width],MAX(100,self.content.bounds.size.height-y))];self.feedGrid.reviewMode=self.reviewMode;
    self.feedGrid.onSelect=^(NSDictionary *m){[weak showDetails:m];};self.feedGrid.onLoadMore=^(BOOL manual){[weak fetchNextBrowse:manual];};
    [self.content addSubview:self.feedGrid];self.content.scrollEnabled=NO;self.content.contentSize=self.content.bounds.size;[self updateBrowseGrid];
}
- (NSArray *)discoveryItems:(NSArray *)items recent:(BOOL)recent {
    RewindStore *s=[RewindStore shared];NSInteger year=[[NSCalendar currentCalendar]component:NSCalendarUnitYear fromDate:NSDate.date];NSMutableSet *seen=[NSMutableSet setWithArray:s.profile[@"hidden"]?:@[]];
    for(NSDictionary *r in s.history)if([r[@"completed"]boolValue]||[r[@"position"]doubleValue]>3)[seen addObject:RWID(r[@"meta"])];
    NSMutableArray *out=[NSMutableArray new];
    for(NSDictionary *m in [RWCatalogPolicy filter:[s allowedItems:items] genre:nil year:0 rating:0 sort:@"Popular" now:NSDate.date])if(![seen containsObject:RWID(m)]&&(!recent||(RWString(m[@"releaseInfo"]).integerValue==year&&RWString(m[@"released"]).length>=10))){[out addObject:m];[seen addObject:RWID(m)];}
    return out;
}
