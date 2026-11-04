#import <Foundation/Foundation.h>
// A shared predicate keeps ranking, contextual evidence and stable Home merges
// from treating filmographies/editorial lists as narrative franchises.
static inline BOOL RWIsNarrativeFranchise(id reference) {
    id value=[reference isKindOfClass:NSDictionary.class]?reference[@"instanceOf"]:nil;
    NSArray *types=[value isKindOfClass:NSArray.class]?value:@[];
    if([types containsObject:@"Q13406463"])return NO;
    for(NSString *type in @[@"Q196600",@"Q24856",@"Q13593818",@"Q130371093",@"Q5398426"])
        if([types containsObject:type])return YES;
    return NO;
}
