// Crisp vector pieces assemble into a Rewind mark or a playful flower, then
// expand and fly past the viewer. Shared timeline also drives the host preview.
- (void)prepareSelectionBackground {
    if(self.lastReducedMotion)return;
    UIView *back=self.transitionBackdrop;back.clipsToBounds=YES;
    NSDictionary *plan=RWProfileMotionPlan(back.bounds.size.width,back.bounds.size.height,self.selectedKids);
    double duration=[plan[@"duration"]doubleValue],begin=CACurrentMediaTime();self.backgroundStarted=NSProcessInfo.processInfo.systemUptime;
    NSMutableArray *pieces=[NSMutableArray new];
    for(NSDictionary *record in plan[@"layers"]){
        CAShapeLayer *piece=[CAShapeLayer layer];UIBezierPath *path=[UIBezierPath bezierPath];BOOL first=YES;
        for(NSArray *point in record[@"path"]){CGPoint p=CGPointMake([point[0]doubleValue],[point[1]doubleValue]);if(first){[path moveToPoint:p];first=NO;}else[path addLineToPoint:p];}[path closePath];
        piece.path=path.CGPath;piece.fillColor=RWColor([record[@"color"]unsignedIntValue]).CGColor;piece.contentsScale=UIScreen.mainScreen.scale;piece.opacity=0;
        [back.layer addSublayer:piece];[pieces addObject:piece];
        NSMutableArray *times=[NSMutableArray new],*positions=[NSMutableArray new],*xs=[NSMutableArray new],*ys=[NSMutableArray new],*rotations=[NSMutableArray new],*opacities=[NSMutableArray new],*easing=[NSMutableArray new];
        for(NSArray *frame in record[@"frames"]){[times addObject:@([frame[0]doubleValue]/duration)];[positions addObject:[NSValue valueWithCGPoint:CGPointMake([frame[1]doubleValue],[frame[2]doubleValue])]];[xs addObject:frame[3]];[ys addObject:frame[4]];[rotations addObject:frame[5]];[opacities addObject:frame[6]];}
        for(NSUInteger i=1;i<times.count;i++)[easing addObject:i==times.count-1?[CAMediaTimingFunction functionWithControlPoints:.70 :0 :1 :1]:[CAMediaTimingFunction functionWithControlPoints:.22 :.70 :.30 :1]];
        NSArray *keys=@[@"position",@"transform.scale.x",@"transform.scale.y",@"transform.rotation.z",@"opacity"],*values=@[positions,xs,ys,rotations,opacities];
        for(NSUInteger i=0;i<keys.count;i++){CAKeyframeAnimation *animation=[CAKeyframeAnimation animationWithKeyPath:keys[i]];animation.values=values[i];animation.keyTimes=times;animation.timingFunctions=easing;animation.duration=duration;animation.beginTime=begin;animation.fillMode=kCAFillModeBackwards;[piece addAnimation:animation forKey:keys[i]];}
    }
    self.backgroundRibbons=pieces;
}
- (void)openSelectionBackground:(double)duration {
    // The opaque base fades while each independent shape keeps flying past.
    // There is no centre seam, two-panel mask, screenshot or gradient curtain.
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionAllowUserInteraction animations:^{self.transitionBackdrop.backgroundColor=UIColor.clearColor;} completion:nil];
}
