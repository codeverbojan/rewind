# How Rewind works

Rewind's UI, catalog state, transfer engine and playback run on the device. The development Mac builds packages and gathers diagnostics; it is not a required streaming server.

## App layers

| Layer | Code to start with | Responsibility |
| --- | --- | --- |
| App and navigation | `RewindApp.m`, `RewindNavigation.inc`, `RewindBrowser.inc` | Lifecycle, destinations and native UIKit views |
| Profiles and state | `RWProfiles.m`, `RewindStore.m`, `RewindTVStore.inc` | Profile separation, lists, preferences and episode progress |
| Discovery | `RWDiscoveryCatalog.m`, `RWRecommendationPolicy.m`, `RWCatalogSearch.m` | Catalog normalization, ranking, search and related titles |
| Shelves and artwork | `RWHomeView.m`, `RWPosterCollection.m`, `RWArtworkLoader.m` | Incremental loading, recycling, image fetching and caching |
| Title details | `RewindEntities.inc`, `RWDetailHeader.m`, `RWEpisodeList.m` | Credits, series episodes, people and studios |
| Trailers | `RWApplePreviewLookup.m`, `RWPreviewDecoder.mm` | Preview lookup, native decoding and view lifecycle |
| Source selection | `RWSourcePolicy.m`, `RWSourceExperience.m`, `RewindTorrentSelection.inc` | Eligibility, ranking and observed health |
| Transfers | `TorrentEngine.mm`, `TorrentDiscovery.inc`, `RWPeerEvidence.h` | libtorrent integration, discovery, verified bytes and connection evidence |
| Players | `RewindPlayer.m`, `RWLegacyPlayer.mm` | AVFoundation and MobileVLCKit adapters, controls and audio selection |
| Captions | `RWSubtitles.m`, `RWCaptionClock.m`, `RWSubtitleTicker.m` | Text parsing, display clock, delay and buffering visibility |

Paths in this table are relative to `standalone-media/`.

## What happens after Play

1. **Identify the requested content.** Preserve the selected movie or exact season/episode and profile preferences.
2. **Filter and rank.** Evaluate quality, codec evidence, storage, file selection and available source hints. The legacy profile caps video at 1080p; a resolution cap is not a guarantee of smooth playback for every encode.
3. **Measure the connection.** Discover peers through source trackers and the permitted discovery mechanisms. Advertised seeds, connected peers and peers actually sending useful data are different signals.
4. **Verify and buffer.** Prioritize the opening/read region, verify pieces and assess measured transfer against playback demand. Cached verified data can shorten this stage.
5. **Open a player.** Use the compatible playback adapter. Buffering, seek recovery and cancellation remain explicit states.
6. **Keep continuity.** Store progress and preferences locally. Audio/subtitle changes should remain responsive, and leaving playback releases owned work.

No tracker can guarantee that a listed peer will send data. A source that worked previously can disappear. These external limits are separate from the app's remaining startup and subtitle acceptance work.

## Performance approach

The app uses native UIKit views, bounded image and metadata work, horizontal shelf continuation, recycled content, and lifecycle guards that avoid refreshing the browser behind an active player. Playback work separates background transfer/decoder responsibilities from UI updates. The project includes tests for time discontinuities, peer state, cache boundaries and cancellation rather than treating a successful launch as complete acceptance.

## Portability

The C++ policies are a starting point for shared logic, but UIKit, Foundation, AVFoundation, notifications and Objective-C++ ownership still need platform adapters. ARM64 compilation does not establish phone UX or playback acceptance. See the [porting assessment](porting-assessment.md) for Android, desktop and LG webOS.
