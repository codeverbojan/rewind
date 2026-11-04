#import "RWPlaybackLifetimeProbe.h"
@implementation RWPlaybackLifetimeProbe {
    NSDictionary *_references;
}
- (instancetype)initWithObjects:(NSDictionary *)objects {
    if((self=[super init])){
        NSMutableDictionary *refs=[NSMutableDictionary new];
        for(NSString *key in objects){NSHashTable *weak=[NSHashTable weakObjectsHashTable];[weak addObject:objects[key]];refs[key]=weak;}
        _references=[refs copy];
    }return self;
}
- (NSDictionary *)snapshot {
    NSMutableDictionary *out=[NSMutableDictionary new];
    for(NSString *key in _references){NSUInteger count=0;@autoreleasepool{count=[_references[key]allObjects].count;}out[key]=@(count);}
    return out;
}
@end
