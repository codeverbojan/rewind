#import "RWArtworkPolicy.h"
#import "RWHomePresentation.h"
#import "RewindUI.h"
#import "RWUIProbe.h"

UIColor *RWColor(unsigned int rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255. green:((rgb >> 8) & 255) / 255. blue:(rgb & 255) / 255. alpha:1];
}
UIColor *RWLogoBackdrop(UIImage *image) {
    // Inspect a tiny alpha-weighted sample of the decoded logo. Transparent
    // black lettering needs a light mat; white lettering keeps a dark one.
    if(!image.CGImage)return RWColor(0x191c21);
    unsigned char pixels[16*16*4]={0};CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef c=CGBitmapContextCreate(pixels,16,16,8,64,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);CGColorSpaceRelease(space);
    if(!c)return RWColor(0x191c21);CGContextDrawImage(c,CGRectMake(0,0,16,16),image.CGImage);CGContextRelease(c);
    double ink=0,alpha=0;for(int i=0;i<256;i++){unsigned char *p=pixels+4*i;if(p[3]<8)continue;ink+=.2126*p[0]+.7152*p[1]+.0722*p[2];alpha+=p[3];}
    return RWColor(alpha>0&&ink/alpha<.55?0xe9e8e4:0x191c21);
}
UILabel *RWLabel(NSString *text, CGFloat size, CGFloat weight, UIColor *color) {
    UILabel *label = [UILabel new]; label.text = text;
    label.font = [UIFont systemFontOfSize:size weight:weight]; label.textColor = color;
    label.numberOfLines = 1; return label;
}
void RWTracking(UILabel *label, CGFloat spacing) {
    label.attributedText = [[NSAttributedString alloc] initWithString:label.text ?: @"" attributes:@{NSKernAttributeName:@(spacing)}];
}
UIImage *RWIcon(NSString *name, CGFloat size, UIColor *color) {
    static NSCache *cache; static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; cache.countLimit = 80; });
    NSString *key = [NSString stringWithFormat:@"%@-%g-%@", name, size, color];
    UIImage *image = [cache objectForKey:key]; if (image) return image;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
    CGContextRef c = UIGraphicsGetCurrentContext(); CGContextScaleCTM(c, size / 24., size / 24.);
    CGContextSetStrokeColorWithColor(c, color.CGColor); CGContextSetFillColorWithColor(c, color.CGColor);
    CGContextSetLineWidth(c, 2); CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
    #include "RewindIconPaths.inc"
    if ([name isEqual:@"play"] || [name isEqual:@"rewind"] || [name isEqual:@"pause"]) CGContextDrawPath(c, kCGPathFillStroke);
    else CGContextStrokePath(c);
    image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
    if (image) [cache setObject:image forKey:key]; return image;
}
UIView *RWPanel(CGRect frame) {
    UIView *panel = [[UIView alloc] initWithFrame:frame]; panel.backgroundColor = RWColor(0x191c21);
    panel.layer.cornerRadius = 12; panel.layer.borderColor = RWColor(0x2a2d32).CGColor; panel.layer.borderWidth = .5;
    return panel;
}
void RWShade(UIView *view, BOOL horizontal) {
    CAGradientLayer *g = [CAGradientLayer layer]; g.frame = view.bounds;
    g.colors = @[(id)[UIColor colorWithRed:.035 green:.043 blue:.055 alpha:.98].CGColor,
                 (id)[UIColor colorWithRed:.035 green:.043 blue:.055 alpha:horizontal?.78:.15].CGColor,
                 (id)[UIColor colorWithRed:.035 green:.043 blue:.055 alpha:horizontal?.05:.92].CGColor];
    g.locations = @[@0, @.48, @1];
    g.startPoint = horizontal ? CGPointMake(0,.5) : CGPointMake(.5,0);
    g.endPoint = horizontal ? CGPointMake(1,.5) : CGPointMake(.5,1);
    [view.layer addSublayer:g];
}
@implementation RWTextTabs {
    NSArray *_buttons; UIView *_indicator;
}
- (instancetype)initWithItems:(NSArray *)items {
    if((self=[super initWithFrame:CGRectZero])){
        NSMutableArray *buttons=[NSMutableArray new];
        for(NSString *title in items){UIButton *button=[UIButton buttonWithType:UIButtonTypeCustom];[button setTitle:title forState:UIControlStateNormal];button.tag=buttons.count;button.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];[button setTitleColor:RWColor(0x929aa6) forState:UIControlStateNormal];[button setTitleColor:RWColor(0xf5f2eb) forState:UIControlStateSelected];[button addTarget:self action:@selector(choose:) forControlEvents:UIControlEventTouchUpInside];[self addSubview:button];[buttons addObject:button];}
        _buttons=buttons;_indicator=[UIView new];_indicator.backgroundColor=RWColor(0xf5f2eb);_indicator.userInteractionEnabled=NO;[self addSubview:_indicator];self.selectedSegmentIndex=0;
    }return self;
}
- (void)setSelectedSegmentIndex:(NSInteger)index {
    if(index<0||index>=(NSInteger)_buttons.count)return;_selectedSegmentIndex=index;
    for(UIButton *button in _buttons){button.selected=button.tag==index;button.accessibilityTraits=UIAccessibilityTraitButton|(button.selected?UIAccessibilityTraitSelected:0);}
    self.accessibilityValue=[_buttons[index] currentTitle];[self setNeedsLayout];
}
- (void)choose:(UIButton *)button {if(button.tag==_selectedSegmentIndex)return;self.selectedSegmentIndex=button.tag;[self sendActionsForControlEvents:UIControlEventValueChanged];}
- (void)layoutSubviews {
    [super layoutSubviews];if(!_buttons.count)return;CGFloat cell=self.bounds.size.width/_buttons.count,height=self.bounds.size.height;
    for(UIButton *button in _buttons)button.frame=CGRectMake(cell*button.tag,0,cell,height);
    UIButton *selected=_buttons[_selectedSegmentIndex];CGFloat width=MIN(cell-24,MAX(24,[selected.titleLabel sizeThatFits:CGSizeMake(cell,height)].width));
    _indicator.frame=CGRectMake(cell*_selectedSegmentIndex+(cell-width)/2,height-3,width,2);
}
@end
@implementation RWButton
+ (instancetype)text:(NSString *)text action:(void(^)(void))action {
    RWButton *b = [self buttonWithType:UIButtonTypeCustom];
    [b setTitle:text forState:UIControlStateNormal]; b.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [b setTitleColor:RWColor(0xf5f2eb) forState:UIControlStateNormal];
    b.action = action; b.layer.cornerRadius = 8; b.adjustsImageWhenHighlighted = NO;
    b.accessibilityLabel = text; [b addTarget:b action:@selector(fire) forControlEvents:UIControlEventTouchUpInside]; return b;
}
- (void)appearance:(BOOL)primary {
    self.backgroundColor = RWColor(primary ? 0xf4f1e9 : 0x25282e);
    [self setTitleColor:RWColor(primary ? 0x111318 : 0xf5f2eb) forState:UIControlStateNormal];
    self.layer.borderWidth = primary ? 0 : .5; self.layer.borderColor = RWColor(0x4a4d52).CGColor;
}
- (void)icon:(NSString *)name {
    [self setImage:RWIcon(name, 20, [self titleColorForState:UIControlStateNormal]) forState:UIControlStateNormal]; [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews]; if (!self.currentImage) return;
    CGFloat h = self.bounds.size.height, w = self.bounds.size.width;
    CGFloat textWidth = MIN(MAX(0,w-54), [self.titleLabel sizeThatFits:CGSizeMake(1000,h)].width);
    if (!self.currentTitle.length) textWidth = 0;
    CGFloat iconSize = self.currentImage.size.width, total = iconSize + (textWidth ? textWidth + 9 : 0);
    self.imageView.frame = CGRectMake(round((w-total)/2), round((h-iconSize)/2), iconSize, iconSize);
    self.titleLabel.frame = CGRectMake(CGRectGetMaxX(self.imageView.frame)+9, 0, textWidth, h);
}
- (void)fire { if (self.action) self.action(); }
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; self.alpha = highlighted ? .62 : 1; }
@end
@implementation RWGradient
+ (Class)layerClass { return CAGradientLayer.class; }
- (instancetype)init {
    if ((self = [super init])) {
        self.userInteractionEnabled = NO; CAGradientLayer *g = (CAGradientLayer *)self.layer;
        g.colors = @[(id)[UIColor clearColor].CGColor, (id)[UIColor colorWithWhite:.045 alpha:.25].CGColor, (id)RWColor(0x0e1116).CGColor];
        g.locations = @[@0, @.5, @1];
    } return self;
}
@end
@implementation RWPoster {
    UIImageView *_art,*_fallbackIcon;NSArray *_artURLs;BOOL _artRequested,_artScheduled,_artComplete;NSUInteger _artAttempts,_artGeneration;double _retryAfter;BOOL _landscape,_contentsBuilt;
    UIView *_base,*_resumeShade,*_progressTrack,*_progress;UIImageView *_resumePlay;
    UILabel *_placeholder,*_title,*_detail,*_rating,*_kind;
}
- (instancetype)initWithMeta:(NSDictionary *)meta width:(CGFloat)width landscape:(BOOL)landscape {
    CGFloat imageHeight=landscape?width*.5625:width*1.45;
    if((self=[super initWithFrame:CGRectMake(0,0,width,imageHeight+51)])){
        self.meta=meta;self.accessibilityLabel=RWString(meta[@"name"]);self.accessibilityTraits=UIAccessibilityTraitButton;_landscape=landscape;
        [self addTarget:self action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    }return self;
}
- (void)prepareContents {
    if(_contentsBuilt)return;_contentsBuilt=YES;CGFloat width=self.bounds.size.width,height=_landscape?width*.5625:width*1.45;
    _base=RWPanel(CGRectMake(0,0,width,height));_base.clipsToBounds=YES;_base.userInteractionEnabled=NO;[self addSubview:_base];
    _fallbackIcon=[[UIImageView alloc]initWithImage:RWIcon(@"film",28,RWColor(0x727982))];_fallbackIcon.frame=CGRectMake(16,18,28,28);_fallbackIcon.hidden=YES;[_base addSubview:_fallbackIcon];
    _placeholder=RWLabel(@"",17,UIFontWeightSemibold,RWColor(0xbac0c7));_placeholder.numberOfLines=3;_placeholder.frame=CGRectMake(16,height/2-20,width-32,74);_placeholder.hidden=YES;[_base addSubview:_placeholder];
    _art=[[UIImageView alloc]initWithFrame:_base.bounds];_art.contentMode=UIViewContentModeScaleAspectFill;_art.clipsToBounds=YES;[_base addSubview:_art];
    _title=RWLabel(@"",14,UIFontWeightSemibold,RWColor(0xf4f1eb));_title.frame=CGRectMake(0,height+10,width,18);[self addSubview:_title];
    _detail=RWLabel(@"",12,UIFontWeightRegular,RWColor(0xa0a5ad));_detail.frame=CGRectMake(0,height+32,width,16);[self addSubview:_detail];
    [self updateMeta:self.meta];
}
- (BOOL)contentsPrepared {return _contentsBuilt;}
- (NSDictionary *)artworkState {return @{@"loaded":@(_artComplete&&_art.image!=nil),@"requested":@(_artRequested),@"attempts":@(_artAttempts),@"width":@(_art.image.size.width),@"height":@(_art.image.size.height)};}
- (BOOL)prepareVisibleContents {
    if(_contentsBuilt||![self artworkVisible])return NO;
    double began=NSProcessInfo.processInfo.systemUptime;[self prepareContents];
    [[RWUIProbe shared]work:@"poster_content_create" started:began];return YES;
}
#include "RWPosterContent.inc"
- (void)didMoveToWindow {[super didMoveToWindow];if(!self.window){[self cancelArtwork];_art.image=nil;_artComplete=NO;}}
- (void)tapped { if (self.action) self.action(self.meta); }
- (BOOL)artworkVisible {
    if(!self.window||self.hidden||self.alpha<=0)return NO;
    CGRect visible=[self convertRect:self.bounds toView:self.window];
    for(UIView *parent=self.superview;parent;parent=parent.superview){if(parent.hidden||parent.alpha<=0)return NO;if(parent.clipsToBounds||parent==self.window){visible=CGRectIntersection(visible,[parent convertRect:parent.bounds toView:self.window]);if(CGRectIsNull(visible)||CGRectIsEmpty(visible))return NO;}}
    return YES;
}
- (BOOL)artworkMoving {for(UIView *parent=self.superview;parent;parent=parent.superview)if([parent isKindOfClass:UIScrollView.class]){UIScrollView *scroll=(UIScrollView *)parent;if(scroll.tracking||scroll.dragging||scroll.decelerating)return YES;}return NO;}
#include "RWPosterArtwork.inc"
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; self.alpha = highlighted ? .65 : 1; }
@end
void RWAlert(UIViewController *controller, NSString *title, NSString *message) {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]]; [controller presentViewController:a animated:YES completion:nil];
}
void RWCapture(UIView *view, NSString *name) {
    if (!view.window || view.bounds.size.width < 1) return;
    UIGraphicsBeginImageContextWithOptions(view.bounds.size,YES,1); [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    UIImage *im = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
    NSString *folder = [RWDocuments() stringByAppendingPathComponent:@"RewindDiagnostics"];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    [UIImagePNGRepresentation(im) writeToFile:[folder stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]] atomically:YES];
}
