#pragma once
#include <stdint.h>
#ifndef __cplusplus
#include <stdbool.h>
#endif
#ifdef __cplusplus
extern "C" {
#endif
// App-owned, synchronous diagnostic boundary in pinned libtorrent1.2.20.
// Pointers are borrowed for this call only. No tracker/peer policy is changed.
enum { RWTrackerResponse=1, RWTrackerEndpoint=2, RWTrackerDNSStarted=3,
       RWTrackerDNSResolved=4, RWTrackerDNSFailed=5 };
struct RWTrackerObservation {
    uint32_t version;
    uint32_t kind;
    const void *torrent;
    const char *url;
    uint32_t url_length;
    uint32_t count;
    uint32_t scope;
    uint16_t port;
    uint8_t address_length;
    uint8_t stopped;
    uint8_t address[16];
};
#ifdef RW_TRACKER_LIBRARY_BUILD
__attribute__((weak_import))
#endif
bool RWObserveTracker(const struct RWTrackerObservation *event);
#ifdef __cplusplus
}
#endif
