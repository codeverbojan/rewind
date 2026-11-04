#import "RWPreviewSession.h"
@implementation RWPreviewSession {NSUInteger _fallbacks;}
- (instancetype)init {if((self=[super init])){_key=@"";_state=@"idle";}return self;}
- (void)selectKey:(NSString *)key {key=key?:@"";if([key isEqual:_key])return;_key=[key copy];_generation++;_attempts=0;_fallbacks=0;_state=key.length?@"waiting":@"idle";}
- (BOOL)beginAllowed:(BOOL)allowed visible:(BOOL)visible manual:(BOOL)manual {
    if(!_key.length||!visible||(!allowed&&!manual)||[@[@"lookup",@"loading",@"playing"]containsObject:_state])return NO;
    if(!manual&&![_state isEqual:@"waiting"])return NO;
    _attempts++;_generation++;_state=@"lookup";return YES;
}
- (BOOL)acceptSource:(BOOL)available generation:(NSUInteger)generation {if(generation!=_generation||![_state isEqual:@"lookup"])return NO;_state=available?@"loading":@"unavailable";return YES;}
- (BOOL)beginNativeFallback {if(_fallbacks||![@[@"loading",@"playing"]containsObject:_state])return NO;_fallbacks++;_generation++;_state=@"lookup";return YES;}
- (BOOL)event:(NSString *)event generation:(NSUInteger)generation {
    if(generation!=_generation||![@[@"lookup",@"loading",@"playing"]containsObject:_state])return NO;
    if([event isEqual:@"playing"]){if([_state isEqual:@"lookup"])return NO;_state=@"playing";return YES;}
    if([@[@"ended",@"unavailable",@"released"]containsObject:event]){_state=[event copy];return YES;}return NO;
}
- (void)cancel {_generation++;_key=@"";_state=@"idle";_attempts=0;_fallbacks=0;}
- (NSDictionary *)diagnostics {return @{@"key":_key,@"state":_state,@"attempts":@(_attempts),@"native_fallbacks":@(_fallbacks),@"generation":@(_generation)};}
@end
