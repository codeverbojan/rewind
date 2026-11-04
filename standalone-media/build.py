"""Build an isolated ARMv7/iOS 9 app using the explicitly approved SDK."""
import hashlib
import json
import plistlib
import shutil
import subprocess
import zipfile
from pathlib import Path
from prepare_sdk import prepare

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parent
SDK = prepare()
BUILD = ROOT / "build"
APP = BUILD / "Payload/MiniStreamLab.app"
BUNDLE = "org.local.ministreamlab"
VERSION = "0.300"


def run(args):
    subprocess.run([str(x) for x in args], check=True)


def main():
    if (ROOT / "versions" / VERSION).exists():
        raise RuntimeError("This release is frozen; choose a new version before building.")
    from build_tracker_tls import FLAGS, SRC, BOOST, LIBRARIES, OPENSSL, verify
    verify()
    APP.mkdir(parents=True, exist_ok=True)
    flags = ["-target", "armv7-apple-ios9.0", "-isysroot", SDK, "-miphoneos-version-min=9.0",
             "-fobjc-arc", "-fmodules", "-fmodules-cache-path=" + str(BUILD / "modules"),
             "-Os", "-Werror=unguarded-availability", "-framework", "UIKit",
             "-framework", "Foundation", "-framework", "AVKit", "-framework", "AVFoundation",
             "-framework", "SafariServices", "-framework", "WebKit", "-framework", "Security", "-framework", "ImageIO", "-framework", "CoreGraphics", "-framework", "CoreText", "-framework", "CoreMedia", "-framework", "QuartzCore", "-framework", "OpenGLES", "-framework", "SystemConfiguration"]
    vlc_source = PROJECT / "downloads/standalone-media-sources/MobileVLCKit-3.7.3/MobileVLCKit-binary/MobileVLCKit.xcframework/ios-arm64_armv7_armv7s/MobileVLCKit.framework"
    frameworks = APP / "Frameworks"
    frameworks.mkdir(exist_ok=True)
    vlc = frameworks / "MobileVLCKit.framework"
    if vlc.exists(): shutil.rmtree(vlc)
    shutil.copytree(vlc_source, vlc)
    run(["/usr/bin/lipo", vlc_source / "MobileVLCKit", "-thin", "armv7", "-output", vlc / "MobileVLCKit"])
    for extra in ["Headers", "PrivateHeaders", "Modules", "_CodeSignature"]:
        if (vlc / extra).exists(): shutil.rmtree(vlc / extra)
    run(["/usr/bin/codesign", "--force", "--sign", "-", "--digest-algorithm=sha1,sha256", vlc])
    include_vlc = ["-F" + str(vlc_source.parent), "-I" + str(vlc_source / "Headers")]
    flags += include_vlc + ["-framework", "MobileVLCKit", "-Wl,-rpath,@executable_path/Frameworks"]
    objects = []
    for name in ["RWMainThreadStallProbe.m", "RWCaptionClock.m", "RWFontLookupProbe.m", "RWPlaybackLifetimeProbe.m", "RWUpcomingSelection.m", "RWHomeCategoryPolicy.m", "RWPublisherRatingPolicy.m", "RWProfileMotionPlan.m", "RWProfileExperience.m", "RWCatalogSearch.m", "RWListAnchor.m", "RWEpisodeFetcher.m", "RWEpisodeCatalog.m", "RWPackedEpisodes.m", "RWReminderPolicy.m", "RWUpcomingPolicy.m", "RWAvailabilityCache.m", "RWHomeDeferredPreparation.m", "RWHomePreparation.m", "RWSourceWork.m", "RWStateSaveScheduler.m", "RWDeviceExercise.m", "RWApplePreviewPolicy.m", "RWApplePreviewLookup.m", "RWPreviewDecoder.mm", "RWPreviewTrace.mm", "RWDiscoveryCandidatePolicy.m", "RWEntityCreditPolicy.m", "RWEntitySearchPolicy.m", "RWEntityDetailsPolicy.m", "RWHomePresentation.m", "RWPreviewSession.m", "RWDetailPresentation.m", "RWDetailHeader.m", "RWArtworkLoader.m", "RWArtworkDecode.m", "RWDownloadInventory.m", "RWDownloadsList.m", "RWExploreIndex.m", "RWEntityCard.m", "RWInteractionMetrics.m", "RWUIProbe.m", "RWAvailabilityList.m", "RWHomeView.m", "RWHomeFeedStore.m", "RWHomeFeedCoordinator.m", "RWHomeRailPolicy.m", "RWFeedStore.m", "RWFeedArchive.m", "RWPosterCollection.m", "RWDiscoverySnapshot.m", "RWLocalCatalog.m", "RWHomeDelivery.m", "RWMetadataBudget.m", "RWDiscoveryEpisodes.m", "RWDiscoveryCatalog.m", "RWOfflineMedia.m", "RWIMDbIndex.m", "RWDiscoveryMetadataPolicy.m", "RWDiscoveryMetadata.m", "RWRecommendationPolicy.m", "RWRecommendationSignals.m", "RWViewingSignals.m", "RWAvailability.m", "RWRemoteMKVProbe.m", "RWSourceExperience.m", "RWPlaybackPreparation.m", "RWSourceCache.m", "RWArtworkPolicy.m", "RWViewport.m", "RWEpisodeList.m", "RWCast.m", "RWCastStrip.m", "RWAtomicWriter.m", "RWRequestCoalescer.m", "RWMKVProbe.m", "RWAudioPolicy.m", "RWMKVAudioMap.m", "RWCatalogPolicy.m", "RWLegacyPlayer.mm", "RewindApp.m", "RewindStore.m", "RWProfiles.m", "RWRatingPolicy.m", "RWSkipPolicy.m", "RWRatings.m", "RWTrailerView.m", "RWTrailerPolicy.m", "RWTrailers.m", "RWTVPolicy.m", "RWSourcePolicy.m", "RWTrackerPolicy.m", "RWTrackerTrust.m", "RWPlaybackMetrics.m", "RWMediaCache.m", "RWLibraryPolicy.m", "RWSubtitleTicker.m", "RWSubtitleTimingProbe.m", "RWSubtitleLoadProbe.m", "RWSubtitleLabel.m", "RWSubtitles.m", "RWSubtitlePolicy.m", "RWSubtitleDownload.m", "RewindUI.m", "RewindPlayer.m", "TorrentLoader.m", "TorrentEngine.mm"]:
        obj = BUILD / (name + ".o")
        run(["/usr/bin/clang++", *FLAGS, *include_vlc, "-fobjc-arc", "-gline-tables-only", "-Werror=unguarded-availability",
             "-x", "objective-c++", "-c", ROOT / name, "-o", obj])
        objects.append(obj)
    run(["/usr/bin/clang++", *flags, *objects, *LIBRARIES, "-lc++", "-lz", "-lsqlite3", "-lgcc_s.1",
         "-o", APP / "MiniStreamLab"])
    info = {
        "CFBundleIdentifier": BUNDLE, "CFBundleExecutable": "MiniStreamLab",
        "CFBundleName": "Rewind", "CFBundleDisplayName": "Rewind",
        "CFBundlePackageType": "APPL", "CFBundleVersion": VERSION.rsplit(".", 1)[-1], "CFBundleShortVersionString": VERSION,
        "CFBundleURLTypes": [{"CFBundleURLName": "org.local.ministreamlab.lab", "CFBundleURLSchemes": ["rewind-lab"]}],
        "MinimumOSVersion": "9.0", "UIBackgroundModes": ["fetch"], "UIDeviceFamily": [2],
        "UIRequiredDeviceCapabilities": ["armv7"], "UIFileSharingEnabled": True,
        "CFBundleIcons~ipad": {"CFBundlePrimaryIcon": {"CFBundleIconFiles": ["Rewind/Icon-76", "Rewind/Icon-152"], "UIPrerenderedIcon": True}},
        "UILaunchImages": [], "UISupportedInterfaceOrientations": [
            "UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight"],
        "NSAppTransportSecurity": {"NSAllowsArbitraryLoads": True},
    }
    (APP / "Info.plist").write_bytes(plistlib.dumps(info))
    shutil.copytree(ROOT / "Resources/Rewind", APP / "Rewind", dirs_exist_ok=True)
    shutil.copy2(PROJECT / "downloads/standalone-media-sources/MobileVLCKit-3.7.3/MobileVLCKit-binary/COPYING.txt", APP / "MobileVLCKit-LICENSE.txt")
    shutil.copy2(ROOT / "Resources/playback-test.mp4", APP / "playback-test.mp4")
    shutil.copy2(ROOT / "Resources/big-buck-bunny.torrent", APP / "big-buck-bunny.torrent")
    shutil.copy2(ROOT / "Resources/cosmos-laundromat.torrent", APP / "cosmos-laundromat.torrent")
    shutil.copy2(SRC / "COPYING", APP / "libtorrent-LICENSE.txt")
    shutil.copy2(BOOST / "LICENSE_1_0.txt", APP / "boost-LICENSE.txt")
    shutil.copy2(OPENSSL / "LICENSE.txt", APP / "OpenSSL-LICENSE.txt")
    (APP / "TrackerTLS-SOURCE.txt").write_text("OpenSSL 3.5.9, official openssl/openssl release, Apache-2.0. ARMv7 static portable build with upstream pthread-lock fallback.\nlibtorrent 1.2.20, BSD license; build-local HTTP redirect patch retains TLS and limits inherited Basic authentication to the same origin. A bounded tracker-response observer preserves peer provenance through asynchronous DNS; it does not alter transport or peer selection. Patch: Patches/libtorrent-1.2.20-peer-provenance.json.\nMozilla CA bundle from https://curl.se/ca/cacert-2026-10-20.pem, MPL-2.0; used only by Rewind's torrent TLS context. No system trust changes.\n")
    (APP / "TEST-CONTENT.txt").write_text("Cosmos Laundromat: © 2015 Blender Foundation, Creative Commons. https://www.blender.org/press/cosmos-laundromat-released/\nhttps://studio.blender.org/projects/cosmos-laundromat/\nBig Buck Bunny: © 2008 Blender Foundation, CC BY 3.0. https://peach.blender.org/\nTorrent metadata from https://webtorrent.io/free-torrents\nLocal playback test clip generated for this project.\n")
    (APP / "MobileVLCKit-SOURCE.txt").write_text("MobileVLCKit 3.7.3, official VideoLAN binary, ARMv7 slice.\nhttps://download.videolan.org/pub/cocoapods/prod/MobileVLCKit-3.7.3-319ed2c0-79128878.tar.xz\nVLCKit source: https://code.videolan.org/videolan/VLCKit/-/tree/319ed2c0\nVLC source: https://code.videolan.org/videolan/vlc/-/tree/79128878\nDynamically linked; replace Frameworks/MobileVLCKit.framework with a compatible ARMv7 build and re-sign the app to relink.\n")
    (APP / "PkgInfo").write_bytes(b"APPL????")
    run(["/usr/bin/codesign", "--force", "--sign", "-", "--digest-algorithm=sha1,sha256", APP])
    run(["/usr/bin/codesign", "--verify", "--strict", "--verbose=2", APP])
    # Keep symbols matched to this exact release, even after the next build
    # replaces Payload. Device crash addresses can then resolve to source lines.
    symbols = BUILD / "symbols" / info["CFBundleShortVersionString"]
    symbols.mkdir(parents=True, exist_ok=True)
    shutil.copy2(APP / "MiniStreamLab", symbols / "MiniStreamLab")
    run(["/usr/bin/dsymutil", APP / "MiniStreamLab", "-o", symbols / "MiniStreamLab.dSYM"])
    ipa = BUILD / f"Rewind-{VERSION}.ipa"
    with zipfile.ZipFile(ipa, "w", zipfile.ZIP_DEFLATED) as z:
        for f in APP.rglob("*"):
            if f.is_file():
                z.write(f, f.relative_to(BUILD))
    report = {"ipa": str(ipa), "bytes": ipa.stat().st_size,
              "sha256": hashlib.sha256(ipa.read_bytes()).hexdigest(),
              "bundle_id": BUNDLE, "target": "armv7 / iOS 9.0", "symbols": str(symbols),
              "status": "Built and signature verified; not yet runtime tested"}
    (BUILD / "build-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
