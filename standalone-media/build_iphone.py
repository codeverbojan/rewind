"""Separate ARM64 iPhone experiment; never overwrites the frozen iPad package.

Uses already approved, pinned local sources and SDK. No downloads, provisioning,
account access or device writes. The resulting IPA requires development signing.
"""
import ast
import hashlib
import json
import os
import plistlib
import re
import shutil
import signal
import subprocess
import sys
import zipfile
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parent
ROOT = APP_ROOT.parent
OUT = APP_ROOT / 'build/iphone-301'
REPORT = ROOT / 'diagnostics/iphone-301'
SOURCE = ROOT / 'downloads/standalone-media-sources'
SDK = APP_ROOT / 'build/iPhoneOS10.3-armv7.sdk'  # Device overlay retains ARM64 stubs.
TLS_SOURCE = SOURCE / 'openssl-3.5.9'
TORRENT_SOURCE = SOURCE / 'libtorrent-rasterbar-1.2.20'
BOOST = SOURCE / 'boost_1_84_0'
TLS = OUT / 'openssl'
TORRENT = OUT / 'torrent'
TARGET = ['-target', 'arm64-apple-ios9.0', '-isysroot', str(SDK)]
CURRENT = None


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def cleanup(sig=None, frame=None):
    if CURRENT is not None and CURRENT.poll() is None:
        os.killpg(CURRENT.pid, signal.SIGTERM)
        try:
            CURRENT.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(CURRENT.pid, signal.SIGKILL)
            CURRENT.wait()
    if sig is not None:
        raise SystemExit(130)


