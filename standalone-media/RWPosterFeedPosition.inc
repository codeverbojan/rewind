- (void)applyFeedPosition {
    if(!_pendingFeedPosition||_restoringPosition||_updating||!_feed||![_pendingFeedPosition[@"context"]isEqual:_feed.context])return;
    if(self.dragging||self.decelerating){_pendingFeedPosition=nil;return;}
    NSUInteger index=[_pendingFeedPosition[@"index"]unsignedIntegerValue];
    if(index>=[self recordCount]){_pendingFeedPosition=nil;return;}
    UICollectionViewLayoutAttributes *a=[self layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
    if(!a||(self.horizontal?self.contentSize.width:self.contentSize.height)<=0)return;
    // UIKit can expose new item attributes while contentSize still describes
    // the preceding batch. Clamping against that old extent loses the anchor.
    if((self.horizontal?CGRectGetMaxX(a.frame):CGRectGetMaxY(a.frame))>(self.horizontal?self.contentSize.width:self.contentSize.height)+.5)return;
    double delta=[_pendingFeedPosition[@"delta"]doubleValue];_pendingFeedPosition=nil;_restoringPosition=YES;
    if(self.horizontal)self.contentOffset=CGPointMake(MAX(0,MIN(a.frame.origin.x+delta,MAX(0,self.contentSize.width-self.bounds.size.width))),0);
    else self.contentOffset=CGPointMake(0,MAX(0,MIN(a.frame.origin.y+delta,MAX(0,self.contentSize.height-self.bounds.size.height))));
    _restoringPosition=NO;
}
- (void)restorePositionIndex:(NSUInteger)index delta:(double)delta context:(NSString *)context {
    if(index==NSNotFound||!isfinite(delta)||!context.length||self.dragging||self.decelerating)return;
    _pendingFeedPosition=@{@"index":@(index),@"delta":@(delta),@"context":[context copy]};
    [self setNeedsLayout];[self layoutIfNeeded];[self applyFeedPosition];
}
