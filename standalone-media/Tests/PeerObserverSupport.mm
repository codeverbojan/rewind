// Supply the production observer symbol when a policy-only test links the
// patched static library without TorrentEngine.mm. No fixture-specific policy.
#define RW_PEER_EVIDENCE_IMPLEMENTATION 1
#include "../RWPeerEvidence.h"
