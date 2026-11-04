# Rewind porting assessment

Assessment date: 24 October 2026. Baseline: Rewind 0.149 on ARMv7 and iOS 9.3.5. This is a future-work proposal, not an instruction to resume the paused iPad goal or start a port.

Android, Windows, macOS and Linux have established foundations for a standalone Rewind application. LG webOS requires an early capability test on the exact television. The proposed approach is a shared modern interface and portable streaming core, with platform-specific playback, lifecycle and system integration. The existing legacy iPad application remains a separate supported target during any migration.

## Current architecture and reuse

The existing interface uses UIKit and Objective-C. Native playback uses AVFoundation; the MKV path uses MobileVLCKit. `TorrentEngine.mm` wraps libtorrent in Objective-C++, with Apple dispatch queues, Foundation objects and filesystem integration. The C++ engine logic is reusable after extracting those platform dependencies; the wrapper is not directly portable.

| Component | Proposed treatment |
| --- | --- |
| Torrent health, buffering, piece priorities and verified byte reads | Extract a C++ core with a small versioned C interface, cancellation and explicit ownership |
| Recommendations, source eligibility, profiles, Kids rules and episode progress | Translate or extract platform-neutral logic; preserve behavior using existing fixtures |
| Catalog schemas, bundled metadata, artwork and notices | Reuse suitable resources with provenance and versioned data migration |
| UIKit views, Apple networking, storage and notifications | Implement platform equivalents |
| Playback | Define one application-facing player contract with native implementations |
| Device exercise recipes | Reuse acceptance intent and fixtures; replace UIKit/USB-specific automation |

Unresolved recommendation, artwork, subtitle and catalog coverage work remains part of the product scope. Porting does not establish that those requirements are complete.

## Android and Android TV

