#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "../RWArtworkPolicy.h"
@interface UIImageView:NSObject
@property(strong) id image;
@end
@implementation UIImageView @end
@interface RWArtworkBinding:NSObject
@property(copy) NSArray *urls;
@property(copy) NSString *identity,*profile;
@end
@implementation RWArtworkBinding @end
@interface RewindStore:NSObject
@property(strong) NSDictionary *state;
- (void)artwork:(NSArray *)urls role:(NSString *)role identity:(NSString *)identity into:(UIImageView *)view completion:(void(^)(BOOL))completion;
@end
@implementation RewindStore
- (NSString *)canonicalArtworkURL:(NSString *)url{return url;}
- (void)cancelArtwork:(UIImageView *)view{objc_setAssociatedObject(view,@selector(cancelArtwork:),nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
// The runner extracts the actual production method's synchronous binding prefix.
// Async decode/rendering is verified separately on iOS, not by this facade.
#include "ArtworkBindingUnderTest.inc"
@end
static int checks,failures;
static void Case(RewindStore *s,NSString *oldID,NSString *newID,NSArray *oldURLs,NSArray *newURLs,NSString *oldProfile,BOOL keeps,BOOL owned){
 UIImageView *v=[UIImageView new];v.image=@"previous pixels";RWArtworkBinding *b=[RWArtworkBinding new];b.identity=oldID;b.urls=oldURLs;b.profile=oldProfile;
 if(owned)objc_setAssociatedObject(v,@selector(cancelArtwork:),b,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
 [s artwork:newURLs role:@"hero" identity:newID into:v completion:nil];checks++;if((v.image!=nil)!=keeps){failures++;fprintf(stderr,"FAIL %s -> %s urls %lu, owned%d, keep%d\n",oldID.UTF8String,newID.UTF8String,(unsigned long)newURLs.count,owned,keeps);}
}
int main(){@autoreleasepool{RewindStore *s=[RewindStore new];s.state=@{@"activeProfile":@"main"};NSArray *a=@[@"https://art.test/a"],*b=@[@"https://art.test/b"];
 Case(s,@"first",@"second",a,b,@"main",NO,YES);
 Case(s,@"first",@"second",a,a,@"main",NO,YES);
 Case(s,@"first",@"first",a,a,@"main",YES,YES);
 Case(s,@"first",@"first",a,b,@"main",YES,YES);
 Case(s,@"first",@"second",a,@[],@"main",NO,YES);
 Case(s,@"first",@"first",a,@[],@"main",NO,YES);
 Case(s,@"",@"",a,b,@"main",NO,YES);
 Case(s,@"",@"",a,a,@"main",YES,YES);
 Case(s,@"first",@"first",a,a,@"kids",NO,YES);
 Case(s,@"first",@"first",a,a,@"main",NO,NO);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;}}
