#import <Foundation/Foundation.h>
#import "../RWArtworkPolicy.h"
int main(void){@autoreleasepool{
    __block int checks=0,failures=0;void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *label){checks++;if(!ok){failures++;fprintf(stderr,"FAIL %s\n",label.UTF8String);}};
    NSArray *u=[RWArtworkPolicy URLsForMeta:@{@"id":@"tt1375666",@"poster":@"https://img.example/poster.jpg",@"background":@"https://img.example/still.jpg"} landscape:NO];
    check(u.count==4&&[u[0]hasSuffix:@"poster.jpg"]&&[u[1]containsString:@"/poster/small/"]&&[u[2]hasSuffix:@"still.jpg"],@"Same-shape fallbacks precede the same title's other artwork");
    u=[RWArtworkPolicy URLsForMeta:@{@"id":@"tt1375666",@"poster":[NSNull null],@"background":@"asset:background-tt1375666.jpg"} landscape:YES];
    check(u.count==3&&[u[0]hasPrefix:@"asset:"],@"Missing poster and bundled background are supported");
    u=[RWArtworkPolicy URLsForMeta:@{@"id":@"tt1375666"} landscape:NO];
    check(u.count==2&&[u[0]containsString:@"/tt1375666/"],@"Missing metadata has an exact IMDb artwork fallback");
    check(![RWArtworkPolicy URLsForMeta:@{@"id":@"tt1375666/../other"} landscape:NO].count,@"Malformed identity cannot fetch unrelated title artwork");
    check(![RWArtworkPolicy URLsForMeta:@{@"poster":@"javascript:alert(1)",@"background":@"file:///private/example"} landscape:NO].count,@"Non-image URL schemes are rejected");
    check(![RWArtworkPolicy URLsForMeta:@{@"poster":@"https://user:pass@img.example/a"} landscape:NO].count,@"Credentials are not accepted in artwork metadata");
    check([RWArtworkPolicy URLsForMeta:@{@"poster":@"https://img.example/a",@"background":@"https://img.example/a"} landscape:NO].count==1,@"Duplicate metadata artwork is fetched only once per chain");
    u=[RWArtworkPolicy URLsForMeta:@{@"id":@"tt1375666",@"poster":@"asset:poster.jpg",@"background":@"https://example.com/a"} landscape:YES];
    check([u[1]containsString:@"/background/medium/"]&&[u[2]isEqual:@"asset:poster.jpg"],@"A bundled poster cannot precede the exact-title backdrop fallback");
    check(![RWArtworkPolicy validURLs:@[@"asset:../secret",@"asset:/tmp/a",@"asset:%2e%2e/a",@"https:///a"]].count,@"Malformed asset paths and remote hosts are rejected");
    NSDictionary *verified=@{@"id":@"tt1380596",@"type":@"series",@"background":@"https://images.metahub.space/background/medium/tt1380596/img",@"discovery":@{@"artwork":@{@"imdb":@"tt1380596",@"provider":@"TVmaze",@"background":@[@"https://static.tvmaze.com/uploads/images/original_untouched/37/93284.jpg"]}}};
    NSArray *verifiedURLs=[RWArtworkPolicy URLsForMeta:verified landscape:YES];check([verifiedURLs.firstObject hasSuffix:@"93284.jpg"]&&![verifiedURLs containsObject:verified[@"background"]],@"Exact-identity landscape replaces unverified same-role artwork");
    NSDictionary *hero=[RWArtworkPolicy requestForRole:@"hero" identity:@"tt1" width:1024 height:320 scale:1];
    NSDictionary *poster=[RWArtworkPolicy requestForRole:@"poster" identity:@"tt1" width:160 height:230 scale:1];
    check(![[RWArtworkPolicy variantKey:@"https://e/a" request:hero]isEqual:[RWArtworkPolicy variantKey:@"https://e/a" request:poster]],@"A small poster bitmap is never a hero cache hit");
    NSDictionary *fit=[RWArtworkPolicy sizing:hero sourceWidth:300 height:450];
    check(![fit[@"sufficient"]boolValue]&&[fit[@"presentation"]isEqual:@"fit"]&&[fit[@"max_pixel"]intValue]<=320,@"Portrait fallback is contained, not enlarged to fill a landscape hero");
    NSDictionary *wide=[RWArtworkPolicy sizing:hero sourceWidth:1280 height:720];
    check([wide[@"sufficient"]boolValue]&&[wide[@"max_pixel"]intValue]==1024,@"Hero decodes for actual target pixels rather than URL words");
    NSDictionary *small=[RWArtworkPolicy sizing:hero sourceWidth:320 height:180];
    check(![small[@"sufficient"]boolValue]&&[small[@"presentation"]isEqual:@"fit"],@"Small backdrops also cannot be stretched full width");
    NSDictionary *retina=[RWArtworkPolicy requestForRole:@"hero" identity:@"tt1" width:1024 height:320 scale:2];
    NSDictionary *large=[RWArtworkPolicy sizing:retina sourceWidth:6000 height:2000];check(large&&[large[@"max_pixel"]intValue]<=1280,@"Large sources remain within the old-iPad decode budget");
    check([RWArtworkPolicy sizing:hero sourceWidth:50000 height:50000]==nil,@"Pathological image dimensions are rejected before decoding");
    check([RWArtworkPolicy sizing:hero sourceWidth:6000 height:4000]==nil,@"Compressed images cannot expand into an unsafe source bitmap on this iPad");
    check(![RWArtworkPolicy URLsForMeta:@{@"id":@"tt1375666\n"} landscape:YES].count,@"Exact title identity does not accept a trailing newline");
    NSDictionary *invalid=[RWArtworkPolicy requestForRole:@"nonsense" identity:nil width:NAN height:INFINITY scale:NAN];
    check([invalid[@"width"]intValue]==320&&[invalid[@"height"]intValue]==192&&[invalid[@"scale"]intValue]==1,@"Invalid layout numbers cannot create unbounded cache dimensions");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
