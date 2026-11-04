#import "RWDetailPresentation.h"
#import <math.h>
static NSString *DText(id v){return [v isKindOfClass:NSString.class]?v:[v isKindOfClass:NSNumber.class]?[v stringValue]:@"";}
static NSArray *DArray(id v){return [v isKindOfClass:NSArray.class]?v:@[];}
@implementation RWDetailPresentation
+ (NSDictionary *)textForMeta:(NSDictionary *)meta rating:(NSDictionary *)rating {
    BOOL series=[meta[@"type"]isEqual:@"series"];NSMutableArray *facts=[NSMutableArray new];NSString *year=DText(meta[@"releaseInfo"]);if(year.length>12)year=[year substringToIndex:4];NSInteger first=year.integerValue;if(first>=1800&&first<=2200)[facts addObject:year];
    if(series){NSMutableSet *seasons=[NSMutableSet new];for(id raw in DArray(meta[@"videos"])){if(![raw isKindOfClass:NSDictionary.class])continue;NSInteger season=[DText(raw[@"season"])integerValue];if(season>0&&season<=100)[seasons addObject:@(season)];}if(seasons.count)[facts addObject:[NSString stringWithFormat:@"%lu season%@",(unsigned long)seasons.count,seasons.count==1?@"":@"s"]];}
    else {NSString *runtime=DText(meta[@"runtime"]);NSRange minutes=[runtime rangeOfString:@"^[0-9]{1,4}\\s*(min|minutes)$" options:NSRegularExpressionSearch];NSInteger n=runtime.integerValue;if(minutes.location==0&&minutes.length==runtime.length&&n>0&&n<1500){[facts addObject:n>=60?[NSString stringWithFormat:@"%ldh%@",(long)(n/60),n%60?[NSString stringWithFormat:@" %ldm",(long)(n%60)]:@""]:[NSString stringWithFormat:@"%ldm",(long)n]];}else if(runtime.length&&runtime.length<=24)[facts addObject:runtime];}
    NSString *age=DText(rating[@"label"]);if(age.length&&age.length<30)[facts addObject:age];
    NSString *rawScore=DText(meta[@"imdbRating"]);NSScanner *scanner=[NSScanner scannerWithString:rawScore];double score=0;BOOL valid=[scanner scanDouble:&score]&&scanner.isAtEnd&&isfinite(score)&&score>=1&&score<=10;
    NSMutableOrderedSet *genres=[NSMutableOrderedSet new];for(id genre in DArray(meta[@"genres"]))if([genre isKindOfClass:NSString.class]&&[genre length]&&[genre length]<40){[genres addObject:genre];if(genres.count==3)break;}
    return @{@"kind":series?@"SERIES":@"FILM",@"title":DText(meta[@"name"]),@"facts":[facts componentsJoinedByString:@"  ·  "],@"rating":valid?[NSString stringWithFormat:@"IMDb %.1f",score]:@"",@"genres":[genres.array componentsJoinedByString:@" · "]};
}
+ (NSDictionary *)layoutForWidth:(double)w {
    if(!isfinite(w)||w<320)w=320;w=MIN(w,1600);BOOL wide=w>=900;double mediaW=wide?w-400:w,mediaH=mediaW*9/16;
    // Official embedded controls stay in an unobscured 16:9 viewport. Text has
    // reserved space outside it, so metadata and trailer arrival cannot overlap.
    return @{@"wide":@(wide),@"height":@(wide?MAX(326,mediaH)+12:mediaH+192),@"media":@[@(wide?400:0),@0,@(mediaW),@(mediaH)],@"kind":@[@32,@(wide?20:mediaH+12),@(wide?336:w-64),@20],@"title":@[@32,@(wide?51:mediaH+40),@(wide?336:w-64),@(wide?132:84)],@"facts":@[@32,@(wide?195:mediaH+132),@(wide?336:w-64),@(wide?52:22)],@"rating":@[@32,@(wide?259:mediaH+162),@90,@24],@"genres":@[@(wide?32:134),@(wide?298:mediaH+164),@(wide?336:w-166),@22]};
}
@end
