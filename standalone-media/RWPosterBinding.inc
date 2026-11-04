// Shared with the host ownership harness; UIKit behavior still needs device proof.
- (void)configure:(NSDictionary *)meta width:(CGFloat)width landscape:(BOOL)landscape action:(void(^)(NSDictionary *))action {
    double began=NSProcessInfo.processInfo.systemUptime;BOOL rebuilt=NO,updated=NO;
    BOOL entity=[@[@"person",@"studio",@"mood"]containsObject:meta[@"type"]?:@""];
    NSDictionary *display=entity?meta:meta[@"availability"]?meta:[[RewindStore shared]discoveryMeta:meta];
    NSDictionary *presentation=entity?display:[RWHomePresentation posterContent:display];
    BOOL changed=![self.presentation isEqual:presentation];
    if(!self.poster||entity!=[self.poster isKindOfClass:RWEntityCard.class]||(entity&&changed)||self.landscape!=landscape||fabs(self.poster.bounds.size.width-width)>.5){
        rebuilt=YES;
        [self.poster removeFromSuperview];self.presentation=presentation;self.landscape=landscape;
        self.poster=entity?[[RWEntityCard alloc]initWithMeta:display width:width landscape:NO]:[[RWPoster alloc]initWithMeta:display width:width landscape:landscape];self.poster.defersContents=self.defersContents&&!entity;[self.contentView addSubview:self.poster];
    }else if(changed){[self.poster updateMeta:display];self.presentation=presentation;updated=YES;}
    // Keep selection and permissions current even when no pixel changed.
    self.record=meta;self.poster.meta=display;self.poster.action=action;self.poster.defersContents=self.defersContents&&!entity;self.poster.frame=CGRectMake(0,0,width,[self.poster isKindOfClass:RWEntityCard.class]?width+141:(landscape?width*.5625:width*1.45)+51);[self.poster loadArtworkIfVisible];
    [[RWUIProbe shared]work:rebuilt?@"poster_rebuild":updated?@"poster_update":@"poster_rebind" started:began];
}
