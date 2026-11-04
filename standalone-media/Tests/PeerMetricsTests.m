#import <Foundation/Foundation.h>
#import "../RWPlaybackMetrics.h"
static int checks=0,failures=0;
static void check(BOOL pass,const char*name){checks++;if(!pass){failures++;fprintf(stderr,"FAIL: %s\n",name);}}
int main(){@autoreleasepool{
 RWPlaybackMetrics*m=[[RWPlaybackMetrics alloc]initAtUptime:10];
 NSMutableDictionary*totals=[@{@"payload_bytes":@100,@"useful_peers":@1}mutableCopy];
 NSMutableDictionary*evidence=[@{@"available":@YES,@"unique":totals,@"trackers":@[@{@"tracker_id":@1,@"payload_bytes":@100}]}mutableCopy];
 NSMutableDictionary*sample=[@{@"infoHash":@"1111111111111111111111111111111111111111",@"fileIdx":@0,@"peer_discovery":evidence}mutableCopy];
 [m recordDiscovery:@{@"session_id":@"A",@"candidates":@[sample]}uptime:11];
 NSDictionary*first=[m snapshot];NSDictionary*record=[first[@"torrent_probes"]firstObject];
 check([record[@"peer_discovery"]isEqual:evidence],"Per-tracker evidence retained in source history");
 totals[@"payload_bytes"]=@200;
 check([record[@"peer_discovery"][@"unique"][@"payload_bytes"]intValue]==100,"Nested producer changes cannot rewrite prior evidence");
 sample[@"reason"]=@"Too slow";
 [m recordDiscovery:@{@"session_id":@"A",@"failures":@[sample]}uptime:12];
 record=[[m snapshot][@"torrent_probes"]firstObject];
 check([record[@"failed"]boolValue]&&[record[@"peer_discovery"][@"unique"][@"payload_bytes"]intValue]==200,"Failure retains final useful-peer evidence");
 check([first[@"torrent_probes"][0][@"peer_discovery"][@"unique"][@"payload_bytes"]intValue]==100,"Later failure leaves earlier published sample unchanged");
 [m recordDiscovery:@{@"session_id":@"B",@"candidates":@[sample]}uptime:13];
 check([[m snapshot][@"torrent_probes"]count]==2,"Same hash in another engine owns separate evidence");
 evidence[@"oversized"]=[@"X" stringByPaddingToLength:40000 withString:@"X" startingAtIndex:0];
 [m recordDiscovery:@{@"session_id":@"A",@"candidates":@[sample]}uptime:14];
 BOOL rejected=NO;for(NSDictionary*r in [m snapshot][@"torrent_probes"])if([r[@"engine_session_id"]isEqual:@"A"])rejected=!r[@"peer_discovery"]&&[r[@"peer_discovery_status"]isEqual:@"invalid_or_oversize"];
 check(rejected,"Oversized update removes stale evidence and marks rejection");
 sample[@"peer_discovery"]=@{@"available":@NO};
 [m recordDiscovery:@{@"session_id":@"A",@"candidates":@[sample]}uptime:15];
 BOOL unavailable=NO;for(NSDictionary*r in [m snapshot][@"torrent_probes"])if([r[@"engine_session_id"]isEqual:@"A"])unavailable=[r[@"peer_discovery"]isEqual:@{@"available":@NO}]&&!r[@"peer_discovery_status"];
 check(unavailable,"Unavailable observer remains explicit without stale rejection");
 NSMutableDictionary *tcp=[@{@"established":@2,@"choked_established":@1,@"requests_unsent":@7}mutableCopy];
 sample[@"transport"]=@{@"tcp":tcp,@"session_limits":@{@"tcp_download_bytes_per_second":@30000}};
 [m recordDiscovery:@{@"session_id":@"A",@"candidates":@[sample]}uptime:16];
 NSDictionary *transportFirst=nil;for(NSDictionary*r in [m snapshot][@"torrent_probes"])if([r[@"engine_session_id"]isEqual:@"A"])transportFirst=r;
 check([transportFirst[@"transport"][@"tcp"][@"requests_unsent"]intValue]==7,"Discovery request queues survive metric recording");
 tcp[@"requests_unsent"]=@0;
 check([transportFirst[@"transport"][@"tcp"][@"requests_unsent"]intValue]==7,"Prior queue evidence cannot be rewritten by producer");
 [m recordDiscovery:@{@"session_id":@"A",@"failures":@[sample]}uptime:17];
 NSDictionary *final=nil;for(NSDictionary*r in [m snapshot][@"torrent_probes"])if([r[@"engine_session_id"]isEqual:@"A"])final=r;
 check([final[@"failed"]boolValue]&&final[@"transport"]&&[final[@"transport"][@"tcp"][@"requests_unsent"]intValue]==0,"Terminal source failure owns latest queue evidence");
 sample[@"transport"]=@{@"too_big":[@"x" stringByPaddingToLength:9000 withString:@"x" startingAtIndex:0]};
 [m recordDiscovery:@{@"session_id":@"A",@"candidates":@[sample]}uptime:18];
 BOOL transportRejected=NO;for(NSDictionary*r in [m snapshot][@"torrent_probes"])if([r[@"engine_session_id"]isEqual:@"A"])transportRejected=!r[@"transport"]&&[r[@"transport_status"]isEqual:@"invalid_or_oversize"];
 check(transportRejected,"Oversize transport update cannot leave misleading old queue data");
 check([NSJSONSerialization isValidJSONObject:[m snapshot]],"Peer diagnostics remain valid JSON");
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
