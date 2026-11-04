- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout referenceSizeForFooterInSection:(NSInteger)section{// Reserve the same space for loading, retry and end states. Shrinking
    // the footer during retry clamps a bottom-scrolled list before append.
    // A Home rebind briefly clears action blocks before measuring the row.
    // The feed still owns its continuation extent during that measurement.
    return self.horizontal?((_feed||self.onLoadMore)?CGSizeMake(64,self.bounds.size.height):CGSizeZero):CGSizeMake(self.bounds.size.width,104);}
