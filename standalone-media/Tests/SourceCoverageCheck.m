#import <Foundation/Foundation.h>
#import "../RWSourcePolicy.h"
int main(int argc,char **argv){@autoreleasepool{
    [RWSourcePolicy setLegacyEnabled:getenv("RW_TEST_LEGACY")!=NULL];[RWSourcePolicy setNativeSurroundEnabled:getenv("RW_TEST_SURROUND")!=NULL];
    NSMutableArray *results=[NSMutableArray new];
    for(int i=1;i<argc;i++){
        NSDictionary *j=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[i])] options:0 error:nil];NSMutableArray *all=[NSMutableArray new];
        for(NSDictionary *r in j[@"streams"]){NSDictionary *n=[RWSourcePolicy normalize:r provider:@"Torrentio"];if(n)[all addObject:n];}
        if(j[@"data"])[all addObjectsFromArray:[RWSourcePolicy ytsSources:j imdbID:@"tt6262770"]];
        NSMutableArray *rows=[NSMutableArray new];for(NSDictionary *source in all){NSDictionary *s=[RWSourcePolicy evaluate:source quality:0 freeBytes:0];[rows addObject:@{@"filename":s[@"filename"]?:@"",@"release":s[@"release"]?:@"",@"eligible":s[@"eligible"]?:@NO,@"reason":s[@"rejection"]?:@"",@"seeders":s[@"seeders"]?:@0}];}
        NSArray *ranked=[RWSourcePolicy rank:all quality:0 freeBytes:0];NSMutableArray *top=[NSMutableArray new];for(NSUInteger n=0;n<MIN((NSUInteger)6,ranked.count);n++){NSDictionary *s=ranked[n];[top addObject:@{@"filename":s[@"filename"]?:@"",@"release":s[@"release"]?:@"",@"quality":s[@"resolution"]?:@0,@"seeders_hint":s[@"seeders"]?:@0}];}
        [results addObject:@{@"fixture":[@(argv[i])lastPathComponent],@"eligible":@(ranked.count),@"top_candidates":top,@"sources":rows}];
    }
    puts([[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:results options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding].UTF8String);return 0;
}}
