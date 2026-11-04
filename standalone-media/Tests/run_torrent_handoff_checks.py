"""Run bounded integration checks against the pinned, already-built host library.
Uses one temporary loopback seed and a client with generated data; no Internet or device writes. Run build_host_torrent.py first.
"""
import json
import os
import pathlib
import signal
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
source = root.parent / 'downloads/standalone-media-sources/libtorrent-rasterbar-1.2.20'
boost = source.parent / 'boost_1_84_0'
output = root / 'build/host-torrent'
current = None


def stop(*_):
    if current is not None and current.poll() is None:
        os.killpg(current.pid, signal.SIGTERM)
        try:
            current.wait(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(current.pid, signal.SIGKILL)
            current.wait()
    raise SystemExit(130)


signal.signal(signal.SIGINT, stop)
signal.signal(signal.SIGTERM, stop)


def run(args, timeout):
    global current
    current = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
    print('Owned test process group:', current.pid, flush=True)
    try:
        stdout, stderr = current.communicate(timeout=timeout)
    except BaseException:
        if current.poll() is None:
            os.killpg(current.pid, signal.SIGKILL)
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
run(['/usr/bin/clang++', *flags, str(root / 'Tests/TorrentHandoffTests.cpp'),
     str(output / 'libtorrent.a'), '-framework', 'CoreFoundation',
     '-framework', 'SystemConfiguration', '-lz', '-o', str(output / 'handoff-tests')], 30)
for mode in (sys.argv[1:] or ['header-only', 'ahead']):
    if mode not in ['header-only', 'ahead']:
        raise SystemExit('Use header-only or ahead.')
    report = run([str(output / 'handoff-tests'), mode], 70)
    (root.parent / ('diagnostics/torrent-handoff-0.31-' + mode + '.jsonl')).write_text(report)
    print(report.strip(), flush=True)
    for line in report.splitlines():
        event=json.loads(line)
        if event.get('event')=='listener':
            probe=subprocess.run(['/usr/sbin/lsof','-nP','-iTCP:'+str(event['port']),'-sTCP:LISTEN'],capture_output=True,text=True,timeout=5)
            if probe.returncode!=1:raise RuntimeError('Test listener was not confirmed released: '+probe.stdout+probe.stderr)
            print('Released loopback port:',event['port'],flush=True)
