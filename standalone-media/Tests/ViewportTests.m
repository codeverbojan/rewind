#import <Foundation/Foundation.h>
#import "../RWViewport.h"
#include <math.h>
int main(){@autoreleasepool{
    __block int checks=0,failures=0;void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *label){checks++;if(!ok){failures++;fprintf(stderr,"FAIL %s\n",label.UTF8String);}};
    check(!RWVisibleRows(30,162,-800,700,1).length,@"Season below the viewport creates no episode cards");
    NSRange r=RWVisibleRows(30,162,-100,500,1);check(r.location==0&&r.length==4,@"Partly visible first rows include only one extra row");
    r=RWVisibleRows(30,162,1620,648,1);check(r.location==9&&r.length==6,@"Middle viewport retains the previous and next row only");
    r=RWVisibleRows(30,162,29*162,700,1);check(r.location==28&&r.length==2,@"Bottom overscroll cannot create rows past the season");
    check(!RWVisibleRows(30,162,30*162,700,1).length,@"Fully offscreen season releases all active cells");
    check(!RWVisibleRows(0,162,0,700,1).length&&!RWVisibleRows(30,0,0,700,1).length,@"Empty data and invalid row height are safe");
    check(!RWVisibleRows(30,162,NAN,700,1).length&&!RWVisibleRows(30,162,0,INFINITY,1).length,@"Invalid layout dimensions cannot request an unbounded window");
    check(RWVisibleRows(1000000,162,500000*162,940,1).length<=9,@"A million-row season has the same bounded portrait window");
    r=RWVisibleRows(30,162,162,162,0);check(r.location==1&&r.length==1,@"Rows touching but not intersecting the viewport do not request thumbnails");
    BOOL cover=YES,bounded=YES;for(NSUInteger row=0;row<10000;row++){NSRange v=RWVisibleRows(10000,162,row*162,940,1);if(!NSLocationInRange(row,v))cover=NO;if(v.length>9)bounded=NO;}
    check(cover,@"Every episode remains reachable across a long season");check(bounded,@"Scrolling never turns a long season into thousands of live cards");
    for(NSNumber *height in @[@150,@210,@270,@300])for(NSNumber *landscape in @[@YES,@NO]){double w=RWPosterRailWidth(height.doubleValue,landscape.boolValue);double h=w*(landscape.boolValue?.5625:1.45)+51;check(h<height.doubleValue,@"Horizontal poster and caption fit the actual rail height");}
    check(RWPosterRailWidth(270,NO)==148&&RWPosterRailWidth(210,YES)==264,@"Regular rails preserve intended card sizes");
    r=RWFeedVisibleRange(10000,10,14,YES);check(r.location==9&&r.length==7,@"Horizontal rail reads visible metadata and one neighbor each side");
    r=RWFeedVisibleRange(10000,40,51,NO);check(r.location==28&&r.length==36,@"Grid reads one visible screen ahead and behind, not120 records");
    r=RWFeedVisibleRange(8,5,7,YES);check(r.location==4&&r.length==4,@"End of rail never reads beyond available records");
    check(!RWFeedVisibleRange(0,0,0,NO).length&&!RWFeedVisibleRange(10,10,10,YES).length&&!RWFeedVisibleRange(10,5,2,YES).length,@"Empty and invalid visible windows do no work");
    check(RWFeedVisibleRange(NSUIntegerMax,NSUIntegerMax-3,NSUIntegerMax-1,YES).length==4,@"Large offsets cannot overflow the metadata window");
    BOOL feedBounded=YES;for(NSUInteger i=0;i<10000;i++)for(int horizontal=0;horizontal<2;horizontal++){NSRange range=RWFeedVisibleRange(10000,i,MIN((NSUInteger)9999,i+11),horizontal);if(range.length>72||!NSLocationInRange(i,range)||NSMaxRange(range)>10000)feedBounded=NO;}check(feedBounded,@"Long feeds remain bounded and always contain the first visible card");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
