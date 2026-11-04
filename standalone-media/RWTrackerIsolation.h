#pragma once
#import "RWTrackerPolicy.h"
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/torrent_handle.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/torrent_status.hpp>
#include <algorithm>
#include <vector>

// Normalized URLs and peer endpoints stay in memory. Diagnostics expose counts
// only: tracker paths and query strings can contain private authentication data.
inline std::vector<libtorrent::announce_entry> RWBoundedTrackers(
    std::vector<libtorrent::announce_entry> const &input) {
    std::vector<libtorrent::announce_entry> out;
    NSMutableSet *seen=[NSMutableSet new];size_t scanned=0;
    for(auto const &entry:input){
        if(scanned++>=256||out.size()>=16)break;
        if(entry.url.size()>2048)continue;
        NSString *url=[[NSString alloc]initWithBytes:entry.url.data() length:entry.url.size() encoding:NSUTF8StringEncoding];
        NSString *key=[RWTrackerPolicy canonicalKeyForURL:url allowHTTPS:[RWTrackerPolicy supportsHTTPS]];
        if(!key||[seen containsObject:key])continue;
        NSRange colon=[url rangeOfString:@":"];
        NSString *usable=[[[url substringToIndex:colon.location]lowercaseString]stringByAppendingString:[url substringFromIndex:colon.location]];
        auto normalized=entry;normalized.url=usable.UTF8String;
        out.push_back(normalized);[seen addObject:key];
    }
    std::stable_sort(out.begin(),out.end(),[](libtorrent::announce_entry const &a,libtorrent::announce_entry const &b){return a.tier<b.tier;});
    return out;
}

struct RWPrivateTrackers {
    bool restricted=false,draining=false;
    size_t pending=0;
    std::vector<libtorrent::announce_entry> candidates;
    size_t current=0;
    unsigned switches=0;

    void prepare(libtorrent::add_torrent_params &params) {
        *this=RWPrivateTrackers();
        std::vector<libtorrent::announce_entry> all;
        if(params.ti){auto const &declared=params.ti->trackers();
            all.assign(declared.begin(),declared.begin()+std::min(size_t(256),declared.size()));}
        bool declaredPrivate=params.ti&&params.ti->priv()&&!params.ti->trackers().empty();
        for(size_t i=0;!declaredPrivate&&i<params.trackers.size()&&all.size()<256;i++){
            libtorrent::announce_entry entry(params.trackers[i]);
            entry.tier=i<params.tracker_tiers.size()?std::max(0,std::min(255,params.tracker_tiers[i])):0;
            all.push_back(entry);
        }
        auto normalized=RWBoundedTrackers(all);
        restricted=params.ti&&params.ti->priv();
        if(restricted){
            candidates=normalized;
            // Explicit magnet peers and saved peers are not authorization from
            // the current private tracker. Keep saved verified file progress.
            params.peers.clear();
            params.flags|=libtorrent::torrent_flags::disable_dht|libtorrent::torrent_flags::disable_pex|libtorrent::torrent_flags::disable_lsd;
        }
        params.flags|=libtorrent::torrent_flags::override_trackers;
        params.trackers.clear();params.tracker_tiers.clear();
        size_t count=restricted?std::min(size_t(1),normalized.size()):normalized.size();
        for(size_t i=0;i<count;i++){params.trackers.push_back(normalized[i].url);params.tracker_tiers.push_back(normalized[i].tier);}
    }

    void settle(libtorrent::torrent_handle handle) {
        if(!draining)return;
        // pause() first queues the old tracker's stopped announce. Keep the
        // torrent paused until every old endpoint request has completed or
        // failed under libtorrent's existing stop_tracker_timeout. A stopped
        // reply can still contain peers; clear those before resuming elsewhere.
        auto old=handle.trackers();
        for(auto const &tracker:old)for(auto const &endpoint:tracker.endpoints)
            if(endpoint.updating)return;
        handle.clear_peers();
        handle.replace_trackers(candidates.empty()?std::vector<libtorrent::announce_entry>{}:std::vector<libtorrent::announce_entry>{candidates[pending]});
        if(pending!=current)++switches;
        current=pending;draining=false;handle.resume();
    }

    void transition(libtorrent::torrent_handle handle,size_t index) {
        pending=index;draining=true;
        handle.pause();handle.clear_peers();
        handle.set_flags(libtorrent::torrent_flags::disable_dht|libtorrent::torrent_flags::disable_pex|libtorrent::torrent_flags::disable_lsd);
        settle(handle);
    }

    void learnedPrivate(libtorrent::torrent_handle handle) {
        if(restricted)return;
        candidates=RWBoundedTrackers(handle.trackers());restricted=true;current=0;
        transition(handle,0);
    }

    bool failed(libtorrent::torrent_handle handle,std::string const &url) {
        if(!restricted||draining||current>=candidates.size()||candidates[current].url!=url||current+1>=candidates.size())return false;
        if(handle.status().flags&libtorrent::torrent_flags::paused)return false;
        transition(handle,current+1);
        return true;
    }
};
