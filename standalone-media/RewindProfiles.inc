- (void)presentProfileEntrance {
    if([self.page isEqual:@"Profiles"]&&!self.reviewMode)[self.profileExperience presentIfActive];
}
- (void)chooseProfileCard:(NSString *)identifier {
    if(![self.page isEqual:@"Profiles"]||![RewindStore shared].state[@"profiles"][identifier])return;
    UIView *selected=nil;for(UIView *view in self.content.subviews)if([view.accessibilityIdentifier isEqual:[@"RWProfile:" stringByAppendingString:identifier]]){selected=view;break;}
    if(!selected)return;__weak RewindController *weak=self;
    [self.profileExperience selectCard:selected page:self.content host:self.view change:^{[weak selectProfile:identifier];} destination:^UIView *{return weak.navigationProfile;}];
}
- (void)selectProfile:(NSString *)identifier {
    RewindStore *s=[RewindStore shared];NSDictionary *target=s.state[@"profiles"][identifier];if(!target)return;__weak RewindController *weak=self;
    // Rail offset keys already contain the profile and destination. Keep the
    // bounded in-process map for a return visit; a new launch still starts left.
    void(^change)(void)=^{weak.myListSuspendedAnchor=nil;weak.myListSuspendedProfile=nil;NSString *owner=RWString(weak.pendingReminder[@"rewindReminder"][@"profileID"]);if(owner.length&&![owner isEqual:identifier])weak.pendingReminder=nil;weak.notificationEpisodeID=nil;weak.notificationTitleID=nil;[weak discardParkedHome];[weak stopPreview];[weak.homeView saveVisibleAnchors];[weak.homeFeeds cancel];[s switchProfile:identifier];weak.homePlan=nil;weak.homeRefreshStarted=NO;[weak resetEntityFeed];[weak resetExplore];weak.downloadsGeneration++;weak.downloadsBusy=NO;weak.downloadsSnapshot=nil;weak.downloadsScope=nil;[weak.destinationStack removeAllObjects];weak.relatedKey=nil;weak.relatedTitles=@[];weak.detail=nil;weak.search.text=@"";weak.searchResults=@[];weak.searchMessage=nil;weak.filter=@"All";weak.returnPage=nil;weak.heroIndex=0;weak.managingProfiles=NO;weak.prefetchedEpisode=nil;[weak resetBrowse];[weak go:@"Home"];[weak processPendingReminder];};
    double selected=NSProcessInfo.processInfo.systemUptime;change();if(!self.reviewMode)[[RWUIProbe shared]transition:@"profile_to_home_display_callback" started:selected];[s report:@{@"profile_to_home_seconds":@(NSProcessInfo.processInfo.systemUptime-selected)}];[self loadCatalogs];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{if([s.state[@"activeProfile"]isEqual:identifier]){[s checkAvailability];[s checkEpisodes:^(BOOL changed){}];}});if(!self.reviewMode)[self performSelector:@selector(beginLayoutReview) withObject:nil afterDelay:1];
}
- (void)profilesPage {
    RewindStore *s=[RewindStore shared];CGFloat w=[self width],h=self.content.bounds.size.height;__weak RewindController *weak=self;
    if(!self.profileExperience)self.profileExperience=[RWProfileExperience new];
    self.profileExperience.cinematic=[s.state[@"profileMotion"]isEqual:@"cinematic"];
    self.profileExperience.soundEnabled=s.state[@"startupSoundEnabled"]?[s.state[@"startupSoundEnabled"]boolValue]:YES;
    NSMutableArray *entranceCards=[NSMutableArray new];
    UILabel *brand=[self label:@"REWIND" x:40 y:30 width:200 size:22 weight:UIFontWeightHeavy color:0xff6847];RWTracking(brand,2);
    NSArray *keys=[[s.state[@"profiles"]allKeys]sortedArrayUsingComparator:^NSComparisonResult(NSString *a,NSString *b){if([a isEqual:@"main"])return NSOrderedAscending;if([b isEqual:@"main"])return NSOrderedDescending;return [a compare:b];}];
    NSUInteger total=keys.count+(keys.count<6?1:0),columns=MIN(total,(NSUInteger)(w<900?3:4));CGFloat tile=146,gap=30;NSUInteger rows=(total+columns-1)/columns;
    CGFloat top=MAX(150,(h-(rows*220+190))/2),headingY=MAX(95,top-85);
    UILabel *heading=[self label:self.managingProfiles?@"Manage profiles":@"Who’s watching?" x:32 y:headingY width:w-64 size:42 weight:UIFontWeightRegular color:0xf5f2eb];heading.textAlignment=NSTextAlignmentCenter;
    for(NSUInteger i=0;i<total;i++){
        NSUInteger row=i/columns,col=i%columns,count=MIN(columns,total-row*columns);CGFloat x=(w-(count*tile+(count-1)*gap))/2+col*(tile+gap),y=top+row*220;
        BOOL add=i==keys.count;NSString *key=add?nil:keys[i];NSDictionary *profile=add?nil:s.state[@"profiles"][key];NSInteger age=[profile[@"maxAge"]integerValue];BOOL kids=!add&&age>=0;
        RWProfileButton *card=[RWProfileButton text:@"" action:^{if(add)[weak editProfile:nil];else if(weak.managingProfiles)[weak editProfile:key];else[weak chooseProfileCard:key];}];card.frame=CGRectMake(x,y,tile,202);card.accessibilityLabel=add?@"Add profile":[NSString stringWithFormat:@"%@%@",RWString(profile[@"name"]),kids?[NSString stringWithFormat:@", age %ld and under",(long)age]:@""];[self.content addSubview:card];
        [entranceCards addObject:card];
        if(!add)card.accessibilityIdentifier=[@"RWProfile:" stringByAppendingString:key];
        UIView *avatar=add?[[UIView alloc]initWithFrame:CGRectMake(5,0,136,136)]:RWProfileAvatar(CGRectMake(5,0,136,136),RWProfileAvatarColor(key,s.state[@"profiles"]),kids);
        avatar.userInteractionEnabled=NO;avatar.layer.cornerRadius=12;avatar.clipsToBounds=YES;[card addSubview:avatar];
        card.cinematic=self.profileExperience.cinematic;card.profileAvatar=avatar;card.profileName=add?@"Add profile":RWString(profile[@"name"]);card.kids=kids;
        if(add){avatar.backgroundColor=RWColor(0x20262e);UIImageView *plus=[[UIImageView alloc]initWithImage:RWIcon(@"plus",48,RWColor(0xb6bec8))];plus.frame=CGRectMake(44,44,48,48);[avatar addSubview:plus];}
        else {
            if(self.managingProfiles){UIView *veil=[[UIView alloc]initWithFrame:avatar.bounds];veil.backgroundColor=[UIColor colorWithWhite:0 alpha:.45];[avatar addSubview:veil];UIImageView *edit=[[UIImageView alloc]initWithImage:RWIcon(@"sliders-horizontal",32,UIColor.whiteColor)];edit.frame=CGRectMake(52,52,32,32);[veil addSubview:edit];}
        }
        UILabel *name=RWLabel(add?@"Add profile":RWString(profile[@"name"]),19,UIFontWeightMedium,RWColor(add?0x9ca5b1:0xf5f2eb));name.frame=CGRectMake(0,150,tile,26);name.textAlignment=NSTextAlignmentCenter;[card addSubview:name];
        if(kids){UILabel *limit=RWLabel(age==0?@"General audience":[NSString stringWithFormat:@"Ages %ld and under",(long)age],12,UIFontWeightRegular,RWColor(0xa4b4ae));limit.frame=CGRectMake(0,179,tile,20);limit.textAlignment=NSTextAlignmentCenter;[card addSubview:limit];}
    }
    CGFloat bottom=top+rows*220+10;
    RWButton *manage=[self button:self.managingProfiles?@"Done":@"Manage profiles" x:(w-200)/2 y:bottom width:200 primary:NO action:^{weak.managingProfiles=!weak.managingProfiles;[weak render];}];manage.layer.borderWidth=1;manage.layer.borderColor=RWColor(0x56606e).CGColor;
    self.content.contentSize=CGSizeMake(w,MAX(h,bottom+110));
    if(!self.reviewMode)[self.profileExperience prepare:self.content brand:brand heading:heading cards:entranceCards footer:manage];
}
- (void)editProfile:(NSString *)identifier {
    RewindStore *s=[RewindStore shared];if(!identifier&&[s.state[@"profiles"]count]>=6){RWAlert(self,@"Six profiles are available",@"Edit an existing profile to make room for another viewer.");return;}
    UIAlertController *a=[UIAlertController alertControllerWithTitle:identifier?@"Edit profile":@"New profile" message:@"Give this viewer a name, then choose an age limit." preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *f){f.placeholder=@"Profile name";f.text=identifier?s.state[@"profiles"][identifier][@"name"]:@"";}];__weak RewindController *weak=self;
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Choose age limit" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){NSString *name=[a.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(!name.length||name.length>24){RWAlert(weak,@"Choose a short name",@"Use between 1 and 24 characters.");return;}[weak chooseAge:identifier name:name];}]];[self presentViewController:a animated:YES completion:nil];
}
- (void)chooseAge:(NSString *)identifier name:(NSString *)name {
    __weak RewindController *weak=self;RewindStore *s=[RewindStore shared];UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Age limit" message:@"Choose what this viewer can watch. Kids profiles show rated family titles; titles without a verified rating stay hidden." preferredStyle:UIAlertControllerStyleActionSheet];
    for(NSNumber *age in @[@0,@7,@8,@10,@12,@13,@15,@17,@18,@(-1)]){NSString *title=age.integerValue<0?@"Everyone · all ratings":age.integerValue==0?@"General audience only":[NSString stringWithFormat:@"Age limit %@",age];
        [a addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){NSString *key=identifier?:NSUUID.UUID.UUIDString;NSMutableDictionary *p=identifier?s.state[@"profiles"][key]:[RWProfiles make:name age:age.integerValue];p[@"name"]=name;p[@"maxAge"]=age;if(!identifier&&age.integerValue>=0)p[@"autoplayTrailers"]=@NO;s.state[@"profiles"][key]=p;[s save];[weak go:@"Profiles"];}]];}
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=self.view;a.popoverPresentationController.sourceRect=CGRectMake([self width]/2,240,1,1);[self presentViewController:a animated:YES completion:nil];
}
