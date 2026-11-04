# Status and verification boundaries

Public source snapshot: **4 November 2026**. This page describes recorded checkpoints, not a new device test performed for publication.

| Area | Recorded status |
| --- | --- |
| iPad | Original iPad mini, ARMv7, iOS 9.3.5; installed/frozen checkpoint 0.300 |
| iPhone | ARM64 package 0.301 built; developer trust/signing setup was in progress; launch and playback not confirmed |
| Browsing screenshots | Historical real-device captures from 0.156, 0.229 and 0.230 |
| Other platforms | Assessment only; no released Android, desktop or webOS application |
| Distribution | Source release; no signed public binary or fresh-clone native bootstrap |

## What was measured

- The 0.300 caption change passed **2,533 focused checks across 11 suites** and a zero-warning ARMv7 build. This was not a complete full-suite run.
- One controlled physical-device run exercised delayed captions, a seed outage, seek recovery, paused captions, two minutes of subsequent playback, subtitle Off and player exit. Buffered captions were hidden while the displayed picture had not caught up.
- Earlier 0.292 runs measured **5.897 seconds** to playback for a fully cached episode and **18.647 seconds** for a partially cached film, each with more than two minutes of playback and no observed stalls. These are cached examples, not cold-start guarantees or population averages.
- Local MKV testing verified multichannel-to-stereo output and player controls. It does not prove every release has the correct spoken language or a suitable audio track.
- The separate iPhone package and all five binary components were verified as ARM64. Its 107 app translation units compiled without warnings. Runtime behavior remains unverified.

Raw evidence, private state snapshots, device identifiers and frozen archives remain local. The public source retains test implementations and authored fixtures, but does not claim that the entire historical research archive can be reproduced from a clone.

## Still open

- Startup under constrained throughput: a retained controlled comparison was **22.37% slower than the legacy baseline**, missing a 10% regression allowance.
- Broader cold-source reliability, changing peer availability and startup latency across real releases.
- Spoken-English confirmation and semantic subtitle alignment at start/middle/end, including longer-term drift.
- Some catalog, Kids-rating, artwork and trailer coverage gaps; these depend partly on external services.
- Actual OS notification delivery/tap coverage and a reproducible native bootstrap.
- iPhone launch, layout and playback acceptance on physical hardware.

The original playback work was paused at the owner's request. Preparing this repository for publication does not resume it or mark it complete.
