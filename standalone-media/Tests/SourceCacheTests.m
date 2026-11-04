#import <Foundation/Foundation.h>
#import "../RWSourceCache.h"
static int checks=0,failures=0;
static void check(BOOL ok,const char *message){checks++;if(!ok){failures++;fprintf(stderr,"FAIL: %s\n",message);}}
int main(){@autoreleasepool{
    RWSourceCache *c=[[RWSourceCache alloc]initWithCapacity:2];
    NSArray *magnet=@[@{@"url":@"magnet:?xt=urn:btih:1111111111111111111111111111111111111111"}];
    [c storeSources:magnet forKey:@"main:episode1" now:0];
    check([c sourcesForKey:@"main:episode1" now:120 freshOnly:YES].count==1,"Returning to details after two minutes reuses a source listing");
    check(![c sourcesForKey:@"main:episode1" now:180 freshOnly:YES],"Old listing triggers a refresh");
    check([c sourcesForKey:@"main:episode1" now:180 freshOnly:NO].count==1,"Known magnet can connect while provider refreshes");
    check(![c sourcesForKey:@"kids:episode1" now:180 freshOnly:NO],"Profile identities cannot share a candidate entry");
    [c storeSources:magnet forKey:@"main:episode2" now:190];
    [c sourcesForKey:@"main:episode1" now:191 freshOnly:NO];
    [c storeSources:magnet forKey:@"main:episode3" now:192];
    check([c sourcesForKey:@"main:episode1" now:193 freshOnly:NO].count==1,"Inserting a new title preserves the recently viewed title");
    check(![c sourcesForKey:@"main:episode2" now:193 freshOnly:NO],"Only the least recently used title is evicted");
    [c storeSources:magnet forKey:@"main:episode3" now:194];
    check([c sourcesForKey:@"main:episode1" now:195 freshOnly:NO].count==1,"Updating an existing title at capacity causes no eviction");
    check(![c sourcesForKey:@"main:episode1" now:1800 freshOnly:NO],"Reading stale entries does not extend their expiry");
    NSArray *mixed=[magnet arrayByAddingObject:@{@"url":@"https://publisher.example/temporary.mp4?token=fixture"}];
    [c storeSources:mixed forKey:@"main:mixed" now:2000];
    check(![c sourcesForKey:@"main:mixed" now:2001 freshOnly:YES],"Temporary URLs require a new provider lookup even beside magnets");
    NSArray *cached=[c sourcesForKey:@"main:mixed" now:2001 freshOnly:NO];
    check(cached.count==1&&[cached[0][@"url"]hasPrefix:@"magnet:"],"Temporary credentials and expired URLs are not served from cache");
    [c storeSources:@[] forKey:@"main:mixed" now:2002];
    check([c sourcesForKey:@"main:mixed" now:2003 freshOnly:NO].count==1,"An empty response does not erase useful candidates");
    check(![c sourcesForKey:@"main:mixed" now:1999 freshOnly:NO],"A backwards clock cannot make an entry fresh forever");
    [c removeAllObjects];check(![c sourcesForKey:@"main:episode3" now:2000 freshOnly:NO],"Profile reset releases cached entries");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
