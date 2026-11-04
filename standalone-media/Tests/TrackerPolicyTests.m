#import <Foundation/Foundation.h>
#import "../RWTrackerPolicy.h"
#import "../RWSourcePolicy.h"
static NSMutableArray *results;
static void Check(NSString *name,BOOL passed){[results addObject:@{@"case":name,@"passed":@(passed)}];}
static NSString *Key(NSString *s,BOOL tls){return [RWTrackerPolicy canonicalKeyForURL:s allowHTTPS:tls];}
static NSArray *URLs(NSArray *a,BOOL tls,NSUInteger limit){return [RWTrackerPolicy URLsFromSourceEntries:a allowHTTPS:tls limit:limit];}
static NSArray *Trackers(NSArray *sources) {
    NSDictionary *normal=[RWSourcePolicy normalize:@{@"infoHash":@"0123456789012345678901234567890123456789",@"sources":sources} provider:@"Fixture"];
    NSURLComponents *parts=[NSURLComponents componentsWithString:normal[@"url"]];
    NSMutableArray *values=[NSMutableArray new];
    for(NSURLQueryItem *item in parts.queryItems)if([item.name isEqual:@"tr"]&&item.value)[values addObject:item.value];
    return values;
}
int main(void){@autoreleasepool{
 results=[NSMutableArray new];
 Check(@"Uppercase first scheme becomes usable by libtorrent",[URLs(@[@"tracker:HTTPS://Example.COM/Token%2FKey?x=A%2BB"],YES,4).firstObject isEqual:@"https://Example.COM/Token%2FKey?x=A%2BB"]);
 Check(@"UDP uppercase scheme corrected without changing opaque data",[URLs(@[@"tracker:UDP://Example.COM:80/Token?x=A%2FB"],NO,4).firstObject isEqual:@"udp://Example.COM:80/Token?x=A%2FB"]);
 Check(@"HTTPS requires explicit capability",Key(@"https://example.com/a",NO)==nil&&Key(@"https://example.com/a",YES)!=nil);
 Check(@"HTTPS default port and empty path equivalent",[Key(@"https://EXAMPLE.com",YES)isEqual:Key(@"https://example.com:443/",YES)]);
 Check(@"Scheme separates HTTP and HTTPS",![Key(@"http://example.com:443/a",YES)isEqual:Key(@"https://example.com/a",YES)]);
 Check(@"Username and password are identity",![Key(@"https://one:owned@example.com/a",YES)isEqual:Key(@"https://two:owned@example.com/a",YES)]&&![Key(@"https://one:a@example.com/a",YES)isEqual:Key(@"https://one:b@example.com/a",YES)]);
 Check(@"Query order stays opaque",![Key(@"udp://example.com:80/a?x=1&y=2",NO)isEqual:Key(@"udp://example.com:80/a?y=2&x=1",NO)]);
 Check(@"Escaped slash is not path separator",![Key(@"https://example.com/A%2FB",YES)isEqual:Key(@"https://example.com/A/B",YES)]);
 Check(@"Malformed percent rejected",Key(@"https://example.com/%ZZ",YES)==nil&&Key(@"https://example.com/%",YES)==nil);
 Check(@"IPv6 address accepted",Key(@"udp://[::1]:1337/announce",NO)!=nil);
 Check(@"Missing UDP port rejected",Key(@"udp://example.com/announce",YES)==nil);
 Check(@"Control and whitespace rejected",Key(@"https://example.com/a\nb",YES)==nil&&Key(@"https://example.com/a b",YES)==nil);
 Check(@"Fragment and oversized port rejected",Key(@"https://example.com:65536/",YES)==nil&&Key(@"https://example.com/#",YES)==nil);
 NSMutableArray *many=[NSMutableArray new];for(int i=0;i<256;i++)[many addObject:@"not a tracker"];
 [many addObject:@"tracker:https://example.com/late"];
 Check(@"Provider scanning bounded to256",URLs(many,YES,4).count==0);
 many[255]=@"tracker:https://example.com/last";
 Check(@"Last admitted input is processed",URLs(many,YES,4).count==1);
 [many removeAllObjects];for(int i=0;i<20;i++)[many addObject:[NSString stringWithFormat:@"tracker:https://example.com/%d",i]];
 Check(@"Absolute output cap16",URLs(many,YES,99).count==16);
 Check(@"Zero allowance emits nothing",URLs(many,YES,0).count==0);
    NSString *one=@"tracker:udp://first.example:1337/announce",*two=@"tracker:udp://second.example:451/announce";
    NSArray *v=Trackers(@[one,one,one,one,two]);
    Check(@"Duplicate input cannot consume all four unique tracker slots",v.count==2&&[v containsObject:@"udp://second.example:451/announce"]);
    Check(@"Scheme/host case and explicit default HTTP port deduplicate",Trackers(@[@"tracker:http://Example.COM:80/announce",@"tracker:HTTP://example.com/announce"]).count==1);
    Check(@"Port zero rejected",Trackers(@[@"tracker:udp://example.com:0/announce"]).count==0);
    Check(@"Out-of-range port rejected",Trackers(@[@"tracker:udp://example.com:65536/announce"]).count==0);
    Check(@"Fragment rejected",Trackers(@[@"tracker:http://example.com/announce#fragment"]).count==0);
    Check(@"Non-tracker transport rejected",Trackers(@[@"tracker:file:///tmp/announce",@"tracker:ftp://example.com/announce"]).count==0);
    Check(@"Distinct path and auth query retained",Trackers(@[@"tracker:udp://example.com:80/a?auth=fixture-A",@"tracker:udp://example.com:80/a?auth=fixture-B",@"tracker:udp://example.com:80/b?auth=fixture-A"]).count==3);
    NSString *opaque=@"http://example.com/Token%2Fpart/announce?key=Fixture%2BKey&order=2&order=1";
    Check(@"Opaque escaping/query order preserved",[Trackers(@[[@"tracker:" stringByAppendingString:opaque]]).firstObject isEqual:opaque]);
    Check(@"Provider tracker cap retained",Trackers(@[one,two,@"tracker:http://third.example/a",@"tracker:http://fourth.example/a",@"tracker:http://fifth.example/a"]).count==4);
    NSString *longURL=[@"tracker:http://example.com/" stringByAppendingString:[@"x" stringByPaddingToLength:3000 withString:@"x" startingAtIndex:0]];
    Check(@"Oversized tracker rejected",Trackers(@[longURL]).count==0);
    NSString *magnet=@"magnet:?xt=urn:btih:0123456789012345678901234567890123456789&tr=http%3A%2F%2Fprivate.example%2Fannounce%3Fkey%3DFixture&x.pe=127.0.0.1%3A1234";
    NSDictionary *raw=[RWSourcePolicy normalize:@{@"url":magnet} provider:@"Saved source"];
    Check(@"Imported valid private magnet keeps explicit tracker and peer bytes",[raw[@"url"]isEqual:magnet]);
 NSUInteger failed=0;for(NSDictionary *r in results)if(![r[@"passed"]boolValue])failed++;
 NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"checks":@(results.count),@"failures":@(failed),@"cases":results} options:NSJSONWritingPrettyPrinted error:nil];
 puts([[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding].UTF8String);return failed?1:0;
}}
