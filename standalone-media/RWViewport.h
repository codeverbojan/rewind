#import <Foundation/Foundation.h>
// Metadata window around actual visible cards: one neighbor each side for
// rails, one visible screen each side for grids, with an absolute 72 cap.
NSRange RWFeedVisibleRange(NSUInteger total,NSUInteger first,NSUInteger last,BOOL horizontal);
// Fixed-height rows intersecting a viewport, plus a small reuse margin.
NSRange RWVisibleRows(NSUInteger total, double rowHeight, double top, double height, NSUInteger margin);
// Preserve the poster aspect ratio and 51-point caption inside a horizontal rail.
double RWPosterRailWidth(double height, BOOL landscape);
