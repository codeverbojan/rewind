#pragma once
#include <libtorrent/extensions.hpp>
#include <libtorrent/entry.hpp>
#include <memory>

// Pinned libtorrent1.2.20's initial extension handshake advertises upload_only
// even when close_redundant_connections=false. Its later upload-only messages
// correctly honor that setting. A metadata/short-prefix preparation is temporary:
// the player will request further pieces, so preserve the seed's interest too.
// This stateless network-thread hook changes only that optional declaration.
// It does not change peer discovery, bitfields, requests, or payload permissions.
class RWStreamingPeerHandshake final : public libtorrent::peer_plugin {
public:
    void add_handshake(libtorrent::entry &handshake) override {
        handshake.dict().erase("upload_only");
    }
};
class RWStreamingTorrentHandshake final : public libtorrent::torrent_plugin {
public:
    std::shared_ptr<libtorrent::peer_plugin> new_connection(
        libtorrent::peer_connection_handle const&) override {
        return std::make_shared<RWStreamingPeerHandshake>();
    }
};
inline std::shared_ptr<libtorrent::torrent_plugin> RWCreateStreamingHandshake(
    libtorrent::torrent_handle const&, void*) {
    return std::make_shared<RWStreamingTorrentHandshake>();
}
