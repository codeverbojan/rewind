#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "../RWHomePresentation.h"

// Execute the production binding method with view ownership facades. These
// checks do not simulate rendering, UIImage memory, layout or frame latency.
@interface RWPoster:NSObject
@property(nonatomic,strong) NSDictionary *meta;
@property(nonatomic,assign) CGRect frame;
@property(nonatomic,readonly) CGRect bounds;
@property(nonatomic,copy) void(^action)(NSDictionary *);
@property(nonatomic,assign) NSUInteger loads;
@property(nonatomic,assign) BOOL defersContents;
@property(nonatomic,assign) NSUInteger updates;
- (instancetype)initWithMeta:(NSDictionary *)meta width:(CGFloat)width landscape:(BOOL)landscape;
- (void)removeFromSuperview;
- (void)loadArtworkIfVisible;
- (void)updateMeta:(NSDictionary *)meta;
@end
@implementation RWPoster
- (instancetype)initWithMeta:(NSDictionary *)meta width:(CGFloat)w landscape:(BOOL)landscape {if((self=[super init])){_meta=meta;_frame=CGRectMake(0,0,w,landscape?w*.5625:w*1.45);}return self;}
- (CGRect)bounds {return CGRectMake(0,0,_frame.size.width,_frame.size.height);}
- (void)removeFromSuperview {}
- (void)loadArtworkIfVisible {_loads++;}
- (void)updateMeta:(NSDictionary *)meta {_updates++;self.meta=meta;}
@end
@interface RWEntityCard:RWPoster @end
@implementation RWEntityCard @end
@interface View:NSObject
- (void)addSubview:(id)view;
@end
@implementation View
- (void)addSubview:(id)view {}
@end
@interface RewindStore:NSObject
+ (instancetype)shared;
- (NSDictionary *)discoveryMeta:(NSDictionary *)meta;
@end
@implementation RewindStore
+ (instancetype)shared {static RewindStore *s;static dispatch_once_t once;dispatch_once(&once,^{s=[self new];});return s;}
- (NSDictionary *)discoveryMeta:(NSDictionary *)meta {NSMutableDictionary *m=[meta mutableCopy];m[@"availability"]=@{@"state":@"unknown"};return m;}
@end
@interface RWUIProbe:NSObject
+ (instancetype)shared;
- (void)work:(NSString *)name started:(double)started;
@end
@implementation RWUIProbe
+ (instancetype)shared {static RWUIProbe *p;static dispatch_once_t once;dispatch_once(&once,^{p=[self new];});return p;}
- (void)work:(NSString *)name started:(double)started {}
@end
@interface Binding:NSObject
@property(nonatomic,strong) NSDictionary *record,*presentation;
@property(nonatomic,strong) RWPoster *poster;
@property(nonatomic,strong) View *contentView;
@property(nonatomic,assign) BOOL landscape;
@property(nonatomic,assign) BOOL defersContents;
@end
@implementation Binding
#include "../RWPosterBinding.inc"
@end
static int Checks,Failures;
#define CHECK(...) do{Checks++;if(!(__VA_ARGS__)){Failures++;fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#__VA_ARGS__);}}while(0)
int main(){@autoreleasepool{
    Binding *b=[Binding new];b.contentView=[View new];NSDictionary *base=@{@"id":@"tt123456",@"name":@"Title",@"type":@"movie",@"poster":@"asset:poster.jpg",@"imdbRating":@8.1};
    __block NSDictionary *selected=nil;void(^select)(NSDictionary *)=^(NSDictionary *m){selected=m;};
    [b configure:base width:148 landscape:NO action:select];RWPoster *original=b.poster;
    CHECK(original&&b.record==base&&original.meta[@"availability"]);CHECK(original.loads==1);
    for(int i=0;i<20;i++){
        NSMutableDictionary *fresh=[base mutableCopy];fresh[@"availability"]=@{@"checked":@(i),@"discovery_eligible":@(i%2)};fresh[@"discovery"]=@{@"cast":@[@{@"name":@"New credit"}],@"revision":@(i)};fresh[@"source"]=@{@"seeders":@(i)};
        [b configure:fresh width:148 landscape:NO action:select];CHECK(b.poster==original);CHECK(b.record==fresh&&b.poster.meta==fresh);b.poster.action(b.poster.meta);CHECK(selected==fresh);
    }
    // The same production method must update visual changes in place, preserving
    // live actions rather than retaining a stale record through reuse.
    for(NSString *field in @[@"id",@"name",@"poster",@"background",@"type",@"releaseInfo",@"imdbRating",@"seriesName",@"episodeCaption",@"episodeVideoID",@"showLanguage"]){
        [b configure:base width:148 landscape:NO action:select];RWPoster *previous=b.poster;NSMutableDictionary *changed=[base mutableCopy];changed[field]=[field isEqual:@"showLanguage"]?@YES:@"changed";
        NSUInteger priorUpdates=previous.updates;[b configure:changed width:148 landscape:NO action:select];CHECK(b.poster==previous&&b.poster.updates==priorUpdates+1&&b.poster.meta[@"name"]);
    }
    [b configure:base width:148 landscape:NO action:select];RWPoster *previous=b.poster;[b configure:base width:264 landscape:NO action:select];CHECK(b.poster!=previous&&b.poster.bounds.size.width==264);
    previous=b.poster;[b configure:base width:264 landscape:YES action:select];CHECK(b.poster!=previous&&b.landscape);previous=b.poster;[b configure:base width:264 landscape:YES action:select];CHECK(b.poster==previous);
    b.poster=nil;[b configure:base width:264 landscape:YES action:select];CHECK(b.poster!=nil);
    NSDictionary *progress=@{@"id":@"tt12",@"type":@"series",@"historyRecord":@{@"videoID":@"tt12:1:2",@"position":@60,@"duration":@1200,@"source":@"old"}};
    NSMutableDictionary *next=[progress mutableCopy];next[@"historyRecord"]=@{@"videoID":@"tt12:1:2",@"position":@60,@"duration":@1200,@"source":@"new"};CHECK([[RWHomePresentation posterContent:progress]isEqual:[RWHomePresentation posterContent:next]]);
    for(NSString *field in @[@"videoID",@"position",@"duration"]){NSMutableDictionary *record=[progress[@"historyRecord"]mutableCopy];record[field]=@999;next[@"historyRecord"]=record;CHECK(![[RWHomePresentation posterContent:progress]isEqual:[RWHomePresentation posterContent:next]]);}
    next=[base mutableCopy];next[@"showLanguage"]=@YES;next[@"discovery"]=@{@"primaryLanguage":@"fr"};NSDictionary *signature=[RWHomePresentation posterContent:next];next[@"discovery"]=@{@"primaryLanguage":@"ko"};CHECK(![signature isEqual:[RWHomePresentation posterContent:next]]);
    NSMutableDictionary *artTitle=[base mutableCopy];artTitle[@"type"]=@"series";[b configure:artTitle width:264 landscape:YES action:select];previous=b.poster;NSUInteger artUpdates=previous.updates;
    artTitle=[artTitle mutableCopy];artTitle[@"discovery"]=@{@"artwork":@{@"provider":@"TVmaze",@"imdb":@"tt123456",@"background":@[@"https://static.tvmaze.com/uploads/images/original_untouched/1/new.jpg"],@"checkedAt":@1}};
    [b configure:artTitle width:264 landscape:YES action:select];CHECK(b.poster==previous&&b.poster.updates==artUpdates+1);
    signature=[RWHomePresentation posterContent:artTitle];NSMutableDictionary *renewed=[artTitle[@"discovery"][@"artwork"]mutableCopy];renewed[@"checkedAt"]=@2;artTitle=[artTitle mutableCopy];artTitle[@"discovery"]=@{@"artwork":renewed};CHECK([signature isEqual:[RWHomePresentation posterContent:artTitle]]);
    NSDictionary *person=@{@"id":@"Q1",@"type":@"person",@"name":@"Person",@"imageURL":@"first"};[b configure:person width:180 landscape:NO action:select];CHECK([b.poster isKindOfClass:RWEntityCard.class]);previous=b.poster;[b configure:person width:180 landscape:NO action:select];CHECK(previous==b.poster);next=[person mutableCopy];next[@"imageURL"]=@"second";[b configure:next width:180 landscape:NO action:select];CHECK(b.poster!=previous);
    b.defersContents=YES;[b configure:base width:148 landscape:NO action:select];CHECK(b.poster.defersContents);
    previous=b.poster;NSMutableDictionary *latest=[base mutableCopy];latest[@"name"]=@"Updated while waiting";[b configure:latest width:148 landscape:NO action:select];CHECK(b.poster==previous&&[b.poster.meta[@"name"]isEqual:latest[@"name"]]);b.poster.action(b.poster.meta);CHECK(selected==b.poster.meta&&[selected[@"name"]isEqual:latest[@"name"]]);
    b.defersContents=NO;[b configure:latest width:148 landscape:NO action:select];CHECK(!b.poster.defersContents&&b.poster==previous);
    b.defersContents=YES;[b configure:person width:180 landscape:NO action:select];CHECK(!b.poster.defersContents&&[b.poster isKindOfClass:RWEntityCard.class]);
    printf("{\"checks\":%d,\"failures\":%d}\n",Checks,Failures);return Failures?1:0;
}}
