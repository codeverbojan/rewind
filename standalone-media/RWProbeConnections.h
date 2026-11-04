#pragma once
// A stalled connection occupies a libtorrent slot before it can send payload.
// Lend each full probe one spare attempt, without disconnecting useful peers
// or changing any network timeout. Three probes use at most39 of40 slots.
namespace RWProbeConnections {
constexpr int Initial = 12;
constexpr int WithSpare = 13;
static_assert(3 * WithSpare < 40, "Discovery must retain the shared connection bound");
inline int Target(bool preparing, int limit, int occupied, int candidates) {
    return !preparing && limit == Initial && occupied >= Initial && candidates > 0
        ? WithSpare : limit;
}
}
