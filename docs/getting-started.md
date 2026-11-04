# Build and installation

Rewind is a source-level research project. There is no supported one-command installer or signed public IPA at this checkpoint. Start with the checks that work from a clean clone, then prepare a separate local build environment if you intend to work on the app.

## Check a clean clone

```sh
python3 tools/check_public_repo.py
python3 tools/run_portable_checks.py
```

Requirements: Python 3.9+ and a C++14 compiler (`clang++`, `g++`, or `CXX`). The checks run sequentially, create temporary build outputs and remove them when finished. They do not access a device, start a server or download media. The portable runner exercises existing connection-budget, frame-code and other dependency-free policy tests. It is deliberately a subset of the full suite.

## Native build prerequisites

The historical build host was macOS 12.5 with Apple command-line tools. Paths below are relative to the checkout. Obtain dependencies separately from their upstreams; installers and SDKs are not redistributed here.

| Input | Expected location | Reference |
| --- | --- | --- |
| Apple compiler, linker, signing tools | System toolchain | Apple development tools |
| Community-patched iPhoneOS 10.3 SDK | `downloads/ios9-build-sdk/theos-sdks/iPhoneOS10.3.sdk` | [Theos SDKs](https://github.com/theos/sdks), recorded commit `0222fd5413cf4b9af096f37b4621afa2688572f7` |
| libtorrent 1.2.20 | `downloads/standalone-media-sources/libtorrent-rasterbar-1.2.20/` | [Official release](https://github.com/arvidn/libtorrent/releases/tag/v1.2.20) |
| Boost 1.84.0 | `downloads/standalone-media-sources/boost_1_84_0/` | [Official archive](https://archives.boost.io/release/1.84.0/source/) |
| OpenSSL 3.5.9 | `downloads/standalone-media-sources/openssl-3.5.9/` | [OpenSSL source](https://github.com/openssl/openssl) |
| MobileVLCKit 3.7.3 | `downloads/standalone-media-sources/MobileVLCKit-3.7.3/MobileVLCKit-binary/` | [Pinned VideoLAN archive](https://download.videolan.org/pub/cocoapods/prod/MobileVLCKit-3.7.3-319ed2c0-79128878.tar.xz) |

The VideoLAN archive SHA-256 is `0d04059906962ddc9a7bd1ebaa12e1f9ae85eb2466116a97a2f46886dd27a0a9`. The recorded OpenSSL archive SHA-256 is `603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a`. [Dependency lock](../standalone-media/Dependencies/tracker-tls.json) and [source patches](../standalone-media/Patches/) retain additional pinned hashes.

## Build entry points and limitations

Read these scripts before execution:

- `standalone-media/prepare_sdk.py` creates a local linker-stub overlay. Importing `build.py` also invokes SDK preparation.
- `standalone-media/build_tracker_tls.py` verifies and uses the pinned TLS/torrent build inputs. It expects existing local compiled libraries; it is not a full bootstrap.
- `standalone-media/build.py` compiles and packages the ARMv7 iPad app. Its recorded version is 0.300. Choose a new version/output directory for new work; never overwrite frozen evidence.
- `standalone-media/build_iphone.py` builds the separate ARM64 0.301 experiment and applies `iPhone/prepare_sources.py`. It requires the local 0.300 native-input manifest, generated SDK overlay and pinned libraries. Those receipts are not in this public tree. A portable build/bootstrap is future work.
- `standalone-media/run_checks.py` is the historical full macOS suite. Some suites require omitted research fixtures, generated ratings data and native libraries. Do not report it as passing on a fresh clone.

The public tree intentionally omits harvested catalog JSON, standalone commercial artwork, downloaded films, raw research responses and the IMDb ratings database. Data preparation scripts remain as reference implementations, but obtaining data is subject to each provider's terms. Use your own authorized inputs. Included authored diagnostic clips and sounds are identified by their adjacent notices.

## Installation and signing

Building and installing are separate operations. The historical iPad setup used a compatible jailbreak and AppSync; this repository does not automate or recommend changing your device's jailbreak or firmware. The ARM64 phone build needs valid development signing before it can run on an unmodified iPhone. Use a supported signing workflow and complete account/trust steps locally; never submit passwords, signing keys or verification codes to an issue.

An ad-hoc signature only validates a local package; it is not permission to install on a stock iPhone. Preserve the same bundle identifier and your saved data when updating. Always obtain device-owner approval before installation or changing device settings.

## Device automation

The historical USB/SSH control script references a separate local `ipadwifi` project. That configuration, its private keys and USB tools are not included. It is specific to the original authorized iPad, and must not be assumed to work on a different device. The public portable checks require none of it.
