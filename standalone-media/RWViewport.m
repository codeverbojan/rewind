#import "RWViewport.h"
#include <math.h>
NSRange RWFeedVisibleRange(NSUInteger total,NSUInteger first,NSUInteger last,BOOL horizontal) {
    if(!total||first>=total||last<first)return NSMakeRange(0,0);
    last=MIN(last,total-1);NSUInteger count=MIN((NSUInteger)24,last-first+1),margin=horizontal?1:count;
    NSUInteger start=first>margin?first-margin:0;
    NSUInteger length=MIN(total-start,MIN((NSUInteger)72,(first-start)+count+margin));
    return NSMakeRange(start,length);
}
double RWPosterRailWidth(double height,BOOL landscape) {
    double maximum=landscape?264:148,aspect=landscape?.5625:1.45;
    return isfinite(height)&&height>52?floor(MIN(maximum,(height-52)/aspect)):1;
}
NSRange RWVisibleRows(NSUInteger total,double rowHeight,double top,double height,NSUInteger margin) {
    if(!total||!isfinite(rowHeight)||rowHeight<=0||!isfinite(top)||!isfinite(height)||height<=0)return NSMakeRange(0,0);
    double end=top+height,extent=(double)total*rowHeight;
    if(!isfinite(end)||end<=0||top>=extent)return NSMakeRange(0,0);
    NSUInteger first=(NSUInteger)floor(MAX(0,top)/rowHeight);
    NSUInteger last=(NSUInteger)ceil(MIN(extent,end)/rowHeight);
    first=first>margin?first-margin:0;last=MIN(total,last+MIN(margin,total-last));
    return NSMakeRange(first,last-first);
}
