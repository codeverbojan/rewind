// One-shot, opt-in UI review. Runs only when a request file exists in this app's
// Documents folder. Renders real UIKit views off screen, without tapping controls,
// starting playback, modifying the library, or capturing anything outside Rewind.
- (void)beginLayoutReview {
    NSString *request=[RWDocuments() stringByAppendingPathComponent:@"rewind-review.request"];
    if (self.reviewMode || ![[NSFileManager defaultManager] fileExistsAtPath:request]) return;
    NSData *requestData=[NSData dataWithContentsOfFile:request];id options=requestData.length?[NSJSONSerialization JSONObjectWithData:requestData options:0 error:nil]:nil;
    [[NSFileManager defaultManager] removeItemAtPath:request error:nil];
    self.reviewCases=[@[
        @{@"page":@"Loading",@"width":@1024,@"height":@768},
        @{@"page":@"Loading",@"width":@768,@"height":@1024},
        @{@"page":@"Home",@"width":@768,@"height":@1024},
        @{@"page":@"Home",@"width":@1024,@"height":@768},
        @{@"page":@"Details",@"width":@768,@"height":@1024},
        @{@"page":@"Details",@"width":@1024,@"height":@768},
        @{@"page":@"Details",@"filter":@"Series",@"width":@768,@"height":@1024},
        @{@"page":@"Details",@"filter":@"Series",@"width":@1024,@"height":@768},
        @{@"page":@"Details",@"filter":@"Episodes",@"width":@768,@"height":@1024,@"offset":@570},
        @{@"page":@"Details",@"filter":@"About",@"width":@1024,@"height":@768,@"offset":@555},
        @{@"page":@"Details",@"filter":@"Cast",@"width":@768,@"height":@1024,@"offset":@500},
        @{@"page":@"Home",@"filter":@"Filters",@"width":@768,@"height":@1024},
        @{@"page":@"Search",@"width":@768,@"height":@1024},
        @{@"page":@"My List",@"width":@768,@"height":@1024},
        @{@"page":@"Downloads",@"width":@768,@"height":@1024},
        @{@"page":@"Settings",@"width":@1024,@"height":@768},
        @{@"page":@"Profiles",@"width":@768,@"height":@1024},
        @{@"page":@"Profiles",@"width":@1024,@"height":@768},
        @{@"page":@"Home",@"filter":@"Series",@"width":@1024,@"height":@768}
    ] mutableCopy];
    if([options isKindOfClass:NSDictionary.class]&&[options[@"cases"]isKindOfClass:NSArray.class]){NSMutableArray *selected=[NSMutableArray new];for(id test in options[@"cases"]){if(![test isKindOfClass:NSDictionary.class]||![@[@"Home",@"Search",@"Profiles",@"Details",@"Upcoming",@"Entity",@"Explore",@"Preferences",@"Downloads"]containsObject:test[@"page"]])continue;NSInteger w=[test[@"width"]integerValue],h=[test[@"height"]integerValue];if(!((w==768&&h==1024)||(w==1024&&h==768)))continue;[selected addObject:test];if(selected.count==12)break;}if(selected.count)self.reviewCases=selected;}
    self.reviewResults=[NSMutableArray new]; [self reviewNextLayout];
}
- (void)reviewNextLayout {
    if (!self.reviewCases.count) {
        NSData *data=[NSJSONSerialization dataWithJSONObject:self.reviewResults options:NSJSONWritingPrettyPrinted error:nil];
        [data writeToFile:[RWDocuments() stringByAppendingPathComponent:@"RewindDiagnostics/layout-review.json"] atomically:YES];
        self.reviewController=nil; [[RewindStore shared] report:@{@"layout_review_complete":@YES,@"screen":self.page}]; return;
    }
    NSDictionary *test=self.reviewCases.firstObject; [self.reviewCases removeObjectAtIndex:0];
    RewindController *review=[RewindController new]; review.reviewMode=YES; self.reviewController=review;
    CGFloat w=[test[@"width"] doubleValue],h=[test[@"height"] doubleValue];
    review.view.frame=CGRectMake(self.view.bounds.size.width+64,0,w,h); review.page=test[@"page"]; review.filter=test[@"filter"]?:@"All";
    NSData *movieData=[NSData dataWithContentsOfFile:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Rewind/review-movie.json"]];review.detail=[NSJSONSerialization JSONObjectWithData:movieData options:0 error:nil][@"meta"]?:[RewindStore shared].openFilms.firstObject;if([@[@"Series",@"Episodes",@"About"]containsObject:test[@"filter"]?:@""]){NSData *data=[NSData dataWithContentsOfFile:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Rewind/review-series.json"]];review.detail=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil][@"meta"];} review.season=1;if([review.filter isEqual:@"About"])review.detailTab=@"About";if([review.filter isEqual:@"Filters"]){review.browseSort=@"Newest";review.browseResults=[RewindStore shared].freshMovies;} review.laidOutSize=CGSizeMake(w,h);
    review.upcomingMode=test[@"mode"]?:@"Coming soon";review.exploreKind=test[@"kind"]?:@"Moods";review.exploreMood=test[@"mood"];review.exploreType=@"Films";
    if([review.page isEqual:@"Entity"]){review.entity=@{@"id":@"Q25191",@"name":@"Christopher Nolan",@"creditRole":@"director"};review.entityType=@"All";review.entitySort=@"Year";review.entityItems=[review localEntityCredits:review.entity];}
    review.homePlan=[RewindStore shared].discoveryHome;
    [self.view addSubview:review.view]; [review render];if([review.page isEqual:@"Explore"])[review fetchExplore]; [review.view layoutIfNeeded];if(test[@"offset"])review.content.contentOffset=CGPointMake(0,[test[@"offset"]doubleValue]);
    if([test[@"page"]isEqual:@"Loading"]){for(UIView *v in [review.view.subviews copy])[v removeFromSuperview];RewindPlayer *player=[[RewindPlayer alloc]initWithMeta:review.detail videoID:@"review:preview" source:@{} resume:0];player.reviewOnly=YES;[review addChildViewController:player];player.view.frame=review.view.bounds;[review.view addSubview:player.view];[player.view layoutIfNeeded];}
    __weak RewindController *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.8*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        RewindController *root=weak; if (!root) return;
        NSString *name=[NSString stringWithFormat:@"Review-%@-%@-%@",test[@"page"],review.filter,w>800?@"landscape":@"portrait"];
        @autoreleasepool {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(w,h),YES,1);
            [review.view.layer renderInContext:UIGraphicsGetCurrentContext()]; UIImage *image=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
            NSString *folder=[RWDocuments() stringByAppendingPathComponent:@"RewindDiagnostics"];
            [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
            [UIImagePNGRepresentation(image) writeToFile:[folder stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]] atomically:YES];
        }
        NSMutableArray *small=[NSMutableArray new],*queue=[NSMutableArray arrayWithObject:review.view]; NSUInteger controls=0;
        while (queue.count) {
            UIView *v=queue.lastObject; [queue removeLastObject];
            if ([v isKindOfClass:RWButton.class]) { controls++; if(v.bounds.size.width<44||v.bounds.size.height<44) [small addObject:v.accessibilityLabel?:@"Unlabelled control"]; }
            [queue addObjectsFromArray:v.subviews];
        }
        [root.reviewResults addObject:@{@"screen":name,@"width":@(w),@"height":@(h),@"buttons":@(controls),@"undersized_buttons":small,@"explore_records":@(review.exploreFeed.count),@"explore_loading":@(review.exploreBusy)}];
        [review.view removeFromSuperview]; root.reviewController=nil;
        [root performSelector:@selector(reviewNextLayout) withObject:nil afterDelay:.2];
    });
}
