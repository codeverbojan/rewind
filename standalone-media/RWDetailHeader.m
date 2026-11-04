#import "RWDetailHeader.h"
#import "RWDetailPresentation.h"
#import "RWArtworkPolicy.h"
#import "RewindUI.h"
static CGRect DFrame(NSArray *v){return CGRectMake([v[0]doubleValue],[v[1]doubleValue],[v[2]doubleValue],[v[3]doubleValue]);}
@implementation RWDetailHeader {
    UIImageView *_art;UILabel *_kind,*_name,*_facts,*_rating,*_genres;CAGradientLayer *_edge,*_bottom;NSArray *_urls;NSDictionary *_layout;NSString *_imageBinding,*_instance,*_identity;NSUInteger _updates,_imageLoads;
}
- (instancetype)initWithScope:(NSString *)scope {
    if((self=[super initWithFrame:CGRectZero])){_scope=[scope copy];_instance=NSUUID.UUID.UUIDString;self.backgroundColor=RWColor(0x0e1116);self.clipsToBounds=YES;
        _stage=[UIView new];_stage.clipsToBounds=YES;_stage.backgroundColor=self.backgroundColor;[self addSubview:_stage];_art=[UIImageView new];_art.clipsToBounds=YES;[_stage addSubview:_art];
        _overlay=[UIView new];_overlay.userInteractionEnabled=NO;[_stage addSubview:_overlay];_edge=[CAGradientLayer layer];_edge.colors=@[(id)self.backgroundColor.CGColor,(id)[self.backgroundColor colorWithAlphaComponent:0].CGColor];_edge.startPoint=CGPointMake(0,.5);_edge.endPoint=CGPointMake(1,.5);[_overlay.layer addSublayer:_edge];
        _bottom=[CAGradientLayer layer];_bottom.colors=@[(id)[self.backgroundColor colorWithAlphaComponent:0].CGColor,(id)self.backgroundColor.CGColor];[_overlay.layer addSublayer:_bottom];
        _kind=RWLabel(@"",12,UIFontWeightSemibold,RWColor(0xa6b3c1));_name=RWLabel(@"",36,UIFontWeightBold,RWColor(0xf8f5ef));_name.numberOfLines=3;_name.adjustsFontSizeToFitWidth=YES;_name.minimumScaleFactor=.8;
        _facts=RWLabel(@"",13,UIFontWeightMedium,RWColor(0xb7c0cb));_facts.numberOfLines=2;
        _rating=RWLabel(@"",12,UIFontWeightSemibold,RWColor(0xf3e6bb));_rating.backgroundColor=RWColor(0x292720);_rating.textAlignment=NSTextAlignmentCenter;_rating.layer.cornerRadius=5;_rating.clipsToBounds=YES;
        _genres=RWLabel(@"",12,UIFontWeightRegular,RWColor(0x8e9baa));for(UILabel *label in @[_kind,_name,_facts,_rating,_genres])[self addSubview:label];
    }return self;
}
- (void)updateMeta:(NSDictionary *)meta rating:(NSDictionary *)rating width:(CGFloat)width {
    _updates++;_identity=RWID(meta);_layout=[RWDetailPresentation layoutForWidth:width];NSDictionary *text=[RWDetailPresentation textForMeta:meta rating:rating];BOOL wide=[_layout[@"wide"]boolValue];
    _kind.text=text[@"kind"];_name.text=text[@"title"];_facts.text=text[@"facts"];_rating.text=text[@"rating"];_rating.hidden=!_rating.text.length;_genres.text=text[@"genres"];
    _name.font=[UIFont systemFontOfSize:wide?36:34 weight:UIFontWeightBold];_name.numberOfLines=wide?3:2;
    self.frame=CGRectMake(0,52,width,[_layout[@"height"]doubleValue]);_stage.frame=DFrame(_layout[@"media"]);_art.frame=_stage.bounds;_overlay.frame=_stage.bounds;
    _kind.frame=DFrame(_layout[@"kind"]);_name.frame=DFrame(_layout[@"title"]);_facts.frame=DFrame(_layout[@"facts"]);_rating.frame=DFrame(_layout[@"rating"]);_genres.frame=DFrame(_layout[@"genres"]);
    [CATransaction begin];[CATransaction setDisableActions:YES];_edge.hidden=!wide;_edge.frame=CGRectMake(0,0,MIN(180,_stage.bounds.size.width*.3),_stage.bounds.size.height);_bottom.frame=CGRectMake(0,MAX(0,_stage.bounds.size.height-104),_stage.bounds.size.width,104);[CATransaction commit];
    NSArray *urls=[RWArtworkPolicy URLsForMeta:meta landscape:YES];NSString *key=[NSString stringWithFormat:@"%@|%@|%.0fx%.0f",RWID(meta),[urls componentsJoinedByString:@"\n"],_art.bounds.size.width,_art.bounds.size.height];
    if(![_imageBinding isEqual:key]){_imageBinding=key;_urls=urls;_imageLoads++;[[RewindStore shared]artwork:urls role:@"hero" identity:RWID(meta) into:_art completion:nil];}
    self.accessibilityIdentifier=[@"detail-header:" stringByAppendingString:_scope];
}
- (NSDictionary *)diagnostics {return @{@"identity":_identity?:@"",@"scope":_scope,@"image_present":@(_art.image!=nil),@"bitmap_width":@(_art.image.CGImage?CGImageGetWidth(_art.image.CGImage):0),@"bitmap_height":@(_art.image.CGImage?CGImageGetHeight(_art.image.CGImage):0),@"image_mode":@(_art.contentMode),@"image_scale":@(_art.image.scale),@"instance":_instance,@"updates":@(_updates),@"image_requests":@(_imageLoads),@"media_width":@(_stage.bounds.size.width),@"media_height":@(_stage.bounds.size.height),@"header_height":@(self.bounds.size.height),@"wide":[_layout objectForKey:@"wide"]?:@NO};}
@end
