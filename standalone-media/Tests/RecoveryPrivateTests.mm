#import <Foundation/Foundation.h>
#import "../RWDeviceExercise.m"
#import "../RWTrackerPolicy.m"
#include "../RWTrackerIsolation.h"
#include <libtorrent/magnet_uri.hpp>
#include <libtorrent/create_torrent.hpp>
#include <libtorrent/bencode.hpp>
#include <cstring>
int main(int argc,char **argv){@autoreleasepool{
 if(argc<2)return 2;int checks=0,failures=0;
#define CHECK(x) do{checks++;if(!(x)){failures++;fprintf(stderr,"FAIL line%d\n",__LINE__);}}while(0)
 namespace lt=libtorrent;lt::error_code error;
 NSString *url=argc>2?@(argv[2]):[RWDeviceExercise recoverySource][@"url"];
 auto params=lt::parse_magnet_uri(url.UTF8String,error);CHECK(!error);
 auto info=std::make_shared<lt::torrent_info>(argv[1],error);CHECK(!error);
 if(error)return 2;CHECK(info->priv());CHECK(info->info_hash()==params.info_hash);
 params.ti=info;RWPrivateTrackers policy;policy.prepare(params);
 CHECK(policy.restricted);CHECK(params.peers.empty());
 CHECK(policy.candidates.size()==1);
 CHECK(params.trackers.size()==1&&params.trackers[0]=="http://127.0.0.1:18884/announce");
 CHECK(bool(params.flags&lt::torrent_flags::disable_dht));
 CHECK(bool(params.flags&lt::torrent_flags::disable_pex));
 CHECK(bool(params.flags&lt::torrent_flags::disable_lsd));
 CHECK(info->num_files()==1&&info->total_size()==70159995&&info->piece_length()==1048576);
 // The production engine reserializes metadata when selecting the video.
 // A fixture without a creation date acquires one and breaks exact cleanup.
 NSData *original=[NSData dataWithContentsOfFile:@(argv[1])];
 lt::create_torrent creator(*info);std::vector<char> encoded;
 lt::bencode(std::back_inserter(encoded),creator.generate());
 CHECK(info->creation_date()>0);
 CHECK(original&&original.length==encoded.size()&&!memcmp(original.bytes,encoded.data(),encoded.size()));
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
