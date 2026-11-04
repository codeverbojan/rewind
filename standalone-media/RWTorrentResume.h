#pragma once
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/torrent_info.hpp>
// Only restore download progress belonging to the expected infohash. Keep the
// caller's save path, trackers, priorities, flags and web-seed policy intact.
inline bool RWRestoreTorrentProgress(libtorrent::add_torrent_params &target,
                                     libtorrent::add_torrent_params const &saved) {
    if(!target.ti||saved.info_hash!=target.info_hash||saved.have_pieces.size()>target.ti->num_pieces())return false;
    int count=target.ti->num_pieces(),pieceBytes=target.ti->piece_length();
    if(count<=0||pieceBytes<=0)return false;
    int blocks=pieceBytes/16384+(pieceBytes%16384!=0),padded=(blocks+7)/8*8;
    // libtorrent's writer rounds masks to bytes; its reader restores all bits
    // in those bytes. Validate every mask before mutating the caller. Only
    // zero padding is allowed, including beyond a short final piece.
    for(auto const &piece:saved.unfinished_pieces){
        if(int(piece.first)<0||int(piece.first)>=count||piece.second.size()>padded)return false;
        int bytes=target.ti->piece_size(piece.first),actual=bytes/16384+(bytes%16384!=0);
        for(int bit=actual;bit<piece.second.size();++bit)if(piece.second[bit])return false;
    }
    target.have_pieces=saved.have_pieces;
    target.unfinished_pieces=saved.unfinished_pieces;
    for(auto &piece:target.unfinished_pieces){
        int bytes=target.ti->piece_size(piece.first),actual=bytes/16384+(bytes%16384!=0);
        if(piece.second.size()>actual)piece.second.resize(actual);
    }
    // Retain a bounded list of previously known peers; never restore settings
    // or arbitrary output paths from serialized state.
    for(auto const &peer:saved.peers){
        auto address=peer.address();if(address.is_unspecified()||address.is_loopback()||address.is_multicast()||peer.port()==0)continue;
        if(target.peers.size()>=32)break;target.peers.push_back(peer);
    }
    return true;
}
