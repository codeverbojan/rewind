#import "RWArtworkPolicy.h"
#import <math.h>
@implementation RWArtworkPolicy
+ (NSArray *)URLsForMeta:(NSDictionary *)meta landscape:(BOOL)landscape {
    NSMutableArray *urls=[NSMutableArray new];
    NSString *imdb=[meta[@"id"]isKindOfClass:NSString.class]?meta[@"id"]:@"";
    NSRange match=[imdb rangeOfString:@"^tt[0-9]{5,12}$" options:NSRegularExpressionSearch];BOOL exact=match.location==0&&match.length==imdb.length;
    NSDictionary *discovery=[meta[@"discovery"]isKindOfClass:NSDictionary.class]?meta[@"discovery"]:@{};
    NSDictionary *art=[discovery[@"artwork"]isKindOfClass:NSDictionary.class]?discovery[@"artwork"]:@{};
    BOOL verified=exact&&[meta[@"type"]isEqual:@"series"]&&[art[@"imdb"]isEqual:imdb]&&[art[@"provider"]isEqual:@"TVmaze"];
    // Complete each semantic role before falling back to another shape. A cached
    // poster never outranks an uncached same-title backdrop.
    for(NSString *kind in (landscape?@[@"background",@"poster"]:@[@"poster",@"background"])){
        NSMutableArray *identified=[NSMutableArray new];
        if(verified&&[art[kind]isKindOfClass:NSArray.class])for(NSString *value in [self validURLs:art[kind]]){
            NSURL *url=[NSURL URLWithString:value];if([url.scheme isEqual:@"https"]&&[url.host isEqual:@"static.tvmaze.com"]&&[url.path hasPrefix:@"/uploads/images/"])[identified addObject:value];
        }
        // A verified source replaces unverified pictures of this shape. In
        // particular, a larger cached mislabelled backdrop cannot win again.
        if(identified.count){[urls addObjectsFromArray:identified];continue;}
        if([meta[kind]isKindOfClass:NSString.class])[urls addObject:meta[kind]];
        if(exact)[urls addObject:[NSString stringWithFormat:@"https://images.metahub.space/%@/%@/%@/img",kind,[kind isEqual:@"poster"]?@"small":@"medium",imdb]];
    }
    return [self validURLs:urls];
}
+ (NSArray *)validURLs:(NSArray *)values {
    NSMutableOrderedSet *urls=[NSMutableOrderedSet new];
    for(id value in values){if(![value isKindOfClass:NSString.class]||![value length]||[value length]>4096)continue;NSURL *u=[NSURL URLWithString:value];NSString *scheme=u.scheme.lowercaseString;
        if(u.user||u.password)continue;
        if([scheme isEqual:@"asset"]){NSString *path=[value substringFromIndex:6];if(!path.length||[path hasPrefix:@"/"]||[path containsString:@".."]||[path containsString:@"%"]||[path containsString:@"\\"]||[path containsString:@"?"]||[path containsString:@"#"])continue;}
        else if(![@[@"https",@"http"]containsObject:scheme]||!u.host.length)continue;
        [urls addObject:value];if(urls.count==6)break;
    }
    return urls.array;
}
+ (NSDictionary *)requestForRole:(NSString *)role identity:(NSString *)identity width:(double)width height:(double)height scale:(double)scale {
    if(![@[@"hero",@"poster",@"backdrop",@"episode",@"portrait",@"logo"]containsObject:role?:@""])role=@"backdrop";
    if(!isfinite(width)||width<=0)width=320;if(!isfinite(height)||height<=0)height=180;
    if(!isfinite(scale)||scale<=0)scale=1;scale=MIN(2,MAX(1,scale));
    // Stable 32-pixel buckets avoid one decoded cache entry per fractional frame.
    double w=MIN(2048,ceil(width*scale/32)*32),h=MIN(2048,ceil(height*scale/32)*32);
    return @{@"role":role,@"identity":identity?:@"",@"width":@(w),@"height":@(h),@"point_width":@(width),@"point_height":@(height),@"scale":@(scale),@"pixel_cap":@([role isEqual:@"hero"]?1280:[role isEqual:@"portrait"]||[role isEqual:@"logo"]?512:768)};
}
+ (NSString *)variantKey:(NSString *)url request:(NSDictionary *)r {return [NSString stringWithFormat:@"%@|%@|%@x%@",url,r[@"role"],r[@"width"],r[@"height"]];}
+ (NSDictionary *)sizing:(NSDictionary *)r sourceWidth:(double)w height:(double)h {
    if(!isfinite(w)||!isfinite(h)||w<1||h<1||w>8192||h>8192||w*h>16000000)return nil;
    double tw=[r[@"width"]doubleValue],th=[r[@"height"]doubleValue],ratio=w/h;NSString *role=r[@"role"];
    BOOL landscape=[@[@"hero",@"backdrop",@"episode"]containsObject:role],portrait=[role isEqual:@"poster"],logo=[role isEqual:@"logo"];
    BOOL shape=landscape?ratio>=1.2:portrait?ratio<=.9:YES;
    double fill=MAX(tw/w,th/h),fit=MIN(tw/w,th/h),cap=[r[@"pixel_cap"]doubleValue];
    double decodeScale=MIN(1,MIN((shape&&!logo)?fill:fit,cap/MAX(w,h)));
    double dw=MAX(1,floor(w*decodeScale)),dh=MAX(1,floor(h*decodeScale));
    double coverage=MIN(dw/tw,dh/th);BOOL sufficient=shape&&(logo||coverage>=.8);
    // A low-resolution fallback is contained at native size, never enlarged.
    double score=(shape?1000:0)+MIN(1,coverage)*100;
    return @{@"source_width":@(w),@"source_height":@(h),@"max_pixel":@(ceil(MAX(dw,dh))),@"sufficient":@(sufficient),@"score":@(score),@"presentation":(!logo&&sufficient)?@"fill":@"fit"};
}
@end