Android can package native C/C++ libraries and call them through JNI, providing a route for the extracted torrent engine. A native Kotlin/Compose application is an option for Android alone; a shared Flutter interface is worth evaluating when desktop and compatible LG devices are also targets. [Android NDK](https://developer.android.com/ndk/guides)

Evaluate Media3/ExoPlayer and a VLC integration against the actual media matrix. Media3 supports Matroska, MP4 and common subtitle containers, but decoding depends on the device and any bundled decoder extensions. Verify multichannel downmix, embedded and external subtitles, random-access reads from incomplete torrents, seeking, resume, cancellation and clean shutdown. [Media3 formats](https://developer.android.com/media/media3/exoplayer/supported-formats)

Android TV needs a deliberate remote experience: directional focus, reliable Back behavior, readable cards, season/episode navigation and reachable player controls. Touch and TV layouts can share models without sharing every interaction. [Android TV controls](https://developer.android.com/media/media3/ui/androidtv)

Platform work includes storage quotas, app suspension, interrupted downloads, media sessions, notifications, package signing and real-device testing. A phone/tablet build and a TV build are separate acceptance targets.

## Windows macOS and Linux

Flutter supports native desktop applications on all three systems. A shared interface and torrent library would reduce duplication, while mouse/keyboard controls, window sizing, fullscreen, file access and lifecycle handling remain platform work. [Flutter desktop support](https://docs.flutter.dev/platform-integration/desktop)

Use a player adapter that can support the required formats across all three systems. The standard Flutter `video_player` package currently lists Android, iOS, macOS and web, so it does not by itself cover Windows and Linux. VLC is a candidate for a shared playback foundation, with platform-specific rendering and library packaging still required. [Flutter video player](https://pub.dev/packages/video_player), [VideoLAN platforms](https://github.com/videolan/vlc)

Build and verify Windows releases on Windows, macOS releases on macOS and Linux releases on Linux. The current Mac alone is not a complete release/testing environment for all targets. Include native dependencies and notices, installers or distributable bundles, signing where appropriate, upgrade behavior and a defined supported OS/CPU matrix. [Flutter build environments](https://docs.flutter.dev/platform-integration)

## LG webOS

The TV model, firmware and webOS version determine the available route. Do not use webOS Open Source Edition support on development boards as proof of support on a retail LG TV.

### webOS 26 Re New and later

LG officially supports Flutter starting with webOS TV 26 Re:New. TVs originally shipped with webOS 26 require the Re:New update. This creates a candidate route for sharing the interface with Android and desktop, but does not prove that our native torrent library or player will run unchanged. [LG Flutter announcement](https://webostv.developer.lge.com/news/flutter-for-webos-tv-is-now-available-for-developers)

LG supplies a webOS SDK, NDK and platform plugins. Its supported host is Ubuntu; development from this Mac needs a compatible Linux environment. First prove library loading, socket/file access, media delivery, seeking and cleanup within the actual app sandbox. [LG setup](https://github.com/lg-flutter-webos/flutter-webos/blob/main/doc/getting-started.md), [LG plugins](https://github.com/lg-flutter-webos/plugins/blob/main/doc/plugin-list.md)

### Earlier webOS versions

The established route is an HTML/CSS/JavaScript TV application with a JavaScript service. LG services provide networking, filesystem access and binary processing, but prohibit Node modules containing C/C++ addons. Their Node versions differ substantially across TV generations. Our current native engine cannot simply be inserted into that service. [LG service capabilities](https://webostv.developer.lge.com/develop/guides/js-service-basics)

A pure JavaScript torrent service is an experimental candidate. It must prove ordinary peer connectivity, throughput, bounded storage, seekable media delivery and operation throughout playback. Service lifetime restrictions and the separation between downloaded service files and web-app access are material constraints. A browser-only WebTorrent client has different peer compatibility: it requires WebRTC-capable peers. [LG service lifecycle](https://webostv.developer.lge.com/develop/guides/js-service-usage), [WebTorrent compatibility](https://webtorrent.io/faq)

Check the TV's actual codecs and media APIs. Retain a 1080p ceiling until the product requirements change; a newer screen alone does not authorize expanding the supported media matrix. An external streaming server would change the standalone requirement and must be treated as a separate product decision.

Developer Mode provides a testing installation route, but sessions expire and disabling Developer Mode uninstalls its test apps. Permanent distribution requires a separate packaging/distribution decision. Rooting or firmware changes are outside this proposal. [LG Developer Mode](https://webostv.developer.lge.com/develop/getting-started/developer-mode-app)

## Proposed work sequence

1. Record target devices, OS/CPU versions, Android touch versus TV scope, and personal sideloading versus distribution needs.
2. Define the portable core and player interfaces. Preserve profile/history schemas, exact title/episode identity, honest availability and bounded resources.
3. Prove a generated or freely distributable clip on macOS and Android: real torrent peers, incomplete download playback, seek, audio, subtitles, exit and cleanup.
4. Run the LG capability experiment early if LG support is a firm requirement. Gate that port on real device results.
5. Build shared profiles, Home, search, details, episode progress, discovery, recommendations and storage screens with input-specific layouts.
6. Add Windows and Linux builds and their native library/rendering integrations.
7. Complete per-platform acceptance: playback stability, offline use, suspend/resume, Kids boundaries, storage pressure, network failure, upgrades and preserved user state.

## Planning estimates

These are provisional engineering-effort ranges for one experienced developer with target hardware available, not delivery commitments.

| Milestone | Approximate cumulative effort |
| --- | --- |
| Shared core and playback proof on macOS and Android | 1–2 weeks |
| Usable shared app on the initial platforms | 6–10 weeks |
| Broader feature parity, TV interaction, packaging and reliability across Android and three desktops | 12–20 weeks |
| LG standalone port | Estimate after the exact-TV capability experiment |

The largest uncertainties are native media integration, LG's application restrictions, supported hardware breadth and unfinished existing product requirements. Reassess the estimate after the first playback proofs.
