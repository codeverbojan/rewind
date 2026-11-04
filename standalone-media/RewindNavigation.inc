// One live navigation bar belongs to this controller. Content screens can be
// replaced without rebuilding its buttons, text and icon bitmaps. Actions read
// current controller/store state; no profile or title is captured in them.
- (void)navigation {
    double began=NSProcessInfo.processInfo.systemUptime;CGFloat w=[self width];BOOL created=!self.sidebar;
    __weak RewindController *weak=self;
    if(created){
        self.sidebar=[[UIView alloc]initWithFrame:CGRectMake(0,0,w,84)];self.sidebar.backgroundColor=RWColor(0x0e1116);
        RWButton *brand=[RWButton text:@"" action:^{[weak resetBrowse];weak.filter=@"All";[weak go:@"Home"];}];
        brand.accessibilityLabel=@"Rewind home";UIImageView *symbol=[[UIImageView alloc]initWithImage:RWIcon(@"rewind",26,RWColor(0xff6847))];symbol.frame=CGRectMake(0,12,26,26);[brand addSubview:symbol];
        UILabel *wordmark=RWLabel(@"REWIND",20,UIFontWeightHeavy,RWColor(0xf5f2eb));RWTracking(wordmark,1.2);wordmark.frame=CGRectMake(36,9,118,32);[brand addSubview:wordmark];[self.sidebar addSubview:brand];self.navigationBrand=brand;
        NSArray *titles=@[@"Home",@"Movies",@"Series",@"Upcoming",@"My List"];NSMutableArray *tabs=[NSMutableArray new];
        for(NSUInteger i=0;i<titles.count;i++){NSString *title=titles[i];RWButton *button=[RWButton text:title action:^{[weak.destinationStack removeAllObjects];if(i<3){weak.filter=@[@"All",@"Movies",@"Series"][i];[weak resetBrowse];weak.homePlan=[RewindStore shared].discoveryHome;[weak go:@"Home"];}else[weak go:title];}];
            UIView *line=[[UIView alloc]initWithFrame:CGRectMake(23,48,25,2)];line.backgroundColor=RWColor(0xff6847);line.tag=7101;[button addSubview:line];[tabs addObject:button];[self.sidebar addSubview:button];
        }self.navigationTabs=tabs;
        self.navigationSearch=[RWButton text:@"" action:^{[weak.destinationStack removeAllObjects];[weak go:@"Search"];}];[self.navigationSearch icon:@"search"];self.navigationSearch.accessibilityLabel=@"Search";[self.sidebar addSubview:self.navigationSearch];
        self.navigationProfile=[RWButton text:@"" action:^{[weak profileMenu:weak.navigationProfile];}];self.navigationProfile.layer.cornerRadius=9;[self.sidebar addSubview:self.navigationProfile];
        self.navigationState=nil;
    }
    RewindStore *store=[RewindStore shared];NSString *selected=[self.page isEqual:@"Home"]?self.filter:([@[@"Upcoming",@"My List"]containsObject:self.page]?self.page:@"");
    NSDictionary *state=@{@"width":@(w),@"selected":selected?:@"",@"profile":store.state[@"activeProfile"]?:@"",@"name":RWString(store.profile[@"name"]),@"kids":@(store.restricted)};
    if(![state isEqual:self.navigationState]){
        self.navigationState=state;self.sidebar.frame=CGRectMake(0,0,w,84);self.navigationBrand.frame=CGRectMake(26,17,154,50);CGFloat start=w<900?184:226;
        NSArray *keys=@[@"All",@"Movies",@"Series",@"Upcoming",@"My List"];
        for(NSUInteger i=0;i<self.navigationTabs.count;i++){RWButton *button=self.navigationTabs[i];BOOL active=[selected isEqual:keys[i]];button.frame=CGRectMake(start+i*82,18,78,48);button.titleLabel.font=[UIFont systemFontOfSize:14 weight:active?UIFontWeightSemibold:UIFontWeightRegular];[button setTitleColor:RWColor(active?0xf5f2eb:0xa8aeb7) forState:UIControlStateNormal];[button viewWithTag:7101].hidden=!active;button.accessibilityTraits=(button.accessibilityTraits&~UIAccessibilityTraitSelected)|(active?UIAccessibilityTraitSelected:0);}
        self.navigationSearch.frame=CGRectMake(w-130,19,48,48);self.navigationProfile.frame=CGRectMake(w-74,19,48,48);self.navigationProfile.accessibilityLabel=[@"Profile, " stringByAppendingString:state[@"name"]];self.navigationProfile.backgroundColor=UIColor.clearColor;
        [[self.navigationProfile viewWithTag:9100]removeFromSuperview];UIView *face=RWProfileAvatar(self.navigationProfile.bounds,RWProfileAvatarColor(store.state[@"activeProfile"],store.state[@"profiles"]),NO);face.tag=9100;[self.navigationProfile addSubview:face];
    }
    // Refresh profile labels/selection before a detached bar becomes visible.
    if(self.sidebar.superview!=self.view)[self.view addSubview:self.sidebar];[self.view bringSubviewToFront:self.sidebar];
    [[RWUIProbe shared]work:created?@"navigation_bar_create":@"navigation_bar_reuse" started:began];
}