def run(args, label, cwd=None, env=None, timeout=180):
    global CURRENT
    path = REPORT / (label + '.log')
    if path.exists():
        number = 1
        while path.with_name(path.name + f'.previous-{number}').exists():
            number += 1
        path.rename(path.with_name(path.name + f'.previous-{number}'))
    with path.open('w') as log:
        CURRENT = subprocess.Popen([str(a) for a in args], cwd=cwd, env=env,
                                   stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        code = CURRENT.wait(timeout=timeout)
    if code:
        print(path.read_text()[-6500:], flush=True)
        raise RuntimeError(f'{label} failed ({code}); retained {path}')


def flags():
    return TARGET + ['-std=c++14', '-stdlib=libc++', '-Os', '-DNDEBUG',
        '-DTORRENT_USE_OPENSSL', '-DTORRENT_USE_I2P=0', '-DTORRENT_DISABLE_LOGGING',
        '-DBOOST_ASIO_ENABLE_CANCELIO', '-DBOOST_ASIO_HAS_STD_CHRONO',
        '-DBOOST_ASIO_USE_TS_EXECUTOR_AS_DEFAULT', '-DBOOST_EXCEPTION_DISABLE',
        '-fvisibility=hidden', '-fvisibility-inlines-hidden', '-Wno-deprecated-declarations',
        '-I' + str(TORRENT_SOURCE / 'include'), '-I' + str(BOOST),
        '-I' + str(TLS / 'include'), '-I' + str(TLS_SOURCE / 'include'),
        '-I' + str(APP_ROOT)]


def verify_sources():
    native = json.loads((ROOT / 'diagnostics/rewind-0.300-native-inputs.json').read_text())
    assert all(sha(APP_ROOT / k) == v for k, v in native.items()), 'iPad inputs changed'
    lock = json.loads((APP_ROOT / 'Dependencies/tracker-tls.json').read_text())
    assert all(sha(ROOT / k) == v for k, v in lock['libtorrent_inputs'].items())
    assert sha(SOURCE / 'openssl-3.5.9.tar.gz') == '603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a'
    assert (SDK / '.prepared.json').exists()
    save(REPORT / 'input-verification.json', {'baseline': '0.300', 'native_inputs': native,
        'libtorrent_lock_sha256': sha(APP_ROOT / 'Dependencies/tracker-tls.json'),
        'builder_sha256': sha(Path(__file__)), 'target': 'ARM64 iPhone; existing SDK'})


def build_tls():
    proof = REPORT / 'tls-build.json'
    if proof.exists():
        old = json.loads(proof.read_text())
        assert all(sha(TLS / k) == v for k, v in old['libraries'].items())
        return
    TLS.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(CC='/usr/bin/clang', AR='/usr/bin/ar', RANLIB='/usr/bin/ranlib',
        CFLAGS='-Os -DBROKEN_CLANG_ATOMICS ' + ' '.join(TARGET))
    args = ['/usr/bin/perl', TLS_SOURCE / 'Configure', 'ios64-xcrun', 'no-shared',
            'no-tests', 'no-apps', 'no-module', 'no-dso', 'no-engine', 'no-legacy',
            'no-comp', 'no-asm']
    run(args, 'tls-configure', cwd=TLS, env=env, timeout=90)
    print('Building ARM64 TLS libraries with at most two compiler processes', flush=True)
    run(['/usr/bin/make', '-j2', 'build_libs'], 'tls-libraries', cwd=TLS, env=env, timeout=900)
    save(proof, {'configuration': 'ios64-xcrun/no-asm/pthread-locks', 'cflags': env['CFLAGS'],
        'libraries': {n: sha(TLS / n) for n in ['libssl.a', 'libcrypto.a']}})


def build_torrent():
    TORRENT.mkdir(exist_ok=True)
    cmake = (TORRENT_SOURCE / 'CMakeLists.txt').read_text()
    paths = []
    for group, prefix in [('sources', 'src'), ('kademlia_sources', 'src/kademlia'), ('ed25519_sources', 'ed25519/src')]:
        body = re.search(r'set\(' + group + r'\s+(.*?)\n\)', cmake, re.S)[1]
        paths += [TORRENT_SOURCE / prefix / n for n in re.findall(r'^\s*([a-z0-9_]+\.cpp)\s*$', body, re.M)]
    paths += [TORRENT_SOURCE / 'src' / n for n in ['pe_crypto.cpp', 'hasher512.cpp', 'sha512.cpp']]
    headers = {}
    for base, pattern in [(TORRENT_SOURCE / 'include', '*.hpp'), (BOOST / 'boost', '*.hpp'), (TLS / 'include', '*.h'), (TLS_SOURCE / 'include', '*.h')]:
        headers.update({str(p.relative_to(ROOT)): sha(p) for p in base.rglob(pattern)})
    header_hash = hashlib.sha256(json.dumps(headers, sort_keys=True).encode()).hexdigest()
    objects = []
    for i, source in enumerate(paths):
        actual = source
        if source.name in ['http_connection.cpp', 'torrent.cpp']:
            name = 'https-redirect' if source.name == 'http_connection.cpp' else 'peer-provenance'
            patch = json.loads((APP_ROOT / f'Patches/libtorrent-1.2.20-{name}.json').read_text())
            assert sha(source) == patch['source_sha256']
            text = source.read_text()
            edits = patch['edits'] if 'edits' in patch else [patch] + patch.get('additional_edits', [])
            for edit in edits:
                assert text.count(edit['needle']) == edit.get('count', 1)
                text = text.replace(edit['needle'], edit['replacement'])
            actual = TORRENT / ('patched-' + source.name)
            actual.write_text(text)
        obj = TORRENT / (str(source.relative_to(TORRENT_SOURCE)).replace('/', '_') + '.o')
        marker = obj.with_suffix('.sha256')
        identity = hashlib.sha256(actual.read_bytes() + json.dumps(flags()).encode() + header_hash.encode()).hexdigest()
        if not (obj.exists() and marker.exists() and marker.read_text() == identity):
            run(['/usr/bin/clang++', *flags(), '-DTORRENT_BUILDING_LIBRARY', '-c', actual, '-o', obj], 'torrent-' + str(i), timeout=150)
            marker.write_text(identity)
        objects.append(obj)
        if i % 20 == 0:
            print(f'ARM64 torrent: {i + 1}/{len(paths)} files', flush=True)
    run(['/usr/bin/ar', 'rcs', TORRENT / 'libtorrent.a', *objects], 'torrent-archive')
    save(REPORT / 'torrent-build.json', {'files': len(paths), 'flags': flags(),
        'sha256': sha(TORRENT / 'libtorrent.a'), 'header_digest': header_hash,
        'patches': ['https-redirect', 'peer-provenance']})


def build_app():
    sys.path.insert(0, str(APP_ROOT / 'iPhone'))
    from prepare_sources import prepare
    sources = OUT / 'sources'
    save(REPORT / 'phone-source-overlay.json', prepare(APP_ROOT, sources))
    app = OUT / 'Payload/Rewind.app'
    app.mkdir(parents=True, exist_ok=True)
    # Retained first build failed before packaging due to this name collision.
    if (app / 'Rewind').is_file():
        (app / 'Rewind').rename(OUT / 'first-link-before-packaging-fix')
    framework_source = SOURCE / 'MobileVLCKit-3.7.3/MobileVLCKit-binary/MobileVLCKit.xcframework/ios-arm64_armv7_armv7s/MobileVLCKit.framework'
    framework = app / 'Frameworks/MobileVLCKit.framework'
    if framework.exists():
        shutil.rmtree(framework)
    shutil.copytree(framework_source, framework)
    run(['/usr/bin/lipo', framework_source / 'MobileVLCKit', '-thin', 'arm64', '-output', framework / 'MobileVLCKit'], 'vlc-thin')
    for extra in ['Headers', 'PrivateHeaders', 'Modules', '_CodeSignature']:
        if (framework / extra).exists():
            shutil.rmtree(framework / extra)
    run(['/usr/bin/codesign', '--force', '--sign', '-', framework], 'vlc-sign')
    tree = ast.parse((APP_ROOT / 'build.py').read_text())
    names = next(ast.literal_eval(n.iter) for n in ast.walk(tree)
                 if isinstance(n, ast.For) and isinstance(n.iter, ast.List)
                 and len(n.iter.elts) > 50)
    includes = ['-F' + str(framework_source.parent), '-I' + str(framework_source / 'Headers')]
    objects = []
    for i, name in enumerate(names):
        obj = OUT / (name + '.o')
        run(['/usr/bin/clang++', *flags(), *includes, '-fobjc-arc', '-gline-tables-only',
             '-Werror=unguarded-availability', '-x', 'objective-c++', '-c', sources / name, '-o', obj], 'app-' + name, timeout=150)
        objects.append(obj)
        if i % 20 == 0:
            print(f'ARM64 app: {i + 1}/{len(names)} files', flush=True)
    frameworks = ['UIKit','Foundation','AVKit','AVFoundation','SafariServices','WebKit','Security','ImageIO','CoreGraphics','CoreText','CoreMedia','QuartzCore','OpenGLES','SystemConfiguration','MobileVLCKit']
    fw = [arg for name in frameworks for arg in ['-framework', name]]
    run(['/usr/bin/clang++', *TARGET, '-fobjc-arc', *includes, *fw, *objects,
         TORRENT / 'libtorrent.a', TLS / 'libssl.a', TLS / 'libcrypto.a',
         '-lc++', '-lz', '-lsqlite3', '-Wl,-rpath,@executable_path/Frameworks', '-o', app / 'RewindPhone'], 'app-link')
    baseline = plistlib.loads((APP_ROOT / 'build/Payload/MiniStreamLab.app/Info.plist').read_bytes())
    baseline.update(CFBundleIdentifier='org.local.rewind.iphone', CFBundleExecutable='RewindPhone',
        CFBundleVersion='301', CFBundleShortVersionString='0.301', UIDeviceFamily=[1, 2],
        UIRequiredDeviceCapabilities=['arm64'], UILaunchScreen={},
        NSLocalNetworkUsageDescription='Rewind can connect to media sources on your local network when you choose them.')
    baseline['CFBundleIcons'] = {'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['Rewind/Icon-120', 'Rewind/Icon-180'], 'UIPrerenderedIcon': True}}
    (app / 'Info.plist').write_bytes(plistlib.dumps(baseline))
    shutil.copytree(APP_ROOT / 'Resources/Rewind', app / 'Rewind', dirs_exist_ok=True)
    from PIL import Image
    icon = Image.open(app / 'Rewind/Icon-152.png').convert('RGB')
    for size in [120, 180]:
        icon.resize((size, size), Image.Resampling.LANCZOS).save(app / f'Rewind/Icon-{size}.png')
    for name in ['playback-test.mp4','big-buck-bunny.torrent','cosmos-laundromat.torrent']:
        shutil.copy2(APP_ROOT / 'Resources' / name, app / name)
    for source, name in [(TORRENT_SOURCE / 'COPYING', 'libtorrent-LICENSE.txt'),
        (BOOST / 'LICENSE_1_0.txt', 'boost-LICENSE.txt'), (TLS_SOURCE / 'LICENSE.txt', 'OpenSSL-LICENSE.txt'),
        (framework_source.parents[2] / 'COPYING.txt', 'MobileVLCKit-LICENSE.txt')]:
        shutil.copy2(source, app / name)
    for name in ['TEST-CONTENT.txt','TrackerTLS-SOURCE.txt','MobileVLCKit-SOURCE.txt']:
        text = (APP_ROOT / 'build/Payload/MiniStreamLab.app' / name).read_text().replace('ARMv7', 'ARM64')
        (app / name).write_text(text)
    (app / 'PkgInfo').write_bytes(b'APPL????')
    run(['/usr/bin/codesign', '--force', '--sign', '-', app], 'app-adhoc-sign')
    run(['/usr/bin/codesign', '--verify', '--deep', '--strict', app], 'app-verify')
    ipa = OUT / 'Rewind-iPhone-0.301.ipa'
    with zipfile.ZipFile(ipa, 'w', zipfile.ZIP_DEFLATED) as z:
        for file in app.rglob('*'):
            if file.is_file():
                z.write(file, file.relative_to(OUT))
    result = {'version': '0.301', 'target': 'arm64 iPhone', 'ipa': str(ipa.relative_to(ROOT)),
        'sha256': sha(ipa), 'executable_sha256': sha(app / 'RewindPhone'),
        'bytes': ipa.stat().st_size, 'signing': 'ad-hoc only; development signing required',
        'runtime_tested': False, 'baseline_ipad_modified': False}
    save(REPORT / 'build.json', result)
    print(json.dumps(result), flush=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    REPORT.mkdir(parents=True, exist_ok=True)
    verify_sources()
    for sig in [signal.SIGTERM, signal.SIGINT]:
        signal.signal(sig, cleanup)
    try:
        build_tls()
        build_torrent()
        build_app()
        verify_sources()
    finally:
        cleanup()


if __name__ == '__main__':
    main()
