#import "RWSubtitleLabel.h"
#import "RWSubtitleLayout.h"
@implementation RWSubtitleLabel {
    NSString *_measuredText;
    UIFont *_measuredFont;
    CGFloat _measuredWidth;
    CGSize _measuredSize;
    NSUInteger _measurements;
    BOOL _clipped;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.numberOfLines=6;self.lineBreakMode=NSLineBreakByTruncatingTail;
        self.textAlignment=NSTextAlignmentCenter;self.textColor=UIColor.whiteColor;
        self.font=[UIFont systemFontOfSize:24 weight:UIFontWeightSemibold];
        self.backgroundColor=[UIColor colorWithWhite:0 alpha:.78];
        self.layer.cornerRadius=4;self.layer.masksToBounds=YES;
        self.shadowColor=UIColor.blackColor;self.shadowOffset=CGSizeMake(0,1);
        self.userInteractionEnabled=NO;
    }return self;
}
- (void)placeIn:(CGRect)bounds picture:(CGRect)picture controls:(BOOL)controls {
    self.hidden=!self.text.length;if(self.hidden){self.frame=CGRectZero;return;}
    CGFloat width=MAX(1,bounds.size.width-96);
    if(![_measuredText isEqual:self.text]||![_measuredFont isEqual:self.font]||_measuredWidth!=width){
        _measuredText=[self.text copy];_measuredFont=self.font;_measuredWidth=width;_measurements++;
        CGRect room=CGRectMake(0,0,width,CGFLOAT_MAX);
        CGRect full=[self textRectForBounds:room limitedToNumberOfLines:0];
        CGRect capped=[self textRectForBounds:room limitedToNumberOfLines:6];
        _measuredSize=CGSizeMake(ceil(capped.size.width),ceil(capped.size.height)+2);
        _clipped=full.size.height>capped.size.height+1;
    }
    CGFloat bottom=CGRectIsEmpty(picture)||CGRectIsNull(picture)?bounds.size.height:CGRectGetMaxY(picture);
    self.frame=RWSubtitleFrame(bounds.size,_measuredSize,bottom,controls);
}
- (void)drawTextInRect:(CGRect)rect {[super drawTextInRect:UIEdgeInsetsInsetRect(rect,UIEdgeInsetsMake(6,12,6,12))];}
- (NSDictionary *)layoutDiagnostics {
    return @{@"frame":@[@(self.frame.origin.x),@(self.frame.origin.y),@(self.frame.size.width),@(self.frame.size.height)],@"text_width":@(_measuredSize.width),@"text_height":@(_measuredSize.height),@"font":@(self.font.pointSize),@"line_height":@(self.font.lineHeight),@"measurements":@(_measurements),@"line_limit":@(self.numberOfLines),@"truncated":@(!self.hidden&&(_clipped||self.bounds.size.height+0.5<_measuredSize.height+12)),@"hidden":@(self.hidden),@"background_alpha":@(.78)};
}
@end
