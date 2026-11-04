# Third-party notices

The root MIT license applies to original Rewind code and documentation. It does not replace the terms of upstream code, excerpts, generated icon paths, libraries, media or catalog imagery.

| Component | Terms / attribution | Use in this repository |
| --- | --- | --- |
| libtorrent 1.2.20 | Arvid Norberg and contributors; [BSD license](docs/licenses/libtorrent.txt) | Integration and small source patch descriptions; binaries downloaded separately |
| Boost 1.84.0 | [Boost Software License 1.0](docs/licenses/boost.txt) | External build dependency |
| OpenSSL 3.5.9 | [Apache 2.0](docs/licenses/openssl.txt) | External TLS dependency |
| MobileVLCKit / VLC | VideoLAN and contributors; [LGPL 2.1 notice](docs/licenses/vlckit.txt); individual upstream files retain their terms | External playback framework and documented source references |
| Lucide icons | [ISC license](standalone-media/Resources/Rewind/Lucide-LICENSE.txt) | Generated paths in `RewindIconPaths.inc` |
| Mozilla CA certificates | Mozilla contributors; MPL 2.0; [curl CA extract](https://curl.se/docs/caextract.html) | Public trust certificates in `tracker-roots.pem`; these are not private keys |
| Authored test media and sounds | CC0 notices alongside the resources | Synthetic playback, audio, caption and profile-sound fixtures |

Historical integration targets the [VLCKit 319ed2c0 source](https://code.videolan.org/videolan/VLCKit/-/tree/319ed2c0) and [VLC 79128878 source](https://code.videolan.org/videolan/vlc/-/tree/79128878). Framework binaries, SDKs and the research copies of upstream source are not distributed here. Review upstream obligations before distributing a linked application.

## Data and screenshots

The source references metadata services including Cinemeta, TVmaze, Wikidata, IMDb and publisher preview services. Provider access is not a license to redistribute an entire dataset. The public tree omits harvested catalog/ratings caches, the IMDb database, raw provider responses and standalone commercial poster/background files.

TVmaze data is subject to CC BY-SA and attribution requirements; Wikidata structured data is CC0; IMDb non-commercial data has its own restrictions. The existing [discovery-data notice](standalone-media/Resources/Rewind/DISCOVERY-DATA.txt) records the original research context. Catalog/artwork providers retain their own rights.

Screenshots document the actual Rewind interface. Film/series artwork, names, actor photographs, studio marks and publisher marks visible inside them belong to their respective owners and are not licensed under Rewind's MIT license. They do not imply affiliation, endorsement or media availability. [Screenshot provenance](docs/screenshots.md).

No commercial films, signed application packages, Apple SDKs or account credentials are included. Some historical source scripts reference Blender Open Movies; the corresponding downloaded film assets are not part of this public source snapshot.
