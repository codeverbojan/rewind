- (void)saveAnchorForShelf:(RWHomeShelf *)cell {
    // Use the cell's bound identity, not a table index that may now belong to
    // another row. Reused or old-profile cells cannot overwrite that row.
    if(![cell isKindOfClass:RWHomeShelf.class]||!self.onAnchor||!cell.rowIdentifier.length||!cell.rail.feed)return;
    if(![cell.identity isEqual:[self key:@{@"id":cell.rowIdentifier}]]||![cell.feedContext isEqual:cell.rail.feed.context])return;
    NSDictionary *anchor=[cell.rail positionAnchor];
    if(anchor.count)self.onAnchor(cell.rowIdentifier,anchor);
}
- (void)tableView:(UITableView *)table didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)path {
    if([cell isKindOfClass:RWHomeShelf.class]){
        [self saveAnchorForShelf:(RWHomeShelf *)cell];
        [((RWHomeShelf *)cell).rail cancelVisibleArtwork];
    }
}
