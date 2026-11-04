#import "RWHomeCategoryPolicy.h"
static NSArray *List(id v){return [v isKindOfClass:NSArray.class]?v:@[];}
static NSString *Text(id v){return [v isKindOfClass:NSString.class]?v:@"";}
static NSDictionary *Category(NSString *key,NSString *title,NSString *type,NSArray *any,NSArray *all,NSUInteger minutes){return @{@"id":[@"category-" stringByAppendingString:key],@"recipe":@"category",@"title":title,@"mediaType":type,@"anyGenres":any,@"allGenres":all,@"maxMinutes":@(minutes),@"providerGenre":all.firstObject?:any.firstObject?:@"",@"minimumCount":@6};}
@implementation RWHomeCategoryPolicy
+ (NSArray *)categoriesForKids:(BOOL)kids {
    if(kids)return @[
        Category(@"animated-adventures",@"Animated Adventures",@"movie",@[],@[@"Animation",@"Adventure"],0),
        Category(@"family-laughs",@"Family Laughs",@"movie",@[@"Comedy"],@[],0),
        Category(@"magic-wonder",@"Magic & Wonder",@"movie",@[@"Fantasy"],@[],0),
        Category(@"cartoon-time",@"Cartoon Time",@"series",@[@"Animation"],@[],0),
        Category(@"kids-adventure",@"Big Adventures",@"series",@[@"Adventure",@"Action"],@[],0),
        Category(@"kids-short-comedy",@"Little Laughs, Short Episodes",@"series",@[@"Comedy"],@[],30),
        Category(@"short-family-movies",@"90-Minute Movie Night",@"movie",@[],@[],90),
        Category(@"family-animation",@"Animated Movie Night",@"movie",@[@"Animation"],@[],0)];
    return @[
        Category(@"movie-action",@"Action & Adventure",@"movie",@[@"Action",@"Adventure"],@[],0),
        Category(@"movie-drama",@"Stories That Stay With You",@"movie",@[@"Drama"],@[],0),
        Category(@"series-drama",@"Drama Series",@"series",@[@"Drama"],@[],0),
        Category(@"series-crime",@"Crime & Mystery Series",@"series",@[@"Crime",@"Mystery"],@[],0),
        Category(@"movie-comedy",@"Bring on the Laughs",@"movie",@[@"Comedy"],@[],0),
        Category(@"series-comedy",@"Comedy Series",@"series",@[@"Comedy"],@[],0),
        Category(@"movie-fantasy",@"Sci-Fi & Fantasy Movies",@"movie",@[@"Sci-Fi",@"Science Fiction",@"Fantasy"],@[],0),
        Category(@"series-fantasy",@"Sci-Fi & Fantasy Series",@"series",@[@"Sci-Fi",@"Science Fiction",@"Fantasy"],@[],0),
        Category(@"movie-suspense",@"A Little Suspense",@"movie",@[@"Thriller",@"Mystery"],@[],0),
        Category(@"short-movies",@"90-Minute Movies",@"movie",@[],@[],90),
        Category(@"movie-animation",@"Animated Worlds",@"movie",@[@"Animation"],@[],0),
        Category(@"series-documentary",@"Documentary Series",@"series",@[@"Documentary"],@[],0),
        Category(@"movie-romance",@"Love on Screen",@"movie",@[@"Romance"],@[],0),
        Category(@"short-comedy",@"Short Episodes, Big Laughs",@"series",@[@"Comedy"],@[],30)];
}
+ (BOOL)matches:(NSDictionary *)meta category:(NSDictionary *)category {
    if(![meta[@"type"]isEqual:category[@"mediaType"]])return NO;
    NSMutableSet *genres=[NSMutableSet new];for(id v in List(meta[@"genres"]))if(Text(v).length)[genres addObject:[v lowercaseString]];
    for(id v in List([meta[@"discovery"]isKindOfClass:NSDictionary.class]?meta[@"discovery"][@"genres"]:nil))if([v isKindOfClass:NSDictionary.class]&&Text(v[@"name"]).length)[genres addObject:[v[@"name"]lowercaseString]];
    // Animation can describe CGI in a documentary, not just a cartoon.
    if([category[@"id"]isEqual:@"category-cartoon-time"]&&([genres containsObject:@"documentary"]||[genres containsObject:@"documentary television series"]||[genres containsObject:@"nature documentary"]))return NO;
    for(NSString *g in List(category[@"allGenres"]))if(![genres containsObject:g.lowercaseString])return NO;
    NSArray *any=List(category[@"anyGenres"]);BOOL match=!any.count;for(NSString *g in any)if([genres containsObject:g.lowercaseString])match=YES;if(!match)return NO;
    NSUInteger limit=[category[@"maxMinutes"]unsignedIntegerValue];if(limit){
        // Provider runtime is expressed in minutes. Require the complete value,
        // not a leading number parsed out of an unknown unit or a range.
        NSString *runtime=Text(meta[@"runtime"]);NSRegularExpression *re=[NSRegularExpression regularExpressionWithPattern:@"^([1-9][0-9]{0,2})\\s*(?:min|mins|minutes)$" options:NSRegularExpressionCaseInsensitive error:nil];NSTextCheckingResult *hit=[re firstMatchInString:runtime options:0 range:NSMakeRange(0,runtime.length)];
        if(!hit||[[runtime substringWithRange:[hit rangeAtIndex:1]]integerValue]>(NSInteger)limit)return NO;
    }return YES;
}
@end
