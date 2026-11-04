#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "../RWArtworkPolicy.h"
#import "../RWHomePresentation.h"
// Exercise actual content reset/update logic. Facades verify values and image
// ownership transitions, not UIKit layout, image decoding or device latency.
@interface UIColor:NSObject
+ (instancetype)whiteColor;
+ (instancetype)colorWithWhite:(double)white alpha:(double)alpha;
- (instancetype)colorWithAlphaComponent:(double)alpha;
@end
@implementation UIColor
+ (instancetype)whiteColor {return [self new];}
+ (instancetype)colorWithWhite:(double)white alpha:(double)alpha {return [self new];}
- (instancetype)colorWithAlphaComponent:(double)alpha {return self;}
@end
@interface Layer:NSObject
@property double cornerRadius;
@end
@implementation Layer @end
@interface UIView:NSObject
@property CGRect frame;
@property(readonly) CGRect bounds;
@property CGPoint center;
@property BOOL hidden,clipsToBounds;
@property(strong) UIColor *backgroundColor;
@property(strong) Layer *layer;
@property(strong) NSMutableArray *children;
- (instancetype)initWithFrame:(CGRect)frame;
- (void)addSubview:(id)view;
- (void)bringSubviewToFront:(id)view;
@end
@implementation UIView
- (instancetype)init {if((self=[super init])){_layer=[Layer new];_children=[NSMutableArray new];}return self;}
- (instancetype)initWithFrame:(CGRect)frame {if((self=[self init]))_frame=frame;return self;}
- (CGRect)bounds {return CGRectMake(0,0,_frame.size.width,_frame.size.height);}
- (void)addSubview:(id)view {[_children addObject:view];}
- (void)bringSubviewToFront:(id)view {[_children removeObjectIdenticalTo:view];[_children addObject:view];}
@end
@interface UIImageView:UIView
@property(strong) id image;
- (instancetype)initWithImage:(id)image;
@end
@implementation UIImageView
- (instancetype)initWithImage:(id)image {if((self=[super init]))_image=image;return self;}
@end
@interface UILabel:UIView
@property(copy) NSString *text;
@property int textAlignment;
@end
@implementation UILabel @end
enum {UIFontWeightBold,UIFontWeightSemibold,NSTextAlignmentCenter};
static UIColor *RWColor(unsigned int color){return [UIColor new];}
static NSString *RWString(id value){return [value isKindOfClass:NSString.class]?value:@"";}
static NSString *RWID(NSDictionary *meta){return RWString(meta[@"id"]?:meta[@"imdb_id"]);}
static id RWIcon(NSString *name,double size,UIColor *color){return name;}
static UILabel *RWLabel(NSString *text,double size,int weight,UIColor *color){UILabel *label=[UILabel new];label.text=text;return label;}
@interface Poster:UIView {
@public UIImageView *_art,*_resumePlay,*_fallbackIcon;NSArray *_artURLs;BOOL _contentsBuilt,_landscape,_artRequested,_artComplete;double _retryAfter;
UIView *_base,*_resumeShade,*_progressTrack,*_progress;UILabel *_placeholder,*_title,*_detail,*_rating,*_kind;
}
@property(strong) NSDictionary *meta;
@property(copy) NSString *accessibilityLabel;
@property NSUInteger cancellations;
@property BOOL hidesArtworkBadges;
- (void)cancelArtwork;
@end
@implementation Poster
#include "../RWPosterContent.inc"
- (void)cancelArtwork {_cancellations++;_artRequested=NO;}
@end
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
int main(){@autoreleasepool{
    NSDictionary *a=@{@"id":@"tt123456",@"type":@"movie",@"name":@"First",@"imdbRating":@8.2,@"releaseInfo":@"2026"},*b=@{@"id":@"tt654321",@"type":@"series",@"name":@"Second",@"releaseInfo":@"2025"};
    Poster *p=[Poster new];p.meta=a;[p updateMeta:b];CHECK(p.meta==b&&[p.accessibilityLabel isEqual:@"Second"]&&p.cancellations==0);
    p.frame=CGRectMake(0,0,148,266);p->_base=[[UIView alloc]initWithFrame:CGRectMake(0,0,148,215)];p->_art=[UIImageView new];p->_placeholder=[UILabel new];p->_title=[UILabel new];p->_detail=[UILabel new];p->_contentsBuilt=YES;
    p.meta=a;p->_artURLs=[RWArtworkPolicy URLsForMeta:a landscape:NO];p->_art.image=@"first pixels";p->_artRequested=YES;p->_retryAfter=300;
    [p updateMeta:b];CHECK(p->_art.image==nil&&!p->_artRequested&&p.cancellations==1&&p->_retryAfter==0);CHECK([p->_placeholder.text isEqual:@"Second"]&&[p->_title.text isEqual:@"Second"]);CHECK([p->_kind.text isEqual:@"Series"]&&[p->_detail.text isEqual:@"2025"]);CHECK(!p->_rating||p->_rating.hidden);
    p->_art.image=@"second pixels";p->_artRequested=YES;NSMutableDictionary *rating=[b mutableCopy];rating[@"imdbRating"]=@9.1;[p updateMeta:rating];CHECK([p->_art.image isEqual:@"second pixels"]&&p->_artRequested&&p.cancellations==1);CHECK([p->_rating.text isEqual:@"IMDb 9.1"]&&!p->_rating.hidden);
    UILabel *ratingView=p->_rating,*titleView=p->_title;UIImageView *imageView=p->_art;NSMutableDictionary *progress=[rating mutableCopy];progress[@"historyRecord"]=@{@"videoID":@"tt654321:2:3",@"position":@100,@"duration":@400};[p updateMeta:progress];CHECK(p->_rating==ratingView&&p->_title==titleView&&p->_art==imageView);CHECK(!p->_resumePlay.hidden&&!p->_progressTrack.hidden&&fabs(p->_progress.bounds.size.width-37)<.001);CHECK([p->_detail.text isEqual:@"S2 E3 · 1:40"]);
    UIView *track=p->_progressTrack;[p updateMeta:b];CHECK(p->_progressTrack==track&&track.hidden&&p->_resumePlay.hidden&&p->_resumeShade.hidden);CHECK(p->_rating.hidden&&[p->_detail.text isEqual:@"2025"]);CHECK([p->_art.image isEqual:@"second pixels"]);
    NSMutableDictionary *art=[b mutableCopy];art[@"poster"]=@"asset:new.jpg";[p updateMeta:art];CHECK(!p->_art.image&&p.cancellations==2&&[p->_artURLs.firstObject isEqual:@"asset:new.jpg"]);
    // Repeated identities reuse the existing label/image objects and clear
    // every previous image before a later asynchronous loader can paint it.
    for(int i=0;i<20;i++){p->_art.image=@"old pixels";[p updateMeta:i%2?a:b];CHECK(p->_art.image==nil&&p->_art==imageView&&p->_title==titleView);}
    CHECK([p->_kind.text isEqual:@"Film"]&&[p->_title.text isEqual:@"First"]);CHECK([p.accessibilityLabel containsString:@"IMDb 8.2"]);
    p.hidesArtworkBadges=YES;[p updateMeta:a];CHECK(p->_rating.hidden&&p->_kind.hidden);CHECK([p.accessibilityLabel containsString:@"IMDb 8.2"]);p.hidesArtworkBadges=NO;[p updateMeta:a];CHECK(!p->_rating.hidden&&!p->_kind.hidden);
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
