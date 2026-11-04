"""Run bounded integration checks against the pinned, already-built host library.
No downloads, listening services, or device writes. Run build_host_torrent.py first.
"""
import json
import pathlib
import signal
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
source = root.parent / 'downloads/standalone-media-sources/libtorrent-rasterbar-1.2.20'
boost = source.parent / 'boost_1_84_0'
output = root / 'build/host-torrent'
current = None


def stop(*_):
    if current is not None and current.poll() is None:
        current.terminate()
        try:
            current.wait(timeout=3)
        except subprocess.TimeoutExpired:
            current.kill()
            current.wait()
    raise SystemExit(130)


signal.signal(signal.SIGINT, stop)
signal.signal(signal.SIGTERM, stop)


def run(args, timeout):
    global current
    current = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        stdout, stderr = current.communicate(timeout=timeout)
    except BaseException:
        if current.poll() is None:
            current.kill()
        current.communicate()
        raise
    if stderr:
        print(stderr[-3000:])
    if current.returncode:
        raise RuntimeError(f'Process failed ({current.returncode}): {stdout}')
    return stdout


flags = ['-std=c++14', '-Os', '-DNDEBUG', '-DTORRENT_USE_I2P=0',
         '-DTORRENT_DISABLE_LOGGING', '-DBOOST_ASIO_ENABLE_CANCELIO',
         '-DBOOST_ASIO_HAS_STD_CHRONO', '-DBOOST_ASIO_USE_TS_EXECUTOR_AS_DEFAULT',
         '-DBOOST_EXCEPTION_DISABLE', '-Wno-deprecated-declarations',
         '-I' + str(source / 'include'), '-I' + str(boost)]
run(['/usr/bin/clang++', *flags, str(root / 'Tests/TorrentResumeTests.cpp'),
     str(output / 'libtorrent.a'), '-framework', 'CoreFoundation',
     '-framework', 'SystemConfiguration', '-lz', '-o', str(output / 'resume-tests')], 30)
report = run([str(output / 'resume-tests')], 45)
json.loads(report)
(root.parent / 'diagnostics/torrent-resume-tests-0.23.json').write_text(report)
print(report.strip())
