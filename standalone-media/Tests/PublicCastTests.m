#import <Foundation/Foundation.h>
#import "../RWCast.h"
int main(int argc,char **argv){@autoreleasepool{
    __block int checks=0,failures=0;void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *label){checks++;if(!ok){failures++;fprintf(stderr,"FAIL %s\n",label.UTF8String);}};
    NSString *html=[NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:nil];
    NSDictionary *meta=@{@"id":@"tt37510326",@"moviedb_id":@1281331,@"name":@"The Social Reckoning",@"releaseInfo":@"2026",@"type":@"movie"};
    NSArray *people=[RWCast publicMoviePeople:html meta:meta];
    check(people.count==12,@"Real public cast page produces a bounded full cast rail");
    check([people.firstObject[@"name"]isEqual:@"Mikey Madison"],@"Billing order comes from the exact movie page");
    check([people[1][@"role"]isEqual:@"Jeff Horwitz"],@"Character roles parsed from the cast section");
    check([people.firstObject[@"image"]containsString:@"w132_and_h132_face"],@"Small high-density portrait is selected");
    check([people.firstObject[@"sourceURL"]containsString:@"/movie/1281331-"]&&[people.firstObject[@"credit"]length]>10,@"Source attribution remains attached to portraits");
    NSMutableDictionary *wrong=[meta mutableCopy];wrong[@"moviedb_id"]=@27205;check(![RWCast publicMoviePeople:html meta:wrong].count,@"Wrong numeric movie ID cannot inherit these actors");
    wrong=[meta mutableCopy];wrong[@"name"]=@"An unrelated film";check(![RWCast publicMoviePeople:html meta:wrong].count,@"A title mismatch rejects stale or redirected content");
    wrong=[meta mutableCopy];wrong[@"releaseInfo"]=@"2010";check(![RWCast publicMoviePeople:html meta:wrong].count,@"Remakes and mismatched release years are rejected");
    NSString *bad=[html stringByReplacingOccurrencesOfString:@"https://media.themoviedb.org" withString:@"https://media.themoviedb.org.evil.invalid"];
    NSArray *noPhotos=[RWCast publicMoviePeople:bad meta:meta];BOOL clean=YES;for(NSDictionary *p in noPhotos)if([p[@"image"]length])clean=NO;check(noPhotos.count==12&&clean,@"A lookalike image host cannot supply portraits");
    check(![RWCast publicMoviePeople:@"<html>Challenge or login required</html>" meta:meta].count,@"Login/challenge markup never gets mistaken for cast");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
