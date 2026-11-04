#import <Foundation/Foundation.h>
#import "../RWSubtitleLayout.h"
#import "../RWSubtitles.h"
static int checks,failures;
static void check(BOOL pass){checks++;if(!pass)failures++;}
int main(){@autoreleasepool{
    for(NSString *name in @[@"short",@"long",@"international",@"rtl"]){NSDictionary *source=@{@"subtitles":@[@{@"name":name,@"url":[NSString stringWithFormat:@"asset:subtitle-layout-%@.srt",name]}]};check([RWSubtitles providedBySource:source meta:@{} allowBundled:YES].count==1);check(![RWSubtitles providedBySource:source meta:@{} allowBundled:NO].count);}
    for(NSString *url in @[@"asset:subtitle-layout-other.srt",@"asset:../subtitle-layout-short.srt"]){check(![RWSubtitles providedBySource:@{@"subtitles":@[@{@"url":url}]} meta:@{} allowBundled:YES].count);}
    // Three larger lines need >75pt; the old fixed frame cannot contain them.
    CGRect large=RWSubtitleFrame(CGSizeMake(768,1024),CGSizeMake(600,101),728,true);
    check(large.size.height>=113);check(CGRectGetMaxY(large)<=712);
    for(NSValue *v in @[[NSValue valueWithSize:NSMakeSize(768,1024)],[NSValue valueWithSize:NSMakeSize(1024,768)]]){
        NSSize n=v.sizeValue;CGSize screen=CGSizeMake(n.width,n.height);
        for(NSNumber *h in @[@24,@72,@101,@180,@4096])for(NSNumber *w in @[@20,@600,@4096])for(NSNumber *controls in @[@NO,@YES]){
            CGRect r=RWSubtitleFrame(screen,CGSizeMake(w.doubleValue,h.doubleValue),screen.height,controls.boolValue);
            check(r.origin.x>=32&&CGRectGetMaxX(r)<=screen.width-32);
            check(r.origin.y>=64&&CGRectGetMaxY(r)<=screen.height-(controls.boolValue?205:32));
            check(r.size.height<=screen.height*.35&&r.size.width<=screen.width-64);
            if(h.doubleValue<181)check(r.size.height>=h.doubleValue+12);
        }
        CGRect shown=RWSubtitleFrame(screen,CGSizeMake(600,90),screen.height,true),hidden=RWSubtitleFrame(screen,CGSizeMake(600,90),screen.height,false);
        check(hidden.origin.y>shown.origin.y&&CGSizeEqualToSize(hidden.size,shown.size));
    }
    check(CGRectIsEmpty(RWSubtitleFrame(CGSizeZero,CGSizeMake(100,50),0,true)));
    check(CGRectIsEmpty(RWSubtitleFrame(CGSizeMake(768,1024),CGSizeZero,1024,true)));
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
