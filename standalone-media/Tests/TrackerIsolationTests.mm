#import <Foundation/Foundation.h>
#include "../RWTrackerIsolation.h"
#import "../RWTrackerPolicy.m"
#include <libtorrent/create_torrent.hpp>
#include <libtorrent/file_storage.hpp>
namespace lt=libtorrent;
static NSMutableArray *rows;
static void Check(NSString *name,bool ok){[rows addObject:@{@"case":name,@"passed":@(ok)}];}
static std::shared_ptr<lt::torrent_info> Info(bool priv,bool trackers=true){
    lt::file_storage files;files.add_file("owned.mp4",16384);
    lt::create_torrent create(files,16384);create.set_priv(priv);create.set_hash(lt::piece_index_t(0),lt::sha1_hash());
    if(trackers){create.add_tracker("https://private.example/opaque?key=Fixture",0);create.add_tracker("https://backup.example/a",1);}
    return std::make_shared<lt::torrent_info>(create.generate());
}
int main(){@autoreleasepool{
    rows=[NSMutableArray new];
    lt::add_torrent_params params;params.ti=Info(true);params.info_hash=params.ti->info_hash();params.save_path="unchanged";
    params.peers.emplace_back(lt::make_address("192.0.2.1"),6881);
    params.have_pieces.resize(1,true);params.file_priorities.push_back(lt::dont_download);
    params.trackers={"http://unrelated.example/announce"};
    RWPrivateTrackers policy;policy.prepare(params);
    Check(@"Private metadata does not inherit unrelated magnet trackers",policy.candidates.size()==2);
    Check(@"Known private torrent clears explicit and resumed peers",params.peers.empty());
    Check(@"Private torrent submits one tracker",params.trackers.size()==1&&params.trackers[0]=="https://private.example/opaque?key=Fixture");
    Check(@"DHT PEX and LSD disabled for known private torrent",bool(params.flags & lt::torrent_flags::disable_dht)&&bool(params.flags & lt::torrent_flags::disable_pex)&&bool(params.flags & lt::torrent_flags::disable_lsd));
    Check(@"Verified progress and requested storage are unchanged",params.have_pieces.size()==1&&params.have_pieces[lt::piece_index_t(0)]&&params.save_path=="unchanged"&&params.file_priorities[0]==lt::dont_download);
    Check(@"Metadata hash unchanged",params.info_hash==params.ti->info_hash());
    Check(@"Private opaque token preserved internally",policy.candidates[0].url=="https://private.example/opaque?key=Fixture");
    lt::add_torrent_params publicParams;publicParams.ti=Info(false);publicParams.trackers={"http://additional.example/announce"};
    publicParams.peers.emplace_back(lt::make_address("192.0.2.2"),6881);policy.prepare(publicParams);
    Check(@"Public metadata and supplied trackers retained",publicParams.trackers.size()==3);
    Check(@"Public explicit peer retained",publicParams.peers.size()==1);
    Check(@"Public discovery flags unchanged",!(publicParams.flags&(lt::torrent_flags::disable_dht|lt::torrent_flags::disable_pex|lt::torrent_flags::disable_lsd)));
    Check(@"Reusing policy does not retain old private state",!policy.restricted&&policy.candidates.empty()&&policy.switches==0);
    lt::add_torrent_params privateMagnet;privateMagnet.ti=Info(true,false);privateMagnet.trackers={"HTTPS://tracker.example/a"};policy.prepare(privateMagnet);
    Check(@"Private metadata without tracker can use explicitly supplied tracker",privateMagnet.trackers.size()==1&&privateMagnet.trackers[0]=="https://tracker.example/a");
    std::vector<lt::announce_entry> input;
    for(auto url:{"http://EXAMPLE.com:80/a","HTTP://example.com/a","file:///not-a-tracker","https://example.com/%ZZ","udp://example.com:0/a","https://other.example/a#bad"})input.emplace_back(url);
    auto normalized=RWBoundedTrackers(input);
    Check(@"Imported trackers use canonical validation and deduplication",normalized.size()==1&&normalized[0].url=="http://EXAMPLE.com:80/a");
    input.clear();for(int i=0;i<40;i++)input.emplace_back("https://example.com/"+std::to_string(i));
    Check(@"Imported tracker count bounded",RWBoundedTrackers(input).size()==16);
    input.assign(256,lt::announce_entry("file:///invalid"));input.emplace_back("https://example.com/late");
    Check(@"Input scan bounded",RWBoundedTrackers(input).empty());
    input={lt::announce_entry("https://second.example/a"),lt::announce_entry("https://first.example/a")};input[0].tier=2;input[1].tier=0;
    Check(@"Tracker tiers preserve primary before backup",RWBoundedTrackers(input)[0].url=="https://first.example/a");
    NSUInteger failures=0;for(NSDictionary *row in rows)if(![row[@"passed"]boolValue])failures++;
    NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"checks":@(rows.count),@"failures":@(failures),@"results":rows} options:0 error:nil];
    puts([[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding].UTF8String);return failures?1:0;
}}
